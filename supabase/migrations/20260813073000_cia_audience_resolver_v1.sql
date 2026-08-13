-- ASCENDA OS — Commercial Intelligence & Audience OS
-- Phase 4 — Audience Resolver V1
-- Declarative, whitelisted, read-only audience resolution.

begin;

-- -----------------------------------------------------------------------------
-- PROFILE FACTS V1 — demographic/CRM read layer. No source mutation.
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_profile_facts_v1
with (security_invoker = true)
as
with pbase as (
  select
    i.contact_key,
    i.identity_status,
    i.identity_conflict,
    i.phone_valid,
    i.canonical_names,
    i.canonical_surnames,
    i.canonical_email,
    i.source_flags,
    i.canonical_patient_id,
    p."ESTADO_PACIENTE" as patient_state,
    nullif(btrim(p."ETIQUETA_BASE"),'') as patient_base_label,
    nullif(btrim(p."SEDE_PRINCIPAL"),'') as patient_branch,
    nullif(btrim(p.departamento),'') as department,
    nullif(btrim(p.ciudad),'') as city,
    nullif(btrim(p.distrito),'') as district,
    nullif(upper(btrim(p."Sexo")),'') as sex,
    case
      when p."Fecha de nacimiento" ~ '^\d{1,2}/\d{1,2}/\d{4}$' then to_date(p."Fecha de nacimiento", 'DD/MM/YYYY')
      when p."Fecha de nacimiento" ~ '^\d{4}-\d{2}-\d{2}$' then to_date(p."Fecha de nacimiento", 'YYYY-MM-DD')
      else null
    end as parsed_birth_date
  from public.aos_cia_contact_identity_v1 i
  left join public.aos_pacientes p
    on p."ID_PACIENTE" = i.canonical_patient_id
), enriched as (
  select
    pb.*,
    f.latest_sale_branch,
    f.next_appointment_branch,
    f.last_appointment_branch,
    f.lead_count,
    be.etiqueta as operational_base_label,
    be.campana as operational_campaign,
    case
      when pb.parsed_birth_date is not null
       and pb.parsed_birth_date <= (now() at time zone 'America/Lima')::date
       and pb.parsed_birth_date >= ((now() at time zone 'America/Lima')::date - interval '120 years')::date
      then date_part('year', age((now() at time zone 'America/Lima')::date, pb.parsed_birth_date))::integer
      else null
    end as age_years
  from pbase pb
  left join public.aos_cia_commercial_facts_v1 f using (contact_key)
  left join public.aos_base_etiquetas be
    on public.aos_cia_normalize_contact_key_v1(be.numero) = pb.contact_key
)
select
  1::integer as profile_version,
  e.contact_key,
  e.identity_status,
  e.identity_conflict,
  e.phone_valid,
  e.canonical_names,
  e.canonical_surnames,
  e.canonical_email,
  case
    when e.canonical_email is null or btrim(e.canonical_email) = '' then null
    when lower(btrim(e.canonical_email)) ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then true
    else false
  end as email_valid,
  (e.canonical_patient_id is not null) as exists_as_patient,
  (coalesce(e.lead_count,0) > 0) as exists_as_lead,
  (e.identity_status = 'FUSED_ONLY') as is_fused_only,
  e.source_flags,
  e.patient_state,
  coalesce(e.patient_base_label, nullif(btrim(e.operational_base_label),'')) as base_label,
  nullif(btrim(e.operational_campaign),'') as base_campaign,
  coalesce(e.patient_branch, nullif(btrim(e.latest_sale_branch),''), nullif(btrim(e.next_appointment_branch),''), nullif(btrim(e.last_appointment_branch),'')) as branch,
  e.department,
  e.city,
  e.district,
  e.sex,
  e.age_years,
  case
    when e.age_years is null then null
    when e.age_years < 18 then 'UNDER_18'
    when e.age_years <= 24 then '18_24'
    when e.age_years <= 34 then '25_34'
    when e.age_years <= 44 then '35_44'
    when e.age_years <= 54 then '45_54'
    when e.age_years <= 64 then '55_64'
    else '65_PLUS'
  end::text as age_band,
  statement_timestamp() as observed_at
from enriched e;

comment on view public.aos_cia_profile_facts_v1 is
'CIA Profile Facts V1: canonical CRM/demographic read layer keyed by Identity V1; no raw clinical data.';

-- -----------------------------------------------------------------------------
-- AUDIENCE SOURCE V1 — one row per contact, joining semantic layers only.
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_audience_source_v1
with (security_invoker = true)
as
select
  f.*,
  p.canonical_names,
  p.canonical_surnames,
  p.canonical_email,
  p.email_valid,
  p.phone_valid,
  p.exists_as_patient,
  p.exists_as_lead,
  p.is_fused_only,
  p.source_flags,
  p.patient_state,
  p.base_label,
  p.base_campaign,
  p.branch as crm_branch,
  p.department,
  p.city,
  p.district,
  p.sex,
  p.age_years,
  p.age_band,
  s.policy_key as segment_policy_key,
  s.policy_version as segment_policy_version,
  s.policy_status as segment_policy_status,
  s.value_tier,
  s.value_score,
  s.lifecycle,
  s.customer_last_activity_at,
  s.engagement,
  s.engagement_score,
  s.traits,
  s.calculated_at as segment_calculated_at,
  s.explanation as segment_explanation
from public.aos_cia_commercial_facts_v1 f
join public.aos_cia_profile_facts_v1 p using (contact_key)
join public.aos_cia_customer_segments_v1 s using (contact_key);

comment on view public.aos_cia_audience_source_v1 is
'CIA Audience Source V1: one semantic row per contact_key for whitelisted audience evaluation.';

