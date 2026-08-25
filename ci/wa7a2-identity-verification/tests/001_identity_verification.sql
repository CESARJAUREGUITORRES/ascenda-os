\set ON_ERROR_STOP on

-- Synthetic WA-7A.2 behavioral contract. No canonical patient mutation exists in this test path.
delete from public.aos_wa_events_v1;
delete from public.aos_wa_messages_v1;
delete from public.aos_wa_channel_aliases_v1;
delete from public.aos_wa_conversations_v1;

-- A. Signed PHONE+BSUID pair is one conversation and both facts become VERIFIED.
insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,from_user_id,from_parent_user_id,phone_number_id,message_type,status,provider_timestamp,received_at)
values('wamid.wa7a2.pair','INBOUND','51911111111','PE.PAIR.OLD','PE.ENT.PAIR.OLD','pn-wa7a2','text','received',now(),now());
insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values('identity:pair:wamid.wa7a2.pair','identity.meta_pair','wamid.wa7a2.pair','observed',jsonb_build_object('business_scope','pn-wa7a2','phone','51911111111','user_id','PE.PAIR.OLD','parent_user_id','PE.ENT.PAIR.OLD','observed_at',now()));

do $$ declare v uuid; n int; begin
  select conversation_id into v from public.aos_wa_messages_v1 where provider_message_id='wamid.wa7a2.pair';
  select count(*) into n from public.aos_wa_channel_aliases_v1 where conversation_id=v and active and verification_status='VERIFIED' and alias_type in ('PHONE','BSUID','PARENT_BSUID');
  if n<>3 then raise exception 'WA7A2_META_PAIR_NOT_VERIFIED'; end if;
  if (select status from public.aos_wa_events_v1 where event_key='identity:pair:wamid.wa7a2.pair')<>'VERIFIED' then raise exception 'WA7A2_META_PAIR_EVENT_NOT_VERIFIED'; end if;
end $$;

-- B. BSUID-only system rotation preserves conversation, explicitly supersedes old BSUID and retires stale phone.
insert into public.aos_wa_events_v1(event_key,event_type,status,payload)
values('identity:system:uid-1','identity.system_change','observed',jsonb_build_object(
  'business_scope','pn-wa7a2','system_type','user_changed_user_id','previous_user_id','PE.PAIR.OLD','user_id','PE.PAIR.NEW',
  'previous_parent_user_id','PE.ENT.PAIR.OLD','parent_user_id','PE.ENT.PAIR.NEW','observed_at',now()+interval '1 second'));

do $$ declare v uuid; old_id uuid; new_id uuid; begin
  select conversation_id into v from public.aos_wa_channel_aliases_v1 where business_scope='pn-wa7a2' and alias_type='BSUID' and alias_value='PE.PAIR.NEW';
  select id,superseded_by into old_id,new_id from public.aos_wa_channel_aliases_v1 where business_scope='pn-wa7a2' and alias_type='BSUID' and alias_value='PE.PAIR.OLD';
  if (select active from public.aos_wa_channel_aliases_v1 where id=old_id) then raise exception 'WA7A2_OLD_BSUID_STILL_ACTIVE'; end if;
  if new_id is null or new_id<>(select id from public.aos_wa_channel_aliases_v1 where business_scope='pn-wa7a2' and alias_type='BSUID' and alias_value='PE.PAIR.NEW') then raise exception 'WA7A2_BSUID_LINEAGE_MISSING'; end if;
  if exists(select 1 from public.aos_wa_channel_aliases_v1 where conversation_id=v and alias_type='PHONE' and active) then raise exception 'WA7A2_STALE_PHONE_STILL_ACTIVE'; end if;
  if not exists(select 1 from public.aos_wa_conversations_v1 where id=v and contact_number is null and contact_bsuid='PE.PAIR.NEW' and contact_address_type='BSUID') then raise exception 'WA7A2_BSUID_ONLY_PROJECTION_FAILED'; end if;
end $$;

-- Replay is idempotent: no second mutation/event.
insert into public.aos_wa_events_v1(event_key,event_type,status,payload)
values('identity:system:uid-1','identity.system_change','observed',jsonb_build_object('business_scope','pn-wa7a2','system_type','user_changed_user_id','previous_user_id','PE.PAIR.OLD','user_id','PE.PAIR.NEW'))
on conflict (event_key) do nothing;
do $$ begin
  if (select count(*) from public.aos_wa_events_v1 where event_key='identity:system:uid-1')<>1 then raise exception 'WA7A2_REPLAY_EVENT_DUPLICATED'; end if;
  if (select count(*) from public.aos_wa_channel_aliases_v1 where business_scope='pn-wa7a2' and alias_type='BSUID' and active)<>1 then raise exception 'WA7A2_REPLAY_ALIAS_DUPLICATED'; end if;
