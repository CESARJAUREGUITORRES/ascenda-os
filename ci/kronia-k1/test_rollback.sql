\set ON_ERROR_STOP on

DO $$
declare rls_on boolean; v_2fa_def text; n integer;
begin
  select c.relrowsecurity into rls_on
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='aos_kronia_tokens';
  if coalesce(rls_on,true) then raise exception 'K1-R01 token RLS not restored to compatibility OFF'; end if;

  if to_regprocedure('public.aos_kronia_tool(text,text,jsonb)') is not null then raise exception 'K1-R02 tool gateway not removed'; end if;
  if to_regprocedure('public.aos_kronia_claim_session(text,text,text,text,text,text)') is not null then raise exception 'K1-R03 claim session not removed'; end if;
  if to_regprocedure('public.aos_kronia_admin_desactivar_integracion(text,uuid)') is not null then raise exception 'K1-R04 integration gateway not removed'; end if;

  -- Compatible login returns through login_v2 + atomic 2FA, but never re-open the
  -- password-only login or insecure identity-admin RPCs.
  if not has_function_privilege('anon','public.aos_login_v2(text,text)','EXECUTE') then raise exception 'K1-R05 login_v2 execute not restored'; end if;
  if has_function_privilege('anon','public.aos_login(text,text)','EXECUTE') then raise exception 'K1-R06 password-only login reopened'; end if;
  if has_function_privilege('anon','public.aos_admin_cambiar_password(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text)','EXECUTE') then
    raise exception 'K1-R07 insecure identity ADMIN RPC reopened';
  end if;

  -- Browser identity writes remain closed even in emergency rollback.
  if has_table_privilege('anon','public.aos_usuarios','UPDATE')
     or has_table_privilege('authenticated','public.aos_usuarios','UPDATE')
     or has_table_privilege('anon','public.aos_rrhh','UPDATE') then
    raise exception 'K1-R08 direct identity writes reopened';
  end if;

  -- Private bcrypt store is never rolled back to plaintext.
  if has_table_privilege('anon','public.aos_auth_credentials','SELECT')
     or has_table_privilege('authenticated','public.aos_auth_credentials','SELECT') then
    raise exception 'K1-R09 private credential store became browser-readable';
  end if;
  select count(*) into n from public.aos_rrhh where nullif(password_hash,'') is not null;
  if n<>0 then raise exception 'K1-R10 rollback restored plaintext RRHH passwords rows=%',n; end if;
  select count(*) into n from public.aos_auth_credentials where password_hash !~ '^\$2[aby]\$[0-9]{2}\$';
  if n<>0 then raise exception 'K1-R11 rollback lost bcrypt credential format rows=%',n; end if;

  -- Old operational surfaces are available for emergency runtime compatibility.
  if not has_function_privilege('anon','public.aos_editar_venta(bigint,jsonb,text,text,text)','EXECUTE') then raise exception 'K1-R12 sale execute not restored'; end if;
  if not has_table_privilege('anon','public.aos_integraciones','UPDATE') then raise exception 'K1-R13 integration legacy grant not restored'; end if;
  if not has_table_privilege('anon','public.aos_security_log','DELETE') then raise exception 'K1-R14 audit legacy grant not restored'; end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='aos_kronia_conversaciones' and policyname='aos_kronia_conv_all') then
    raise exception 'K1-R15 conversation legacy policy not restored';
  end if;
  if not has_table_privilege('anon','public.aos_agente_logs','SELECT')
     or not has_table_privilege('anon','public.aos_log_auditoria','INSERT') then
    raise exception 'K1-R16 internal log legacy grants not restored';
  end if;
  if not has_function_privilege('anon','public.aos_security_dashboard()','EXECUTE') then raise exception 'K1-R17 security dashboard legacy execute not restored'; end if;

  -- Atomic OTP intentionally survives rollback.
  select lower(pg_get_functiondef('public.aos_verificar_2fa(text,text)'::regprocedure)) into v_2fa_def;
  if position('for update skip locked' in v_2fa_def)=0 then raise exception 'K1-R18 rollback reintroduced non-atomic 2FA'; end if;
end $$;

-- K1 sessions are invalidated; a newly issued raw-format compatibility token can
-- still be verified by the restored legacy token verifier.
DO $$
declare raw_token text := repeat('a',64); j jsonb;
begin
  if exists(select 1 from public.aos_kronia_tokens) then raise exception 'K1-R19 K1 sessions survived rollback'; end if;
  insert into public.aos_kronia_tokens(token,usuario,rol,expira_at)
  values(raw_token,'ROLLBACK_TEST','ASESOR',now()+interval '1 hour');
  j:=public.aos_kronia_verify_token(raw_token);
  if coalesce((j->>'ok')::boolean,false)=false then raise exception 'K1-R20 legacy raw token verifier not restored: %',j; end if;
end $$;

-- bcrypt-backed login_v2 must remain operational after rollback.
DO $$
declare j json;
begin
  update public.aos_usuarios set two_factor=false where codigo_asesor='A001';
  j:=public.aos_login_v2('alice','alice-pass');
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-R21 bcrypt login_v2 failed after rollback: %',j; end if;
end $$;

select 'KRONIA_K1_ROLLBACK_CERTIFICATE=PASS' as certificate;
