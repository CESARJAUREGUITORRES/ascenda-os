-- ASCENDA OS — F4 Revenue Operations Integration V1
-- Additive core. No legacy grants are revoked in this migration.

create or replace function public.aos_f4_actor(p_token text, p_panel text)
returns uuid
language sql
stable
security definer
set search_path to ''
as $function$
  select au.id
  from public.aos_usuarios au
  join public.aos_rrhh r on r.codigo_asesor=au.codigo_asesor
  where au.id=public.aos_app_actor_v3(p_token,p_panel,true)
    and au.activo=true
    and lower(coalesce(au.rol,''))='admin'
    and au.nivel_jerarquia in (1,2)
    and upper(trim(coalesce(r.estado,'')))='ACTIVO'
  limit 1
$function$;

create or replace function public.aos_f4_sede_allowed(p_actor uuid, p_sede text)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select case
    when au.id is null then false
    when upper(trim(coalesce(p_sede,''))) not in ('SAN ISIDRO','PUEBLO LIBRE') then false
    when au.nivel_jerarquia=1 then true
    else coalesce(upper(trim(p_sede))=any(
      array(select upper(trim(s)) from unnest(coalesce(au.sedes_permitidas,'{}'::text[])) s)
    ),false)
  end
  from public.aos_usuarios au
  where au.id=p_actor
$function$;

