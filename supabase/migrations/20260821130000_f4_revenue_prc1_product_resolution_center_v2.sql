-- ASCENDA OS — REV-PRC1 Product Resolution Center v2
-- Historical/filterable owner review, safe reopen/correction and physical quantity controls.
-- Raw aos_ventas fields remain immutable from these functions.

create or replace function public.aos_product_review_admin_v2(
  p_token text,
  p_status text default 'REVIEW_REQUIRED',
  p_year integer default null,
  p_month integer default null,
  p_sede text default '',
  p_search text default ''
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_status text:=upper(trim(coalesce(p_status,'REVIEW_REQUIRED')));
  v_search text:=upper(trim(coalesce(p_search,'')));
  v_queue jsonb:='[]'::jsonb;
  v_products jsonb:='[]'::jsonb;
  v_years jsonb:='[]'::jsonb;
  v_sedes jsonb:='[]'::jsonb;
  v_summary jsonb:='{}'::jsonb;
  v_selected_lines integer:=0;
  v_selected_groups integer:=0;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-sales');
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if v_status not in ('REVIEW_REQUIRED','RESOLVED','EXCLUDED','ALL') then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_STATUS');
  end if;
  if p_month is not null and (p_month<1 or p_month>12) then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_MONTH');
  end if;

  select pg_catalog.jsonb_build_object(
    'reviewRequired',count(*) filter(where f.resolution_status='REVIEW_REQUIRED'),
    'resolved',count(*) filter(where f.resolution_status='RESOLVED'),
    'excluded',count(*) filter(where f.resolution_status='EXCLUDED'),
    'total',count(*)
  ) into v_summary
  from public.aos_product_sale_fact_v1 f;

  select coalesce(pg_catalog.jsonb_agg(y.yr order by y.yr desc),'[]'::jsonb)
    into v_years
  from (
    select distinct extract(year from v.fecha)::integer yr
    from public.aos_product_sale_fact_v1 f join public.aos_ventas v on v.id=f.sale_id
    where v.fecha is not null
  ) y;

  select coalesce(pg_catalog.jsonb_agg(s.sede order by s.sede),'[]'::jsonb)
    into v_sedes
  from (
    select distinct upper(trim(v.sede)) sede
    from public.aos_product_sale_fact_v1 f join public.aos_ventas v on v.id=f.sale_id
    where nullif(trim(coalesce(v.sede,'')),'') is not null
  ) s;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'productKey',i.product_key,
    'canonicalName',i.canonical_name,
    'lifecycleStatus',i.lifecycle_status,
    'productGroup',i.product_group,
    'variantLabel',i.variant_label,
    'catalogServiceId',i.catalog_service_id
  ) order by i.canonical_name),'[]'::jsonb)
  into v_products
  from public.aos_product_identity_v1 i
  where i.active=true;

  with base as (
    select
      f.sale_id,f.product_key,f.raw_alias_key,f.physical_qty,f.is_pack,
      f.resolution_status,f.resolution_source,f.locked,f.note,f.updated_at fact_updated_at,
      v.fecha,v.nombres,v.apellidos,v.dni,v.celular,v.tratamiento,v.descripcion,v.monto,v.sede,v.asesor,v.atendio,v.tipo,v.updated_at sale_updated_at,
      i.canonical_name,i.lifecycle_status
    from public.aos_product_sale_fact_v1 f
    join public.aos_ventas v on v.id=f.sale_id
    left join public.aos_product_identity_v1 i on i.product_key=f.product_key
    where (v_status='ALL' or f.resolution_status=v_status)
      and (p_year is null or extract(year from v.fecha)::integer=p_year)
      and (p_month is null or extract(month from v.fecha)::integer=p_month)
      and (coalesce(trim(p_sede),'')='' or upper(trim(v.sede))=upper(trim(p_sede)))
      and (
        v_search='' or
        upper(coalesce(v.descripcion,'')) like '%'||v_search||'%' or
        upper(coalesce(f.raw_alias_key,'')) like '%'||v_search||'%' or
        upper(coalesce(i.canonical_name,'')) like '%'||v_search||'%' or
        upper(coalesce(v.nombres,'')||' '||coalesce(v.apellidos,'')) like '%'||v_search||'%' or
        v.id::text=v_search
      )
  ), grouped as (
    select
      coalesce(b.raw_alias_key,'SIN_ALIAS') alias_key,
      b.resolution_status,
      b.product_key,
      max(b.canonical_name) canonical_name,
      max(b.lifecycle_status) lifecycle_status,
      pg_catalog.to_jsonb(pg_catalog.array_agg(distinct b.descripcion order by b.descripcion)) raw_descriptions,
      count(*)::integer line_count,
      count(*) filter(where coalesce(b.locked,false))::integer locked_count,
      min(b.fecha) first_date,
      max(b.fecha) last_date,
      pg_catalog.to_jsonb(pg_catalog.array_agg(distinct b.sede order by b.sede)) sedes,
      coalesce(sum(b.monto),0)::numeric revenue,
      coalesce(sum(b.physical_qty),0)::numeric physical_units,
      count(*) filter(where coalesce(b.is_pack,false))::integer pack_lines,
      max(b.resolution_source) resolution_source,
      max(b.fact_updated_at) fact_updated_at,
      (
        select count(*)::integer
        from public.aos_product_sale_fact_v1 f2
        where f2.raw_alias_key=b.raw_alias_key
          and f2.resolution_status=b.resolution_status
          and (b.product_key is null or f2.product_key=b.product_key)
      ) global_group_count,
      pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'saleId',b.sale_id,'date',b.fecha,'names',b.nombres,'lastNames',b.apellidos,
        'document',b.dni,'phone',b.celular,'treatment',b.tratamiento,'rawDescription',b.descripcion,
        'amount',b.monto,'sede',b.sede,'advisor',b.asesor,'attendedBy',b.atendio,'type',b.tipo,
        'physicalQty',b.physical_qty,'isPack',b.is_pack,'saleUpdatedAt',b.sale_updated_at
      ) order by b.fecha desc,b.sale_id desc) sales
    from base b
    group by b.raw_alias_key,b.resolution_status,b.product_key
  )
  select
    count(*)::integer,
    coalesce(sum(line_count),0)::integer,
    coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'aliasKey',alias_key,
      'status',resolution_status,
      'productKey',product_key,
      'canonicalName',canonical_name,
      'lifecycleStatus',lifecycle_status,
      'rawDescriptions',raw_descriptions,
      'lineCount',line_count,
      'globalGroupCount',global_group_count,
      'lockedCount',locked_count,
      'firstDate',first_date,
      'lastDate',last_date,
      'sedes',sedes,
      'revenue',revenue,
      'physicalUnits',physical_units,
      'packLines',pack_lines,
      'resolutionSource',resolution_source,
      'factUpdatedAt',fact_updated_at,
      'sales',sales
    ) order by last_date desc,alias_key),'[]'::jsonb)
  into v_selected_groups,v_selected_lines,v_queue
  from grouped;

  update public.aos_app_sessions_v3 set last_used_at=pg_catalog.now()
  where user_id=v_actor and revoked=false;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'contract','REV_PRC1_PRODUCT_RESOLUTION_V2',
    'status',v_status,
    'selectedLines',v_selected_lines,
    'selectedGroups',v_selected_groups,
    'summary',v_summary,
    'availableYears',v_years,
    'availableSedes',v_sedes,
    'queue',coalesce(v_queue,'[]'::jsonb),
    'products',coalesce(v_products,'[]'::jsonb)
  );
