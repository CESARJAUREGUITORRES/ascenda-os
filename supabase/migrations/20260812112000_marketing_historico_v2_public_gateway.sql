create or replace function public.aos_marketing_historico_public_v2(p_anio integer)
returns table(
  mes integer,
  anio integer,
  leads bigint,
  llamados bigint,
  citas bigint,
  asistieron bigint,
  clientes bigint,
  ventas bigint,
  fact numeric,
  fact_acumulado numeric,
  conv numeric,
  ingresos bigint,
  reingresos bigint,
  citas_tel bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_anio is null or p_anio < 2020 or p_anio > extract(year from current_date)::integer + 1 then
    raise exception 'Año fuera de rango';
  end if;

  return query
  select h.mes,h.anio,h.leads,h.llamados,h.citas,h.asistieron,h.clientes,h.ventas,
         h.fact,h.fact_acumulado,h.conv,h.ingresos,h.reingresos,h.citas_tel
  from public.aos_marketing_historico_aligned_v2(p_anio) h
  order by h.mes;
end;
$$;

revoke all on function public.aos_marketing_historico_public_v2(integer) from public;
grant execute on function public.aos_marketing_historico_public_v2(integer) to anon, authenticated;
