-- WA-AUTO L3 · TEST ONLY
-- Proves event projection, idempotency, reminder materialization, rebook supersession and dormant boundary.

begin;

do $$
declare
  v_actor uuid:='00000000-0000-0000-0000-00000000c303'::uuid;
  v_treatment uuid;
  v_op1 uuid:=gen_random_uuid();
  v_op2 uuid:=gen_random_uuid();
  v_op3 uuid:=gen_random_uuid();
  v_e1 uuid;
  v_e2 uuid;
  v_e3 uuid;
  v_appt text:='agv2-l3-canary-primary';
  v_appt_bad text:='agv2-l3-canary-malformed-email';
  v_date date:=current_date+3;
  v_new_date date:=current_date+5;
  v_n integer;
  v_r jsonb;
begin
  select treatment_id into v_treatment from public.aos_wa4c_booking_test_fixture where id=1;
  if v_treatment is null then raise exception 'L3_CANARY_TREATMENT_FIXTURE_MISSING'; end if;

  insert into public.aos_agenda_citas(
    id,fecha_cita,tratamiento,tipo_cita,sede,numero,nombre,apellido,correo,asesor,id_asesor,
    estado_cita,hora_cita,doctora,tipo_atencion,origen_cita,numero_limpio,origen
  ) values (
    v_appt,v_date,'L3 TEST SERVICE','CONSULTA NUEVA','SAN ISIDRO','51911111111','Paciente','L3',
    'l3.canary@example.test','TEST','TEST','PENDIENTE','10:00','DRA. TEST','DOCTORA','AGENDA_V2','51911111111','AGENDA_INTERNAL'
  );

  insert into public.aos_booking_operations_v2(
    id,idempotency_key,request_hash,operation_type,channel,actor_id,appointment_id,treatment_id,
    professional_ref,site,appointment_date,appointment_time,identity_state,status,response
  ) values (
    v_op1,'agv2-l3-canary-book-0001',repeat('a',64),'BOOK','AGENDA',v_actor,v_appt,v_treatment,
    'wa4c-doctor-1','SAN ISIDRO',v_date,'10:00','UNRESOLVED','BOOKED','{}'::jsonb
  );

  insert into public.aos_agenda_events_v2(
    operation_id,appointment_id,event_type,actor_id,channel,before_snapshot,after_snapshot
  ) values (
    v_op1,v_appt,'BOOKED',v_actor,'AGENDA',null,jsonb_build_object('appointment_id',v_appt,'date',v_date,'time','10:00')
  ) returning id into v_e1;

  select count(*) into v_n from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e1;
  if v_n<>2 then raise exception 'L3_BOOK_CONFIRMATION_INTENTS_EXPECTED_2:%',v_n; end if;
  if exists(select 1 from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e1 and state<>'DORMANT') then
    raise exception 'L3_BOOK_INTENT_NOT_DORMANT';
  end if;
  if not exists(select 1 from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e1 and channel='EMAIL' and provider='RESEND' and provider_template_verified=true and template_key='confirmacion_cita') then
    raise exception 'L3_EMAIL_CONFIRMATION_CONTRACT_MISSING';
  end if;
  if not exists(select 1 from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e1 and channel='WHATSAPP' and provider='META_CLOUD_API' and provider_template_verified=false and template_key='cita_confirmada' and blocking_reason like '%PROVIDER_TEMPLATE_APPROVAL_UNVERIFIED%') then
    raise exception 'L3_WA_CONFIRMATION_FAIL_CLOSED_MISSING';
  end if;

  -- Replaying projection/reconciliation never duplicates the event delivery intents.
  perform public.aos_agenda_delivery_enqueue_event_v3(v_e1);
  perform public.aos_agenda_delivery_reconcile_v3(100);
  select count(*) into v_n from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e1 and delivery_kind='CONFIRMATION';
  if v_n<>2 then raise exception 'L3_CONFIRMATION_IDEMPOTENCY_FAILED:%',v_n; end if;

  -- Day-before reminder materializes exactly once per channel for the current revision.
  v_r:=public.aos_agenda_delivery_materialize_reminders_v3(((v_date-1)::timestamp + time '12:00') at time zone 'America/Lima',100);
  v_r:=public.aos_agenda_delivery_materialize_reminders_v3(((v_date-1)::timestamp + time '12:05') at time zone 'America/Lima',100);
  select count(*) into v_n from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e1 and delivery_kind='REMINDER_TOMORROW';
  if v_n<>2 then raise exception 'L3_TOMORROW_REMINDER_IDEMPOTENCY_FAILED:%',v_n; end if;
  if not exists(select 1 from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e1 and delivery_kind='REMINDER_TOMORROW' and channel='WHATSAPP' and template_key='recordatorio_manana_si') then
    raise exception 'L3_TOMORROW_SITE_TEMPLATE_FAILED';
  end if;

  -- REBOOK creates a new revision and supersedes every still-unsent old-revision intent.
  update public.aos_agenda_citas
     set fecha_cita=v_new_date,hora_cita='11:00',ts_actualizado=now()
   where id=v_appt;
  insert into public.aos_booking_operations_v2(
    id,idempotency_key,request_hash,operation_type,channel,actor_id,appointment_id,treatment_id,
    professional_ref,site,appointment_date,appointment_time,identity_state,status,response
  ) values (
    v_op2,'agv2-l3-canary-rebook-0001',repeat('b',64),'REBOOK','AGENDA',v_actor,v_appt,v_treatment,
    'wa4c-doctor-1','SAN ISIDRO',v_new_date,'11:00','UNRESOLVED','REBOOKED','{}'::jsonb
  );
  insert into public.aos_agenda_events_v2(
    operation_id,appointment_id,event_type,actor_id,channel,reason,before_snapshot,after_snapshot
  ) values (
    v_op2,v_appt,'RESCHEDULED',v_actor,'AGENDA','L3 canary rebook',
    jsonb_build_object('date',v_date,'time','10:00'),jsonb_build_object('date',v_new_date,'time','11:00')
  ) returning id into v_e2;

  select count(*) into v_n from public.aos_agenda_delivery_outbox_v3 where appointment_id=v_appt and schedule_revision=v_e1::text and state='SUPERSEDED';
  if v_n<>4 then raise exception 'L3_REBOOK_SUPERSESSION_EXPECTED_4:%',v_n; end if;
  select count(*) into v_n from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e2 and delivery_kind='REPROGRAMMATION' and state='DORMANT';
  if v_n<>2 then raise exception 'L3_REPROGRAM_INTENTS_EXPECTED_2:%',v_n; end if;

  -- New schedule gets its own day-before and same-day reminder revisions.
  perform public.aos_agenda_delivery_materialize_reminders_v3(((v_new_date-1)::timestamp + time '12:00') at time zone 'America/Lima',100);
  perform public.aos_agenda_delivery_materialize_reminders_v3((v_new_date::timestamp + time '08:00') at time zone 'America/Lima',100);
  select count(*) into v_n from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e2 and delivery_kind in ('REMINDER_TOMORROW','REMINDER_TODAY');
  if v_n<>4 then raise exception 'L3_NEW_REVISION_REMINDERS_EXPECTED_4:%',v_n; end if;
  if not exists(select 1 from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e2 and delivery_kind='REMINDER_TODAY' and channel='WHATSAPP' and template_key='recordatorio_hoy_si') then
    raise exception 'L3_TODAY_SITE_TEMPLATE_FAILED';
  end if;

  -- Malformed legacy email data never rolls back the event; only the valid phone intent is projected.
  insert into public.aos_agenda_citas(
    id,fecha_cita,tratamiento,tipo_cita,sede,numero,nombre,apellido,correo,asesor,id_asesor,
    estado_cita,hora_cita,doctora,tipo_atencion,origen_cita,numero_limpio,origen
  ) values (
    v_appt_bad,v_date,'L3 TEST SERVICE','CONSULTA NUEVA','PUEBLO LIBRE','51933333333','Paciente','BadMail',
    'correo-invalido','TEST','TEST','PENDIENTE','14:00','DRA. TEST','DOCTORA','AGENDA_V2','51933333333','AGENDA_INTERNAL'
  );
  insert into public.aos_booking_operations_v2(
    id,idempotency_key,request_hash,operation_type,channel,actor_id,appointment_id,treatment_id,
    professional_ref,site,appointment_date,appointment_time,identity_state,status,response
  ) values (
    v_op3,'agv2-l3-canary-book-0002',repeat('c',64),'BOOK','AGENDA',v_actor,v_appt_bad,v_treatment,
    'wa4c-doctor-1','PUEBLO LIBRE',v_date,'14:00','UNRESOLVED','BOOKED','{}'::jsonb
  );
  insert into public.aos_agenda_events_v2(
    operation_id,appointment_id,event_type,actor_id,channel,before_snapshot,after_snapshot
  ) values (
    v_op3,v_appt_bad,'BOOKED',v_actor,'AGENDA',null,jsonb_build_object('appointment_id',v_appt_bad)
  ) returning id into v_e3;
  if not exists(select 1 from public.aos_agenda_events_v2 where id=v_e3) then raise exception 'L3_FAIL_SOFT_EVENT_ROLLED_BACK'; end if;
  select count(*) into v_n from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e3;
  if v_n<>1 then raise exception 'L3_MALFORMED_EMAIL_EXPECTED_WA_ONLY:%',v_n; end if;
  if not exists(select 1 from public.aos_agenda_delivery_outbox_v3 where agenda_event_id=v_e3 and channel='WHATSAPP') then
    raise exception 'L3_MALFORMED_EMAIL_WA_INTENT_MISSING';
  end if;

  if exists(select 1 from public.aos_agenda_delivery_outbox_v3 where state in ('READY','CLAIMED','ACCEPTED')) then
    raise exception 'L3_AUTONOMOUS_DISPATCH_MUST_REMAIN_OFF';
  end if;
  if exists(select idempotency_key from public.aos_agenda_delivery_outbox_v3 group by idempotency_key having count(*)>1) then
    raise exception 'L3_DUPLICATE_IDEMPOTENCY_KEYS';
  end if;
end
$$;

select 'AGV2_L3_DELIVERY_OUTBOX_CANARY_PASS' as result;

rollback;
