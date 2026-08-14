\set ON_ERROR_STOP on

-- Fail-fast assertions without depending on application data.
create temp table k1_tokens(name text primary key, token text not null);

-- Baseline claims: one ADMIN and one advisor.
insert into k1_tokens(name,token)
select 'alice', (public.aos_kronia_claim_session('alice','pw-admin',null,'ci',null,'web')->>'token');
insert into k1_tokens(name,token)
select 'eve', (public.aos_kronia_claim_session('eve','pw-eve',null,'ci',null,'web')->>'token');

DO $$
declare t text; stored text; j jsonb;
begin
  select token into t from k1_tokens where name='alice';
  if t is null or length(t) <> 64 then raise exception 'K1-01 raw opaque token not issued'; end if;
  select token into stored from public.aos_kronia_tokens where upper(usuario)='ALICE' and origen='web' and not revocado order by id desc limit 1;
  if stored = t then raise exception 'K1-02 raw token stored in database'; end if;
  if stored <> encode(digest(t,'sha256'),'hex') then raise exception 'K1-03 token digest mismatch'; end if;

  j := public.aos_kronia_claim_session('alice','wrong',null,'ci',null,'web');
  if coalesce((j->>'ok')::boolean,false) then raise exception 'K1-04 invalid password accepted'; end if;
end $$;

-- Direct browser privileges must be closed.
DO $$
begin
  if has_table_privilege('anon','public.aos_kronia_tokens','SELECT') then raise exception 'K1-05 anon can read tokens'; end if;
  if has_table_privilege('authenticated','public.aos_kronia_tokens','SELECT') then raise exception 'K1-06 authenticated can read tokens'; end if;
  if has_function_privilege('anon','public.aos_editar_venta(bigint,jsonb,text,text,text)','EXECUTE') then raise exception 'K1-07 raw sale editor RPC executable by anon'; end if;
  if has_function_privilege('anon','public.aos_kronia_editar_cita(bigint,jsonb,text,text)','EXECUTE') then raise exception 'K1-08 raw appointment RPC executable by anon'; end if;
  if has_function_privilege('anon','public.aos_kronia_editar_paciente(text,jsonb,text)','EXECUTE') then raise exception 'K1-09 raw patient RPC executable by anon'; end if;
  if has_function_privilege('anon','public.aos_kronia_explorar(text,text,jsonb)','EXECUTE') then raise exception 'K1-10 raw explorer executable by anon'; end if;
  if not has_function_privilege('anon','public.aos_kronia_tool(text,text,jsonb)','EXECUTE') then raise exception 'K1-11 gateway unavailable to anon client'; end if;
  if has_function_privilege('anon','public.aos_kronia_emitir_token(text,text,text,text,text,text,text)','EXECUTE') then raise exception 'K1-12 legacy token issuer still public'; end if;
end $$;

-- Secret columns are inaccessible while safe integration metadata remains readable.
DO $$
begin
  if has_column_privilege('anon','public.aos_integraciones','api_key','SELECT') then raise exception 'K1-13 api_key readable'; end if;
  if has_column_privilege('anon','public.aos_integraciones','api_secret','SELECT') then raise exception 'K1-14 api_secret readable'; end if;
  if has_column_privilege('anon','public.aos_integraciones','config','SELECT') then raise exception 'K1-15 config secret boundary readable'; end if;
  if has_column_privilege('anon','public.aos_integraciones','webhook_url','SELECT') then raise exception 'K1-16 webhook secret boundary readable'; end if;
  if not has_column_privilege('anon','public.aos_integraciones','nombre','SELECT') then raise exception 'K1-17 integration metadata unavailable'; end if;
end $$;

-- Browser roles cannot mutate identity or authoritative security/audit material.
DO $$
begin
  if has_table_privilege('anon','public.aos_usuarios','INSERT') or has_table_privilege('anon','public.aos_usuarios','UPDATE') or has_table_privilege('anon','public.aos_usuarios','DELETE') then raise exception 'K1-18 anon can mutate identity'; end if;
  if has_table_privilege('authenticated','public.aos_usuarios','UPDATE') then raise exception 'K1-19 authenticated can mutate identity'; end if;
  if has_table_privilege('anon','public.aos_kronia_acciones','SELECT') or has_table_privilege('anon','public.aos_kronia_acciones','INSERT') or has_table_privilege('anon','public.aos_kronia_acciones','UPDATE') or has_table_privilege('anon','public.aos_kronia_acciones','DELETE') then raise exception 'K1-20 authoritative KronIA audit exposed'; end if;
  if has_table_privilege('anon','public.aos_security_log','SELECT') or has_table_privilege('anon','public.aos_security_log','INSERT') then raise exception 'K1-21 security log exposed'; end if;
