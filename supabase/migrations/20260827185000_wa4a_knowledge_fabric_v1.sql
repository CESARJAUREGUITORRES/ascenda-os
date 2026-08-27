-- ASCENDA Conversations — WA-4A Knowledge Fabric V1
-- TEST-first / PROD-ready. Derived read-only knowledge contracts over existing canonical sources.
-- No source-of-truth rows are copied or mutated by this migration.
begin;

do $$
begin
  if to_regclass('public.aos_catalogo_servicios') is null then raise exception 'WA4A_SOURCE_REQUIRED:aos_catalogo_servicios'; end if;
  if to_regclass('public.aos_promociones') is null then raise exception 'WA4A_SOURCE_REQUIRED:aos_promociones'; end if;
  if to_regclass('public.aos_sedes_geo') is null then raise exception 'WA4A_SOURCE_REQUIRED:aos_sedes_geo'; end if;
  if to_regclass('public.aos_config_horarios') is null then raise exception 'WA4A_SOURCE_REQUIRED:aos_config_horarios'; end if;
  if to_regclass('public.aos_catalogo_categorias') is null then raise exception 'WA4A_SOURCE_REQUIRED:aos_catalogo_categorias'; end if;
end
$$;

create or replace function public.aos_wa4a_norm_v1(p_value text)
returns text
language sql
immutable
set search_path=''
as $$
  select trim(regexp_replace(
    lower(translate(coalesce(p_value,''),
      'ÁÉÍÓÚÜÑáéíóúüñ',
      'AEIOUUNaeiouun')),
    '[^a-z0-9]+',' ','g'));
$$;

revoke all on function public.aos_wa4a_norm_v1(text) from public,anon,authenticated;
grant execute on function public.aos_wa4a_norm_v1(text) to service_role;

create or replace view public.aos_wa4a_knowledge_authority_v1
with (security_invoker=true)
as
select * from (values
  ('CATALOG'::text,'public.aos_catalogo_servicios'::text,10::smallint,'AUTHORITATIVE'::text,'Commercial product/service identity, prices, approved commercial description, benefits, public FAQ and operational requirements.'::text),
  ('PROMOTION','public.aos_promociones',10::smallint,'AUTHORITATIVE','Promotion name, discount, code, treatment scope and validity window. Only active/current rows are answerable.'),
  ('BRANCH','public.aos_sedes_geo',10::smallint,'AUTHORITATIVE_WITH_FRESHNESS_UNKNOWN','Branch name, address, phone and maps link. horario_lv/horario_finde are deliberately excluded from answerable knowledge.'),
  ('HOURS','public.aos_config_horarios',10::smallint,'AUTHORITATIVE','Operational opening/closing hours by branch/day. Cross-source drift against aos_sedes_geo display hours is surfaced as conflict.'),
  ('CATEGORY','public.aos_catalogo_categorias',20::smallint,'FALLBACK','Generic category commercial description, benefits and FAQ only; never overrides a service-specific fact.'),
  ('EXCLUDED','public.aos_sedes_geo.horario_*',90::smallint,'CONFLICTING_DISPLAY_METADATA','Not answerable. Current production values conflict with aos_config_horarios and remain diagnostic evidence only.'),
  ('EXCLUDED','public.aos_servicios_catalogo',90::smallint,'LEGACY_NOT_AUTHORITY','Legacy/empty catalog is not a WA-4A source of truth.'),
  ('EXCLUDED','generic_llm_knowledge',99::smallint,'NON_AUTHORITY','Generic model knowledge cannot override or fabricate ASCENDA commercial facts.')
) v(domain,source_relation,authority_tier,authority_state,contract_note);

revoke all on table public.aos_wa4a_knowledge_authority_v1 from public,anon,authenticated;
grant select on table public.aos_wa4a_knowledge_authority_v1 to service_role;

