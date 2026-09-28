-- P0: Advisor Home daily appointment count must follow the current canonical
-- appointment owner. The old implementation counted CITA CONFIRMADA call rows,
-- so a valid Agenda reassignment changed Admin Monitoreo but not the advisor KPI.
--
-- Scope: daily `citasHoy` only. Monthly call-attribution metrics remain unchanged
-- for historical comparability.

create or replace function public.aos_panel_asesor(
  p_asesor text,
  p_id_asesor text default ''::text,
  p_hoy text default null::text,
  p_mes_inicio text default null::text
)
returns json
language plpgsql
security definer
as $function$
declare
  v_hoy         date;
  v_mes_inicio  date;
  v_mes_fin     date;
  v_llam_hoy    bigint;
  v_citas_hoy   bigint;
  v_llam_mes    bigint;
  v_citas_mes   bigint;
  v_asist_mes   bigint;
  v_ventas_mes  bigint;
  v_fact_mes    numeric;
  v_leads_n     bigint;
  v_leads_l     bigint;
  v_leads_c     bigint;
  v_llam_hoy_j  json;
  v_tipif_j     json;
  v_anual_j     json;
  v_ventas_j    json;
begin
  v_hoy        := coalesce(nullif(p_hoy, '')::date, current_date);
  v_mes_inicio := coalesce(nullif(p_mes_inicio, '')::date, date_trunc('month', current_date)::date);
  v_mes_fin    := (date_trunc('month', v_mes_inicio) + interval '1 month - 1 day')::date;

  select count(*) into v_llam_hoy
  from public.aos_llamadas
  where fecha = v_hoy and upper(asesor) = upper(p_asesor);

  -- Canonical daily truth: current Agenda owner, not historical call owner.
  select count(*) into v_citas_hoy
  from public.aos_agenda_citas a
  left join public.aos_llamadas l on l.id = a.llamada_id_origen
  where (coalesce(a.ts_creado, a.ts_actualizado) at time zone 'America/Lima')::date = v_hoy
    and (
      upper(trim(coalesce(a.asesor,''))) = upper(trim(coalesce(p_asesor,'')))
      or (
        nullif(trim(coalesce(p_id_asesor,'')), '') is not null
        and trim(coalesce(a.id_asesor,'')) = trim(p_id_asesor)
      )
    )
    and public.aos_callcenter_appointment_class_v1(
      a.origen_cita, l.tipo_gestion, l.sub_estado, a.llamada_id_origen
    ) = 'CITA'
    and upper(coalesce(a.source_channel,'')) not in ('WEB','ADVISOR_LINK');

  select count(*) into v_llam_mes
  from public.aos_llamadas
  where fecha between v_mes_inicio and v_mes_fin and upper(asesor) = upper(p_asesor);

  select count(*) into v_citas_mes
  from public.aos_llamadas
  where fecha between v_mes_inicio and v_mes_fin
    and upper(asesor) = upper(p_asesor) and estado = 'CITA CONFIRMADA';

  select count(*) into v_asist_mes
  from public.aos_agenda_citas
  where fecha_cita between v_mes_inicio and v_mes_fin
    and upper(asesor) = upper(p_asesor) and estado_cita in ('ASISTIO','EFECTIVA','ASISTIÓ');

  select count(*), coalesce(sum(monto), 0)
  into v_ventas_mes, v_fact_mes
  from public.aos_ventas
  where fecha between v_mes_inicio and v_mes_fin and upper(asesor) = upper(p_asesor);

  select count(*) into v_leads_n
  from public.aos_leads
  where fecha between v_mes_inicio and v_mes_fin;

  select count(distinct l.numero_limpio) into v_leads_l
  from public.aos_llamadas l
  join public.aos_leads ld on ld.numero_limpio = l.numero_limpio
  where l.fecha between v_mes_inicio and v_mes_fin
    and ld.fecha between v_mes_inicio and v_mes_fin
    and upper(l.asesor) = upper(p_asesor);

  select count(distinct l.numero_limpio) into v_leads_c
  from public.aos_llamadas l
  join public.aos_leads ld on ld.numero_limpio = l.numero_limpio
  where l.fecha between v_mes_inicio and v_mes_fin
    and ld.fecha between v_mes_inicio and v_mes_fin
    and upper(l.asesor) = upper(p_asesor)
    and l.estado = 'CITA CONFIRMADA';

  select json_agg(t) into v_llam_hoy_j
  from (
    select hora_llamada as hora, numero_limpio as num,
           tratamiento as trat, estado,
           coalesce(sub_estado,'') as "subEstado",
           coalesce(observacion,'') as obs
    from public.aos_llamadas
    where fecha = v_hoy and upper(asesor) = upper(p_asesor)
    order by hora_llamada desc
    limit 50
  ) t;

  select json_agg(t) into v_tipif_j
  from (
    select estado, count(*) as cnt
    from public.aos_llamadas
    where fecha between v_mes_inicio and v_mes_fin and upper(asesor) = upper(p_asesor)
    group by estado order by count(*) desc
  ) t;

  select json_agg(t) into v_anual_j
  from (
    select
      to_char(date_trunc('month', fecha), 'YYYY-MM') as "mesKey",
      to_char(date_trunc('month', fecha), 'Mon') as mes,
      count(*) as llamadas,
      sum(case when estado = 'CITA CONFIRMADA' then 1 else 0 end) as citas,
      (date_trunc('month', fecha) = date_trunc('month', current_date)) as "esCurrent"
    from public.aos_llamadas
    where extract(year from fecha) = extract(year from current_date)
      and upper(asesor) = upper(p_asesor)
    group by date_trunc('month', fecha)
    order by date_trunc('month', fecha) asc
  ) t;

  select json_agg(t) into v_ventas_j
  from (
    select
      to_char(date_trunc('month', fecha), 'YYYY-MM') as "mesKey",
      count(*) as ventas,
      sum(monto) as fact
    from public.aos_ventas
    where extract(year from fecha) = extract(year from current_date)
      and upper(asesor) = upper(p_asesor)
    group by date_trunc('month', fecha)
    order by date_trunc('month', fecha) asc
  ) t;

  return json_build_object(
    'llamHoy', v_llam_hoy,
    'citasHoy', v_citas_hoy,
    'llamMes', v_llam_mes,
    'citasMes', v_citas_mes,
    'asistMes', v_asist_mes,
    'ventasMes', v_ventas_mes,
    'factMes', v_fact_mes,
    'leadsNuevos', v_leads_n,
    'leadsLlamados', v_leads_l,
    'leadsCitas', v_leads_c,
    'llamadasHoy', coalesce(v_llam_hoy_j, '[]'::json),
    'tipifMes', coalesce(v_tipif_j, '[]'::json),
    'resumenAnual', coalesce(v_anual_j, '[]'::json),
    'ventasAnual', coalesce(v_ventas_j, '[]'::json),
    'fromSupabase', true,
    'version', 'v4-current-owner-daily-citas'
  );
end
$function$;
