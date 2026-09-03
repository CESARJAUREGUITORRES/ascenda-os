\set ON_ERROR_STOP on

-- WA-L7 TEST ONLY. Reuses the certified L6 strong-key fixture after L6 canary.
-- No production business rows are created by this file.

do $$
declare r jsonb;
begin
  r:=public.aos_wa_l7_pricing_authority_append_v1(
    'bad-token',
    jsonb_build_object(
      'provider','META_WHATSAPP','pricing_kind','META_MESSAGE','pricing_category','marketing',
      'pricing_model','PMP','market_code','GLOBAL','currency','USD','flat_cost',0.02,
      'authority_grade','VERIFIED','evidence_ref','TEST:PROVIDER_RATE','valid_from','2026-01-01T00:00:00Z'
    )
  );
  if coalesce((r->>'ok')::boolean,false) or r->>'error'<>'WA_L7_UNAUTHORIZED' then
    raise exception 'WA_L7_UNAUTHORIZED_FAIL:%',r;
  end if;

  r:=public.aos_wa_l7_pricing_authority_append_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object(
      'provider','META_WHATSAPP','pricing_kind','META_MESSAGE','pricing_category','marketing',
      'pricing_model','PMP','market_code','GLOBAL','currency','USD','flat_cost',0.02,
      'authority_grade','VERIFIED','evidence_ref','TEST:PROVIDER_RATE','valid_from','2026-01-01T00:00:00Z'
    )
  );
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L7_META_RATE_APPEND_FAIL:%',r; end if;

  r:=public.aos_wa_l7_pricing_authority_append_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object(
      'provider','GROQ','pricing_kind','AI_TOKEN','pricing_model','openai/gpt-oss-20b',
      'market_code','GLOBAL','currency','USD','input_cost_per_million',0.075,
      'output_cost_per_million',0.30,'authority_grade','VERIFIED',
      'evidence_ref','TEST:GROQ_FAST_RATE','valid_from','2026-01-01T00:00:00Z'
    )
  );
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L7_AI_FAST_RATE_APPEND_FAIL:%',r; end if;

  r:=public.aos_wa_l7_pricing_authority_append_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object(
      'provider','GROQ','pricing_kind','AI_TOKEN','pricing_model','openai/gpt-oss-safeguard-20b',
      'market_code','GLOBAL','currency','USD','input_cost_per_million',0.075,
      'output_cost_per_million',0.30,'authority_grade','VERIFIED',
      'evidence_ref','TEST:GROQ_SAFETY_RATE','valid_from','2026-01-01T00:00:00Z'
    )
  );
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L7_AI_SAFETY_RATE_APPEND_FAIL:%',r; end if;

  r:=public.aos_wa_l7_pricing_authority_append_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object(
      'provider','GROQ','pricing_kind','AI_TOKEN','pricing_model','openai/gpt-oss-120b',
      'market_code','GLOBAL','currency','USD','input_cost_per_million',0.15,
      'output_cost_per_million',0.60,'authority_grade','VERIFIED',
      'evidence_ref','TEST:GROQ_REASONING_RATE','valid_from','2026-01-01T00:00:00Z'
    )
  );
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L7_AI_REASONING_RATE_APPEND_FAIL:%',r; end if;

  -- Same effective version may not be silently replaced.
  r:=public.aos_wa_l7_pricing_authority_append_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object(
      'provider','META_WHATSAPP','pricing_kind','META_MESSAGE','pricing_category','marketing',
      'pricing_model','PMP','market_code','GLOBAL','currency','USD','flat_cost',0.03,
      'authority_grade','VERIFIED','evidence_ref','TEST:DUPLICATE','valid_from','2026-01-01T00:00:00Z'
    )
  );
  if r->>'error'<>'WA_L7_PRICING_VERSION_EXISTS' then raise exception 'WA_L7_DUPLICATE_VERSION_FAIL:%',r; end if;
end
$$;

-- Pricing authority is immutable after append.
do $$ begin
  begin
    update public.aos_wa_l7_pricing_authority_v1 set evidence_ref='MUTATED' where evidence_ref='TEST:PROVIDER_RATE';
    raise exception 'WA_L7_PRICING_UPDATE_UNEXPECTEDLY_ALLOWED';
  exception when sqlstate '55000' then null; end;
end $$;

