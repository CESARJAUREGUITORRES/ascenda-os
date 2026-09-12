\set ON_ERROR_STOP on
do $$
declare
  integ uuid := '8587b7fa-96cd-409c-b814-e7d2261cd0c8';
  conn uuid;
  op uuid := '11111111-1111-4111-8111-111111111111';
  wa uuid := '22222222-2222-4222-8222-222222222222';
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

  -- Legacy tables must never own external Google side-effect triggers.
  if exists(
    select 1 from pg_trigger
    where tgrelid in ('public.aos_agenda_citas'::regclass,'public.aos_pacientes'::regclass)
      and tgname like 'trg_aos_google_%' and not tgisinternal
  ) then raise exception 'LEGACY_TABLE_EXTERNAL_SIDE_EFFECT_TRIGGER_FORBIDDEN'; end if;

  -- Governed, browser-write-closed ledgers are the internal DB integration boundary.
  if not exists(select 1 from pg_trigger where tgrelid='public.aos_booking_operations_v2'::regclass and tgname='trg_aos_google_booking_operation_v1' and not tgisinternal) then
    raise exception 'BOOKING_OPERATION_GOOGLE_TRIGGER_MISSING';
  end if;
  if not exists(select 1 from pg_trigger where tgrelid='public.aos_wa4_booking_actions_v1'::regclass and tgname='trg_aos_google_wa4_booking_action_v1' and not tgisinternal) then
    raise exception 'WA4_BOOKING_GOOGLE_TRIGGER_MISSING';
  end if;

  if has_function_privilege('anon','public.aos_google_enqueue_authorized_appointment_v1(text,text,text)','execute')
     or has_function_privilege('authenticated','public.aos_google_enqueue_authorized_appointment_v1(text,text,text)','execute') then
    raise exception 'AUTHORIZED_ENQUEUE_BROWSER_EXPOSED';
  end if;
  if not has_function_privilege('service_role','public.aos_google_enqueue_authorized_appointment_v1(text,text,text)','execute') then
    raise exception 'AUTHORIZED_ENQUEUE_SERVICE_ROLE_DENIED';
  end if;

  insert into public.aos_google_connections_v1(
    integration_id,account_email,refresh_token_enc,is_primary,status,calendar_enabled,contacts_enabled
  ) values (
    integ,'canary@example.com','v1.synthetic.synthetic.synthetic',true,'CONNECTED',true,true
  ) returning id into conn;

  -- Direct legacy writes by themselves must remain inert.
  insert into public.aos_agenda_citas(
    id,fecha_cita,hora_cita,nombre,apellido,tratamiento,sede,correo,numero_limpio,estado_cita
  ) values (
    'appt-1','2026-09-20','10:00','Canary','Paciente','TOXINA','SAN ISIDRO','patient@example.com','999111222','PENDIENTE'
  );
  insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Teléfono","Email",numero_limpio,tratamiento_principal)
  values('P-1','Canary','Paciente','999111222','patient@example.com','999111222','TOXINA');
  select count(*) into c from public.aos_google_sync_outbox_v1;
  if c <> 0 then raise exception 'LEGACY_WRITES_MUST_NOT_AUTO_ENQUEUE:%',c; end if;

  -- Booking Core is authorized to enqueue after commit evidence exists.
  insert into public.aos_booking_operations_v2(
    id,idempotency_key,request_hash,operation_type,channel,actor_id,appointment_id,treatment_id,
    professional_ref,site,appointment_date,appointment_time,identity_state,status,response
  ) values (
    op,'ci-book-1','hash-book-1','BOOK','AGENDA',
    '33333333-3333-4333-8333-333333333333'::uuid,'appt-1',
    '44444444-4444-4444-8444-444444444444'::uuid,'CI-PROF','SAN ISIDRO',
    '2026-09-20'::date,'10:00'::time,'VERIFIED','BOOKED','{}'::jsonb
  );
  select count(*) into c from public.aos_google_sync_outbox_v1 where entity_id='appt-1' and action='CALENDAR_UPSERT';
  if c <> 1 then raise exception 'BOOKING_CORE_CALENDAR_INTENT_COUNT:%',c; end if;
  select count(*) into c from public.aos_google_sync_outbox_v1 where entity_id='appt-1' and action='CONTACT_UPSERT';
  if c <> 1 then raise exception 'BOOKING_CORE_CONTACT_INTENT_COUNT:%',c; end if;

  -- Legacy WA attribution ledger may describe the same governed booking; idempotency must collapse it.
  insert into public.aos_wa4_booking_actions_v1(
    id,idempotency_key,request_hash,conversation_id,actor_id,agenda_id,treatment_id,
    professional_id,site,appointment_date,appointment_time,identity_state,status
  ) values (
    wa,'ci-wa-book-1','hash-wa-book-1',
    '55555555-5555-4555-8555-555555555555'::uuid,
    '33333333-3333-4333-8333-333333333333'::uuid,
    'appt-1','44444444-4444-4444-8444-444444444444'::uuid,
    'CI-PROF','SAN ISIDRO','2026-09-20'::date,'10:00'::time,'VERIFIED','BOOKED'
  );
  select count(*) into c from public.aos_google_sync_outbox_v1 where entity_id='appt-1' and action='CALENDAR_UPSERT';
  if c <> 1 then raise exception 'DUPLICATE_GOVERNED_CALENDAR_INTENT:%',c; end if;
  select count(*) into c from public.aos_google_sync_outbox_v1 where entity_id='appt-1' and action='CONTACT_UPSERT';
  if c <> 1 then raise exception 'DUPLICATE_GOVERNED_CONTACT_INTENT:%',c; end if;

  -- Replaced/cancelled WA booking must generate a delete intent for the same appointment.
  update public.aos_wa4_booking_actions_v1 set status='REPLACED' where id=wa;
  select count(*) into c from public.aos_google_sync_outbox_v1 where entity_id='appt-1' and action='CALENDAR_DELETE';
  if c <> 1 then raise exception 'GOVERNED_CALENDAR_DELETE_INTENT_COUNT:%',c; end if;

  if not has_function_privilege('service_role','public.aos_google_claim_sync_v1(text,integer)','execute') then
    raise exception 'SERVICE_ROLE_CLAIM_DENIED';
  end if;
  if has_function_privilege('anon','public.aos_google_claim_sync_v1(text,integer)','execute')
     or has_function_privilege('authenticated','public.aos_google_claim_sync_v1(text,integer)','execute') then
    raise exception 'CLAIM_RPC_BROWSER_EXPOSED';
  end if;

  select count(*) into c from public.aos_google_claim_sync_v1('ci-worker',10);
  if c < 1 then raise exception 'CLAIM_RETURNED_NO_WORK'; end if;
end $$;

select 'GOOGLE_DB_CONTRACT=PASS' as result;
