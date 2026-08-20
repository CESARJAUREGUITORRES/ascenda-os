-- REV-F6.4 — Sales Intelligence 3.0 V1
-- Read-model / analytics layer only. No mutation of patient, sale, F3, F4, F5 identity or upstream F6 certified truth.

begin;

-- -----------------------------------------------------------------------------
-- 1) SALES FACT READ MODEL — one row per certified sale, no raw PII/PHI.
-- -----------------------------------------------------------------------------
create materialized view if not exists public.aos_rev_si_sales_fact_v1 as
select
  v.id::bigint sale_id,
  v.fecha::date sale_date,
  extract(year from v.fecha)::integer sale_year,
  extract(month from v.fecha)::integer sale_month,
  date_trunc('month',v.fecha)::date sale_month_start,
  coalesce(nullif(trim(v.sede),''),'SIN_SEDE')::text sede,
  coalesce(nullif(trim(v.asesor),''),'SIN_ASESOR')::text advisor,
  coalesce(v.monto,0)::numeric billed_amount,
  case when upper(trim(coalesce(v.tratamiento,'')))='OTROS' then 'SERVICIO' else upper(trim(coalesce(v.tipo,''))) end::text sale_type,
  j.canonical_patient_id::text canonical_patient_id,
  coalesce(j.patient_link_status,'UNRESOLVED')::text patient_link_status,
  coalesce(j.patient_link_method,'NONE')::text patient_link_method,
  coalesce(j.patient_candidate_count,0)::integer patient_candidate_count,
  coalesce(f.resolution_status,'NOT_APPLICABLE')::text product_resolution_status,
  f.product_key::text product_key,
  f.canonical_name::text canonical_product_name,
  coalesce(j.cartera_link_status,'NO_F4_LINK')::text f4_link_status,
  coalesce(j.cartera_row_count,0)::integer f4_row_count,
  coalesce(j.payment_evidence_row_count,0)::integer payment_evidence_row_count,
  coalesce(j.confirmed_balance_row_count,0)::integer confirmed_balance_row_count,
  (coalesce(j.patient_link_status,'')='MATCH' and j.canonical_patient_id is not null)::boolean safe_patient_attribution,
  (coalesce(f.resolution_status,'')='RESOLVED' and f.product_key is not null)::boolean safe_product_attribution,
  (coalesce(j.cartera_link_status,'')='F4_LINKED')::boolean has_f4_evidence
from public.aos_ventas v
left join public.aos_f5_historical_join_v1 j on j.sale_id=v.id
left join public.aos_product_sale_fact_current_v1 f on f.sale_id=v.id;

create unique index if not exists aos_rev_si_sales_fact_v1_sale_uq on public.aos_rev_si_sales_fact_v1(sale_id);
create index if not exists aos_rev_si_sales_fact_v1_period_idx on public.aos_rev_si_sales_fact_v1(sale_year,sale_month,sede,advisor);
create index if not exists aos_rev_si_sales_fact_v1_patient_idx on public.aos_rev_si_sales_fact_v1(canonical_patient_id) where safe_patient_attribution;
create index if not exists aos_rev_si_sales_fact_v1_product_idx on public.aos_rev_si_sales_fact_v1(product_key) where safe_product_attribution;
comment on materialized view public.aos_rev_si_sales_fact_v1 is
'REV-F6.4 zero-PII sale fact read model. Executive billed revenue uses all certified sales; patient-level intelligence uses safe_patient_attribution only.';
revoke all on public.aos_rev_si_sales_fact_v1 from public,anon,authenticated;
grant select on public.aos_rev_si_sales_fact_v1 to service_role;

-- -----------------------------------------------------------------------------
-- 2) MONTHLY EXECUTIVE PREAGGREGATION.
-- -----------------------------------------------------------------------------
create materialized view if not exists public.aos_rev_si_monthly_v1 as
select
  sale_year,
  sale_month,
  sale_month_start,
  sede,
  advisor,
  count(*)::integer transactions,
  coalesce(sum(billed_amount),0)::numeric billed_amount,
  case when count(*)>0 then round(sum(billed_amount)/count(*),2) else 0 end::numeric avg_ticket,
  count(*) filter(where safe_patient_attribution)::integer safe_patient_sales,
  count(*) filter(where patient_link_status='REVIEW')::integer review_patient_sales,
  count(*) filter(where patient_link_status='UNRESOLVED')::integer unresolved_patient_sales,
  count(*) filter(where safe_product_attribution)::integer resolved_product_sales,
  count(*) filter(where has_f4_evidence)::integer f4_evidence_sales,
  coalesce(sum(billed_amount) filter(where has_f4_evidence),0)::numeric billed_amount_with_f4_evidence,
  count(*) filter(where payment_evidence_row_count>0)::integer payment_evidence_sales,
  count(*) filter(where confirmed_balance_row_count>0)::integer confirmed_balance_sales
from public.aos_rev_si_sales_fact_v1
where sale_year=2026
group by sale_year,sale_month,sale_month_start,sede,advisor;

create unique index if not exists aos_rev_si_monthly_v1_uq on public.aos_rev_si_monthly_v1(sale_year,sale_month,sede,advisor);
create index if not exists aos_rev_si_monthly_v1_period_idx on public.aos_rev_si_monthly_v1(sale_year,sale_month);
comment on materialized view public.aos_rev_si_monthly_v1 is
'REV-F6.4 monthly set-based preaggregation. F4 evidence coverage is not collected-cash truth.';
revoke all on public.aos_rev_si_monthly_v1 from public,anon,authenticated;
grant select on public.aos_rev_si_monthly_v1 to service_role;

