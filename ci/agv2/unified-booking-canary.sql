-- TEST ONLY. Synthetic AGV2 BOOK/REBOOK canary. Never apply to PROD.
\set ON_ERROR_STOP on

-- Align synthetic provider with the fixture treatment under the CURRENT capability hierarchy.
update public.aos_perfiles_profesional p
set servicios=array[public.aos_booking_capability_for_service_v1(f.treatment_id)]::text[]
from public.aos_wa4c_booking_test_fixture f
where f.id=1 and p.id='wa4c-doctor-1';

insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_name,phone_number_id,state,box_id,owner_user_id,
  ownership_version,contact_address,contact_address_type,opened_at,updated_at
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid,
  'agv2-local:51933333333','51933333333','Cliente AGV2 QA','local-phone-id','AI_COPILOT',
  '77777777-7777-4777-8777-777777777777'::uuid,'44444444-4444-4444-8444-444444444444'::uuid,
  1,'51933333333','PHONE',now(),now()
) on conflict(id) do update set
  state='AI_COPILOT',owner_user_id='44444444-4444-4444-8444-444444444444'::uuid,
  box_id='77777777-7777-4777-8777-777777777777'::uuid,updated_at=now();

insert into public.aos_wa_assignments_v1(
  id,conversation_id,box_id,owner_user_id,state,assigned_at,claimed_at,assigned_by
) values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'::uuid,
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid,
  '77777777-7777-4777-8777-777777777777'::uuid,
  '44444444-4444-4444-8444-444444444444'::uuid,
  'ACTIVE',now(),now(),'11111111-1111-4111-8111-111111111111'::uuid
) on conflict(id) do update set state='ACTIVE',owner_user_id=excluded.owner_user_id,updated_at=now();

-- Conflict identity fixture.
insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_name,phone_number_id,state,box_id,owner_user_id,
  ownership_version,contact_address,contact_address_type,opened_at,updated_at
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'::uuid,
  'agv2-local:51922222222','51922222222','Cliente Conflict QA','local-phone-id','AI_COPILOT',
  '77777777-7777-4777-8777-777777777777'::uuid,'44444444-4444-4444-8444-444444444444'::uuid,
  1,'51922222222','PHONE',now(),now()
) on conflict(id) do update set state='AI_COPILOT',owner_user_id='44444444-4444-4444-8444-444444444444'::uuid,updated_at=now();

insert into public.aos_wa_assignments_v1(
  id,conversation_id,box_id,owner_user_id,state,assigned_at,claimed_at,assigned_by
) values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'::uuid,
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'::uuid,
  '77777777-7777-4777-8777-777777777777'::uuid,
  '44444444-4444-4444-8444-444444444444'::uuid,
  'ACTIVE',now(),now(),'11111111-1111-4111-8111-111111111111'::uuid
) on conflict(id) do update set state='ACTIVE',owner_user_id=excluded.owner_user_id,updated_at=now();

do $$
declare
  f public.aos_wa4c_booking_test_fixture%rowtype;
  r jsonb;
  replay jsonb;
  mismatch jsonb;
  rebook jsonb;
  conflict_r jsonb;
  not_owner jsonb;
  invalid_agenda jsonb;
  aid text;
  payload jsonb;
  p2 jsonb;
  n int;
