create unique index if not exists ux_cia_assignment_one_initial_run on public.aos_cia_assignment_runs(plan_id) where run_type='INITIAL';

create or replace function public.aos_cia_assignment_candidate_keys_v1(p_plan_id uuid)
returns table(contact_key text) language sql stable set search_path=public as $$
with p as (select id,activation_id,ownership_scope,allow_reassign_released,allow_reassign_expired from public.aos_cia_assignment_plans where id=p_plan_id),
src as (select k.contact_key from p cross join lateral public.aos_cia_activation_available_keys_v1(p.activation_id) k)
select s.contact_key from src s cross join p
where not exists (select 1 from public.aos_cia_assignments x where x.activation_id=p.activation_id and x.contact_key=s.contact_key and x.state='COMPLETED')
and (p.allow_reassign_released or not exists (select 1 from public.aos_cia_assignments x where x.activation_id=p.activation_id and x.contact_key=s.contact_key and x.state='RELEASED'))
and (p.allow_reassign_expired or not exists (select 1 from public.aos_cia_assignments x where x.activation_id=p.activation_id and x.contact_key=s.contact_key and x.state='EXPIRED'))
and not exists (select 1 from public.aos_cia_assignments x where x.activation_id=p.activation_id and x.contact_key=s.contact_key and x.state in ('RESERVED','ASSIGNED','IN_PROGRESS'))
and ((p.ownership_scope='GLOBAL' and not exists (select 1 from public.aos_cia_assignments x where x.contact_key=s.contact_key and x.state in ('RESERVED','ASSIGNED','IN_PROGRESS')))
  or (p.ownership_scope='ACTIVATION' and not exists (select 1 from public.aos_cia_assignments x join public.aos_cia_assignment_plans xp on xp.id=x.plan_id where x.contact_key=s.contact_key and x.state in ('RESERVED','ASSIGNED','IN_PROGRESS') and xp.ownership_scope='GLOBAL')))
order by s.contact_key; $$;
create or replace function public.aos_cia_assignment_candidate_count_v1(p_plan_id uuid) returns integer language sql stable set search_path=public as $$ select count(*)::integer from public.aos_cia_assignment_candidate_keys_v1(p_plan_id); $$;

