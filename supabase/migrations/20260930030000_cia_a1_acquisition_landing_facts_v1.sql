-- ASCENDA CIA · A1 Acquisition / Landing Facts V1
-- Additive lineage projection for web/landing bookings.
-- No Call Center distribution, email send or WhatsApp send is enabled here.

begin;

create index if not exists idx_landing_booking_attr_contact_created_v1
  on public.aos_landing_booking_attribution(numero_limpio, created_at desc);

create or replace view public.aos_cia_acquisition_facts_v1 as
with base as (
  select
    public.aos_cia_normalize_contact_key_v1(a.numero_limpio) as contact_key,
    a.id,a.agenda_id,a.source_channel,a.landing_code,a.landing_name,a.landing_url,
    a.plataforma,a.campaign_code,a.campaign_name,a.ad_code,a.ad_name,a.treatment_id,
    a.tratamiento,a.advisor_code,a.utm_source,a.utm_medium,a.utm_campaign,a.utm_content,
    a.utm_term,a.referrer_url,a.client_event_id,a.created_at
  from public.aos_landing_booking_attribution a
  where public.aos_cia_normalize_contact_key_v1(a.numero_limpio) is not null
), agg as (
  select contact_key,count(*)::integer as web_booking_count,min(created_at) as first_web_booking_at,max(created_at) as last_web_booking_at
  from base group by contact_key
), latest as (
  select distinct on(contact_key) * from base order by contact_key,created_at desc nulls last,id desc
)
select
  1::integer as facts_version,g.contact_key,g.web_booking_count,g.first_web_booking_at,g.last_web_booking_at,
  l.source_channel as latest_acquisition_channel,l.plataforma as latest_platform,
  l.landing_code as latest_landing_code,l.landing_name as latest_landing_name,l.landing_url as latest_landing_url,
  l.campaign_code as latest_campaign_code,l.campaign_name as latest_campaign_name,
  l.ad_code as latest_ad_code,l.ad_name as latest_ad_name,l.treatment_id as latest_treatment_id,
  l.tratamiento as latest_treatment,l.advisor_code as latest_advisor_code,
  l.utm_source as latest_utm_source,l.utm_medium as latest_utm_medium,l.utm_campaign as latest_utm_campaign,
  l.utm_content as latest_utm_content,l.utm_term as latest_utm_term,l.referrer_url as latest_referrer_url,
  l.client_event_id as latest_client_event_id,g.last_web_booking_at as source_last_at
from agg g join latest l using(contact_key);

alter table public.aos_cia_contact_runtime_cache_v1
  add column if not exists web_booking_count integer not null default 0,
  add column if not exists first_web_booking_at timestamptz,
  add column if not exists last_web_booking_at timestamptz,
  add column if not exists latest_acquisition_channel text,
  add column if not exists latest_platform text,
  add column if not exists latest_landing_code text,
  add column if not exists latest_landing_name text,
  add column if not exists latest_landing_url text,
  add column if not exists latest_campaign_code text,
  add column if not exists latest_campaign_name text,
  add column if not exists latest_ad_code text,
  add column if not exists latest_ad_name text,
  add column if not exists latest_treatment_id uuid,
  add column if not exists latest_treatment text,
  add column if not exists latest_advisor_code text,
  add column if not exists latest_utm_source text,
  add column if not exists latest_utm_medium text,
  add column if not exists latest_utm_campaign text,
  add column if not exists latest_utm_content text,
  add column if not exists latest_utm_term text,
  add column if not exists latest_referrer_url text,
  add column if not exists latest_client_event_id text,
  add column if not exists acquisition_source_last_at timestamptz;

create index if not exists idx_cia_runtime_web_booking_v1 on public.aos_cia_contact_runtime_cache_v1(web_booking_count) where web_booking_count>0;
create index if not exists idx_cia_runtime_platform_v1 on public.aos_cia_contact_runtime_cache_v1(latest_platform) where latest_platform is not null;
create index if not exists idx_cia_runtime_landing_v1 on public.aos_cia_contact_runtime_cache_v1(latest_landing_code) where latest_landing_code is not null;
create index if not exists idx_cia_runtime_campaign_v1 on public.aos_cia_contact_runtime_cache_v1(latest_campaign_code) where latest_campaign_code is not null;
create index if not exists idx_cia_runtime_ad_v1 on public.aos_cia_contact_runtime_cache_v1(latest_ad_code) where latest_ad_code is not null;

