-- ASCENDA OS — Commercial Intelligence & Audience OS
-- Phase 3 — Segmentation Engine V1
-- Shadow-mode, versioned, explainable classification. No legacy labels are mutated.

begin;

create table if not exists public.aos_segmentation_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version integer not null check (version > 0),
  status text not null check (status in ('SHADOW','ACTIVE','RETIRED')),
  effective_from timestamptz not null,
  effective_to timestamptz null,
  rules jsonb not null,
  description text null,
  created_by_user_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (policy_key, version),
  check (effective_to is null or effective_to > effective_from)
);

create unique index if not exists uq_aos_segmentation_policies_open_status
  on public.aos_segmentation_policies (policy_key, status)
  where status in ('SHADOW','ACTIVE') and effective_to is null;

alter table public.aos_segmentation_policies enable row level security;

insert into public.aos_segmentation_policies (
  policy_key, version, status, effective_from, rules, description
)
values (
  'COMMERCIAL_SEGMENTATION',
  1,
  'SHADOW',
  timestamptz '2026-08-13 00:00:00-05',
  jsonb_build_object(
    'timezone','America/Lima',
    'value_tier', jsonb_build_object(
      'revenue_bands', jsonb_build_array(500,1800,5000,8000),
      'frequency_bands', jsonb_build_array(2,5,9),
      'recency_days', jsonb_build_array(30,90),
      'premium_min_score',3,
      'gold_min_score',6,
      'diamond_min_score',8,
      'diamond_min_revenue',5000,
      'diamond_min_sales',5
    ),
    'lifecycle', jsonb_build_object(
      'new_customer_days',30,
      'active_customer_days',90,
      'cooling_customer_days',180,
      'active_prospect_days',30,
      'warm_prospect_days',90,
      'terminal_call_statuses',jsonb_build_array('NO LE INTERESA','SACAR DE LA BASE'),
      'positive_call_statuses',jsonb_build_array('CITA CONFIRMADA','SEGUIMIENTO')
    ),
    'engagement', jsonb_build_object(
      'future_appointment_points',4,
      'recent_attendance_points',3,
      'recent_attendance_days',90,
      'positive_call_points',2,
      'positive_call_days',30,
      'recent_lead_points',1,
      'recent_lead_days',30,
      'pending_followup_points',2,
      'email_interaction_points',1,
      'medium_min_score',2,
      'high_min_score',5
    ),
    'traits', jsonb_build_object(
      'repeat_buyer_min_sales',2,
      'frequent_buyer_min_sales',5,
      'high_value_min_revenue',5000,
      'recent_buyer_days',30,
      'lapsed_buyer_days',180,
      'repeat_no_show_min_count',2
    )
  ),
  'CIA Phase 3 Segmentation Policy V1. Shadow mode; empirical thresholds calibrated against the 2026-08-13 live baseline.'
)
on conflict (policy_key, version) do nothing;

comment on table public.aos_segmentation_policies is
'CIA versioned segmentation policy registry. Phase 3 seeds COMMERCIAL_SEGMENTATION v1 in SHADOW mode.';

create or replace view public.aos_cia_current_segmentation_policy_v1
with (security_invoker = true)
as
select p.*
from public.aos_segmentation_policies p
where p.policy_key = 'COMMERCIAL_SEGMENTATION'
  and p.status in ('ACTIVE','SHADOW')
  and p.effective_from <= now()
  and (p.effective_to is null or p.effective_to > now())
order by case p.status when 'ACTIVE' then 0 else 1 end, p.version desc
limit 1;

comment on view public.aos_cia_current_segmentation_policy_v1 is
'CIA current segmentation policy resolver. ACTIVE is preferred; SHADOW is used when no ACTIVE policy exists.';