create or replace function public.aos_sales_admin_gateway_v4(
  p_token text,
  p_mes integer default null,
  p_anio integer default extract(year from (now() at time zone 'America/Lima'))::integer,
  p_sede text default '',
  p_asesor text default '',
  p_mode text default 'MES'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_level integer;
  v_mode text:=upper(trim(coalesce(p_mode,'MES')));
  v_sede text:=upper(trim(coalesce(p_sede,'')));
  v_asesor text:=upper(trim(coalesce(p_asesor,'')));
  v_desde date;
  v_hasta date;
  v_base jsonb;
  v_detail jsonb;
  v_products jsonb;
  v_product_lines integer:=0;
  v_resolved integer:=0;
  v_review integer:=0;
  v_excluded integer:=0;
  v_units numeric:=0;
  v_packs integer:=0;
  v_resolved_revenue numeric:=0;
  v_unresolved_revenue numeric:=0;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-sales');
  if v_actor is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  select nivel_jerarquia into v_level from public.aos_usuarios where id=v_actor;

  if v_mode not in ('MES','ANIO') or p_anio not between 2020 and 2100 then
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

  if v_mode='ANIO' then
    v_desde:=make_date(p_anio,1,1);
    v_hasta:=make_date(p_anio,12,31);
    v_base:=public.aos_ventas_admin_anio(p_anio,v_sede,v_asesor);
  else
    v_desde:=make_date(p_anio,p_mes,1);
    v_hasta:=(v_desde+interval '1 month'-interval '1 day')::date;
    v_base:=public.aos_ventas_admin(p_mes,p_anio,v_sede,v_asesor);
  end if;

  select coalesce(jsonb_agg(
    e || jsonb_build_object(
      'rawDescription',e->>'descripcion',
      'canonicalProductKey',f.product_key,
      'canonicalProductName',pi.canonical_name,
      'physicalQty',f.physical_qty,
      'isPack',f.is_pack,
      'productResolutionStatus',f.resolution_status,
      'productResolutionSource',f.resolution_source,
      'updatedAt',v.updated_at
    ) order by (e->>'fecha') desc,(e->>'id')::bigint desc
  ),'[]'::jsonb)
  into v_detail
  from jsonb_array_elements(coalesce(v_base->'detalle','[]'::jsonb)) e
  left join public.aos_ventas v on v.id=(e->>'id')::bigint
  left join public.aos_product_sale_fact_v1 f on f.sale_id=v.id
  left join public.aos_product_identity_v1 pi on pi.product_key=f.product_key;

  select coalesce(jsonb_agg(to_jsonb(q) order by q.revenue desc,q.canonical_name),'[]'::jsonb)
  into v_products
  from (
    select
      f.product_key,
      max(pi.canonical_name) as canonical_name,
      count(*)::integer as sales_lines,
      coalesce(sum(v.monto),0)::numeric as revenue,
      coalesce(sum(f.physical_qty),0)::numeric as physical_units,
      count(*) filter(where coalesce(f.is_pack,false))::integer as pack_lines
    from public.aos_ventas v
    join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
    join public.aos_product_identity_v1 pi on pi.product_key=f.product_key
    where v.fecha between v_desde and v_hasta
      and upper(trim(coalesce(v.tipo,'')))='PRODUCTO'
      and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
      and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor)
    group by f.product_key
  ) q;

  select
    count(*)::integer,
    count(*) filter(where f.resolution_status='RESOLVED')::integer,
    count(*) filter(where f.resolution_status='REVIEW_REQUIRED' or f.sale_id is null)::integer,
    count(*) filter(where f.resolution_status='EXCLUDED')::integer,
    coalesce(sum(f.physical_qty) filter(where f.resolution_status='RESOLVED'),0),
    count(*) filter(where f.resolution_status='RESOLVED' and coalesce(f.is_pack,false))::integer,
    coalesce(sum(v.monto) filter(where f.resolution_status='RESOLVED'),0),
    coalesce(sum(v.monto) filter(where f.resolution_status='REVIEW_REQUIRED' or f.sale_id is null),0)
  into v_product_lines,v_resolved,v_review,v_excluded,v_units,v_packs,v_resolved_revenue,v_unresolved_revenue
  from public.aos_ventas v
  left join public.aos_product_sale_fact_v1 f on f.sale_id=v.id
  where v.fecha between v_desde and v_hasta
    and upper(trim(coalesce(v.tipo,'')))='PRODUCTO'
    and (v_sede='' or upper(trim(coalesce(v.sede,'')))=v_sede)
    and (v_asesor='' or upper(trim(coalesce(v.asesor,'')))=v_asesor);

  update public.aos_app_sessions_v3 set last_used_at=now()
  where user_id=v_actor and revoked=false;

  return coalesce(v_base,'{}'::jsonb) || jsonb_build_object(
    'ok',true,
    'contract','F4_REVENUE_OPERATIONS_V1',
    'detalle',v_detail,
    'canonicalProducts',v_products,
    'physicalUnits',v_units,
    'productPackLines',v_packs,
    'productResolution',jsonb_build_object(
      'productLines',v_product_lines,
      'resolved',v_resolved,
      'reviewRequired',v_review,
      'excluded',v_excluded,
      'resolvedRevenue',v_resolved_revenue,
      'unresolvedRevenue',v_unresolved_revenue,
      'coveragePct',case when v_product_lines=0 then 100 else round((v_resolved::numeric/v_product_lines::numeric)*100,2) end
    )
  );
end
$function$;

