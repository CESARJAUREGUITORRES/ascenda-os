\set ON_ERROR_STOP on

DO $$
declare
  n integer; j jsonb; tok text; stored text; owner_id uuid; adv_id uuid; blocked boolean; v text;
begin
  select id into owner_id from public.aos_usuarios where codigo_asesor='CAROWNER';
  select id into adv_id from public.aos_usuarios where codigo_asesor='K1ADV';

  -- K1P2-01..07: credential store is private bcrypt; RRHH contains no password material.
  select count(*) into n from public.aos_auth_credentials;
  if n<5 then raise exception 'K1P2-01 expected migrated synthetic credentials, got %',n; end if;
  select count(*) into n from public.aos_auth_credentials where password_hash !~ '^\$2[aby]\$[0-9]{2}\$';
  if n<>0 then raise exception 'K1P2-02 non-bcrypt private credentials=%',n; end if;
  select count(*) into n from public.aos_rrhh where nullif(password_hash,'') is not null;
  if n<>0 then raise exception 'K1P2-03 credential material remains in RRHH=%',n; end if;
  if has_table_privilege('anon','public.aos_auth_credentials','SELECT') or has_table_privilege('authenticated','public.aos_auth_credentials','SELECT') then raise exception 'K1P2-04 private credential table browser-readable'; end if;
  if not public.aos_auth_password_matches('K1ADV','advisor-pass-2026') then raise exception 'K1P2-05 migrated credential rejected'; end if;
  if public.aos_auth_password_matches('K1ADV','wrong-password') then raise exception 'K1P2-06 wrong password accepted'; end if;
  if not coalesce((select tiene_password from public.aos_team_full where codigo_asesor='K1ADV'),false) then raise exception 'K1P2-07 Team lost tiene_password compatibility'; end if;

  -- K1P2-08..11: Auth V3 continues to issue canonical app sessions using private bcrypt.
  j:=public.aos_login_v3('k1.advisor','advisor-pass-2026');
  if not coalesce((j->>'ok')::boolean,false) or coalesce((j->>'require_2fa')::boolean,true) then raise exception 'K1P2-08 Auth V3 advisor login failed: %',j; end if;
  tok:=j->>'app_token';
  if coalesce(length(tok),0)<32 then raise exception 'K1P2-09 Auth V3 did not issue opaque app token'; end if;
  select token_hash into stored from public.aos_app_sessions_v3 where user_id=adv_id and revoked=false order by created_at desc limit 1;
  if stored=tok or stored<>encode(extensions.digest(tok,'sha256'),'hex') then raise exception 'K1P2-10 app token stored raw/mismatched'; end if;
  if public.aos_app_actor_v3(tok,null,false) is distinct from adv_id then raise exception 'K1P2-11 app actor does not resolve new token'; end if;

  -- K1P2-12..16: canonical ADMIN authority is role+level+2FA, never cargo/puesto.
  blocked:=false;
  begin update public.aos_usuarios set two_factor=false where id=owner_id; exception when others then blocked:=true; end;
  if not blocked then raise exception 'K1P2-12 privileged ADMIN can disable 2FA'; end if;
  update public.aos_usuarios set cargo='ADMINISTRADOR',rol='asesor',nivel_jerarquia=4 where id=adv_id;
  j:=public.aos_kronia_identity_v3('k1-advisor-app-token-000000000000000000000001',false,null);
  if not coalesce((j->>'ok')::boolean,false) or j->>'rol'<>'ASESOR' then raise exception 'K1P2-13 free-form cargo elevated authority: %',j; end if;
  j:=public.aos_kronia_identity_v3('k1-owner-app-token-00000000000000000000000001',true,null);
  if not coalesce((j->>'ok')::boolean,false) or j->>'rol'<>'ADMIN' then raise exception 'K1P2-14 owner 2FA app token not authoritative: %',j; end if;
  j:=public.aos_kronia_identity_v3('invalid-token',false,null);if coalesce((j->>'ok')::boolean,true) then raise exception 'K1P2-15 invalid app token accepted'; end if;
  if has_table_privilege('anon','public.aos_app_sessions_v3','SELECT') or has_table_privilege('anon','public.aos_login_challenges_v3','SELECT') then raise exception 'K1P2-16 auth proof stores browser-readable'; end if;

  -- Restore advisor canonical role after anti-escalation check.
  update public.aos_usuarios set cargo='ASESOR',rol='asesor',nivel_jerarquia=4 where id=adv_id;

  -- K1P2-17..25: raw KronIA/business authority is closed; app-token gateway works.
  if has_function_privilege('anon','public.aos_editar_venta(bigint,jsonb,text,text,text)','EXECUTE') then raise exception 'K1P2-17 raw sale editor public'; end if;
  if has_function_privilege('anon','public.aos_kronia_editar_cita(bigint,jsonb,text,text)','EXECUTE') then raise exception 'K1P2-18 raw appointment editor public'; end if;
  if has_function_privilege('anon','public.aos_kronia_explorar(text,text,jsonb)','EXECUTE') then raise exception 'K1P2-19 raw explorer public'; end if;
  if not has_function_privilege('anon','public.aos_kronia_tool_v3(text,text,jsonb)','EXECUTE') then raise exception 'K1P2-20 safe tool gateway unavailable'; end if;
  j:=public.aos_kronia_tool_v3('invalid-token','aos_kronia_stats_leads','{}'::jsonb);if coalesce((j->>'ok')::boolean,true) then raise exception 'K1P2-21 invalid token used tool gateway'; end if;
  j:=public.aos_kronia_tool_v3('k1-advisor-app-token-000000000000000000000001','aos_kronia_explorar',jsonb_build_object('p_modulo','finanzas','p_accion','balance_mes'));
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1P2-22 advisor reached admin explorer'; end if;
  if has_table_privilege('anon','public.aos_kronia_tokens','SELECT') then raise exception 'K1P2-23 legacy KronIA token store readable'; end if;
  if has_function_privilege('anon','public.aos_kronia_emitir_token(text,text,text,text,text,text,text)','EXECUTE') then raise exception 'K1P2-24 legacy KronIA token issuer public'; end if;
  if has_function_privilege('anon','public.aos_kronia_limpiar_tokens_expirados()','EXECUTE') then raise exception 'K1P2-25 token cleanup public'; end if;

  -- K1P2-26..31: authoritative logs are server-owned and sanitized feed is token-gated.
  if has_table_privilege('anon','public.aos_kronia_acciones','SELECT') or has_table_privilege('anon','public.aos_kronia_acciones','INSERT') then raise exception 'K1P2-26 KronIA audit browser-accessible'; end if;
  if has_table_privilege('anon','public.aos_kronia_conversaciones','SELECT') or has_table_privilege('anon','public.aos_kronia_conversaciones','INSERT') then raise exception 'K1P2-27 conversations browser-accessible'; end if;
  if has_table_privilege('anon','public.aos_agente_logs','SELECT') or has_table_privilege('anon','public.aos_log_auditoria','SELECT') then raise exception 'K1P2-28 internal logs browser-readable'; end if;
  if has_table_privilege('anon','public.aos_security_log','DELETE') then raise exception 'K1P2-29 security audit browser-mutable'; end if;
  j:=public.aos_kronia_feed_v3('k1-owner-app-token-00000000000000000000000001','agent_logs',10);
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1P2-30 sanitized admin feed failed: %',j; end if;
  j:=public.aos_kronia_feed_v3('k1-advisor-app-token-000000000000000000000001','agent_logs',10);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1P2-31 advisor read admin feed'; end if;

  -- K1P2-32..40: identity/config/integration secret boundaries.
  if has_table_privilege('anon','public.aos_usuarios','UPDATE') or has_table_privilege('anon','public.aos_rrhh','UPDATE') then raise exception 'K1P2-32 direct identity write remains'; end if;
  if not has_function_privilege('anon','public.aos_admin_identity_v4(text,text,uuid,jsonb)','EXECUTE') then raise exception 'K1P2-33 identity gateway unavailable'; end if;
  j:=public.aos_admin_identity_v4('k1-owner-app-token-00000000000000000000000001','update_profile',adv_id,jsonb_build_object('cargo','ASESOR SENIOR','sede','PUEBLO LIBRE'));
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1P2-34 owner identity update failed: %',j; end if;
  if not exists(select 1 from public.aos_rrhh where codigo_asesor='K1ADV' and puesto='ASESOR SENIOR' and sede='PUEBLO LIBRE') then raise exception 'K1P2-35 RRHH identity projection did not sync'; end if;
  if has_table_privilege('anon','public.aos_configuracion','UPDATE') then raise exception 'K1P2-36 config browser-writable'; end if;
  j:=public.aos_admin_config_v3('k1-owner-app-token-00000000000000000000000001','seg_2fa_habilitado','false');
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1P2-37 owner disabled global 2FA'; end if;
  select valor into v from public.aos_configuracion where clave='seg_2fa_habilitado';if lower(coalesce(v,''))<>'true' then raise exception 'K1P2-38 global 2FA not true'; end if;
  if has_column_privilege('anon','public.aos_integraciones','api_key','SELECT') or has_column_privilege('anon','public.aos_integraciones','api_secret','SELECT') or has_table_privilege('anon','public.aos_integraciones','UPDATE') then raise exception 'K1P2-39 integration secret/write boundary open'; end if;
  j:=public.aos_admin_integracion_v3('invalid-token',gen_random_uuid(),'disable','{}'::jsonb);if coalesce((j->>'ok')::boolean,true) then raise exception 'K1P2-40 integration gateway accepted invalid authority'; end if;
end $$;

select 'KRONIA_K1_PHASE2_CERTIFICATE=PASS' as certificate;
