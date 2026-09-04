\set ON_ERROR_STOP on

do $$
declare
  r jsonb;
  v_hash text;
begin
  insert into public.aos_wa_conversations_v1(
    id,conversation_key,contact_number,phone_number_id,state,opened_at,updated_at,
    box_id,owner_user_id,human_takeover_at,handoff_requested_at,contact_address,contact_address_type
  ) values (
    '66666666-6666-4666-8666-666666666661','L10TEST:51911111111','51911111111','L10TEST','AI_COPILOT',now(),now(),
    '77777777-7777-4777-8777-777777777777','44444444-4444-4444-8444-444444444444',now(),now(),'51911111111','PHONE'
  ) on conflict(id) do nothing;

  insert into public.aos_wa_assignments_v1(
    id,conversation_id,box_id,owner_user_id,state,assigned_by,claimed_at
  ) values (
    '66666666-6666-4666-8666-666666666662','66666666-6666-4666-8666-666666666661',
    '77777777-7777-4777-8777-777777777777','44444444-4444-4444-8444-444444444444','ACTIVE',
    '11111111-1111-4111-8111-111111111111',now()
  ) on conflict(id) do nothing;

  r:=public.aos_wa_l10_prepare_run_v1(
    '11111111-1111-4111-8111-111111111111','CI-L10-BRIDGE-RUN-0001',
    '{"agenda":0,"llamadas":0,"leads":0,"ventas":0,"pacientes":0,"wa_events":0,"wa_messages":0,"wa_l6_journeys":0,"wa_l9_demo_runs":0,"active_allowlist":0,"wa_auto_outbound":0,"wa_auto_decisions":0,"wa_l5_booking_events":0,"wa_l7_ai_cost_events":0,"wa_outbound_requests":0,"wa_l7_meta_cost_events":0,"wa_l9_provider_dispatch":0}'::jsonb,
    'VERIFIED_CURRENT','CI_POLICY_20260904','VERIFIED_CURRENT','CI_PROVIDER_20260904',
    'UNKNOWN','CI_TEMPLATE_SERVICE_WINDOW','UNKNOWN','CI_BILLING_UNKNOWN',
    'UNKNOWN','CI_SERVICE_WINDOW','EXACT_CONVERSATION'
  );
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L10_PREP %',r; end if;
  if coalesce((r->>'activation_authorized')::boolean,true) is not false then raise exception 'L10_PREP_MUST_NOT_ACTIVATE %',r; end if;

  v_hash:=encode(extensions.digest(convert_to('PHONE:51911111111','UTF8'),'sha256'),'hex');
  r:=public.aos_wa_l10_attach_scope_v1(
    '11111111-1111-4111-8111-111111111111','CI-L10-BRIDGE-RUN-0001',
    '66666666-6666-4666-8666-666666666661',v_hash,'CI_EXACT_CONVERSATION'
  );
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L10_SCOPE %',r; end if;

  r:=public.aos_wa_l4_allowlist_set_v1(
    '11111111-1111-4111-8111-111111111111','CONVERSATION','66666666-6666-4666-8666-666666666661',true,now()+interval '2 hours','CI_L10_BRIDGE'
  );
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L10_ALLOWLIST %',r; end if;

  r:=public.aos_wa_l4_set_control_v1(
    '11111111-1111-4111-8111-111111111111','CANARY',false,12,6,3,1,10,120,'CI-OWNER-AUTH-L10-BRIDGE-0001'
  );
  if coalesce((r->>'ok')::boolean,false) is not true or r->>'mode'<>'CANARY' then raise exception 'L10_CANARY %',r; end if;

  r:=public.aos_wa_l10_return_to_autonomous_canary_v1(
    '11111111-1111-4111-8111-111111111111','CI-L10-BRIDGE-RUN-0001',
    '66666666-6666-4666-8666-666666666661','CI_OWNER_AUTH_CANARY'
  );
  if coalesce((r->>'ok')::boolean,false) is not true or r->>'state'<>'AI_ACTIVE' then raise exception 'L10_RETURN %',r; end if;
end
$$;

-- Human ownership was released, never deleted, and the transition is audited.
do $$ begin
  if not exists(select 1 from public.aos_wa_assignments_v1 where id='66666666-6666-4666-8666-666666666662' and state='RELEASED' and terminal_reason='L10_AUTONOMOUS_RETURN') then raise exception 'L10_ASSIGNMENT_HISTORY_NOT_PRESERVED'; end if;
  if not exists(select 1 from public.aos_wa_conversations_v1 where id='66666666-6666-4666-8666-666666666661' and state='AI_ACTIVE' and owner_user_id is null and human_takeover_at is null and handoff_requested_at is null) then raise exception 'L10_AI_ACTIVE_RETURN_FAILED'; end if;
  if not exists(select 1 from public.aos_wa_routing_events_v1 where conversation_id='66666666-6666-4666-8666-666666666661' and event_type='conversation.autonomous_canary_return') then raise exception 'L10_RETURN_AUDIT_MISSING'; end if;
