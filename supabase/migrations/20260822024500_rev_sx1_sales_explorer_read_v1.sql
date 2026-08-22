-- ASCENDA OS Â· REV-SX1 â€” Sales Explorer Read-Only V1
-- Additive analytics only. No business-data writes, triggers, or formula mutations.
-- Initial Explorer rendering is client-memory only; this RPC is lazy-loaded for historical/drill-down analysis.

create or replace function public.aos_sales_explorer_history_v1(
  p_token text,
  p_kind text,
  p_anio integer,
  p_mes integer default null,
  p_mode text default 'MES',
  p_sede text default '',
  p_asesor text default '',
  p_entity text default ''
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $function$
declare
  v_actor uuid;
  v_level integer;
  v_kind text:=upper(trim(coalesce(p_kind,'')));
  v_mode text:=upper(trim(coalesce(p_mode,'MES')));
  v_sede text:=upper(trim(coalesce(p_sede,'')));
  v_asesor text:=upper(trim(coalesce(p_asesor,'')));
  v_entity text:=trim(coalesce(p_entity,''));
  v_today date:=(now() at time zone 'America/Lima')::date;
  v_period_start date;
  v_period_end date;
  v_prev_start date;
  v_prev_end date;
  v_current jsonb;
  v_previous jsonb;
  v_history jsonb:='[]'::jsonb;
  v_clients jsonb:='[]'::jsonb;
  v_advisors jsonb:='[]'::jsonb;
  v_sites jsonb:='[]'::jsonb;
  v_sales jsonb:='[]'::jsonb;
  v_prev_has_rows boolean:=false;
  v_coverage jsonb:='{}'::jsonb;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-sales');
  if v_actor is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  select nivel_jerarquia into v_level from public.aos_usuarios where id=v_actor;

  if v_kind not in ('PRODUCT','SERVICE') then
    return jsonb_build_object('ok',false,'error','INVALID_KIND');
  end if;
  if v_mode not in ('TODAY','MES','ANIO') or p_anio not between 2020 and 2100 then
    return jsonb_build_object('ok',false,'error','INVALID_PERIOD');
  end if;
  if v_mode='MES' and (p_mes is null or p_mes not between 1 and 12) then
    return jsonb_build_object('ok',false,'error','INVALID_MONTH');
  end if;
  if v_sede<>'' and not public.aos_f4_sede_allowed(v_actor,v_sede) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE');
  end if;
  if v_sede='' and v_level<>1 then
    return jsonb_build_object('ok',false,'error','SEDE_REQUIRED');
  end if;

  if v_mode='TODAY' then
    v_period_start:=v_today;
    v_period_end:=v_today;
    v_prev_start:=v_today-1;
    v_prev_end:=v_today-1;
  elsif v_mode='ANIO' then
    v_period_start:=make_date(p_anio,1,1);
    v_period_end:=case when p_anio=extract(year from v_today)::integer then v_today else make_date(p_anio,12,31) end;
    v_prev_start:=make_date(p_anio-1,1,1);
    v_prev_end:=least(make_date(p_anio-1,12,31), (v_period_end-interval '1 year')::date);
  else
    v_period_start:=make_date(p_anio,p_mes,1);
    v_period_end:=least((v_period_start+(interval '1 month' - interval '1 day'))::date,
      case when date_trunc('month',v_period_start)=date_trunc('month',v_today) then v_today else (v_period_start+(interval '1 month' - interval '1 day'))::date end);
    v_prev_start:=(v_period_start-interval '1 month')::date;
    v_prev_end:=least((v_prev_start+(interval '1 month' - interval '1 day'))::date,
      v_prev_start + (v_period_end-v_period_start));
  end if;

  if v_kind='PRODUCT' then
    with base as (
      select v.id,v.fecha,v.monto,v.numero_limpio,v.nombres,v.apellidos,v.sede,v.asesor,v.atendio,v.estado_pago,
             v.descripcion,f.product_key,f.physical_qty,f.is_pack,pi.canonical_name
      from public.aos_ventas v
      join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
      join public.aos_product_identity_v1 pi on pi.product_key=f.product_key
      where upper(trim(coalesce(v.tipo,'')))='PRODUCTO'
        and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
        and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
        and (v_entity='' or f.product_key=v_entity)
    ), months as (
      select extract(month from fecha)::integer mes,
             count(*)::integer ventas,
             coalesce(sum(physical_qty),0)::numeric unidades,
             count(*) filter(where coalesce(is_pack,false))::integer packs,
             count(distinct nullif(numero_limpio,''))::integer clientes,
             coalesce(sum(monto),0)::numeric facturacion
      from base where extract(year from fecha)::integer=p_anio group by 1 order by 1
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'month',mes,'sales',ventas,'units',unidades,'packs',packs,'clients',clientes,
      'revenue',facturacion,'ticket',case when ventas=0 then 0 else round(facturacion/ventas,2) end
    ) order by mes),'[]'::jsonb) into v_history from months;

    with base as (
      select v.* ,f.physical_qty,f.is_pack,f.product_key,pi.canonical_name
      from public.aos_ventas v
      join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
      join public.aos_product_identity_v1 pi on pi.product_key=f.product_key
      where upper(trim(coalesce(v.tipo,'')))='PRODUCTO'
        and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
        and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
        and (v_entity='' or f.product_key=v_entity)
    )
    select jsonb_build_object(
      'sales',count(*)::integer,'units',coalesce(sum(physical_qty),0),'packs',count(*) filter(where coalesce(is_pack,false))::integer,
      'clients',count(distinct nullif(numero_limpio,''))::integer,'revenue',coalesce(sum(monto),0),
      'ticket',case when count(*)=0 then 0 else round(coalesce(sum(monto),0)/count(*),2) end
    ) into v_current from base where fecha between v_period_start and v_period_end;

    with base as (
      select v.* ,f.physical_qty,f.is_pack,f.product_key
      from public.aos_ventas v join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
      where upper(trim(coalesce(v.tipo,'')))='PRODUCTO'
        and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
        and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
        and (v_entity='' or f.product_key=v_entity)
    )
    select jsonb_build_object(
      'sales',count(*)::integer,'units',coalesce(sum(physical_qty),0),'packs',count(*) filter(where coalesce(is_pack,false))::integer,
      'clients',count(distinct nullif(numero_limpio,''))::integer,'revenue',coalesce(sum(monto),0),
      'ticket',case when count(*)=0 then 0 else round(coalesce(sum(monto),0)/count(*),2) end
    ), count(*)>0 into v_previous,v_prev_has_rows from base where fecha between v_prev_start and v_prev_end;

    if v_entity<>'' then
      with base as (
        select v.*,f.physical_qty,f.is_pack,pi.canonical_name
        from public.aos_ventas v
        join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
        join public.aos_product_identity_v1 pi on pi.product_key=f.product_key
        where extract(year from v.fecha)::integer=p_anio and f.product_key=v_entity
          and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
          and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
      )
      select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc),'[]'::jsonb) into v_clients
      from (select coalesce(nullif(trim(nombres||' '||apellidos),''),'SIN NOMBRE') cliente,numero_limpio,
                   count(*)::integer sales,coalesce(sum(physical_qty),0)::numeric units,coalesce(sum(monto),0)::numeric revenue,max(fecha) last_sale
            from base group by 1,2 order by revenue desc limit 100) x;

      with base as (
        select v.*,f.physical_qty from public.aos_ventas v join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
        where extract(year from v.fecha)::integer=p_anio and f.product_key=v_entity
          and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
          and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
      )
      select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc),'[]'::jsonb) into v_advisors
      from (select coalesce(nullif(asesor,''),'SIN ASESOR') asesor,count(*)::integer sales,coalesce(sum(physical_qty),0)::numeric units,
                   count(distinct nullif(numero_limpio,''))::integer clients,coalesce(sum(monto),0)::numeric revenue
            from base group by 1) x;

      with base as (
        select v.*,f.physical_qty from public.aos_ventas v join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
        where extract(year from v.fecha)::integer=p_anio and f.product_key=v_entity
          and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
          and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
      )
      select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc),'[]'::jsonb) into v_sites
      from (select coalesce(nullif(sede,''),'SIN SEDE') sede,count(*)::integer sales,coalesce(sum(physical_qty),0)::numeric units,
                   count(distinct nullif(numero_limpio,''))::integer clients,coalesce(sum(monto),0)::numeric revenue
            from base group by 1) x;

      select coalesce(jsonb_agg(jsonb_build_object(
        'id',v.id,'date',v.fecha,'client',trim(coalesce(v.nombres,'')||' '||coalesce(v.apellidos,'')),'phone',v.numero_limpio,
        'rawDescription',v.descripcion,'canonicalProduct',pi.canonical_name,'amount',v.monto,'units',f.physical_qty,'pack',f.is_pack,
        'advisor',v.asesor,'attendedBy',v.atendio,'site',v.sede,'paymentStatus',v.estado_pago
      ) order by v.fecha desc,v.id desc),'[]'::jsonb) into v_sales
      from public.aos_ventas v
      join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
      join public.aos_product_identity_v1 pi on pi.product_key=f.product_key
      where extract(year from v.fecha)::integer=p_anio and f.product_key=v_entity
        and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
        and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
      limit 500;
    end if;

    select jsonb_build_object(
      'productLines',count(*)::integer,
      'resolved',count(*) filter(where f.resolution_status='RESOLVED')::integer,
      'reviewRequired',count(*) filter(where f.resolution_status='REVIEW_REQUIRED' or f.sale_id is null)::integer,
      'excluded',count(*) filter(where f.resolution_status='EXCLUDED')::integer,
      'units',coalesce(sum(f.physical_qty) filter(where f.resolution_status='RESOLVED'),0),
      'revenue',coalesce(sum(v.monto),0)
    ) into v_coverage
    from public.aos_ventas v left join public.aos_product_sale_fact_v1 f on f.sale_id=v.id
    where extract(year from v.fecha)::integer=p_anio and upper(trim(coalesce(v.tipo,'')))='PRODUCTO'
      and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
      and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor);
  else
    with base as (
      select v.*,
        translate(upper(trim(regexp_replace(coalesce(v.tratamiento,''),'\s+',' ','g'))),'ÃÃ‰ÃÃ“ÃšÃœÃ‘','AEIOUUN') service_key
      from public.aos_ventas v
      where upper(trim(coalesce(v.tipo,'')))='SERVICIO'
        and upper(trim(coalesce(v.tratamiento,'')))<>'OTROS'
        and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
        and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
    ), filtered as (
      select * from base where v_entity='' or service_key=v_entity
    ), months as (
      select extract(month from fecha)::integer mes,count(*)::integer ventas,
             count(distinct nullif(numero_limpio,''))::integer clientes,coalesce(sum(monto),0)::numeric facturacion
      from filtered where extract(year from fecha)::integer=p_anio group by 1 order by 1
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'month',mes,'sales',ventas,'clients',clientes,'revenue',facturacion,
      'ticket',case when ventas=0 then 0 else round(facturacion/ventas,2) end
    ) order by mes),'[]'::jsonb) into v_history from months;

    with base as (
      select v.*,translate(upper(trim(regexp_replace(coalesce(v.tratamiento,''),'\s+',' ','g'))),'ÃÃ‰ÃÃ“ÃšÃœÃ‘','AEIOUUN') service_key
      from public.aos_ventas v where upper(trim(coalesce(v.tipo,'')))='SERVICIO' and upper(trim(coalesce(v.tratamiento,'')))<>'OTROS'
        and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede) and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
    )
    select jsonb_build_object('sales',count(*)::integer,'clients',count(distinct nullif(numero_limpio,''))::integer,
      'revenue',coalesce(sum(monto),0),'ticket',case when count(*)=0 then 0 else round(coalesce(sum(monto),0)/count(*),2) end)
    into v_current from base where fecha between v_period_start and v_period_end and (v_entity='' or service_key=v_entity);

    with base as (
      select v.*,translate(upper(trim(regexp_replace(coalesce(v.tratamiento,''),'\s+',' ','g'))),'ÃÃ‰ÃÃ“ÃšÃœÃ‘','AEIOUUN') service_key
      from public.aos_ventas v where upper(trim(coalesce(v.tipo,'')))='SERVICIO' and upper(trim(coalesce(v.tratamiento,'')))<>'OTROS'
        and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede) and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
    )
    select jsonb_build_object('sales',count(*)::integer,'clients',count(distinct nullif(numero_limpio,''))::integer,
      'revenue',coalesce(sum(monto),0),'ticket',case when count(*)=0 then 0 else round(coalesce(sum(monto),0)/count(*),2) end), count(*)>0
    into v_previous,v_prev_has_rows from base where fecha between v_prev_start and v_prev_end and (v_entity='' or service_key=v_entity);

    if v_entity<>'' then
      with base as (
        select v.* from public.aos_ventas v
        where extract(year from v.fecha)::integer=p_anio and upper(trim(coalesce(v.tipo,'')))='SERVICIO'
          and upper(trim(coalesce(v.tratamiento,'')))<>'OTROS'
          and translate(upper(trim(regexp_replace(coalesce(v.tratamiento,''),'\s+',' ','g'))),'ÃÃ‰ÃÃ“ÃšÃœÃ‘','AEIOUUN')=v_entity
          and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
          and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
      )
      select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc),'[]'::jsonb) into v_clients
      from (select coalesce(nullif(trim(nombres||' '||apellidos),''),'SIN NOMBRE') cliente,numero_limpio,count(*)::integer sales,
                   coalesce(sum(monto),0)::numeric revenue,max(fecha) last_sale from base group by 1,2 order by revenue desc limit 100) x;

      with base as (
        select v.* from public.aos_ventas v
        where extract(year from v.fecha)::integer=p_anio and upper(trim(coalesce(v.tipo,'')))='SERVICIO'
          and upper(trim(coalesce(v.tratamiento,'')))<>'OTROS'
          and translate(upper(trim(regexp_replace(coalesce(v.tratamiento,''),'\s+',' ','g'))),'ÃÃ‰ÃÃ“ÃšÃœÃ‘','AEIOUUN')=v_entity
          and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
          and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
      )
      select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc),'[]'::jsonb) into v_advisors
      from (select coalesce(nullif(asesor,''),'SIN ASESOR') asesor,count(*)::integer sales,count(distinct nullif(numero_limpio,''))::integer clients,
                   coalesce(sum(monto),0)::numeric revenue from base group by 1) x;

      with base as (
        select v.* from public.aos_ventas v
        where extract(year from v.fecha)::integer=p_anio and upper(trim(coalesce(v.tipo,'')))='SERVICIO'
          and upper(trim(coalesce(v.tratamiento,'')))<>'OTROS'
          and translate(upper(trim(regexp_replace(coalesce(v.tratamiento,''),'\s+',' ','g'))),'ÃÃ‰ÃÃ“ÃšÃœÃ‘','AEIOUUN')=v_entity
          and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
          and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
      )
      select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc),'[]'::jsonb) into v_sites
      from (select coalesce(nullif(sede,''),'SIN SEDE') sede,count(*)::integer sales,count(distinct nullif(numero_limpio,''))::integer clients,
                   coalesce(sum(monto),0)::numeric revenue from base group by 1) x;

      select coalesce(jsonb_agg(jsonb_build_object(
        'id',v.id,'date',v.fecha,'client',trim(coalesce(v.nombres,'')||' '||coalesce(v.apellidos,'')),'phone',v.numero_limpio,
        'service',v.tratamiento,'amount',v.monto,'advisor',v.asesor,'attendedBy',v.atendio,'site',v.sede,'paymentStatus',v.estado_pago
      ) order by v.fecha desc,v.id desc),'[]'::jsonb) into v_sales
      from public.aos_ventas v
      where extract(year from v.fecha)::integer=p_anio and upper(trim(coalesce(v.tipo,'')))='SERVICIO'
        and upper(trim(coalesce(v.tratamiento,'')))<>'OTROS'
        and translate(upper(trim(regexp_replace(coalesce(v.tratamiento,''),'\s+',' ','g'))),'ÃÃ‰ÃÃ“ÃšÃœÃ‘','AEIOUUN')=v_entity
        and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
        and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
      limit 500;
    end if;

    select jsonb_build_object('serviceLines',count(*)::integer,'clients',count(distinct nullif(numero_limpio,''))::integer,
      'revenue',coalesce(sum(monto),0)) into v_coverage
    from public.aos_ventas v where extract(year from v.fecha)::integer=p_anio
      and upper(trim(coalesce(v.tipo,'')))='SERVICIO' and upper(trim(coalesce(v.tratamiento,'')))<>'OTROS'
      and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
      and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor);
  end if;

  return jsonb_build_object(
    'ok',true,'contract','REV_SX1_READ_V1','kind',v_kind,'year',p_anio,'entity',v_entity,
    'filters',jsonb_build_object('mode',v_mode,'month',p_mes,'site',v_sede,'advisor',v_asesor),
    'period',jsonb_build_object('start',v_period_start,'end',v_period_end),
    'comparisonPeriod',jsonb_build_object('start',v_prev_start,'end',v_prev_end),
    'current',coalesce(v_current,'{}'::jsonb),
    'previous',case when v_prev_has_rows then coalesce(v_previous,'{}'::jsonb) else null end,
    'comparisonStatus',case when v_prev_has_rows then 'CERTIFIED' else 'NO_CERTIFIED_SOURCE' end,
    'history',v_history,'clients',v_clients,'advisors',v_advisors,'sites',v_sites,'sales',v_sales,'coverage',v_coverage
  );
end
$function$;

revoke all on function public.aos_sales_explorer_history_v1(text,text,integer,integer,text,text,text,text) from public;
grant execute on function public.aos_sales_explorer_history_v1(text,text,integer,integer,text,text,text,text) to anon,authenticated;
