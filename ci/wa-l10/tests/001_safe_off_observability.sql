\set ON_ERROR_STOP on

-- WA-L10 TEST ONLY. Synthetic identities/conversations come from the isolated L5 fixture.
\set l1 '11111111-1111-4111-8111-111111111111'
\set l2 '22222222-2222-4222-8222-222222222222'
\set conv '55555555-5555-4555-8555-555555555551'

-- Browser roles can neither read evidence nor execute server-only RPCs.
do $$ begin
 if has_table_privilege('anon','public.aos_wa_l10_canary_runs_v1','SELECT') then raise exception 'L10_ANON_RUN_READ'; end if;
 if has_table_privilege('authenticated','public.aos_wa_l10_canary_scope_v1','SELECT') then raise exception 'L10_AUTH_SCOPE_READ'; end if;
 if has_function_privilege('anon','public.aos_wa_l10_status_v1(text)','EXECUTE') then raise exception 'L10_ANON_STATUS_EXECUTE'; end if;
 if not has_function_privilege('service_role','public.aos_wa_l10_status_v1(text)','EXECUTE') then raise exception 'L10_SERVICE_STATUS_MISSING'; end if;
end $$;

-- Helper PRE object contains only aggregate counters and no PII/PHI.
create temp table l10_pre(v jsonb not null);
insert into l10_pre values(jsonb_build_object(
 'agenda',3,'llamadas',4,'leads',5,'ventas',6,'pacientes',7,
 'wa_events',8,'wa_messages',9,'wa_l6_journeys',2,'wa_l9_demo_runs',0,
 'active_allowlist',0,'wa_auto_outbound',0,'wa_auto_decisions',0,
 'wa_l5_booking_events',0,'wa_l7_ai_cost_events',0,'wa_outbound_requests',1,
 'wa_l7_meta_cost_events',1,'wa_l9_provider_dispatch',0
));

-- Level 2 cannot prepare evidence.
do $$ declare r jsonb; p jsonb; begin
 select v into p from l10_pre;
 r:=public.aos_wa_l10_prepare_run_v1(
   :'l2'::uuid,'CI-L10-SAFE-OFF-L2-0001',p,
   'VERIFIED_CURRENT','GH456:A1:POLICY','STALE_EVIDENCE','GH456:A1:PROVIDER',
   'UNKNOWN','GH456:A1:TEMPLATE','UNKNOWN','GH456:A1:BILLING',
   'BLOCKED','GH456:A1:CONSENT',null);
 if r->>'error'<>'WA_L10_LEVEL1_ADMIN_REQUIRED' then raise exception 'L10_LEVEL2_GATE %',r; end if;
end $$;

-- Fingerprint rejects unknown keys, preventing arbitrary payload/PII storage.
do $$ declare r jsonb; p jsonb; begin
 select v||jsonb_build_object('patient_name','FORBIDDEN') into p from l10_pre;
 r:=public.aos_wa_l10_prepare_run_v1(
   :'l1'::uuid,'CI-L10-BAD-PRE-000001',p,
   'VERIFIED_CURRENT','GH456:A1:POLICY','STALE_EVIDENCE','GH456:A1:PROVIDER',
   'UNKNOWN','GH456:A1:TEMPLATE','UNKNOWN','GH456:A1:BILLING',
   'BLOCKED','GH456:A1:CONSENT',null);
 if r->>'error'<>'WA_L10_PRE_FINGERPRINT_KEYS_INVALID' then raise exception 'L10_PRE_KEY_GATE %',r; end if;
end $$;

-- Exact SAFE-OFF preparation succeeds but explicitly does NOT authorize activation.
do $$ declare r jsonb; p jsonb; begin
 select v into p from l10_pre;
 r:=public.aos_wa_l10_prepare_run_v1(
   :'l1'::uuid,'CI-L10-SAFE-OFF-0001',p,
   'VERIFIED_CURRENT','GH456:A1:POLICY','STALE_EVIDENCE','GH456:A1:PROVIDER',
   'UNKNOWN','GH456:A1:TEMPLATE','UNKNOWN','GH456:A1:BILLING',
   'BLOCKED','GH456:A1:CONSENT',null);
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L10_PREP_FAILED %',r; end if;
 if coalesce((r->>'readiness_complete')::boolean,true) then raise exception 'L10_PREMATURE_READINESS %',r; end if;
 if coalesce((r->>'activation_authorized')::boolean,true) then raise exception 'L10_PREMATURE_AUTH %',r; end if;
end $$;

-- Exact replay is idempotent and creates one immutable run only.
do $$ declare r jsonb; p jsonb; begin
 select v into p from l10_pre;
 r:=public.aos_wa_l10_prepare_run_v1(
   :'l1'::uuid,'CI-L10-SAFE-OFF-0001',p,
   'VERIFIED_CURRENT','GH456:A1:POLICY','STALE_EVIDENCE','GH456:A1:PROVIDER',
   'UNKNOWN','GH456:A1:TEMPLATE','UNKNOWN','GH456:A1:BILLING',
   'BLOCKED','GH456:A1:CONSENT',null);
 if coalesce((r->>'replay')::boolean,false) is not true then raise exception 'L10_REPLAY_MISSING %',r; end if;
 if (select count(*) from public.aos_wa_l10_canary_runs_v1 where run_key='CI-L10-SAFE-OFF-0001')<>1 then raise exception 'L10_REPLAY_DUPLICATED'; end if;