end $$;

-- C. Phone-visible system rotation supersedes old phone + BSUID, never creates another conversation.
insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,from_user_id,phone_number_id,message_type,status,provider_timestamp,received_at)
values('wamid.wa7a2.number.seed','INBOUND','51922222222','PE.NUM.OLD','pn-number','text','received',now(),now());
insert into public.aos_wa_events_v1(event_key,event_type,status,payload)
values('identity:pair:number.seed','identity.meta_pair','observed',jsonb_build_object('business_scope','pn-number','phone','51922222222','user_id','PE.NUM.OLD','observed_at',now()));
insert into public.aos_wa_events_v1(event_key,event_type,status,payload)
values('identity:system:number-1','identity.system_change','observed',jsonb_build_object('business_scope','pn-number','system_type','user_changed_number','previous_user_id','PE.NUM.OLD','user_id','PE.NUM.NEW','wa_id','51933333333','observed_at',now()+interval '1 second'));

do $$ declare v_old uuid; v_new uuid; begin
  select conversation_id into v_old from public.aos_wa_channel_aliases_v1 where business_scope='pn-number' and alias_type='BSUID' and alias_value='PE.NUM.OLD';
  select conversation_id into v_new from public.aos_wa_channel_aliases_v1 where business_scope='pn-number' and alias_type='BSUID' and alias_value='PE.NUM.NEW';
  if v_old is distinct from v_new then raise exception 'WA7A2_NUMBER_CHANGE_SPLIT_CONVERSATION'; end if;
  if exists(select 1 from public.aos_wa_channel_aliases_v1 where business_scope='pn-number' and alias_value in ('PE.NUM.OLD','51922222222') and active) then raise exception 'WA7A2_OLD_NUMBER_IDENTITY_STILL_ACTIVE'; end if;
  if not exists(select 1 from public.aos_wa_channel_aliases_v1 where business_scope='pn-number' and alias_type='PHONE' and alias_value='51933333333' and active and verification_status='VERIFIED' and verification_source='META_SYSTEM_CHANGE') then raise exception 'WA7A2_NEW_PHONE_NOT_VERIFIED'; end if;
end $$;

-- D. Native REQUEST_CONTACT_INFO response can verify/bind exactly one phone to an existing BSUID-only conversation.
insert into public.aos_wa_messages_v1(provider_message_id,direction,from_user_id,phone_number_id,message_type,status,provider_timestamp,received_at)
values('wamid.wa7a2.contact','INBOUND','PE.CONTACT.ONLY','pn-contact','contacts','received',now(),now());
insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values('identity:contact:wamid.wa7a2.contact:0','identity.contact_disclosure','wamid.wa7a2.contact','observed',jsonb_build_object('business_scope','pn-contact','origin','contact_request','sender_user_id','PE.CONTACT.ONLY','shared_phone','51944444444','shared_phone_count',1,'observed_at',now()));

do $$ declare v uuid; begin
  select conversation_id into v from public.aos_wa_channel_aliases_v1 where business_scope='pn-contact' and alias_type='BSUID' and alias_value='PE.CONTACT.ONLY';
  if not exists(select 1 from public.aos_wa_channel_aliases_v1 where conversation_id=v and alias_type='PHONE' and alias_value='51944444444' and active and verification_status='VERIFIED' and verification_source='META_CONTACT_REQUEST') then raise exception 'WA7A2_CONTACT_REQUEST_PHONE_NOT_VERIFIED'; end if;
end $$;

-- E. Forwarded/manual contact card is CLAIMED evidence only; it never becomes a routing/canonical alias.
insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values('identity:contact:other:0','identity.contact_disclosure','wamid.wa7a2.contact','observed',jsonb_build_object('business_scope','pn-contact','origin','other','sender_user_id','PE.CONTACT.ONLY','shared_phone','51945555555','shared_phone_count',1,'observed_at',now()));
do $$ begin
  if (select status from public.aos_wa_events_v1 where event_key='identity:contact:other:0')<>'CLAIMED' then raise exception 'WA7A2_OTHER_CONTACT_NOT_CLAIMED'; end if;
  if exists(select 1 from public.aos_wa_channel_aliases_v1 where business_scope='pn-contact' and alias_type='PHONE' and alias_value='51945555555') then raise exception 'WA7A2_CLAIMED_PHONE_POISONED_ALIAS_LEDGER'; end if;
