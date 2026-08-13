-- ASCENDA OS — CIA Phase 3 Segmentation Engine auditor
-- READ ONLY. Requires Phase 3 objects in target DB.

-- Policy resolved.
select policy_key,version,status,effective_from,effective_to,rules
from public.aos_cia_current_segmentation_policy_v1;

-- Grain and uniqueness.
select
  (select count(*) from public.aos_cia_commercial_facts_v1) facts_rows,
  count(*) segment_rows,
  count(distinct contact_key) distinct_contacts,
  count(*) - count(distinct contact_key) duplicate_rows
from public.aos_cia_customer_segments_v1;

-- Main distributions.
select 'VALUE_TIER' dimension,value_tier value,count(*) n
from public.aos_cia_customer_segments_v1 group by value_tier
union all
select 'LIFECYCLE',lifecycle,count(*)
from public.aos_cia_customer_segments_v1 group by lifecycle
union all
select 'ENGAGEMENT',engagement,count(*)
from public.aos_cia_customer_segments_v1 group by engagement
order by 1,3 desc;

-- Traits distribution.
select trait,count(*) n
from public.aos_cia_customer_segments_v1 s
cross join lateral unnest(s.traits) trait
group by trait order by n desc,trait;

-- Value tier economics.
select s.value_tier,count(*) contacts,
       round(avg(f.revenue_lifetime),2) avg_revenue,
       min(f.revenue_lifetime) min_revenue,
       max(f.revenue_lifetime) max_revenue,
       round(avg(f.sale_count),2) avg_sales,
       min(f.sale_count) min_sales,
       max(f.sale_count) max_sales,
       round(avg(f.days_since_last_sale),1) filter(where f.last_sale_at is not null) avg_days_since_sale
from public.aos_cia_customer_segments_v1 s
join public.aos_cia_commercial_facts_v1 f using(contact_key)
group by s.value_tier
order by case s.value_tier when 'DIAMANTE' then 1 when 'GOLD' then 2 when 'PREMIUM' then 3 else 4 end;

-- Shadow comparison to legacy VIP for uniquely resolved canonical patients only.
select
  coalesce(nullif(btrim(p.etiqueta_vip),''),'NORMAL') legacy_vip,
  s.value_tier shadow_tier,
  count(*) n
from public.aos_cia_customer_segments_v1 s
join public.aos_cia_contact_identity_v1 i using(contact_key)
join public.aos_pacientes p on p."ID_PACIENTE"::text=i.canonical_patient_id
where i.identity_status='RESOLVED'
group by 1,2
order by 1,2;

-- Explainability sample (non-PII identifiers only).
select contact_key,value_tier,value_score,lifecycle,engagement,engagement_score,traits,explanation
from public.aos_cia_customer_segments_v1
order by value_score desc,engagement_score desc,contact_key
limit 25;

-- Contract anomalies. All counts should be zero.
select 'duplicate_contact' check_name,count(*) n from (
  select contact_key from public.aos_cia_customer_segments_v1 group by contact_key having count(*)>1
) q
union all
select 'invalid_tier',count(*) from public.aos_cia_customer_segments_v1 where value_tier not in ('STANDARD','PREMIUM','GOLD','DIAMANTE')
union all
select 'invalid_engagement',count(*) from public.aos_cia_customer_segments_v1 where engagement not in ('LOW','MEDIUM','HIGH')
union all
select 'missing_explanation',count(*) from public.aos_cia_customer_segments_v1 where explanation is null or facts_provenance is null
union all
select 'invalid_value_sum',count(*) from public.aos_cia_customer_segments_v1 where value_score<>value_revenue_points+value_frequency_points+value_recency_points;
