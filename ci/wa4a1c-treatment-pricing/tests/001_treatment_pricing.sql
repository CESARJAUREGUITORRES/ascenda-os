\set ON_ERROR_STOP on

-- Structural contracts.
do $$ begin
  if (select count(*) from public.aos_wa4_process_templates_v1 where template_state='APPROVED')<>8 then
    raise exception 'expected eight approved Zi Vital process templates';
  end if;
  if (select count(*) from public.aos_wa4_process_role_policy_v1)<>8 then
    raise exception 'expected eight process component roles';
  end if;
  if exists(select 1 from public.aos_wa4_process_role_policy_v1 where can_auto_assign) then
    raise exception 'no process role may auto-assign in WA-4A.1C';
  end if;
  if (select count(*) from public.aos_wa4_price_authority_v1)<>217 then
    raise exception 'price authority must cover 217 active catalog entities';
  end if;
  if (select count(*) from public.aos_wa4_process_entity_context_v1)<>217 then
    raise exception 'process context must cover 217/217 mapped entities';
  end if;
  if (select count(*) from public.aos_wa4_topping_authority_v1)<>20 then
    raise exception 'topping authority must cover 20 active fixture toppings';
  end if;
  if (select count(*) from public.aos_wa4_topping_authority_v1 where benefit_mode='ZERO_PRICE_BENEFIT_CANDIDATE')<>1 then
    raise exception 'zero-price benefit semantics missing';
  end if;
end $$;

-- Fail-closed price anomaly + stale evidence.
do $$ begin
  if (select count(*) from public.aos_wa4_price_authority_v1 where price_state='REVIEW_REQUIRED_OFFER_ABOVE_BASE' and ready_for_quote=false)<>1 then
    raise exception 'offer-above-base anomaly must fail closed';
  end if;
  if (select count(*) from public.aos_wa4_price_authority_v1 where freshness_state='STALE_REVIEW' and ready_for_quote=false)<>1 then
    raise exception 'stale price must fail closed';
  end if;
  if nullif(public.aos_wa4_price_fingerprint_v1(),'') is null then
    raise exception 'price fingerprint missing';
  end if;
end $$;

-- Normal catalog preview and progressive view preserve scope/total.
do $$
declare
  v_id text;
  v_phase text;
  v_complete jsonb;
  v_progressive jsonb;
begin
  select entity_id::text, commercial_phase_codes[1]
    into v_id,v_phase
  from public.aos_wa4_process_entity_context_v1
  where entity_type='SERVICIO' and ready_for_quote=true
    and commercial_phase_codes && array['COMMERCIAL_F1_PREP_ACT','COMMERCIAL_F2_INTERVENTION','COMMERCIAL_F3_CONTINUITY']
  order by entity_name limit 1;

  select public.aos_wa4_quote_preview_v1(
    jsonb_build_array(jsonb_build_object('source_type','CATALOG','source_id',v_id,'quantity',2,'phase_code',v_phase,'role','OPTIONAL_SUPPORT')),
    'COMPLETE',false
  ) into v_complete;
  if not coalesce((v_complete->>'ok')::boolean,false) then raise exception 'complete preview failed: %',v_complete; end if;
  if coalesce((v_complete->>'discount_applied')::boolean,true) then raise exception 'preview applied discount'; end if;
  if not coalesce((v_complete->>'scope_preserved')::boolean,false) then raise exception 'preview did not preserve scope'; end if;

  select public.aos_wa4_quote_preview_v1(
    jsonb_build_array(jsonb_build_object('source_type','CATALOG','source_id',v_id,'quantity',2,'phase_code',v_phase,'role','OPTIONAL_SUPPORT')),
    'PROGRESSIVE',false
  ) into v_progressive;
  if not coalesce((v_progressive->>'ok')::boolean,false) then raise exception 'progressive preview failed: %',v_progressive; end if;
  if (v_progressive->>'canonical_total')::numeric<>(v_complete->>'canonical_total')::numeric then
    raise exception 'payment mode changed canonical scope total';
  end if;
  if v_progressive->'progressive_view' is null then raise exception 'progressive phase view missing'; end if;
end $$;

-- REQUIRED_BY_PLAN cannot be self-declared without plan authority.
do $$
declare
  v_id text;
  v_phase text;
  v_denied jsonb;
  v_allowed jsonb;
begin
  select entity_id::text, commercial_phase_codes[1]
  into v_id,v_phase
  from public.aos_wa4_process_entity_context_v1
  where entity_type='SERVICIO' and ready_for_quote=true
  order by entity_name limit 1;

  select public.aos_wa4_quote_preview_v1(
    jsonb_build_array(jsonb_build_object('source_id',v_id,'phase_code',v_phase,'role','REQUIRED_BY_PLAN')),
    'COMPLETE',false
  ) into v_denied;
  if v_denied->>'error'<>'AUTHORIZED_PLAN_REQUIRED' then raise exception 'required role did not fail closed: %',v_denied; end if;

  select public.aos_wa4_quote_preview_v1(
    jsonb_build_array(jsonb_build_object('source_id',v_id,'phase_code',v_phase,'role','REQUIRED_BY_PLAN')),
    'COMPLETE',true
  ) into v_allowed;
  if not coalesce((v_allowed->>'ok')::boolean,false) then raise exception 'authorized required role failed: %',v_allowed; end if;
