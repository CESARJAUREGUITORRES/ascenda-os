-- K1 rollback to pre-2026-08-14 trust boundary.
-- SECURITY NOTE: this intentionally restores legacy browser privileges only for
-- emergency compatibility rollback. Re-applying K1 should be prioritized.
-- Token digests are irreversible, so rollback invalidates all KronIA sessions.

begin;

-- 1) Remove K1-only gateways/session issuance.
drop function if exists public.aos_kronia_admin_desactivar_integracion(text,uuid);
drop function if exists public.aos_kronia_tool(text,text,jsonb);
drop function if exists public.aos_kronia_claim_verified_2fa(text,text,text,text,text);
drop function if exists public.aos_kronia_claim_session(text,text,text,text,text,text);

-- 2) Hashed session material cannot safely be converted back to raw tokens.
-- Force re-authentication under the restored legacy issuer instead.
truncate table public.aos_kronia_tokens restart identity;
drop policy if exists kronia_tokens_service_only on public.aos_kronia_tokens;
alter table public.aos_kronia_tokens disable row level security;
grant all on table public.aos_kronia_tokens to anon,authenticated;

-- Restore the exact pre-K1 token verifier/revoker behavior.
create or replace function public.aos_kronia_verify_token(p_token text)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_row public.aos_kronia_tokens%rowtype;
begin
  if p_token is null or length(p_token) < 32 then
    return jsonb_build_object('ok',false,'error','Token invalido');
  end if;

  select * into v_row from public.aos_kronia_tokens where token=p_token limit 1;
  if v_row.id is null then return jsonb_build_object('ok',false,'error','Token no encontrado'); end if;
  if v_row.revocado then return jsonb_build_object('ok',false,'error','Sesion revocada'); end if;
  if v_row.expira_at < now() then return jsonb_build_object('ok',false,'error','Sesion expirada'); end if;

  update public.aos_kronia_tokens set ultimo_uso=now() where id=v_row.id;
  return jsonb_build_object(
    'ok',true,'usuario',v_row.usuario,'id_asesor',v_row.id_asesor,
    'rol',v_row.rol,'sede',v_row.sede,'email',v_row.email,'expira_at',v_row.expira_at
  );
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

-- 3) Restore legacy Integration / identity / audit policies and grants.
drop policy if exists integrations_browser_metadata on public.aos_integraciones;
drop policy if exists anon_integ_read on public.aos_integraciones;
drop policy if exists anon_integ_write on public.aos_integraciones;
create policy anon_integ_read on public.aos_integraciones for select to anon using (true);
create policy anon_integ_write on public.aos_integraciones for all to anon using (true) with check (true);
grant all on table public.aos_integraciones to anon,authenticated;

drop policy if exists usuarios_legacy_read on public.aos_usuarios;
drop policy if exists anon_usuarios_all on public.aos_usuarios;
create policy anon_usuarios_all on public.aos_usuarios for all to anon using (true) with check (true);
grant all on table public.aos_usuarios to anon,authenticated;

drop policy if exists kronia_acc_all on public.aos_kronia_acciones;
create policy kronia_acc_all on public.aos_kronia_acciones for all to anon,authenticated using (true) with check (true);
grant all on table public.aos_kronia_acciones to anon,authenticated;

grant all on table public.aos_kronia_conversaciones to anon,authenticated;
grant all on table public.aos_agente_logs to anon,authenticated;
grant all on table public.aos_agente_acciones to anon,authenticated;
grant all on table public.aos_log_auditoria to anon,authenticated;
grant all on table public.aos_security_log to anon,authenticated;

-- 4) Restore pre-K1 browser EXECUTE privileges.
grant execute on function public.aos_login_v2(text,text) to anon,authenticated;
grant execute on function public.aos_verificar_2fa(text,text) to anon,authenticated;
grant execute on function public.aos_kronia_emitir_token(text,text,text,text,text,text,text) to anon,authenticated;
grant execute on function public.aos_kronia_limpiar_tokens_expirados() to anon,authenticated;
grant execute on function public.aos_kronia_verify_token(text) to anon,authenticated;
grant execute on function public.aos_kronia_revocar_token(text) to anon,authenticated;

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
