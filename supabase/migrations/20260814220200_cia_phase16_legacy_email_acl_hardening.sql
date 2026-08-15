-- ASCENDA OS CIA V3 — F16 legacy Email ACL hardening
-- CRITICAL / additive authorization closure. Apply only after server/browser consumers
-- use the authoritative backend boundary and SUPABASE_SERVICE_ROLE_KEY is configured.

begin;

do $acl$
declare
  t text;
begin
  foreach t in array array[
    'aos_email_alertas','aos_email_audiencias','aos_email_cadencia','aos_email_campanias','aos_email_envios',
    'aos_email_eventos','aos_email_flujo_ejecuciones','aos_email_flujos','aos_email_plantillas',
    'aos_emails_empresa','aos_emails_enviados'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on table public.%I from public,anon,authenticated',t);
    execute format('grant all on table public.%I to service_role',t);
  end loop;
end
$acl$;

revoke all on function public.aos_email_buscar_paciente(text,integer) from public,anon,authenticated;
revoke all on function public.aos_email_dashboard() from public,anon,authenticated;
revoke all on function public.aos_email_historial_paciente(text) from public,anon,authenticated;

grant execute on function public.aos_email_buscar_paciente(text,integer) to service_role;
grant execute on function public.aos_email_dashboard() to service_role;
grant execute on function public.aos_email_historial_paciente(text) to service_role;

comment on function public.aos_email_buscar_paciente(text,integer) is 'F16 legacy compatibility RPC: service-role only; browser access goes through server-authoritative Email gateway.';
comment on function public.aos_email_dashboard() is 'F16 legacy compatibility RPC: service-role only; browser access goes through server-authoritative Email gateway.';
comment on function public.aos_email_historial_paciente(text) is 'F16 legacy compatibility RPC: service-role only; browser access goes through server-authoritative Email gateway.';

commit;
