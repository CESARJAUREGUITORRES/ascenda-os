\set ON_ERROR_STOP on

DO $$
declare j jsonb; n integer;
begin
  -- Core Auth V3 must remain operational after safe recovery.
  j:=public.aos_login_v3('k1.advisor','advisor-pass-2026');
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1REC-01 Auth V3 unavailable after recovery: %',j; end if;

  -- Security improvements must survive recovery.
  select count(*) into n from public.aos_rrhh where nullif(password_hash,'') is not null;
  if n<>0 then raise exception 'K1REC-02 RRHH credential material restored'; end if;
  if has_table_privilege('anon','public.aos_auth_credentials','SELECT') then raise exception 'K1REC-03 private credentials exposed'; end if;
  if has_table_privilege('anon','public.aos_usuarios','UPDATE') or has_table_privilege('anon','public.aos_rrhh','UPDATE') then raise exception 'K1REC-04 identity writes reopened'; end if;
  if has_column_privilege('anon','public.aos_integraciones','api_key','SELECT') or has_table_privilege('anon','public.aos_integraciones','UPDATE') then raise exception 'K1REC-05 integration secret boundary reopened'; end if;
  if has_table_privilege('anon','public.aos_security_log','SELECT') or has_table_privilege('anon','public.aos_kronia_acciones','SELECT') then raise exception 'K1REC-06 audit boundary reopened'; end if;
  if has_function_privilege('anon','public.aos_editar_venta(bigint,jsonb,text,text,text)','EXECUTE') or has_function_privilege('anon','public.aos_kronia_editar_cita(bigint,jsonb,text,text)','EXECUTE') then raise exception 'K1REC-07 raw mutation authority reopened'; end if;
  if has_function_privilege('anon','public.aos_login(text,text)','EXECUTE') then raise exception 'K1REC-08 password-only login reopened'; end if;
end $$;

select 'KRONIA_K1_PHASE2_SAFE_RECOVERY=PASS' as certificate;
