\set ON_ERROR_STOP on

-- WA-7A.4 isolated behavior contract.
set role postgres;

insert into public.aos_wa_conversations_v1(
  id,conversation_key,phone_number_id,contact_address,contact_address_type
) values (
  '71000000-0000-0000-0000-000000000001','pn-test:bsuid-user-1','pn-test','bsuid-user-1','BSUID'
);

-- 1. No routable alias -> fail closed as UNREACHABLE.
do $$
declare r record;
begin
  select * into r from public.aos_wa_marketing_eligibility_v1
   where conversation_id='71000000-0000-0000-0000-000000000001' and eligibility_scope='MARKETING';
  if r.reachability_status<>'UNREACHABLE' or r.eligibility_status<>'NOT_ELIGIBLE' or r.send_allowed then
    raise exception 'WA7A4_UNREACHABLE_FAIL_CLOSED_FAILED';
  end if;
end$$;

-- 2. BSUID alone is reachability, not consent.
insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,verification_status,verification_source)
values('pn-test','BSUID','bsuid-user-1','71000000-0000-0000-0000-000000000001','VERIFIED','SIGNED_PROVIDER');

do $$
declare r record;
begin
  select * into r from public.aos_wa_marketing_eligibility_v1
   where conversation_id='71000000-0000-0000-0000-000000000001' and eligibility_scope='MARKETING';
  if r.reachability_status<>'REACHABLE' or r.eligibility_status<>'UNKNOWN' or r.send_allowed then
    raise exception 'WA7A4_BSUID_MUST_NOT_GRANT_CONSENT';
  end if;
end$$;

-- 3. Attribution/CTWA evidence cannot grant consent.
do $$
begin
  begin
    perform public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
      'event_key','wa7a4:weak-source:1','conversation_id','71000000-0000-0000-0000-000000000001',
      'eligibility_scope','MARKETING','consent_status','ALLOWED','suppression_status','CLEAR',
      'source','CTWA','observed_at','2026-08-27T18:20:00Z','evidence',jsonb_build_object('ctwa_clid','x')
    ));
    raise exception 'WA7A4_WEAK_SOURCE_UNEXPECTEDLY_GRANTED';
  exception when sqlstate '42501' then
    if sqlerrm not like '%WA7A4_SOURCE_CANNOT_GRANT_CONSENT%' then raise; end if;
  end;
end$$;

-- 4. Explicit MARKETING opt-in makes a reachable BSUID conversation eligible.
select public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
  'event_key','wa7a4:marketing:allow:1','conversation_id','71000000-0000-0000-0000-000000000001',
  'eligibility_scope','MARKETING','consent_status','ALLOWED','suppression_status','CLEAR',
  'source','WEB_FORM_OPT_IN','source_ref','form:test','policy_version','WA_7A_4_V1',
  'observed_at','2026-08-27T18:21:00Z','evidence',jsonb_build_object('explicit_opt_in',true,'categories',jsonb_build_array('MARKETING'))
));

do $$
declare r record;
begin
  select * into r from public.aos_wa_marketing_eligibility_v1
   where conversation_id='71000000-0000-0000-0000-000000000001' and eligibility_scope='MARKETING';
  if r.consent_status<>'ALLOWED' or r.suppression_status<>'CLEAR' or r.eligibility_status<>'ELIGIBLE' or not r.send_allowed then
    raise exception 'WA7A4_EXPLICIT_MARKETING_OPTIN_FAILED';
  end if;
end$$;

-- 5. MARKETING consent never grants CALL consent.
do $$
declare r record;
begin
  select * into r from public.aos_wa_marketing_eligibility_v1
   where conversation_id='71000000-0000-0000-0000-000000000001' and eligibility_scope='CALL';
  if r.eligibility_status<>'UNKNOWN' or r.send_allowed then raise exception 'WA7A4_SCOPE_SEPARATION_FAILED'; end if;
end$$;

