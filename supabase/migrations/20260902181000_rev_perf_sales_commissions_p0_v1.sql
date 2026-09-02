-- ASCENDA OS · REV-PERF P0 · Sales + Commissions
-- Read-path only. Preserve business formulas and result contracts.
-- Doctrine: critical path first; scoped/materialized reads; no timeout changes.

create or replace function public.aos_comisiones_asesor(
  p_asesor text,
  p_id_asesor text,
  p_mes integer,
  p_anio integer
) returns jsonb
language plpgsql
security definer
as $function$
declare
  v_mes_inicio date := make_date(p_anio,p_mes,1);
  v_mes_fin date := (make_date(p_anio,p_mes,1)+interval '1 month'-interval '1 day')::date;
  v_anio_inicio date := make_date(p_anio,1,1);
  v_anio_fin date := make_date(p_anio,12,31);
begin
  return (
    with product_rules as materialized (
      select monto_min::numeric monto_min,comision::numeric comision
      from public.aos_tabla_comisiones
      where tipo='PRODUCTO' and activo=true
    ),
    year_sales as materialized (
      select v.*,
        case
          when v.tipo='SERVICIO' then round(v.monto::numeric*0.005,2)
          when v.tipo='PRODUCTO' then (
            select coalesce(max(r.comision),0)
            from product_rules r
            where r.monto_min<=v.monto::numeric
          )
          else 0
        end as calc_com
      from public.aos_ventas v
      where v.asesor=p_asesor
        and v.fecha between v_anio_inicio and v_anio_fin
    ),
    month_sales as materialized (
      select * from year_sales
      where fecha between v_mes_inicio and v_mes_fin
    ),
    ranking_sales as materialized (
      select v.asesor,
        sum(v.monto::numeric) as fact,
        sum(
          case
            when v.tipo='SERVICIO' then round(v.monto::numeric*0.005,2)
            when v.tipo='PRODUCTO' then (
              select coalesce(max(r.comision),0)
              from product_rules r
              where r.monto_min<=v.monto::numeric
            )
            else 0
          end
        ) as com
      from public.aos_ventas v
      where v.fecha between v_mes_inicio and v_mes_fin
        and v.asesor not in ('NO APLICA','DRA CAROLINA','DRA YESSICA','VINO SOLA(O)')
      group by v.asesor
    ),
    rankpos as (
      select asesor,row_number() over(order by com desc) pos
      from ranking_sales
    )
    select jsonb_build_object(
      'comTotal',coalesce((select sum(calc_com) from month_sales),0),
      -- Preserve legacy null semantics when the advisor has no sales in the month.
      'comServ',(select sum(calc_com) from month_sales where tipo='SERVICIO'),
      'comProd',(select sum(calc_com) from month_sales where tipo='PRODUCTO'),
      'factTotal',coalesce((select sum(monto::numeric) from month_sales),0),
      'nVentas',(select count(*) from month_sales),
      'nServ',(select count(*) from month_sales where tipo='SERVICIO'),
      'nProd',(select count(*) from month_sales where tipo='PRODUCTO'),
      'ranking',(select pos from rankpos where asesor=p_asesor),
      'meta',100,
      'pct',round(coalesce((select sum(calc_com) from month_sales),0)/100.0*100,1),
      'detalle',coalesce((
        select jsonb_agg(to_jsonb(d) order by d.fecha desc)
        from (
          select fecha::text,nombres,apellidos,numero_limpio,tratamiento,descripcion,
            monto::numeric,tipo,sede,pago,estado_pago,calc_com as comision_calculada
          from month_sales
        ) d
      ),'[]'::jsonb),
      'anual',coalesce((
        select jsonb_agg(to_jsonb(h) order by h.mes_num)
        from (
          select extract(month from fecha)::integer mes_num,
            to_char(fecha,'TMMonth') mes_nombre,
            sum(monto::numeric) facturado,
            sum(calc_com) comision,
            sum(calc_com) filter(where tipo='SERVICIO') com_serv,
            sum(calc_com) filter(where tipo='PRODUCTO') com_prod,
            count(*) n_ventas
          from year_sales
          group by extract(month from fecha),to_char(fecha,'TMMonth')
        ) h
      ),'[]'::jsonb),
      'topClientes',coalesce((
        select jsonb_agg(to_jsonb(t) order by t.total desc)
        from (
          select (coalesce(nombres,'')||' '||coalesce(apellidos,'')) cliente,
            numero_limpio num,sum(monto::numeric) total,count(*) compras,max(fecha::text) ult_fecha
          from year_sales
          where numero_limpio is not null and numero_limpio<>''
          group by nombres,apellidos,numero_limpio
          order by sum(monto::numeric) desc
          limit 5
        ) t
      ),'[]'::jsonb),
      -- Additive field: lets the advisor UI render ranking without a second sales-table download.
      'rankingTop',coalesce((
        select jsonb_agg(to_jsonb(r) order by r.com desc)
        from (
          select asesor,com,fact
          from ranking_sales
          order by com desc
          limit 5
        ) r
      ),'[]'::jsonb)
    )
  );