-- Known-zero provider evidence plus one governed billable message on the certified L6 conversation.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  pricing_category,pricing_model,billable,provider_timestamp,sent_at,delivered_at,conversation_id
) values
(
  'wamid.l7.meta.free','OUTBOUND','519999111222','51977777771','pn-l6','text','L7 free','delivered',
  'service','PMP',false,now()-interval '20 seconds',now()-interval '20 seconds',now()-interval '19 seconds',
  '77777777-7777-4777-8777-777777777761'::uuid
),
(
  'wamid.l7.meta.paid','OUTBOUND','519999111222','51977777771','pn-l6','text','L7 paid','delivered',
  'marketing','PMP',true,now()-interval '10 seconds',now()-interval '10 seconds',now()-interval '9 seconds',
  '77777777-7777-4777-8777-777777777761'::uuid
);

insert into public.aos_wa_ai_runs_v1(
  id,conversation_id,actor_id,task,provider,model,safety_model,outcome,
  input_messages,input_chars,output_chars,prompt_tokens,completion_tokens,total_tokens,
  estimated_cost_usd,latency_ms,safety_action,safety_category,created_at
) values (
  '99999999-9999-4999-8999-999999999971'::uuid,
  '77777777-7777-4777-8777-777777777761'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid,
  'SALES_COPILOT','groq','openai/gpt-oss-20b','openai/gpt-oss-safeguard-20b','SUGGESTED',
  4,600,200,1000,500,1500,0.00022500,450,'ALLOW','SAFE',now()
);

-- A different-rate main+safety pair cannot be exactly recomputed because WA-4 historical
-- telemetry stores aggregate token counts. L7 must preserve the legacy estimate as PARTIAL.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  pricing_category,pricing_model,billable,provider_timestamp,sent_at,conversation_id
) values (
  'wamid.l7.meta.unknown','OUTBOUND','519999111222','51977777772','pn-l6','text','L7 unknown rate','sent',
  'authentication','PMP',true,now(),now(),
  '77777777-7777-4777-8777-777777777762'::uuid
);

insert into public.aos_wa_ai_runs_v1(
  id,conversation_id,actor_id,task,provider,model,safety_model,outcome,
  input_messages,input_chars,output_chars,prompt_tokens,completion_tokens,total_tokens,
  estimated_cost_usd,latency_ms,safety_action,safety_category,created_at
) values (
  '99999999-9999-4999-8999-999999999972'::uuid,
  '77777777-7777-4777-8777-777777777762'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid,
  'SALES_COPILOT','groq','openai/gpt-oss-120b','openai/gpt-oss-safeguard-20b','SUGGESTED',
  5,800,260,1200,600,1800,0.00054000,620,'ALLOW','SAFE',now()
);

-- A no-usage conversation proves known zero without any fabricated price.
insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_name,phone_number_id,state,opened_at,updated_at
) values (
  '77777777-7777-4777-8777-777777777763'::uuid,'pn-l7:51977777773','51977777773','L7 ZERO','pn-l7','AI_COPILOT',now(),now()
) on conflict(id) do nothing;

-- Event-level semantics.
do $$
declare e record;
begin
  select * into e from public.aos_wa_l7_meta_cost_events_v1 where provider_message_id='wamid.l7.meta.free';
  if e.cost_state<>'KNOWN' or e.cost_amount<>0 or e.cost_reason<>'PROVIDER_NON_BILLABLE' then
    raise exception 'WA_L7_META_NONBILLABLE_FAIL:%/%/%',e.cost_state,e.cost_amount,e.cost_reason;
  end if;

  select * into e from public.aos_wa_l7_meta_cost_events_v1 where provider_message_id='wamid.l7.meta.paid';
  if e.cost_state<>'KNOWN' or e.cost_amount<>0.02 or e.cost_currency<>'USD' or e.authority_grade<>'VERIFIED' then
    raise exception 'WA_L7_META_VERIFIED_RATE_FAIL:%/%/%',e.cost_state,e.cost_amount,e.cost_currency;
  end if;

  select * into e from public.aos_wa_l7_meta_cost_events_v1 where provider_message_id='wamid.l7.meta.unknown';
  if e.cost_state<>'UNKNOWN' or e.cost_amount is not null or e.cost_reason<>'VERIFIED_RATE_NOT_FOUND' then
    raise exception 'WA_L7_META_UNKNOWN_FAIL:%/%/%',e.cost_state,e.cost_amount,e.cost_reason;
  end if;
end $$;