-- 6. Exact replay is idempotent; same key with changed evidence is a conflict.
do $$
declare r jsonb;
begin
  r := public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
    'event_key','wa7a4:marketing:allow:1','conversation_id','71000000-0000-0000-0000-000000000001',
    'eligibility_scope','MARKETING','consent_status','ALLOWED','suppression_status','CLEAR',
    'source','WEB_FORM_OPT_IN','source_ref','form:test','policy_version','WA_7A_4_V1',
    'observed_at','2026-08-27T18:21:00Z','evidence',jsonb_build_object('explicit_opt_in',true,'categories',jsonb_build_array('MARKETING'))
  ));
  if coalesce((r->>'idempotent')::boolean,false) is not true then raise exception 'WA7A4_REPLAY_NOT_IDEMPOTENT'; end if;
  begin
    perform public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
      'event_key','wa7a4:marketing:allow:1','conversation_id','71000000-0000-0000-0000-000000000001',
      'eligibility_scope','MARKETING','consent_status','DENIED','suppression_status','SUPPRESSED',
      'source','USER_OPT_OUT','observed_at','2026-08-27T18:22:00Z','evidence',jsonb_build_object('opt_out',true)
    ));
    raise exception 'WA7A4_REPLAY_CONFLICT_NOT_BLOCKED';
  exception when unique_violation then null;
  end;
end$$;

-- 7. Opt-out immediately wins.
select public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
  'event_key','wa7a4:marketing:deny:1','conversation_id','71000000-0000-0000-0000-000000000001',
  'eligibility_scope','MARKETING','consent_status','DENIED','suppression_status','SUPPRESSED',
  'source','USER_OPT_OUT','observed_at','2026-08-27T18:23:00Z','evidence',jsonb_build_object('explicit_opt_out',true)
));

do $$
declare r record;
begin
  select * into r from public.aos_wa_marketing_eligibility_v1
   where conversation_id='71000000-0000-0000-0000-000000000001' and eligibility_scope='MARKETING';
  if r.eligibility_status<>'NOT_ELIGIBLE' or r.reason_code<>'WA_SUPPRESSED' or r.send_allowed then raise exception 'WA7A4_OPTOUT_DID_NOT_WIN'; end if;
end$$;

-- 8. Silent reversal is forbidden; explicit re-consent is allowed.
do $$
begin
  begin
    perform public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
      'event_key','wa7a4:marketing:reallow:no-proof','conversation_id','71000000-0000-0000-0000-000000000001',
      'eligibility_scope','MARKETING','consent_status','ALLOWED','suppression_status','CLEAR',
      'source','WEB_FORM_OPT_IN','observed_at','2026-08-27T18:24:00Z','evidence','{}'::jsonb
    ));
    raise exception 'WA7A4_SILENT_REVERSAL_NOT_BLOCKED';
  exception when sqlstate '42501' then
    if sqlerrm not like '%WA7A4_EXPLICIT_RECONSENT_REQUIRED%' then raise; end if;
  end;
end$$;

select public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
  'event_key','wa7a4:marketing:reallow:1','conversation_id','71000000-0000-0000-0000-000000000001',
  'eligibility_scope','MARKETING','consent_status','ALLOWED','suppression_status','CLEAR',
  'source','WEB_FORM_OPT_IN','observed_at','2026-08-27T18:25:00Z',
  'evidence',jsonb_build_object('explicit_reconsent',true,'explicit_opt_in',true)
));

-- 9. Existing CIA-F17 suppression is a blocker, never a grant.
insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,verification_status,verification_source)
values('pn-test','PHONE','51987654321','71000000-0000-0000-0000-000000000001','VERIFIED','SIGNED_PROVIDER');
insert into public.aos_cia_channel_recipient_controls_v1(contact_key,channel,consent_status,suppression_status,source,evidence)
values('987654321','WHATSAPP','UNKNOWN','SUPPRESSED','CIA_TEST',jsonb_build_object('reason','legacy suppression'));