-- -----------------------------------------------------------------------------
-- 3) OBSERVED PATIENT VALUE — MATCH-only, never predicted LTV.
-- -----------------------------------------------------------------------------
create materialized view if not exists public.aos_rev_si_patient_value_v1 as
with ranked as (
  select
    s.*,
    row_number() over(partition by canonical_patient_id order by sale_date,sale_id)::integer rn,
    lead(sale_date) over(partition by canonical_patient_id order by sale_date,sale_id) next_sale_date
  from public.aos_rev_si_sales_fact_v1 s
  where s.sale_year=2026 and s.safe_patient_attribution
), agg as (
  select
    canonical_patient_id,
    min(sale_date)::date first_observed_purchase,
    max(sale_date)::date last_observed_purchase,
    min(sale_date) filter(where rn=2)::date second_observed_purchase,
    count(*)::integer observed_purchase_count,
    coalesce(sum(billed_amount),0)::numeric observed_value,
    count(*) filter(where safe_product_attribution)::integer resolved_product_purchase_count,
    count(*) filter(where has_f4_evidence)::integer f4_evidence_purchase_count
  from ranked
  group by canonical_patient_id
)
select
  a.*,
  case when second_observed_purchase is not null then (second_observed_purchase-first_observed_purchase)::integer else null end time_to_second_days,
  (observed_purchase_count>=2)::boolean repeat_observed,
  'OBSERVED_VALUE_NOT_LIFETIME_PREDICTION'::text value_semantic,
  '2026_CERTIFIED_SALES_SCOPE'::text source_period
from agg a;

create unique index if not exists aos_rev_si_patient_value_v1_patient_uq on public.aos_rev_si_patient_value_v1(canonical_patient_id);
create index if not exists aos_rev_si_patient_value_v1_first_idx on public.aos_rev_si_patient_value_v1(first_observed_purchase);
comment on materialized view public.aos_rev_si_patient_value_v1 is
'REV-F6.4 MATCH-only observed patient value. It is not predicted future LTV and not lifetime truth outside certified transactional coverage.';
revoke all on public.aos_rev_si_patient_value_v1 from public,anon,authenticated;
grant select on public.aos_rev_si_patient_value_v1 to service_role;

-- -----------------------------------------------------------------------------
-- 4) COHORT / RETENTION READ MODEL — MATCH-only.
-- -----------------------------------------------------------------------------
create materialized view if not exists public.aos_rev_si_cohort_month_v1 as
with cohort as (
  select
    p.canonical_patient_id,
    date_trunc('month',p.first_observed_purchase)::date cohort_month,
    p.first_observed_purchase,
    p.second_observed_purchase,
    p.time_to_second_days,
    p.repeat_observed,
    p.observed_purchase_count,
    p.observed_value
  from public.aos_rev_si_patient_value_v1 p
), sale_followup as (
  select
    c.*,
    count(s.sale_id) filter(where s.sale_date>c.first_observed_purchase and s.sale_date<=c.first_observed_purchase+30)::integer purchases_within_30d,
    count(s.sale_id) filter(where s.sale_date>c.first_observed_purchase and s.sale_date<=c.first_observed_purchase+90)::integer purchases_within_90d
  from cohort c
  left join public.aos_rev_si_sales_fact_v1 s on s.canonical_patient_id=c.canonical_patient_id and s.safe_patient_attribution
  group by c.canonical_patient_id,c.cohort_month,c.first_observed_purchase,c.second_observed_purchase,c.time_to_second_days,c.repeat_observed,c.observed_purchase_count,c.observed_value
)
select
  cohort_month,
  count(*)::integer cohort_patients,
  count(*) filter(where repeat_observed)::integer repeat_patients,
  round(100.0*count(*) filter(where repeat_observed)/nullif(count(*),0),2)::numeric repeat_rate_pct,
  count(*) filter(where purchases_within_30d>0)::integer repeat_30d_patients,
  round(100.0*count(*) filter(where purchases_within_30d>0)/nullif(count(*),0),2)::numeric repeat_30d_pct,
  count(*) filter(where purchases_within_90d>0)::integer repeat_90d_patients,
  round(100.0*count(*) filter(where purchases_within_90d>0)/nullif(count(*),0),2)::numeric repeat_90d_pct,
  round(avg(time_to_second_days) filter(where time_to_second_days is not null),2)::numeric avg_time_to_second_days,
  coalesce(sum(observed_value),0)::numeric observed_cohort_value,
  'MATCH_ONLY_SAFE_IDENTITY'::text identity_semantic
from sale_followup
group by cohort_month;

create unique index if not exists aos_rev_si_cohort_month_v1_uq on public.aos_rev_si_cohort_month_v1(cohort_month);
comment on materialized view public.aos_rev_si_cohort_month_v1 is
'REV-F6.4 retention/cohort model. First observed purchase is within certified 2026 transactional scope; it is not guaranteed lifetime first purchase.';
revoke all on public.aos_rev_si_cohort_month_v1 from public,anon,authenticated;
grant select on public.aos_rev_si_cohort_month_v1 to service_role;

-- -----------------------------------------------------------------------------
-- 5) PRODUCT / CROSS-SELL TRANSITIONS — F3 RESOLVED + MATCH identity only.
-- -----------------------------------------------------------------------------
create materialized view if not exists public.aos_rev_si_product_transition_v1 as
with seq as (
  select
    canonical_patient_id,
    sale_id,
    sale_date,
    product_key,
    canonical_product_name,
    lead(product_key) over(partition by canonical_patient_id order by sale_date,sale_id) next_product_key,
    lead(canonical_product_name) over(partition by canonical_patient_id order by sale_date,sale_id) next_product_name
  from public.aos_rev_si_sales_fact_v1
  where sale_year=2026 and safe_patient_attribution and safe_product_attribution
)
select
  product_key,
  canonical_product_name,
  next_product_key,
  next_product_name,
  count(*)::integer transition_count,
  count(distinct canonical_patient_id)::integer patient_sample_size,
  'F3_RESOLVED_MATCH_IDENTITY_ONLY'::text evidence_semantic