do $$
declare e record;
begin
  select * into e from public.aos_wa_l7_ai_cost_events_v1 where ai_run_id='99999999-9999-4999-8999-999999999971'::uuid;
  if e.cost_state<>'KNOWN' or e.cost_amount<>0.00022500 or e.cost_currency<>'USD' or e.cost_reason<>'VERIFIED_EQUAL_RATE_COMBINED_USAGE' then
    raise exception 'WA_L7_AI_EQUAL_RATE_FAIL:%/%/%',e.cost_state,e.cost_amount,e.cost_reason;
  end if;

  select * into e from public.aos_wa_l7_ai_cost_events_v1 where ai_run_id='99999999-9999-4999-8999-999999999972'::uuid;
  if e.cost_state<>'PARTIAL' or e.cost_amount<>0.00054000 or e.cost_reason<>'AI_USAGE_NOT_SPLIT_BY_MODEL' then
    raise exception 'WA_L7_AI_PARTIAL_FAIL:%/%/%',e.cost_state,e.cost_amount,e.cost_reason;
  end if;
end $$;

-- Conversation and strong-key journey semantics.
do $$
declare r jsonb; v numeric;
begin
  r:=public.aos_wa_l7_conversation_cost_v1('77777777-7777-4777-8777-777777777761'::uuid);
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L7_CONVERSATION_COST_RPC_FAIL:%',r; end if;
  if r->'meta'->>'state'<>'KNOWN' or r->'ai'->>'state'<>'KNOWN' or r->'total'->>'state'<>'KNOWN' then
    raise exception 'WA_L7_KNOWN_STATE_FAIL:%',r;
  end if;
  v:=(r->'total'->>'amount')::numeric;
  if v<>0.02022500 or r->'total'->>'currency'<>'USD' then raise exception 'WA_L7_TOTAL_COST_FAIL:%',r; end if;

  r:=public.aos_wa_l7_journey_cost_v1('77777777-7777-4777-8777-777777777761'::uuid);
  if (r->'journey'->>'bookings')::integer<>1 or (r->'journey'->>'rebooks')::integer<>1
     or (r->'journey'->>'attendances')::integer<>1 or (r->'journey'->>'sales')::integer<>1 then
    raise exception 'WA_L7_STRONG_KEY_JOURNEY_FAIL:%',r;
  end if;
  if (r->'journey'->>'revenue_amount')::numeric<>899.00 or r->'journey'->>'revenue_currency'<>'PEN' then
    raise exception 'WA_L7_REVENUE_FAIL:%',r;
  end if;
  if r->'kpis'->>'revenue_cost_ratio' is not null
     or r->'kpis'->>'revenue_cost_ratio_reason'<>'REVENUE_COST_CURRENCY_MISMATCH_REQUIRES_FX' then
    raise exception 'WA_L7_FX_FAIL_CLOSED_FAIL:%',r;
  end if;

  r:=public.aos_wa_l7_conversation_cost_v1('77777777-7777-4777-8777-777777777762'::uuid);
  if r->'meta'->>'state'<>'UNKNOWN' or r->'ai'->>'state'<>'PARTIAL' or r->'total'->>'state'<>'PARTIAL' then
    raise exception 'WA_L7_PARTIAL_STATE_FAIL:%',r;
  end if;

  r:=public.aos_wa_l7_conversation_cost_v1('77777777-7777-4777-8777-777777777763'::uuid);
  if r->'total'->>'state'<>'KNOWN' or (r->'total'->>'amount')::numeric<>0 then
    raise exception 'WA_L7_ZERO_USAGE_FAIL:%',r;
  end if;
end $$;

-- Browser roles never gain direct financial/pricing visibility or mutation.
do $$ begin
  if has_table_privilege('anon','public.aos_wa_l7_pricing_authority_v1','SELECT')
     or has_table_privilege('authenticated','public.aos_wa_l7_pricing_authority_v1','SELECT') then
    raise exception 'WA_L7_BROWSER_PRICING_READ_LEAK';
  end if;
  if has_table_privilege('anon','public.aos_wa_l7_pricing_authority_v1','INSERT')
     or has_table_privilege('authenticated','public.aos_wa_l7_pricing_authority_v1','INSERT') then
    raise exception 'WA_L7_BROWSER_PRICING_WRITE_LEAK';
  end if;
  if has_function_privilege('anon','public.aos_wa_l7_conversation_cost_v1(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_wa_l7_conversation_cost_v1(uuid)','EXECUTE') then
    raise exception 'WA_L7_BROWSER_COST_RPC_LEAK';
  end if;
end $$;

select 'WA_L7_COST_INTELLIGENCE_CONTRACT_PASS' as result;
