-- Marketing Attribution V2 — filtered totals for paged Ver Leads UI.

create or replace function public.aos_marketing_leads_detalle_v2_summary(
  p_fecha_desde date default null,
  p_fecha_hasta date default null,
  p_search text default null,
  p_estado text default null
)
returns jsonb
language sql
stable
as $function$
with base as materialized (
  select * from public.aos_marketing_leads_detalle_v2(p_fecha_desde,p_fecha_hasta)
), filtered as (
  select * from base b
  where (p_estado is null or p_estado='' or lower(p_estado)='todos' or b.estado_lead=p_estado)
    and (
      p_search is null or btrim(p_search)='' or
      lower(coalesce(b.celular,'')) like '%'||lower(btrim(p_search))||'%' or
      lower(coalesce(b.numero_limpio,'')) like '%'||lower(btrim(p_search))||'%' or
      lower(coalesce(b.anuncio,'')) like '%'||lower(btrim(p_search))||'%' or
      lower(coalesce(b.tratamiento,'')) like '%'||lower(btrim(p_search))||'%'
    )
)
select jsonb_build_object(
  'total',count(*),
  'llamados',count(*) filter(where llamadas_total>0),
  'conCita',count(*) filter(where citas_total>0),
  'vendidos',count(*) filter(where ventas_total>0),
  'sinContacto',count(*) filter(where estado_lead='SIN CONTACTO'),
  'montoFacturado',coalesce(sum(monto_facturado),0)
)
from filtered;
$function$;

grant execute on function public.aos_marketing_leads_detalle_v2_summary(date,date,text,text) to anon;
