
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
  v_templates integer;
  v_requests integer;
  v_illegal integer;
begin
  v_f15 := public.aos_cia_kronia_f16_readiness_v1();
  select count(*)::integer into v_tables
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions','aos_cia_email_send_requests','aos_cia_email_send_events'
  ) and c.relkind='r';

  select count(*)::integer into v_rls
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions','aos_cia_email_send_requests','aos_cia_email_send_events'
  ) and c.relrowsecurity;

  v_anon_direct := has_table_privilege('anon','public.aos_cia_email_send_requests','SELECT')
                   or has_table_privilege('anon','public.aos_cia_email_send_requests','INSERT')
                   or has_table_privilege('anon','public.aos_cia_email_recipient_controls','SELECT');
  v_auth_direct := has_table_privilege('authenticated','public.aos_cia_email_send_requests','SELECT')
                   or has_table_privilege('authenticated','public.aos_cia_email_send_requests','INSERT')
                   or has_table_privilege('authenticated','public.aos_cia_email_recipient_controls','SELECT');

  select count(*)::integer into v_templates from public.aos_cia_email_template_versions where state='ACTIVE';
  select count(*)::integer into v_requests from public.aos_cia_email_send_requests;
  select count(*)::integer into v_illegal from public.aos_cia_email_send_requests where state <> 'PREPARED';

  return jsonb_build_object(
    'ok',coalesce((v_f15->>'ready_for_f16')::boolean,false) and v_tables=5 and v_rls=5 and not v_anon_direct and not v_auth_direct and v_illegal=0,
    'status','IN_PROGRESS_PREVIEW_ONLY',
    'mode','GOVERNED_EMAIL_SHADOW',
