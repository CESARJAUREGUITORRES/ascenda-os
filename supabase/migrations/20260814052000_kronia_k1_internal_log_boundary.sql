-- K1 — Internal conversation / audit / agent-log boundary.
-- Browser roles must not read or forge internal history. Approved UI consumers
-- are migrated to authenticated Node endpoints which use service_role.

begin;

-- KronIA conversation history may contain user/patient context. Remove the
-- historical ALL policy and make the already-RLS-enabled table service-only.
drop policy if exists aos_kronia_conv_all on public.aos_kronia_conversaciones;
drop policy if exists kronia_conv_service_only on public.aos_kronia_conversaciones;
revoke all on table public.aos_kronia_conversaciones from anon, authenticated;
grant select, insert, update, delete on table public.aos_kronia_conversaciones to service_role;
create policy kronia_conv_service_only
  on public.aos_kronia_conversaciones
  for all to service_role
  using (true)
  with check (true);

-- Internal agent telemetry/actions are no longer a direct browser datastore.
-- The Agent Office consumes a narrow ADMIN Bearer endpoint after K1.
revoke all on table public.aos_agente_logs from anon, authenticated;
revoke all on table public.aos_agente_acciones from anon, authenticated;
grant select, insert, update, delete on table public.aos_agente_logs to service_role;
grant select, insert, update, delete on table public.aos_agente_acciones to service_role;

-- Audit history is served only through tokenized/sanitized application APIs.
-- Remove the dormant permissive policy too so a later RLS enable cannot
-- accidentally reopen anonymous access.
drop policy if exists gas_access_auditoria on public.aos_log_auditoria;
revoke all on table public.aos_log_auditoria from anon, authenticated;
grant select, insert, update, delete on table public.aos_log_auditoria to service_role;

-- Security log was already browser-denied by 515; make the server dependency
-- explicit because K1 security dashboard/report paths now read it via service.
revoke all on table public.aos_security_log from anon, authenticated;
grant select, insert, update, delete on table public.aos_security_log to service_role;

-- Security dashboard is an internal read model. The browser must go through
-- /api/kronia/admin/security-dashboard with an authoritative ADMIN session.
revoke all on function public.aos_security_dashboard() from public, anon, authenticated;
grant execute on function public.aos_security_dashboard() to service_role;

commit;