create or replace view public.aos_wa4a_knowledge_items_v1
with (security_invoker=true)
as
with
service_rows as (
  select s.*,
         public.aos_wa4a_norm_v1(s.nombre) as norm_name
  from public.aos_catalogo_servicios s
  where coalesce(s.estado,'ACTIVO')='ACTIVO'
),
service_conflicts as (
  select norm_name
  from service_rows
  group by norm_name
  having count(*) > 1
     and (
       count(distinct coalesce(precio_base,-99999999::numeric)) > 1
       or count(distinct coalesce(precio_oferta,-99999999::numeric)) > 1
     )
),
service_items as (
  select
    'service:'||s.id::text as knowledge_id,
    'CATALOG'::text as domain,
    upper(coalesce(s.tipo,'SERVICIO'))::text as subject_type,
    s.id::text as subject_id,
    s.norm_name as subject_key,
    s.nombre::text as title,
    concat_ws(' ',s.nombre,s.nombre_corto,s.categoria,s.descripcion_comercial,s.beneficios,s.duracion_sesion,s.num_sesiones,s.frecuencia,coalesce(s.faqs::text,''),s.tags)::text as search_text,
    jsonb_strip_nulls(jsonb_build_object(
      'tipo',upper(coalesce(s.tipo,'SERVICIO')),
      'nombre',s.nombre,
      'nombre_corto',s.nombre_corto,
      'categoria',s.categoria,
      'precio_base',s.precio_base,
      'precio_oferta',s.precio_oferta,
      'duracion_sesion',s.duracion_sesion,
      'num_sesiones',s.num_sesiones,
      'frecuencia',s.frecuencia,
      'descripcion_comercial',s.descripcion_comercial,
      'beneficios',s.beneficios,
      'faqs',coalesce(s.faqs,'[]'::jsonb),
      'requiere_doctora',coalesce(s.requiere_doctora,false),
      'requiere_enfermeria',coalesce(s.requiere_enfermeria,false)
    )) as facts,
    10::smallint as authority_tier,
    'public.aos_catalogo_servicios'::text as source_relation,
    s.id::text as source_pk,
    s.updated_at as source_updated_at,
    null::timestamptz as valid_from,
    null::timestamptz as valid_to,
    case
      when s.updated_at is null then 'UNKNOWN'
      when s.updated_at >= now()-interval '180 days' then 'FRESH'
      else 'STALE'
    end::text as freshness_state,
    case when c.norm_name is null then 'CLEAR' else 'CONFLICT' end::text as conflict_state,
    case
      when c.norm_name is not null then 'BLOCKED_CONFLICT'
      when s.updated_at is not null and s.updated_at < now()-interval '180 days' then 'BLOCKED_STALE'
      when s.precio_base is null and coalesce(s.descripcion_comercial,'')='' and jsonb_array_length(coalesce(s.faqs,'[]'::jsonb))=0 then 'BLOCKED_INSUFFICIENT'
      else 'READY'
    end::text as retrieval_state,
    jsonb_build_object('relation','public.aos_catalogo_servicios','pk',s.id::text,'version',coalesce(s.updated_at::text,s.created_at::text,'UNKNOWN')) as evidence_ref
  from service_rows s
  left join service_conflicts c using(norm_name)
),
promo_rows as (
  select p.*,
         public.aos_wa4a_norm_v1(coalesce(nullif(p.codigo,''),p.nombre)) as norm_key
  from public.aos_promociones p
),
promo_conflicts as (
  select norm_key
  from promo_rows
  where coalesce(activa,false)=true
  group by norm_key
  having count(*)>1 and (
    count(distinct coalesce(tipo_descuento,''))>1
    or count(distinct coalesce(valor_descuento,-99999999::numeric))>1
  )
),
promo_items as (
  select
    'promotion:'||p.id::text as knowledge_id,
    'PROMOTION'::text as domain,
    'PROMOTION'::text as subject_type,
    p.id::text as subject_id,
    p.norm_key as subject_key,
    p.nombre::text as title,
    concat_ws(' ',p.nombre,p.descripcion,p.codigo,array_to_string(p.tratamientos,' '),array_to_string(p.segmentos,' '))::text as search_text,
    jsonb_strip_nulls(jsonb_build_object(
      'nombre',p.nombre,'descripcion',p.descripcion,'tipo_descuento',p.tipo_descuento,
      'valor_descuento',p.valor_descuento,'tratamientos',coalesce(to_jsonb(p.tratamientos),'[]'::jsonb),
      'segmentos',coalesce(to_jsonb(p.segmentos),'[]'::jsonb),'codigo',p.codigo,
      'vigencia_inicio',p.vigencia_inicio,'vigencia_fin',p.vigencia_fin
    )) as facts,
    10::smallint as authority_tier,
    'public.aos_promociones'::text as source_relation,
    p.id::text as source_pk,
    p.updated_at as source_updated_at,
    p.vigencia_inicio::timestamptz as valid_from,
    case when p.vigencia_fin is null then null else (p.vigencia_fin+1)::timestamptz end as valid_to,
    case
      when coalesce(p.activa,false)=false then 'INACTIVE'
      when p.vigencia_inicio is not null and current_date<p.vigencia_inicio then 'UPCOMING'
      when p.vigencia_fin is not null and current_date>p.vigencia_fin then 'EXPIRED'
      when p.updated_at is null then 'UNKNOWN'
      when p.updated_at >= now()-interval '180 days' then 'FRESH'
      else 'STALE'
    end::text as freshness_state,
    case when c.norm_key is null then 'CLEAR' else 'CONFLICT' end::text as conflict_state,
    case
      when c.norm_key is not null then 'BLOCKED_CONFLICT'
      when coalesce(p.activa,false)=false then 'BLOCKED_INACTIVE'
      when p.vigencia_inicio is not null and current_date<p.vigencia_inicio then 'BLOCKED_UPCOMING'
      when p.vigencia_fin is not null and current_date>p.vigencia_fin then 'BLOCKED_EXPIRED'
      when p.updated_at is not null and p.updated_at < now()-interval '180 days' then 'BLOCKED_STALE'
      else 'READY'
    end::text as retrieval_state,
    jsonb_build_object('relation','public.aos_promociones','pk',p.id::text,'version',coalesce(p.updated_at::text,p.created_at::text,'UNKNOWN')) as evidence_ref
  from promo_rows p
  left join promo_conflicts c using(norm_key)
),
branch_items as (
  select
    'branch:'||g.id::text as knowledge_id,
    'BRANCH'::text as domain,
    'BRANCH'::text as subject_type,
    g.id::text as subject_id,
    public.aos_wa4a_norm_v1(g.nombre) as subject_key,
    replace(g.nombre,'_',' ')::text as title,
    concat_ws(' ',replace(g.nombre,'_',' '),g.direccion,g.telefono,g.maps_link)::text as search_text,
    jsonb_strip_nulls(jsonb_build_object(
      'nombre',replace(g.nombre,'_',' '),'direccion',g.direccion,'telefono',g.telefono,'maps_link',g.maps_link
    )) as facts,
    10::smallint as authority_tier,
    'public.aos_sedes_geo'::text as source_relation,
    g.id::text as source_pk,
    null::timestamptz as source_updated_at,
    null::timestamptz as valid_from,
    null::timestamptz as valid_to,
    'UNKNOWN'::text as freshness_state,
    'CLEAR'::text as conflict_state,
    case when coalesce(g.activa,false) then 'READY_WITH_WARNING' else 'BLOCKED_INACTIVE' end::text as retrieval_state,
    jsonb_build_object('relation','public.aos_sedes_geo','pk',g.id::text,'version','NO_UPDATED_AT','warning','FRESHNESS_UNKNOWN') as evidence_ref
  from public.aos_sedes_geo g
),
hour_rows as (
  select
    h.*,
    public.aos_wa4a_norm_v1(h.sede) as norm_sede,
    g.id as geo_id,
    g.horario_lv,
    g.horario_finde,
    case when g.horario_lv ~ '^[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}$' then split_part(g.horario_lv,'-',1)::time end as geo_lv_open,
    case when g.horario_lv ~ '^[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}$' then split_part(g.horario_lv,'-',2)::time end as geo_lv_close,
    case when g.horario_finde ~ '^[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}$' then split_part(g.horario_finde,'-',1)::time end as geo_finde_open,
    case when g.horario_finde ~ '^[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}$' then split_part(g.horario_finde,'-',2)::time end as geo_finde_close
  from public.aos_config_horarios h
  left join public.aos_sedes_geo g
    on public.aos_wa4a_norm_v1(replace(g.nombre,'_',' '))=public.aos_wa4a_norm_v1(h.sede)
),
hour_items as (
  select
    'hours:'||h.id::text as knowledge_id,
    'HOURS'::text as domain,
    'BRANCH_HOURS'::text as subject_type,
    h.id::text as subject_id,
    h.norm_sede||':'||h.dia_semana::text as subject_key,
    h.sede||' día '||h.dia_semana::text as title,
    concat_ws(' ',h.sede,'dia',h.dia_semana::text,h.hora_apertura::text,h.hora_cierre::text)::text as search_text,
    jsonb_build_object(
      'sede',h.sede,'dia_semana',h.dia_semana,'hora_apertura',h.hora_apertura::text,
      'hora_cierre',h.hora_cierre::text,'activo',coalesce(h.activo,false)
    ) as facts,
    10::smallint as authority_tier,
    'public.aos_config_horarios'::text as source_relation,
    h.id::text as source_pk,
    h.updated_at as source_updated_at,
    null::timestamptz as valid_from,
    null::timestamptz as valid_to,
    case
      when h.updated_at is null then 'UNKNOWN'
      when h.updated_at >= now()-interval '180 days' then 'FRESH'
      else 'STALE'
    end::text as freshness_state,
    case
      when h.geo_id is null then 'SOURCE_MISSING'
      when h.dia_semana between 1 and 5 and h.geo_lv_open is not null and (h.hora_apertura is distinct from h.geo_lv_open or h.hora_cierre is distinct from h.geo_lv_close) then 'CONFLICT'
      when h.dia_semana=6 and h.geo_finde_open is not null and (h.hora_apertura is distinct from h.geo_finde_open or h.hora_cierre is distinct from h.geo_finde_close) then 'CONFLICT'
      else 'CLEAR'
    end::text as conflict_state,
    case
      when coalesce(h.activo,false)=false then 'BLOCKED_INACTIVE'
      when h.geo_id is null then 'BLOCKED_SOURCE_MISSING'
      when h.dia_semana between 1 and 5 and h.geo_lv_open is not null and (h.hora_apertura is distinct from h.geo_lv_open or h.hora_cierre is distinct from h.geo_lv_close) then 'BLOCKED_CONFLICT'
      when h.dia_semana=6 and h.geo_finde_open is not null and (h.hora_apertura is distinct from h.geo_finde_open or h.hora_cierre is distinct from h.geo_finde_close) then 'BLOCKED_CONFLICT'
      when h.updated_at is not null and h.updated_at < now()-interval '180 days' then 'BLOCKED_STALE'
      else 'READY'
    end::text as retrieval_state,
    jsonb_build_object('relation','public.aos_config_horarios','pk',h.id::text,'version',coalesce(h.updated_at::text,h.created_at::text,'UNKNOWN'),'compared_to','public.aos_sedes_geo.horario_*') as evidence_ref
  from hour_rows h
),
category_items as (
  select
    'category:'||c.id::text as knowledge_id,
    'CATEGORY'::text as domain,
    'CATEGORY'::text as subject_type,
    c.id::text as subject_id,
    public.aos_wa4a_norm_v1(c.nombre) as subject_key,
    c.nombre::text as title,
    concat_ws(' ',c.nombre,c.descripcion_comercial,c.beneficios,coalesce(c.faqs::text,''))::text as search_text,
    jsonb_strip_nulls(jsonb_build_object('nombre',c.nombre,'descripcion_comercial',c.descripcion_comercial,'beneficios',c.beneficios,'faqs',coalesce(c.faqs,'[]'::jsonb))) as facts,
    20::smallint as authority_tier,
    'public.aos_catalogo_categorias'::text as source_relation,
    c.id::text as source_pk,
    c.updated_at as source_updated_at,
    null::timestamptz as valid_from,
    null::timestamptz as valid_to,
    case when c.updated_at is null then 'UNKNOWN' when c.updated_at>=now()-interval '180 days' then 'FRESH' else 'STALE' end::text as freshness_state,
    'CLEAR'::text as conflict_state,
    case
      when coalesce(c.estado,'ACTIVO')<>'ACTIVO' then 'BLOCKED_INACTIVE'
      when c.updated_at is not null and c.updated_at<now()-interval '180 days' then 'BLOCKED_STALE'
      when coalesce(c.descripcion_comercial,'')='' and jsonb_array_length(coalesce(c.faqs,'[]'::jsonb))=0 then 'BLOCKED_INSUFFICIENT'
      else 'READY'
    end::text as retrieval_state,
    jsonb_build_object('relation','public.aos_catalogo_categorias','pk',c.id::text,'version',coalesce(c.updated_at::text,c.created_at::text,'UNKNOWN')) as evidence_ref
  from public.aos_catalogo_categorias c
)
select * from service_items
union all select * from promo_items
union all select * from branch_items
union all select * from hour_items
union all select * from category_items;