create or replace function public.aos_sales_admin_sale_v4(p_token text,p_sale_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_sede text;
  v_row jsonb;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-sales');
  if v_actor is null or p_sale_id is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  select upper(trim(coalesce(sede,''))) into v_sede from public.aos_ventas where id=p_sale_id;
  if v_sede is null then return jsonb_build_object('ok',false,'error','SALE_NOT_FOUND'); end if;
  if not public.aos_f4_sede_allowed(v_actor,v_sede) then return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE'); end if;

  select to_jsonb(v) || jsonb_build_object(
    'rawDescription',v.descripcion,
    'canonicalProductKey',f.product_key,
    'canonicalProductName',pi.canonical_name,
    'physicalQty',f.physical_qty,
    'isPack',f.is_pack,
    'productResolutionStatus',f.resolution_status
  ) into v_row
  from public.aos_ventas v
  left join public.aos_product_sale_fact_v1 f on f.sale_id=v.id
  left join public.aos_product_identity_v1 pi on pi.product_key=f.product_key
  where v.id=p_sale_id;

  return jsonb_build_object('ok',true,'row',v_row);
end
$function$;

create or replace function public.aos_editar_venta_v4(
  p_token text,
  p_venta_id bigint,
  p_expected_updated_at timestamptz,
  p_campos jsonb,
  p_origen text default 'panel_ventas_f4'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_actor_name text;
  v_row record;
  v_target_sede text;
  v_allowed text[]:=array[
    'fecha','nombres','apellidos','dni','celular','tratamiento','descripcion',
    'pago','monto','estado_pago','asesor','atendio','sede','numero_limpio',
    'nro_doc','estado_doc','tipo_comprobante','tipo'
  ]::text[];
  v_result jsonb;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-sales');
  if v_actor is null or p_venta_id is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if p_expected_updated_at is null then return jsonb_build_object('ok',false,'error','EXPECTED_VERSION_REQUIRED'); end if;
  if p_campos is null or jsonb_typeof(p_campos)<>'object' then return jsonb_build_object('ok',false,'error','INVALID_FIELDS'); end if;
  if exists(select 1 from jsonb_object_keys(p_campos) k where not (k=any(v_allowed))) then
    return jsonb_build_object('ok',false,'error','FIELD_NOT_ALLOWED');
  end if;

  select v.id,v.updated_at,upper(trim(coalesce(v.sede,''))) sede
  into v_row
  from public.aos_ventas v where v.id=p_venta_id for update;
  if v_row.id is null then return jsonb_build_object('ok',false,'error','SALE_NOT_FOUND'); end if;
  if v_row.updated_at<>p_expected_updated_at then
    return jsonb_build_object('ok',false,'error','STALE_SALE','current_updated_at',v_row.updated_at);
  end if;
  if not public.aos_f4_sede_allowed(v_actor,v_row.sede) then return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE'); end if;

  if p_campos ? 'sede' then
    v_target_sede:=upper(trim(coalesce(p_campos->>'sede','')));
    if not public.aos_f4_sede_allowed(v_actor,v_target_sede) then return jsonb_build_object('ok',false,'error','FORBIDDEN_TARGET_SEDE'); end if;
  end if;

  select au.nombre into v_actor_name from public.aos_usuarios au where au.id=v_actor;
  v_result:=public.aos_editar_venta(p_venta_id,p_campos,coalesce(v_actor_name,'ADMIN'),'ADMIN',coalesce(nullif(trim(p_origen),''),'panel_ventas_f4'));

  insert into public.aos_security_log(usuario,accion,detalles)
  values(coalesce(v_actor_name,'ADMIN'),'F4_SALE_EDIT',jsonb_build_object(
    'actor_id',v_actor,'sale_id',p_venta_id,'fields',(select coalesce(jsonb_agg(k),'[]'::jsonb) from jsonb_object_keys(p_campos) k),'origin',p_origen
  ));

  return coalesce(v_result,'{}'::jsonb) || jsonb_build_object(
    'updated_at',(select updated_at from public.aos_ventas where id=p_venta_id),
    'security_contract','F4_TOKEN_2FA_ADMIN_SALES'
  );
end
$function$;

create or replace function public.aos_importar_ventas_preview_v4(p_token text,p_ventas jsonb)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_row jsonb;
  v_total integer;
  v_errors integer:=0;
  v_products integer:=0;
  v_resolved integer:=0;
  v_review integer:=0;
  v_advances integer:=0;
  v_existing integer:=0;
  v_total_amount numeric:=0;
  v_amount numeric;
  v_trat text;
  v_desc text;
  v_alias text;
  v_sede text;
  v_num text;
  v_fecha date;
  v_hash text;
  v_already boolean:=false;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-import-ventas');
  if v_actor is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if p_ventas is null or jsonb_typeof(p_ventas)<>'array' then return jsonb_build_object('ok',false,'error','INVALID_BATCH'); end if;
  v_total:=jsonb_array_length(p_ventas);
  if v_total<1 or v_total>2000 then return jsonb_build_object('ok',false,'error','INVALID_BATCH_SIZE','total',v_total); end if;
  v_hash:=md5(p_ventas::text);
  select exists(select 1 from public.aos_import_ventas_batches where batch_hash=v_hash) into v_already;

  for v_row in select value from jsonb_array_elements(p_ventas)
  loop
    begin
      v_sede:=upper(trim(coalesce(v_row->>'sede','')));
      if not public.aos_f4_sede_allowed(v_actor,v_sede) then v_errors:=v_errors+1; continue; end if;
      v_fecha:=(v_row->>'fecha')::date;
      v_amount:=coalesce(nullif(regexp_replace(coalesce(v_row->>'monto',''),'[^0-9.]','','g'),'')::numeric,0);
      if v_amount<0 then v_errors:=v_errors+1; continue; end if;
      v_total_amount:=v_total_amount+v_amount;
      v_trat:=upper(trim(coalesce(v_row->>'tratamiento','')));
      v_desc:=coalesce(v_row->>'descripcion','');
      if upper(trim(coalesce(v_row->>'estado_pago','PAGO COMPLETO')))='ADELANTO' then v_advances:=v_advances+1; end if;
      if v_trat like '%COMPRA%' or v_trat like '%PRODUCTO%' or v_trat='OTROS' then
        v_products:=v_products+1;
        v_alias:=public.aos_product_normalize_alias_v2(v_desc);
        if exists(select 1 from public.aos_product_alias_v2 a where a.alias_key=v_alias and a.active=true) then v_resolved:=v_resolved+1; else v_review:=v_review+1; end if;
      end if;
      v_num:=regexp_replace(coalesce(v_row->>'celular',''),'[^0-9]','','g');
      if length(v_num)>9 then v_num:=right(v_num,9); end if;
      if exists(
        select 1 from public.aos_ventas v
        where v.fecha=v_fecha and v.numero_limpio=v_num
          and upper(trim(coalesce(v.tratamiento,'')))=v_trat
          and coalesce(v.monto,0)=v_amount
          and upper(trim(coalesce(v.pago,'')))=upper(trim(coalesce(v_row->>'pago','')))
          and upper(trim(coalesce(v.asesor,'')))=upper(trim(coalesce(v_row->>'asesor','')))
      ) then v_existing:=v_existing+1; end if;
    exception when others then
      v_errors:=v_errors+1;
    end;
  end loop;

  return jsonb_build_object(
    'ok',v_errors=0,
    'error',case when v_errors>0 then 'PREVIEW_VALIDATION_ERRORS' else null end,
    'total',v_total,
    'totalAmount',v_total_amount,
    'batchHash',v_hash,
    'alreadyImported',v_already,
    'possibleExistingMatches',v_existing,
    'productLines',v_products,
    'productResolved',v_resolved,
    'productReviewRequired',v_review,
    'advances',v_advances,
    'validationErrors',v_errors,
    'mutates',false
  );
end
$function$;

create or replace function public.aos_importar_ventas_v4(p_token text,p_ventas jsonb)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_actor_name text;
  v_preview jsonb;
  v_result jsonb;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-import-ventas');
  if v_actor is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  v_preview:=public.aos_importar_ventas_preview_v4(p_token,p_ventas);
  if coalesce((v_preview->>'ok')::boolean,false)=false then return v_preview; end if;

  v_result:=public.aos_importar_ventas(p_ventas);
  select au.nombre into v_actor_name from public.aos_usuarios au where au.id=v_actor;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(coalesce(v_actor_name,'ADMIN'),'F4_IMPORT_VENTAS',jsonb_build_object(
    'actor_id',v_actor,'preview',v_preview,'result',v_result
  ));

  return coalesce(v_result,'{}'::jsonb) || jsonb_build_object('ok',true,'preview',v_preview,'security_contract','F4_TOKEN_2FA_ADMIN_IMPORT');
end
$function$;

create or replace function public.aos_grabar_venta_caja_v4(
  p_token text,
  p_sede text, p_usuario text, p_sesion_id text, p_numero_limpio text,
  p_nombres text, p_apellidos text, p_celular text, p_dni text,
  p_asesor text, p_doctor text, p_items jsonb, p_metodo_pago text,
  p_monto_total numeric, p_moneda text, p_tipo_comprobante text,
  p_nro_doc text, p_estado_pago text, p_nota text, p_tipo text, p_fecha text,
  p_razon_social_id text default null, p_monto_pagado numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_actor_name text;
  v_session record;
  v_result jsonb;
  v_sede text:=upper(trim(coalesce(p_sede,'')));
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-caja');
  if v_actor is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if not public.aos_f4_sede_allowed(v_actor,v_sede) then return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE'); end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then return jsonb_build_object('ok',false,'error','ITEMS_REQUIRED'); end if;
  if coalesce(p_monto_total,0)<0 or coalesce(p_monto_pagado,p_monto_total,0)<0 then return jsonb_build_object('ok',false,'error','INVALID_AMOUNT'); end if;

  if nullif(trim(coalesce(p_sesion_id,'')),'') is not null then
    select id,upper(trim(coalesce(sede,''))) sede,upper(trim(coalesce(estado,''))) estado
    into v_session from public.aos_caja_sesiones where id=p_sesion_id;
    if v_session.id is null then return jsonb_build_object('ok',false,'error','SESSION_NOT_FOUND'); end if;
    if v_session.estado<>'ABIERTA' then return jsonb_build_object('ok',false,'error','SESSION_NOT_OPEN'); end if;
    if v_session.sede<>v_sede then return jsonb_build_object('ok',false,'error','SESSION_SEDE_MISMATCH'); end if;
  end if;

  select au.nombre into v_actor_name from public.aos_usuarios au where au.id=v_actor;
  v_result:=public.aos_grabar_venta_caja(
    v_sede,coalesce(v_actor_name,'ADMIN'),p_sesion_id,p_numero_limpio,p_nombres,p_apellidos,p_celular,p_dni,
    p_asesor,p_doctor,p_items,p_metodo_pago,p_monto_total,p_moneda,p_tipo_comprobante,p_nro_doc,
    p_estado_pago,p_nota,p_tipo,p_fecha,p_razon_social_id,p_monto_pagado
  );

  insert into public.aos_security_log(usuario,accion,detalles)
  values(coalesce(v_actor_name,'ADMIN'),'F4_CAJA_VENTA',jsonb_build_object(
    'actor_id',v_actor,'sede',v_sede,'session_id',p_sesion_id,'result',v_result
  ));
  return coalesce(v_result,'{}'::jsonb) || jsonb_build_object('security_contract','F4_TOKEN_2FA_ADMIN_CAJA');
end
$function$;

revoke all on function public.aos_f4_actor(text,text) from public;
revoke all on function public.aos_f4_sede_allowed(uuid,text) from public;
revoke all on function public.aos_sales_admin_gateway_v4(text,integer,integer,text,text,text) from public;
revoke all on function public.aos_sales_admin_sale_v4(text,bigint) from public;
revoke all on function public.aos_editar_venta_v4(text,bigint,timestamptz,jsonb,text) from public;
revoke all on function public.aos_importar_ventas_preview_v4(text,jsonb) from public;
revoke all on function public.aos_importar_ventas_v4(text,jsonb) from public;
revoke all on function public.aos_grabar_venta_caja_v4(text,text,text,text,text,text,text,text,text,text,text,jsonb,text,numeric,text,text,text,text,text,text,text,text,numeric) from public;

grant execute on function public.aos_sales_admin_gateway_v4(text,integer,integer,text,text,text) to anon,authenticated;
grant execute on function public.aos_sales_admin_sale_v4(text,bigint) to anon,authenticated;
grant execute on function public.aos_editar_venta_v4(text,bigint,timestamptz,jsonb,text) to anon,authenticated;
grant execute on function public.aos_importar_ventas_preview_v4(text,jsonb) to anon,authenticated;
grant execute on function public.aos_importar_ventas_v4(text,jsonb) to anon,authenticated;
grant execute on function public.aos_grabar_venta_caja_v4(text,text,text,text,text,text,text,text,text,text,text,jsonb,text,numeric,text,text,text,text,text,text,text,text,numeric) to anon,authenticated;