from seq
where next_product_key is not null
group by product_key,canonical_product_name,next_product_key,next_product_name;

create unique index if not exists aos_rev_si_product_transition_v1_uq on public.aos_rev_si_product_transition_v1(product_key,next_product_key);
comment on materialized view public.aos_rev_si_product_transition_v1 is
'REV-F6.4 observed next-product transitions. Sample size is explicit; no recommendation causal claim.';
revoke all on public.aos_rev_si_product_transition_v1 from public,anon,authenticated;
grant select on public.aos_rev_si_product_transition_v1 to service_role;

-- -----------------------------------------------------------------------------
-- 6) EXPLICIT ACQUISITION→REVENUE FACT — no phone-only attribution.
-- -----------------------------------------------------------------------------
create materialized view if not exists public.aos_rev_si_acquisition_fact_v1 as
select distinct on (v.id)
  v.id::bigint sale_id,
  v.fecha::date sale_date,
  coalesce(v.monto,0)::numeric billed_amount,
  c.id::text appointment_id,
  c.fecha_cita::date appointment_date,
  c.lead_id_origen::bigint lead_id,
  c.llamada_id_origen::bigint call_id,
  c.etiqueta_campana::text campaign_label,
  c.origen_cita::text appointment_origin,
  'EXPLICIT_AGENDA_VENTA_ID_MATCH_PLUS_LEAD_LINEAGE'::text attribution_method
from public.aos_ventas v
join public.aos_agenda_citas c
  on nullif(trim(c.venta_id_match),'') in (v.id::text,coalesce(v.venta_id,''))
where c.lead_id_origen is not null
  and v.fecha>=c.fecha_cita
order by v.id,c.fecha_cita desc,c.id;

create unique index if not exists aos_rev_si_acquisition_fact_v1_sale_uq on public.aos_rev_si_acquisition_fact_v1(sale_id);
create index if not exists aos_rev_si_acquisition_fact_v1_lead_idx on public.aos_rev_si_acquisition_fact_v1(lead_id);
comment on materialized view public.aos_rev_si_acquisition_fact_v1 is
'REV-F6.4 acquisition-to-revenue fact. Only explicit Agenda sale-id + lead lineage qualifies; phone-only or phone-near matching is prohibited.';
revoke all on public.aos_rev_si_acquisition_fact_v1 from public,anon,authenticated;
grant select on public.aos_rev_si_acquisition_fact_v1 to service_role;

-- -----------------------------------------------------------------------------
-- 7) SERVICE-ONLY PATIENT OBSERVED VALUE DETAIL.
-- -----------------------------------------------------------------------------
create or replace function public.aos_rev_si_patient_value_by_patient_v1(p_canonical_patient_id text)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
select case when p.canonical_patient_id is null then
  jsonb_build_object(
    'contract','REV-F6.4_PATIENT_VALUE_V1',
    'canonical_patient_id',p_canonical_patient_id,
    'source_status','NO_SAFE_MATCHED_SALES',
    'value',null,
    'semantic','OBSERVED_VALUE_NOT_LIFETIME_PREDICTION'
  )
else jsonb_build_object(
  'contract','REV-F6.4_PATIENT_VALUE_V1',
  'canonical_patient_id',p.canonical_patient_id,
  'source_status','AVAILABLE_MATCH_ONLY',
  'observed_value',p.observed_value,
  'observed_purchase_count',p.observed_purchase_count,
  'first_observed_purchase',p.first_observed_purchase,
  'second_observed_purchase',p.second_observed_purchase,
  'last_observed_purchase',p.last_observed_purchase,
  'repeat_observed',p.repeat_observed,
  'time_to_second_days',p.time_to_second_days,
  'resolved_product_purchase_count',p.resolved_product_purchase_count,
  'f4_evidence_purchase_count',p.f4_evidence_purchase_count,
  'source_period',p.source_period,
  'semantic',p.value_semantic,
  'limitations',jsonb_build_array('MATCH_ONLY_PATIENT_LINKAGE','2024_2025_TRANSACTIONAL_SALES_NO_CERTIFIED_SOURCE','FIRST_OBSERVED_PURCHASE_IS_WITHIN_CERTIFIED_SCOPE')
) end
from (select 1) seed
left join public.aos_rev_si_patient_value_v1 p on p.canonical_patient_id=p_canonical_patient_id;
$$;
comment on function public.aos_rev_si_patient_value_by_patient_v1(text) is
'REV-F6.4 service-only observed patient commercial value. Null means no safe matched-sale evidence, not zero lifetime value.';
revoke all on function public.aos_rev_si_patient_value_by_patient_v1(text) from public,anon,authenticated;
grant execute on function public.aos_rev_si_patient_value_by_patient_v1(text) to service_role;

