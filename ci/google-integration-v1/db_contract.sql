\set ON_ERROR_STOP on
do $$
declare
  integ uuid := '8587b7fa-96cd-409c-b814-e7d2261cd0c8';
  conn uuid;
  c bigint;
begin
  if to_regclass('public.aos_google_connections_v1') is null then raise exception 'GOOGLE_CONNECTION_TABLE_MISSING'; end if;
  if to_regclass('public.aos_google_sync_outbox_v1') is null then raise exception 'GOOGLE_OUTBOX_TABLE_MISSING'; end if;

  if not (select relrowsecurity and relforcerowsecurity from pg_class where oid='public.aos_google_connections_v1'::regclass) then
    raise exception 'GOOGLE_CONNECTION_RLS_NOT_FORCED';
  end if;
  if has_table_privilege('anon','public.aos_google_connections_v1','select')
     or has_table_privilege('authenticated','public.aos_google_connections_v1','select') then
    raise exception 'GOOGLE_CONNECTION_BROWSER_READ_EXPOSED';
  end if;
  if has_table_privilege('anon','public.aos_google_sync_outbox_v1','insert')
     or has_table_privilege('authenticated','public.aos_google_sync_outbox_v1','insert') then
    raise exception 'GOOGLE_OUTBOX_BROWSER_WRITE_EXPOSED';
  end if;

  if exists(
    select 1 from pg_trigger
    where tgrelid in ('public.aos_agenda_citas'::regclass,'public.aos_pacientes'::regclass)
      and tgname like 'trg_aos_google_%' and not tgisinternal
  ) then raise exception 'LEGACY_TABLE_EXTERNAL_SIDE_EFFECT_TRIGGER_FORBIDDEN'; end if;

  insert into public.aos_google_connections_v1(
    integration_id,account_email,refresh_token_enc,is_primary,status,calendar_enabled,contacts_enabled
  ) values (
    integ,'canary@example.com','v1.synthetic.synthetic.synthetic',true,'CONNECTED',true,true
  ) returning id into conn;

  insert into public.aos_agenda_citas(
    id,fecha_cita,hora_cita,nombre,apellido,tratamiento,sede,correo,numero_limpio,estado_cita
  ) values (
    'appt-1','2026-09-20','10:00','Canary','Paciente','TOXINA','SAN ISIDRO','patient@example.com','999111222','PENDIENTE'
  );
  insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Teléfono","Email",numero_limpio,tratamiento_principal)
  values('P-1','Canary','Paciente','999111222','patient@example.com','999111222','TOXINA');

  select count(*) into c from public.aos_google_sync_outbox_v1;
  if c <> 0 then raise exception 'LEGACY_WRITES_MUST_NOT_AUTO_ENQUEUE:%',c; end if;

  insert into public.aos_google_calendar_links_v1(connection_id,appointment_id,calendar_id,event_id)
  values(conn,'appt-1','primary','synthetic-event');
  insert into public.aos_google_contact_links_v1(connection_id,patient_id,resource_name)
  values(conn,'P-1','people/synthetic');

  insert into public.aos_google_sync_outbox_v1(
    idempotency_key,connection_id,entity_type,entity_id,action,payload
  ) values (
    'ci:calendar:1',conn,'APPOINTMENT','appt-1','CALENDAR_UPSERT','{}'::jsonb
  );

  if not has_function_privilege('service_role','public.aos_google_claim_sync_v1(text,integer)','execute') then
    raise exception 'SERVICE_ROLE_CLAIM_DENIED';
  end if;
  if has_function_privilege('anon','public.aos_google_claim_sync_v1(text,integer)','execute')
     or has_function_privilege('authenticated','public.aos_google_claim_sync_v1(text,integer)','execute') then
    raise exception 'CLAIM_RPC_BROWSER_EXPOSED';
  end if;

  select count(*) into c from public.aos_google_claim_sync_v1('ci-worker',10);
  if c <> 1 then raise exception 'CLAIM_COUNT_INVALID:%',c; end if;
end $$;

select 'GOOGLE_DB_CONTRACT=PASS' as result;
