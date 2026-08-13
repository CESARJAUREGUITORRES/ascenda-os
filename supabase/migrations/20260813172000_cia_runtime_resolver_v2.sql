-- ASCENDA Commercial Intelligence — Runtime Resolver V2
-- Consolidated final state from the physical Phase 5 audit.
-- Requires Phase 4 CIA facts/registry/validator migrations.

begin;

-- Keep canonical normalization semantically identical but planner-inlineable.
create or replace function public.aos_cia_normalize_contact_key_v1(p_raw text)
returns text language sql immutable parallel safe as $$
select case
  when length(regexp_replace(coalesce(p_raw,''),'\D','','g'))=9
    then regexp_replace(coalesce(p_raw,''),'\D','','g')
  when length(regexp_replace(coalesce(p_raw,''),'\D','','g'))=11
    and left(regexp_replace(coalesce(p_raw,''),'\D','','g'),2)='51'
    then right(regexp_replace(coalesce(p_raw,''),'\D','','g'),9)
  else null
end;
$$;

create table if not exists public.aos_cia_segment_runtime_cache_v2(
  contact_key text primary key,
  policy_key text not null,
  policy_version integer not null,
  policy_status text not null,
  value_tier text not null,
  value_score integer not null,
  lifecycle text not null,
  engagement text not null,
  engagement_score integer not null,
  traits text[] not null default array[]::text[],
  explanation jsonb not null default '{}'::jsonb,
  segment_calculated_at timestamptz,
  cache_refreshed_at timestamptz not null default now()
);
alter table public.aos_cia_segment_runtime_cache_v2 enable row level security;
revoke all on public.aos_cia_segment_runtime_cache_v2 from public,anon,authenticated;
grant select,insert,update,delete on public.aos_cia_segment_runtime_cache_v2 to service_role;

insert into public.aos_cia_segment_runtime_cache_v2(
  contact_key,policy_key,policy_version,policy_status,value_tier,value_score,lifecycle,engagement,
  engagement_score,traits,explanation,segment_calculated_at,cache_refreshed_at)
select contact_key,policy_key,policy_version,policy_status,value_tier,value_score,lifecycle,engagement,
  engagement_score,traits,explanation,segment_calculated_at,statement_timestamp()
from public.aos_cia_customer_segments_v1
on conflict(contact_key) do update set
  policy_key=excluded.policy_key,policy_version=excluded.policy_version,policy_status=excluded.policy_status,
  value_tier=excluded.value_tier,value_score=excluded.value_score,lifecycle=excluded.lifecycle,
  engagement=excluded.engagement,engagement_score=excluded.engagement_score,traits=excluded.traits,
  explanation=excluded.explanation,segment_calculated_at=excluded.segment_calculated_at,
  cache_refreshed_at=excluded.cache_refreshed_at;

create table if not exists public.aos_cia_email_runtime_cache_v2(
  contact_key text primary key,
  identity_confidence text,
  sent_count integer not null default 0,
  never_sent boolean,
  last_sent_at timestamptz,
  days_since_last integer,
  delivered_count integer not null default 0,
  opened_count integer not null default 0,
  clicked_count integer not null default 0,
  bounced_count integer not null default 0,
  last_event_at timestamptz,
  cache_refreshed_at timestamptz not null default now()
);
alter table public.aos_cia_email_runtime_cache_v2 enable row level security;
revoke all on public.aos_cia_email_runtime_cache_v2 from public,anon,authenticated;
grant select,insert,update,delete on public.aos_cia_email_runtime_cache_v2 to service_role;

insert into public.aos_cia_email_runtime_cache_v2(
  contact_key,identity_confidence,sent_count,never_sent,last_sent_at,days_since_last,delivered_count,
  opened_count,clicked_count,bounced_count,last_event_at,cache_refreshed_at)