-- -----------------------------------------------------------------------------
-- 8) SALES INTELLIGENCE 3.0 SERVICE CONTRACT.
-- -----------------------------------------------------------------------------
create or replace function public.aos_rev_sales_intelligence_v3(
  p_anio integer,
  p_sede text default '',
  p_asesor text default ''
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_sede text := upper(trim(coalesce(p_sede,'')));
  v_asesor text := trim(coalesce(p_asesor,''));
  v_data_through date;
  v_business_date date := public.aos_rev_business_date_lima_v1();
  v_month integer;
  v_day integer;
  v_days_month integer;
  v_billed numeric := 0;
  v_tx bigint := 0;
  v_safe bigint := 0;
  v_review bigint := 0;
  v_unresolved bigint := 0;
  v_f3 bigint := 0;
  v_f4 bigint := 0;
  v_f4_billed numeric := 0;
  v_payment_evidence bigint := 0;
  v_confirmed_balance bigint := 0;
  v_mtd numeric := 0;
  v_mtd_tx bigint := 0;
  v_target_mtd numeric;
  v_target_ytd numeric := 0;
  v_target_annual numeric := 0;
  v_projection numeric;
  v_cohorts jsonb := '[]'::jsonb;
  v_products jsonb := '[]'::jsonb;
  v_transitions jsonb := '[]'::jsonb;
  v_sede_perf jsonb := '[]'::jsonb;
  v_advisor_perf jsonb := '[]'::jsonb;
  v_acq_count bigint := 0;
  v_acq_value numeric := 0;
  v_geo_n bigint := 0;
  v_sex_n bigint := 0;
  v_district_n bigint := 0;
  v_city_n bigint := 0;
  v_dept_n bigint := 0;
  v_dob_n bigint := 0;
  v_demo_threshold numeric := 70.0;
  v_min_cell integer := 5;
  v_now timestamptz := clock_timestamp();
  v_metric_baseline jsonb;
  v_hist_2024 jsonb;
  v_hist_2025 jsonb;
  v_exec_trust jsonb;
  v_identity_trust jsonb;
  v_f3_trust jsonb;
  v_f4_trust jsonb;
  v_acq_trust jsonb;
  v_monthly jsonb := '[]'::jsonb;
  v_patient_value jsonb;
begin
  if p_anio not between 2020 and 2100 then
    return jsonb_build_object('ok',false,'error','INVALID_YEAR');
  end if;
  if v_sede not in ('','SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'error','INVALID_FILTER');
  end if;

  select max(sale_date),coalesce(sum(billed_amount),0),count(*)::bigint,
         count(*) filter(where safe_patient_attribution)::bigint,
         count(*) filter(where patient_link_status='REVIEW')::bigint,
         count(*) filter(where patient_link_status='UNRESOLVED')::bigint,
         count(*) filter(where safe_product_attribution)::bigint,
         count(*) filter(where has_f4_evidence)::bigint,
         coalesce(sum(billed_amount) filter(where has_f4_evidence),0),
         count(*) filter(where payment_evidence_row_count>0)::bigint,
         count(*) filter(where confirmed_balance_row_count>0)::bigint
  into v_data_through,v_billed,v_tx,v_safe,v_review,v_unresolved,v_f3,v_f4,v_f4_billed,v_payment_evidence,v_confirmed_balance
  from public.aos_rev_si_sales_fact_v1
  where sale_year=p_anio and (v_sede='' or sede=v_sede) and (v_asesor='' or advisor=v_asesor);

  if v_data_through is null then
    return jsonb_build_object(
      'ok',true,'hasData',false,'contract','REV-F6.4_SALES_INTELLIGENCE_3_V1','anio',p_anio,
      'source_status',case when p_anio in (2024,2025) then 'NO_CERTIFIED_SOURCE' else 'NO_ROWS_IN_FILTER' end,
      'value',null,
      'limitations',case when p_anio in (2024,2025) then jsonb_build_array('NO_CERTIFIED_SOURCE_NE_ZERO_REVENUE') else jsonb_build_array('NO_ROWS_MATCH_FILTER') end,
      'historical_source_status',jsonb_build_object('2024','NO_CERTIFIED_SOURCE','2025','NO_CERTIFIED_SOURCE','2026','AVAILABLE')
    );
  end if;

  v_month:=extract(month from v_data_through)::integer;
  v_day:=extract(day from v_data_through)::integer;
  v_days_month:=extract(day from (date_trunc('month',v_data_through)+interval '1 month - 1 day'))::integer;

  select coalesce(sum(s.billed_amount),0),count(*)::bigint
  into v_mtd,v_mtd_tx
  from public.aos_rev_si_sales_fact_v1 s
  where s.sale_year=p_anio and s.sale_month=v_month and s.sale_date<=v_data_through
    and (v_sede='' or s.sede=v_sede) and (v_asesor='' or s.advisor=v_asesor);

  select coalesce(sum(m.meta),0),max(m.meta) filter(where m.periodo=p_anio::text||'-'||lpad(v_month::text,2,'0'))
  into v_target_annual,v_target_mtd
  from public.aos_metas_ventas m where m.periodo like p_anio::text||'-%';

  select coalesce(sum(m.meta),0) into v_target_ytd
  from public.aos_metas_ventas m
  where m.periodo between p_anio::text||'-01' and p_anio::text||'-'||lpad(v_month::text,2,'0');

  v_projection := case when v_day>0 and v_data_through < (date_trunc('month',v_data_through)+interval '1 month - 1 day')::date
    then round(v_mtd/v_day*v_days_month,2) else v_mtd end;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.cohort_month),'[]'::jsonb) into v_cohorts
  from public.aos_rev_si_cohort_month_v1 c
  where extract(year from c.cohort_month)::integer=p_anio;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.observed_value desc,x.canonical_product_name),'[]'::jsonb) into v_products
  from (
    select s.product_key,s.canonical_product_name,count(*)::integer transactions,
           count(distinct s.canonical_patient_id) filter(where s.safe_patient_attribution)::integer safe_patient_sample_size,
           coalesce(sum(s.billed_amount),0)::numeric observed_value
    from public.aos_rev_si_sales_fact_v1 s
    where s.sale_year=p_anio and s.safe_product_attribution
      and (v_sede='' or s.sede=v_sede) and (v_asesor='' or s.advisor=v_asesor)
    group by s.product_key,s.canonical_product_name
    order by observed_value desc,s.canonical_product_name
    limit 20
  ) x;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.transition_count desc,t.product_key,t.next_product_key),'[]'::jsonb) into v_transitions
  from (select * from public.aos_rev_si_product_transition_v1 order by transition_count desc,product_key,next_product_key limit 30) t;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.billed_amount desc,x.sede),'[]'::jsonb) into v_sede_perf
  from (
    select s.sede,count(*)::integer transactions,coalesce(sum(s.billed_amount),0)::numeric billed_amount,
           round(100.0*count(*) filter(where s.safe_patient_attribution)/nullif(count(*),0),2)::numeric patient_link_coverage_pct,
           round(100.0*count(*) filter(where s.safe_product_attribution)/nullif(count(*),0),2)::numeric product_coverage_pct
    from public.aos_rev_si_sales_fact_v1 s where s.sale_year=p_anio and (v_asesor='' or s.advisor=v_asesor)
    group by s.sede
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.billed_amount desc,x.advisor),'[]'::jsonb) into v_advisor_perf
  from (
    select s.advisor,count(*)::integer transactions,coalesce(sum(s.billed_amount),0)::numeric billed_amount,
           round(100.0*count(*) filter(where s.safe_patient_attribution)/nullif(count(*),0),2)::numeric patient_link_coverage_pct,
           round(100.0*count(*) filter(where s.safe_product_attribution)/nullif(count(*),0),2)::numeric product_coverage_pct
    from public.aos_rev_si_sales_fact_v1 s where s.sale_year=p_anio and (v_sede='' or s.sede=v_sede)
    group by s.advisor
  ) x;

  select count(*)::bigint,coalesce(sum(billed_amount),0)::numeric into v_acq_count,v_acq_value
  from public.aos_rev_si_acquisition_fact_v1 a where extract(year from a.sale_date)::integer=p_anio;

  with safe_patients as (
    select distinct s.canonical_patient_id
    from public.aos_rev_si_sales_fact_v1 s
    where s.sale_year=p_anio and s.safe_patient_attribution and (v_sede='' or s.sede=v_sede) and (v_asesor='' or s.advisor=v_asesor)
  )
  select count(*)::bigint,
    count(*) filter(where nullif(trim(coalesce(p."Sexo",'')),'') is not null)::bigint,
    count(*) filter(where nullif(trim(coalesce(p.distrito,'')),'') is not null)::bigint,
    count(*) filter(where nullif(trim(coalesce(p.ciudad,'')),'') is not null)::bigint,
    count(*) filter(where nullif(trim(coalesce(p.departamento,'')),'') is not null)::bigint,
    count(*) filter(where nullif(trim(coalesce(p."Fecha de nacimiento",'')),'') is not null)::bigint
  into v_geo_n,v_sex_n,v_district_n,v_city_n,v_dept_n,v_dob_n
  from public.aos_pacientes p join safe_patients sp on sp.canonical_patient_id=p."ID_PACIENTE"
  where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO';

  select coalesce(jsonb_agg(to_jsonb(x) order by x.sale_month),'[]'::jsonb) into v_monthly
  from (
    select s.sale_month,
      count(*)::integer transactions,
      coalesce(sum(s.billed_amount),0)::numeric billed_amount,
      case when count(*)>0 then round(sum(s.billed_amount)/count(*),2) else 0 end::numeric avg_ticket,
      count(*) filter(where s.safe_patient_attribution)::integer safe_patient_sales,
      count(*) filter(where s.safe_product_attribution)::integer resolved_product_sales,
      count(*) filter(where s.has_f4_evidence)::integer f4_evidence_sales
    from public.aos_rev_si_sales_fact_v1 s
    where s.sale_year=p_anio and (v_sede='' or s.sede=v_sede) and (v_asesor='' or s.advisor=v_asesor)
    group by s.sale_month
  ) x;

  select jsonb_build_object(
    'patients',count(*)::integer,
    'repeat_patients',count(*) filter(where repeat_observed)::integer,
    'repeat_rate_pct',round(100.0*count(*) filter(where repeat_observed)/nullif(count(*),0),2),
    'observed_value',coalesce(sum(observed_value),0),
    'avg_observed_value',round(avg(observed_value),2),
    'avg_time_to_second_days',round(avg(time_to_second_days) filter(where time_to_second_days is not null),2),
    'semantic','OBSERVED_VALUE_NOT_LIFETIME_PREDICTION',
    'source_period','2026_CERTIFIED_SALES_SCOPE'
  ) into v_patient_value
  from public.aos_rev_si_patient_value_v1;

  v_metric_baseline:=public.aos_rev_metric_trust_baseline_v1();
  v_hist_2024:=v_metric_baseline->'TRANSACTIONAL_SALES_2024';
  v_hist_2025:=v_metric_baseline->'TRANSACTIONAL_SALES_2025';

  v_exec_trust:=public.aos_rev_metric_trust_envelope_v1(
    'F6_4_EXECUTIVE_REVENUE',to_jsonb(v_billed),v_tx,v_tx,'CERTIFIED_SALES_ROWS_IN_FILTER',v_tx,
    'AVAILABLE','2026_CERTIFIED_SALES_SCOPE',(select max(updated_at) from public.aos_ventas),v_now,v_now,'HIGH',
    jsonb_build_array('DIRECT_AOS_VENTAS_FACT'),jsonb_build_array('BILLED_REVENUE_NOT_CONFIRMED_COLLECTED_CASH'),jsonb_build_array('aos_ventas','REV-F6.4')
  );
  v_identity_trust:=public.aos_rev_metric_trust_envelope_v1(
    'F6_4_SAFE_PATIENT_LINKAGE',to_jsonb(v_safe),v_safe,v_tx,'MATCH_ONLY_SALES_TO_CANONICAL_PATIENT',v_tx,
    'AVAILABLE_PARTIAL_COVERAGE','2026_CERTIFIED_SALES_SCOPE',(select max(generated_at) from public.aos_f5_historical_join_v1),v_now,v_now,'HIGH',
    jsonb_build_array('REV_F5_MATCH_ONLY'),jsonb_build_array('REVIEW_AND_UNRESOLVED_SALES_EXCLUDED_FROM_PATIENT_ANALYTICS'),jsonb_build_array('REV-F5','REV-F6.4')
  );
  v_f3_trust:=public.aos_rev_metric_trust_envelope_v1(
    'F6_4_PRODUCT_RESOLUTION',to_jsonb(v_f3),v_f3,v_tx,'F3_RESOLVED_SALES_IN_FILTER',v_tx,
    'AVAILABLE_PARTIAL_COVERAGE','2026_CERTIFIED_SALES_SCOPE',(select max(updated_at) from public.aos_ventas),v_now,v_now,'HIGH',
    jsonb_build_array('F3_CANONICAL_PRODUCT_TRUTH'),jsonb_build_array('UNRESOLVED_PRODUCT_FACTS_EXCLUDED_FROM_CANONICAL_PRODUCT_PATTERNS'),jsonb_build_array('REV-F3','REV-F6.4')
  );
  v_f4_trust:=public.aos_rev_metric_trust_envelope_v1(
    'F6_4_FINANCIAL_EVIDENCE',to_jsonb(v_f4),v_f4,v_tx,'F4_LINKED_FINANCIAL_EVIDENCE',v_tx,
    'AVAILABLE_PARTIAL_COVERAGE','2026_CERTIFIED_SALES_SCOPE',(select max(updated_at) from public.aos_cartera_reconciliacion),v_now,v_now,'HIGH',
    jsonb_build_array('F4_IS_FINANCIAL_TRUTH'),jsonb_build_array('F4_LINKED_IS_EVIDENCE_COVERAGE_NOT_COLLECTED_CASH','MISSING_EVIDENCE_IS_NOT_NON_PAYMENT'),jsonb_build_array('REV-F4','REV-F6.4')
  );
  v_acq_trust:=public.aos_rev_metric_trust_envelope_v1(
    'F6_4_ACQUISITION_TO_REVENUE',case when v_acq_count>0 then to_jsonb(v_acq_value) else 'null'::jsonb end,
    v_acq_count,v_tx,'EXPLICIT_AGENDA_SALE_ID_PLUS_LEAD_LINEAGE',v_acq_count,
    case when v_acq_count>0 then 'AVAILABLE_PARTIAL_COVERAGE' else 'NO_DEFENDABLE_ATTRIBUTION' end,
    '2026_EXPLICIT_LINEAGE_ONLY',(select max(ts_actualizado) from public.aos_agenda_citas),v_now,v_now,
    case when v_acq_count>0 then 'HIGH' else 'UNRESOLVED' end,
    case when v_acq_count>0 then jsonb_build_array('EXPLICIT_VENTA_ID_MATCH_AND_LEAD_ID') else jsonb_build_array('NO_EXPLICIT_SALE_LINEAGE_IN_SCOPE') end,
    jsonb_build_array('PHONE_ONLY_ATTRIBUTION_PROHIBITED','ABSENCE_OF_EXPLICIT_LINEAGE_NE_ZERO_CONVERSION'),jsonb_build_array('aos_agenda_citas','aos_ventas','REV-F6.4')
  );

  return jsonb_build_object(
    'ok',true,
    'hasData',true,
    'contract','REV-F6.4_SALES_INTELLIGENCE_3_V1',
    'anio',p_anio,
    'filters',jsonb_build_object('sede',v_sede,'asesor',v_asesor),
    'business_date_lima',v_business_date,
    'dataThrough',v_data_through,
    'executive_revenue',jsonb_build_object(
      'billed_amount',v_billed,
      'transactions',v_tx,
      'avg_ticket',case when v_tx>0 then round(v_billed/v_tx,2) else 0 end,
      'target_ytd',v_target_ytd,
      'target_annual',v_target_annual,
      'pct_target_ytd',case when v_target_ytd>0 then round(100.0*v_billed/v_target_ytd,2) else null end,
      'mtd_billed',v_mtd,
      'mtd_transactions',v_mtd_tx,
      'mtd_target',v_target_mtd,
      'mtd_projection',case when v_target_mtd is null then null else v_projection end,
      'f4_evidence_sales',v_f4,
      'billed_amount_with_f4_evidence',v_f4_billed,
      'payment_evidence_sales',v_payment_evidence,
      'confirmed_balance_sales',v_confirmed_balance,
      'confirmed_collected_amount',null,
      'financial_semantic','F4_LINKED_IS_EVIDENCE_COVERAGE_NOT_COLLECTED_CASH'
    ),
    'identity_coverage',jsonb_build_object('safe_match_sales',v_safe,'review_sales',v_review,'unresolved_sales',v_unresolved,'denominator',v_tx),
    'product_coverage',jsonb_build_object('resolved_sales',v_f3,'denominator',v_tx),
    'monthly',v_monthly,
    'cohorts',v_cohorts,
    'observed_ltv',v_patient_value,
    'products',v_products,
    'cross_sell_transitions',v_transitions,
    'sede_performance',v_sede_perf,
    'advisor_performance',v_advisor_perf,
    'acquisition_to_revenue',case when v_acq_count>0 then jsonb_build_object(
      'source_status','AVAILABLE_PARTIAL_COVERAGE','explicit_attributed_sales',v_acq_count,'explicit_attributed_billed',v_acq_value,
      'attribution_method','EXPLICIT_AGENDA_VENTA_ID_MATCH_PLUS_LEAD_LINEAGE','sample_size',v_acq_count
    ) else jsonb_build_object(
      'source_status','NO_DEFENDABLE_ATTRIBUTION','value',null,'sample_size',0,
      'attribution_method','EXPLICIT_AGENDA_VENTA_ID_MATCH_PLUS_LEAD_LINEAGE',
      'limitations',jsonb_build_array('NO_EXPLICIT_LINEAGE_IN_CURRENT_SCOPE','PHONE_ONLY_ATTRIBUTION_PROHIBITED','ABSENCE_NE_ZERO_CONVERSION')
    ) end,
    'demographic_geographic_readiness',jsonb_build_object(
      'safe_patient_denominator',v_geo_n,
      'threshold_pct',v_demo_threshold,
      'minimum_cell_size',v_min_cell,
      'fields',jsonb_build_object(
        'sex',jsonb_build_object('available',v_sex_n,'pct',case when v_geo_n>0 then round(100.0*v_sex_n/v_geo_n,2) end,'enabled',(v_geo_n>=v_min_cell and 100.0*v_sex_n/nullif(v_geo_n,0)>=v_demo_threshold)),
        'district',jsonb_build_object('available',v_district_n,'pct',case when v_geo_n>0 then round(100.0*v_district_n/v_geo_n,2) end,'enabled',(v_geo_n>=v_min_cell and 100.0*v_district_n/nullif(v_geo_n,0)>=v_demo_threshold)),
        'city',jsonb_build_object('available',v_city_n,'pct',case when v_geo_n>0 then round(100.0*v_city_n/v_geo_n,2) end,'enabled',(v_geo_n>=v_min_cell and 100.0*v_city_n/nullif(v_geo_n,0)>=v_demo_threshold)),
        'department',jsonb_build_object('available',v_dept_n,'pct',case when v_geo_n>0 then round(100.0*v_dept_n/v_geo_n,2) end,'enabled',(v_geo_n>=v_min_cell and 100.0*v_dept_n/nullif(v_geo_n,0)>=v_demo_threshold)),
        'dob',jsonb_build_object('available',v_dob_n,'pct',case when v_geo_n>0 then round(100.0*v_dob_n/v_geo_n,2) end,'enabled',(v_geo_n>=v_min_cell and 100.0*v_dob_n/nullif(v_geo_n,0)>=v_demo_threshold))
      ),
      'enabled_fields',to_jsonb(array_remove(array[
        case when v_geo_n>=v_min_cell and 100.0*v_sex_n/nullif(v_geo_n,0)>=v_demo_threshold then 'sex' end,
        case when v_geo_n>=v_min_cell and 100.0*v_district_n/nullif(v_geo_n,0)>=v_demo_threshold then 'district' end,
        case when v_geo_n>=v_min_cell and 100.0*v_city_n/nullif(v_geo_n,0)>=v_demo_threshold then 'city' end,
        case when v_geo_n>=v_min_cell and 100.0*v_dept_n/nullif(v_geo_n,0)>=v_demo_threshold then 'department' end,
        case when v_geo_n>=v_min_cell and 100.0*v_dob_n/nullif(v_geo_n,0)>=v_demo_threshold then 'dob' end
      ]::text[],null))
    ),
    'metric_trust',jsonb_build_object('executive_revenue',v_exec_trust,'patient_linkage',v_identity_trust,'product_resolution',v_f3_trust,'financial_evidence',v_f4_trust,'acquisition_to_revenue',v_acq_trust),
    'historical_source_status',jsonb_build_object(
      '2024',jsonb_build_object('value',v_hist_2024->'value','source_status',v_hist_2024->>'source_status','trust_level',v_hist_2024->>'trust_level'),
      '2025',jsonb_build_object('value',v_hist_2025->'value','source_status',v_hist_2025->>'source_status','trust_level',v_hist_2025->>'trust_level'),
      '2026',jsonb_build_object('source_status','AVAILABLE','min_date',(select min(sale_date) from public.aos_rev_si_sales_fact_v1),'max_date',(select max(sale_date) from public.aos_rev_si_sales_fact_v1))
    ),
    'limitations',jsonb_build_array(
      '2024_2025_TRANSACTIONAL_SALES_NO_CERTIFIED_SOURCE',
      'PATIENT_ANALYTICS_MATCH_ONLY',
      'OBSERVED_VALUE_NOT_FUTURE_LTV',
      'F4_EVIDENCE_NOT_CONFIRMED_COLLECTED_CASH',
      'ACQUISITION_ATTRIBUTION_REQUIRES_EXPLICIT_LINEAGE'
    ),
    'read_model_architecture','MATERIALIZED_READ_MODELS_PLUS_SET_BASED_AGGREGATION'
  );