create or replace view public.aos_cia_acquisition_adapter_v1 as
select contact_key,web_booking_count,first_web_booking_at,last_web_booking_at,latest_acquisition_channel,latest_platform,
 latest_landing_code,latest_landing_name,latest_landing_url,latest_campaign_code,latest_campaign_name,latest_ad_code,
 latest_ad_name,latest_treatment_id,latest_treatment,latest_advisor_code,latest_utm_source,latest_utm_medium,
 latest_utm_campaign,latest_utm_content,latest_utm_term,latest_referrer_url,latest_client_event_id,acquisition_source_last_at
from public.aos_cia_contact_runtime_cache_v1;

-- Keep the original audience source contract intact and append purchase detail + acquisition columns.
-- This avoids a circular v1 -> v1_1 -> v1 dependency.
create or replace view public.aos_cia_audience_source_v1 as
select
  f.facts_version,f.identity_version,f.contact_key,f.identity_status,f.canonical_patient_id,f.identity_conflict,
  f.lead_count,f.first_lead_at,f.last_lead_at,f.days_since_last_lead,f.latest_lead_id,f.latest_interest,f.latest_interest_type,f.lead_interests,f.lead_interest_types,f.latest_ad,f.lead_ads,
  f.call_count,f.calls_never_called,f.first_call_at,f.last_call_at,f.days_since_last_call,f.latest_call_id,f.latest_call_status,f.latest_call_substatus,f.latest_call_advisor_id,f.latest_call_advisor_label,f.latest_call_treatment,f.call_ever_statuses,f.called_today,f.max_call_attempt,f.effective_contact_count,f.non_contact_count,f.lead_never_called,f.lead_called_since_latest_entry,f.lead_unworked_since_latest_entry,
  f.appointment_count,f.appointments_never_had,f.last_appointment_at,f.last_appointment_status,f.last_appointment_treatment,f.last_appointment_branch,f.next_appointment_at,f.next_appointment_status,f.next_appointment_treatment,f.next_appointment_branch,f.has_future_appointment,f.no_show_count,f.ever_no_show,f.attended_count,f.last_attended_at,f.appointment_statuses,
  f.sale_count,f.sales_never_bought,f.revenue_lifetime,f.first_sale_at,f.last_sale_at,f.days_since_last_sale,f.product_count,f.service_count,f.product_revenue,f.service_revenue,f.products,f.services,f.latest_item_type,f.latest_item,f.latest_sale_branch,f.latest_sale_advisor_id,f.latest_sale_advisor_label,f.payment_states,f.payment_methods,
  f.followup_count,f.pending_followup_count,f.overdue_followup_count,f.completed_followup_count,f.next_followup_at,f.oldest_overdue_at,f.latest_followup_advisor_id,f.latest_followup_advisor_label,f.followup_treatments,
  f.email_identity_confidence,f.email_sent_count,f.email_never_sent,f.email_last_sent_at,f.email_days_since_last,f.email_delivered_count,f.email_opened_count,f.email_clicked_count,f.email_bounced_count,f.email_last_event_at,f.facts_observed_at,f.provenance,
  p.canonical_names,p.canonical_surnames,p.canonical_email,p.email_valid,p.phone_valid,p.exists_as_patient,p.exists_as_lead,p.is_fused_only,p.source_flags,p.patient_state,p.base_label,p.base_campaign,p.branch as crm_branch,p.department,p.city,p.district,p.sex,p.age_years,p.age_band,
  s.policy_key as segment_policy_key,s.policy_version as segment_policy_version,s.policy_status as segment_policy_status,s.value_tier,s.value_score,s.lifecycle,s.customer_last_activity_at,s.engagement,s.engagement_score,s.traits,s.calculated_at as segment_calculated_at,s.explanation as segment_explanation,
  case when f.next_appointment_at is not null then f.next_appointment_at-(now() at time zone 'America/Lima')::date else null::integer end as days_until_next_appointment,
  case when f.next_followup_at is not null then f.next_followup_at-(now() at time zone 'America/Lima')::date else null::integer end as days_until_next_followup,
  d.product_mapped_count,d.product_unresolved_count,d.canonical_products,d.product_categories,d.service_unresolved_count,d.service_category_unresolved_count,d.canonical_services,d.service_categories,
  coalesce(a.web_booking_count,0)::integer as web_booking_count,a.first_web_booking_at,a.last_web_booking_at,a.latest_acquisition_channel,a.latest_platform,a.latest_landing_code,a.latest_landing_name,a.latest_landing_url,a.latest_campaign_code,a.latest_campaign_name,a.latest_ad_code,a.latest_ad_name,a.latest_treatment_id,a.latest_treatment,a.latest_advisor_code,a.latest_utm_source,a.latest_utm_medium,a.latest_utm_campaign,a.latest_utm_content,a.latest_utm_term,a.latest_referrer_url,a.latest_client_event_id,a.source_last_at as acquisition_source_last_at