end;
$function$;

comment on function public.aos_comisiones_asesor(text,text,integer,integer) is
  'REV-PERF P0: one scoped advisor/year base + monthly derivation and embedded ranking. Commission semantics preserved.';

create or replace function public.aos_ventas_admin(
  p_mes integer,
  p_anio integer,
  p_sede text default '',
  p_asesor text default ''
) returns jsonb
language plpgsql
security definer
as $function$
declare
  v_desde date := make_date(p_anio,p_mes,1);
  v_hasta date := (make_date(p_anio,p_mes,1)+interval '1 month'-interval '1 day')::date;
  v_periodo text := p_anio||'-'||lpad(p_mes::text,2,'0');
  v_anio_desde date := make_date(p_anio,1,1);
  v_anio_hasta date := make_date(p_anio,12,31);
begin
  return (
    with product_rules as materialized (
      select monto_min::numeric monto_min,comision::numeric comision
      from public.aos_tabla_comisiones
      where tipo='PRODUCTO' and activo=true
    ),
    period_all as materialized (
      select v.*
      from public.aos_ventas v
      where v.fecha between v_desde and v_hasta
    ),
    base as materialized (
      select v.*
      from period_all v
      where (p_sede='' or v.sede=p_sede)
        and (p_asesor='' or v.asesor=p_asesor)
    ),
    advisor_base as materialized (
      select v.*
      from period_all v
      where p_asesor='' or v.asesor=p_asesor
    ),
    year_base as materialized (
      select v.fecha,v.monto
      from public.aos_ventas v
      where v.fecha between v_anio_desde and v_anio_hasta
        and (p_sede='' or v.sede=p_sede)
        and (p_asesor='' or v.asesor=p_asesor)
    ),
    agg as (
      select count(*) nventas,
        coalesce(sum(monto),0) fact,
        case when count(*)>0 then round(sum(monto)/count(*)) else 0 end ticket,
        count(*) filter(where tipo='SERVICIO') nserv,
        coalesce(sum(monto) filter(where tipo='SERVICIO'),0) fserv,
        count(*) filter(where tipo='PRODUCTO') nprod,
        coalesce(sum(monto) filter(where tipo='PRODUCTO'),0) fprod,
        count(*) filter(where estado_pago='PAGO COMPLETO') npago,
        count(*) filter(where estado_pago='ADELANTO') nadel,
        coalesce(sum(monto) filter(where estado_pago='ADELANTO'),0) fadel,
        count(*) filter(where estado_pago is null or estado_pago not in ('PAGO COMPLETO','ADELANTO')) nsin
      from base
    )
    select jsonb_build_object(
      'factTotal',a.fact,'nVentas',a.nventas,'ticketProm',a.ticket,
      'nServ',a.nserv,'factServ',a.fserv,'nProd',a.nprod,'factProd',a.fprod,
      'nPagoCompleto',a.npago,'nAdelanto',a.nadel,'factAdelanto',a.fadel,'nSinDefinir',a.nsin,
      'meta',(select coalesce(meta,0) from public.aos_metas_ventas where periodo=v_periodo),
      'detalle',coalesce((
        select jsonb_agg(to_jsonb(d) order by d.fecha desc,d.id desc)
        from (
          select v.id,v.fecha::text fecha,v.monto,v.tipo,v.tratamiento,v.descripcion,v.pago,v.sede,
            v.estado_pago,v.atendio,v.numero_limpio,v.asesor,v.nombres,v.apellidos,
            case when v.asesor='NO APLICA' then 0
                 when v.tipo='SERVICIO' then round(v.monto*0.005,2)
                 when v.tipo='PRODUCTO' then coalesce((select max(r.comision) from product_rules r where r.monto_min<=v.monto),0)
                 else 0 end as comision
          from base v
        ) d
      ),'[]'::jsonb),
      -- Legacy filter semantics intentionally preserved: advisor ranking ignores p_asesor.
      'porAsesor',coalesce((
        select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (
          select v.asesor,count(*) n,sum(v.monto) total,
            sum(case when v.tipo='SERVICIO' then round(v.monto*0.005,2)
                     when v.tipo='PRODUCTO' then coalesce((select max(r.comision) from product_rules r where r.monto_min<=v.monto),0)
                     else 0 end) comision
          from period_all v
          where (p_sede='' or v.sede=p_sede) and v.asesor!='NO APLICA'
          group by v.asesor
        ) x
      ),'[]'::jsonb),
      'noAplica',(select jsonb_build_object('n',count(*),'total',coalesce(sum(v.monto),0))
        from period_all v where v.asesor='NO APLICA' and (p_sede='' or v.sede=p_sede)),
      -- Legacy filter semantics intentionally preserved: sede summaries ignore p_sede.
      'porSede',coalesce((
        select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select sede,count(*) n,sum(monto) total,
          count(*) filter(where tipo='SERVICIO') n_serv,count(*) filter(where tipo='PRODUCTO') n_prod
          from advisor_base group by sede) x
      ),'[]'::jsonb),
      'porMetodoPago',coalesce((select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select pago metodo,count(*) n,sum(monto) total from base group by pago) x),'[]'::jsonb),
      'porMetodoPagoSede',coalesce((select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select pago metodo,sede,count(*) n,sum(monto) total from advisor_base group by pago,sede) x),'[]'::jsonb),
      'porTratamiento',coalesce((select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select tratamiento,count(*) n,sum(monto) total from base group by tratamiento order by sum(monto) desc limit 10) x),'[]'::jsonb),
      'anual',coalesce((select jsonb_agg(to_jsonb(x) order by x.mes_num)
        from (select extract(month from fecha)::int mes_num,sum(monto) facturado,count(*) n_ventas
          from year_base group by extract(month from fecha)) x),'[]'::jsonb),
      'metodos',(select coalesce(jsonb_agg(to_jsonb(x) order by x.orden),'[]'::jsonb)
        from (select id,nombre,moneda,activo,orden,sede from public.aos_metodos_pago order by orden) x),
      'metas',(select coalesce(jsonb_agg(to_jsonb(x) order by x.periodo desc),'[]'::jsonb)
        from (select id,periodo,meta,moneda,descripcion from public.aos_metas_ventas order by periodo desc) x)
    ) from agg a
  );