revoke all on table public.aos_wa4a_knowledge_items_v1 from public,anon,authenticated;
grant select on table public.aos_wa4a_knowledge_items_v1 to service_role;

create or replace view public.aos_wa4a_knowledge_issues_v1
with (security_invoker=true)
as
select knowledge_id,domain,subject_type,subject_id,subject_key,title,authority_tier,source_relation,source_pk,source_updated_at,freshness_state,conflict_state,retrieval_state,evidence_ref
from public.aos_wa4a_knowledge_items_v1
where retrieval_state not in ('READY','READY_WITH_WARNING');

revoke all on table public.aos_wa4a_knowledge_issues_v1 from public,anon,authenticated;
grant select on table public.aos_wa4a_knowledge_issues_v1 to service_role;

create or replace function public.aos_wa4a_knowledge_search_v1(
  p_query text,
  p_limit integer default 12,
  p_domains text[] default null
)
returns table(
  knowledge_id text,
  domain text,
  subject_type text,
  subject_id text,
  title text,
  facts jsonb,
  authority_tier smallint,
  source_relation text,
  source_pk text,
  source_updated_at timestamptz,
  freshness_state text,
  conflict_state text,
  retrieval_state text,
  evidence_ref jsonb,
  score integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_q text := public.aos_wa4a_norm_v1(p_query);
  v_limit integer := greatest(1,least(coalesce(p_limit,12),24));
begin
  if length(v_q)<2 then
    return;
  end if;

  return query
  select
    k.knowledge_id,k.domain,k.subject_type,k.subject_id,k.title,k.facts,k.authority_tier,
    k.source_relation,k.source_pk,k.source_updated_at,k.freshness_state,k.conflict_state,k.retrieval_state,k.evidence_ref,
    (
      case when public.aos_wa4a_norm_v1(k.title)=v_q then 100 else 0 end
      + case when public.aos_wa4a_norm_v1(k.title) like '%'||v_q||'%' then 45 else 0 end
      + case when public.aos_wa4a_norm_v1(k.search_text) like '%'||v_q||'%' then 25 else 0 end
      + coalesce((select count(*)::integer*6 from unnest(string_to_array(v_q,' ')) w where length(w)>=3 and public.aos_wa4a_norm_v1(k.search_text) like '%'||w||'%'),0)
      + case when k.authority_tier=10 then 5 else 0 end
    )::integer as score
  from public.aos_wa4a_knowledge_items_v1 k
  where k.retrieval_state in ('READY','READY_WITH_WARNING')
    and k.conflict_state='CLEAR'
    and (p_domains is null or cardinality(p_domains)=0 or k.domain=any(p_domains))
    and (
      public.aos_wa4a_norm_v1(k.title) like '%'||v_q||'%'
      or public.aos_wa4a_norm_v1(k.search_text) like '%'||v_q||'%'
      or exists(select 1 from unnest(string_to_array(v_q,' ')) w where length(w)>=3 and public.aos_wa4a_norm_v1(k.search_text) like '%'||w||'%')
    )
  order by score desc,k.authority_tier asc,k.title asc
  limit v_limit;
end
$$;

revoke all on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) from public,anon,authenticated;
grant execute on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) to service_role;

comment on view public.aos_wa4a_knowledge_authority_v1 is 'WA-4A machine-readable authority matrix. Derived metadata only; no duplicate truth store.';
comment on view public.aos_wa4a_knowledge_items_v1 is 'WA-4A governed commercial knowledge projection with provenance, freshness, conflict and retrieval state. Clinical/private fields are excluded.';
comment on view public.aos_wa4a_knowledge_issues_v1 is 'WA-4A fail-closed diagnostics for stale, conflicting, inactive or insufficient source facts.';
comment on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) is 'Private service-role lexical retrieval over READY governed facts only. Conflicting/stale/inactive knowledge is never returned as answerable context.';

commit;
