-- ASCENDA OS — REV-PRC1 Product Resolution Center v1
-- Human-in-the-loop canonical product resolution on top of certified F3/F4.
-- Never overwrites aos_ventas.descripcion. No silent canonical inference.

create or replace function public.aos_product_review_admin_v1(p_token text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_queue jsonb;
  v_products jsonb;
  v_lines integer:=0;
  v_aliases integer:=0;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-sales');
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  select count(*)::integer,count(distinct f.raw_alias_key)::integer
    into v_lines,v_aliases
  from public.aos_product_sale_fact_v1 f
  where f.resolution_status='REVIEW_REQUIRED';

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'aliasKey',q.raw_alias_key,
    'rawDescriptions',q.raw_descriptions,
    'lineCount',q.line_count,
    'lockedCount',q.locked_count,
    'firstDate',q.first_date,
    'lastDate',q.last_date,
    'sedes',q.sedes,
    'revenue',q.revenue,
    'saleIds',q.sale_ids
  ) order by q.last_date desc,q.raw_alias_key),'[]'::jsonb)
  into v_queue
  from (
    select
      f.raw_alias_key,
      pg_catalog.to_jsonb(pg_catalog.array_agg(distinct v.descripcion order by v.descripcion)) raw_descriptions,
      count(*)::integer line_count,
      count(*) filter(where coalesce(f.locked,false))::integer locked_count,
      min(v.fecha) first_date,
      max(v.fecha) last_date,
      pg_catalog.to_jsonb(pg_catalog.array_agg(distinct v.sede order by v.sede)) sedes,
      coalesce(sum(v.monto),0)::numeric revenue,
      pg_catalog.to_jsonb(pg_catalog.array_agg(v.id order by v.id)) sale_ids
    from public.aos_product_sale_fact_v1 f
    join public.aos_ventas v on v.id=f.sale_id
    where f.resolution_status='REVIEW_REQUIRED'
    group by f.raw_alias_key
  ) q;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'productKey',i.product_key,
    'canonicalName',i.canonical_name,
    'lifecycleStatus',i.lifecycle_status,
    'catalogServiceId',i.catalog_service_id
  ) order by i.canonical_name),'[]'::jsonb)
  into v_products
  from public.aos_product_identity_v1 i
  where i.active=true;

  update public.aos_app_sessions_v3 set last_used_at=pg_catalog.now()
  where user_id=v_actor and revoked=false;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'contract','REV_PRC1_PRODUCT_RESOLUTION_V1',
    'reviewLines',v_lines,
    'uniqueAliases',v_aliases,
    'queue',coalesce(v_queue,'[]'::jsonb),
    'products',coalesce(v_products,'[]'::jsonb)
  );
end
$function$;

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
    select
      coalesce(e->>'descripcion','') raw_description,
      public.aos_product_normalize_alias_v2(e->>'descripcion') alias_key,
      upper(trim(coalesce(e->>'tratamiento',''))) treatment
    from pg_catalog.jsonb_array_elements(p_ventas) e
  ), unresolved as (
    select r.*
    from rows r
    where (r.treatment like '%COMPRA%' or r.treatment like '%PRODUCTO%' or r.treatment='OTROS')
      and r.alias_key is not null
      and not exists(
        select 1 from public.aos_product_alias_v2 a
        where a.alias_key=r.alias_key and a.active=true
      )
  )
  select count(*)::integer,count(distinct alias_key)::integer
  into v_lines,v_aliases from unresolved;

  with rows as (
    select
      coalesce(e->>'descripcion','') raw_description,
      public.aos_product_normalize_alias_v2(e->>'descripcion') alias_key,
      upper(trim(coalesce(e->>'tratamiento',''))) treatment
    from pg_catalog.jsonb_array_elements(p_ventas) e
  ), unresolved as (
    select r.*
    from rows r
    where (r.treatment like '%COMPRA%' or r.treatment like '%PRODUCTO%' or r.treatment='OTROS')
      and r.alias_key is not null
      and not exists(
        select 1 from public.aos_product_alias_v2 a
        where a.alias_key=r.alias_key and a.active=true
      )
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'aliasKey',x.alias_key,
    'rawDescriptions',x.raw_descriptions,
    'lineCount',x.line_count
  ) order by x.line_count desc,x.alias_key),'[]'::jsonb)
  into v_groups
  from (
    select alias_key,
      pg_catalog.to_jsonb(pg_catalog.array_agg(distinct raw_description order by raw_description)) raw_descriptions,
      count(*)::integer line_count
    from unresolved group by alias_key
  ) x;

  return pg_catalog.jsonb_build_object(
    'ok',true,'reviewLines',v_lines,'uniqueAliases',v_aliases,'groups',coalesce(v_groups,'[]'::jsonb)
  );