end;
$function$;

comment on function public.aos_ventas_admin(integer,integer,text,text) is
  'REV-PERF P0: one materialized monthly base reused by KPIs/detail/rankings; legacy JSON/filter semantics preserved.';

create or replace function public.aos_ventas_admin_anio(
  p_anio integer,
  p_sede text default '',
  p_asesor text default ''
) returns jsonb
language plpgsql
security definer
as $function$
declare
  v_desde date := make_date(p_anio,1,1);
  v_hasta date := make_date(p_anio,12,31);
begin
  return (
    with product_rules as materialized (
      select monto_min::numeric monto_min,comision::numeric comision
      from public.aos_tabla_comisiones
      where tipo='PRODUCTO' and activo=true
    ),
    period_all as materialized (
      select v.* from public.aos_ventas v where v.fecha between v_desde and v_hasta
    ),
    base as materialized (
      select v.* from period_all v
      where (p_sede='' or v.sede=p_sede) and (p_asesor='' or v.asesor=p_asesor)
    ),
    advisor_base as materialized (
      select v.* from period_all v where p_asesor='' or v.asesor=p_asesor
    ),
    agg as (
      select count(*) nventas,coalesce(sum(monto),0) fact,
        case when count(*)>0 then round(sum(monto)/count(*)) else 0 end ticket,
        count(*) filter(where tipo='SERVICIO') nserv,
        coalesce(sum(monto) filter(where tipo='SERVICIO'),0) fserv,
        count(*) filter(where tipo='PRODUCTO') nprod,
        coalesce(sum(monto) filter(where tipo='PRODUCTO'),0) fprod,
        count(*) filter(where estado_pago='PAGO COMPLETO') npago,
        count(*) filter(where estado_pago='ADELANTO') nadel,
        coalesce(sum(monto) filter(where estado_pago='ADELANTO'),0) fadel,
        count(*) filter(where estado_pago is null or estado_pago not in ('PAGO COMPLETO','ADELANTO')) nsin
      from base
    )
    select jsonb_build_object(
      'factTotal',a.fact,'nVentas',a.nventas,'ticketProm',a.ticket,
      'nServ',a.nserv,'factServ',a.fserv,'nProd',a.nprod,'factProd',a.fprod,
      'nPagoCompleto',a.npago,'nAdelanto',a.nadel,'factAdelanto',a.fadel,'nSinDefinir',a.nsin,
      'detalle',coalesce((select jsonb_agg(to_jsonb(d) order by d.fecha desc,d.id desc)
        from (select v.id,v.fecha::text fecha,v.monto,v.tipo,v.tratamiento,v.descripcion,v.pago,v.sede,
          v.estado_pago,v.atendio,v.numero_limpio,v.asesor,v.nombres,v.apellidos,
          case when v.asesor='NO APLICA' then 0
               when v.tipo='SERVICIO' then round(v.monto*0.005,2)
               when v.tipo='PRODUCTO' then coalesce((select max(r.comision) from product_rules r where r.monto_min<=v.monto),0)
               else 0 end as comision
          from base v) d),'[]'::jsonb),
      'porAsesor',coalesce((select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select v.asesor,count(*) n,sum(v.monto) total,
          sum(case when v.tipo='SERVICIO' then round(v.monto*0.005,2)
                   when v.tipo='PRODUCTO' then coalesce((select max(r.comision) from product_rules r where r.monto_min<=v.monto),0)
                   else 0 end) comision
          from period_all v where (p_sede='' or v.sede=p_sede) and v.asesor!='NO APLICA' group by v.asesor) x),'[]'::jsonb),
      'noAplica',(select jsonb_build_object('n',count(*),'total',coalesce(sum(v.monto),0))
        from period_all v where v.asesor='NO APLICA' and (p_sede='' or v.sede=p_sede)),
      'porSede',coalesce((select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select sede,count(*) n,sum(monto) total,count(*) filter(where tipo='SERVICIO') n_serv,
          count(*) filter(where tipo='PRODUCTO') n_prod from advisor_base group by sede) x),'[]'::jsonb),
      'porMetodoPago',coalesce((select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select pago metodo,count(*) n,sum(monto) total from base group by pago) x),'[]'::jsonb),
      'porMetodoPagoSede',coalesce((select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select pago metodo,sede,count(*) n,sum(monto) total from advisor_base group by pago,sede) x),'[]'::jsonb),
      'porTratamiento',coalesce((select jsonb_agg(to_jsonb(x) order by x.total desc)
        from (select tratamiento,count(*) n,sum(monto) total from base group by tratamiento order by sum(monto) desc limit 10) x),'[]'::jsonb),
      'anual',coalesce((select jsonb_agg(to_jsonb(x) order by x.mes_num)
        from (select extract(month from fecha)::int mes_num,sum(monto) facturado,count(*) n_ventas
          from base group by extract(month from fecha)) x),'[]'::jsonb)
    ) from agg a
  );
end;
$function$;

comment on function public.aos_ventas_admin_anio(integer,text,text) is
  'REV-PERF P0: one materialized annual base reused by all dashboard aggregates; legacy JSON/filter semantics preserved.';
