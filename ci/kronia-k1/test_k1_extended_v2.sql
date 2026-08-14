\set ON_ERROR_STOP on

DO $$
declare v_2fa_def text;
begin
  if has_function_privilege('anon','public.aos_login_v2(text,text)','EXECUTE') then raise exception 'K1E-01 login_v2 browser-callable'; end if;
  if has_function_privilege('authenticated','public.aos_verificar_2fa(text,text)','EXECUTE') then raise exception 'K1E-02 2FA verifier browser-callable'; end if;
  if has_function_privilege('anon','public.aos_kronia_claim_session(text,text,text,text,text,text)','EXECUTE') then raise exception 'K1E-03 session issuer browser-callable'; end if;
  if has_function_privilege('anon','public.aos_kronia_verify_token(text)','EXECUTE') then raise exception 'K1E-04 token verifier browser-callable'; end if;
  if has_function_privilege('anon','public.aos_kronia_revocar_token(text)','EXECUTE') then raise exception 'K1E-05 token revoker browser-callable'; end if;
  if not has_function_privilege('service_role','public.aos_kronia_claim_session(text,text,text,text,text,text)','EXECUTE') then raise exception 'K1E-06 service cannot issue session'; end if;
  if not has_function_privilege('anon','public.aos_kronia_tool(text,text,jsonb)','EXECUTE') then raise exception 'K1E-07 token business gateway unavailable'; end if;
  select lower(pg_get_functiondef('public.aos_verificar_2fa(text,text)'::regprocedure)) into v_2fa_def;
  if position('for update skip locked' in v_2fa_def)=0 or position('set usado = true' in v_2fa_def)=0 then raise exception 'K1E-08 OTP consumption not atomic'; end if;
end $$;

DO $$
declare t text;
begin
  foreach t in array array['aos_kronia_conversaciones','aos_agente_logs','aos_agente_acciones','aos_log_auditoria','aos_security_log'] loop
    if has_table_privilege('anon','public.'||t,'SELECT') or has_table_privilege('anon','public.'||t,'INSERT') or has_table_privilege('anon','public.'||t,'UPDATE') or has_table_privilege('anon','public.'||t,'DELETE') then raise exception 'K1E-09 anon privilege on %',t; end if;
    if has_table_privilege('authenticated','public.'||t,'SELECT') or has_table_privilege('authenticated','public.'||t,'INSERT') or has_table_privilege('authenticated','public.'||t,'UPDATE') or has_table_privilege('authenticated','public.'||t,'DELETE') then raise exception 'K1E-10 auth privilege on %',t; end if;
    if not has_table_privilege('service_role','public.'||t,'SELECT') then raise exception 'K1E-11 service cannot read %',t; end if;
  end loop;
  if has_function_privilege('anon','public.aos_security_dashboard()','EXECUTE') then raise exception 'K1E-12 security dashboard direct browser execute'; end if;
  if exists(select 1 from pg_policies where schemaname='public' and tablename='aos_kronia_conversaciones' and policyname='aos_kronia_conv_all') then raise exception 'K1E-13 permissive conversation policy survived'; end if;
end $$;

insert into public.aos_rrhh(codigo_asesor,nombre,puesto,sede,usuario,password_hash,estado)
values ('A010','Carol Admin','Administradora','SAN ISIDRO','carol',null,'ACTIVO'),('A011','Dave Advisor','Asesor','PUEBLO LIBRE','dave',null,'ACTIVO');
insert into public.aos_usuarios(nombre,email,rol,cargo,sede,activo,two_factor,codigo_asesor,nivel_jerarquia)
values ('Carol Admin','carol@example.test','admin','Administradora','SAN ISIDRO',true,true,'A010',1),('Dave Advisor','dave@example.test','asesor','Asesor','PUEBLO LIBRE',true,false,'A011',4);
select public.aos_auth_set_password('A010','carol-pass-2026');
select public.aos_auth_set_password('A011','dave-pass-2026');

DO $$
declare admin_token text; advisor_token text; integration_id uuid; j jsonb; current_state text; current_key text;
begin
  select id into integration_id from public.aos_integraciones limit 1;
  j:=public.aos_kronia_admin_desactivar_integracion('invalid-token',integration_id);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1E-14 integration accepts invalid token'; end if;
  advisor_token:=public.aos_kronia_claim_session('dave','dave-pass-2026',null,'ci',null,'web')->>'token';
  j:=public.aos_kronia_admin_desactivar_integracion(advisor_token,integration_id);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1E-15 advisor disabled integration'; end if;
  admin_token:=public.k1_ci_claim_token('carol','carol-pass-2026');
  j:=public.aos_kronia_admin_desactivar_integracion(admin_token,integration_id);
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1E-16 admin integration gateway failed %',j; end if;
  select estado,api_key into current_state,current_key from public.aos_integraciones where id=integration_id;
  if current_state<>'pendiente' or current_key is not null then raise exception 'K1E-17 integration secret/state not cleared'; end if;
  if not exists(select 1 from public.aos_kronia_acciones where accion='integration_disable' and objeto_id=integration_id::text and exitoso=true) then raise exception 'K1E-18 integration audit missing'; end if;
end $$;

select 'KRONIA_K1_EXTENDED_V2_CERTIFICATE=PASS' as certificate;