end $$;

-- Product support and topping semantics.
do $$
declare
  v_product text;
  v_top text;
  v_product_result jsonb;
  v_top_result jsonb;
begin
  select entity_id::text into v_product
  from public.aos_wa4_process_entity_context_v1
  where entity_type='PRODUCTO' and ready_for_quote=true and commercial_phase_codes @> array['COMMERCIAL_F3_CONTINUITY']
  order by entity_name limit 1;
  select topping_id into v_top from public.aos_wa4_topping_authority_v1 where benefit_mode='ZERO_PRICE_BENEFIT_CANDIDATE' limit 1;

  select public.aos_wa4_quote_preview_v1(
    jsonb_build_array(jsonb_build_object('source_id',v_product,'phase_code','COMMERCIAL_F3_CONTINUITY','role','PRODUCT_SUPPORT')),
    'COMPLETE',false
  ) into v_product_result;
  if not coalesce((v_product_result->>'ok')::boolean,false) then raise exception 'product support preview failed: %',v_product_result; end if;

  select public.aos_wa4_quote_preview_v1(
    jsonb_build_array(jsonb_build_object('source_type','TOPPING','source_id',v_top,'phase_code','COMMERCIAL_F3_CONTINUITY','role','TOPPING_ELIGIBLE')),
    'COMPLETE',false
  ) into v_top_result;
  if not coalesce((v_top_result->>'ok')::boolean,false) then raise exception 'topping preview failed: %',v_top_result; end if;
  if v_top_result#>>'{lines,0,benefit_mode}'<>'ZERO_PRICE_BENEFIT_CANDIDATE' then raise exception 'zero-price topping not explicit'; end if;
end $$;

-- Anomalous and stale catalog prices cannot be quoted.
do $$
declare
  v_bad text;
  v_stale text;
  v_phase text;
  v_result jsonb;
begin
  select entity_id::text, commercial_phase_codes[1] into v_bad,v_phase
  from public.aos_wa4_process_entity_context_v1 where price_state='REVIEW_REQUIRED_OFFER_ABOVE_BASE' limit 1;
  select public.aos_wa4_quote_preview_v1(jsonb_build_array(jsonb_build_object('source_id',v_bad,'phase_code',v_phase,'role','OPTIONAL_SUPPORT')),'COMPLETE',false) into v_result;
  if v_result->>'error'<>'PRICE_NOT_READY' then raise exception 'anomalous price did not fail closed: %',v_result; end if;

  select entity_id::text, commercial_phase_codes[1] into v_stale,v_phase
  from public.aos_wa4_process_entity_context_v1 where freshness_state='STALE_REVIEW' limit 1;
  select public.aos_wa4_quote_preview_v1(jsonb_build_array(jsonb_build_object('source_id',v_stale,'phase_code',v_phase,'role',case when (select entity_type from public.aos_wa4_process_entity_context_v1 where entity_id=v_stale::uuid)='PRODUCTO' then 'PRODUCT_SUPPORT' else 'OPTIONAL_SUPPORT' end)),'COMPLETE',false) into v_result;
  if v_result->>'error'<>'PRICE_NOT_READY' then raise exception 'stale price did not fail closed: %',v_result; end if;
end $$;

-- Least privilege: no end-user direct data/RPC access.
do $$ begin
  if has_table_privilege('anon','public.aos_wa4_price_authority_v1','SELECT') or
     has_table_privilege('authenticated','public.aos_wa4_price_authority_v1','SELECT') or
     has_table_privilege('anon','public.aos_wa4_process_templates_v1','SELECT') or
     has_table_privilege('authenticated','public.aos_wa4_process_templates_v1','SELECT') then
    raise exception '1C pricing/process data leaked to end-user roles';
  end if;
  if has_function_privilege('anon','public.aos_wa4_quote_preview_v1(jsonb,text,boolean)','EXECUTE') or
     has_function_privilege('authenticated','public.aos_wa4_quote_preview_v1(jsonb,text,boolean)','EXECUTE') then
    raise exception 'quote preview leaked to end-user roles';
  end if;
  if not has_function_privilege('service_role','public.aos_wa4_quote_preview_v1(jsonb,text,boolean)','EXECUTE') then
    raise exception 'service_role missing quote preview';
  end if;
end $$;

-- Canonical sources remain unchanged in shape and count.
do $$ begin
  if (select count(*) from public.aos_catalogo_servicios where estado='ACTIVO')<>217 then raise exception 'catalog mutated by 1C'; end if;
  if (select count(*) from public.aos_catalogo_toppings where estado='ACTIVO')<>20 then raise exception 'toppings mutated by 1C'; end if;
end $$;

select 'WA4A1C_TREATMENT_PRICING_ARCHITECTURE_PASS' as certification;
