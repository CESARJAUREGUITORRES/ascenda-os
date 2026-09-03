\set ON_ERROR_STOP on

-- Exact synthetic IDs only. This file is never applied to PROD.
\set admin_id '11111111-1111-4111-8111-111111111111'
\set book_conv '55555555-5555-4555-8555-555555555551'
\set rebook_conv '55555555-5555-4555-8555-555555555552'
\set conflict_conv '55555555-5555-4555-8555-555555555553'

-- L5 must enter with L4 dormant.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_status_v1();
 if r->>'mode'<>'AUTO_OFF' or coalesce((r->>'kill_switch_engaged')::boolean,false) is not true or coalesce((r->>'effective_autonomous_send')::boolean,true) is true then
   raise exception 'L5_ENTRY_NOT_SAFE_OFF %',r;
 end if;
end $$;

-- Real availability comes only from AGV2 authority and exposes bounded options.
do $$ declare r jsonb; tid uuid; d date; begin
 select treatment_id,target_date into tid,d from public.aos_wa4c_booking_test_fixture where id=1;
 r:=public.aos_wa_l5_availability_v1(:'book_conv'::uuid,tid,'SAN ISIDRO',d,'wa4c-doctor-1','DOCTORA',3);
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'status'<>'REAL_AVAILABILITY_READY' then raise exception 'L5_AVAILABILITY %',r; end if;
 if jsonb_array_length(coalesce(r->'dates','[]'::jsonb))<1 then raise exception 'L5_AVAILABILITY_EMPTY %',r; end if;
 if (r->>'max_slots_per_date')::int<>5 then raise exception 'L5_AVAILABILITY_UNBOUNDED %',r; end if;
end $$;

-- BOOK prepare requires a real slot and explicit customer identity data only when unresolved.
do $$ declare r jsonb; tid uuid; d date; begin
 select treatment_id,target_date into tid,d from public.aos_wa4c_booking_test_fixture where id=1;
 r:=public.aos_wa_l5_prepare_confirmation_v1(:'book_conv'::uuid,'BOOK',tid,'SAN ISIDRO',d,'10:00'::time,'wa4c-doctor-1','DOCTORA',null,'CLIENTE','BOOK',600);
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'status'<>'AWAITING_CONFIRMATION' then raise exception 'L5_BOOK_PREPARE %',r; end if;
 if coalesce(r->>'confirmation_nonce','')='' then raise exception 'L5_BOOK_NONCE_MISSING %',r; end if;
end $$;

-- Confirmation must be a post-prepare inbound affirmative; arbitrary text is rejected.
insert into public.aos_wa_messages_v1(provider_message_id,conversation_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at)
values('wamid.l5.book.no',:'book_conv'::uuid,'INBOUND','51911111111','51999999999','local-phone-id','text','Todavía no','received',now(),now())
on conflict(provider_message_id) do nothing;

do $$ declare r jsonb; n uuid; begin
 select confirmation_nonce into n from public.aos_wa_l5_booking_memory_v1 where conversation_id=:'book_conv'::uuid;
 r:=public.aos_wa_l5_mark_explicit_confirmation_v1(:'book_conv'::uuid,n,'wamid.l5.book.no');
 if r->>'error'<>'WA_L5_EXPLICIT_CONFIRMATION_REQUIRED' then raise exception 'L5_NON_AFFIRMATIVE_ACCEPTED %',r; end if;
end $$;

insert into public.aos_wa_messages_v1(provider_message_id,conversation_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at)
values('wamid.l5.book.yes',:'book_conv'::uuid,'INBOUND','51911111111','51999999999','local-phone-id','text','Sí, confirmo','received',now(),now())
on conflict(provider_message_id) do nothing;

do $$ declare r jsonb; n uuid; begin
 select confirmation_nonce into n from public.aos_wa_l5_booking_memory_v1 where conversation_id=:'book_conv'::uuid;
 r:=public.aos_wa_l5_mark_explicit_confirmation_v1(:'book_conv'::uuid,n,'wamid.l5.book.yes');
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'status'<>'CONFIRMED' then raise exception 'L5_EXPLICIT_CONFIRMATION %',r; end if;
end $$;

