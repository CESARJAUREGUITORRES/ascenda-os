-- ASCENDA OS — CIA Phase 1 Identity Resolver live audit
-- READ ONLY. Simulates the V1 resolver without requiring DDL.

with source_rows as (
  select 'patient'::text src, numero_limpio raw from public.aos_pacientes
  union all select 'lead', numero_limpio from public.aos_leads
  union all select 'call', numero_limpio from public.aos_llamadas
  union all select 'appointment', numero_limpio from public.aos_agenda_citas
  union all select 'sale', numero_limpio from public.aos_ventas
), source_norm as (
  select src,
    case
      when length(regexp_replace(coalesce(raw,''),'\D','','g'))=9 then regexp_replace(coalesce(raw,''),'\D','','g')
      when length(regexp_replace(coalesce(raw,''),'\D','','g'))=11 and left(regexp_replace(coalesce(raw,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(raw,''),'\D','','g'),9)
      else null
    end contact_key
  from source_rows
), universe as (
  select contact_key,
         bool_or(src='patient') has_patient_source,
         bool_or(src='lead') has_lead,
         bool_or(src='call') has_call,
         bool_or(src='appointment') has_appointment,
         bool_or(src='sale') has_sale
  from source_norm
  where contact_key is not null
  group by contact_key
), patient_norm as (
  select p.*,
    case
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9 then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11 and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
      else null
    end contact_key
  from public.aos_pacientes p
), patient_stats as (
  select contact_key,
         count(*)::integer patient_rows,
         count(*) filter(where upper(coalesce("ESTADO_PACIENTE",''))<>'FUSIONADO')::integer non_fused_count,
         count(*) filter(where upper(coalesce("ESTADO_PACIENTE",''))='FUSIONADO')::integer fused_count
  from patient_norm
  where contact_key is not null
  group by contact_key
), ranked as (
  select pn.*,
         row_number() over(partition by contact_key order by
           case when upper(coalesce("ESTADO_PACIENTE",''))='FUSIONADO' then 1 else 0 end,
           updated_at desc nulls last,
           created_at desc nulls last,
           "ID_PACIENTE" desc
         ) rn
  from patient_norm pn
  where contact_key is not null
), resolved as (
  select u.contact_key,
         case
           when coalesce(ps.non_fused_count,0)>1 then 'CONFLICT'
           when coalesce(ps.non_fused_count,0)=1 then 'RESOLVED'
           when coalesce(ps.fused_count,0)>0 then 'FUSED_ONLY'
           else 'NO_PATIENT_PROFILE'
         end identity_status,
         case when coalesce(ps.non_fused_count,0)=1 then r."ID_PACIENTE" else null end canonical_patient_id,
         case when coalesce(ps.non_fused_count,0)=1 then r."ESTADO_PACIENTE" else null end canonical_patient_state,
         coalesce(ps.non_fused_count,0) non_fused_count,
         coalesce(ps.fused_count,0) fused_count,
         u.has_patient_source,u.has_lead,u.has_call,u.has_appointment,u.has_sale
  from universe u
  left join patient_stats ps using(contact_key)
  left join ranked r on r.contact_key=u.contact_key and r.rn=1
), checks as (
  select 'unique_contact_key' check_name,(count(*)=count(distinct contact_key)) ok,count(*)::text observed from resolved
  union all select 'all_keys_9_digits',bool_and(contact_key ~ '^\d{9}$'),count(*)::text from resolved
  union all select 'resolved_has_canonical',coalesce(bool_and(canonical_patient_id is not null),true),count(*)::text from resolved where identity_status='RESOLVED'
  union all select 'nonresolved_has_no_canonical',coalesce(bool_and(canonical_patient_id is null),true),count(*)::text from resolved where identity_status<>'RESOLVED'
  union all select 'canonical_never_fused',coalesce(bool_and(upper(coalesce(canonical_patient_state,''))<>'FUSIONADO'),true),count(*)::text from resolved where canonical_patient_id is not null
  union all select 'conflict_exactly_multi_nonfused',coalesce(bool_and(non_fused_count>1 and canonical_patient_id is null),true),count(*)::text from resolved where identity_status='CONFLICT'
)
select check_name, case when ok then 'PASS' else 'FAIL' end status, observed
from checks
order by check_name;

-- Distribution
with p as (
 select case when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9 then regexp_replace(coalesce(numero_limpio,''),'\D','','g') when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11 and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9) else null end contact_key,
        "ESTADO_PACIENTE"
 from public.aos_pacientes
), g as (
 select contact_key,count(*) filter(where upper(coalesce("ESTADO_PACIENTE",''))<>'FUSIONADO') non_fused,count(*) filter(where upper(coalesce("ESTADO_PACIENTE",''))='FUSIONADO') fused
 from p where contact_key is not null group by contact_key
)
select
 count(*) filter(where non_fused=1) as patient_keys_resolvable,
 count(*) filter(where non_fused>1) as conflicts,
 count(*) filter(where non_fused=0 and fused>0) as fused_only
from g;
