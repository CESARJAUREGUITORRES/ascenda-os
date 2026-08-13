-- ASCENDA OS — CIA Phase 4 read-only production audit
-- Safe on current production: no DDL / no writes.

-- 1. Current five-source contact universe.
with src as (
 select numero_limpio raw from aos_pacientes union all select numero_limpio from aos_leads
 union all select numero_limpio from aos_llamadas union all select numero_limpio from aos_agenda_citas union all select numero_limpio from aos_ventas
), n as (
 select distinct case when length(regexp_replace(coalesce(raw,''),'\D','','g'))=9 then regexp_replace(coalesce(raw,''),'\D','','g') when length(regexp_replace(coalesce(raw,''),'\D','','g'))=11 and left(regexp_replace(coalesce(raw,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(raw,''),'\D','','g'),9) end contact_key from src
)
select count(*) filter(where contact_key is not null) valid_contact_universe from n;

-- 2. Canonical demographic coverage (approximate equivalent to Profile Facts V1).
select
 count(*) filter(where coalesce("ESTADO_PACIENTE",'')<>'FUSIONADO') non_fused_profiles,
 count(*) filter(where coalesce("ESTADO_PACIENTE",'')<>'FUSIONADO' and nullif(btrim("Sexo"),'') is not null) sex_present,
 count(*) filter(where coalesce("ESTADO_PACIENTE",'')<>'FUSIONADO' and nullif(btrim("SEDE_PRINCIPAL"),'') is not null) branch_present,
 count(*) filter(where coalesce("ESTADO_PACIENTE",'')<>'FUSIONADO' and nullif(btrim(departamento),'') is not null) department_present,
 count(*) filter(where coalesce("ESTADO_PACIENTE",'')<>'FUSIONADO' and nullif(btrim(ciudad),'') is not null) city_present,
 count(*) filter(where coalesce("ESTADO_PACIENTE",'')<>'FUSIONADO' and nullif(btrim(distrito),'') is not null) district_present
from aos_pacientes;

-- 3. System preset baselines directly from live sources.
with l as (
 select numero_limpio,max(coalesce(hora_ingreso,created_at,fecha::timestamp at time zone 'America/Lima')) last_lead from aos_leads group by numero_limpio
), c as (select numero_limpio,max(created_at) last_call from aos_llamadas group by numero_limpio)
select count(*) leads_unworked from l left join c using(numero_limpio) where c.last_call is null or c.last_call<l.last_lead;

select count(distinct numero_limpio) no_show_without_future from aos_agenda_citas a
where estado_cita='NO ASISTIO'
and not exists(select 1 from aos_agenda_citas x where x.numero_limpio=a.numero_limpio and x.estado_cita in ('PENDIENTE','CITA CONFIRMADA') and x.fecha_cita >= (now() at time zone 'America/Lima')::date);

-- 4. Product detail raw quality.
select upper(btrim(coalesce(tratamiento,''))) treatment,count(*) n
from aos_ventas where upper(btrim(coalesce(tipo,'')))='PRODUCTO' group by 1 order by n desc;
select count(*) product_rows,count(distinct nullif(btrim(descripcion),'')) distinct_product_descriptions
from aos_ventas where upper(btrim(coalesce(tipo,'')))='PRODUCTO';

-- 5. Service family raw distribution.
select upper(btrim(coalesce(tratamiento,''))) service_family,count(*) n
from aos_ventas where upper(btrim(coalesce(tipo,'')))='SERVICIO' group by 1 order by n desc;

-- 6. Production must remain without Phase 4 physical objects until deployment gate.
select table_name from information_schema.tables where table_schema='public' and table_name in ('aos_audience_filter_registry','aos_audience_presets','aos_product_alias_overrides','aos_service_family_taxonomy_v1');
select table_name from information_schema.views where table_schema='public' and table_name like 'aos_cia_audience%';