select contact_key,identity_confidence,sent_count,never_sent,last_sent_at,days_since_last,delivered_count,
  opened_count,clicked_count,bounced_count,last_event_at,statement_timestamp()
from public.aos_cia_email_facts_v1
on conflict(contact_key) do update set
  identity_confidence=excluded.identity_confidence,sent_count=excluded.sent_count,never_sent=excluded.never_sent,
  last_sent_at=excluded.last_sent_at,days_since_last=excluded.days_since_last,delivered_count=excluded.delivered_count,
  opened_count=excluded.opened_count,clicked_count=excluded.clicked_count,bounced_count=excluded.bounced_count,
  last_event_at=excluded.last_event_at,cache_refreshed_at=excluded.cache_refreshed_at;

create or replace view public.aos_cia_profile_fast_v2 with (security_invoker=true) as
select i.contact_key,i.identity_status,i.identity_conflict,i.canonical_patient_id,
  i.canonical_names,i.canonical_surnames,i.canonical_email,
  p."ESTADO_PACIENTE" patient_state,
  coalesce(nullif(btrim(p."ETIQUETA_BASE"),''),nullif(btrim(be.etiqueta),'')) base_label,
  nullif(btrim(be.campana),'') base_campaign,
  nullif(btrim(p."SEDE_PRINCIPAL"),'') raw_branch,
  nullif(btrim(p.departamento),'') department,nullif(btrim(p.ciudad),'') city,
  nullif(btrim(p.distrito),'') district,nullif(upper(btrim(p."Sexo")),'') sex,
  case
    when p."Fecha de nacimiento" ~ '^\d{1,2}/\d{1,2}/\d{4}$'
      then date_part('year',age((now() at time zone 'America/Lima')::date,to_date(p."Fecha de nacimiento",'DD/MM/YYYY')))::integer
    when p."Fecha de nacimiento" ~ '^\d{4}-\d{2}-\d{2}$'
      then date_part('year',age((now() at time zone 'America/Lima')::date,to_date(p."Fecha de nacimiento",'YYYY-MM-DD')))::integer
    else null end age_years
from public.aos_cia_contact_identity_v1 i
left join public.aos_pacientes p on p."ID_PACIENTE"=i.canonical_patient_id
left join public.aos_base_etiquetas be on public.aos_cia_normalize_contact_key_v1(be.numero)=i.contact_key;
revoke all on public.aos_cia_profile_fast_v2 from public,anon,authenticated;
grant select on public.aos_cia_profile_fast_v2 to service_role;

create table if not exists public.aos_cia_filter_execution_map_v2(
  field_key text primary key,source_key text not null,source_column text,special_key text,
  data_type text not null,updated_at timestamptz not null default now()
);
alter table public.aos_cia_filter_execution_map_v2 enable row level security;
revoke all on public.aos_cia_filter_execution_map_v2 from public,anon,authenticated;
grant select on public.aos_cia_filter_execution_map_v2 to service_role;

-- Derive the private execution map from the canonical public registry. No SQL fragments are stored.
insert into public.aos_cia_filter_execution_map_v2(field_key,source_key,source_column,special_key,data_type,updated_at)
select r.field_key,
  case
    when r.field_key in('contact.exists_as_lead','lead.called_since_latest_entry','lead.unworked_since_latest_entry',
      'calls.never_called','appointments.never_had','sales.never_bought','crm.branch') then 'SPECIAL'
    when r.field_key in('contact.identity_status','contact.identity_conflict') then 'IDENTITY'
    when r.field_key like 'contact.%' or r.field_key like 'crm.%' then 'PROFILE'
    when r.field_key like 'lead.%' then 'LEAD'
    when r.field_key like 'calls.%' then 'CALL'
    when r.field_key like 'appointments.%' then 'APPOINTMENT'
    when r.field_key like 'followups.%' then 'FOLLOWUP'
    when r.field_key like 'email.%' then 'EMAIL'
    when r.field_key like 'segment.%' then 'SEGMENT'
    when r.field_key in('sales.products','sales.product_categories','sales.product_unresolved_count',
      'sales.services','sales.service_categories','sales.service_category_unresolved_count') then 'PURCHASE'
    when r.field_key like 'sales.%' then 'SALE'
    else 'PROFILE' end,
  null,
  case r.field_key
    when 'contact.exists_as_lead' then 'EXISTS_AS_LEAD'
    when 'lead.called_since_latest_entry' then 'LEAD_CALLED_SINCE'
    when 'lead.unworked_since_latest_entry' then 'LEAD_UNWORKED'
    when 'calls.never_called' then 'CALLS_NEVER'
    when 'appointments.never_had' then 'APPOINTMENTS_NEVER'
    when 'sales.never_bought' then 'SALES_NEVER'
    when 'crm.branch' then 'CRM_BRANCH'
    else null end,
  r.data_type,statement_timestamp()
