-- Hotfix 2026-08-12
-- Align Home > MKT ticker with the same monthly cohort semantics used by
-- the stable Marketing dashboard. Fixes the August discrepancy where Home
-- reported S/756 while Marketing correctly reported S/1,045.
--
-- Important: this does not mutate sales/leads data. It only changes the
-- aggregation function consumed by admin-home.html.

create or replace function public.aos_ticker_mkt(p_mes_inicio text)
returns jsonb
language plpgsql
security definer
as $function$
declare
  v_desde date := p_mes_inicio::date;
  v_hasta date := (p_mes_inicio::date + interval '1 month' - interval '1 day')::date;
  v_leads int;
  v_contactados int;
  v_con_cita int;
  v_asistio int;
  v_con_venta int;
  v_fact numeric;
  v_inversion numeric;
  v_mes_num int;
  v_anio int;
begin
  v_mes_num := extract(month from v_desde);
  v_anio := extract(year from v_desde);

  select count(distinct l.numero_limpio)
    into v_leads
  from aos_leads l
  where l.fecha between v_desde and v_hasta
    and nullif(l.numero_limpio,'') is not null;

  select count(distinct ld.numero_limpio)
    into v_contactados
  from aos_leads ld
  where ld.fecha between v_desde and v_hasta
    and nullif(ld.numero_limpio,'') is not null
    and exists (
      select 1 from aos_llamadas ll
      where ll.numero_limpio = ld.numero_limpio
        and ll.fecha between v_desde and v_hasta
    );

  select count(distinct ll.numero_limpio)
    into v_con_cita
  from aos_llamadas ll
  where ll.fecha between v_desde and v_hasta
    and upper(ll.estado) = 'CITA CONFIRMADA'
    and ll.numero_limpio in (
      select numero_limpio from aos_leads
      where fecha between v_desde and v_hasta
    );

  select count(distinct ac.numero_limpio)
    into v_asistio
  from aos_agenda_citas ac
  where ac.fecha_cita between v_desde and v_hasta
    and upper(ac.estado_cita) in ('ASISTIO','EFECTIVA')
    and ac.numero_limpio in (
      select numero_limpio from aos_leads
      where fecha between v_desde and v_hasta
    );

  select count(distinct v.numero_limpio), coalesce(sum(v.monto),0)
    into v_con_venta, v_fact
  from aos_ventas v
  where v.fecha between v_desde and v_hasta
    and v.numero_limpio in (
      select numero_limpio from aos_leads
      where fecha between v_desde and v_hasta
    );

  select coalesce(sum(inversion),0)
    into v_inversion
  from aos_inversion_campanas
  where mes_num = v_mes_num and anio = v_anio;

  return jsonb_build_object(
    'leads', v_leads,
    'contactados', v_contactados,
    'con_cita', v_con_cita,
    'asistio', v_asistio,
    'con_venta', v_con_venta,
    'facturacion', v_fact,
    'inversion', v_inversion,
    'roas', case when v_inversion > 0 then round(v_fact / v_inversion, 1) else 0 end,
    'pct_contacto', case when v_leads > 0 then round(v_contactados::numeric / v_leads * 100) else 0 end
  );
end;
$function$;