-- -----------------------------------------------------------------------------
-- FILTER REGISTRY V1
-- -----------------------------------------------------------------------------
create table if not exists public.aos_audience_filter_registry (
  field_key text primary key,
  label text not null,
  category text not null,
  data_type text not null check (data_type in ('text','enum','boolean','boolean3','integer','numeric','date','timestamp','set')),
  allowed_operators text[] not null,
  enum_values text[] null,
  source_column text not null,
  ui_visible boolean not null default true,
  active boolean not null default true,
  registry_version integer not null default 1,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.aos_audience_filter_registry enable row level security;

insert into public.aos_audience_filter_registry
(field_key,label,category,data_type,allowed_operators,enum_values,source_column,description)
values
('contact.identity_status','Estado identidad','CONTACT','enum',array['eq','neq','in','not_in'],array['RESOLVED','CONFLICT','FUSED_ONLY','NO_PATIENT_PROFILE'],'identity_status','Identity Resolver V1 status'),
('contact.identity_conflict','Conflicto identidad','CONTACT','boolean',array['is_true','is_false'],null,'identity_conflict','Multiple non-fused patient profiles'),
('contact.email_valid','Email válido','CONTACT','boolean3',array['is_true','is_false','is_unknown'],null,'email_valid','Canonical patient email format status'),
('contact.exists_as_patient','Existe como paciente','CONTACT','boolean',array['is_true','is_false'],null,'exists_as_patient','Canonical patient exists'),
('contact.exists_as_lead','Existe como lead','CONTACT','boolean',array['is_true','is_false'],null,'exists_as_lead','At least one lead exists'),
('crm.patient_state','Estado paciente','CRM','text',array['eq','neq','in','not_in','exists','not_exists'],null,'patient_state','Canonical patient state'),
('crm.base_label','Etiqueta base','CRM','text',array['eq','neq','contains','in','not_in','exists','not_exists'],null,'base_label','Canonical/operational base label'),
('crm.base_campaign','Campaña base','CRM','text',array['eq','neq','contains','in','not_in','exists','not_exists'],null,'base_campaign','Operational base campaign'),
('crm.branch','Sede','CRM','text',array['eq','neq','in','not_in','exists','not_exists'],null,'crm_branch','Derived commercial branch'),
('crm.department','Departamento','DEMOGRAPHIC','text',array['eq','neq','contains','in','not_in','exists','not_exists'],null,'department','Canonical department'),
('crm.city','Ciudad','DEMOGRAPHIC','text',array['eq','neq','contains','in','not_in','exists','not_exists'],null,'city','Canonical city'),
('crm.district','Distrito','DEMOGRAPHIC','text',array['eq','neq','contains','in','not_in','exists','not_exists'],null,'district','Canonical district'),
('crm.sex','Sexo','DEMOGRAPHIC','text',array['eq','neq','in','not_in','exists','not_exists'],null,'sex','Canonical normalized sex label'),
('crm.age_years','Edad','DEMOGRAPHIC','integer',array['eq','neq','gt','gte','lt','lte','between','exists','not_exists'],null,'age_years','Derived age in years when DOB is parseable'),
('crm.age_band','Rango edad','DEMOGRAPHIC','enum',array['eq','neq','in','not_in','exists','not_exists'],array['UNDER_18','18_24','25_34','35_44','45_54','55_64','65_PLUS'],'age_band','Derived age band'),
('lead.count','Cantidad leads','LEAD','integer',array['eq','neq','gt','gte','lt','lte','between'],null,'lead_count','Lead entry count'),
('lead.days_since_last','Días desde último lead','LEAD','integer',array['eq','gt','gte','lt','lte','between','exists','not_exists'],null,'days_since_last_lead','Days since latest lead'),
('lead.latest_interest','Último interés','LEAD','text',array['eq','neq','contains','in','not_in','exists','not_exists'],null,'latest_interest','Latest lead interest'),
('lead.latest_interest_type','Tipo interés','LEAD','enum',array['eq','neq','in','not_in','exists','not_exists'],array['PRODUCTO','SERVICIO','UNKNOWN'],'latest_interest_type','Latest interest taxonomy type'),
('lead.interests','Intereses históricos','LEAD','set',array['contains','contains_any','contains_all','not_contains'],null,'lead_interests','Historical lead interests'),
('lead.ads','Anuncios históricos','LEAD','set',array['contains','contains_any','contains_all','not_contains'],null,'lead_ads','Historical lead ads'),
('lead.called_since_latest_entry','Llamado desde último ingreso','LEAD','boolean3',array['is_true','is_false','is_unknown'],null,'lead_called_since_latest_entry','Call exists after latest lead entry'),
('lead.unworked_since_latest_entry','Lead sin trabajar','LEAD','boolean3',array['is_true','is_false','is_unknown'],null,'lead_unworked_since_latest_entry','Latest lead entry has no later call'),
('calls.total','Cantidad llamadas','CALL','integer',array['eq','neq','gt','gte','lt','lte','between'],null,'call_count','Known call rows'),
('calls.never_called','Nunca llamado','CALL','boolean',array['is_true','is_false'],null,'calls_never_called','No call history'),
('calls.days_since_last','Días desde última llamada','CALL','integer',array['eq','gt','gte','lt','lte','between','exists','not_exists'],null,'days_since_last_call','Days since latest call'),
('calls.latest_status','Última tipificación','CALL','text',array['eq','neq','in','not_in','exists','not_exists'],null,'latest_call_status','Latest normalized call status'),
('calls.latest_substatus','Último subestado','CALL','text',array['eq','neq','contains','in','not_in','exists','not_exists'],null,'latest_call_substatus','Latest call substatus'),
('calls.ever_statuses','Tipificaciones históricas','CALL','set',array['contains','contains_any','contains_all','not_contains'],null,'call_ever_statuses','Historical normalized call statuses'),
('calls.called_today','Llamado hoy','CALL','boolean',array['is_true','is_false'],null,'called_today','Call exists today Lima'),
('calls.effective_contact_count','Contactos efectivos','CALL','integer',array['eq','gt','gte','lt','lte','between'],null,'effective_contact_count','Known effective-contact calls'),
('appointments.total','Cantidad citas','APPOINTMENT','integer',array['eq','neq','gt','gte','lt','lte','between'],null,'appointment_count','Known appointments'),
('appointments.never_had','Nunca tuvo cita','APPOINTMENT','boolean',array['is_true','is_false'],null,'appointments_never_had','No appointment history'),
('appointments.last_at','Última cita','APPOINTMENT','date',array['before','after','between','within_last_days','older_than_days','exists','not_exists'],null,'last_appointment_at','Latest past/present appointment'),
('appointments.last_status','Estado última cita','APPOINTMENT','text',array['eq','neq','in','not_in','exists','not_exists'],null,'last_appointment_status','Latest appointment status'),
('appointments.next_at','Próxima cita','APPOINTMENT','date',array['before','after','between','exists','not_exists'],null,'next_appointment_at','Next active future appointment'),
('appointments.has_future','Tiene cita futura','APPOINTMENT','boolean',array['is_true','is_false'],null,'has_future_appointment','Future active appointment exists'),
('appointments.no_show_count','Cantidad no-show','APPOINTMENT','integer',array['eq','gt','gte','lt','lte','between'],null,'no_show_count','NO ASISTIO count'),
('appointments.ever_no_show','Alguna vez no-show','APPOINTMENT','boolean',array['is_true','is_false'],null,'ever_no_show','Any no-show history'),
('appointments.attended_count','Asistencias','APPOINTMENT','integer',array['eq','gt','gte','lt','lte','between'],null,'attended_count','ASISTIO/EFECTIVA count'),
('appointments.statuses','Estados cita históricos','APPOINTMENT','set',array['contains','contains_any','contains_all','not_contains'],null,'appointment_statuses','Historical appointment statuses'),
('sales.total','Cantidad compras','SALE','integer',array['eq','neq','gt','gte','lt','lte','between'],null,'sale_count','Known sales'),
('sales.never_bought','Nunca compró','SALE','boolean',array['is_true','is_false'],null,'sales_never_bought','No sales history'),
('sales.revenue_lifetime','Facturación lifetime','SALE','numeric',array['eq','neq','gt','gte','lt','lte','between'],null,'revenue_lifetime','Lifetime sales amount'),
('sales.days_since_last','Días desde última compra','SALE','integer',array['eq','gt','gte','lt','lte','between','exists','not_exists'],null,'days_since_last_sale','Days since latest sale'),
('sales.product_count','Compras producto','SALE','integer',array['eq','gt','gte','lt','lte','between'],null,'product_count','Product purchase count'),
('sales.service_count','Compras servicio','SALE','integer',array['eq','gt','gte','lt','lte','between'],null,'service_count','Service purchase count'),
('sales.products','Productos comprados','SALE','set',array['contains','contains_any','contains_all','not_contains'],null,'products','Purchased product set'),
('sales.services','Servicios comprados','SALE','set',array['contains','contains_any','contains_all','not_contains'],null,'services','Purchased service set'),
('sales.latest_item_type','Tipo última compra','SALE','enum',array['eq','neq','in','not_in','exists','not_exists'],array['PRODUCTO','SERVICIO'],'latest_item_type','Latest sale type'),
('sales.payment_states','Estados pago','SALE','set',array['contains','contains_any','contains_all','not_contains'],null,'payment_states','Observed payment states'),
('sales.payment_methods','Métodos pago','SALE','set',array['contains','contains_any','contains_all','not_contains'],null,'payment_methods','Observed payment methods'),
('followups.pending_count','Seguimientos pendientes','FOLLOWUP','integer',array['eq','gt','gte','lt','lte','between'],null,'pending_followup_count','Pending follow-up count'),
('followups.overdue_count','Seguimientos vencidos','FOLLOWUP','integer',array['eq','gt','gte','lt','lte','between'],null,'overdue_followup_count','Overdue follow-up count'),
('followups.next_at','Próximo seguimiento','FOLLOWUP','date',array['before','after','between','within_last_days','exists','not_exists'],null,'next_followup_at','Next pending follow-up date'),
('followups.treatments','Tratamientos seguimiento','FOLLOWUP','set',array['contains','contains_any','contains_all','not_contains'],null,'followup_treatments','Follow-up treatment set'),
('email.sent_count','Emails enviados','EMAIL','integer',array['eq','gt','gte','lt','lte','between'],null,'email_sent_count','Safely reconciled unique sends'),
('email.never_sent','Nunca recibió email','EMAIL','boolean3',array['is_true','is_false','is_unknown'],null,'email_never_sent','BOOLEAN3 email never-sent fact'),
('email.days_since_last','Días desde último email','EMAIL','integer',array['eq','gt','gte','lt','lte','between','exists','not_exists'],null,'email_days_since_last','Days since last safely mapped send'),
('email.opened_count','Aperturas email','EMAIL','integer',array['eq','gt','gte','lt','lte','between'],null,'email_opened_count','Known opened evidence'),
('email.clicked_count','Clicks email','EMAIL','integer',array['eq','gt','gte','lt','lte','between'],null,'email_clicked_count','Known click evidence'),
('email.bounced_count','Rebotes email','EMAIL','integer',array['eq','gt','gte','lt','lte','between'],null,'email_bounced_count','Known bounce evidence'),
('segment.value_tier','Nivel valor','SEGMENT','enum',array['eq','neq','in','not_in'],array['STANDARD','PREMIUM','GOLD','DIAMANTE'],'value_tier','Policy-versioned commercial value tier'),
('segment.value_score','Score valor','SEGMENT','integer',array['eq','gt','gte','lt','lte','between'],null,'value_score','Value score 0-9'),
('segment.lifecycle','Lifecycle','SEGMENT','enum',array['eq','neq','in','not_in'],array['NEW_CUSTOMER','ACTIVE_CUSTOMER','COOLING_CUSTOMER','INACTIVE_CUSTOMER','APPOINTMENT_READY_PROSPECT','DISQUALIFIED_PROSPECT','ACTIVE_PROSPECT','WARM_PROSPECT','COLD_PROSPECT','PROFILE_ONLY'],'lifecycle','Commercial lifecycle V1'),
('segment.engagement','Engagement','SEGMENT','enum',array['eq','neq','in','not_in'],array['LOW','MEDIUM','HIGH'],'engagement','Commercial engagement V1'),
('segment.traits','Características comerciales','SEGMENT','set',array['contains','contains_any','contains_all','not_contains'],null,'traits','Non-exclusive commercial traits')
on conflict (field_key) do update set
  label=excluded.label, category=excluded.category, data_type=excluded.data_type,
  allowed_operators=excluded.allowed_operators, enum_values=excluded.enum_values,
  source_column=excluded.source_column, description=excluded.description,
  active=true, registry_version=1, updated_at=now();

-- -----------------------------------------------------------------------------
-- OFFICIAL PRESETS V1 — system-owned definitions, not user-saved audiences.
-- -----------------------------------------------------------------------------
create table if not exists public.aos_audience_presets (
  preset_key text primary key,
  name text not null,
  description text,
  category text not null,
  dsl jsonb not null,
  registry_version integer not null default 1,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.aos_audience_presets enable row level security;

insert into public.aos_audience_presets(preset_key,name,description,category,dsl)
values
('LEADS_UNWORKED','Leads sin trabajar','Ingreso lead más reciente sin llamada posterior','LEAD','{"version":1,"root":{"op":"AND","rules":[{"field":"lead.unworked_since_latest_entry","operator":"is_true"}]}}'::jsonb),
('LEADS_UNWORKED_7D','Leads sin trabajar — 7 días','Lead reciente sin llamada posterior','LEAD','{"version":1,"root":{"op":"AND","rules":[{"field":"lead.unworked_since_latest_entry","operator":"is_true"},{"field":"lead.days_since_last","operator":"lte","value":7}]}}'::jsonb),
('NO_SHOW_NO_FUTURE','No-show sin cita futura','Historial no-show y sin próxima cita activa','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.ever_no_show","operator":"is_true"},{"field":"appointments.has_future","operator":"is_false"}]}}'::jsonb),
('FOLLOWUP_OVERDUE','Seguimientos vencidos','Contactos con al menos un seguimiento vencido','FOLLOWUP','{"version":1,"root":{"op":"AND","rules":[{"field":"followups.overdue_count","operator":"gt","value":0}]}}'::jsonb),
('INACTIVE_CUSTOMERS','Clientes inactivos','Lifecycle comercial inactivo','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.lifecycle","operator":"eq","value":"INACTIVE_CUSTOMER"}]}}'::jsonb),
('HIGH_VALUE_COOLING','Gold/Diamante en enfriamiento','Clientes de alto valor cooling/inactive','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.value_tier","operator":"in","value":["GOLD","DIAMANTE"]},{"field":"segment.lifecycle","operator":"in","value":["COOLING_CUSTOMER","INACTIVE_CUSTOMER"]}]}}'::jsonb),
('PRODUCT_BUYERS','Compradores de producto','Tiene trait PRODUCT_BUYER','SALE','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.traits","operator":"contains","value":"PRODUCT_BUYER"}]}}'::jsonb),
('SERVICE_BUYERS','Compradores de servicio','Tiene trait SERVICE_BUYER','SALE','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.traits","operator":"contains","value":"SERVICE_BUYER"}]}}'::jsonb),
('NEVER_EMAILED_KNOWN','Nunca recibió email — evidencia segura','Solo TRUE; UNKNOWN queda fuera','EMAIL','{"version":1,"root":{"op":"AND","rules":[{"field":"email.never_sent","operator":"is_true"}]}}'::jsonb),
('ACTIVE_PROSPECTS','Prospectos activos','Lifecycle ACTIVE_PROSPECT o APPOINTMENT_READY','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.lifecycle","operator":"in","value":["ACTIVE_PROSPECT","APPOINTMENT_READY_PROSPECT"]}]}}'::jsonb)
on conflict (preset_key) do update set
 name=excluded.name, description=excluded.description, category=excluded.category,
 dsl=excluded.dsl, registry_version=1, active=true, updated_at=now();

-- -----------------------------------------------------------------------------
-- SAFE FIELD ACCESS — fixed CASE mapping. source_column metadata is never used
-- to interpolate SQL.
-- -----------------------------------------------------------------------------
create or replace function public.aos_cia_audience_get_value_v1(p_row jsonb, p_field text)
returns jsonb
language sql
immutable
parallel safe
as $$
select case p_field
  when 'contact.identity_status' then p_row->'identity_status'
  when 'contact.identity_conflict' then p_row->'identity_conflict'
  when 'contact.email_valid' then p_row->'email_valid'
  when 'contact.exists_as_patient' then p_row->'exists_as_patient'
  when 'contact.exists_as_lead' then p_row->'exists_as_lead'
  when 'crm.patient_state' then p_row->'patient_state'
  when 'crm.base_label' then p_row->'base_label'
  when 'crm.base_campaign' then p_row->'base_campaign'
  when 'crm.branch' then p_row->'crm_branch'
  when 'crm.department' then p_row->'department'
  when 'crm.city' then p_row->'city'
  when 'crm.district' then p_row->'district'
  when 'crm.sex' then p_row->'sex'
  when 'crm.age_years' then p_row->'age_years'
  when 'crm.age_band' then p_row->'age_band'
  when 'lead.count' then p_row->'lead_count'
  when 'lead.days_since_last' then p_row->'days_since_last_lead'
  when 'lead.latest_interest' then p_row->'latest_interest'
  when 'lead.latest_interest_type' then p_row->'latest_interest_type'
  when 'lead.interests' then p_row->'lead_interests'
  when 'lead.ads' then p_row->'lead_ads'
  when 'lead.called_since_latest_entry' then p_row->'lead_called_since_latest_entry'
  when 'lead.unworked_since_latest_entry' then p_row->'lead_unworked_since_latest_entry'
  when 'calls.total' then p_row->'call_count'
  when 'calls.never_called' then p_row->'calls_never_called'
  when 'calls.days_since_last' then p_row->'days_since_last_call'
  when 'calls.latest_status' then p_row->'latest_call_status'
  when 'calls.latest_substatus' then p_row->'latest_call_substatus'
  when 'calls.ever_statuses' then p_row->'call_ever_statuses'
  when 'calls.called_today' then p_row->'called_today'
  when 'calls.effective_contact_count' then p_row->'effective_contact_count'
  when 'appointments.total' then p_row->'appointment_count'
  when 'appointments.never_had' then p_row->'appointments_never_had'
  when 'appointments.last_at' then p_row->'last_appointment_at'
  when 'appointments.last_status' then p_row->'last_appointment_status'
  when 'appointments.next_at' then p_row->'next_appointment_at'
  when 'appointments.has_future' then p_row->'has_future_appointment'
  when 'appointments.no_show_count' then p_row->'no_show_count'
  when 'appointments.ever_no_show' then p_row->'ever_no_show'
  when 'appointments.attended_count' then p_row->'attended_count'
  when 'appointments.statuses' then p_row->'appointment_statuses'
  when 'sales.total' then p_row->'sale_count'
  when 'sales.never_bought' then p_row->'sales_never_bought'
  when 'sales.revenue_lifetime' then p_row->'revenue_lifetime'
  when 'sales.days_since_last' then p_row->'days_since_last_sale'
  when 'sales.product_count' then p_row->'product_count'
  when 'sales.service_count' then p_row->'service_count'
  when 'sales.products' then p_row->'products'
  when 'sales.services' then p_row->'services'
  when 'sales.latest_item_type' then p_row->'latest_item_type'
  when 'sales.payment_states' then p_row->'payment_states'
  when 'sales.payment_methods' then p_row->'payment_methods'
  when 'followups.pending_count' then p_row->'pending_followup_count'
  when 'followups.overdue_count' then p_row->'overdue_followup_count'
  when 'followups.next_at' then p_row->'next_followup_at'
  when 'followups.treatments' then p_row->'followup_treatments'
  when 'email.sent_count' then p_row->'email_sent_count'
  when 'email.never_sent' then p_row->'email_never_sent'
  when 'email.days_since_last' then p_row->'email_days_since_last'
  when 'email.opened_count' then p_row->'email_opened_count'
  when 'email.clicked_count' then p_row->'email_clicked_count'
  when 'email.bounced_count' then p_row->'email_bounced_count'
  when 'segment.value_tier' then p_row->'value_tier'
  when 'segment.value_score' then p_row->'value_score'
  when 'segment.lifecycle' then p_row->'lifecycle'
  when 'segment.engagement' then p_row->'engagement'
  when 'segment.traits' then p_row->'traits'
  else null
end;
$$;

create or replace function public.aos_cia_audience_field_type_v1(p_field text)
returns text
language sql
stable
as $$
  select data_type from public.aos_audience_filter_registry where field_key=p_field and active=true;
$$;

create or replace function public.aos_cia_audience_rule_count_v1(p_node jsonb)
returns integer
language plpgsql
immutable
as $$
declare r jsonb; n integer := 0;
begin
  if p_node ? 'field' then return 1; end if;
  if jsonb_typeof(p_node->'rules') <> 'array' then return 0; end if;
  for r in select value from jsonb_array_elements(p_node->'rules') loop
    n := n + public.aos_cia_audience_rule_count_v1(r);
  end loop;
  return n;
end;
$$;

create or replace function public.aos_cia_audience_validate_node_v1(p_node jsonb, p_depth integer default 1, p_path text default '$.root')
returns jsonb
language plpgsql
stable
as $$
declare
  errors jsonb := '[]'::jsonb;
  r jsonb; idx integer := 0;
  f text; op text; dtype text; ops text[]; enums text[]; v jsonb;
begin
  if p_depth > 2 then
    return jsonb_build_array(jsonb_build_object('code','MAX_DEPTH_EXCEEDED','path',p_path,'detail','Maximum group depth is 2'));
  end if;

  if p_node ? 'field' then
    f := p_node->>'field'; op := p_node->>'operator'; v := p_node->'value';
    select data_type, allowed_operators, enum_values into dtype, ops, enums
    from public.aos_audience_filter_registry where field_key=f and active=true;
    if dtype is null then
      errors := errors || jsonb_build_array(jsonb_build_object('code','FIELD_NOT_ALLOWED','path',p_path,'field',f));
      return errors;
    end if;
    if op is null or not (op = any(ops)) then
      errors := errors || jsonb_build_array(jsonb_build_object('code','OPERATOR_NOT_ALLOWED','path',p_path,'field',f,'operator',op));
      return errors;
    end if;
    if op in ('is_true','is_false','is_unknown','exists','not_exists') then
      return errors;
    end if;
    if not (p_node ? 'value') or v is null or v='null'::jsonb then
      return errors || jsonb_build_array(jsonb_build_object('code','VALUE_REQUIRED','path',p_path,'field',f));
    end if;
    if op in ('in','not_in','contains_any','contains_all','between') and jsonb_typeof(v) <> 'array' then
      return errors || jsonb_build_array(jsonb_build_object('code','ARRAY_VALUE_REQUIRED','path',p_path,'field',f));
    end if;
    if op='between' and jsonb_array_length(v) <> 2 then
      return errors || jsonb_build_array(jsonb_build_object('code','BETWEEN_REQUIRES_TWO_VALUES','path',p_path,'field',f));
    end if;
    if op in ('in','not_in','contains_any','contains_all') and jsonb_array_length(v)=0 then
      return errors || jsonb_build_array(jsonb_build_object('code','NONEMPTY_ARRAY_REQUIRED','path',p_path,'field',f));
    end if;
    if dtype in ('integer','numeric') then
      if op='between' then
        if exists (select 1 from jsonb_array_elements_text(v) x where x !~ '^-?\d+(\.\d+)?$') then
          errors := errors || jsonb_build_array(jsonb_build_object('code','NUMERIC_VALUE_REQUIRED','path',p_path,'field',f));
        end if;
      elsif (v#>>'{}') !~ '^-?\d+(\.\d+)?$' then
        errors := errors || jsonb_build_array(jsonb_build_object('code','NUMERIC_VALUE_REQUIRED','path',p_path,'field',f));
      end if;
    end if;
    if op in ('within_last_days','older_than_days') and (v#>>'{}') !~ '^\d+$' then
      errors := errors || jsonb_build_array(jsonb_build_object('code','INTEGER_DAYS_REQUIRED','path',p_path,'field',f));
    end if;
    if enums is not null and op in ('eq','neq') and not (upper(v#>>'{}') = any(enums)) then
      errors := errors || jsonb_build_array(jsonb_build_object('code','ENUM_VALUE_NOT_ALLOWED','path',p_path,'field',f,'value',v));
    end if;
    if enums is not null and op in ('in','not_in') and exists (
      select 1 from jsonb_array_elements_text(v) x where not (upper(x) = any(enums))
    ) then
      errors := errors || jsonb_build_array(jsonb_build_object('code','ENUM_VALUE_NOT_ALLOWED','path',p_path,'field',f,'value',v));
    end if;
    return errors;
  end if;

  if upper(coalesce(p_node->>'op','')) not in ('AND','OR') then
    errors := errors || jsonb_build_array(jsonb_build_object('code','GROUP_OPERATOR_INVALID','path',p_path));
  end if;
  if jsonb_typeof(p_node->'rules') <> 'array' or jsonb_array_length(coalesce(p_node->'rules','[]'::jsonb))=0 then
    return errors || jsonb_build_array(jsonb_build_object('code','GROUP_RULES_REQUIRED','path',p_path));
  end if;
  for r in select value from jsonb_array_elements(p_node->'rules') loop
    errors := errors || public.aos_cia_audience_validate_node_v1(r,p_depth+1,p_path||'.rules['||idx||']');
    idx := idx + 1;
  end loop;
  return errors;
end;
$$;

create or replace function public.aos_cia_audience_validate_v1(p_filter jsonb)
returns jsonb
language plpgsql
stable
as $$
declare errors jsonb := '[]'::jsonb; n integer;
begin
  if p_filter is null or jsonb_typeof(p_filter) <> 'object' then
    return jsonb_build_object('valid',false,'errors',jsonb_build_array(jsonb_build_object('code','FILTER_OBJECT_REQUIRED')));
  end if;
  if coalesce((p_filter->>'version')::integer,0) <> 1 then
    errors := errors || jsonb_build_array(jsonb_build_object('code','DSL_VERSION_UNSUPPORTED'));
  end if;
  if not (p_filter ? 'root') or jsonb_typeof(p_filter->'root') <> 'object' then
    errors := errors || jsonb_build_array(jsonb_build_object('code','ROOT_OBJECT_REQUIRED'));
  else
    n := public.aos_cia_audience_rule_count_v1(p_filter->'root');
    if n > 25 then errors := errors || jsonb_build_array(jsonb_build_object('code','MAX_RULES_EXCEEDED','count',n,'max',25)); end if;
    errors := errors || public.aos_cia_audience_validate_node_v1(p_filter->'root',1,'$.root');
  end if;
  return jsonb_build_object('valid',jsonb_array_length(errors)=0,'rule_count',coalesce(n,0),'max_group_depth',2,'max_rules',25,'errors',errors);
exception when others then
  return jsonb_build_object('valid',false,'errors',jsonb_build_array(jsonb_build_object('code','FILTER_VALIDATION_ERROR','detail',sqlerrm)));
end;
$$;

-- -----------------------------------------------------------------------------
-- RULE EVALUATOR — no dynamic SQL.
-- -----------------------------------------------------------------------------
create or replace function public.aos_cia_audience_rule_match_v1(p_row jsonb, p_rule jsonb)
returns boolean
language plpgsql
stable
as $$
declare
  f text := p_rule->>'field'; op text := p_rule->>'operator';
  dtype text; observed jsonb; v jsonb; ot text; vt text;
  onum numeric; vnum numeric; a numeric; b numeric;
  od timestamptz; d1 timestamptz; d2 timestamptz;
begin
  dtype := public.aos_cia_audience_field_type_v1(f);
  observed := public.aos_cia_audience_get_value_v1(p_row,f);
  v := p_rule->'value';

  if op='is_unknown' then return observed is null or observed='null'::jsonb; end if;
  if op='is_true' then return observed='true'::jsonb; end if;
  if op='is_false' then return observed='false'::jsonb; end if;
  if op='exists' then return observed is not null and observed <> 'null'::jsonb and not (jsonb_typeof(observed)='string' and btrim(observed#>>'{}')=''); end if;
  if op='not_exists' then return not public.aos_cia_audience_rule_match_v1(p_row,jsonb_build_object('field',f,'operator','exists')); end if;
  if observed is null or observed='null'::jsonb then return false; end if;

  if dtype='set' then
    if jsonb_typeof(observed) <> 'array' then return false; end if;
    if op='contains' then return exists(select 1 from jsonb_array_elements_text(observed) x where upper(btrim(x))=upper(btrim(v#>>'{}'))); end if;
    if op='not_contains' then return not exists(select 1 from jsonb_array_elements_text(observed) x where upper(btrim(x))=upper(btrim(v#>>'{}'))); end if;
    if op='contains_any' then return exists(select 1 from jsonb_array_elements_text(observed) o join jsonb_array_elements_text(v) q on upper(btrim(o))=upper(btrim(q))); end if;
    if op='contains_all' then return not exists(select 1 from jsonb_array_elements_text(v) q where not exists(select 1 from jsonb_array_elements_text(observed) o where upper(btrim(o))=upper(btrim(q)))); end if;
    return false;
  end if;

  if dtype in ('integer','numeric') then
    onum := (observed#>>'{}')::numeric;
    if op='between' then a := (v->>0)::numeric; b := (v->>1)::numeric; return onum between least(a,b) and greatest(a,b); end if;
    vnum := (v#>>'{}')::numeric;
    return case op when 'eq' then onum=vnum when 'neq' then onum<>vnum when 'gt' then onum>vnum when 'gte' then onum>=vnum when 'lt' then onum<vnum when 'lte' then onum<=vnum else false end;
  end if;

  if dtype in ('date','timestamp') then
    od := (observed#>>'{}')::timestamptz;
    if op='within_last_days' then return od >= ((now() at time zone 'America/Lima')::date - ((v#>>'{}')::integer))::timestamptz; end if;
    if op='older_than_days' then return od < ((now() at time zone 'America/Lima')::date - ((v#>>'{}')::integer))::timestamptz; end if;
    if op='between' then d1 := (v->>0)::timestamptz; d2 := (v->>1)::timestamptz; return od between least(d1,d2) and greatest(d1,d2); end if;
    d1 := (v#>>'{}')::timestamptz;
    return case op when 'before' then od<d1 when 'after' then od>d1 else false end;
  end if;

  ot := upper(btrim(observed#>>'{}'));
  if op='eq' then return ot=upper(btrim(v#>>'{}')); end if;
  if op='neq' then return ot<>upper(btrim(v#>>'{}')); end if;
  if op='contains' then return ot like '%'||upper(btrim(v#>>'{}'))||'%'; end if;
  if op='in' then return exists(select 1 from jsonb_array_elements_text(v) x where ot=upper(btrim(x))); end if;
  if op='not_in' then return not exists(select 1 from jsonb_array_elements_text(v) x where ot=upper(btrim(x))); end if;
  return false;
exception when others then
  return false;
end;
$$;

create or replace function public.aos_cia_audience_eval_node_v1(p_row jsonb, p_node jsonb, p_depth integer default 1)
returns boolean
language plpgsql
stable
as $$
declare r jsonb; op text; matched boolean;
begin
  if p_depth>2 then return false; end if;
  if p_node ? 'field' then return public.aos_cia_audience_rule_match_v1(p_row,p_node); end if;
  op := upper(coalesce(p_node->>'op',''));
  if op='AND' then
    for r in select value from jsonb_array_elements(p_node->'rules') loop
      if not public.aos_cia_audience_eval_node_v1(p_row,r,p_depth+1) then return false; end if;
    end loop;
    return true;
  elsif op='OR' then
    for r in select value from jsonb_array_elements(p_node->'rules') loop
      if public.aos_cia_audience_eval_node_v1(p_row,r,p_depth+1) then return true; end if;
    end loop;
    return false;
  end if;
  return false;
end;
$$;

create or replace function public.aos_cia_audience_trace_node_v1(p_row jsonb, p_node jsonb, p_depth integer default 1)
returns jsonb
language plpgsql
stable
as $$
declare
  r jsonb; children jsonb := '[]'::jsonb; child jsonb; m boolean; op text;
  f text; rop text; observed jsonb; code text;
begin
  if p_node ? 'field' then
    f:=p_node->>'field'; rop:=p_node->>'operator'; observed:=public.aos_cia_audience_get_value_v1(p_row,f);
    m:=public.aos_cia_audience_rule_match_v1(p_row,p_node);
    code := (case when m then 'MATCH_' else 'MISS_' end)||regexp_replace(upper(f||'_'||rop),'[^A-Z0-9]+','_','g');
    return jsonb_build_object('kind','rule','field',f,'operator',rop,'expected',p_node->'value','observed',observed,'matched',m,'reason_code',code);
  end if;
  op:=upper(coalesce(p_node->>'op',''));
  for r in select value from jsonb_array_elements(p_node->'rules') loop
    child:=public.aos_cia_audience_trace_node_v1(p_row,r,p_depth+1);
    children:=children||jsonb_build_array(child);
  end loop;
  if op='AND' then select bool_and((x->>'matched')::boolean) into m from jsonb_array_elements(children) x;
  elsif op='OR' then select bool_or((x->>'matched')::boolean) into m from jsonb_array_elements(children) x;
  else m:=false; end if;
  return jsonb_build_object('kind','group','op',op,'matched',coalesce(m,false),'children',children);
end;
$$;

-- -----------------------------------------------------------------------------
-- PUBLIC CONTRACTS FOR BACKEND/SERVICE_ROLE ONLY.
-- -----------------------------------------------------------------------------
create or replace function public.aos_cia_audience_count_v1(p_filter jsonb)
returns jsonb
language plpgsql
stable
as $$
declare v jsonb; n bigint;
begin
  v:=public.aos_cia_audience_validate_v1(p_filter);
  if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v); end if;
  select count(*) into n from public.aos_cia_audience_source_v1 s
  where public.aos_cia_audience_eval_node_v1(to_jsonb(s),p_filter->'root',1);
  return jsonb_build_object('ok',true,'count',n,'registry_version',1,'observed_at',statement_timestamp());
end;
$$;

create or replace function public.aos_cia_audience_preview_v1(p_filter jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
as $$
declare v jsonb; lim integer; offv integer; items jsonb; n bigint;
begin
  v:=public.aos_cia_audience_validate_v1(p_filter);
  if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v); end if;
  lim:=greatest(1,least(coalesce(p_limit,50),100)); offv:=greatest(0,coalesce(p_offset,0));
  select count(*) into n from public.aos_cia_audience_source_v1 s
  where public.aos_cia_audience_eval_node_v1(to_jsonb(s),p_filter->'root',1);
  select coalesce(jsonb_agg(rowj),'[]'::jsonb) into items from (
    select jsonb_build_object(
      'contact_key',s.contact_key,
      'identity_status',s.identity_status,
      'identity_conflict',s.identity_conflict,
      'name',nullif(btrim(concat_ws(' ',s.canonical_names,s.canonical_surnames)),''),
      'branch',s.crm_branch,
      'age_band',s.age_band,
      'patient_state',s.patient_state,
      'value_tier',s.value_tier,
      'lifecycle',s.lifecycle,
      'engagement',s.engagement,
      'traits',s.traits,
      'latest_interest',s.latest_interest,
      'last_call_at',s.last_call_at,
      'latest_call_status',s.latest_call_status,
      'has_future_appointment',s.has_future_appointment,
      'next_appointment_at',s.next_appointment_at,
      'sale_count',s.sale_count,
      'revenue_lifetime',s.revenue_lifetime,
      'pending_followups',s.pending_followup_count,
      'overdue_followups',s.overdue_followup_count,
      'email_never_sent',s.email_never_sent
    ) as rowj
    from public.aos_cia_audience_source_v1 s
    where public.aos_cia_audience_eval_node_v1(to_jsonb(s),p_filter->'root',1)
    order by s.contact_key
    limit lim offset offv
  ) q;
  return jsonb_build_object('ok',true,'count',n,'limit',lim,'offset',offv,'registry_version',1,'items',items,'observed_at',statement_timestamp());
end;
$$;

create or replace function public.aos_cia_audience_explain_v1(p_filter jsonb, p_contact_key text)
returns jsonb
language plpgsql
stable
as $$
declare v jsonb; rowj jsonb; trace jsonb;
begin
  v:=public.aos_cia_audience_validate_v1(p_filter);
  if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v); end if;
  select to_jsonb(s) into rowj from public.aos_cia_audience_source_v1 s where s.contact_key=p_contact_key;
  if rowj is null then return jsonb_build_object('ok',false,'error','CONTACT_NOT_FOUND','contact_key',p_contact_key); end if;
  trace:=public.aos_cia_audience_trace_node_v1(rowj,p_filter->'root',1);
  return jsonb_build_object('ok',true,'contact_key',p_contact_key,'included',(trace->>'matched')::boolean,'trace',trace,'registry_version',1,'observed_at',statement_timestamp());
end;
$$;

-- Private by default. Phase 5 frontend will use controlled backend/RPC integration.
revoke all on public.aos_cia_profile_facts_v1 from public, anon, authenticated;
revoke all on public.aos_cia_audience_source_v1 from public, anon, authenticated;
revoke all on public.aos_audience_filter_registry from public, anon, authenticated;
revoke all on public.aos_audience_presets from public, anon, authenticated;
revoke all on function public.aos_cia_audience_get_value_v1(jsonb,text) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_field_type_v1(text) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_rule_count_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_validate_node_v1(jsonb,integer,text) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_validate_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_rule_match_v1(jsonb,jsonb) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_eval_node_v1(jsonb,jsonb,integer) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_trace_node_v1(jsonb,jsonb,integer) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_count_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_preview_v1(jsonb,integer,integer) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_explain_v1(jsonb,text) from public, anon, authenticated;

grant select on public.aos_cia_profile_facts_v1 to service_role;
grant select on public.aos_cia_audience_source_v1 to service_role;
grant select on public.aos_audience_filter_registry to service_role;
grant select on public.aos_audience_presets to service_role;
grant execute on function public.aos_cia_audience_get_value_v1(jsonb,text) to service_role;
grant execute on function public.aos_cia_audience_field_type_v1(text) to service_role;
grant execute on function public.aos_cia_audience_rule_count_v1(jsonb) to service_role;
grant execute on function public.aos_cia_audience_validate_node_v1(jsonb,integer,text) to service_role;
grant execute on function public.aos_cia_audience_validate_v1(jsonb) to service_role;
grant execute on function public.aos_cia_audience_rule_match_v1(jsonb,jsonb) to service_role;
grant execute on function public.aos_cia_audience_eval_node_v1(jsonb,jsonb,integer) to service_role;
grant execute on function public.aos_cia_audience_trace_node_v1(jsonb,jsonb,integer) to service_role;
grant execute on function public.aos_cia_audience_count_v1(jsonb) to service_role;
grant execute on function public.aos_cia_audience_preview_v1(jsonb,integer,integer) to service_role;
grant execute on function public.aos_cia_audience_explain_v1(jsonb,text) to service_role;

commit;
