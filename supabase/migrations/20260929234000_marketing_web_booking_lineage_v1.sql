-- Marketing Web Booking Lineage V1
-- Additive acquisition traceability for direct bookings from landing pages.
-- Keeps aos_agenda_citas as the canonical booking ledger and does not duplicate leads.

begin;

alter table public.aos_agenda_citas add column if not exists source_landing_id uuid;
alter table public.aos_agenda_citas add column if not exists source_landing_code text;
alter table public.aos_agenda_citas add column if not exists source_platform text;
alter table public.aos_agenda_citas add column if not exists source_ad text;

create table if not exists public.aos_landing_registry (
  id uuid primary key default gen_random_uuid(),
  token text not null unique default replace(gen_random_uuid()::text,'-',''),
  landing_code text not null,
  nombre text not null,
  landing_url text,
  treatment_id uuid,
  tratamiento text,
  plataforma text,
  campaign_code text,
  campaign_name text,
  ad_code text,
  ad_name text,
  booking_token text,
  activo boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists aos_landing_registry_code_uq
  on public.aos_landing_registry ((upper(trim(landing_code))));
create index if not exists aos_landing_registry_campaign_idx
  on public.aos_landing_registry ((upper(coalesce(campaign_code,campaign_name,''))), activo);
create index if not exists aos_landing_registry_platform_idx
  on public.aos_landing_registry ((upper(coalesce(plataforma,''))), activo);

alter table public.aos_landing_registry enable row level security;
revoke all on table public.aos_landing_registry from anon, authenticated;

create table if not exists public.aos_landing_booking_attribution (
  id uuid primary key default gen_random_uuid(),
  agenda_id text not null unique,
  landing_id uuid not null references public.aos_landing_registry(id),
  idempotency_key text,
  numero_limpio text not null,
  source_channel text not null default 'LANDING',
  landing_code text not null,
  landing_name text not null,
  landing_url text,
  plataforma text,
  campaign_code text,
  campaign_name text,
  ad_code text,
  ad_name text,
  treatment_id uuid,
  tratamiento text,
  advisor_code text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term text,
  referrer_url text,
  client_event_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists aos_landing_booking_idempotency_uq
  on public.aos_landing_booking_attribution (landing_id,idempotency_key)
  where idempotency_key is not null and length(trim(idempotency_key))>0;
create index if not exists aos_landing_booking_phone_ts_idx
  on public.aos_landing_booking_attribution (numero_limpio,created_at desc);
create index if not exists aos_landing_booking_campaign_ts_idx
  on public.aos_landing_booking_attribution ((upper(coalesce(campaign_code,campaign_name,''))),created_at desc);
create index if not exists aos_landing_booking_ad_ts_idx
  on public.aos_landing_booking_attribution ((upper(coalesce(ad_code,ad_name,''))),created_at desc);

alter table public.aos_landing_booking_attribution enable row level security;
revoke all on table public.aos_landing_booking_attribution from anon, authenticated;

create table if not exists public.aos_marketing_spend_items (
  id uuid primary key default gen_random_uuid(),
  anio integer not null check (anio between 2020 and 2100),
  mes_num integer not null check (mes_num between 1 and 12),
  plataforma text not null,
  campaign_code text,
  campaign_name text,
  ad_code text,
  ad_name text,
  landing_id uuid references public.aos_landing_registry(id),
  tratamiento text,
  inversion numeric(14,2) not null check (inversion>=0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists aos_marketing_spend_items_grain_uq
  on public.aos_marketing_spend_items (
    anio,mes_num,
    upper(trim(plataforma)),
    upper(trim(coalesce(campaign_code,''))),
    upper(trim(coalesce(ad_code,''))),
    coalesce(landing_id,'00000000-0000-0000-0000-000000000000'::uuid)
  );
create index if not exists aos_marketing_spend_items_period_idx
  on public.aos_marketing_spend_items (anio,mes_num);

alter table public.aos_marketing_spend_items enable row level security;
revoke all on table public.aos_marketing_spend_items from anon, authenticated;

create or replace function public.aos_marketing_web_touch_guard_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
  raise exception 'WEB_BOOKING_ATTRIBUTION_APPEND_ONLY';
end;
$$;

drop trigger if exists trg_aos_landing_booking_append_only on public.aos_landing_booking_attribution;
create trigger trg_aos_landing_booking_append_only
before update or delete on public.aos_landing_booking_attribution
for each row execute function public.aos_marketing_web_touch_guard_v1();

create or replace function public.aos_landing_registry_admin_v1(p_token text)
returns jsonb
language sql
stable
security definer
set search_path=''
as $function$
with actor as (
  select public.aos_app_actor_v3(p_token,'admin-marketing',true) as id
), authorized as (
  select u.id from actor a join public.aos_usuarios u on u.id=a.id
  where coalesce(u.nivel_jerarquia,99)<=2
)
select case when not exists(select 1 from authorized)
  then jsonb_build_object('ok',false,'error','MARKETING_ADMIN_2FA_REQUIRED','rows','[]'::jsonb)
  else jsonb_build_object(
    'ok',true,
    'rows',coalesce((select jsonb_agg(jsonb_build_object(
      'id',r.id,'token',r.token,'landing_code',r.landing_code,'nombre',r.nombre,'landing_url',r.landing_url,
      'treatment_id',r.treatment_id,'tratamiento',r.tratamiento,'plataforma',r.plataforma,
      'campaign_code',r.campaign_code,'campaign_name',r.campaign_name,'ad_code',r.ad_code,'ad_name',r.ad_name,
      'booking_token',r.booking_token,'activo',r.activo,'metadata',r.metadata,'created_at',r.created_at,'updated_at',r.updated_at
    ) order by r.nombre) from public.aos_landing_registry r),'[]'::jsonb)
  ) end
$function$;

create or replace function public.aos_landing_registry_upsert_admin_v1(p_token text,p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare actor uuid; rid uuid; outrow public.aos_landing_registry%rowtype; rotate boolean;
begin
  actor:=public.aos_app_actor_v3(p_token,'admin-marketing',true);
  if not exists(select 1 from public.aos_usuarios u where u.id=actor and coalesce(u.nivel_jerarquia,99)<=2) then
    return jsonb_build_object('ok',false,'error','MARKETING_ADMIN_2FA_REQUIRED');
  end if;
  begin rid:=nullif(p_payload->>'id','')::uuid; exception when others then rid:=null; end;
  rotate:=coalesce((p_payload->>'rotate_token')::boolean,false);
  if coalesce(trim(p_payload->>'landing_code'),'')='' or coalesce(trim(p_payload->>'nombre'),'')='' then
    return jsonb_build_object('ok',false,'error','LANDING_CODE_AND_NAME_REQUIRED');
  end if;
  if rid is null then
    insert into public.aos_landing_registry(
      landing_code,nombre,landing_url,treatment_id,tratamiento,plataforma,campaign_code,campaign_name,ad_code,ad_name,booking_token,activo,metadata,created_by
    ) values(
      upper(trim(p_payload->>'landing_code')),trim(p_payload->>'nombre'),nullif(trim(p_payload->>'landing_url'),''),
      nullif(p_payload->>'treatment_id','')::uuid,nullif(trim(p_payload->>'tratamiento'),''),upper(nullif(trim(p_payload->>'plataforma'),'')),
      nullif(trim(p_payload->>'campaign_code'),''),nullif(trim(p_payload->>'campaign_name'),''),nullif(trim(p_payload->>'ad_code'),''),nullif(trim(p_payload->>'ad_name'),''),
      nullif(trim(p_payload->>'booking_token'),''),coalesce((p_payload->>'activo')::boolean,true),coalesce(p_payload->'metadata','{}'::jsonb),actor
    ) returning * into outrow;
  else
    update public.aos_landing_registry r set
      landing_code=upper(trim(p_payload->>'landing_code')),
      nombre=trim(p_payload->>'nombre'),
      landing_url=nullif(trim(p_payload->>'landing_url'),''),
      treatment_id=nullif(p_payload->>'treatment_id','')::uuid,
      tratamiento=nullif(trim(p_payload->>'tratamiento'),''),
      plataforma=upper(nullif(trim(p_payload->>'plataforma'),'')),
      campaign_code=nullif(trim(p_payload->>'campaign_code'),''),
      campaign_name=nullif(trim(p_payload->>'campaign_name'),''),
      ad_code=nullif(trim(p_payload->>'ad_code'),''),
      ad_name=nullif(trim(p_payload->>'ad_name'),''),
      booking_token=nullif(trim(p_payload->>'booking_token'),''),
      activo=coalesce((p_payload->>'activo')::boolean,r.activo),
      metadata=coalesce(p_payload->'metadata',r.metadata),
      token=case when rotate then replace(gen_random_uuid()::text,'-','') else r.token end,
      updated_at=now()
    where r.id=rid returning * into outrow;
    if not found then return jsonb_build_object('ok',false,'error','LANDING_NOT_FOUND'); end if;
  end if;
  return jsonb_build_object('ok',true,'id',outrow.id,'token',outrow.token,'landing_code',outrow.landing_code,'nombre',outrow.nombre,'activo',outrow.activo);
exception when unique_violation then
  return jsonb_build_object('ok',false,'error','LANDING_CODE_ALREADY_EXISTS');
end;
$$;

create or replace function public.aos_marketing_spend_item_upsert_admin_v1(p_token text,p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare actor uuid; rid uuid; lid uuid; outrow public.aos_marketing_spend_items%rowtype;
begin
  actor:=public.aos_app_actor_v3(p_token,'admin-marketing',true);
  if not exists(select 1 from public.aos_usuarios u where u.id=actor and coalesce(u.nivel_jerarquia,99)<=2) then
    return jsonb_build_object('ok',false,'error','MARKETING_ADMIN_2FA_REQUIRED');
  end if;
  begin rid:=nullif(p_payload->>'id','')::uuid; exception when others then rid:=null; end;
  begin lid:=nullif(p_payload->>'landing_id','')::uuid; exception when others then lid:=null; end;
  if coalesce((p_payload->>'anio')::int,0)<2020 or coalesce((p_payload->>'mes_num')::int,0) not between 1 and 12 or coalesce(trim(p_payload->>'plataforma'),'')='' then
    return jsonb_build_object('ok',false,'error','SPEND_PERIOD_AND_PLATFORM_REQUIRED');
  end if;
  if rid is null then
    insert into public.aos_marketing_spend_items(anio,mes_num,plataforma,campaign_code,campaign_name,ad_code,ad_name,landing_id,tratamiento,inversion,metadata)
    values((p_payload->>'anio')::int,(p_payload->>'mes_num')::int,upper(trim(p_payload->>'plataforma')),nullif(trim(p_payload->>'campaign_code'),''),nullif(trim(p_payload->>'campaign_name'),''),nullif(trim(p_payload->>'ad_code'),''),nullif(trim(p_payload->>'ad_name'),''),lid,nullif(trim(p_payload->>'tratamiento'),''),coalesce((p_payload->>'inversion')::numeric,0),coalesce(p_payload->'metadata','{}'::jsonb))
    returning * into outrow;
  else
    update public.aos_marketing_spend_items s set
      anio=(p_payload->>'anio')::int,mes_num=(p_payload->>'mes_num')::int,plataforma=upper(trim(p_payload->>'plataforma')),
      campaign_code=nullif(trim(p_payload->>'campaign_code'),''),campaign_name=nullif(trim(p_payload->>'campaign_name'),''),
      ad_code=nullif(trim(p_payload->>'ad_code'),''),ad_name=nullif(trim(p_payload->>'ad_name'),''),landing_id=lid,
      tratamiento=nullif(trim(p_payload->>'tratamiento'),''),inversion=coalesce((p_payload->>'inversion')::numeric,0),metadata=coalesce(p_payload->'metadata',s.metadata),updated_at=now()
    where s.id=rid returning * into outrow;
    if not found then return jsonb_build_object('ok',false,'error','SPEND_ITEM_NOT_FOUND'); end if;
  end if;
  return jsonb_build_object('ok',true,'id',outrow.id,'inversion',outrow.inversion);
exception when unique_violation then
  return jsonb_build_object('ok',false,'error','SPEND_GRAIN_ALREADY_EXISTS');
end;
$$;

create or replace function public.aos_agendar_publica_landing_v1(
  p_landing_token text,
  p_idempotency_key text,
  p_nombre text,
  p_apellido text,
  p_telefono text,
  p_treatment_id uuid,
  p_fecha date,
  p_hora text,
  p_sede text,
  p_profesional_id text default null,
  p_dni text default '',
  p_email text default '',
  p_nota text default '',
  p_tipo_cita text default 'CONSULTA NUEVA',
  p_utm_source text default null,
  p_utm_medium text default null,
  p_utm_campaign text default null,
  p_utm_content text default null,
  p_utm_term text default null,
  p_referrer_url text default null,
  p_client_event_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare r public.aos_landing_registry%rowtype; prior record; booked jsonb; aid text; num text; btoken text; canonical_treatment text;
begin
  if coalesce(length(trim(p_landing_token)),0)<20 then return jsonb_build_object('ok',false,'error','LANDING_INVALID'); end if;
  if coalesce(length(trim(p_idempotency_key)),0)>128 then return jsonb_build_object('ok',false,'error','IDEMPOTENCY_KEY_TOO_LONG'); end if;
  perform pg_advisory_xact_lock(hashtextextended('landing-booking:'||trim(p_landing_token)||':'||coalesce(nullif(trim(p_idempotency_key),''),regexp_replace(coalesce(p_telefono,''),'[^0-9]','','g')||':'||p_fecha::text||':'||p_hora),0));
  select * into r from public.aos_landing_registry where token=trim(p_landing_token) and activo=true limit 1;
  if not found then return jsonb_build_object('ok',false,'error','LANDING_INVALID'); end if;
  if r.treatment_id is not null and r.treatment_id<>p_treatment_id then return jsonb_build_object('ok',false,'error','LANDING_TREATMENT_MISMATCH'); end if;
  if coalesce(trim(p_idempotency_key),'')<>'' then
    select l.agenda_id,a.fecha_cita,a.hora_cita,a.sede,a.tratamiento into prior
    from public.aos_landing_booking_attribution l
    left join public.aos_agenda_citas a on a.id=l.agenda_id
    where l.landing_id=r.id and l.idempotency_key=trim(p_idempotency_key)
    limit 1;
    if found then
      return jsonb_build_object('ok',true,'status','BOOKED','idempotent_replay',true,'agenda_id',prior.agenda_id,'fecha',prior.fecha_cita,'hora',prior.hora_cita,'sede',prior.sede,'treatment',prior.tratamiento,'source_channel','LANDING','landing_code',r.landing_code,'landing_name',r.nombre,'platform',r.plataforma,'campaign_code',r.campaign_code,'campaign_name',r.campaign_name,'ad_code',r.ad_code,'ad_name',r.ad_name);
    end if;
  end if;
  btoken:=coalesce(nullif(trim(r.booking_token),''),'__permanent__');
  booked:=public.aos_agendar_publica_v2(btoken,p_nombre,p_apellido,p_telefono,p_treatment_id,p_fecha,p_hora,p_sede,p_profesional_id,p_dni,p_email,p_nota,p_tipo_cita);
  if coalesce((booked->>'ok')::boolean,false) is not true then return booked; end if;
  aid:=booked->>'agenda_id';
  num:=regexp_replace(coalesce(p_telefono,''),'[^0-9]','','g');
  canonical_treatment:=coalesce(nullif(booked->>'treatment',''),r.tratamiento);
  update public.aos_agenda_citas set
    source_channel='LANDING',
    source_campaign=coalesce(nullif(r.campaign_code,''),nullif(r.campaign_name,''),source_campaign),
    source_landing_id=r.id,
    source_landing_code=r.landing_code,
    source_platform=r.plataforma,
    source_ad=coalesce(nullif(r.ad_code,''),nullif(r.ad_name,''))
  where id=aid;
  insert into public.aos_landing_booking_attribution(
    agenda_id,landing_id,idempotency_key,numero_limpio,landing_code,landing_name,landing_url,plataforma,campaign_code,campaign_name,ad_code,ad_name,treatment_id,tratamiento,advisor_code,
    utm_source,utm_medium,utm_campaign,utm_content,utm_term,referrer_url,client_event_id,metadata
  ) values(
    aid,r.id,nullif(trim(p_idempotency_key),''),num,r.landing_code,r.nombre,r.landing_url,r.plataforma,r.campaign_code,r.campaign_name,r.ad_code,r.ad_name,p_treatment_id,canonical_treatment,booked->>'advisor_code',
    nullif(trim(p_utm_source),''),nullif(trim(p_utm_medium),''),nullif(trim(p_utm_campaign),''),nullif(trim(p_utm_content),''),nullif(trim(p_utm_term),''),nullif(trim(p_referrer_url),''),nullif(trim(p_client_event_id),''),
    jsonb_build_object('booking_source','LANDING_V1')
  ) on conflict (agenda_id) do nothing;
  return booked || jsonb_build_object(
    'source_channel','LANDING','landing_code',r.landing_code,'landing_name',r.nombre,'platform',r.plataforma,
    'campaign_code',r.campaign_code,'campaign_name',r.campaign_name,'ad_code',r.ad_code,'ad_name',r.ad_name
  );
end;
$$;

create or replace function public.aos_marketing_web_bookings_admin_v1(
  p_token text,
  p_desde date,
  p_hasta date,
  p_filters jsonb default '{}'::jsonb
)
returns jsonb
language sql
stable
security definer
set search_path=''
set statement_timeout to '8s'
as $function$
with actor as (
  select public.aos_app_actor_v3(p_token,'admin-marketing',true) as id
), authorized as (
  select u.id from actor a join public.aos_usuarios u on u.id=a.id where coalesce(u.nivel_jerarquia,99)<=2
), bounds as (
  select p_desde as d0,p_hasta as d1 where p_desde is not null and p_hasta is not null and p_desde<=p_hasta and p_hasta-p_desde<=366
), sequenced as (
  select l.*,lead(l.created_at) over(partition by l.numero_limpio order by l.created_at,l.id) as next_created_at
  from public.aos_landing_booking_attribution l
), period_rows as (
  select s.*
  from sequenced s,bounds b
  where (s.created_at at time zone 'America/Lima')::date between b.d0 and b.d1
), enriched as (
  select
    s.id,s.agenda_id,s.created_at,s.numero_limpio,s.landing_id,s.landing_code,s.landing_name,s.landing_url,
    s.plataforma,s.campaign_code,s.campaign_name,s.ad_code,s.ad_name,s.treatment_id,s.tratamiento,s.advisor_code,
    s.utm_source,s.utm_medium,s.utm_campaign,s.utm_content,s.utm_term,s.referrer_url,
    a.fecha_cita,a.hora_cita,a.sede,a.estado_cita,a.asesor,a.id_asesor,a.nombre,a.apellido,a.correo,
    coalesce(c.llamadas_total,0)::bigint as llamadas_total,c.ultimo_estado,c.ultimo_asesor,c.ultima_gestion,coalesce(c.contactado,false) as contactado,
    coalesce(v.ventas_total,0)::bigint as ventas_total,coalesce(v.facturacion,0)::numeric as facturacion,v.primera_venta,
    case
      when coalesce(v.ventas_total,0)>0 then 'VENDIDO'
      when upper(coalesce(a.estado_cita,'')) in ('ASISTIO','EFECTIVA') then 'ASISTIO'
      when upper(coalesce(a.estado_cita,''))='NO ASISTIO' then 'NO ASISTIO'
      when upper(coalesce(a.estado_cita,''))='CANCELADA' then 'CANCELADA'
      when coalesce(c.contactado,false) then 'CONTACTADO'
      when coalesce(c.llamadas_total,0)>0 then 'SIN CONTACTO'
      when upper(coalesce(a.estado_cita,''))='REAGENDADA' then 'REAGENDADA'
      else 'AGENDADO'
    end as estado_comercial
  from period_rows s
  left join public.aos_agenda_citas a on a.id=s.agenda_id
  left join lateral (
    select
      count(*)::bigint as llamadas_total,
      (array_agg(upper(coalesce(ll.estado,'')) order by coalesce(ll.ult_ts,ll.ts_log,ll.created_at,(ll.fecha::timestamp at time zone 'America/Lima')) desc nulls last))[1] as ultimo_estado,
      (array_agg(ll.asesor order by coalesce(ll.ult_ts,ll.ts_log,ll.created_at,(ll.fecha::timestamp at time zone 'America/Lima')) desc nulls last))[1] as ultimo_asesor,
      max(coalesce(ll.ult_ts,ll.ts_log,ll.created_at,(ll.fecha::timestamp at time zone 'America/Lima'))) as ultima_gestion,
      bool_or(upper(coalesce(ll.estado,'')) not in ('','SIN CONTACTO','NO CONTESTA')) as contactado
    from public.aos_llamadas ll
    where ll.numero_limpio=s.numero_limpio
      and coalesce(ll.ult_ts,ll.ts_log,ll.created_at,(ll.fecha::timestamp at time zone 'America/Lima'))>=s.created_at-interval '5 minutes'
      and (s.next_created_at is null or coalesce(ll.ult_ts,ll.ts_log,ll.created_at,(ll.fecha::timestamp at time zone 'America/Lima'))<s.next_created_at)
  ) c on true
  left join lateral (
    select count(*)::bigint as ventas_total,sum(coalesce(x.monto,0))::numeric as facturacion,min(x.fecha) as primera_venta
    from public.aos_ventas x
    where x.numero_limpio=s.numero_limpio
      and coalesce(x.created_at,(x.fecha::timestamp at time zone 'America/Lima'))>=s.created_at-interval '5 minutes'
      and (s.next_created_at is null or coalesce(x.created_at,(x.fecha::timestamp at time zone 'America/Lima'))<s.next_created_at)
  ) v on true
), filtered as (
  select e.* from enriched e
  where (coalesce(trim(p_filters->>'platform'),'')='' or upper(coalesce(e.plataforma,''))=upper(trim(p_filters->>'platform')))
    and (coalesce(trim(p_filters->>'campaign'),'')='' or upper(coalesce(nullif(e.campaign_code,''),e.campaign_name,''))=upper(trim(p_filters->>'campaign')))
    and (coalesce(trim(p_filters->>'ad'),'')='' or upper(coalesce(nullif(e.ad_code,''),e.ad_name,''))=upper(trim(p_filters->>'ad')))
    and (coalesce(trim(p_filters->>'landing'),'')='' or upper(coalesce(e.landing_code,''))=upper(trim(p_filters->>'landing')))
    and (coalesce(trim(p_filters->>'status'),'')='' or upper(e.estado_comercial)=upper(trim(p_filters->>'status')))
), spend as (
  select coalesce(sum(s.inversion),0)::numeric as inversion,count(*)::bigint as spend_items
  from public.aos_marketing_spend_items s
  left join public.aos_landing_registry lr on lr.id=s.landing_id,bounds b
  where make_date(s.anio,s.mes_num,1) between date_trunc('month',b.d0)::date and date_trunc('month',b.d1)::date
    and (coalesce(trim(p_filters->>'platform'),'')='' or upper(s.plataforma)=upper(trim(p_filters->>'platform')))
    and (coalesce(trim(p_filters->>'campaign'),'')='' or upper(coalesce(nullif(s.campaign_code,''),s.campaign_name,''))=upper(trim(p_filters->>'campaign')))
    and (coalesce(trim(p_filters->>'ad'),'')='' or upper(coalesce(nullif(s.ad_code,''),s.ad_name,''))=upper(trim(p_filters->>'ad')))
    and (coalesce(trim(p_filters->>'landing'),'')='' or upper(coalesce(lr.landing_code,''))=upper(trim(p_filters->>'landing')))
), metrics as (
  select
    count(*)::bigint as reservas,
    count(*) filter(where f.contactado or f.ventas_total>0)::bigint as contactados,
    count(*) filter(where upper(coalesce(f.estado_cita,'')) in ('ASISTIO','EFECTIVA'))::bigint as asistieron,
    count(*) filter(where f.ventas_total>0)::bigint as clientes,
    coalesce(sum(f.ventas_total),0)::bigint as ventas,
    coalesce(sum(f.facturacion),0)::numeric as facturacion
  from filtered f
), dimensions as (
  select jsonb_build_object(
    'platforms',coalesce((select jsonb_agg(x order by x) from (select distinct plataforma x from period_rows where coalesce(plataforma,'')<>'') q),'[]'::jsonb),
    'campaigns',coalesce((select jsonb_agg(x order by x) from (select distinct coalesce(nullif(campaign_code,''),campaign_name) x from period_rows where coalesce(campaign_code,campaign_name,'')<>'') q),'[]'::jsonb),
    'ads',coalesce((select jsonb_agg(x order by x) from (select distinct coalesce(nullif(ad_code,''),ad_name) x from period_rows where coalesce(ad_code,ad_name,'')<>'') q),'[]'::jsonb),
    'landings',coalesce((select jsonb_agg(x order by x) from (select distinct landing_code x from period_rows where coalesce(landing_code,'')<>'') q),'[]'::jsonb)
  ) as data
)
select case
  when not exists(select 1 from authorized) then jsonb_build_object('ok',false,'error','MARKETING_ADMIN_2FA_REQUIRED','rows','[]'::jsonb)
  when not exists(select 1 from bounds) then jsonb_build_object('ok',false,'error','INVALID_RANGE','rows','[]'::jsonb)
  else jsonb_build_object(
    'ok',true,'version','WEB-BOOKING-LINEAGE-V1','range',jsonb_build_object('desde',p_desde,'hasta',p_hasta),
    'summary',(select jsonb_build_object(
      'reservas',m.reservas,'contactados',m.contactados,'asistieron',m.asistieron,'clientes',m.clientes,'ventas',m.ventas,'facturacion',m.facturacion,
      'inversion',s.inversion,'spend_available',s.spend_items>0,
      'costo_reserva',case when s.spend_items>0 and m.reservas>0 then round(s.inversion/m.reservas,2) else null end,
      'cac',case when s.spend_items>0 and m.clientes>0 then round(s.inversion/m.clientes,2) else null end,
      'roas',case when s.inversion>0 then round(m.facturacion/s.inversion,2) else null end
    ) from metrics m cross join spend s),
    'dimensions',(select data from dimensions),
    'rows_total',(select count(*) from filtered),
    'truncated',(select count(*)>1000 from filtered),
    'rows',coalesce((select jsonb_agg(to_jsonb(z) order by z.created_at desc) from (select * from filtered order by created_at desc limit 1000) z),'[]'::jsonb)
  ) end
$function$;

revoke all on function public.aos_landing_registry_admin_v1(text) from public;
revoke all on function public.aos_landing_registry_upsert_admin_v1(text,jsonb) from public;
revoke all on function public.aos_marketing_spend_item_upsert_admin_v1(text,jsonb) from public;
revoke all on function public.aos_marketing_web_bookings_admin_v1(text,date,date,jsonb) from public;
revoke all on function public.aos_agendar_publica_landing_v1(text,text,text,text,text,uuid,date,text,text,text,text,text,text,text,text,text,text,text,text,text,text) from public;

grant execute on function public.aos_landing_registry_admin_v1(text) to anon,authenticated,service_role;
grant execute on function public.aos_landing_registry_upsert_admin_v1(text,jsonb) to anon,authenticated,service_role;
grant execute on function public.aos_marketing_spend_item_upsert_admin_v1(text,jsonb) to anon,authenticated,service_role;
grant execute on function public.aos_marketing_web_bookings_admin_v1(text,date,date,jsonb) to anon,authenticated,service_role;
grant execute on function public.aos_agendar_publica_landing_v1(text,text,text,text,text,uuid,date,text,text,text,text,text,text,text,text,text,text,text,text,text,text) to anon,authenticated,service_role;

select pg_notify('pgrst','reload schema');
commit;