begin
  select * into f from public.aos_wa4c_booking_test_fixture where id=1;
  if not found then raise exception 'AGV2_CANARY_FIXTURE_MISSING'; end if;

  payload:=jsonb_build_object(
    'treatment_id',f.treatment_id,
    'professional_id',f.professional_id,
    'slot_role','DOCTORA',
    'site','SAN_ISIDRO',
    'date',f.target_date,
    'time','10:00',
    'name','Cliente',
    'last_name','AGV2 QA',
    'appointment_type','CONSULTA NUEVA'
  );

  r:=public.aos_wa4_commit_booking_v2(
    '44444444-4444-4444-8444-444444444444'::uuid,
    'agv2-local-book-00000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid,
    payload
  );
  if coalesce((r->>'ok')::boolean,false) is not true or r->>'status'<>'BOOKED' then
    raise exception 'AGV2_CANARY_BOOK_FAILED %',r;
  end if;
  aid:=r->>'appointment_id';
  if coalesce(aid,'')='' then raise exception 'AGV2_CANARY_APPOINTMENT_ID_MISSING'; end if;

  replay:=public.aos_wa4_commit_booking_v2(
    '44444444-4444-4444-8444-444444444444'::uuid,
    'agv2-local-book-00000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid,
    payload
  );
  if coalesce((replay->>'idempotent_replay')::boolean,false) is not true or replay->>'appointment_id'<>aid then
    raise exception 'AGV2_CANARY_IDEMPOTENCY_REPLAY_FAILED %',replay;
  end if;

  mismatch:=public.aos_wa4_commit_booking_v2(
    '44444444-4444-4444-8444-444444444444'::uuid,
    'agv2-local-book-00000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid,
    jsonb_set(payload,'{time}','"11:30"'::jsonb)
  );
  if mismatch->>'error'<>'AGV2_IDEMPOTENCY_MISMATCH' then
    raise exception 'AGV2_CANARY_IDEMPOTENCY_MISMATCH_NOT_BLOCKED %',mismatch;
  end if;

  not_owner:=public.aos_wa4_commit_booking_v2(
    '11111111-1111-4111-8111-111111111111'::uuid,
    'agv2-local-book-not-owner',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid,
    jsonb_set(payload,'{time}','"11:30"'::jsonb)
  );
  if not_owner->>'error'<>'WA4_BOOKING_NOT_CONVERSATION_OWNER' then
    raise exception 'AGV2_CANARY_OWNERSHIP_NOT_BLOCKED %',not_owner;
  end if;

  conflict_r:=public.aos_wa4_commit_booking_v2(
    '44444444-4444-4444-8444-444444444444'::uuid,
    'agv2-local-book-conflict',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'::uuid,
    jsonb_set(payload,'{time}','"11:30"'::jsonb)
  );
  if conflict_r->>'error'<>'AGV2_IDENTITY_CONFLICT' then
    raise exception 'AGV2_CANARY_IDENTITY_CONFLICT_NOT_BLOCKED %',conflict_r;
  end if;

  p2:=jsonb_build_object(
    'site','SAN_ISIDRO','date',f.target_date,'time','10:30',
    'professional_id',f.professional_id,'slot_role','DOCTORA','reason','Cambio solicitado por QA'
  );
  rebook:=public.aos_wa4_rebook_booking_v2(
    '44444444-4444-4444-8444-444444444444'::uuid,
    'agv2-local-rebook-000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid,
    aid,p2
  );
  if coalesce((rebook->>'ok')::boolean,false) is not true or rebook->>'status'<>'REBOOKED' or rebook->>'appointment_id'<>aid then
    raise exception 'AGV2_CANARY_REBOOK_FAILED %',rebook;
  end if;

  select count(*) into n from public.aos_agenda_citas where id=aid;
  if n<>1 then raise exception 'AGV2_CANARY_REBOOK_DUPLICATED_APPOINTMENT %',n; end if;
  if not exists(select 1 from public.aos_agenda_citas where id=aid and left(hora_cita,5)='10:30' and estado_cita='PENDIENTE') then
    raise exception 'AGV2_CANARY_REBOOK_DID_NOT_MUTATE_SAME_APPOINTMENT';
  end if;
  select count(*) into n from public.aos_agenda_events_v2 where appointment_id=aid and event_type in ('BOOKED','RESCHEDULED');
  if n<>2 then raise exception 'AGV2_CANARY_EVENT_LEDGER_BAD_COUNT %',n; end if;
  select count(*) into n from public.aos_booking_operations_v2 where appointment_id=aid and operation_type in ('BOOK','REBOOK');
  if n<>2 then raise exception 'AGV2_CANARY_OPERATION_LEDGER_BAD_COUNT %',n; end if;
  if not exists(select 1 from public.aos_wa4_booking_actions_v1 where agenda_id=aid and status='BOOKED') then
    raise exception 'AGV2_CANARY_LEGACY_WA_LEDGER_NOT_PRESERVED';
  end if;

  begin
    update public.aos_agenda_events_v2 set reason='tamper' where appointment_id=aid;
    raise exception 'AGV2_CANARY_APPEND_ONLY_NOT_ENFORCED';
  exception when others then
    if sqlerrm not like '%AGV2_EVENT_LEDGER_APPEND_ONLY%' then raise; end if;
  end;

  invalid_agenda:=public.aos_agenda_commit_booking_v2('invalid-token','agv2-invalid-agenda-0001',payload||jsonb_build_object('phone','51944444444'));
  if invalid_agenda->>'error'<>'AGENDA_2FA_PANEL_REQUIRED' then
    raise exception 'AGV2_CANARY_AGENDA_STRONG_SESSION_NOT_ENFORCED %',invalid_agenda;
  end if;

  if to_regprocedure('public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb)') is null then
    raise exception 'AGV2_CANARY_WA_V1_COMPAT_REMOVED';
  end if;

  raise notice 'AGV2_UNIFIED_BOOKING_CANARY_PASS appointment_id=%',aid;
end
$$;

select 'AGV2_UNIFIED_BOOKING_CANARY_PASS' as result;