create or replace function public.aos_cia_assignment_plan_create_admin_v1(
  p_token text,p_activation_id uuid,p_strategy text,p_targets jsonb,p_ownership_scope text default 'GLOBAL',p_source_limit integer default null,
  p_lease_minutes integer default 480,p_must_start_minutes integer default 120,p_topup_policy text default 'NONE',p_topup_target_per_advisor integer default null,
  p_allow_reassign_released boolean default true,p_allow_reassign_expired boolean default true,p_idempotency_key text default null,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare auth jsonb;uid uuid;v_ctx jsonb;v_plan_id uuid;v_count integer;v_distinct integer;v_valid integer;v_sum numeric;v_existing uuid;
 v_strategy text:=upper(coalesce(p_strategy,''));v_scope text:=upper(coalesce(p_ownership_scope,'GLOBAL'));v_topup text:=upper(coalesce(p_topup_policy,'NONE'));
begin
 auth:=public.aos_cia_verify_admin_session_v1(p_token);if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED');end if;uid:=(auth->>'user_id')::uuid;
 if p_idempotency_key is null or length(p_idempotency_key) not between 12 and 128 then return jsonb_build_object('ok',false,'error','INVALID_IDEMPOTENCY_KEY');end if;
 select id into v_existing from public.aos_cia_assignment_plans where idempotency_key=p_idempotency_key;if v_existing is not null then return jsonb_build_object('ok',true,'idempotent',true,'plan_id',v_existing);end if;
 if v_strategy not in ('ONE','EQUAL','PERCENTAGE','FIXED') then return jsonb_build_object('ok',false,'error','INVALID_STRATEGY');end if;
 if v_scope not in ('ACTIVATION','GLOBAL') then return jsonb_build_object('ok',false,'error','INVALID_OWNERSHIP_SCOPE');end if;
 if v_topup not in ('NONE','MAINTAIN_TARGET','CONTINUOUS') then return jsonb_build_object('ok',false,'error','INVALID_TOPUP_POLICY');end if;
 if p_source_limit is not null and (p_source_limit<1 or p_source_limit>100000) then return jsonb_build_object('ok',false,'error','INVALID_SOURCE_LIMIT');end if;
 if p_lease_minutes not between 30 and 10080 or p_must_start_minutes not between 5 and p_lease_minutes then return jsonb_build_object('ok',false,'error','INVALID_LEASE');end if;
 if v_topup='MAINTAIN_TARGET' and (p_topup_target_per_advisor is null or p_topup_target_per_advisor<1 or p_topup_target_per_advisor>100000 or v_strategy not in ('ONE','EQUAL')) then return jsonb_build_object('ok',false,'error','INVALID_MAINTAIN_TARGET');end if;
 if v_topup='CONTINUOUS' and p_source_limit is not null then return jsonb_build_object('ok',false,'error','CONTINUOUS_REQUIRES_UNLIMITED_SOURCE');end if;
 if p_metadata is null or jsonb_typeof(p_metadata)<>'object' or octet_length(p_metadata::text)>32768 then return jsonb_build_object('ok',false,'error','INVALID_METADATA');end if;
 if p_targets is null or jsonb_typeof(p_targets)<>'array' then return jsonb_build_object('ok',false,'error','INVALID_TARGETS');end if;
 v_count:=jsonb_array_length(p_targets);if v_count<1 or v_count>50 then return jsonb_build_object('ok',false,'error','INVALID_TARGET_COUNT');end if;
 select count(distinct (e->>'advisor_user_id')::uuid),count(*) filter(where u.id is not null and u.activo and lower(coalesce(u.rol,''))='asesor') into v_distinct,v_valid from jsonb_array_elements(p_targets)e left join public.aos_usuarios u on u.id=(e->>'advisor_user_id')::uuid;
 if v_distinct<>v_count then return jsonb_build_object('ok',false,'error','DUPLICATE_TARGET');end if;if v_valid<>v_count then return jsonb_build_object('ok',false,'error','INVALID_ADVISOR_TARGET');end if;
 if v_strategy='ONE' and v_count<>1 then return jsonb_build_object('ok',false,'error','ONE_REQUIRES_ONE_TARGET');end if;
 if v_strategy in ('ONE','EQUAL') and exists(select 1 from jsonb_array_elements(p_targets)e where e?'weight_percent' or e?'fixed_quantity') then return jsonb_build_object('ok',false,'error','TARGET_FIELDS_NOT_ALLOWED');end if;
 if v_strategy='PERCENTAGE' then if exists(select 1 from jsonb_array_elements(p_targets)e where not(e?'weight_percent') or (e->>'weight_percent')::numeric<=0 or (e->>'weight_percent')::numeric>100 or e?'fixed_quantity') then return jsonb_build_object('ok',false,'error','INVALID_PERCENTAGE_TARGET');end if;select round(sum((e->>'weight_percent')::numeric),4) into v_sum from jsonb_array_elements(p_targets)e;if v_sum<>100.0000 then return jsonb_build_object('ok',false,'error','PERCENTAGES_MUST_SUM_100','sum',v_sum);end if;end if;
 if v_strategy='FIXED' and exists(select 1 from jsonb_array_elements(p_targets)e where not(e?'fixed_quantity') or (e->>'fixed_quantity')::integer<1 or e?'weight_percent') then return jsonb_build_object('ok',false,'error','INVALID_FIXED_TARGET');end if;
 v_ctx:=public.aos_cia_activation_context_summary_v1(p_activation_id);if not coalesce((v_ctx->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error',coalesce(v_ctx->>'error','CONTEXT_NOT_READY'));end if;if coalesce(v_ctx->>'activation_state','')<>'ACTIVE' then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_ACTIVE');end if;
 if exists(select 1 from public.aos_cia_assignment_plans where activation_id=p_activation_id and state in ('DRAFT','ACTIVE','PAUSED')) then return jsonb_build_object('ok',false,'error','OPEN_PLAN_EXISTS');end if;
 insert into public.aos_cia_assignment_plans(activation_id,strategy,ownership_scope,source_limit,lease_minutes,must_start_minutes,topup_policy,topup_target_per_advisor,allow_reassign_released,allow_reassign_expired,idempotency_key,created_by_user_id,updated_by_user_id,metadata)
 values(p_activation_id,v_strategy,v_scope,p_source_limit,p_lease_minutes,p_must_start_minutes,v_topup,p_topup_target_per_advisor,coalesce(p_allow_reassign_released,true),coalesce(p_allow_reassign_expired,true),p_idempotency_key,uid,uid,p_metadata) returning id into v_plan_id;
 insert into public.aos_cia_assignment_targets(plan_id,advisor_user_id,priority,weight_percent,fixed_quantity,capacity_limit)
 select v_plan_id,(e.value->>'advisor_user_id')::uuid,coalesce(nullif(e.value->>'priority','')::integer,(e.ordinality*10)::integer),case when v_strategy='PERCENTAGE' then(e.value->>'weight_percent')::numeric else null end,case when v_strategy='FIXED' then(e.value->>'fixed_quantity')::integer else null end,nullif(e.value->>'capacity_limit','')::integer from jsonb_array_elements(p_targets)with ordinality e(value,ordinality);
 return jsonb_build_object('ok',true,'plan_id',v_plan_id,'state','DRAFT','strategy',v_strategy,'ownership_scope',v_scope,'topup_policy',v_topup,'source_available_now',coalesce((v_ctx->>'available_now')::integer,0),'target_count',v_count);
exception when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('ok',false,'error','INVALID_TARGET_PAYLOAD');when unique_violation then return jsonb_build_object('ok',false,'error','PLAN_CONFLICT');end$$;
revoke all on function public.aos_cia_assignment_candidate_keys_v1(uuid) from public,anon,authenticated;
revoke all on function public.aos_cia_assignment_candidate_count_v1(uuid) from public,anon,authenticated;
revoke all on function public.aos_cia_assignment_plan_create_admin_v1(text,uuid,text,jsonb,text,integer,integer,integer,text,integer,boolean,boolean,text,jsonb) from public,anon,authenticated;