from public.aos_audience_filter_registry r
where r.active
on conflict(field_key) do update set source_key=excluded.source_key,source_column=excluded.source_column,
  special_key=excluded.special_key,data_type=excluded.data_type,updated_at=excluded.updated_at;

create or replace view public.aos_cia_branch_fast_v2 with (security_invoker=true) as
select p.contact_key,
  coalesce(p.raw_branch,nullif(btrim(s.latest_branch),''),nullif(btrim(a.next_branch),''),nullif(btrim(a.last_branch),'')) branch
from public.aos_cia_profile_fast_v2 p
left join public.aos_cia_sales_facts_v1 s using(contact_key)
left join public.aos_cia_appointment_facts_v1 a using(contact_key);
revoke all on public.aos_cia_branch_fast_v2 from public,anon,authenticated;
grant select on public.aos_cia_branch_fast_v2 to service_role;

create or replace view public.aos_cia_profile_adapter_v2 with (security_invoker=true) as
select p.contact_key,p.identity_status,p.identity_conflict,p.canonical_patient_id,
  case when p.canonical_email is null or btrim(p.canonical_email)='' then null
       when lower(btrim(p.canonical_email)) ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then true else false end email_valid,
  (p.canonical_patient_id is not null) exists_as_patient,p.patient_state,p.base_label,p.base_campaign,
  p.department,p.city,p.district,p.sex,p.age_years,
  case when p.age_years is null then null when p.age_years<18 then 'UNDER_18'
       when p.age_years<=24 then '18_24' when p.age_years<=34 then '25_34' when p.age_years<=44 then '35_44'
       when p.age_years<=54 then '45_54' when p.age_years<=64 then '55_64' else '65_PLUS' end::text age_band
from public.aos_cia_profile_fast_v2 p;

create or replace view public.aos_cia_lead_adapter_v2 with (security_invoker=true) as
select contact_key,lead_count,days_since_last_lead,latest_interest,latest_interest_type,
  interests as lead_interests,ads as lead_ads from public.aos_cia_lead_facts_v1;
create or replace view public.aos_cia_call_adapter_v2 with (security_invoker=true) as
select contact_key,call_count,days_since_last_call,latest_status as latest_call_status,
  latest_substatus as latest_call_substatus,ever_statuses as call_ever_statuses,called_today,effective_contact_count
from public.aos_cia_call_facts_v1;
create or replace view public.aos_cia_appointment_adapter_v2 with (security_invoker=true) as
select contact_key,appointment_count,last_appointment_at,last_appointment_status,next_appointment_at,
  has_future_appointment,no_show_count,ever_no_show,attended_count,appointment_statuses,
  case when next_appointment_at is not null then (next_appointment_at-(now() at time zone 'America/Lima')::date)::integer end days_until_next_appointment
from public.aos_cia_appointment_facts_v1;
create or replace view public.aos_cia_sale_adapter_v2 with (security_invoker=true) as
select contact_key,sale_count,revenue_lifetime,days_since_last_sale,product_count,service_count,
  latest_item_type,payment_states,payment_methods from public.aos_cia_sales_facts_v1;