end;
$$;
comment on function public.aos_rev_sales_intelligence_v3(integer,text,text) is
'REV-F6.4 service-only Sales Intelligence 3.0. Performance-oriented set-based aggregate over governed materialized read models; explicit coverage/trust semantics.';
revoke all on function public.aos_rev_sales_intelligence_v3(integer,text,text) from public,anon,authenticated;
grant execute on function public.aos_rev_sales_intelligence_v3(integer,text,text) to service_role;

-- -----------------------------------------------------------------------------
-- 9) DETERMINISTIC F6.4 CERTIFICATION CONTRACT.
-- -----------------------------------------------------------------------------
create or replace function public.aos_rev_f6_4_contract_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_f63 jsonb := public.aos_rev_f6_3_contract_v1();
  v_payload jsonb;
  v_fp text;
  v_sales bigint;
  v_monthly bigint;
  v_patients bigint;
  v_cohorts bigint;
  v_transitions bigint;
  v_acq bigint;
begin
  select count(*) into v_sales from public.aos_rev_si_sales_fact_v1;
  select count(*) into v_monthly from public.aos_rev_si_monthly_v1;
  select count(*) into v_patients from public.aos_rev_si_patient_value_v1;
  select count(*) into v_cohorts from public.aos_rev_si_cohort_month_v1;
  select count(*) into v_transitions from public.aos_rev_si_product_transition_v1;
  select count(*) into v_acq from public.aos_rev_si_acquisition_fact_v1;

  v_payload:=jsonb_build_object(
    'contract_id','REV-F6.4_SALES_INTELLIGENCE_3_V1',
    'contract_version',1,
    'input_fingerprints',jsonb_build_object(
      'f6_0',v_f63#>>'{contract,input_fingerprints,f6_0}',
      'f6_1',v_f63#>>'{contract,input_fingerprints,f6_1}',
      'f6_2',v_f63#>>'{contract,input_fingerprints,f6_2}',
      'f6_3',v_f63->>'contract_fingerprint'
    ),
    'read_models',jsonb_build_object(
      'sales_fact_rows',v_sales,
      'monthly_rows',v_monthly,
      'patient_value_rows',v_patients,
      'cohort_rows',v_cohorts,
      'product_transition_rows',v_transitions,
      'explicit_acquisition_rows',v_acq
    ),
    'semantic_guards',jsonb_build_object(
      'patient_analytics_match_only',true,
      'observed_ltv_is_prediction',false,
      'f4_link_means_collected_cash',false,
      'phone_only_acquisition_attribution',false,
      'no_certified_source_means_zero',false,
      'demographic_coverage_threshold_pct',70,
      'demographic_minimum_cell_size',5
    ),
    'historical_transaction_sources',jsonb_build_object('2024','NO_CERTIFIED_SOURCE','2025','NO_CERTIFIED_SOURCE','2026','AVAILABLE'),
    'performance_contract',jsonb_build_object(
      'architecture','MATERIALIZED_READ_MODELS_PLUS_SET_BASED_AGGREGATION',
      'live_rpc_target_ms',1000,
      'timeout_increase_is_solution',false
    ),
    'security',jsonb_build_object(
      'raw_read_models_browser_closed',true,
      'raw_pii_phi_in_aggregate_contract',false,
      'browser_gateway_reuses_existing_admin_2fa_authorization',true
    )
  );
  v_fp:=md5(v_payload::text);
  return jsonb_build_object('ok',true,'generated_at',clock_timestamp(),'contract',v_payload,'contract_fingerprint',v_fp);
