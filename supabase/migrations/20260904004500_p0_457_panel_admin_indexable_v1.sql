-- P0 #457 / P0 #432 — remove non-sargable date casts from aos_panel_admin.
-- Business payload and Lima business-date semantics are preserved exactly.
-- No new indexes, triggers, materialized views, retries, caches or timeout changes.

begin;

create or replace function public.aos_panel_admin(p_hoy text, p_ayer text, p_mes_inicio text)
returns json
language plpgsql
security definer
as $function$
declare
  v_hoy date := (now() at time zone 'America/Lima')::date;
  v_ayer date := ((now() at time zone 'America/Lima')::date - 1);
  v_mes_inicio date := date_trunc('month', (now() at time zone 'America/Lima'))::date;
  v_fact_hoy numeric := 0;
  v_fact_si numeric := 0;
  v_fact_pl numeric := 0;
  v_fact_ayer numeric := 0;
  v_n_ventas integer := 0;
  v_llam_hoy integer := 0;
  v_llam_mes integer := 0;
  v_citas_hoy integer := 0;
  v_citas_ag integer := 0;
  v_leads_mes integer := 0;
  v_semaforo json;
  v_tipif json;
  v_ventas_hoy json;
begin
  select
    coalesce(sum(case when fecha = v_hoy then monto else 0 end), 0),
    coalesce(sum(case when fecha = v_hoy and (sede ilike '%ISIDRO%' or sede ilike '%SAN%') then monto else 0 end), 0),
    coalesce(sum(case when fecha = v_hoy and (sede ilike '%PUEBLO%' or sede ilike '%LIBRE%') then monto else 0 end), 0),
    coalesce(sum(case when fecha = v_ayer then monto else 0 end), 0),
    count(*) filter (where fecha = v_hoy)
  into v_fact_hoy, v_fact_si, v_fact_pl, v_fact_ayer, v_n_ventas
  from public.aos_ventas
  where fecha in (v_hoy, v_ayer);

  select json_agg(row_to_json(v)) into v_ventas_hoy from (
    select nombres, apellidos, tratamiento, monto, tipo, asesor, sede, numero_limpio as num
    from public.aos_ventas
    where fecha = v_hoy
    order by created_at desc
    limit 20
  ) v;

  select
    count(*) filter (where fecha = v_hoy),
    count(*)
  into v_llam_hoy, v_llam_mes
  from public.aos_llamadas
  where fecha >= v_mes_inicio;

  select
    count(*),
    count(*) filter (where estado_cita not in ('CANCELADA','NO ASISTIO'))
  into v_citas_hoy, v_citas_ag
  from public.aos_agenda_citas
  where fecha_cita = v_hoy;

  select count(*) into v_leads_mes
  from public.aos_leads
  where fecha >= v_mes_inicio;

  select json_agg(row_to_json(s)) into v_semaforo from (
    select
      l.id_asesor,
      l.asesor,
      count(*) as llamadas,
      count(*) filter (where l.estado = 'CITA CONFIRMADA') as citas,
      max(coalesce(l.ult_ts, l.created_at)) as ult_ts,
      round(extract(epoch from (now() - max(coalesce(l.ult_ts, l.created_at)))) / 60) as mins_sin,
      (select l2.numero_limpio
       from public.aos_llamadas l2
       where l2.id_asesor = l.id_asesor
         and l2.fecha = v_hoy
       order by coalesce(l2.ult_ts, l2.created_at) desc nulls last
       limit 1) as ult_numero,
      to_char(max(coalesce(l.ult_ts, l.created_at)) at time zone 'America/Lima', 'HH12:MI AM') as ult_hora
    from public.aos_llamadas l
    where l.fecha = v_hoy
      and l.id_asesor is not null and l.id_asesor != ''
    group by l.id_asesor, l.asesor
    order by llamadas desc
  ) s;

  select json_agg(row_to_json(t)) into v_tipif from (
    select estado, count(*) as total
    from public.aos_llamadas
    where fecha = v_hoy
    group by estado
    order by total desc
    limit 10
  ) t;

  return json_build_object(
    'businessDate', v_hoy::text,
    'businessTimezone', 'America/Lima',
    'kpis', json_build_object(
      'factHoy', v_fact_hoy,
      'factHoySI', v_fact_si,
      'factHoyPL', v_fact_pl,
      'nVentasHoy', v_n_ventas,
      'deltaVentasHoy', case when v_fact_ayer > 0 then round((v_fact_hoy - v_fact_ayer) / v_fact_ayer * 100) / 100.0 else null end,
      'llamHoy', v_llam_hoy,
      'llamMes', v_llam_mes,
      'citasHoy', v_citas_hoy,
      'citasAgHoy', v_citas_ag,
      'leadsMes', v_leads_mes,
      'alertas', 0
    ),
    'ventasHoy', coalesce(v_ventas_hoy, '[]'::json),
    'semaforo', coalesce(v_semaforo, '[]'::json),
    'tipif', coalesce(v_tipif, '[]'::json),
    'fromSupabase', true
  );
end;
$function$;

comment on function public.aos_panel_admin(text,text,text) is
  'P0 #457 indexable admin summary. Preserves Lima business-date payload while using native date predicates and existing indexes.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
