-- F16 emergency rollback for legacy Email ACL hardening.
-- Restores the exact pre-F16 browser privilege posture observed in production baseline.
-- Use only as recovery if the authoritative server boundary cannot sustain Email operations.

do $rollback$
declare
  t text;
begin
  foreach t in array array[
    'aos_email_alertas','aos_email_audiencias','aos_email_cadencia','aos_email_campanias','aos_email_envios',
    'aos_email_eventos','aos_email_flujo_ejecuciones','aos_email_flujos','aos_email_plantillas',
    'aos_emails_empresa','aos_emails_enviados'
  ] loop
    execute format('alter table public.%I disable row level security',t);
    execute format('grant all on table public.%I to anon,authenticated',t);
  end loop;
end
$rollback$;

grant execute on function public.aos_email_buscar_paciente(text,integer) to public,anon,authenticated,service_role;
grant execute on function public.aos_email_dashboard() to public,anon,authenticated,service_role;
grant execute on function public.aos_email_historial_paciente(text) to public,anon,authenticated,service_role;

select case when count(*)=0 then 'CIA_PHASE16_LEGACY_ACL_ROLLBACK=PASS' else 'CIA_PHASE16_LEGACY_ACL_ROLLBACK=FAIL' end as rollback_result
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relname in (
    'aos_email_alertas','aos_email_audiencias','aos_email_cadencia','aos_email_campanias','aos_email_envios',
    'aos_email_eventos','aos_email_flujo_ejecuciones','aos_email_flujos','aos_email_plantillas',
    'aos_emails_empresa','aos_emails_enviados'
  )
  and c.relrowsecurity;
