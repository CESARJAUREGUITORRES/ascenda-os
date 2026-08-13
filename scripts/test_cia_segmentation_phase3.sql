-- ASCENDA OS — CIA Phase 3 Segmentation Engine contract tests
-- Run only where Phase 1 + Phase 2 + Phase 3 migrations are applied.

begin;

-- G01: exactly one current policy must resolve.
do $$
declare n int;
begin
  select count(*) into n from public.aos_cia_current_segmentation_policy_v1;
  if n <> 1 then raise exception 'P3 current policy count expected 1, got %', n; end if;
end $$;

-- G02: segmentation grain must equal Commercial Facts grain.
do $$
declare a int; b int;
begin
  select count(*) into a from public.aos_cia_commercial_facts_v1;
  select count(*) into b from public.aos_cia_customer_segments_v1;
  if a <> b then raise exception 'P3 rowcount mismatch facts=% segments=%', a,b; end if;
end $$;

-- G03: no duplicate contact_key.
do $$
declare n int;
begin
  select count(*) into n
  from (
    select contact_key from public.aos_cia_customer_segments_v1
    group by contact_key having count(*) > 1
  ) d;
  if n <> 0 then raise exception 'P3 duplicate contact keys=%', n; end if;
end $$;

-- G04: enum contracts.
do $$
declare n int;
begin
  select count(*) into n from public.aos_cia_customer_segments_v1
   where value_tier not in ('STANDARD','PREMIUM','GOLD','DIAMANTE')
      or engagement not in ('LOW','MEDIUM','HIGH')
      or lifecycle not in (
        'NEW_CUSTOMER','ACTIVE_CUSTOMER','COOLING_CUSTOMER','INACTIVE_CUSTOMER',
        'APPOINTMENT_READY_PROSPECT','DISQUALIFIED_PROSPECT','ACTIVE_PROSPECT',
        'WARM_PROSPECT','COLD_PROSPECT','PROFILE_ONLY'
      );
  if n <> 0 then raise exception 'P3 invalid enum rows=%', n; end if;
end $$;

-- G05: score component ranges and sum.
do $$
declare n int;
begin
  select count(*) into n from public.aos_cia_customer_segments_v1
   where value_revenue_points not between 0 and 4
      or value_frequency_points not between 0 and 3
      or value_recency_points not between 0 and 2
      or value_score <> value_revenue_points + value_frequency_points + value_recency_points
      or value_score not between 0 and 9;
  if n <> 0 then raise exception 'P3 invalid value score rows=%', n; end if;
end $$;

-- G06: Diamond guardrails must hold.
do $$
declare n int;
begin
  select count(*) into n
  from public.aos_cia_customer_segments_v1 s
  join public.aos_cia_commercial_facts_v1 f using(contact_key)
  where s.value_tier='DIAMANTE'
    and (s.value_score < 8 or f.revenue_lifetime < 5000 or f.sale_count < 5);
  if n <> 0 then raise exception 'P3 invalid DIAMANTE rows=%', n; end if;
end $$;

-- G07: no buyer can be a prospect lifecycle; no non-buyer can be a customer lifecycle.
do $$
declare n int;
begin
  select count(*) into n
  from public.aos_cia_customer_segments_v1 s
  join public.aos_cia_commercial_facts_v1 f using(contact_key)
  where (f.sale_count > 0 and s.lifecycle like '%PROSPECT%')
     or (f.sale_count = 0 and s.lifecycle like '%CUSTOMER%');
  if n <> 0 then raise exception 'P3 lifecycle buyer/prospect mismatch rows=%', n; end if;
end $$;

-- G08: disqualified requires terminal latest state after/no newer lead.
do $$
declare n int;
begin
  select count(*) into n
  from public.aos_cia_customer_segments_v1 s
  join public.aos_cia_commercial_facts_v1 f using(contact_key)
  where s.lifecycle='DISQUALIFIED_PROSPECT'
    and not (
      f.sale_count=0
      and f.latest_call_status in ('NO LE INTERESA','SACAR DE LA BASE')
      and (f.last_lead_at is null or f.last_call_at >= f.last_lead_at)
    );
  if n <> 0 then raise exception 'P3 invalid disqualified rows=%', n; end if;
end $$;

-- G09: explanation/provenance/version must be present.
do $$
declare n int;
begin
  select count(*) into n from public.aos_cia_customer_segments_v1
   where policy_id is null or policy_version is null or policy_status is null
      or explanation is null or facts_provenance is null or calculated_at is null
      or traits is null;
  if n <> 0 then raise exception 'P3 missing explainability rows=%', n; end if;
end $$;

-- G10: segmentation must not emit REACTIVATED in V1.
do $$
declare n int;
begin
  select count(*) into n from public.aos_cia_customer_segments_v1 where lifecycle='REACTIVATED';
  if n <> 0 then raise exception 'P3 REACTIVATED unsupported rows=%', n; end if;
end $$;

rollback;
