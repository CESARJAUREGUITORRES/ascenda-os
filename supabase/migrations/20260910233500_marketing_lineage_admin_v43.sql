-- Marketing V4.3 UI polish · secure operational lineage
-- Adds an admin/2FA-only monthly lineage reader so the internal Marketing panel
-- can show client identity and prior commercial history without expanding the
-- public/masked V4.3 value-map surface.

create or replace function public.aos_marketing_lineage_admin_v43(
  p_token text,
  p_anio integer,
  p_mes integer
)
returns jsonb
language sql
stable
security definer
set search_path to ''
set statement_timeout to '4s'
as $function$
with actor as (
  select public.aos_app_actor_v3(p_token,'admin-marketing',true) as id
),
authorized as (
  select u.id
  from actor a
  join public.aos_usuarios u on u.id=a.id
  where coalesce(u.nivel_jerarquia,99)<=2
),
bounds as (
  select
    pg_catalog.make_date(p_anio,p_mes,1) as d0,
    (pg_catalog.make_date(p_anio,p_mes,1)+interval '1 month')::date as d1
  where p_anio between 2020 and extract(year from current_date)::int+1
    and p_mes between 1 and 12
),
attrs as materialized (
  select a.*
  from bounds b,
       lateral public.aos_marketing_attribution_v2_preview(b.d0,b.d1-1) a
  where a.lead_fecha>=b.d0
    and a.lead_fecha<b.d1
    and a.venta_fecha>=b.d0
    and a.venta_fecha<b.d1
    and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
),
grp as (
  select
    a.numero_limpio,
    a.tipo_atribucion,
    a.lead_id,
    a.lead_fecha,
    a.lead_tratamiento,
    a.lead_anuncio,
    count(*)::bigint as operaciones,
    sum(a.monto)::numeric as facturacion,
    count(distinct a.llamada_id) filter(where a.llamada_id is not null)::bigint as llamadas_vinculadas,
    count(distinct a.cita_id) filter(where a.cita_id is not null)::bigint as citas_vinculadas,
    max(a.confidence)::int as confidence,
    string_agg(
      distinct case
        when a.metodo_match='SAME_MONTH_UNIQUE_NEW_CUSTOMER' then 'SAME_MONTH_UNIQUE_LEAD'
        else a.metodo_match
      end,
      ', ' order by case
        when a.metodo_match='SAME_MONTH_UNIQUE_NEW_CUSTOMER' then 'SAME_MONTH_UNIQUE_LEAD'
        else a.metodo_match
      end
    ) as metodo_match
  from attrs a
  group by 1,2,3,4,5,6
),
rows as (
  select
    g.numero_limpio as telefono,
    right(g.numero_limpio,4) as telefono_ult4,
    coalesce(nullif(ci.cliente,''),'SIN NOMBRE') as cliente,
    g.tipo_atribucion,
    g.lead_id,
    g.lead_fecha,
    g.lead_tratamiento as campana,
    g.lead_anuncio as anuncio,
    ph.prior_lead_date,
    ph.prior_campaign,
    ph.prior_ad,
    fs.first_sale_date,
    fl.first_lead_date,
    g.llamadas_vinculadas,
    g.citas_vinculadas,
    g.confidence,
    g.metodo_match,
    g.operaciones,
    g.facturacion,
    case
      when g.llamadas_vinculadas>0 and g.citas_vinculadas>0 then 'LEAD_CALL_APPOINTMENT'
      when g.llamadas_vinculadas>0 then 'LEAD_CALL'
      when g.citas_vinculadas>0 then 'LEAD_APPOINTMENT'
      when g.confidence>=80 then 'STRONG_INFERRED'
      else 'INFERRED'
    end as lineage_strength,
    case
      when ph.prior_lead_date is not null then 'PRIOR_LEAD'
      when fs.first_sale_date is not null and fs.first_sale_date<g.lead_fecha then 'PRIOR_CLIENT'
      when fl.first_lead_date is not null and fl.first_lead_date<g.lead_fecha then 'PRIOR_LEAD'
      else 'NEW'
    end as prior_origin_type
  from grp g
  left join lateral (
    select
      trim(concat_ws(' ',
        nullif(trim(v.nombres),''),
        nullif(trim(v.apellidos),'')
      )) as cliente
    from public.aos_ventas v
    where v.numero_limpio=g.numero_limpio
    order by
      case when coalesce(trim(v.nombres),'')<>'' or coalesce(trim(v.apellidos),'')<>'' then 0 else 1 end,
      v.fecha desc,
      v.created_at desc nulls last
    limit 1
  ) ci on true
  left join lateral (
    select
      l.fecha as prior_lead_date,
      l.tratamiento as prior_campaign,
      l.anuncio as prior_ad
    from public.aos_leads l
    where l.numero_limpio=g.numero_limpio
      and l.fecha<g.lead_fecha
    order by l.fecha desc,l.created_at desc nulls last,l.id desc
    limit 1
  ) ph on true
  left join lateral (
    select min(v.fecha) as first_sale_date
    from public.aos_ventas v
    where v.numero_limpio=g.numero_limpio
  ) fs on true
  left join lateral (
    select min(l.fecha) as first_lead_date
    from public.aos_leads l
    where l.numero_limpio=g.numero_limpio
  ) fl on true
)
select case
  when not exists(select 1 from bounds) then
    jsonb_build_object('ok',false,'error','INVALID_PERIOD','rows','[]'::jsonb)
  when not exists(select 1 from authorized) then
    jsonb_build_object('ok',false,'error','MARKETING_ADMIN_2FA_REQUIRED','rows','[]'::jsonb)
  else jsonb_build_object(
    'ok',true,
    'version','MKT-V4.3-UI',
    'rows',coalesce((select jsonb_agg(to_jsonb(r) order by r.facturacion desc,r.lead_id) from rows r),'[]'::jsonb)
  )
end
$function$;

revoke all on function public.aos_marketing_lineage_admin_v43(text,integer,integer) from public;
grant execute on function public.aos_marketing_lineage_admin_v43(text,integer,integer)
  to anon,authenticated,service_role;

comment on function public.aos_marketing_lineage_admin_v43(text,integer,integer)
is 'Admin+2FA monthly Marketing lineage. Full phone/name plus prior lead/client history; read-only. Public V4.3 map remains masked.';

select pg_notify('pgrst','reload schema');
