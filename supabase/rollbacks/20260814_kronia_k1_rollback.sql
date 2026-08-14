-- K1 emergency compatibility rollback — post-private-credentials model.
--
-- NON-REVERSIBLE SECURITY IMPROVEMENTS (intentionally preserved):
-- - private bcrypt credential store (`aos_auth_credentials`);
-- - plaintext removed from `aos_rrhh.password_hash`;
-- - atomic one-time OTP verification;
-- - password-only legacy `aos_login` remains browser-denied;
-- - browser writes to `aos_rrhh` / `aos_usuarios` remain denied;
-- - unsafe legacy ADMIN identity RPCs remain denied.
--
-- Operational trade-off: if runtime is reverted to pre-K1 code, Team identity
-- mutation may be temporarily unavailable. Clinic login/data flows take priority
-- over reopening a credential/authorization vulnerability.

begin;

-- 1) Remove K1 core operational gateways/session issuance that require the K1
-- runtime, but retain the safe identity gateway/private credential functions.
drop function if exists public.aos_kronia_admin_desactivar_integracion(text,uuid);
drop function if exists public.aos_kronia_tool(text,text,jsonb);
drop function if exists public.aos_kronia_claim_verified_2fa(text,text,text,text,text);
drop function if exists public.aos_kronia_claim_session(text,text,text,text,text,text);

-- 2) Session token format rolls back to the historical raw-token verifier.
-- K1 SHA-256 token digests cannot be reversed, therefore all sessions expire.
truncate table public.aos_kronia_tokens restart identity;
drop policy if exists kronia_tokens_service_only on public.aos_kronia_tokens;
alter table public.aos_kronia_tokens disable row level security;
grant all on table public.aos_kronia_tokens to anon,authenticated;

create or replace function public.aos_kronia_verify_token(p_token text)
returns jsonb
language plpgsql
security definer
as $$
declare v_row public.aos_kronia_tokens%rowtype;
begin
  if p_token is null or length(p_token)<32 then return jsonb_build_object('ok',false,'error','Token invalido'); end if;
  select * into v_row from public.aos_kronia_tokens where token=p_token limit 1;
  if v_row.id is null then return jsonb_build_object('ok',false,'error','Token no encontrado'); end if;
  if v_row.revocado then return jsonb_build_object('ok',false,'error','Sesion revocada'); end if;
  if v_row.expira_at<now() then return jsonb_build_object('ok',false,'error','Sesion expirada'); end if;
  update public.aos_kronia_tokens set ultimo_uso=now() where id=v_row.id;
  return jsonb_build_object('ok',true,'usuario',v_row.usuario,'id_asesor',v_row.id_asesor,'rol',v_row.rol,'sede',v_row.sede,'email',v_row.email,'expira_at',v_row.expira_at);
end;
$$;

create or replace function public.aos_kronia_revocar_token(p_token text)
returns jsonb
language plpgsql
security definer
as $$
declare v_count integer;
begin
  update public.aos_kronia_tokens set revocado=true where token=p_token and not revocado;
  get diagnostics v_count=row_count;
  return jsonb_build_object('ok',v_count>0,'revocados',v_count);
end;
$$;

-- 3) Restore legacy operational surfaces needed by a pre-K1 runtime.
drop policy if exists integrations_browser_metadata on public.aos_integraciones;
drop policy if exists anon_integ_read on public.aos_integraciones;
drop policy if exists anon_integ_write on public.aos_integraciones;
create policy anon_integ_read on public.aos_integraciones for select to anon using (true);
create policy anon_integ_write on public.aos_integraciones for all to anon using (true) with check (true);
grant all on table public.aos_integraciones to anon,authenticated;

-- Identity tables remain READ-only from browser. Never restore direct writes.
drop policy if exists anon_usuarios_all on public.aos_usuarios;
drop policy if exists usuarios_legacy_read on public.aos_usuarios;
create policy usuarios_legacy_read on public.aos_usuarios for select to anon,authenticated using (true);
revoke insert,update,delete on table public.aos_usuarios from anon,authenticated;
grant select on table public.aos_usuarios to anon,authenticated;
revoke insert,update,delete on table public.aos_rrhh from anon,authenticated;
grant select on table public.aos_rrhh to anon,authenticated;