end $$;

-- A real inbound-shaped ledger row binds to the exact conversation before enqueue.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,contact_name,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.ci.l10.in.0001','INBOUND','51911111111','15550000000','L10TEST','CI Contact','text','hello canary','received',now(),now()
);

do $$
declare r jsonb; a jsonb; begin
  r:=public.aos_wa_l10_bridge_enqueue_v1('wamid.ci.l10.in.0001');
  if coalesce((r->>'queued')::boolean,false) is not true or coalesce((r->>'replay')::boolean,true) is not false then raise exception 'L10_ENQUEUE %',r; end if;
  a:=public.aos_wa_l10_bridge_enqueue_v1('wamid.ci.l10.in.0001');
  if coalesce((a->>'queued')::boolean,false) is not true or coalesce((a->>'replay')::boolean,false) is not true then raise exception 'L10_ENQUEUE_REPLAY %',a; end if;

  r:=public.aos_wa_l10_bridge_claim_v1('wamid.ci.l10.in.0001');
  if coalesce((r->>'claimed')::boolean,false) is not true or r->>'recipient_kind'<>'PHONE' then raise exception 'L10_CLAIM %',r; end if;

  a:=public.aos_wa_l10_bridge_claim_v1('wamid.ci.l10.in.0001');
  if coalesce((a->>'claimed')::boolean,true) is not false or a->>'reason'<>'WA_L10_JOB_BUSY' then raise exception 'L10_CLAIM_EXACT_ONCE %',a; end if;

  perform public.aos_wa_l10_bridge_event_v1('wamid.ci.l10.in.0001',(r->>'attempt_id')::uuid,'SUGGESTED','CI_GOVERNED_SUGGESTION',null,null,25);
  perform public.aos_wa_l10_bridge_event_v1('wamid.ci.l10.in.0001',(r->>'attempt_id')::uuid,'SENT','CI_AUTO_SENT',null,'wamid.ci.l10.out.0001',50);

  a:=public.aos_wa_l10_bridge_claim_v1('wamid.ci.l10.in.0001');
  if coalesce((a->>'claimed')::boolean,true) is not false or a->>'reason'<>'WA_L10_JOB_TERMINAL' then raise exception 'L10_TERMINAL_REPLAY %',a; end if;
end
$$;

do $$ declare s jsonb; begin
  s:=public.aos_wa_l10_bridge_status_v1('CI-L10-BRIDGE-RUN-0001');
  if (s->>'jobs')::integer<>1 or (s->>'sent')::integer<>1 or coalesce((s->>'effective_autonomous_send')::boolean,false) is not true then raise exception 'L10_STATUS %',s; end if;
  if exists(select 1 from public.aos_wa_l10_bridge_pending_v1(5)) then raise exception 'L10_TERMINAL_JOB_MUST_NOT_BE_PENDING'; end if;
end $$;

-- Human boundary wins even while global CANARY remains on.
update public.aos_wa_conversations_v1
set state='HUMAN_ACTIVE',owner_user_id='44444444-4444-4444-8444-444444444444',human_takeover_at=now()
where id='66666666-6666-4666-8666-666666666661';
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,contact_name,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.ci.l10.in.0002','INBOUND','51911111111','15550000000','L10TEST','CI Contact','text','human now','received',now(),now()
);
do $$ declare r jsonb; begin
  r:=public.aos_wa_l10_bridge_enqueue_v1('wamid.ci.l10.in.0002');
  if coalesce((r->>'queued')::boolean,true) is not false or r->>'reason'<>'WA_L10_HUMAN_BOUNDARY_ACTIVE' then raise exception 'L10_HUMAN_BOUNDARY %',r; end if;
end $$;

-- Return global authority to SAFE-OFF at test exit.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','AUTO_OFF',true,null,null,null,null,null,null,null);
  if coalesce((r->>'ok')::boolean,false) is not true or r->>'mode'<>'AUTO_OFF' then raise exception 'L10_SAFE_OFF_EXIT %',r; end if;
  r:=public.aos_wa_l4_allowlist_set_v1('11111111-1111-4111-8111-111111111111','CONVERSATION','66666666-6666-4666-8666-666666666661',false,null,'CI_L10_BRIDGE_EXIT');
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L10_ALLOWLIST_EXIT %',r; end if;
end $$;

select 'WA_L10_AUTONOMOUS_BRIDGE_DB_CONTRACT_PASS' as result;
