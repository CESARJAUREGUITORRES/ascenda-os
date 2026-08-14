\set ON_ERROR_STOP on

create temp table k1_v5_tokens(name text primary key, token text not null);
insert into k1_v5_tokens(name,token) values
  ('alice',public.k1_ci_claim_token('alice','alice-pass')),
  ('eve',(public.aos_kronia_claim_session('eve','eve-pass',null,'ci-core',null,'ci')->>'token'));

DO $$
declare t text; stored text; j jsonb; is_revoked boolean;
begin
  -- K1V5-01..04: opaque token issuance + digest storage + bad credential rejection.
  select token into t from k1_v5_tokens where name='alice';
  if t is null or length(t)<>64 then raise exception 'K1V5-01 owner opaque token not issued'; end if;
  select token into stored from public.aos_kronia_tokens where id_asesor='A001' and not revocado order by id desc limit 1;
  if stored=t then raise exception 'K1V5-02 raw token stored'; end if;
  if stored<>encode(extensions.digest(t,'sha256'),'hex') then raise exception 'K1V5-03 token digest mismatch'; end if;
  j:=public.aos_kronia_claim_session('alice','wrong-password',null,'ci-core',null,'ci');
  if coalesce((j->>'ok')::boolean,false) then raise exception 'K1V5-04 wrong password accepted'; end if;

  -- K1V5-05..13: browser cannot reach raw authority/secret stores.
  if has_table_privilege('anon','public.aos_kronia_tokens','SELECT') then raise exception 'K1V5-05 anon reads tokens'; end if;
  if has_function_privilege('anon','public.aos_editar_venta(bigint,jsonb,text,text,text)','EXECUTE') then raise exception 'K1V5-06 raw sale RPC public'; end if;
  if has_function_privilege('anon','public.aos_kronia_editar_cita(bigint,jsonb,text,text)','EXECUTE') then raise exception 'K1V5-07 raw appointment RPC public'; end if;
  if has_function_privilege('anon','public.aos_kronia_editar_paciente(text,jsonb,text)','EXECUTE') then raise exception 'K1V5-08 raw patient RPC public'; end if;
  if not has_function_privilege('anon','public.aos_kronia_tool(text,text,jsonb)','EXECUTE') then raise exception 'K1V5-09 safe business gateway unavailable'; end if;
  if has_column_privilege('anon','public.aos_integraciones','api_key','SELECT')
     or has_column_privilege('anon','public.aos_integraciones','api_secret','SELECT')
     or has_column_privilege('anon','public.aos_integraciones','config','SELECT')
     or has_column_privilege('anon','public.aos_integraciones','webhook_url','SELECT') then
    raise exception 'K1V5-10 integration secret boundary exposed';
  end if;
  if has_table_privilege('anon','public.aos_usuarios','UPDATE') or has_table_privilege('authenticated','public.aos_usuarios','UPDATE') then raise exception 'K1V5-11 identity browser-writable'; end if;
  if has_table_privilege('anon','public.aos_kronia_acciones','SELECT') or has_table_privilege('anon','public.aos_security_log','SELECT') then raise exception 'K1V5-12 audit browser-readable'; end if;
  if has_function_privilege('anon','public.aos_kronia_claim_session(text,text,text,text,text,text)','EXECUTE') then raise exception 'K1V5-13 session issuer browser-callable'; end if;

  -- K1V5-14..19: forged actor/role cannot cross the token-bound gateway.
  select token into t from k1_v5_tokens where name='eve';
  j:=public.aos_kronia_tool(t,'aos_editar_venta',jsonb_build_object(
      'p_venta_id',77,'p_campos','{}'::jsonb,'p_usuario','FAKE ADMIN','p_rol','ADMIN','_session_id','ci-v5-eve'));
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1V5-14 valid advisor gateway call failed: %',j; end if;
  if j->>'actor'<>'EVE' then raise exception 'K1V5-15 forged actor reached RPC: %',j; end if;
  if j->>'role'<>'ASESOR' then raise exception 'K1V5-16 forged role reached RPC: %',j; end if;
  if j->>'origin'<>'kronia' then raise exception 'K1V5-17 origin not server-controlled'; end if;
  j:=public.aos_kronia_tool(t,'aos_kronia_explorar',jsonb_build_object('p_modulo','finanzas','p_accion','balance_mes'));
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1V5-18 advisor reached admin explorer'; end if;
  j:=public.aos_kronia_tool('not-a-valid-token','aos_kronia_stats_leads','{}'::jsonb);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1V5-19 invalid token accepted'; end if;

  -- K1V5-20: authoritative gateway audit is written server-side.
  if not exists(select 1 from public.aos_kronia_acciones where session_id='ci-v5-eve' and accion='tool_call') then
    raise exception 'K1V5-20 gateway audit missing';
  end if;

  -- K1V5-21/22: deactivation invalidates a live session immediately.
  update public.aos_usuarios set activo=false where codigo_asesor='A002';
  j:=public.aos_kronia_verify_token(t);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1V5-21 inactive user token remained valid'; end if;
  select revocado into is_revoked from public.aos_kronia_tokens where token=encode(extensions.digest(t,'sha256'),'hex');
  if not coalesce(is_revoked,false) then raise exception 'K1V5-22 inactive session row not revoked'; end if;
  update public.aos_usuarios set activo=true where codigo_asesor='A002';
end $$;

select 'KRONIA_K1_CORE_V5_CERTIFICATE=PASS' as certificate;