end;
$$;
comment on function public.aos_rev_f6_4_contract_v1() is
'REV-F6.4 deterministic aggregate certification contract. Dynamic generated_at excluded from fingerprint payload.';
revoke all on function public.aos_rev_f6_4_contract_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_f6_4_contract_v1() to service_role;

-- -----------------------------------------------------------------------------
-- 10) CONTROLLED REFRESH — derived read models only.
-- -----------------------------------------------------------------------------
create or replace function public.aos_rev_si_refresh_v1()
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
begin
  refresh materialized view public.aos_rev_si_sales_fact_v1;
  refresh materialized view public.aos_rev_si_monthly_v1;
  refresh materialized view public.aos_rev_si_patient_value_v1;
  refresh materialized view public.aos_rev_si_cohort_month_v1;
  refresh materialized view public.aos_rev_si_product_transition_v1;
  refresh materialized view public.aos_rev_si_acquisition_fact_v1;
  return public.aos_rev_f6_4_contract_v1();
end;
$$;
comment on function public.aos_rev_si_refresh_v1() is
'REV-F6.4 service-only deterministic refresh of derived materialized read models. Does not mutate business source rows.';
revoke all on function public.aos_rev_si_refresh_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_si_refresh_v1() to service_role;

-- -----------------------------------------------------------------------------
-- 11) BROWSER GATEWAY — preserve existing Sales Intelligence admin + 2FA auth.
-- Existing gateway is used as an authorization probe; V3 does not weaken it.
-- -----------------------------------------------------------------------------
create or replace function public.aos_rev_sales_intelligence_v3_gateway(
  p_token text,
  p_anio integer,
  p_sede text default '',
  p_asesor text default ''
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_auth_probe jsonb;
begin
  v_auth_probe:=public.aos_sales_intelligence_gateway(p_token,p_anio,p_sede,p_asesor);
  if coalesce(v_auth_probe->>'error','')='UNAUTHORIZED' or coalesce((v_auth_probe->>'ok')::boolean,true)=false then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  return public.aos_rev_sales_intelligence_v3(p_anio,p_sede,p_asesor);
end;
$$;
comment on function public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text) is
'REV-F6.4 browser gateway. Authorization is delegated to existing certified Sales Intelligence admin+2FA access contract before service-only V3 analytics.';
revoke all on function public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text) from public;
grant execute on function public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text) to anon,authenticated,service_role;

