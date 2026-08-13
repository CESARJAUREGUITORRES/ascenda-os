-- ASCENDA OS — Commercial Intelligence & Audience OS
-- Phase 1 — Identity Resolver V1
-- Read-only identity layer. No source row is mutated.

begin;

create or replace function public.aos_cia_normalize_contact_key_v1(p_raw text)
returns text
language sql
immutable
parallel safe
as $$
  with d as (
    select regexp_replace(coalesce(p_raw, ''), '\D', '', 'g') as digits
  )
  select case
    when length(digits) = 9 then digits
    when length(digits) = 11 and left(digits, 2) = '51' then right(digits, 9)
    else null
  end
  from d;
$$;

comment on function public.aos_cia_normalize_contact_key_v1(text) is
'CIA V1 read-only contact key normalization: 9 digits or Peru 51+9 digits. Does not mutate source data.';

create or replace view public.aos_cia_contact_identity_v1
with (security_invoker = true)
as
with source_rows as (
  select 'patient'::text as source_type, "ID_PACIENTE"::text as source_record_id, numero_limpio as raw_contact
  from public.aos_pacientes
  union all
  select 'lead', id::text, numero_limpio from public.aos_leads
  union all
  select 'call', id::text, numero_limpio from public.aos_llamadas
  union all
  select 'appointment', id::text, numero_limpio from public.aos_agenda_citas
  union all
  select 'sale', id::text, numero_limpio from public.aos_ventas
),
source_norm as (
  select source_type,
         source_record_id,
         public.aos_cia_normalize_contact_key_v1(raw_contact) as contact_key
  from source_rows
),
universe as (
  select contact_key,
         bool_or(source_type = 'patient') as has_patient_source,
         bool_or(source_type = 'lead') as has_lead,
         bool_or(source_type = 'call') as has_call,
         bool_or(source_type = 'appointment') as has_appointment,
         bool_or(source_type = 'sale') as has_sale
  from source_norm
  where contact_key is not null
  group by contact_key
),
patient_norm as (
  select p.*,
         public.aos_cia_normalize_contact_key_v1(p.numero_limpio) as contact_key
  from public.aos_pacientes p
),
patient_stats as (
  select contact_key,
         count(*)::integer as patient_rows,
         count(*) filter (where upper(coalesce("ESTADO_PACIENTE", '')) <> 'FUSIONADO')::integer as non_fused_count,
         count(*) filter (where upper(coalesce("ESTADO_PACIENTE", '')) = 'FUSIONADO')::integer as fused_count
  from patient_norm
  where contact_key is not null
  group by contact_key
),
patient_ranked as (
  select pn.*,
         row_number() over (
           partition by contact_key
           order by
             case when upper(coalesce("ESTADO_PACIENTE", '')) = 'FUSIONADO' then 1 else 0 end,
             updated_at desc nulls last,
             created_at desc nulls last,
             "ID_PACIENTE" desc
         ) as rn
  from patient_norm pn
  where contact_key is not null
)
select
  1::integer as identity_version,
  u.contact_key,
  true as phone_valid,
  case
    when coalesce(ps.non_fused_count, 0) > 1 then 'CONFLICT'
    when coalesce(ps.non_fused_count, 0) = 1 then 'RESOLVED'
    when coalesce(ps.fused_count, 0) > 0 then 'FUSED_ONLY'
    else 'NO_PATIENT_PROFILE'
  end::text as identity_status,
  case
    when coalesce(ps.non_fused_count, 0) = 1 then pr."ID_PACIENTE"
    else null
  end::text as canonical_patient_id,
  pr."ID_PACIENTE"::text as audit_selected_patient_id,
  (coalesce(ps.non_fused_count, 0) > 1) as identity_conflict,
  (coalesce(ps.fused_count, 0) > 0) as has_fused_rows,
  coalesce(ps.patient_rows, 0)::integer as patient_rows,
  coalesce(ps.non_fused_count, 0)::integer as non_fused_count,
  coalesce(ps.fused_count, 0)::integer as fused_count,
  u.has_patient_source,
  u.has_lead,
  u.has_call,
  u.has_appointment,
  u.has_sale,
  jsonb_build_object(
    'patient', u.has_patient_source,
    'lead', u.has_lead,
    'call', u.has_call,
    'appointment', u.has_appointment,
    'sale', u.has_sale
  ) as source_flags,
  case when coalesce(ps.non_fused_count, 0) = 1 then pr."Nombres" else null end as canonical_names,
  case when coalesce(ps.non_fused_count, 0) = 1 then pr."Apellidos" else null end as canonical_surnames,
  case when coalesce(ps.non_fused_count, 0) = 1 then pr."Email" else null end as canonical_email,
  case when coalesce(ps.non_fused_count, 0) = 1 then pr."ESTADO_PACIENTE" else null end as canonical_patient_state,
  case when coalesce(ps.non_fused_count, 0) = 1 then pr.updated_at else null end as canonical_patient_updated_at
from universe u
left join patient_stats ps using (contact_key)
left join patient_ranked pr
  on pr.contact_key = u.contact_key
 and pr.rn = 1;

comment on view public.aos_cia_contact_identity_v1 is
'CIA Identity Resolver V1. One row per normalized valid contact_key; conflicts never receive canonical patient identity.';

create or replace view public.aos_cia_identity_unresolved_v1
with (security_invoker = true)
as
with source_rows as (
  select 'patient'::text as source_type, "ID_PACIENTE"::text as source_record_id, numero_limpio as raw_contact
  from public.aos_pacientes
  union all
  select 'lead', id::text, numero_limpio from public.aos_leads
  union all
  select 'call', id::text, numero_limpio from public.aos_llamadas
  union all
  select 'appointment', id::text, numero_limpio from public.aos_agenda_citas
  union all
  select 'sale', id::text, numero_limpio from public.aos_ventas
)
select
  source_type,
  source_record_id,
  raw_contact as raw_contact_value,
  regexp_replace(coalesce(raw_contact, ''), '\D', '', 'g') as digits_only,
  case
    when raw_contact is null or btrim(raw_contact) = '' then 'MISSING'
    else 'INVALID_FORMAT'
  end::text as resolution_status
from source_rows
where public.aos_cia_normalize_contact_key_v1(raw_contact) is null;

comment on view public.aos_cia_identity_unresolved_v1 is
'CIA Identity Resolver V1 audit lane for missing/invalid phone values. Not part of V1 audience universe.';

-- New identity objects are private by default. Later phases expose controlled RPC/endpoints.
revoke all on function public.aos_cia_normalize_contact_key_v1(text) from public, anon, authenticated;
revoke all on public.aos_cia_contact_identity_v1 from public, anon, authenticated;
revoke all on public.aos_cia_identity_unresolved_v1 from public, anon, authenticated;

grant execute on function public.aos_cia_normalize_contact_key_v1(text) to service_role;
grant select on public.aos_cia_contact_identity_v1 to service_role;
grant select on public.aos_cia_identity_unresolved_v1 to service_role;

commit;