end
$function$;

create or replace function public.aos_product_review_resolve_v2(
  p_token text,
  p_alias_key text,
  p_action text,
  p_expected_count integer default null,
  p_product_key text default null,
  p_canonical_name text default null,
  p_lifecycle_status text default 'CURRENT_UNCATALOGED',
  p_default_qty numeric default 1,
  p_default_is_pack boolean default false,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_result jsonb;
  v_key text;
  v_qty numeric:=coalesce(p_default_qty,1);
  v_product text;
begin
  if v_qty<=0 or v_qty>999 then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_PHYSICAL_QTY');
  end if;

  v_result:=public.aos_product_review_resolve_v1(
    p_token,p_alias_key,p_action,p_expected_count,p_product_key,p_canonical_name,p_lifecycle_status,p_note
  );
  if coalesce((v_result->>'ok')::boolean,false)=false then return v_result; end if;
  if upper(trim(coalesce(p_action,'')))='EXCLUDE_NOT_PRODUCT' then return v_result; end if;

  v_key:=public.aos_product_normalize_alias_v2(p_alias_key);
  v_product:=v_result->>'productKey';
  if nullif(v_product,'') is null then return v_result; end if;

  update public.aos_product_alias_v2
  set default_qty=v_qty,default_is_pack=coalesce(p_default_is_pack,false),updated_at=pg_catalog.now()
  where alias_key=v_key and product_key=v_product;

  update public.aos_product_sale_fact_v1
  set physical_qty=v_qty,is_pack=coalesce(p_default_is_pack,false),updated_at=pg_catalog.now()
  where raw_alias_key=v_key and product_key=v_product and resolution_status='RESOLVED' and coalesce(locked,false)=false;

  return v_result || pg_catalog.jsonb_build_object('physicalQty',v_qty,'isPack',coalesce(p_default_is_pack,false));
end
$function$;

create or replace function public.aos_product_review_reopen_v1(
  p_token text,
  p_alias_key text,
  p_expected_status text,
  p_expected_product_key text default null,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_actor_name text;
  v_alias text;
  v_status text:=upper(trim(coalesce(p_expected_status,'')));
  v_count integer:=0;
  v_product_count integer:=0;
  v_affected integer:=0;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-sales');
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if v_status not in ('RESOLVED','EXCLUDED') then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_REOPEN_STATUS'); end if;
  v_alias:=public.aos_product_normalize_alias_v2(p_alias_key);
  if v_alias is null then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ALIAS'); end if;

  perform 1 from public.aos_product_sale_fact_v1 f
  where f.raw_alias_key=v_alias and f.resolution_status=v_status
  for update;

  select count(*)::integer,count(distinct coalesce(f.product_key,''))::integer
    into v_count,v_product_count
  from public.aos_product_sale_fact_v1 f
  where f.raw_alias_key=v_alias and f.resolution_status=v_status
    and (p_expected_product_key is null or f.product_key=p_expected_product_key);

  if v_count=0 then return pg_catalog.jsonb_build_object('ok',false,'error','GROUP_NOT_FOUND'); end if;
  if v_status='RESOLVED' and p_expected_product_key is null and v_product_count>1 then
    return pg_catalog.jsonb_build_object('ok',false,'error','EXPECTED_PRODUCT_REQUIRED');
  end if;

  if v_status='RESOLVED' then
    update public.aos_product_alias_v2
    set active=false,updated_at=pg_catalog.now()
    where alias_key=v_alias and (p_expected_product_key is null or product_key=p_expected_product_key);
  end if;

  update public.aos_product_sale_fact_v1 f set
    product_key=null,
    physical_qty=null,
    is_pack=null,
    resolution_status='REVIEW_REQUIRED',
    resolution_source='OWNER_REOPENED',
    locked=false,
    note=coalesce(nullif(trim(p_note),''),'Reopened by owner for correction; raw sale preserved'),
    updated_at=pg_catalog.now()
  where f.raw_alias_key=v_alias and f.resolution_status=v_status
    and (p_expected_product_key is null or f.product_key=p_expected_product_key);
  get diagnostics v_affected=row_count;

  select u.nombre into v_actor_name from public.aos_usuarios u where u.id=v_actor;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(coalesce(v_actor_name,'ADMIN'),'REV_PRC1_PRODUCT_REOPEN',pg_catalog.jsonb_build_object(
    'actor_id',v_actor,'alias_key',v_alias,'previous_status',v_status,
    'previous_product_key',p_expected_product_key,'affected',v_affected,'note',p_note
  ));

  return pg_catalog.jsonb_build_object('ok',true,'status','REVIEW_REQUIRED','aliasKey',v_alias,'affected',v_affected);
end
$function$;

-- Override v1 batch preview: OTROS is always SERVICIO and must never enter product review.
create or replace function public.aos_product_batch_review_v1(p_token text,p_ventas jsonb)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_groups jsonb;
  v_lines integer:=0;
  v_aliases integer:=0;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-import-ventas');
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if p_ventas is null or pg_catalog.jsonb_typeof(p_ventas)<>'array' then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_BATCH');
  end if;

  with rows as (
    select coalesce(e->>'descripcion','') raw_description,
           public.aos_product_normalize_alias_v2(e->>'descripcion') alias_key,
           upper(trim(coalesce(e->>'tratamiento',''))) treatment
    from pg_catalog.jsonb_array_elements(p_ventas) e
  ), unresolved as (
    select r.* from rows r
    where r.treatment<>'OTROS'
      and (r.treatment like '%COMPRA%PRODUCTO%' or r.treatment like '%PRODUCTO%')
      and r.alias_key is not null
      and not exists(select 1 from public.aos_product_alias_v2 a where a.alias_key=r.alias_key and a.active=true)
  )
  select count(*)::integer,count(distinct alias_key)::integer into v_lines,v_aliases from unresolved;

  with rows as (
    select coalesce(e->>'descripcion','') raw_description,
           public.aos_product_normalize_alias_v2(e->>'descripcion') alias_key,
           upper(trim(coalesce(e->>'tratamiento',''))) treatment
    from pg_catalog.jsonb_array_elements(p_ventas) e
  ), unresolved as (
    select r.* from rows r
    where r.treatment<>'OTROS'
      and (r.treatment like '%COMPRA%PRODUCTO%' or r.treatment like '%PRODUCTO%')
      and r.alias_key is not null
      and not exists(select 1 from public.aos_product_alias_v2 a where a.alias_key=r.alias_key and a.active=true)
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'aliasKey',x.alias_key,'rawDescriptions',x.raw_descriptions,'lineCount',x.line_count
  ) order by x.line_count desc,x.alias_key),'[]'::jsonb)
  into v_groups
  from (
    select alias_key,pg_catalog.to_jsonb(pg_catalog.array_agg(distinct raw_description order by raw_description)) raw_descriptions,
           count(*)::integer line_count
    from unresolved group by alias_key
  ) x;

  return pg_catalog.jsonb_build_object('ok',true,'reviewLines',v_lines,'uniqueAliases',v_aliases,'groups',coalesce(v_groups,'[]'::jsonb));
end
$function$;

revoke all on function public.aos_product_review_admin_v2(text,text,integer,integer,text,text) from public;
revoke all on function public.aos_product_review_resolve_v2(text,text,text,integer,text,text,text,numeric,boolean,text) from public;
revoke all on function public.aos_product_review_reopen_v1(text,text,text,text,text) from public;
grant execute on function public.aos_product_review_admin_v2(text,text,integer,integer,text,text) to anon,authenticated,service_role;
grant execute on function public.aos_product_review_resolve_v2(text,text,text,integer,text,text,text,numeric,boolean,text) to anon,authenticated,service_role;
grant execute on function public.aos_product_review_reopen_v1(text,text,text,text,text) to anon,authenticated,service_role;
