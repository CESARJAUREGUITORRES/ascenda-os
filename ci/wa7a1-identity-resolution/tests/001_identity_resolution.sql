\set ON_ERROR_STOP on

truncate table public.aos_rev_patient_identity_alias_v2;
delete from public.aos_wa_channel_aliases_v1;
delete from public.aos_wa_messages_v1;
delete from public.aos_wa_conversations_v1;

insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_name,phone_number_id,state,opened_at,updated_at,
  contact_address,contact_address_type,contact_bsuid
) values
('10000000-0000-0000-0000-000000000001','phone-A:51911111111','51911111111','A','phone-A','NEW',now(),now(),'PE.ABC1','BSUID','PE.ABC1'),
('10000000-0000-0000-0000-000000000002','phone-A:BSUID:PE.ONLY',null,'B','phone-A','NEW',now(),now(),'PE.ONLY','BSUID','PE.ONLY'),
('10000000-0000-0000-0000-000000000003','phone-A:51922222222','51922222222','C','phone-A','NEW',now(),now(),'51922222222','PHONE',null),
('10000000-0000-0000-0000-000000000004','phone-A:51933333333','51933333333','D','phone-A','NEW',now(),now(),'51933333333','PHONE',null),
('10000000-0000-0000-0000-000000000005','phone-A:51955555555','51955555555','E','phone-A','NEW',now(),now(),'PE.HIGH1','BSUID','PE.HIGH1');

insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active) values
('phone-A','PHONE','51911111111','10000000-0000-0000-0000-000000000001',true),
('phone-A','BSUID','PE.ABC1','10000000-0000-0000-0000-000000000001',true),
('phone-A','BSUID','PE.ONLY','10000000-0000-0000-0000-000000000002',true),
('phone-A','PHONE','51922222222','10000000-0000-0000-0000-000000000003',true),
('phone-A','PHONE','51933333333','10000000-0000-0000-0000-000000000004',true),
('phone-A','PHONE','51944444444','10000000-0000-0000-0000-000000000004',true),
('phone-A','PHONE','51955555555','10000000-0000-0000-0000-000000000005',true),
('phone-A','BSUID','PE.HIGH1','10000000-0000-0000-0000-000000000005',true);

insert into public.aos_rev_patient_identity_alias_v2 values
('PHONE','911111111','P-1',1,'["CANONICAL_CURRENT"]',1,'RESOLVED','MEDIUM',false),
('PHONE','922222222','P-2A',1,'["CANONICAL_CURRENT"]',2,'CONFLICT','MEDIUM',false),
('PHONE','922222222','P-2B',1,'["CANONICAL_CURRENT"]',2,'CONFLICT','MEDIUM',false),
('PHONE','933333333','P-3',1,'["CANONICAL_CURRENT"]',1,'RESOLVED','MEDIUM',false),
('PHONE','944444444','P-4',1,'["CANONICAL_CURRENT"]',1,'RESOLVED','MEDIUM',false),
('PHONE','955555555','P-5',2,'["F5_REVIEWED_MATCH"]',1,'RESOLVED','HIGH',true);

-- PHONE + BSUID: canonical result comes from REV PHONE evidence, never BSUID itself.
do $$ declare r record; begin
  select * into r from public.aos_wa_identity_resolution_v1 where conversation_id='10000000-0000-0000-0000-000000000001';
  if r.resolution_status<>'MATCH' or r.canonical_patient_id<>'P-1' or r.canonical_candidate_count<>1 then raise exception 'WA7A1_PHONE_BSUID_MATCH_FAILED'; end if;
  if r.phone_alias_count<>1 or r.bsuid_alias_count<>1 or r.resolution_method<>'REV_PATIENT_IDENTITY_ALIAS_V2' then raise exception 'WA7A1_PHONE_BSUID_EVIDENCE_FAILED'; end if;
end $$;

-- Current transport may be BSUID-only while a historical PHONE alias remains on the conversation.
do $$ declare r record; begin
  select * into r from public.aos_wa_identity_resolution_v1 where conversation_id='10000000-0000-0000-0000-000000000001';
  if r.resolution_status<>'MATCH' or r.canonical_patient_id<>'P-1' then raise exception 'WA7A1_BSUID_CONTINUITY_FAILED'; end if;
end $$;

-- A genuinely BSUID-only conversation has no basis for canonical person resolution.
do $$ declare r record; begin
  select * into r from public.aos_wa_identity_resolution_v1 where conversation_id='10000000-0000-0000-0000-000000000002';
  if r.resolution_status<>'UNRESOLVED' or r.canonical_patient_id is not null or r.resolution_method<>'NO_PHONE_EVIDENCE' then raise exception 'WA7A1_PURE_BSUID_MUST_STAY_UNRESOLVED'; end if;
end $$;

-- REV conflict must remain fail-closed.
do $$ declare r record; begin
  select * into r from public.aos_wa_identity_resolution_v1 where conversation_id='10000000-0000-0000-0000-000000000003';
  if r.resolution_status<>'IDENTITY_CONFLICT' or r.canonical_patient_id is not null then raise exception 'WA7A1_REV_CONFLICT_NOT_CLOSED'; end if;
end $$;

-- Two individually resolved PHONE aliases pointing to different canonical patients are a conversation conflict.
do $$ declare r record; begin
  select * into r from public.aos_wa_identity_resolution_v1 where conversation_id='10000000-0000-0000-0000-000000000004';
  if r.resolution_status<>'IDENTITY_CONFLICT' or r.canonical_candidate_count<>2 or r.canonical_patient_id is not null then raise exception 'WA7A1_MULTI_ALIAS_CONFLICT_NOT_CLOSED'; end if;
end $$;

-- Reviewed REV evidence is surfaced as HIGH confidence without mutating REV.
do $$ declare r record; begin
  select * into r from public.aos_wa_identity_resolution_v1 where conversation_id='10000000-0000-0000-0000-000000000005';
  if r.resolution_status<>'MATCH' or r.canonical_patient_id<>'P-5' or r.confidence_band<>'HIGH' then raise exception 'WA7A1_REVIEWED_CONFIDENCE_FAILED'; end if;
end $$;

-- One resolution row per conversation: adding BSUID aliases cannot duplicate a canonical subject.
do $$ declare n integer; begin
  select count(*) into n from public.aos_wa_identity_resolution_v1 where conversation_id='10000000-0000-0000-0000-000000000001';
  if n<>1 then raise exception 'WA7A1_DUPLICATE_RESOLUTION_ROW'; end if;
end $$;

-- No raw channel address is exposed by the bridge view.
do $$ declare n integer; begin
  select count(*) into n from information_schema.columns
  where table_schema='public' and table_name='aos_wa_identity_resolution_v1'
    and column_name in ('alias_value','contact_number','contact_bsuid','contact_username','identifier_key');
  if n<>0 then raise exception 'WA7A1_RAW_ALIAS_EXPOSURE'; end if;
end $$;

-- Bridge remains private; RPC is the permissioned browser boundary.
do $$ begin
  if has_table_privilege('anon','public.aos_wa_identity_resolution_v1','SELECT') then raise exception 'WA7A1_ANON_VIEW_ACCESS'; end if;
  if has_table_privilege('authenticated','public.aos_wa_identity_resolution_v1','SELECT') then raise exception 'WA7A1_AUTH_VIEW_ACCESS'; end if;
  if to_regprocedure('public.aos_wa7a1_resolve_conversation_identity_v1(text,uuid)') is null then raise exception 'WA7A1_RPC_MISSING'; end if;
end $$;

select 'WA7A1_IDENTITY_RESOLUTION_PASS' as result;
