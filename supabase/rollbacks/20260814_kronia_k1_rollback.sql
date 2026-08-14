-- K1 security-preserving emergency rollback.
--
-- PURPOSE
-- Revert K1-dependent runtime behavior while NEVER restoring the vulnerabilities
-- K1 was created to remove. Availability may degrade for KronIA/Team/Agents;
-- identity, credentials, auth/session primitives, secrets and authoritative audit
-- remain closed. Emergency recovery must prefer safe degradation over reopening
-- a browser-trust boundary.
--
-- PERMANENTLY PRESERVED SECURITY
-- - bcrypt credentials remain in aos_auth_credentials only;
-- - aos_rrhh.password_hash stays empty;
-- - ADMIN role hierarchy + ADMIN 2FA identity invariant survive;
-- - global 2FA=true invariant survives;
-- - token store remains service-only and all K1 sessions are invalidated;
-- - login/2FA/token primitives are NOT re-opened to browser roles;
-- - identity/config/integration-secret/audit browser writes remain denied;
-- - raw business mutation RPCs remain denied to browser roles.

begin;

-- 1) Invalidate all K1 sessions. Keep token storage private; never restore raw
-- browser-managed tokens during emergency rollback.
truncate table public.aos_kronia_tokens restart identity;
alter table public.aos_kronia_tokens enable row level security;
drop policy if exists kronia_tokens_service_only on public.aos_kronia_tokens;
create policy kronia_tokens_service_only on public.aos_kronia_tokens
  for all to service_role using (true) with check (true);
revoke all on table public.aos_kronia_tokens from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_kronia_tokens to service_role;

revoke all on function public.aos_kronia_emitir_token(text,text,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.aos_kronia_verify_token(text) from public,anon,authenticated;
revoke all on function public.aos_kronia_revocar_token(text) from public,anon,authenticated;
grant execute on function public.aos_kronia_verify_token(text) to service_role;
grant execute on function public.aos_kronia_revocar_token(text) to service_role;

-- K1-only issuance/tool functions may be removed when reverting the runtime.
drop function if exists public.aos_kronia_admin_desactivar_integracion(text,uuid);
drop function if exists public.aos_kronia_tool(text,text,jsonb);
drop function if exists public.aos_kronia_claim_verified_2fa(text,text,text,text,text);
drop function if exists public.aos_kronia_claim_session(text,text,text,text,text,text);

-- 2) Authentication primitives remain server-only. login_v2 returns the OTP code
-- in its JSON contract for trusted server-side delivery; exposing it directly to
-- a browser would collapse the second factor. Rollback therefore does NOT grant
-- anon/authenticated EXECUTE on login_v2 or aos_verificar_2fa.
revoke all on function public.aos_login_v2(text,text) from public,anon,authenticated;
revoke all on function public.aos_verificar_2fa(text,text) from public,anon,authenticated;
grant execute on function public.aos_login_v2(text,text) to service_role;
grant execute on function public.aos_verificar_2fa(text,text) to service_role;
revoke all on function public.aos_login(text,text) from public,anon,authenticated;
revoke all on function public.aos_cambiar_password(text,text,text) from public,anon,authenticated;

-- 3) Identity and credentials remain protected.
alter table public.aos_auth_credentials enable row level security;
drop policy if exists auth_credentials_service_only on public.aos_auth_credentials;
create policy auth_credentials_service_only on public.aos_auth_credentials
  for all to service_role using (true) with check (true);
revoke all on table public.aos_auth_credentials from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_auth_credentials to service_role;
revoke all on function public.aos_auth_password_matches(text,text) from public,anon,authenticated;
revoke all on function public.aos_auth_set_password(text,text) from public,anon,authenticated;
grant execute on function public.aos_auth_password_matches(text,text) to service_role;
grant execute on function public.aos_auth_set_password(text,text) to service_role;

revoke insert,update,delete on table public.aos_usuarios from anon,authenticated;
grant select on table public.aos_usuarios to anon,authenticated;
revoke insert,update,delete on table public.aos_rrhh from anon,authenticated;
grant select on table public.aos_rrhh to anon,authenticated;

revoke all on function public.aos_admin_cambiar_password(uuid,text) from public,anon,authenticated;
revoke all on function public.aos_admin_cambiar_password(text,text,text,text) from public,anon,authenticated;
revoke all on function public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text) from public,anon,authenticated;
revoke all on function public.aos_admin_cambiar_username(uuid,text) from public,anon,authenticated;
revoke all on function public.aos_admin_toggle_usuario(uuid,boolean) from public,anon,authenticated;
revoke all on function public.aos_admin_eliminar_usuario(uuid,text) from public,anon,authenticated;
revoke all on function public.aos_kronia_admin_identity(text,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.aos_kronia_admin_identity(text,text,uuid,jsonb) to service_role;

-- Safe wrapper/config gateway may remain present, but without a browser-mintable
-- K1 session they cannot create authority during rollback.

-- 4) Configuration and integration secrets stay non-mutable/non-readable.
revoke insert,update,delete on table public.aos_configuracion from anon,authenticated;
grant select on table public.aos_configuracion to anon,authenticated;

revoke all on table public.aos_integraciones from anon,authenticated;
grant select (id,tipo,nombre,cuenta,estado,principal,categoria,icono,descripcion,uso_para,orden,url_docs,url_signup,multi_cuenta,logo_url,created_at,updated_at)
  on public.aos_integraciones to anon,authenticated;

-- 5) Authoritative logs/conversations stay server-owned.
revoke all on table public.aos_kronia_acciones from anon,authenticated;
revoke all on table public.aos_kronia_conversaciones from anon,authenticated;
revoke all on table public.aos_agente_logs from anon,authenticated;
revoke all on table public.aos_agente_acciones from anon,authenticated;
revoke all on table public.aos_log_auditoria from anon,authenticated;
revoke all on table public.aos_security_log from anon,authenticated;
revoke all on function public.aos_security_dashboard() from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_kronia_acciones to service_role;
grant select,insert,update,delete on table public.aos_kronia_conversaciones to service_role;
grant select,insert,update,delete on table public.aos_agente_logs to service_role;
grant select,insert,update,delete on table public.aos_agente_acciones to service_role;
grant select,insert,update,delete on table public.aos_log_auditoria to service_role;
grant select,insert,update,delete on table public.aos_security_log to service_role;
grant execute on function public.aos_security_dashboard() to service_role;

-- 6) Raw browser mutation/explorer RPCs remain closed. Emergency rollback is a
-- safe degradation, not permission restoration.
revoke all on function public.aos_kronia_editar_cita(bigint,jsonb,text,text) from public,anon,authenticated;
revoke all on function public.aos_kronia_editar_paciente(text,jsonb,text) from public,anon,authenticated;
revoke all on function public.aos_kronia_reprogramar_seguimiento(text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.aos_kronia_marcar_estado_cita(bigint,text,text,text) from public,anon,authenticated;
revoke all on function public.aos_kronia_agregar_nota_paciente(text,text,text) from public,anon,authenticated;
revoke all on function public.aos_kronia_explorar(text,text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_editar_venta(bigint,jsonb,text,text,text) from public,anon,authenticated;

commit;
