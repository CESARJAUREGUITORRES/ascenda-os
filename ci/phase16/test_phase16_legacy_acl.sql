-- F16 synthetic legacy Email ACL closure tests.

do $test$
declare
  t text;
begin
  foreach t in array array[
    'aos_email_alertas','aos_email_audiencias','aos_email_cadencia','aos_email_campanias','aos_email_envios',
    'aos_email_eventos','aos_email_flujo_ejecuciones','aos_email_flujos','aos_email_plantillas',
    'aos_emails_empresa','aos_emails_enviados'
  ] loop
    if not (select c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=t) then
      raise exception 'F16_LEGACY_ACL_TEST_FAIL: RLS disabled on %',t;
    end if;
    if has_table_privilege('anon',format('public.%I',t),'SELECT')
       or has_table_privilege('anon',format('public.%I',t),'INSERT')
       or has_table_privilege('anon',format('public.%I',t),'UPDATE')
       or has_table_privilege('anon',format('public.%I',t),'DELETE')
       or has_table_privilege('authenticated',format('public.%I',t),'SELECT')
       or has_table_privilege('authenticated',format('public.%I',t),'INSERT')
       or has_table_privilege('authenticated',format('public.%I',t),'UPDATE')
       or has_table_privilege('authenticated',format('public.%I',t),'DELETE') then
      raise exception 'F16_LEGACY_ACL_TEST_FAIL: browser privilege remains on %',t;
    end if;
    if not has_table_privilege('service_role',format('public.%I',t),'SELECT')
       or not has_table_privilege('service_role',format('public.%I',t),'INSERT')
       or not has_table_privilege('service_role',format('public.%I',t),'UPDATE') then
      raise exception 'F16_LEGACY_ACL_TEST_FAIL: service role compatibility missing on %',t;
    end if;
  end loop;

  if has_function_privilege('anon','public.aos_email_buscar_paciente(text,integer)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_email_buscar_paciente(text,integer)','EXECUTE')
     or has_function_privilege('anon','public.aos_email_dashboard()','EXECUTE')
     or has_function_privilege('authenticated','public.aos_email_dashboard()','EXECUTE')
     or has_function_privilege('anon','public.aos_email_historial_paciente(text)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_email_historial_paciente(text)','EXECUTE') then
    raise exception 'F16_LEGACY_ACL_TEST_FAIL: legacy RPC browser execute remains';
  end if;

  if not has_function_privilege('service_role','public.aos_email_buscar_paciente(text,integer)','EXECUTE')
     or not has_function_privilege('service_role','public.aos_email_dashboard()','EXECUTE')
     or not has_function_privilege('service_role','public.aos_email_historial_paciente(text)','EXECUTE') then
    raise exception 'F16_LEGACY_ACL_TEST_FAIL: service role RPC compatibility missing';
  end if;
end
$test$;

select 'CIA_PHASE16_LEGACY_EMAIL_ACL=PASS' as result;