create or replace view public.aos_cia_customer_segments_v1
with (security_invoker = true)
as
with policy as (
  select
    id as policy_id,
    policy_key,
    version as policy_version,
    status as policy_status,
    effective_from,
    rules,
    (rules#>>'{value_tier,revenue_bands,0}')::numeric as rev_b1,
    (rules#>>'{value_tier,revenue_bands,1}')::numeric as rev_b2,
    (rules#>>'{value_tier,revenue_bands,2}')::numeric as rev_b3,
    (rules#>>'{value_tier,revenue_bands,3}')::numeric as rev_b4,
    (rules#>>'{value_tier,frequency_bands,0}')::integer as freq_b1,
    (rules#>>'{value_tier,frequency_bands,1}')::integer as freq_b2,
    (rules#>>'{value_tier,frequency_bands,2}')::integer as freq_b3,
    (rules#>>'{value_tier,recency_days,0}')::integer as value_recent_days,
    (rules#>>'{value_tier,recency_days,1}')::integer as value_warm_days,
    (rules#>>'{value_tier,premium_min_score}')::integer as premium_min_score,
    (rules#>>'{value_tier,gold_min_score}')::integer as gold_min_score,
    (rules#>>'{value_tier,diamond_min_score}')::integer as diamond_min_score,
    (rules#>>'{value_tier,diamond_min_revenue}')::numeric as diamond_min_revenue,
    (rules#>>'{value_tier,diamond_min_sales}')::integer as diamond_min_sales,
    (rules#>>'{lifecycle,new_customer_days}')::integer as new_customer_days,
    (rules#>>'{lifecycle,active_customer_days}')::integer as active_customer_days,
    (rules#>>'{lifecycle,cooling_customer_days}')::integer as cooling_customer_days,
    (rules#>>'{lifecycle,active_prospect_days}')::integer as active_prospect_days,
    (rules#>>'{lifecycle,warm_prospect_days}')::integer as warm_prospect_days,
    rules#>'{lifecycle,terminal_call_statuses}' as terminal_statuses,
    rules#>'{lifecycle,positive_call_statuses}' as positive_statuses,
    (rules#>>'{engagement,future_appointment_points}')::integer as e_future_points,
    (rules#>>'{engagement,recent_attendance_points}')::integer as e_attend_points,
    (rules#>>'{engagement,recent_attendance_days}')::integer as e_attend_days,
    (rules#>>'{engagement,positive_call_points}')::integer as e_call_points,
    (rules#>>'{engagement,positive_call_days}')::integer as e_call_days,
    (rules#>>'{engagement,recent_lead_points}')::integer as e_lead_points,
    (rules#>>'{engagement,recent_lead_days}')::integer as e_lead_days,
    (rules#>>'{engagement,pending_followup_points}')::integer as e_followup_points,
    (rules#>>'{engagement,email_interaction_points}')::integer as e_email_points,
    (rules#>>'{engagement,medium_min_score}')::integer as e_medium_min,
    (rules#>>'{engagement,high_min_score}')::integer as e_high_min,
    (rules#>>'{traits,repeat_buyer_min_sales}')::integer as t_repeat_sales,
    (rules#>>'{traits,frequent_buyer_min_sales}')::integer as t_frequent_sales,
    (rules#>>'{traits,high_value_min_revenue}')::numeric as t_high_value,
    (rules#>>'{traits,recent_buyer_days}')::integer as t_recent_days,
    (rules#>>'{traits,lapsed_buyer_days}')::integer as t_lapsed_days,
    (rules#>>'{traits,repeat_no_show_min_count}')::integer as t_repeat_no_show
  from public.aos_cia_current_segmentation_policy_v1
), base as (
  select
    f.*,
    p.*,
    greatest(f.last_sale_at, f.last_attended_at) as customer_last_activity_at,
    case
      when f.revenue_lifetime >= p.rev_b4 then 4
      when f.revenue_lifetime >= p.rev_b3 then 3
      when f.revenue_lifetime >= p.rev_b2 then 2
      when f.revenue_lifetime >= p.rev_b1 then 1
      else 0
    end as revenue_points,
    case
      when f.sale_count >= p.freq_b3 then 3
      when f.sale_count >= p.freq_b2 then 2
      when f.sale_count >= p.freq_b1 then 1
      else 0
    end as frequency_points,
    case
      when f.last_sale_at is null then 0
      when ((now() at time zone 'America/Lima')::date - f.last_sale_at) <= p.value_recent_days then 2
      when ((now() at time zone 'America/Lima')::date - f.last_sale_at) <= p.value_warm_days then 1
      else 0
    end as value_recency_points,
    (
      case when f.has_future_appointment then p.e_future_points else 0 end
      + case when f.last_attended_at is not null
                   and ((now() at time zone 'America/Lima')::date - f.last_attended_at) <= p.e_attend_days
             then p.e_attend_points else 0 end
      + case when f.last_call_at is not null
                   and f.days_since_last_call <= p.e_call_days
                   and p.positive_statuses ? coalesce(f.latest_call_status,'')
             then p.e_call_points else 0 end
      + case when f.last_lead_at is not null
                   and f.days_since_last_lead <= p.e_lead_days
             then p.e_lead_points else 0 end
      + case when f.pending_followup_count > 0 then p.e_followup_points else 0 end
      + case when f.email_opened_count > 0 or f.email_clicked_count > 0 then p.e_email_points else 0 end
    )::integer as engagement_score
  from public.aos_cia_commercial_facts_v1 f
  cross join policy p
), scored as (
  select
    b.*,
    (b.revenue_points + b.frequency_points + b.value_recency_points)::integer as value_score,
    case
      when b.sale_count > 0
       and (b.revenue_points + b.frequency_points + b.value_recency_points) >= b.diamond_min_score
       and b.revenue_lifetime >= b.diamond_min_revenue
       and b.sale_count >= b.diamond_min_sales then 'DIAMANTE'
      when b.sale_count > 0
       and (b.revenue_points + b.frequency_points + b.value_recency_points) >= b.gold_min_score then 'GOLD'
      when b.sale_count > 0
       and (b.revenue_points + b.frequency_points + b.value_recency_points) >= b.premium_min_score then 'PREMIUM'
      else 'STANDARD'
    end::text as value_tier,
    case
      when b.sale_count > 0 and ((now() at time zone 'America/Lima')::date - b.first_sale_at) <= b.new_customer_days
        then 'NEW_CUSTOMER'
      when b.sale_count > 0 and b.customer_last_activity_at is not null
           and ((now() at time zone 'America/Lima')::date - b.customer_last_activity_at) <= b.active_customer_days
        then 'ACTIVE_CUSTOMER'
      when b.sale_count > 0 and b.customer_last_activity_at is not null
           and ((now() at time zone 'America/Lima')::date - b.customer_last_activity_at) <= b.cooling_customer_days
        then 'COOLING_CUSTOMER'
      when b.sale_count > 0 then 'INACTIVE_CUSTOMER'
      when b.has_future_appointment then 'APPOINTMENT_READY_PROSPECT'
      when b.sale_count = 0
       and b.terminal_statuses ? coalesce(b.latest_call_status,'')
       and (b.last_lead_at is null or b.last_call_at >= b.last_lead_at)
        then 'DISQUALIFIED_PROSPECT'
      when b.sale_count = 0 and (
        (b.last_lead_at is not null and b.days_since_last_lead <= b.active_prospect_days)
        or (b.last_call_at is not null and b.days_since_last_call <= b.active_prospect_days
            and b.positive_statuses ? coalesce(b.latest_call_status,''))
        or b.pending_followup_count > 0
      ) then 'ACTIVE_PROSPECT'
      when b.sale_count = 0 and (
        (b.last_lead_at is not null and b.days_since_last_lead <= b.warm_prospect_days)
        or (b.last_call_at is not null and b.days_since_last_call <= b.warm_prospect_days
            and not (b.terminal_statuses ? coalesce(b.latest_call_status,'')))
      ) then 'WARM_PROSPECT'
      when b.sale_count = 0 and (b.lead_count > 0 or b.call_count > 0 or b.appointment_count > 0 or b.followup_count > 0)
        then 'COLD_PROSPECT'
      else 'PROFILE_ONLY'
    end::text as lifecycle,
    case
      when b.engagement_score >= b.e_high_min then 'HIGH'
      when b.engagement_score >= b.e_medium_min then 'MEDIUM'
      else 'LOW'
    end::text as engagement
  from base b
), traited as (
  select
    s.*,
    array_remove(array[
      case when s.lead_count > 0 then 'HAS_LEAD' end,
      case when s.lead_unworked_since_latest_entry is true then 'UNWORKED_LEAD' end,
      case when s.calls_never_called is true then 'NEVER_CALLED' end,
      case when s.product_count > 0 then 'PRODUCT_BUYER' end,
      case when s.service_count > 0 then 'SERVICE_BUYER' end,
      case when s.product_count > 0 and s.service_count > 0 then 'PRODUCT_AND_SERVICE_BUYER' end,
      case when s.sale_count >= s.t_repeat_sales then 'REPEAT_BUYER' end,
      case when s.sale_count >= s.t_frequent_sales then 'FREQUENT_BUYER' end,
      case when s.revenue_lifetime >= s.t_high_value and s.sale_count > 0 then 'HIGH_VALUE_BUYER' end,
      case when s.last_sale_at is not null and s.days_since_last_sale <= s.t_recent_days then 'RECENT_BUYER' end,
      case when s.last_sale_at is not null and s.days_since_last_sale > s.t_lapsed_days then 'LAPSED_BUYER' end,
      case when s.has_future_appointment then 'FUTURE_APPOINTMENT' end,
      case when s.no_show_count > 0 then 'NO_SHOW_HISTORY' end,
      case when s.no_show_count >= s.t_repeat_no_show then 'REPEAT_NO_SHOW' end,
      case when s.pending_followup_count > 0 then 'FOLLOWUP_PENDING' end,
      case when s.overdue_followup_count > 0 then 'FOLLOWUP_OVERDUE' end
    ]::text[], null) as traits
  from scored s
)
select
  1::integer as segment_version,
  t.policy_id,
  t.policy_key,
  t.policy_version,
  t.policy_status,
  t.effective_from as policy_effective_from,
  t.contact_key,
  t.identity_status,
  t.identity_conflict,
  t.value_tier,
  t.value_score,
  t.revenue_points as value_revenue_points,
  t.frequency_points as value_frequency_points,
  t.value_recency_points,
  t.lifecycle,
  t.customer_last_activity_at,
  t.engagement,
  t.engagement_score,
  t.traits,
  statement_timestamp() as calculated_at,
  jsonb_build_object(
    'value_tier', jsonb_build_object(
      'result', t.value_tier,
      'score', t.value_score,
      'revenue', t.revenue_lifetime,
      'sale_count', t.sale_count,
      'days_since_last_sale', t.days_since_last_sale,
      'points', jsonb_build_object(
        'revenue', t.revenue_points,
        'frequency', t.frequency_points,
        'recency', t.value_recency_points
      )
    ),
    'lifecycle', jsonb_build_object(
      'result', t.lifecycle,
      'first_sale_at', t.first_sale_at,
      'last_sale_at', t.last_sale_at,
      'last_attended_at', t.last_attended_at,
      'customer_last_activity_at', t.customer_last_activity_at,
      'last_lead_at', t.last_lead_at,
      'last_call_at', t.last_call_at,
      'latest_call_status', t.latest_call_status,
      'has_future_appointment', t.has_future_appointment
    ),
    'engagement', jsonb_build_object(
      'result', t.engagement,
      'score', t.engagement_score,
      'has_future_appointment', t.has_future_appointment,
      'pending_followups', t.pending_followup_count,
      'email_opened_count', t.email_opened_count,
      'email_clicked_count', t.email_clicked_count
    ),
    'traits', to_jsonb(t.traits),
    'policy', jsonb_build_object(
      'id', t.policy_id,
      'key', t.policy_key,
      'version', t.policy_version,
      'status', t.policy_status
    )
  ) as explanation,
  t.provenance as facts_provenance
from traited t;

comment on view public.aos_cia_customer_segments_v1 is
'CIA Segmentation Engine V1. One explainable shadow classification per Commercial Facts contact_key.';

revoke all on public.aos_segmentation_policies from public, anon, authenticated;
revoke all on public.aos_cia_current_segmentation_policy_v1 from public, anon, authenticated;
revoke all on public.aos_cia_customer_segments_v1 from public, anon, authenticated;

grant select on public.aos_segmentation_policies to service_role;
grant select on public.aos_cia_current_segmentation_policy_v1 to service_role;
grant select on public.aos_cia_customer_segments_v1 to service_role;

commit;
