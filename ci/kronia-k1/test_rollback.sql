\set ON_ERROR_STOP on

DO $$
declare rls_on boolean; v_2fa_def text; n integer; blocked boolean; v text; j json;
begin
  -- K1-R01..04: session store remains private and K1 sessions are invalidated.
  select c.relrowsecurity into rls_on
  from pg_class c join pg_namespace nsp on nsp.oid=c.relnamespace
  where nsp.nspname='public' and c.relname='aos_kronia_tokens';
  if not coalesce(rls_on,false) then raise exception 'K1-R01 token RLS disabled by rollback'; end if;
  if has_table_privilege('anon','public.aos_kronia_tokens','SELECT')
     or has_table_privilege('authenticated','public.aos_kronia_tokens','SELECT') then raise exception 'K1-R02 browser can read token store'; end if;
  if not has_table_privilege('service_role','public.aos_kronia_tokens','SELECT') then raise exception 'K1-R03 service cannot read token store'; end if;
  if exists(select 1 from public.aos_kronia_tokens) then raise exception 'K1-R04 K1 sessions survived rollback'; end if;

  -- K1-R05..10: no browser auth/token issuer or identity-admin authority is restored.
  if has_function_privilege('anon','public.aos_login_v2(text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_login_v2(text,text)','EXECUTE') then raise exception 'K1-R05 login_v2 exposed to browser'; end if;
  if has_function_privilege('anon','public.aos_verificar_2fa(text,text)','EXECUTE') then raise exception 'K1-R06 2FA verifier exposed to browser'; end if;
  if has_function_privilege('anon','public.aos_kronia_emitir_token(text,text,text,text,text,text,text)','EXECUTE') then raise exception 'K1-R07 legacy token issuer reopened'; end if;
  if has_function_privilege('anon','public.aos_kronia_verify_token(text)','EXECUTE') then raise exception 'K1-R08 token verifier reopened'; end if;
  if has_function_privilege('anon','public.aos_login(text,text)','EXECUTE') then raise exception 'K1-R09 password-only login reopened'; end if;
  if has_function_privilege('anon','public.aos_admin_cambiar_password(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text)','EXECUTE') then raise exception 'K1-R10 unsafe identity ADMIN RPC reopened'; end if;

  -- K1-R11..14: credentials and identity tables remain protected.
  if has_table_privilege('anon','public.aos_auth_credentials','SELECT')
     or has_table_privilege('authenticated','public.aos_auth_credentials','SELECT') then raise exception 'K1-R11 private credential store readable'; end if;
  select count(*) into n from public.aos_rrhh where nullif(password_hash,'') is not null;
  if n<>0 then raise exception 'K1-R12 plaintext RRHH password material restored rows=%',n; end if;
  select count(*) into n from public.aos_auth_credentials where password_hash !~ '^\$2[aby]\$[0-9]{2}\$';
  if n<>0 then raise exception 'K1-R13 non-bcrypt credential rows=%',n; end if;
  if has_table_privilege('anon','public.aos_usuarios','UPDATE') or has_table_privilege('anon','public.aos_rrhh','UPDATE') then raise exception 'K1-R14 identity browser writes reopened'; end if;

  -- K1-R15..18: secrets/audit/raw mutation boundaries stay closed.
  if has_table_privilege('anon','public.aos_integraciones','UPDATE')
     or has_column_privilege('anon','public.aos_integraciones','api_key','SELECT') then raise exception 'K1-R15 integration secret boundary reopened'; end if;
  if has_table_privilege('anon','public.aos_security_log','SELECT')
     or has_table_privilege('anon','public.aos_kronia_conversaciones','SELECT') then raise exception 'K1-R16 audit/conversation boundary reopened'; end if;
  if has_function_privilege('anon','public.aos_editar_venta(bigint,jsonb,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.aos_kronia_editar_cita(bigint,jsonb,text,text)','EXECUTE') then raise exception 'K1-R17 raw business mutation reopened'; end if;
  if has_function_privilege('anon','public.aos_security_dashboard()','EXECUTE') then raise exception 'K1-R18 security dashboard reopened'; end if;

  -- K1-R19..22: atomic OTP + global/admin 2FA invariants survive rollback.
  select lower(pg_get_functiondef('public.aos_verificar_2fa(text,text)'::regprocedure)) into v_2fa_def;
  if position('for update skip locked' in v_2fa_def)=0 then raise exception 'K1-R19 non-atomic 2FA restored'; end if;
  select valor into v from public.aos_configuracion where clave='seg_2fa_habilitado';
  if lower(coalesce(v,''))<>'true' then raise exception 'K1-R20 global 2FA invariant lost'; end if;
  blocked:=false;
  begin update public.aos_configuracion set valor='false' where clave='seg_2fa_habilitado'; exception when others then blocked:=true; end;
  if not blocked then raise exception 'K1-R21 rollback allows global 2FA disable'; end if;
  blocked:=false;
  begin update public.aos_usuarios set two_factor=false where codigo_asesor='A001'; exception when others then blocked:=true; end;
  if not blocked then raise exception 'K1-R22 privileged ADMIN 2FA invariant lost'; end if;

  -- K1-R23: server-side bcrypt login primitive remains operational and still
  -- requires 2FA for the owner. It is tested as postgres/service context only.
  j:=public.aos_login_v2('alice','alice-pass');
  if not coalesce((j->>'ok')::boolean,false) or not coalesce((j->>'require_2fa')::boolean,false) then
    raise exception 'K1-R23 server-side bcrypt login/2FA failed after rollback: %',j;
  end if;
end $$;

select 'KRONIA_K1_ROLLBACK_CERTIFICATE=PASS' as certificate;
