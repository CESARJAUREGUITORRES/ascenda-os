\set ON_ERROR_STOP on

-- Deployment must always land dormant.
do $$
declare s jsonb;
begin
 s:=public.aos_wa_l4_status_v1();
 if s->>'mode'<>'AUTO_OFF' then raise exception 'L4_DEFAULT_MODE %',s; end if;
 if coalesce((s->>'kill_switch_engaged')::boolean,false) is not true then raise exception 'L4_DEFAULT_KILL %',s; end if;
 if coalesce((s->>'auto_reply_enabled')::boolean,true) then raise exception 'L4_DEFAULT_AUTO_REPLY %',s; end if;
 if coalesce((s->>'ai_send_enabled')::boolean,true) then raise exception 'L4_DEFAULT_AI_SEND %',s; end if;
 if coalesce((s->>'auto_routing_enabled')::boolean,true) then raise exception 'L4_DEFAULT_ROUTING %',s; end if;
 if coalesce((s->>'human_send_enabled')::boolean,false) is not true then raise exception 'L4_DEFAULT_HUMAN_SEND %',s; end if;
end $$;

-- Browser roles cannot control or read raw authority tables/functions.
do $$ begin
 if has_table_privilege('anon','public.aos_wa_auto_authority_v1','SELECT') then raise exception 'L4_ANON_AUTHORITY_READ'; end if;
 if has_table_privilege('authenticated','public.aos_wa_auto_allowlist_v1','SELECT') then raise exception 'L4_AUTH_ALLOWLIST_READ'; end if;
 if has_function_privilege('anon','public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)','EXECUTE') then raise exception 'L4_ANON_AUTHORIZE'; end if;
 if not has_function_privilege('service_role','public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)','EXECUTE') then raise exception 'L4_SERVICE_AUTHORIZE_MISSING'; end if;
end $$;

-- Level 2 cannot alter authority.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('22222222-2222-4222-8222-222222222222','CANARY',false,null,null,null,null,null,null,'CI-AUTH-REF-LEVEL2');
 if r->>'error'<>'WA_L4_LEVEL1_ADMIN_REQUIRED' then raise exception 'L4_LEVEL2_CONTROL %',r; end if;
end $$;

