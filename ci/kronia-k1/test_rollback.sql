\set ON_ERROR_STOP on

DO $$
declare rls_on boolean; v_2fa_def text;
begin
  select c.relrowsecurity into rls_on
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='aos_kronia_tokens';
  if coalesce(rls_on,true) then raise exception 'K1-R01 token RLS not restored to baseline OFF'; end if;

  if to_regprocedure('public.aos_kronia_tool(text,text,jsonb)') is not null then raise exception 'K1-R02 tool gateway not removed'; end if;
  if to_regprocedure('public.aos_kronia_claim_session(text,text,text,text,text,text)') is not null then raise exception 'K1-R03 claim session not removed'; end if;
  if to_regprocedure('public.aos_kronia_admin_desactivar_integracion(text,uuid)') is not null then raise exception 'K1-R04 integration gateway not removed'; end if;

  if not has_function_privilege('anon','public.aos_login_v2(text,text)','EXECUTE') then raise exception 'K1-R05 login execute not restored'; end if;
  if not has_function_privilege('anon','public.aos_editar_venta(bigint,jsonb,text,text,text)','EXECUTE') then raise exception 'K1-R06 sale execute not restored'; end if;
  if not has_table_privilege('anon','public.aos_integraciones','UPDATE') then raise exception 'K1-R07 integration legacy grant not restored'; end if;
  if not has_table_privilege('anon','public.aos_usuarios','UPDATE') then raise exception 'K1-R08 identity legacy grant not restored'; end if;
  if not has_table_privilege('anon','public.aos_security_log','DELETE') then raise exception 'K1-R09 audit legacy grant not restored'; end if;

  if not exists(select 1 from pg_policies where schemaname='public' and tablename='aos_kronia_conversaciones' and policyname='aos_kronia_conv_all') then
    raise exception 'K1-R12 conversation legacy policy not restored';
  end if;
  if not has_table_privilege('anon','public.aos_agente_logs','SELECT')
     or not has_table_privilege('anon','public.aos_log_auditoria','INSERT') then
    raise exception 'K1-R13 internal log legacy grants not restored';
  end if;
  if not has_function_privilege('anon','public.aos_security_dashboard()','EXECUTE') then
    raise exception 'K1-R14 security dashboard legacy execute not restored';
  end if;

  -- Security improvement intentionally survives rollback because the public JSON
  -- contract is unchanged; reintroducing the OTP race is never required for compatibility.
  select lower(pg_get_functiondef('public.aos_verificar_2fa(text,text)'::regprocedure)) into v_2fa_def;
  if position('for update skip locked' in v_2fa_def)=0 then
    raise exception 'K1-R15 rollback reintroduced non-atomic 2FA';
  end if;
end $$;

-- Hashed K1 sessions must have been invalidated, but the legacy raw verifier must
-- operate after a new raw token is issued/inserted.
DO $$
declare raw_token text := repeat('a',64); j jsonb;
begin
  if exists(select 1 from public.aos_kronia_tokens) then raise exception 'K1-R10 K1 sessions survived rollback'; end if;
  insert into public.aos_kronia_tokens(token,usuario,rol,expira_at)
  values(raw_token,'ROLLBACK_TEST','ASESOR',now()+interval '1 hour');
  j := public.aos_kronia_verify_token(raw_token);
  if coalesce((j->>'ok')::boolean,false)=false then raise exception 'K1-R11 legacy raw token verifier not restored: %',j; end if;
end $$;

select 'KRONIA_K1_ROLLBACK_CERTIFICATE=PASS' as certificate;