create or replace view public.aos_cia_followup_adapter_v2 with (security_invoker=true) as
select contact_key,pending_count as pending_followup_count,overdue_count as overdue_followup_count,
  next_followup_at,treatments as followup_treatments,
  case when next_followup_at is not null then (next_followup_at-(now() at time zone 'America/Lima')::date)::integer end days_until_next_followup
from public.aos_cia_followup_facts_v1;
create or replace view public.aos_cia_email_adapter_v2 with (security_invoker=true) as
select contact_key,sent_count as email_sent_count,never_sent as email_never_sent,
  days_since_last as email_days_since_last,opened_count as email_opened_count,
  clicked_count as email_clicked_count,bounced_count as email_bounced_count
from public.aos_cia_email_runtime_cache_v2;
create or replace view public.aos_cia_segment_adapter_v2 with (security_invoker=true) as
select contact_key,value_tier,value_score,lifecycle,engagement,traits from public.aos_cia_segment_runtime_cache_v2;
create or replace view public.aos_cia_purchase_adapter_v2 with (security_invoker=true) as
select contact_key,canonical_products,product_categories,product_unresolved_count,canonical_services,
  service_categories,service_category_unresolved_count,service_unresolved_count
from public.aos_cia_purchase_detail_facts_v1;
revoke all on public.aos_cia_profile_adapter_v2,public.aos_cia_lead_adapter_v2,public.aos_cia_call_adapter_v2,
  public.aos_cia_appointment_adapter_v2,public.aos_cia_sale_adapter_v2,public.aos_cia_followup_adapter_v2,
  public.aos_cia_email_adapter_v2,public.aos_cia_segment_adapter_v2,public.aos_cia_purchase_adapter_v2
from public,anon,authenticated;
grant select on public.aos_cia_profile_adapter_v2,public.aos_cia_lead_adapter_v2,public.aos_cia_call_adapter_v2,
  public.aos_cia_appointment_adapter_v2,public.aos_cia_sale_adapter_v2,public.aos_cia_followup_adapter_v2,
  public.aos_cia_email_adapter_v2,public.aos_cia_segment_adapter_v2,public.aos_cia_purchase_adapter_v2 to service_role;

create or replace view public.aos_cia_lead_call_state_v2 with (security_invoker=true) as
with l as(
  select distinct on(public.aos_cia_normalize_contact_key_v1(numero_limpio))
    public.aos_cia_normalize_contact_key_v1(numero_limpio) contact_key,
    coalesce(hora_ingreso,created_at,fecha::timestamp at time zone 'America/Lima') last_lead_at
  from public.aos_leads where public.aos_cia_normalize_contact_key_v1(numero_limpio) is not null
  order by public.aos_cia_normalize_contact_key_v1(numero_limpio),
    coalesce(hora_ingreso,created_at,fecha::timestamp at time zone 'America/Lima') desc,id desc
),c as(
  select public.aos_cia_normalize_contact_key_v1(numero_limpio) contact_key,max(created_at) last_call_at
  from public.aos_llamadas where public.aos_cia_normalize_contact_key_v1(numero_limpio) is not null group by 1
)
select l.contact_key,l.last_lead_at,c.last_call_at,
  (c.last_call_at is not null and c.last_call_at>=l.last_lead_at) called_since_latest_entry,
  (c.last_call_at is null or c.last_call_at<l.last_lead_at) unworked_since_latest_entry
from l left join c using(contact_key);
revoke all on public.aos_cia_lead_call_state_v2 from public,anon,authenticated;
grant select on public.aos_cia_lead_call_state_v2 to service_role;

