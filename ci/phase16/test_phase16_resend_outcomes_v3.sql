-- CIA F16 Resend outcome coverage v3 synthetic tests.
-- Zero PII/PHI and zero provider network calls.

do $test$
declare
  j jsonb;
  v_tpl uuid;
  v_req uuid;
begin
  j := public.aos_cia_email_template_version_create_v1(
    '00000000-0000-0000-0000-000000000001','synthetic.marketing.outcomes-v3','MARKETING',
    'Outcome coverage','<p>Outcome coverage</p>',array[]::text[],null
  );
  if coalesce((j->>'ok')::boolean,false) is not true then raise exception 'F16_OUTCOME_V3_FAIL: template create %',j; end if;
  v_tpl := (j->>'template_version_id')::uuid;
  perform public.aos_cia_email_template_version_activate_v1('00000000-0000-0000-0000-000000000001',v_tpl);

  j := public.aos_cia_email_prepare_request_v2(
    '00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','synthetic-contact-1',v_tpl,'{}'::jsonb
  );
  if coalesce((j->>'ok')::boolean,false) is not true then raise exception 'F16_OUTCOME_V3_FAIL: prepare %',j; end if;
  v_req := (j->>'request_id')::uuid;

  perform public.aos_cia_email_queue_request_v2('00000000-0000-0000-0000-000000000001',v_req);
  j := public.aos_cia_email_claim_dispatch_v2(v_req);
  if coalesce((j->>'send_allowed')::boolean,false) is not true then raise exception 'F16_OUTCOME_V3_FAIL: failed-event dispatch claim %',j; end if;
  j := public.aos_cia_email_record_dispatch_result_v2(v_req,true,'RESEND','synthetic-provider-message-failed-v3',null,jsonb_build_object('synthetic',true));
  if j->>'state' <> 'ACCEPTED' then raise exception 'F16_OUTCOME_V3_FAIL: failed-event provider accept %',j; end if;

  j := public.aos_cia_email_ingest_provider_event_v2(
    'synthetic-event-failed-v3','synthetic-provider-message-failed-v3','email.failed',now(),jsonb_build_object('synthetic',true)
  );
  if j->>'state' <> 'FAILED' then raise exception 'F16_OUTCOME_V3_FAIL: email.failed transition %',j; end if;
  if coalesce((select global_suppressed from public.aos_cia_email_recipient_controls where contact_key='synthetic-contact-1'),false) is true then
    raise exception 'F16_OUTCOME_V3_FAIL: email.failed incorrectly globally suppressed recipient';
  end if;

  j := public.aos_cia_email_queue_request_v2('00000000-0000-0000-0000-000000000001',v_req);
  if j->>'state' <> 'QUEUED' then raise exception 'F16_OUTCOME_V3_FAIL: failed request not retryable %',j; end if;
  j := public.aos_cia_email_claim_dispatch_v2(v_req);
  if coalesce((j->>'send_allowed')::boolean,false) is not true then raise exception 'F16_OUTCOME_V3_FAIL: suppressed-event dispatch claim %',j; end if;
  j := public.aos_cia_email_record_dispatch_result_v2(v_req,true,'RESEND','synthetic-provider-message-suppressed-v3',null,jsonb_build_object('synthetic',true));
  if j->>'state' <> 'ACCEPTED' then raise exception 'F16_OUTCOME_V3_FAIL: suppressed-event provider accept %',j; end if;

  j := public.aos_cia_email_ingest_provider_event_v2(
    'synthetic-event-suppressed-v3','synthetic-provider-message-suppressed-v3','email.suppressed',now(),jsonb_build_object('synthetic',true)
  );
  if j->>'state' <> 'FAILED' then raise exception 'F16_OUTCOME_V3_FAIL: email.suppressed transition %',j; end if;
  if coalesce((select global_suppressed from public.aos_cia_email_recipient_controls where contact_key='synthetic-contact-1'),false) is not true then
    raise exception 'F16_OUTCOME_V3_FAIL: email.suppressed did not fail closed into recipient controls';
  end if;
  if coalesce((select suppression_reason from public.aos_cia_email_recipient_controls where contact_key='synthetic-contact-1'),'') <> 'RESEND_SUPPRESSED' then
    raise exception 'F16_OUTCOME_V3_FAIL: suppression reason not canonical';
  end if;

  j := public.aos_cia_email_ingest_provider_event_v2(
    'synthetic-event-suppressed-v3','synthetic-provider-message-suppressed-v3','email.suppressed',now(),jsonb_build_object('synthetic',true)
  );
  if coalesce((j->>'idempotent')::boolean,false) is not true then raise exception 'F16_OUTCOME_V3_FAIL: suppressed webhook replay not idempotent %',j; end if;

  j := public.aos_cia_email_ingest_provider_event_v2(
    'synthetic-event-unsupported-v3','synthetic-provider-message-suppressed-v3','email.received',now(),jsonb_build_object('synthetic',true)
  );
  if j->>'error' <> 'UNSUPPORTED_PROVIDER_EVENT' then raise exception 'F16_OUTCOME_V3_FAIL: unsupported event did not fail closed %',j; end if;

  update public.aos_cia_email_recipient_controls
     set global_suppressed=false,suppression_reason=null,source='SYNTHETIC_RESET',source_updated_at=now(),updated_by_user_id='00000000-0000-0000-0000-000000000001'
   where contact_key='synthetic-contact-1';
end
$test$;

select 'CIA_PHASE16_RESEND_OUTCOMES_V3=PASS' as result;
select 'PROVIDER_NETWORK_CALLS=0' as provider_policy;