-- AUTO_OFF is an absolute mutation barrier even after explicit confirmation.
do $$ declare r jsonb; n uuid; before_n bigint; after_n bigint; begin
 select count(*) into before_n from public.aos_agenda_citas;
 select confirmation_nonce into n from public.aos_wa_l5_booking_memory_v1 where conversation_id=:'book_conv'::uuid;
 r:=public.aos_wa_l5_commit_confirmed_v1(:'book_conv'::uuid,n,'wa-l5-book-idem-000001');
 if r->>'error'<>'WA_L5_AUTO_OFF' then raise exception 'L5_AUTO_OFF_NOT_BLOCKED %',r; end if;
 select count(*) into after_n from public.aos_agenda_citas;
 if after_n<>before_n then raise exception 'L5_AUTO_OFF_MUTATED_AGENDA before %, after %',before_n,after_n; end if;
end $$;

-- Identity conflict must hand off before any appointment mutation.
do $$ declare r jsonb; tid uuid; d date; begin
 select treatment_id,target_date into tid,d from public.aos_wa4c_booking_test_fixture where id=1;
 r:=public.aos_wa_l5_prepare_confirmation_v1(:'conflict_conv'::uuid,'BOOK',tid,'SAN ISIDRO',d,'11:00'::time,'wa4c-doctor-1','DOCTORA',null,'CONFLICT','TEST',600);
 if r->>'error'<>'WA_L5_IDENTITY_CONFLICT' or coalesce((r->>'requires_human')::boolean,false) is not true then raise exception 'L5_IDENTITY_CONFLICT_NOT_HANDOFF %',r; end if;
 if (select state from public.aos_wa_l5_booking_memory_v1 where conversation_id=:'conflict_conv'::uuid)<>'HANDOFF' then raise exception 'L5_IDENTITY_CONFLICT_STATE'; end if;
end $$;

-- REBOOK requires exact second-factor document verification and exposes only governed appointments.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l5_verify_patient_v1(:'rebook_conv'::uuid,'00000000');
 if r->>'error'<>'WA_L5_VERIFICATION_FAILED' then raise exception 'L5_BAD_DOCUMENT_ACCEPTED %',r; end if;
 r:=public.aos_wa_l5_verify_patient_v1(:'rebook_conv'::uuid,'12345678');
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'status'<>'VERIFIED' then raise exception 'L5_VERIFY %',r; end if;
 r:=public.aos_wa_l5_active_appointments_v1(:'rebook_conv'::uuid);
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L5_ACTIVE_APPOINTMENTS %',r; end if;
 if (r->>'candidate_count')::int<>1 then raise exception 'L5_APPOINTMENT_AMBIGUITY_EXPECTED_ONE %',r; end if;
end $$;

-- Local-only CANARY simulates the future authorization path. It is rolled back with the isolated DB.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_allowlist_set_v1(:'admin_id'::uuid,'PHONE','51911111111',true,null,'WA-L5 LOCAL BOOK');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L5_ALLOWLIST_BOOK %',r; end if;
 r:=public.aos_wa_l4_allowlist_set_v1(:'admin_id'::uuid,'PHONE','51933333333',true,null,'WA-L5 LOCAL REBOOK');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L5_ALLOWLIST_REBOOK %',r; end if;
 r:=public.aos_wa_l4_set_control_v1(:'admin_id'::uuid,'CANARY',false,50,12,60,10,0,0,'WA-L5-LOCAL-CANARY-ONLY');
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'mode'<>'CANARY' or coalesce((r->>'effective_autonomous_send')::boolean,false) is not true then raise exception 'L5_LOCAL_CANARY_CONTROL %',r; end if;
end $$;