end $$;

-- F. A verified disclosure cannot steal a phone already owned by another conversation.
insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,phone_number_id,message_type,status,provider_timestamp,received_at)
values('wamid.wa7a2.otherowner','INBOUND','51955555555','pn-contact','text','received',now(),now());
insert into public.aos_wa_events_v1(event_key,event_type,status,payload)
values('identity:contact:conflict:0','identity.contact_disclosure','observed',jsonb_build_object('business_scope','pn-contact','origin','contact_request','sender_user_id','PE.CONTACT.ONLY','shared_phone','51955555555','shared_phone_count',1,'observed_at',now()));
do $$ declare owner_conv uuid; begin
  if (select status from public.aos_wa_events_v1 where event_key='identity:contact:conflict:0')<>'CONFLICT' then raise exception 'WA7A2_PHONE_CONFLICT_NOT_CLOSED'; end if;
  select conversation_id into owner_conv from public.aos_wa_channel_aliases_v1 where business_scope='pn-contact' and alias_type='PHONE' and alias_value='51955555555';
  if owner_conv=(select conversation_id from public.aos_wa_channel_aliases_v1 where business_scope='pn-contact' and alias_type='BSUID' and alias_value='PE.CONTACT.ONLY') then raise exception 'WA7A2_CONFLICT_PHONE_WAS_STOLEN'; end if;
end $$;

-- G. recipient_user_id on delivered/read status can verify the BSUID that owns an already-bound outbound PHONE recipient.
insert into public.aos_wa_messages_v1(provider_message_id,conversation_id,direction,to_number,phone_number_id,message_type,message_body,status,received_at)
select 'wamid.wa7a2.status',conversation_id,'OUTBOUND','51944444444','pn-contact','text','reply','accepted',now()
from public.aos_wa_channel_aliases_v1 where business_scope='pn-contact' and alias_type='PHONE' and alias_value='51944444444';
insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values('identity:status:wamid.wa7a2.status:delivered:PE.STATUS.NEW','identity.status_binding','wamid.wa7a2.status','delivered',jsonb_build_object('business_scope','pn-contact','recipient_user_id','PE.STATUS.NEW','observed_at',now()));
do $$ declare v uuid; begin
  select conversation_id into v from public.aos_wa_messages_v1 where provider_message_id='wamid.wa7a2.status';
  if not exists(select 1 from public.aos_wa_channel_aliases_v1 where conversation_id=v and alias_type='BSUID' and alias_value='PE.STATUS.NEW' and verification_status='VERIFIED' and verification_source='META_STATUS_RECIPIENT_USER_ID') then raise exception 'WA7A2_STATUS_BSUID_NOT_VERIFIED'; end if;
  if not exists(select 1 from public.aos_wa_channel_aliases_v1 where conversation_id=v and alias_type='PHONE' and alias_value='51944444444' and verification_status='VERIFIED' and verification_source='META_STATUS_RECIPIENT_USER_ID') then raise exception 'WA7A2_STATUS_PHONE_NOT_VERIFIED'; end if;
end $$;

-- H. Username can exist on conversation/message display metadata but never in alias ledger authority.
do $$ begin
  if exists(select 1 from public.aos_wa_channel_aliases_v1 where alias_type not in ('PHONE','BSUID','PARENT_BSUID')) then raise exception 'WA7A2_USERNAME_ALIAS_FORBIDDEN'; end if;
end $$;

-- I. WA-7A.1 bridge remains derived from ACTIVE PHONE aliases only: BSUID-only rotation cannot retain stale canonical phone evidence.
insert into public.aos_rev_patient_identity_alias_v2(identifier_type,identifier_key,canonical_patient_id,evidence_rows,evidence_scopes,candidate_count,status,confidence_band,has_reviewed_match)
values('PHONE','911111111','P-STALE',1,'["CANONICAL_CURRENT"]',1,'RESOLVED','MEDIUM',false);
do $$ declare v uuid; r record; begin
  select conversation_id into v from public.aos_wa_channel_aliases_v1 where business_scope='pn-wa7a2' and alias_type='BSUID' and alias_value='PE.PAIR.NEW';
  select * into r from public.aos_wa_identity_resolution_v1 where conversation_id=v;
  if r.resolution_status<>'UNRESOLVED' or r.canonical_patient_id is not null or r.phone_alias_count<>0 then raise exception 'WA7A2_STALE_PHONE_LEAKED_TO_WA7A1'; end if;
end $$;

select 'WA7A2_IDENTITY_VERIFICATION_PASS' as result;