from public.aos_cia_commercial_facts_v1 f
join public.aos_cia_profile_facts_v1 p using(contact_key)
left join public.aos_cia_customer_segments_v1 s using(contact_key)
join public.aos_cia_purchase_detail_facts_v1 d using(contact_key)
left join public.aos_cia_acquisition_facts_v1 a using(contact_key);

insert into public.aos_audience_filter_registry
(field_key,label,category,data_type,allowed_operators,enum_values,source_column,ui_visible,active,registry_version,description,created_at,updated_at)
values
('acquisition.web_booking_count','Reservas web','ACQUISITION','integer',array['eq','neq','gt','gte','lt','lte','between']::text[],null,'web_booking_count',true,true,1,'Direct web/landing booking count',now(),now()),
('acquisition.first_web_booking_at','Primera reserva web','ACQUISITION','date',array['before','after','between','within_last_days','older_than_days','exists','not_exists']::text[],null,'first_web_booking_at',true,true,1,'First landing/web booking timestamp',now(),now()),
('acquisition.last_web_booking_at','Última reserva web','ACQUISITION','date',array['before','after','between','within_last_days','older_than_days','exists','not_exists']::text[],null,'last_web_booking_at',true,true,1,'Latest landing/web booking timestamp',now(),now()),
('acquisition.channel','Canal de adquisición web','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_acquisition_channel',true,true,1,'Latest canonical web acquisition channel',now(),now()),
('acquisition.platform','Plataforma','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_platform',true,true,1,'Latest acquisition platform',now(),now()),
('acquisition.landing_code','Landing · código','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_landing_code',true,true,1,'Latest canonical landing code',now(),now()),
('acquisition.landing_name','Landing','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_landing_name',true,true,1,'Latest canonical landing name',now(),now()),
('acquisition.campaign_code','Campaña · código','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_campaign_code',true,true,1,'Latest canonical campaign code',now(),now()),
('acquisition.campaign_name','Campaña','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_campaign_name',true,true,1,'Latest canonical campaign name',now(),now()),
('acquisition.ad_code','Anuncio · código','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_ad_code',true,true,1,'Latest canonical ad code',now(),now()),
('acquisition.ad_name','Anuncio','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_ad_name',true,true,1,'Latest canonical ad name',now(),now()),
('acquisition.treatment','Tratamiento de landing','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_treatment',true,true,1,'Latest landing treatment',now(),now()),
('acquisition.utm_source','UTM source','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_utm_source',true,true,1,'Latest utm_source',now(),now()),
('acquisition.utm_medium','UTM medium','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_utm_medium',true,true,1,'Latest utm_medium',now(),now()),
('acquisition.utm_campaign','UTM campaign','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_utm_campaign',true,true,1,'Latest utm_campaign',now(),now()),
('acquisition.utm_content','UTM content','ACQUISITION','text',array['eq','neq','contains','in','not_in','exists','not_exists']::text[],null,'latest_utm_content',true,true,1,'Latest utm_content',now(),now())
on conflict(field_key) do update set label=excluded.label,category=excluded.category,data_type=excluded.data_type,allowed_operators=excluded.allowed_operators,source_column=excluded.source_column,ui_visible=true,active=true,description=excluded.description,updated_at=now();

insert into public.aos_cia_filter_execution_map_v2(field_key,source_key,source_column,special_key,data_type,updated_at)
select field_key,'ACQUISITION',source_column,null,data_type,now()
from public.aos_audience_filter_registry where category='ACQUISITION' and active=true
on conflict(field_key) do update set source_key='ACQUISITION',source_column=excluded.source_column,special_key=null,data_type=excluded.data_type,updated_at=now();