-- -----------------------------------------------------------------------------
-- 12) PATIENT COMMERCIAL 360 — preserve F6.3 as private base, add F6.4 read detail.
-- -----------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.aos_patient_commercial_360_v2_f6_3_base(text,text,text)') is null then
    execute 'alter function public.aos_patient_commercial_360_v2(text,text,text) rename to aos_patient_commercial_360_v2_f6_3_base';
  end if;
end $$;
revoke all on function public.aos_patient_commercial_360_v2_f6_3_base(text,text,text) from public,anon,authenticated;
grant execute on function public.aos_patient_commercial_360_v2_f6_3_base(text,text,text) to service_role;

create or replace function public.aos_patient_commercial_360_v2(p_token text,p_lookup_type text,p_lookup_value text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_base jsonb;
  v_pid text;
  v_value jsonb;
begin
  v_base:=public.aos_patient_commercial_360_v2_f6_3_base(p_token,p_lookup_type,p_lookup_value);
  if coalesce((v_base->>'found')::boolean,false) then
    v_pid:=v_base#>>'{paciente,canonical_patient_id}';
    v_value:=public.aos_rev_si_patient_value_by_patient_v1(v_pid);
    v_base:=jsonb_set(v_base,'{intelligence,sales_intelligence}',v_value,true);
  end if;
  v_base:=jsonb_set(v_base,'{contract}',to_jsonb('REV-F6.4_PATIENT_COMMERCIAL_360_V2'::text),true);
  return v_base;
end;
$$;
comment on function public.aos_patient_commercial_360_v2(text,text,text) is
'REV-F6.4 governed Patient Commercial 360 wrapper. Preserves F6.3 authorization/privacy and adds MATCH-only observed Sales Intelligence metadata.';
revoke all on function public.aos_patient_commercial_360_v2(text,text,text) from public;
grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon,authenticated,service_role;

commit;
