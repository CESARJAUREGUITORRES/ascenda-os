-- ASCENDA OS CIA V3 — Phase 14 deterministic SHADOW engine.
-- SQL/RPC computes; AI interprets later. No operational ownership/source write-path changes.
create or replace function public.aos_cia_intelligence_shadow_refresh_v1(p_actor_user_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public as $function$
declare v_ready jsonb; v_seg jsonb; v_seg_at timestamptz; v_current_cache integer; v_run uuid; v_recs integer; v_now timestamptz:=clock_timestamp();
begin
  if not pg_try_advisory_xact_lock(hashtext('cia_intelligence_shadow_f14_v1')) then return jsonb_build_object('ok',false,'error','REFRESH_BUSY'); end if;
  v_ready:=public.aos_cia_request_f14_readiness_v1();
  if coalesce((v_ready->>'ready_for_f14')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','F14_PREFLIGHT_BLOCKED','readiness',v_ready); end if;
  v_seg:=public.aos_cia_refresh_segment_cache_v2();
  if coalesce((v_seg->>'ok')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','SEGMENT_REFRESH_FAILED','segment_refresh',v_seg); end if;
  v_seg_at:=(v_seg->>'refreshed_at')::timestamptz;
  select count(*)::integer into v_current_cache from public.aos_cia_segment_runtime_cache_v2 where cache_refreshed_at=v_seg_at;
  if v_current_cache<>coalesce((v_seg->>'rows')::integer,-1) then return jsonb_build_object('ok',false,'error','SEGMENT_COVERAGE_MISMATCH','refresh_rows',coalesce((v_seg->>'rows')::integer,-1),'current_cache_rows',v_current_cache,'refreshed_at',v_seg_at); end if;
  insert into public.aos_cia_intelligence_shadow_runs(engine_version,status,source_counts,source_freshness,created_by_user_id,metadata)
  values('F14_V1','RUNNING',jsonb_build_object('segment_rows',v_current_cache),jsonb_build_object('segment_cache_refreshed_at',v_seg_at,'batch_started_at',v_now),p_actor_user_id,jsonb_build_object('mode','SHADOW','autonomous_execution',false,'facts_contract','aos_cia_commercial_facts_v1','segment_contract','aos_cia_segment_runtime_cache_v2','purchase_contract','aos_cia_purchase_detail_facts_v1')) returning id into v_run;
  with facts as materialized (
    select f.contact_key,f.identity_status,f.identity_conflict,f.lead_count,f.call_count,f.appointment_count,f.sale_count,f.followup_count,f.overdue_followup_count,f.days_since_last_sale,f.lead_unworked_since_latest_entry,f.has_future_appointment,f.last_lead_at,f.last_call_at,f.last_appointment_at,f.last_sale_at,f.last_attended_at,f.next_followup_at,f.revenue_lifetime,f.latest_interest,f.latest_interest_type,f.latest_item_type,f.latest_item,f.facts_observed_at from public.aos_cia_commercial_facts_v1 f
  ), purchase as materialized (
    select p.contact_key,p.product_row_count,p.product_mapped_count,p.product_unresolved_count,p.canonical_products,p.product_categories,p.service_row_count,p.service_unresolved_count,p.service_category_unresolved_count,p.canonical_services,p.service_categories,p.observed_at from public.aos_cia_purchase_detail_facts_v1 p
  ), active_owner as (
    select contact_key,(array_agg(id order by assigned_at desc nulls last,created_at desc))[1] assignment_id,(array_agg(advisor_user_id order by assigned_at desc nulls last,created_at desc))[1] advisor_user_id
    from public.aos_cia_assignments where state in ('ASSIGNED','IN_PROGRESS') and expires_at>statement_timestamp() group by contact_key having count(*)=1
  ), base as (
    select f.*,s.value_tier,s.value_score,s.lifecycle,s.engagement,s.engagement_score,s.traits,p.product_row_count,p.product_mapped_count,p.product_unresolved_count,p.canonical_products,p.product_categories,p.service_row_count,p.service_unresolved_count,p.service_category_unresolved_count,p.canonical_services,p.service_categories,o.assignment_id,o.advisor_user_id,
      (coalesce(f.lead_count,0)+coalesce(f.call_count,0)+coalesce(f.appointment_count,0)+coalesce(f.sale_count,0)+coalesce(f.followup_count,0)+coalesce(p.product_row_count,0)+coalesce(p.service_row_count,0))::integer evidence_sample_size,
      case when coalesce(f.lead_count,0)+coalesce(f.call_count,0)+coalesce(f.appointment_count,0)+coalesce(f.sale_count,0)+coalesce(f.followup_count,0)=0 then null::date else greatest(coalesce(f.last_lead_at::date,date '1900-01-01'),coalesce(f.last_call_at::date,date '1900-01-01'),coalesce(f.last_appointment_at,date '1900-01-01'),coalesce(f.last_sale_at,date '1900-01-01'),coalesce(f.last_attended_at,date '1900-01-01'),coalesce(f.next_followup_at,date '1900-01-01')) end latest_evidence_date
    from facts f join public.aos_cia_segment_runtime_cache_v2 s on s.contact_key=f.contact_key and s.cache_refreshed_at=v_seg_at left join purchase p on p.contact_key=f.contact_key left join active_owner o on o.contact_key=f.contact_key
    where f.identity_status='RESOLVED' and coalesce(f.identity_conflict,false)=false
  ), candidates as (
    select b.*,x.opportunity_type,x.base_score,x.reason_code from base b cross join lateral (values
      ('UNWORKED_LEAD'::text,90::integer,'LEAD_NOT_WORKED'::text,coalesce(b.lead_unworked_since_latest_entry,false)),
      ('FOLLOWUP_RECOVERY',85+least(coalesce(b.overdue_followup_count,0)*2,10),'FOLLOWUP_OVERDUE',coalesce(b.overdue_followup_count,0)>0),
      ('REACTIVATION',70,'CUSTOMER_COOLING_OR_INACTIVE',b.lifecycle in ('COOLING_CUSTOMER','INACTIVE_CUSTOMER') and not coalesce(b.has_future_appointment,false)),
      ('REPURCHASE_SIGNAL',65,'REPEAT_BUYER_CYCLE',coalesce(b.sale_count,0)>=2 and b.days_since_last_sale between 45 and 365 and not coalesce(b.has_future_appointment,false)),
      ('HIGH_VALUE_ATTENTION',80,'HIGH_VALUE_WITHOUT_FUTURE_APPOINTMENT',b.value_tier in ('GOLD','DIAMANTE') and not coalesce(b.has_future_appointment,false) and (b.lifecycle in ('COOLING_CUSTOMER','INACTIVE_CUSTOMER') or coalesce(b.days_since_last_sale,0)>=60))
    ) x(opportunity_type,base_score,reason_code,enabled) where x.enabled
  )
  insert into public.aos_cia_intelligence_recommendations(run_id,contact_key,assignment_id,advisor_user_id,opportunity_type,priority_score,confidence,sample_size,freshness_status,evidence,explanation,observed_affinity,proposed_action,policy_decision,state)
  select v_run,c.contact_key,c.assignment_id,c.advisor_user_id,c.opportunity_type,
    least(100,greatest(0,c.base_score+case when c.value_tier='DIAMANTE' then 8 when c.value_tier='GOLD' then 5 else 0 end)),
    case when c.evidence_sample_size>=8 and coalesce(c.product_unresolved_count,0)=0 and coalesce(c.service_unresolved_count,0)=0 and coalesce(c.service_category_unresolved_count,0)=0 then 'HIGH' when c.evidence_sample_size>=3 then 'MEDIUM' else 'LOW' end,
    c.evidence_sample_size,
    case when c.latest_evidence_date is null then 'UNKNOWN' when ((statement_timestamp() at time zone 'America/Lima')::date-c.latest_evidence_date)<=30 then 'FRESH' when ((statement_timestamp() at time zone 'America/Lima')::date-c.latest_evidence_date)<=90 then 'AGING' else 'STALE' end,
    jsonb_build_object('reason_code',c.reason_code,'value_tier',c.value_tier,'value_score',c.value_score,'lifecycle',c.lifecycle,'engagement',c.engagement,'engagement_score',c.engagement_score,'lead_count',coalesce(c.lead_count,0),'call_count',coalesce(c.call_count,0),'appointment_count',coalesce(c.appointment_count,0),'sale_count',coalesce(c.sale_count,0),'followup_count',coalesce(c.followup_count,0),'overdue_followup_count',coalesce(c.overdue_followup_count,0),'days_since_last_sale',c.days_since_last_sale,'has_future_appointment',c.has_future_appointment,'revenue_lifetime',coalesce(c.revenue_lifetime,0),'latest_interest',c.latest_interest,'latest_interest_type',c.latest_interest_type,'latest_item_type',c.latest_item_type,'latest_item',c.latest_item,'latest_evidence_date',c.latest_evidence_date,'facts_observed_at',c.facts_observed_at,'segment_cache_refreshed_at',v_seg_at),
    jsonb_build_object('engine','F14_V1','mode','SHADOW','deterministic',true,'why',c.reason_code,'rule',case c.opportunity_type when 'UNWORKED_LEAD' then 'Latest lead has no qualifying work evidence after entry.' when 'FOLLOWUP_RECOVERY' then 'At least one follow-up is overdue.' when 'REACTIVATION' then 'Commercial lifecycle is cooling/inactive and no future appointment is present.' when 'REPURCHASE_SIGNAL' then 'Observed repeat-buyer history and elapsed time since last sale fall inside the deterministic review window.' when 'HIGH_VALUE_ATTENTION' then 'High commercial value tier with no future appointment and cooling/inactivity or elapsed purchase time.' end,'limitations',jsonb_build_array('Recommendation is not a causal prediction.','SHADOW output cannot autoassign, approve or execute.','Observed affinity reflects recorded commercial purchases only.')),
    jsonb_build_object('canonical_products',coalesce(to_jsonb(c.canonical_products),'[]'::jsonb),'product_categories',coalesce(to_jsonb(c.product_categories),'[]'::jsonb),'canonical_services',coalesce(to_jsonb(c.canonical_services),'[]'::jsonb),'service_categories',coalesce(to_jsonb(c.service_categories),'[]'::jsonb),'product_unresolved_count',coalesce(c.product_unresolved_count,0),'service_unresolved_count',coalesce(c.service_unresolved_count,0),'service_category_unresolved_count',coalesce(c.service_category_unresolved_count,0)),
    null,'{"decision":"SHADOW_ONLY","auto_execute":false}'::jsonb,'SHADOW' from candidates c;
  get diagnostics v_recs=row_count;
  insert into public.aos_cia_intelligence_events(recommendation_id,event_type,payload) select id,'GENERATED',jsonb_build_object('run_id',v_run,'engine_version','F14_V1','state','SHADOW') from public.aos_cia_intelligence_recommendations where run_id=v_run;
  update public.aos_cia_intelligence_shadow_runs set status='COMPLETE',completed_at=clock_timestamp(),recommendation_count=v_recs,source_counts=source_counts||jsonb_build_object('recommendations',v_recs),source_freshness=source_freshness||jsonb_build_object('batch_completed_at',clock_timestamp()) where id=v_run;
  return jsonb_build_object('ok',true,'run_id',v_run,'status','COMPLETE','mode','SHADOW','recommendations',v_recs,'segment_rows',v_current_cache,'segment_refreshed_at',v_seg_at,'autonomous_execution',false);
end $function$;
revoke all on function public.aos_cia_intelligence_shadow_refresh_v1(uuid) from public,anon,authenticated;
comment on function public.aos_cia_intelligence_shadow_refresh_v1(uuid) is 'F14 deterministic batch. Refreshes/proves F3 segment cache and persists explainable SHADOW recommendations; never mutates operational ownership.';
