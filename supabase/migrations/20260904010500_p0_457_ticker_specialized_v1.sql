-- P0 #457 / P0 #432 — specialize the synchronous marketing ticker.
--
-- aos_ticker_mkt only exposes a small subset of aos_marketing_period_summary_v2,
-- but the legacy implementation computes the entire marketing/touchpoint summary
-- (including discarded touchpoint metrics) on every ticker read. Production
-- evidence showed ~1.66s / 9,336 shared hits / 227 temp blocks for one ticker call.
--
-- This implementation preserves the exact ticker contract and the same canonical
-- business rules for the fields it actually returns. It keeps M0 revenue on the
-- existing Marketing Attribution V2 authority and does not alter that authority.
-- No new indexes, triggers, materialized views, caches, retries or timeout changes.

begin;

create or replace function public.aos_ticker_mkt(p_mes_inicio text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_desde date := p_mes_inicio::date;
  v_hasta date := (date_trunc('month', p_mes_inicio::date) + interval '1 month - 1 day')::date;
  v_leads integer := 0;
  v_contactados integer := 0;
  v_con_cita integer := 0;
  v_asistio integer := 0;
  v_con_venta integer := 0;
  v_facturacion numeric := 0;
  v_inversion numeric := 0;
  v_mes_num integer;
  v_anio integer;
begin
  v_mes_num := extract(month from v_desde);
  v_anio := extract(year from v_desde);

  with period_seed as materialized (
    select l.numero_limpio,l.fecha
    from public.aos_leads l
    where l.fecha between v_desde and v_hasta
      and l.numero_limpio is not null
      and l.numero_limpio<>''
  ),
  cohort as materialized (
    select numero_limpio,min(fecha) first_lead_date
    from period_seed
    group by numero_limpio
  ),
  person_flags as materialized (
    select
      c.numero_limpio,
      exists(
        select 1
        from public.aos_llamadas l
        where l.numero_limpio=c.numero_limpio
          and l.fecha between c.first_lead_date and v_hasta
      ) managed,
      exists(
        select 1
        from public.aos_llamadas l
        where l.numero_limpio=c.numero_limpio
          and l.fecha between c.first_lead_date and v_hasta
          and upper(l.estado)='CITA CONFIRMADA'
      ) cita_tel,
      exists(
        select 1
        from public.aos_agenda_citas a
        where a.numero_limpio=c.numero_limpio
          and a.fecha_cita between c.first_lead_date and v_hasta
          and upper(a.estado_cita) in ('ASISTIO','EFECTIVA')
      ) asistio
    from cohort c
  ),
  attrs_m0 as materialized (
    select a.numero_limpio,a.monto
    from public.aos_marketing_attribution_v2_preview(v_desde,v_hasta) a
    where a.lead_fecha between v_desde and v_hasta
      and a.venta_fecha between v_desde and v_hasta
  )
  select
    (select count(*) from cohort)::integer,
    (select count(*) from person_flags where managed)::integer,
    (select count(*) from person_flags where cita_tel)::integer,
    (select count(*) from person_flags where asistio)::integer,
    (select count(distinct numero_limpio) from attrs_m0)::integer,
    (select coalesce(sum(monto),0) from attrs_m0)::numeric
  into v_leads,v_contactados,v_con_cita,v_asistio,v_con_venta,v_facturacion;

  select coalesce(sum(inversion),0)
  into v_inversion
  from public.aos_inversion_campanas
  where mes_num=v_mes_num and anio=v_anio;

  return jsonb_build_object(
    'leads',v_leads,
    'contactados',v_contactados,
    'con_cita',v_con_cita,
    'asistio',v_asistio,
    'con_venta',v_con_venta,
    'facturacion',v_facturacion,
    'inversion',v_inversion,
    'roas',case when v_inversion>0 then round(v_facturacion/v_inversion,1) else 0 end,
    'pct_contacto',case when v_leads>0 then round(v_contactados::numeric/v_leads*100) else 0 end
  );
end;
$function$;

comment on function public.aos_ticker_mkt(text) is
  'P0 #457 bounded marketing ticker. Computes only ticker-exposed cohort metrics while preserving Marketing Attribution V2 for M0 revenue; avoids full period-summary/touchpoint fanout.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