create table if not exists public.aos_cia_domain_defaults_v2(
  source_key text primary key,default_row jsonb not null,updated_at timestamptz not null default now()
);
alter table public.aos_cia_domain_defaults_v2 enable row level security;
revoke all on public.aos_cia_domain_defaults_v2 from public,anon,authenticated;
grant select on public.aos_cia_domain_defaults_v2 to service_role;
insert into public.aos_cia_domain_defaults_v2(source_key,default_row) values
('LEAD','{"lead_ads":[],"lead_count":0,"lead_interests":[],"latest_interest":null,"days_since_last_lead":null,"latest_interest_type":null}'::jsonb),
('CALL','{"call_count":0,"called_today":false,"call_ever_statuses":[],"latest_call_status":null,"days_since_last_call":null,"latest_call_substatus":null,"effective_contact_count":0}'::jsonb),
('APPOINTMENT','{"ever_no_show":false,"no_show_count":0,"attended_count":0,"appointment_count":0,"last_appointment_at":null,"next_appointment_at":null,"appointment_statuses":[],"has_future_appointment":false,"last_appointment_status":null,"days_until_next_appointment":null}'::jsonb),
('SALE','{"sale_count":0,"product_count":0,"service_count":0,"payment_states":[],"payment_methods":[],"latest_item_type":null,"revenue_lifetime":0,"days_since_last_sale":null}'::jsonb),
('FOLLOWUP','{"next_followup_at":null,"followup_treatments":[],"overdue_followup_count":0,"pending_followup_count":0,"days_until_next_followup":null}'::jsonb)
on conflict(source_key) do update set default_row=excluded.default_row,updated_at=now();

create or replace function public.aos_cia_keys_intersect_v2(a text[],b text[])
returns text[] language sql immutable parallel safe as $$
select coalesce(array_agg(x order by x),array[]::text[]) from(select unnest(a)x intersect select unnest(b)x)q;$$;
create or replace function public.aos_cia_keys_union_v2(a text[],b text[])
returns text[] language sql immutable parallel safe as $$
select coalesce(array_agg(x order by x),array[]::text[]) from(select unnest(a)x union select unnest(b)x)q;$$;