do $$
declare r record;
begin
  select * into r from public.aos_wa_marketing_eligibility_v1
   where conversation_id='71000000-0000-0000-0000-000000000001' and eligibility_scope='MARKETING';
  if r.eligibility_status<>'NOT_ELIGIBLE' or r.reason_code<>'CIA_SUPPRESSED' or r.send_allowed then raise exception 'WA7A4_CIA_SUPPRESSION_FAILED'; end if;
end$$;

delete from public.aos_cia_channel_recipient_controls_v1 where contact_key='987654321' and channel='WHATSAPP';

-- CIA ALLOWED alone must never grant a scope with no WA explicit consent.
insert into public.aos_cia_channel_recipient_controls_v1(contact_key,channel,consent_status,suppression_status,source,evidence)
values('987654321','WHATSAPP','ALLOWED','CLEAR','CIA_TEST',jsonb_build_object('legacy',true));
do $$
declare r record;
begin
  select * into r from public.aos_wa_marketing_eligibility_v1
   where conversation_id='71000000-0000-0000-0000-000000000001' and eligibility_scope='CALL';
  if r.eligibility_status<>'UNKNOWN' or r.send_allowed then raise exception 'WA7A4_CIA_MUST_NOT_GRANT_CONSENT'; end if;
end$$;

-- 10. GLOBAL denial overrides category opt-in.
select public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
  'event_key','wa7a4:global:deny:1','conversation_id','71000000-0000-0000-0000-000000000001',
  'eligibility_scope','GLOBAL','consent_status','DENIED','suppression_status','SUPPRESSED',
  'source','GLOBAL_OPT_OUT','observed_at','2026-08-27T18:26:00Z','evidence',jsonb_build_object('explicit_opt_out',true)
));
do $$
declare r record;
begin
  select * into r from public.aos_wa_marketing_eligibility_v1
   where conversation_id='71000000-0000-0000-0000-000000000001' and eligibility_scope='MARKETING';
  if r.reason_code<>'WA_SUPPRESSED' or r.send_allowed then raise exception 'WA7A4_GLOBAL_SUPPRESSION_FAILED'; end if;
end$$;

-- 11. Evidence is immutable even to service_role/runtime.
do $$
begin
  begin
    update public.aos_wa_marketing_eligibility_events_v1 set source='MUTATED' where event_key='wa7a4:marketing:allow:1';
    raise exception 'WA7A4_UPDATE_NOT_BLOCKED';
  exception when sqlstate '55000' then null;
  end;
  begin
    delete from public.aos_wa_marketing_eligibility_events_v1 where event_key='wa7a4:marketing:allow:1';
    raise exception 'WA7A4_DELETE_NOT_BLOCKED';
  exception when sqlstate '55000' then null;
  end;
end$$;

-- 12. ACL boundary.
do $$
begin
  if has_table_privilege('anon','public.aos_wa_marketing_eligibility_events_v1','SELECT') then raise exception 'WA7A4_ANON_EVENT_READ'; end if;
  if has_table_privilege('authenticated','public.aos_wa_marketing_eligibility_v1','SELECT') then raise exception 'WA7A4_AUTH_VIEW_READ'; end if;
  if not has_table_privilege('service_role','public.aos_wa_marketing_eligibility_events_v1','SELECT') then raise exception 'WA7A4_SERVICE_EVENT_READ_MISSING'; end if;
  if has_table_privilege('service_role','public.aos_wa_marketing_eligibility_events_v1','UPDATE') then raise exception 'WA7A4_SERVICE_UPDATE_PRESENT'; end if;
  if has_function_privilege('anon','public.aos_wa_marketing_eligibility_record_v1(jsonb)','EXECUTE') then raise exception 'WA7A4_ANON_RECORD_EXECUTE'; end if;
end$$;

-- 13. Service check returns fail-closed global result.
do $$
declare r jsonb;
begin
  r := public.aos_wa_marketing_eligibility_check_v1('71000000-0000-0000-0000-000000000001','MARKETING');
  if coalesce((r->>'send_allowed')::boolean,true) is not false then raise exception 'WA7A4_CHECK_NOT_FAIL_CLOSED'; end if;
end$$;

select 'WA7A4_MARKETING_ELIGIBILITY_PASS' as result;
