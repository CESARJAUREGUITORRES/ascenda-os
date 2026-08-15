-- F16 synthetic legacy Email ACL fixture. Schema-only; no real records or PII/PHI.

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end
$roles$;

do $tables$
declare
  t text;
begin
  foreach t in array array[
    'aos_email_alertas','aos_email_audiencias','aos_email_cadencia','aos_email_campanias','aos_email_envios',
    'aos_email_eventos','aos_email_flujo_ejecuciones','aos_email_flujos','aos_email_plantillas',
    'aos_emails_empresa','aos_emails_enviados'
  ] loop
    execute format('create table if not exists public.%I (id uuid primary key default gen_random_uuid(), payload jsonb not null default ''{}''::jsonb)',t);
    execute format('grant all on table public.%I to anon,authenticated,service_role',t);
  end loop;
end
$tables$;

create or replace function public.aos_email_buscar_paciente(p_buscar text,p_limite integer default 20)
returns jsonb language sql stable as $$ select '[]'::jsonb $$;
create or replace function public.aos_email_dashboard()
returns jsonb language sql stable as $$ select '{}'::jsonb $$;
create or replace function public.aos_email_historial_paciente(p_numero text)
returns jsonb language sql stable as $$ select '[]'::jsonb $$;

grant execute on function public.aos_email_buscar_paciente(text,integer) to public,anon,authenticated,service_role;
grant execute on function public.aos_email_dashboard() to public,anon,authenticated,service_role;
grant execute on function public.aos_email_historial_paciente(text) to public,anon,authenticated,service_role;

select 'CIA_PHASE16_LEGACY_EMAIL_FIXTURE=PASS' as result;