create or replace function public.aos_cia_audience_get_value_v1(p_row jsonb,p_field text)
returns jsonb language sql immutable parallel safe as $function$
select case p_field
when 'contact.identity_status' then p_row->'identity_status' when 'contact.identity_conflict' then p_row->'identity_conflict' when 'contact.email_valid' then p_row->'email_valid' when 'contact.exists_as_patient' then p_row->'exists_as_patient' when 'contact.exists_as_lead' then p_row->'exists_as_lead'
when 'crm.patient_state' then p_row->'patient_state' when 'crm.base_label' then p_row->'base_label' when 'crm.base_campaign' then p_row->'base_campaign' when 'crm.branch' then p_row->'crm_branch' when 'crm.department' then p_row->'department' when 'crm.city' then p_row->'city' when 'crm.district' then p_row->'district' when 'crm.sex' then p_row->'sex' when 'crm.age_years' then p_row->'age_years' when 'crm.age_band' then p_row->'age_band'
when 'lead.count' then p_row->'lead_count' when 'lead.days_since_last' then p_row->'days_since_last_lead' when 'lead.latest_interest' then p_row->'latest_interest' when 'lead.latest_interest_type' then p_row->'latest_interest_type' when 'lead.interests' then p_row->'lead_interests' when 'lead.ads' then p_row->'lead_ads' when 'lead.called_since_latest_entry' then p_row->'lead_called_since_latest_entry' when 'lead.unworked_since_latest_entry' then p_row->'lead_unworked_since_latest_entry'
when 'calls.total' then p_row->'call_count' when 'calls.never_called' then p_row->'calls_never_called' when 'calls.days_since_last' then p_row->'days_since_last_call' when 'calls.latest_status' then p_row->'latest_call_status' when 'calls.latest_substatus' then p_row->'latest_call_substatus' when 'calls.ever_statuses' then p_row->'call_ever_statuses' when 'calls.called_today' then p_row->'called_today' when 'calls.effective_contact_count' then p_row->'effective_contact_count'
when 'appointments.total' then p_row->'appointment_count' when 'appointments.never_had' then p_row->'appointments_never_had' when 'appointments.last_at' then p_row->'last_appointment_at' when 'appointments.last_status' then p_row->'last_appointment_status' when 'appointments.next_at' then p_row->'next_appointment_at' when 'appointments.has_future' then p_row->'has_future_appointment' when 'appointments.no_show_count' then p_row->'no_show_count' when 'appointments.ever_no_show' then p_row->'ever_no_show' when 'appointments.attended_count' then p_row->'attended_count' when 'appointments.statuses' then p_row->'appointment_statuses'
when 'sales.total' then p_row->'sale_count' when 'sales.never_bought' then p_row->'sales_never_bought' when 'sales.revenue_lifetime' then p_row->'revenue_lifetime' when 'sales.days_since_last' then p_row->'days_since_last_sale' when 'sales.product_count' then p_row->'product_count' when 'sales.service_count' then p_row->'service_count' when 'sales.products' then p_row->'products' when 'sales.services' then p_row->'services' when 'sales.latest_item_type' then p_row->'latest_item_type' when 'sales.payment_states' then p_row->'payment_states' when 'sales.payment_methods' then p_row->'payment_methods'
when 'followups.pending_count' then p_row->'pending_followup_count' when 'followups.overdue_count' then p_row->'overdue_followup_count' when 'followups.next_at' then p_row->'next_followup_at' when 'followups.treatments' then p_row->'followup_treatments'
when 'email.sent_count' then p_row->'email_sent_count' when 'email.never_sent' then p_row->'email_never_sent' when 'email.days_since_last' then p_row->'email_days_since_last' when 'email.opened_count' then p_row->'email_opened_count' when 'email.clicked_count' then p_row->'email_clicked_count' when 'email.bounced_count' then p_row->'email_bounced_count'
when 'segment.value_tier' then p_row->'value_tier' when 'segment.value_score' then p_row->'value_score' when 'segment.lifecycle' then p_row->'lifecycle' when 'segment.engagement' then p_row->'engagement' when 'segment.traits' then p_row->'traits'
when 'acquisition.web_booking_count' then p_row->'web_booking_count' when 'acquisition.first_web_booking_at' then p_row->'first_web_booking_at' when 'acquisition.last_web_booking_at' then p_row->'last_web_booking_at' when 'acquisition.channel' then p_row->'latest_acquisition_channel' when 'acquisition.platform' then p_row->'latest_platform' when 'acquisition.landing_code' then p_row->'latest_landing_code' when 'acquisition.landing_name' then p_row->'latest_landing_name' when 'acquisition.campaign_code' then p_row->'latest_campaign_code' when 'acquisition.campaign_name' then p_row->'latest_campaign_name' when 'acquisition.ad_code' then p_row->'latest_ad_code' when 'acquisition.ad_name' then p_row->'latest_ad_name' when 'acquisition.treatment' then p_row->'latest_treatment' when 'acquisition.utm_source' then p_row->'latest_utm_source' when 'acquisition.utm_medium' then p_row->'latest_utm_medium' when 'acquisition.utm_campaign' then p_row->'latest_utm_campaign' when 'acquisition.utm_content' then p_row->'latest_utm_content'
else null end
$function$;