end $$;

-- Gateway must ignore forged p_usuario/p_rol and use token-derived identity.
DO $$
declare t text; j jsonb;
begin
  select token into t from k1_tokens where name='eve';
  j := public.aos_kronia_tool(t,'aos_editar_venta',jsonb_build_object(
    'p_venta_id',77,'p_campos','{}'::jsonb,'p_usuario','FAKE ADMIN','p_rol','ADMIN','_session_id','ci-eve'));
  if coalesce((j->>'ok')::boolean,false)=false then raise exception 'K1-22 gateway rejected valid advisor'; end if;
  if j->>'actor' <> 'EVE' then raise exception 'K1-23 forged actor reached raw RPC: %',j; end if;
  if j->>'role' <> 'ASESOR' then raise exception 'K1-24 forged role reached raw RPC: %',j; end if;
  if j->>'origin' <> 'kronia' then raise exception 'K1-25 origin not server controlled'; end if;

  j := public.aos_kronia_tool(t,'aos_kronia_explorar',jsonb_build_object('p_modulo','finanzas','p_accion','balance_mes'));
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-26 advisor reached admin explorer'; end if;

  j := public.aos_kronia_tool('not-a-valid-token','aos_kronia_stats_leads','{}'::jsonb);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-27 invalid token accepted by gateway'; end if;
end $$;

-- Role changes take effect without reissuing a token.
DO $$
declare t text; j jsonb;
begin
  select token into t from k1_tokens where name='alice';
  j := public.aos_kronia_verify_token(t);
  if j->>'rol' <> 'ADMIN' then raise exception 'K1-28 initial authoritative admin role wrong'; end if;
  update public.aos_usuarios set rol='ASESOR',cargo='Asesora' where nombre='Alice Admin';
  j := public.aos_kronia_verify_token(t);
  if j->>'rol' <> 'ASESOR' then raise exception 'K1-29 role not re-derived after demotion'; end if;
end $$;

-- Deactivation immediately invalidates an existing session and revokes its row.
DO $$
declare t text; j jsonb; is_revoked boolean;
begin
  select token into t from k1_tokens where name='eve';
  update public.aos_usuarios set activo=false where nombre='Eve Advisor';
  j := public.aos_kronia_verify_token(t);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-30 inactive user token remains valid'; end if;
  select revocado into is_revoked from public.aos_kronia_tokens where token=encode(digest(t,'sha256'),'hex');
  if not coalesce(is_revoked,false) then raise exception 'K1-31 inactive session row not revoked'; end if;
end $$;

-- 2FA extension claim is impossible before verification, then one-time after it.
insert into public.aos_auth_codes(usuario,email,codigo,usado,expira_at)
values ('Bob TwoFactor','bob@example.test','123456',false,now()+interval '5 minutes');

DO $$
declare j jsonb;
begin
  j := public.aos_kronia_claim_verified_2fa('Bob TwoFactor','123456','ci',null,'chrome_extension');
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-32 unverified 2FA code claimed'; end if;
end $$;

update public.aos_auth_codes set usado=true where usuario='Bob TwoFactor' and codigo='123456';

DO $$
declare j jsonb; raw text; stored text;
begin
  j := public.aos_kronia_claim_verified_2fa('Bob TwoFactor','123456','ci',null,'chrome_extension');
  if coalesce((j->>'ok')::boolean,false)=false then raise exception 'K1-33 verified 2FA claim failed: %',j; end if;
  raw := j->>'token';
  select token into stored from public.aos_kronia_tokens where usuario='BOB' and origen='chrome_extension' and not revocado order by id desc limit 1;
  if stored=raw or stored<>encode(digest(raw,'sha256'),'hex') then raise exception 'K1-34 extension token stored raw/mismatched'; end if;
  j := public.aos_kronia_claim_verified_2fa('Bob TwoFactor','123456','ci',null,'chrome_extension');
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-35 2FA code replay accepted'; end if;
end $$;

-- Authoritative gateway audit exists and is not browser-readable.
DO $$
begin
  if not exists (select 1 from public.aos_kronia_acciones where session_id='ci-eve' and accion='tool_call') then
    raise exception 'K1-36 gateway did not write authoritative audit';
  end if;
end $$;

select 'KRONIA_K1_NEGATIVE_AUTH_CERTIFICATE=PASS' as certificate;