-- AUTO_OFF blocks before provider eligibility and records decision.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_authorize_autonomous_send_v1(
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,
   'ci-auto-off-00000001',repeat('a',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L4_AUTO_OFF' then raise exception 'L4_AUTO_OFF_BLOCK %',r; end if;
end $$;

-- CANARY needs explicit authorization reference and an allowlist.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',false,null,null,null,null,null,null,null);
 if r->>'error'<>'WA_L4_EXPLICIT_AUTHORIZATION_REF_REQUIRED' then raise exception 'L4_AUTH_REF_GATE %',r; end if;
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',false,null,null,null,null,null,null,'CI-AUTH-REF-0001');
 if r->>'error'<>'WA_L4_CANARY_ALLOWLIST_REQUIRED' then raise exception 'L4_ALLOWLIST_REQUIRED %',r; end if;
end $$;

-- Invalid phone must not enter allowlist; valid subject does.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_allowlist_set_v1('11111111-1111-4111-8111-111111111111','PHONE','name-only',true,null,'ci');
 if r->>'error'<>'WA_L4_INVALID_ALLOWLIST_SUBJECT' then raise exception 'L4_INVALID_ALLOWLIST %',r; end if;
 r:=public.aos_wa_l4_allowlist_set_v1('11111111-1111-4111-8111-111111111111','PHONE','999111222',true,null,'ci');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L4_ALLOWLIST_SET %',r; end if;
 r:=public.aos_wa_l4_allowlist_set_v1('11111111-1111-4111-8111-111111111111','PHONE','999111444',true,null,'ci-human');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L4_ALLOWLIST_HUMAN %',r; end if;
 r:=public.aos_wa_l4_allowlist_set_v1('11111111-1111-4111-8111-111111111111','PHONE','999111555',true,null,'ci-template');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L4_ALLOWLIST_TEMPLATE %',r; end if;
 r:=public.aos_wa_l4_allowlist_set_v1('11111111-1111-4111-8111-111111111111','BSUID','bsuid-test-001',true,null,'ci-bsuid');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L4_ALLOWLIST_BSUID %',r; end if;
end $$;

-- Kill switch remains absolute even when CANARY is configured.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',true,50,10,20,10,0,120,'CI-AUTH-REF-0002');
 if coalesce((r->>'ok')::boolean,false) is not true or coalesce((r->>'effective_autonomous_send')::boolean,true) then raise exception 'L4_KILL_CONTROL %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-kill-000000000001',repeat('b',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'reason'<>'WA_L4_KILL_SWITCH' then raise exception 'L4_KILL_BLOCK %',r; end if;
end $$;

-- Synthetic CANARY activation is isolated CI only; it proves atomically consistent flags.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',false,50,10,20,10,0,120,'CI-AUTH-REF-0003');
 if coalesce((r->>'effective_autonomous_send')::boolean,false) is not true then raise exception 'L4_CANARY_EFFECTIVE %',r; end if;
 if not (select auto_reply_enabled from public.aos_wa_ai_control_v1 where id=1) then raise exception 'L4_FLAG_AUTO_REPLY'; end if;
 if not (select ai_send_enabled from public.aos_wa_routing_control_v1 where id=1) then raise exception 'L4_FLAG_AI_SEND'; end if;
 if (select auto_routing_enabled from public.aos_wa_routing_control_v1 where id=1) then raise exception 'L4_AUTO_ROUTING_MUST_STAY_OFF'; end if;
 if not (select human_send_enabled from public.aos_wa_routing_control_v1 where id=1) then raise exception 'L4_HUMAN_SEND_MUST_STAY_ON'; end if;
end $$;

-- Allowlisted conversation can pass; exact decision replay cannot consume budget twice.
do $$ declare r jsonb; r2 jsonb; begin
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-allow-000000000001',repeat('c',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'decision'<>'ALLOW' then raise exception 'L4_ALLOWED_EXPECTED %',r; end if;
 r2:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-allow-000000000001',repeat('c',64),'ALLOW','NOT_REQUIRED',false,null);
 if coalesce((r2->>'replay')::boolean,false) is not true or r2->>'decision'<>'ALLOW' then raise exception 'L4_REPLAY %',r2; end if;
 if (select count(*) from public.aos_wa_auto_decisions_v1 where idempotency_key='ci-allow-000000000001')<>1 then raise exception 'L4_REPLAY_DUPLICATED_DECISION'; end if;
end $$;

-- Nonallowlisted recipient blocks; recipient mismatch hands off.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','PHONE','999111333','text',null,'ci-notallow-000000001',repeat('d',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'reason'<>'WA_L4_CANARY_NOT_ALLOWLISTED' then raise exception 'L4_NOT_ALLOWLISTED %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111333','text',null,'ci-mismatch-0000000001',repeat('e',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L4_RECIPIENT_CONVERSATION_MISMATCH' then raise exception 'L4_RECIPIENT_MISMATCH %',r; end if;
end $$;

-- Human ownership, safety and identity conflicts hand off, never send.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','PHONE','999111444','text',null,'ci-human-000000000001',repeat('f',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L4_HUMAN_OWNERSHIP_BOUNDARY' then raise exception 'L4_HUMAN_BOUNDARY %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-safety-00000000001',repeat('1',64),'CLINICAL','NOT_REQUIRED',false,null);
 if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L4_SAFETY_HANDOFF' then raise exception 'L4_SAFETY_HANDOFF %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-identconf-000000001',repeat('2',64),'ALLOW','CONFLICT',true,null);
 if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L4_IDENTITY_CONFLICT' then raise exception 'L4_IDENTITY_CONFLICT %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-identreq-0000000001',repeat('3',64),'ALLOW','UNRESOLVED',true,null);
 if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L4_IDENTITY_REQUIRED' then raise exception 'L4_IDENTITY_REQUIRED %',r; end if;
end $$;

-- Template send is fail-closed unless provider registry has a verified exact name.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','PHONE','999111555','template','unverified_template','ci-tplbad-000000000001',repeat('4',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'reason'<>'WA_L4_TEMPLATE_NOT_PROVIDER_VERIFIED' then raise exception 'L4_UNVERIFIED_TEMPLATE %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','PHONE','999111555','template','verified_template','ci-tplgood-00000000001',repeat('5',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'decision'<>'ALLOW' then raise exception 'L4_VERIFIED_TEMPLATE %',r; end if;
end $$;

-- BSUID is allowed only by exact conversation identity/allowlist; no phone fallback.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa5','BSUID','bsuid-test-001','text',null,'ci-bsuid-000000000001',repeat('6',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'decision'<>'ALLOW' then raise exception 'L4_BSUID_ALLOW %',r; end if;
end $$;

-- Duplicate guard after an ALLOW on same conversation/content.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-duplicate-000000001',repeat('c',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'reason'<>'WA_L4_DUPLICATE_GUARD' then raise exception 'L4_DUPLICATE_GUARD %',r; end if;
end $$;

-- Cooldown and per-minute limits are deterministic after tightening controls.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',false,50,10,20,10,3600,0,'CI-AUTH-REF-0004');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L4_COOLDOWN_CONTROL %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-cooldown-0000000001',repeat('7',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'reason'<>'WA_L4_COOLDOWN' then raise exception 'L4_COOLDOWN %',r; end if;
end $$;

-- Max-turn handoff: set max turns below existing allowed count for conversation 1.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',false,50,1,20,10,0,0,'CI-AUTH-REF-0005');
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','PHONE','999111222','text',null,'ci-maxturns-0000000001',repeat('8',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L4_MAX_TURNS_HANDOFF' then raise exception 'L4_MAX_TURNS %',r; end if;
end $$;

-- Daily and rate controls use ALLOW decisions only; blocked/handoff attempts do not spend quota.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',false,1,50,120,30,0,0,'CI-AUTH-REF-0006');
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','PHONE','999111555','text',null,'ci-daily-000000000001',repeat('9',64),'ALLOW','NOT_REQUIRED',false,null);
 if r->>'reason'<>'WA_L4_DAILY_MESSAGE_LIMIT' then raise exception 'L4_DAILY_LIMIT %',r; end if;
end $$;

-- AUTO_OFF is atomic: all autonomous flags false, human send true.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','AUTO_OFF',true,null,null,null,null,null,null,null);
 if r->>'mode'<>'AUTO_OFF' or coalesce((r->>'effective_autonomous_send')::boolean,true) then raise exception 'L4_AUTO_OFF_RESET %',r; end if;
 if (select auto_reply_enabled from public.aos_wa_ai_control_v1 where id=1) then raise exception 'L4_AUTO_REPLY_NOT_RESET'; end if;
 if (select ai_send_enabled from public.aos_wa_routing_control_v1 where id=1) then raise exception 'L4_AI_SEND_NOT_RESET'; end if;
 if not (select human_send_enabled from public.aos_wa_routing_control_v1 where id=1) then raise exception 'L4_HUMAN_SEND_RESET'; end if;
end $$;

-- Append-only audit surfaces cannot be mutated.
do $$ begin
 begin update public.aos_wa_auto_decisions_v1 set reason_code='MUTATED' where false; exception when others then null; end;
 begin
  update public.aos_wa_auto_decisions_v1 set reason_code='MUTATED' where id=(select id from public.aos_wa_auto_decisions_v1 limit 1);
  raise exception 'L4_DECISION_APPEND_GUARD_MISSING';
 exception when sqlstate '55000' then null; end;
end $$;