end $$;

-- Scope attachment is hash-only and never writes L4 allowlist.
do $$ declare r jsonb; before_n bigint; after_n bigint; begin
 select count(*) into before_n from public.aos_wa_auto_allowlist_v1 where active is true;
 r:=public.aos_wa_l10_attach_scope_v1(
   :'l1'::uuid,'CI-L10-SAFE-OFF-0001',:'conv'::uuid,repeat('a',64),'CI_MINIMAL_SCOPE');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L10_SCOPE_FAILED %',r; end if;
 if coalesce((r->>'activation_authorized')::boolean,true) then raise exception 'L10_SCOPE_PREMATURE_AUTH %',r; end if;
 select count(*) into after_n from public.aos_wa_auto_allowlist_v1 where active is true;
 if before_n<>after_n or after_n<>0 then raise exception 'L10_SCOPE_MUTATED_ALLOWLIST % %',before_n,after_n; end if;
 if (select recipient_hash from public.aos_wa_l10_canary_scope_v1 limit 1)<>repeat('a',64) then raise exception 'L10_SCOPE_HASH_DRIFT'; end if;
end $$;

-- Bounded status is run-scoped, preserves SAFE-OFF and sees no autonomous activity.
do $$ declare s jsonb; begin
 s:=public.aos_wa_l10_status_v1('CI-L10-SAFE-OFF-0001');
 if s->>'readback_class'<>'RUN_SCOPED_BOUNDED_V1' then raise exception 'L10_STATUS_CLASS %',s; end if;
 if coalesce((s->>'safe_off_intact')::boolean,false) is not true then raise exception 'L10_SAFE_OFF_DRIFT %',s; end if;
 if (s->>'mode')<>'AUTO_OFF' or coalesce((s->>'kill_switch_engaged')::boolean,false) is not true then raise exception 'L10_AUTHORITY_DRIFT %',s; end if;
 if (s->>'scope_count')::bigint<>1 then raise exception 'L10_SCOPE_COUNT %',s; end if;
 if (s->>'scope_allowlist_matches')::bigint<>0 or coalesce((s->>'any_active_allowlist')::boolean,true) then raise exception 'L10_ALLOWLIST_LEAK %',s; end if;
 if (s->>'run_scoped_auto_outbound')::bigint<>0 or (s->>'run_scoped_allow_decisions')::bigint<>0 then raise exception 'L10_AUTONOMOUS_ACTIVITY %',s; end if;
 if coalesce((s->>'unexpected_auto_outbound_while_auto_off')::boolean,true) then raise exception 'L10_UNEXPECTED_AUTO %',s; end if;
 if coalesce((s->>'activation_authorized')::boolean,true) then raise exception 'L10_STATUS_PREMATURE_AUTH %',s; end if;
end $$;

-- Active allowlist blocks preparation; L10-A cannot silently inherit or create a live cohort.
do $$ declare r jsonb; p jsonb; begin
 r:=public.aos_wa_l4_allowlist_set_v1(:'l1'::uuid,'CONVERSATION',:'conv',true,null,'l10-ci-guard');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L10_CI_ALLOWLIST_FIXTURE %',r; end if;
 select v into p from l10_pre;
 r:=public.aos_wa_l10_prepare_run_v1(
   :'l1'::uuid,'CI-L10-ACTIVE-LIST-01',p,
   'VERIFIED_CURRENT','GH456:A1:POLICY','STALE_EVIDENCE','GH456:A1:PROVIDER',
   'UNKNOWN','GH456:A1:TEMPLATE','UNKNOWN','GH456:A1:BILLING',
   'BLOCKED','GH456:A1:CONSENT',null);
 if r->>'error'<>'WA_L10_ACTIVE_ALLOWLIST_MUST_BE_EMPTY_DURING_PREP' then raise exception 'L10_ACTIVE_ALLOWLIST_GATE %',r; end if;
 r:=public.aos_wa_l4_allowlist_set_v1(:'l1'::uuid,'CONVERSATION',:'conv',false,null,'l10-ci-cleanup');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L10_CI_ALLOWLIST_CLEANUP %',r; end if;
end $$;

-- Append-only evidence cannot be rewritten or deleted.
do $$ begin
 begin
   update public.aos_wa_l10_canary_runs_v1 set cohort_method='MUTATION_FORBIDDEN' where run_key='CI-L10-SAFE-OFF-0001';
   raise exception 'L10_RUN_UPDATE_SHOULD_FAIL';
 exception when sqlstate '55000' then null; end;
 begin
   delete from public.aos_wa_l10_canary_scope_v1;
   raise exception 'L10_SCOPE_DELETE_SHOULD_FAIL';
 exception when sqlstate '55000' then null; end;
end $$;

-- Existing authority/provider/business ledgers remain untouched by L10 evidence.
do $$ begin
 if (select count(*) from public.aos_wa_messages_v1 where direction='OUTBOUND' and send_origin='AUTO')<>0 then raise exception 'L10_AUTO_OUTBOUND_CREATED'; end if;
 if (select count(*) from public.aos_wa_auto_decisions_v1 where decision='ALLOW' and created_at>=(select min(created_at) from public.aos_wa_l10_canary_runs_v1))<>0 then raise exception 'L10_ALLOW_DECISION_CREATED'; end if;
end $$;

select 'WA_L10_SAFE_OFF_OBSERVABILITY_PASS' as result;