create or replace function public.aos_cia_audience_leaf_keys_v3(p_rule jsonb)
returns text[] language plpgsql stable as $function$
declare keys text[]; absent text[]; sk text; default_row jsonb;
begin
 select source_key into sk from public.aos_cia_filter_execution_map_v2 where field_key=p_rule->>'field';
 if sk='ACQUISITION' then
   select coalesce(array_agg(s.contact_key order by s.contact_key),array[]::text[]) into keys
   from public.aos_cia_acquisition_adapter_v1 s
   where public.aos_cia_audience_rule_match_v1(to_jsonb(s),p_rule);
   return coalesce(keys,array[]::text[]);
 end if;
 keys:=public.aos_cia_audience_leaf_keys_v2(p_rule);
 if sk in ('LEAD','CALL','APPOINTMENT','SALE','FOLLOWUP') then
   select d.default_row into default_row from public.aos_cia_domain_defaults_v2 d where d.source_key=sk;
   if default_row is not null and public.aos_cia_audience_rule_match_v1(default_row,p_rule) then
     absent:=public.aos_cia_domain_absent_keys_v2(sk); keys:=public.aos_cia_keys_union_v2(keys,absent);
   end if;
 end if;
 return coalesce(keys,array[]::text[]);
end
$function$;

insert into public.aos_audience_presets(preset_key,name,description,category,dsl,registry_version,active,created_at,updated_at)
values
('WEB_BOOKINGS','Reservaron desde web/landing','Contactos con al menos una reserva trazada desde una landing.','ACQUISITION','{"version":1,"root":{"op":"AND","rules":[{"field":"acquisition.web_booking_count","operator":"gt","value":0}]}}'::jsonb,1,true,now(),now()),
('WEB_BOOKINGS_FUTURE','Web con cita futura','Reservaron desde landing y mantienen una próxima cita activa.','ACQUISITION','{"version":1,"root":{"op":"AND","rules":[{"field":"acquisition.web_booking_count","operator":"gt","value":0},{"field":"appointments.has_future","operator":"is_true"}]}}'::jsonb,1,true,now(),now()),
('WEB_BOOKINGS_NO_PURCHASE','Web sin compra','Reservaron desde landing y todavía no registran compra.','ACQUISITION','{"version":1,"root":{"op":"AND","rules":[{"field":"acquisition.web_booking_count","operator":"gt","value":0},{"field":"sales.never_bought","operator":"is_true"}]}}'::jsonb,1,true,now(),now())
on conflict(preset_key) do update set name=excluded.name,description=excluded.description,category=excluded.category,dsl=excluded.dsl,active=true,updated_at=now();

insert into public.aos_audience_preset_runtime_cache_v1(preset_key,count_cache,refreshed_at,duration_ms,status,error_code,updated_at)
values('WEB_BOOKINGS',0,now(),0,'READY',null,now()),('WEB_BOOKINGS_FUTURE',0,now(),0,'READY',null,now()),('WEB_BOOKINGS_NO_PURCHASE',0,now(),0,'READY',null,now())
on conflict(preset_key) do nothing;

commit;