create or replace function public.aos_cia_domain_absent_keys_v2(p_source_key text)
returns text[] language plpgsql stable security invoker as $$
declare keys text[]:=array[]::text[];
begin
 if p_source_key='LEAD' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where not has_lead;
 elsif p_source_key='CALL' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where not has_call;
 elsif p_source_key='APPOINTMENT' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where not has_appointment;
 elsif p_source_key='SALE' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where not has_sale;
 elsif p_source_key='FOLLOWUP' then select coalesce(array_agg(i.contact_key order by i.contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 i left join public.aos_cia_followup_facts_v1 f using(contact_key) where f.contact_key is null;
 end if;return keys;end;$$;

create or replace function public.aos_cia_audience_leaf_keys_v2(p_rule jsonb)
returns text[] language plpgsql stable security invoker as $$
declare f text:=p_rule->>'field';op text:=p_rule->>'operator';sk text;sp text;keys text[]:=array[]::text[];
begin
 select source_key,special_key into sk,sp from public.aos_cia_filter_execution_map_v2 where field_key=f;
 if sp='EXISTS_AS_LEAD' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where case op when 'is_true' then has_lead when 'is_false' then not has_lead else false end;
 elsif sp in('LEAD_CALLED_SINCE','LEAD_UNWORKED') then
   if op='is_unknown' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where not has_lead;
   elsif sp='LEAD_CALLED_SINCE' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_lead_call_state_v2 where case op when 'is_true' then called_since_latest_entry when 'is_false' then not called_since_latest_entry else false end;
   else select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_lead_call_state_v2 where case op when 'is_true' then unworked_since_latest_entry when 'is_false' then not unworked_since_latest_entry else false end;end if;
 elsif sp='CALLS_NEVER' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where case op when 'is_true' then not has_call when 'is_false' then has_call else false end;
 elsif sp='APPOINTMENTS_NEVER' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where case op when 'is_true' then not has_appointment when 'is_false' then has_appointment else false end;
 elsif sp='SALES_NEVER' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 where case op when 'is_true' then not has_sale when 'is_false' then has_sale else false end;
 elsif sp='CRM_BRANCH' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_branch_fast_v2 x where public.aos_cia_audience_rule_match_v1(jsonb_build_object('crm_branch',x.branch),p_rule);
 elsif sk='IDENTITY' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_contact_identity_v1 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='PROFILE' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_profile_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='LEAD' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_lead_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='CALL' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_call_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='APPOINTMENT' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_appointment_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='SALE' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_sale_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='FOLLOWUP' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_followup_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='EMAIL' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_email_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='SEGMENT' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_segment_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 elsif sk='PURCHASE' then select coalesce(array_agg(contact_key order by contact_key),array[]::text[]) into keys from public.aos_cia_purchase_adapter_v2 x where public.aos_cia_audience_rule_match_v1(to_jsonb(x),p_rule);
 end if;return keys;end;$$;

create or replace function public.aos_cia_audience_leaf_keys_v3(p_rule jsonb)
returns text[] language plpgsql stable security invoker as $$
declare keys text[];absent text[];sk text;default_row jsonb;
begin
 keys:=public.aos_cia_audience_leaf_keys_v2(p_rule);
 select source_key into sk from public.aos_cia_filter_execution_map_v2 where field_key=p_rule->>'field';
 if sk in('LEAD','CALL','APPOINTMENT','SALE','FOLLOWUP') then
   select d.default_row into default_row from public.aos_cia_domain_defaults_v2 d where d.source_key=sk;
   if default_row is not null and public.aos_cia_audience_rule_match_v1(default_row,p_rule) then
     absent:=public.aos_cia_domain_absent_keys_v2(sk);keys:=public.aos_cia_keys_union_v2(keys,absent);end if;
 end if;return coalesce(keys,array[]::text[]);end;$$;

create or replace function public.aos_cia_audience_resolve_node_v2(p_node jsonb,p_depth integer default 1)
returns text[] language plpgsql stable security invoker as $$
declare r jsonb;child text[];acc text[];first_child boolean:=true;op text;
begin
 if p_node?'field' then return public.aos_cia_audience_leaf_keys_v3(p_node);end if;
 if p_depth>2 then return array[]::text[];end if;op:=upper(coalesce(p_node->>'op',''));
 for r in select value from jsonb_array_elements(p_node->'rules') loop
   child:=public.aos_cia_audience_resolve_node_v2(r,case when r?'field' then p_depth else p_depth+1 end);
   if first_child then acc:=child;first_child:=false;
   elsif op='AND' then acc:=public.aos_cia_keys_intersect_v2(acc,child);
   elsif op='OR' then acc:=public.aos_cia_keys_union_v2(acc,child);else return array[]::text[];end if;
 end loop;return coalesce(acc,array[]::text[]);end;$$;

create or replace function public.aos_cia_audience_count_v2(p_filter jsonb)
returns jsonb language plpgsql stable security invoker as $$
declare v jsonb;keys text[];refreshed timestamptz;
begin
 v:=public.aos_cia_audience_validate_v1(p_filter);
 if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v);end if;
 keys:=public.aos_cia_audience_resolve_node_v2(p_filter->'root',1);
 select max(cache_refreshed_at) into refreshed from public.aos_cia_segment_runtime_cache_v2;
 return jsonb_build_object('ok',true,'count',cardinality(keys),'resolver_version',2,'registry_version',1,
   'segment_cache_refreshed_at',refreshed,'observed_at',statement_timestamp());end;$$;

create or replace function public.aos_cia_preview_core_v2(p_keys text[])
returns table(contact_key text,identity_status text,identity_conflict boolean,contact_name text,patient_state text,
  raw_branch text,age_band text,value_tier text,lifecycle text,engagement text,traits text[],email_never_sent boolean)
language sql stable security invoker as $$
select k,p.identity_status,p.identity_conflict,nullif(btrim(concat_ws(' ',p.canonical_names,p.canonical_surnames)),'') contact_name,
  p.patient_state,p.raw_branch,
  case when p.age_years is null then null when p.age_years<18 then 'UNDER_18' when p.age_years<=24 then '18_24'
       when p.age_years<=34 then '25_34' when p.age_years<=44 then '35_44' when p.age_years<=54 then '45_54'
       when p.age_years<=64 then '55_64' else '65_PLUS' end::text,
  sg.value_tier,sg.lifecycle,sg.engagement,sg.traits,em.never_sent
from unnest(p_keys)k left join public.aos_cia_profile_fast_v2 p on p.contact_key=k
left join public.aos_cia_segment_runtime_cache_v2 sg on sg.contact_key=k
left join public.aos_cia_email_runtime_cache_v2 em on em.contact_key=k;$$;

create or replace function public.aos_cia_preview_activity_v2(p_keys text[])
returns table(contact_key text,latest_interest text,last_call_at timestamptz,latest_call_status text,
  next_appointment_at date,next_appointment_branch text,sale_count integer,revenue_lifetime numeric,
  latest_sale_branch text,pending_followups integer,overdue_followups integer)
language sql stable security invoker as $$
select k,ld.latest_interest,cl.last_call_at,cl.latest_call_status,ap.next_at,ap.next_branch,
  coalesce(sv.sale_count,0),coalesce(sv.revenue_lifetime,0),sv.latest_branch,
  coalesce(fu.pending_count,0),coalesce(fu.overdue_count,0)
from unnest(p_keys)k
left join lateral(select nullif(upper(btrim(l.tratamiento)),'') latest_interest from public.aos_leads l
  where public.aos_cia_normalize_contact_key_v1(l.numero_limpio)=k
  order by coalesce(l.hora_ingreso,l.created_at,l.fecha::timestamp at time zone 'America/Lima') desc,l.id desc limit 1)ld on true
left join lateral(select c.created_at last_call_at,nullif(upper(btrim(c.estado)),'') latest_call_status from public.aos_llamadas c
  where public.aos_cia_normalize_contact_key_v1(c.numero_limpio)=k order by c.created_at desc nulls last,c.fecha desc,c.id desc limit 1)cl on true
left join lateral(select a.fecha_cita next_at,a.sede next_branch from public.aos_agenda_citas a
  where public.aos_cia_normalize_contact_key_v1(a.numero_limpio)=k and a.fecha_cita>=(now() at time zone 'America/Lima')::date
    and upper(btrim(coalesce(a.estado_cita,''))) in('PENDIENTE','CITA CONFIRMADA') order by a.fecha_cita,a.id limit 1)ap on true
left join lateral(select count(*)::integer sale_count,coalesce(sum(v.monto),0)::numeric revenue_lifetime,
  (array_agg(nullif(btrim(v.sede),'') order by v.fecha desc,v.id desc)filter(where nullif(btrim(v.sede),'')is not null))[1] latest_branch
  from public.aos_ventas v where public.aos_cia_normalize_contact_key_v1(v.numero_limpio)=k)sv on true
left join lateral(select count(*)filter(where upper(btrim(coalesce(s."ESTADO",'')))='PENDIENTE')::integer pending_count,
  count(*)filter(where upper(btrim(coalesce(s."ESTADO",'')))='VENCIDO' or(upper(btrim(coalesce(s."ESTADO",'')))='PENDIENTE'
    and s."FECHA_PROGRAMADA"~'^\d{4}-\d{2}-\d{2}$' and to_date(s."FECHA_PROGRAMADA",'YYYY-MM-DD')<(now() at time zone 'America/Lima')::date))::integer overdue_count
  from public.aos_seguimientos s where public.aos_cia_normalize_contact_key_v1(s."NUMERO")=k)fu on true;$$;

create or replace function public.aos_cia_audience_preview_v2(p_filter jsonb,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql stable security invoker as $$
declare v jsonb;keys text[];page_keys text[];lim integer:=greatest(1,least(coalesce(p_limit,50),100));
 offv integer:=greatest(0,coalesce(p_offset,0));items jsonb;seg_fresh timestamptz;email_fresh timestamptz;
begin
 v:=public.aos_cia_audience_validate_v1(p_filter);if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v);end if;
 keys:=public.aos_cia_audience_resolve_node_v2(p_filter->'root',1);
 select coalesce(array_agg(k order by k),array[]::text[]) into page_keys from(select k from unnest(keys)k order by k limit lim offset offv)q;
 select coalesce(jsonb_agg(jsonb_build_object('contact_key',c.contact_key,'identity_status',c.identity_status,
  'identity_conflict',c.identity_conflict,'name',c.contact_name,'patient_state',c.patient_state,
  'branch',coalesce(c.raw_branch,a.latest_sale_branch,a.next_appointment_branch),'age_band',c.age_band,
  'value_tier',c.value_tier,'lifecycle',c.lifecycle,'engagement',c.engagement,'traits',c.traits,
  'latest_interest',a.latest_interest,'last_call_at',a.last_call_at,'latest_call_status',a.latest_call_status,
  'has_future_appointment',(a.next_appointment_at is not null),'next_appointment_at',a.next_appointment_at,
  'sale_count',a.sale_count,'revenue_lifetime',a.revenue_lifetime,'pending_followups',a.pending_followups,
  'overdue_followups',a.overdue_followups,'email_never_sent',c.email_never_sent)order by c.contact_key),'[]'::jsonb) into items
 from public.aos_cia_preview_core_v2(page_keys)c join public.aos_cia_preview_activity_v2(page_keys)a using(contact_key);
 select max(cache_refreshed_at)into seg_fresh from public.aos_cia_segment_runtime_cache_v2;
 select max(cache_refreshed_at)into email_fresh from public.aos_cia_email_runtime_cache_v2;
 return jsonb_build_object('ok',true,'count',cardinality(keys),'limit',lim,'offset',offv,'items',items,'resolver_version',2,
  'segment_cache_refreshed_at',seg_fresh,'email_cache_refreshed_at',email_fresh,'observed_at',statement_timestamp());end;$$;

-- Read-only resolver internals remain private.
revoke all on function public.aos_cia_keys_intersect_v2(text[],text[]),public.aos_cia_keys_union_v2(text[],text[]),
 public.aos_cia_domain_absent_keys_v2(text),public.aos_cia_audience_leaf_keys_v2(jsonb),
 public.aos_cia_audience_leaf_keys_v3(jsonb),public.aos_cia_audience_resolve_node_v2(jsonb,integer),
 public.aos_cia_audience_count_v2(jsonb),public.aos_cia_preview_core_v2(text[]),
 public.aos_cia_preview_activity_v2(text[]),public.aos_cia_audience_preview_v2(jsonb,integer,integer)
from public,anon,authenticated;
grant execute on function public.aos_cia_keys_intersect_v2(text[],text[]),public.aos_cia_keys_union_v2(text[],text[]),
 public.aos_cia_domain_absent_keys_v2(text),public.aos_cia_audience_leaf_keys_v2(jsonb),
 public.aos_cia_audience_leaf_keys_v3(jsonb),public.aos_cia_audience_resolve_node_v2(jsonb,integer),
 public.aos_cia_audience_count_v2(jsonb),public.aos_cia_preview_core_v2(text[]),
 public.aos_cia_preview_activity_v2(text[]),public.aos_cia_audience_preview_v2(jsonb,integer,integer)
to service_role;

commit;