-- Credential store and helpers remain private.
alter table public.aos_auth_credentials enable row level security;
revoke all on table public.aos_auth_credentials from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_auth_credentials to service_role;
revoke all on function public.aos_auth_password_matches(text,text) from public,anon,authenticated;
revoke all on function public.aos_auth_set_password(text,text) from public,anon,authenticated;
grant execute on function public.aos_auth_password_matches(text,text) to service_role;
grant execute on function public.aos_auth_set_password(text,text) to service_role;

-- Keep safe identity gateway available only if a compatible token is present;
-- never reopen the implementation or legacy ADMIN identity functions.
revoke all on function public.aos_kronia_admin_identity(text,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.aos_kronia_admin_identity(text,text,uuid,jsonb) to service_role;
revoke all on function public.aos_kronia_admin_identity_safe(text,text,uuid,jsonb) from public;
grant execute on function public.aos_kronia_admin_identity_safe(text,text,uuid,jsonb) to anon,authenticated,service_role;

-- Restore old operational audit/log feeds for compatibility with a pre-K1 UI.
drop policy if exists kronia_acc_all on public.aos_kronia_acciones;
create policy kronia_acc_all on public.aos_kronia_acciones for all to anon,authenticated using (true) with check (true);
grant all on table public.aos_kronia_acciones to anon,authenticated;

drop policy if exists kronia_conv_service_only on public.aos_kronia_conversaciones;
drop policy if exists aos_kronia_conv_all on public.aos_kronia_conversaciones;
create policy aos_kronia_conv_all on public.aos_kronia_conversaciones for all to anon,authenticated using (true) with check (true);
grant all on table public.aos_kronia_conversaciones to anon,authenticated;

grant all on table public.aos_agente_logs to anon,authenticated;
grant all on table public.aos_agente_acciones to anon,authenticated;
drop policy if exists gas_access_auditoria on public.aos_log_auditoria;
create policy gas_access_auditoria on public.aos_log_auditoria for all to anon using (true) with check (true);
grant all on table public.aos_log_auditoria to anon,authenticated;
grant all on table public.aos_security_log to anon,authenticated;

-- 4) Restore only compatible browser auth/operational RPCs.
-- login_v2 now uses bcrypt/private credentials; 2FA remains atomic.
grant execute on function public.aos_login_v2(text,text) to anon,authenticated;
grant execute on function public.aos_verificar_2fa(text,text) to anon,authenticated;
revoke all on function public.aos_login(text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_cambiar_password(text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_cambiar_password(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_cambiar_password(text,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_cambiar_username(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_toggle_usuario(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_eliminar_usuario(uuid,text) from public,anon,authenticated,service_role;

grant execute on function public.aos_kronia_emitir_token(text,text,text,text,text,text,text) to anon,authenticated;
grant execute on function public.aos_kronia_limpiar_tokens_expirados() to anon,authenticated;
grant execute on function public.aos_kronia_verify_token(text) to anon,authenticated;
grant execute on function public.aos_kronia_revocar_token(text) to anon,authenticated;
grant execute on function public.aos_security_dashboard() to anon,authenticated;

grant execute on function public.aos_kronia_buscar_cita(text,text,text) to anon,authenticated;
grant execute on function public.aos_kronia_buscar_paciente(text) to anon,authenticated;
grant execute on function public.aos_kronia_buscar_venta(text,text,text) to anon,authenticated;
grant execute on function public.aos_kronia_editar_cita(bigint,jsonb,text,text) to anon,authenticated;
grant execute on function public.aos_kronia_editar_paciente(text,jsonb,text) to anon,authenticated;
grant execute on function public.aos_kronia_reprogramar_seguimiento(text,text,text,text,text) to anon,authenticated;
grant execute on function public.aos_kronia_marcar_estado_cita(bigint,text,text,text) to anon,authenticated;
grant execute on function public.aos_kronia_agregar_nota_paciente(text,text,text) to anon,authenticated;
grant execute on function public.aos_kronia_explorar(text,text,jsonb) to anon,authenticated;
grant execute on function public.aos_kronia_obtener_insights_sofia() to anon,authenticated;
grant execute on function public.aos_kronia_stats_leads() to anon,authenticated;
grant execute on function public.aos_kronia_stats_agenda() to anon,authenticated;
grant execute on function public.aos_kronia_stats_llamadas() to anon,authenticated;
grant execute on function public.aos_kronia_stats_pacientes() to anon,authenticated;
grant execute on function public.aos_editar_venta(bigint,jsonb,text,text,text) to anon,authenticated;

commit;
