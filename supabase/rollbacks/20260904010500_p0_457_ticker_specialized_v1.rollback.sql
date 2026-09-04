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
  s jsonb;
  v_inversion numeric;
  v_mes_num int;
  v_anio int;
begin
  v_mes_num := extract(month from v_desde);
  v_anio := extract(year from v_desde);

  select public.aos_marketing_period_summary_v2(v_desde,v_hasta) into s;

  select coalesce(sum(inversion),0) into v_inversion
  from public.aos_inversion_campanas
  where mes_num=v_mes_num and anio=v_anio;

  return jsonb_build_object(
    'leads',coalesce((s->>'personasUnicas')::int,0),
    'contactados',coalesce((s->>'personasGestionadas')::int,0),
    'con_cita',coalesce((s->>'personasCitaTel')::int,0),
    'asistio',coalesce((s->>'personasAsistieron')::int,0),
    'con_venta',coalesce((s->>'clientesM0')::int,0),
    'facturacion',coalesce((s->>'factM0')::numeric,0),
    'inversion',v_inversion,
    'roas',case when v_inversion>0 then round(coalesce((s->>'factM0')::numeric,0)/v_inversion,1) else 0 end,
    'pct_contacto',case when coalesce((s->>'personasUnicas')::numeric,0)>0
      then round(coalesce((s->>'personasGestionadas')::numeric,0)/(s->>'personasUnicas')::numeric*100)
      else 0 end
  );
end;
$function$;

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
