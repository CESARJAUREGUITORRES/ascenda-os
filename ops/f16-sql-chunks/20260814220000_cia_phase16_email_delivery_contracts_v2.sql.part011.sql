  return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
end
$function$;

create or replace function public.aos_cia_email_f17_readiness_v1()
returns jsonb
language plpgsql
stable
set search_path = ''
as $function$
declare
  v_f15 jsonb;
  v_tables integer;
  v_rls integer;
  v_anon_direct boolean;
  v_auth_direct boolean;
  v_illegal integer;
  v_release record;
  v_ready boolean;
begin
  v_f15 := public.aos_cia_kronia_f16_readiness_v1();

  select count(*)::integer into v_tables
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions',
    'aos_cia_email_send_requests','aos_cia_email_send_events','aos_cia_email_release_state'
  ) and c.relkind='r';

  select count(*)::integer into v_rls
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions',
    'aos_cia_email_send_requests','aos_cia_email_send_events','aos_cia_email_release_state'
  ) and c.relrowsecurity;

  select exists(
    select 1 from information_schema.table_privileges
    where table_schema='public' and table_name like 'aos_cia_email_%' and grantee='anon'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')
  ) into v_anon_direct;
  select exists(
    select 1 from information_schema.table_privileges
    where table_schema='public' and table_name like 'aos_cia_email_%' and grantee='authenticated'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')