-- BOOK now commits exactly once through AGV2.
do $$ declare r jsonb; n uuid; begin
 select confirmation_nonce into n from public.aos_wa_l5_booking_memory_v1 where conversation_id=:'book_conv'::uuid;
 r:=public.aos_wa_l5_commit_confirmed_v1(:'book_conv'::uuid,n,'wa-l5-book-idem-000001');
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'status'<>'BOOKED' then raise exception 'L5_BOOK_COMMIT %',r; end if;
 if (select state from public.aos_wa_l5_booking_memory_v1 where conversation_id=:'book_conv'::uuid)<>'COMMITTED' then raise exception 'L5_BOOK_MEMORY_NOT_COMMITTED'; end if;
 if (select count(*) from public.aos_booking_operations_v2 where idempotency_key='wa-l5-book-idem-000001' and operation_type='BOOK')<>1 then raise exception 'L5_BOOK_OPERATION_COUNT'; end if;
 if (select count(*) from public.aos_agenda_events_v2 where event_type='BOOKED')<1 then raise exception 'L5_BOOK_EVENT_MISSING'; end if;
end $$;

-- REBOOK keeps the same logical appointment id.
do $$ declare r jsonb; tid uuid; d date; n uuid; before_id text:='L5-REBOOK-APPT-1'; begin
 select treatment_id,target_date into tid,d from public.aos_wa4c_booking_test_fixture where id=1;
 r:=public.aos_wa_l5_prepare_confirmation_v1(:'rebook_conv'::uuid,'REBOOK',tid,'SAN ISIDRO',d,'11:00'::time,'wa4c-doctor-1','DOCTORA',before_id,null,null,600);
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'status'<>'AWAITING_CONFIRMATION' then raise exception 'L5_REBOOK_PREPARE %',r; end if;
 select confirmation_nonce into n from public.aos_wa_l5_booking_memory_v1 where conversation_id=:'rebook_conv'::uuid;
 insert into public.aos_wa_messages_v1(provider_message_id,conversation_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at)
 values('wamid.l5.rebook.yes',:'rebook_conv'::uuid,'INBOUND','51933333333','51999999999','local-phone-id','text','Confirmo','received',now(),now())
 on conflict(provider_message_id) do nothing;
 r:=public.aos_wa_l5_mark_explicit_confirmation_v1(:'rebook_conv'::uuid,n,'wamid.l5.rebook.yes');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L5_REBOOK_CONFIRM %',r; end if;
 r:=public.aos_wa_l5_commit_confirmed_v1(:'rebook_conv'::uuid,n,'wa-l5-rebook-idem-0001');
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'status'<>'REBOOKED' or r->>'appointment_id'<>before_id then raise exception 'L5_REBOOK_COMMIT %',r; end if;
 if (select count(*) from public.aos_agenda_citas where id=before_id)<>1 then raise exception 'L5_REBOOK_DUPLICATED_APPOINTMENT'; end if;
 if (select left(hora_cita,5) from public.aos_agenda_citas where id=before_id)<>'11:00' then raise exception 'L5_REBOOK_TIME_NOT_UPDATED'; end if;
 if (select count(*) from public.aos_booking_operations_v2 where idempotency_key='wa-l5-rebook-idem-0001' and operation_type='REBOOK')<>1 then raise exception 'L5_REBOOK_OPERATION_COUNT'; end if;
 if (select count(*) from public.aos_agenda_events_v2 where appointment_id=before_id and event_type='RESCHEDULED')<>1 then raise exception 'L5_REBOOK_EVENT_MISSING'; end if;
end $$;

-- Event ledger is sanitized and append-only.
do $$ begin
 if exists(select 1 from public.aos_wa_l5_booking_events_v1 where metadata ?| array['document','dni','email','message_body','raw_text','prompt','reply']) then raise exception 'L5_EVENT_PII_LEAK'; end if;
 if (select count(*) from public.aos_wa_l5_booking_events_v1 where event_type='COMMITTED')<>2 then raise exception 'L5_COMMIT_EVENT_COUNT'; end if;
end $$;

-- Return production controls to dormant state even inside isolated TEST before closeout.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1(:'admin_id'::uuid,'AUTO_OFF',true,null,null,null,null,null,null,null);
 if coalesce((r->>'ok')::boolean,false) is not true or r->>'mode'<>'AUTO_OFF' or coalesce((r->>'kill_switch_engaged')::boolean,false) is not true then raise exception 'L5_RETURN_SAFE_OFF %',r; end if;
end $$;

select 'WA_L5_BOOK_REBOOK_CONTRACT_PASS' as result;