end
$function$;

create or replace function public.aos_product_review_resolve_v1(
  p_token text,
  p_alias_key text,
  p_action text,
  p_expected_count integer default null,
  p_product_key text default null,
  p_canonical_name text default null,
  p_lifecycle_status text default 'CURRENT_UNCATALOGED',
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
  v_alias_text text;
  v_action text:=upper(trim(coalesce(p_action,'')));
  v_product_key text;
  v_existing_product text;
  v_existing_active boolean;
  v_count integer:=0;
  v_locked integer:=0;
  v_lifecycle text:=upper(trim(coalesce(p_lifecycle_status,'CURRENT_UNCATALOGED')));
  v_norm_name text;
  v_affected integer:=0;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-sales');
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;

  v_alias:=public.aos_product_normalize_alias_v2(p_alias_key);
  if v_alias is null then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ALIAS'); end if;
  if v_action not in ('LINK_EXISTING','CREATE_NEW','EXCLUDE_NOT_PRODUCT') then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTION');
  end if;

  perform 1 from public.aos_product_sale_fact_v1 f
  where f.raw_alias_key=v_alias and f.resolution_status='REVIEW_REQUIRED'
  for update;

  select count(*)::integer,
         count(*) filter(where coalesce(f.locked,false))::integer,
         min(v.descripcion)
    into v_count,v_locked,v_alias_text
  from public.aos_product_sale_fact_v1 f
  join public.aos_ventas v on v.id=f.sale_id
  where f.raw_alias_key=v_alias and f.resolution_status='REVIEW_REQUIRED';

  if v_count=0 then
    select a.product_key,a.active into v_existing_product,v_existing_active
    from public.aos_product_alias_v2 a where a.alias_key=v_alias limit 1;
    if v_existing_product is not null and coalesce(v_existing_active,false) then
      return pg_catalog.jsonb_build_object('ok',true,'status','ALREADY_RESOLVED','aliasKey',v_alias,'productKey',v_existing_product,'affected',0);
    end if;
    return pg_catalog.jsonb_build_object('ok',false,'error','REVIEW_NOT_FOUND','aliasKey',v_alias);
  end if;

  if p_expected_count is not null and p_expected_count<>v_count then
    return pg_catalog.jsonb_build_object('ok',false,'error','STALE_REVIEW','expected',p_expected_count,'current',v_count);
  end if;
  if v_locked>0 then
    return pg_catalog.jsonb_build_object('ok',false,'error','LOCKED_REVIEW_REQUIRES_MANUAL','lockedCount',v_locked);
  end if;

  select au.nombre into v_actor_name from public.aos_usuarios au where au.id=v_actor;

  if v_action='EXCLUDE_NOT_PRODUCT' then
    update public.aos_product_sale_fact_v1 f set
      product_key=null,
      physical_qty=null,
      is_pack=null,
      resolution_status='EXCLUDED',
      resolution_source='OWNER_REVIEW_CENTER',
      locked=true,
      note=coalesce(nullif(trim(p_note),''),'Owner excluded from canonical product analytics; raw sale preserved'),
      updated_at=pg_catalog.now()
    where f.raw_alias_key=v_alias and f.resolution_status='REVIEW_REQUIRED' and coalesce(f.locked,false)=false;
    get diagnostics v_affected=row_count;

    insert into public.aos_security_log(usuario,accion,detalles)
    values(coalesce(v_actor_name,'ADMIN'),'REV_PRC1_PRODUCT_EXCLUDE',pg_catalog.jsonb_build_object(
      'actor_id',v_actor,'alias_key',v_alias,'affected',v_affected,'raw_description',v_alias_text,'note',p_note
    ));

    return pg_catalog.jsonb_build_object('ok',true,'status','EXCLUDED','aliasKey',v_alias,'affected',v_affected);
  end if;

  if v_action='LINK_EXISTING' then
    v_product_key:=trim(coalesce(p_product_key,''));
    if v_product_key='' or not exists(
      select 1 from public.aos_product_identity_v1 i where i.product_key=v_product_key and i.active=true
    ) then return pg_catalog.jsonb_build_object('ok',false,'error','PRODUCT_NOT_FOUND'); end if;
  else
    if nullif(trim(coalesce(p_canonical_name,'')),'') is null then
      return pg_catalog.jsonb_build_object('ok',false,'error','CANONICAL_NAME_REQUIRED');
    end if;
    if v_lifecycle not in ('CURRENT_UNCATALOGED','LEGACY') then
      return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_LIFECYCLE');
    end if;

    select i.product_key into v_product_key
    from public.aos_product_identity_v1 i
    where lower(trim(i.canonical_name))=lower(trim(p_canonical_name))
    limit 1;
    if v_product_key is not null then
      return pg_catalog.jsonb_build_object('ok',false,'error','CANONICAL_ALREADY_EXISTS','productKey',v_product_key);
    end if;

    v_norm_name:=public.aos_product_normalize_alias_v2(p_canonical_name);
    if v_norm_name is null then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_CANONICAL_NAME'); end if;
    v_product_key:='PRC:'||v_norm_name;
    if exists(select 1 from public.aos_product_identity_v1 i where i.product_key=v_product_key) then
      v_product_key:='PRC:'||substr(pg_catalog.md5(trim(p_canonical_name)),1,20);
    end if;

    insert into public.aos_product_identity_v1(
      product_key,canonical_name,lifecycle_status,active,metadata,created_at,updated_at
    ) values(
      v_product_key,trim(p_canonical_name),v_lifecycle,true,
      pg_catalog.jsonb_build_object('createdBy','REV_PRC1','sourceAlias',v_alias,'actorId',v_actor),
      pg_catalog.now(),pg_catalog.now()
    );
  end if;

  select a.product_key,a.active into v_existing_product,v_existing_active
  from public.aos_product_alias_v2 a where a.alias_key=v_alias limit 1;
  if v_existing_product is not null and v_existing_product<>v_product_key and coalesce(v_existing_active,false) then
    return pg_catalog.jsonb_build_object('ok',false,'error','ALIAS_CONFLICT','existingProductKey',v_existing_product);
  end if;

  insert into public.aos_product_alias_v2(
    alias_key,alias_text,product_key,default_qty,default_is_pack,source,confidence,active,created_at,updated_at
  ) values(
    v_alias,coalesce(nullif(v_alias_text,''),p_alias_key),v_product_key,1,false,
    'OWNER_REVIEW_CENTER','OWNER_CONFIRMED',true,pg_catalog.now(),pg_catalog.now()
  )
  on conflict(alias_key) do update set
    alias_text=excluded.alias_text,
    product_key=excluded.product_key,
    default_qty=coalesce(public.aos_product_alias_v2.default_qty,excluded.default_qty),
    default_is_pack=coalesce(public.aos_product_alias_v2.default_is_pack,excluded.default_is_pack),
    source='OWNER_REVIEW_CENTER',confidence='OWNER_CONFIRMED',active=true,updated_at=pg_catalog.now();

  update public.aos_product_sale_fact_v1 f set
    product_key=v_product_key,
    physical_qty=coalesce(f.physical_qty,1),
    is_pack=coalesce(f.is_pack,false),
    resolution_status='RESOLVED',
    resolution_source='OWNER_REVIEW_CENTER',
    note=coalesce(nullif(trim(p_note),''),'Resolved by Product Resolution Center; raw description preserved'),
    updated_at=pg_catalog.now()
  where f.raw_alias_key=v_alias and f.resolution_status='REVIEW_REQUIRED' and coalesce(f.locked,false)=false;
  get diagnostics v_affected=row_count;

  insert into public.aos_security_log(usuario,accion,detalles)
  values(coalesce(v_actor_name,'ADMIN'),'REV_PRC1_PRODUCT_RESOLVE',pg_catalog.jsonb_build_object(
    'actor_id',v_actor,'alias_key',v_alias,'action',v_action,'product_key',v_product_key,
    'affected',v_affected,'raw_description',v_alias_text,'note',p_note
  ));

  update public.aos_app_sessions_v3 set last_used_at=pg_catalog.now()
  where user_id=v_actor and revoked=false;

  return pg_catalog.jsonb_build_object(
    'ok',true,'status','RESOLVED','aliasKey',v_alias,'productKey',v_product_key,'affected',v_affected
  );
end
$function$;

revoke all on function public.aos_product_review_admin_v1(text) from public;
revoke all on function public.aos_product_batch_review_v1(text,jsonb) from public;
revoke all on function public.aos_product_review_resolve_v1(text,text,text,integer,text,text,text,text) from public;
grant execute on function public.aos_product_review_admin_v1(text) to anon,authenticated,service_role;
grant execute on function public.aos_product_batch_review_v1(text,jsonb) to anon,authenticated,service_role;
grant execute on function public.aos_product_review_resolve_v1(text,text,text,integer,text,text,text,text) to anon,authenticated,service_role;
