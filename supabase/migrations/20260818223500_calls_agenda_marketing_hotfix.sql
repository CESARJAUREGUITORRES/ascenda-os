-- ASCENDA OS — Calls / Agenda / Marketing Hotfix — 2026-08-18
-- Server-side source-of-truth protections for manual agenda, duplicate conversions,
-- explicit Marketing/Organic acquisition and late-loaded lead reconciliation.

create or replace function public.aos_hotfix_call_guard_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_num text;
  v_call_ts timestamptz;
  v_eff_trat text;
  v_prior_count integer := 0;
  v_match_count integer := 0;
  v_any_leads integer := 0;
  v_lead_id bigint;
  v_lead_trat text;
  v_lead_anuncio text;
begin
  v_num := regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
  new.numero_limpio := v_num;
  if upper(trim(coalesce(new.estado,''))) <> 'CITA CONFIRMADA' or v_num='' then return new; end if;

  if exists(
    select 1 from public.aos_llamadas l
    where l.numero_limpio=v_num
      and l.fecha=coalesce(new.fecha,current_date)
      and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,''))
      and upper(coalesce(l.estado,''))='CITA CONFIRMADA'
  ) then
    new.estado := 'SEGUIMIENTO';
    new.sub_estado := 'CITA YA EXISTENTE';
    new.origen := coalesce(nullif(new.origen,''),'FOLLOWUP_EXISTING_CITA');
    new.observacion := trim(concat_ws(' | ',nullif(new.observacion,''),'No suma nueva conversión: ya existía CITA CONFIRMADA para este número/asesor en el día.'));
    return new;
  end if;

  v_call_ts := public.aos_llamada_event_ts(coalesce(new.fecha,current_date),new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);
  v_eff_trat := case when upper(coalesce(new.tratamiento,''))='ORGANICO' then coalesce(nullif(new.anuncio,''),new.tratamiento,'') else coalesce(new.tratamiento,'') end;

  select count(*) into v_prior_count
  from public.aos_marketing_touchpoints_v2(null,null) t
  where t.numero_limpio=v_num
    and not t.es_duplicado_tecnico_probable
    and t.lead_ts<=v_call_ts;

  if v_prior_count=1 then
    select t.lead_id,t.tratamiento,t.anuncio
    into v_lead_id,v_lead_trat,v_lead_anuncio
    from public.aos_marketing_touchpoints_v2(null,null) t
    where t.numero_limpio=v_num
      and not t.es_duplicado_tecnico_probable
      and t.lead_ts<=v_call_ts
    order by t.lead_ts desc,t.lead_id desc
    limit 1;
  elsif v_prior_count>1 and nullif(trim(v_eff_trat),'') is not null then
    select count(*) into v_match_count
    from public.aos_marketing_touchpoints_v2(null,null) t
    where t.numero_limpio=v_num
      and not t.es_duplicado_tecnico_probable
      and t.lead_ts<=v_call_ts
      and regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(v_eff_trat),'[^A-Z0-9]+','','g');
    if v_match_count=1 then
      select t.lead_id,t.tratamiento,t.anuncio
      into v_lead_id,v_lead_trat,v_lead_anuncio
      from public.aos_marketing_touchpoints_v2(null,null) t
      where t.numero_limpio=v_num
        and not t.es_duplicado_tecnico_probable
        and t.lead_ts<=v_call_ts
        and regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(v_eff_trat),'[^A-Z0-9]+','','g')
      order by t.lead_ts desc,t.lead_id desc
      limit 1;
    end if;
  end if;

  if v_lead_id is not null then
    new.lead_id_origen := v_lead_id;
    new.origen := 'MARKETING';
    new.anuncio := coalesce(nullif(new.anuncio,''),v_lead_anuncio);
    if nullif(trim(coalesce(new.tratamiento,'')),'') is null or upper(coalesce(new.tratamiento,''))='ORGANICO' then
      new.tratamiento:=v_lead_trat;
    end if;
  else
    select count(*) into v_any_leads from public.aos_leads l where l.numero_limpio=v_num;
    if v_any_leads=0 then
      new.origen := 'ORGANICO';
      if upper(coalesce(new.tratamiento,''))<>'ORGANICO' then
        new.anuncio := coalesce(nullif(new.anuncio,''),nullif(new.tratamiento,''));
        new.tratamiento := 'ORGANICO';
      end if;
    else
      new.origen := coalesce(nullif(new.origen,''),'MARKETING_UNRESOLVED');
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_aos_hotfix_call_guard_v1 on public.aos_llamadas;
create trigger trg_aos_hotfix_call_guard_v1
before insert on public.aos_llamadas
for each row execute function public.aos_hotfix_call_guard_v1();

create or replace function public.aos_hotfix_agenda_dedupe_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_num text;
  v_ts timestamptz;
begin
  v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
  new.numero_limpio:=v_num;
  v_ts:=coalesce(new.ts_creado,now());
  if v_num<>'' and exists(
    select 1 from public.aos_agenda_citas a
    where a.numero_limpio=v_num
      and upper(coalesce(a.asesor,''))=upper(coalesce(new.asesor,''))
      and a.fecha_cita=new.fecha_cita
      and left(coalesce(a.hora_cita,''),5)=left(coalesce(new.hora_cita,''),5)
      and regexp_replace(upper(coalesce(a.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(coalesce(new.tratamiento,'')),'[^A-Z0-9]+','','g')
      and upper(coalesce(a.estado_cita,''))<>'CANCELADA'
      and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-v_ts)))<=30
  ) then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_aos_hotfix_agenda_dedupe_v1 on public.aos_agenda_citas;
create trigger trg_aos_hotfix_agenda_dedupe_v1
before insert on public.aos_agenda_citas
for each row execute function public.aos_hotfix_agenda_dedupe_v1();

create or replace function public.aos_hotfix_reconcile_late_lead_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_num text;
  v_lead_ts timestamptz;
  v_same_day integer;
begin
  v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.celular,''),'[^0-9]','','g');
  if v_num='' or new.fecha is null then return new; end if;
  select count(*) into v_same_day
  from public.aos_leads l
  where l.numero_limpio=v_num and l.fecha=new.fecha;
  if v_same_day<>1 then return new; end if;

  v_lead_ts:=public.aos_lead_event_ts(new.fecha,new.hora_ingreso,new.created_at);
  update public.aos_llamadas ll
  set lead_id_origen=new.id,
      origen='MARKETING',
      tratamiento=coalesce(nullif(new.tratamiento,''),ll.tratamiento),
      anuncio=coalesce(nullif(new.anuncio,''),ll.anuncio)
  where ll.numero_limpio=v_num
    and ll.fecha=new.fecha
    and ll.lead_id_origen is null
    and upper(coalesce(ll.estado,''))='CITA CONFIRMADA'
    and public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)<v_lead_ts
    and exists(
      select 1 from public.aos_agenda_citas a
      where a.numero_limpio=ll.numero_limpio
        and upper(coalesce(a.asesor,''))=upper(coalesce(ll.asesor,''))
        and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log))))<=600
        and (
          nullif(trim(coalesce(new.tratamiento,'')),'') is null
          or regexp_replace(upper(new.tratamiento),'[^A-Z0-9]+','','g')=regexp_replace(upper(coalesce(case when upper(coalesce(ll.tratamiento,''))='ORGANICO' then nullif(ll.anuncio,'') else nullif(ll.tratamiento,'') end,a.tratamiento,'')),'[^A-Z0-9]+','','g')
        )
    );
  return new;
end;
$$;

drop trigger if exists trg_aos_hotfix_reconcile_late_lead_v1 on public.aos_leads;
create trigger trg_aos_hotfix_reconcile_late_lead_v1
after insert on public.aos_leads
for each row execute function public.aos_hotfix_reconcile_late_lead_v1();

create or replace function public.aos_hotfix_manual_agenda_cleanup_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_call_ts timestamptz;
  v_agenda_ts timestamptz;
  v_num text;
begin
  if tg_table_name='aos_agenda_citas' then
    if upper(coalesce(new.origen_cita,''))<>'CITA_MANUAL' then return new; end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
    v_agenda_ts:=coalesce(new.ts_creado,now());
    delete from public.aos_llamadas l
    where l.numero_limpio=v_num
      and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,''))
      and (
        upper(coalesce(l.estado,''))='CITA CONFIRMADA'
        or (upper(coalesce(l.estado,''))='SEGUIMIENTO' and upper(coalesce(l.sub_estado,''))='CITA YA EXISTENTE')
      )
      and abs(extract(epoch from(public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)-v_agenda_ts)))<=10;
    return new;
  end if;

  if tg_table_name='aos_llamadas' then
    if not (
      upper(coalesce(new.estado,''))='CITA CONFIRMADA'
      or (upper(coalesce(new.estado,''))='SEGUIMIENTO' and upper(coalesce(new.sub_estado,''))='CITA YA EXISTENTE')
    ) then return new; end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
    v_call_ts:=public.aos_llamada_event_ts(new.fecha,new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);
    if exists(
      select 1 from public.aos_agenda_citas a
      where a.numero_limpio=v_num
        and upper(coalesce(a.asesor,''))=upper(coalesce(new.asesor,''))
        and upper(coalesce(a.origen_cita,''))='CITA_MANUAL'
        and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-v_call_ts)))<=10
    ) then
      delete from public.aos_llamadas where id=new.id;
    end if;
    return new;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_aos_hotfix_manual_agenda_cleanup_agenda_v1 on public.aos_agenda_citas;
create trigger trg_aos_hotfix_manual_agenda_cleanup_agenda_v1
after insert on public.aos_agenda_citas
for each row execute function public.aos_hotfix_manual_agenda_cleanup_v1();

drop trigger if exists trg_aos_hotfix_manual_agenda_cleanup_call_v1 on public.aos_llamadas;
create trigger trg_aos_hotfix_manual_agenda_cleanup_call_v1
after insert on public.aos_llamadas
for each row execute function public.aos_hotfix_manual_agenda_cleanup_v1();

-- Back up and remove only proven technical/fabricated duplicate conversion rows.
with conf as (
  select l.id,l.numero_limpio,l.asesor,l.fecha,l.tratamiento,
         public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log) call_ts,
         lag(l.id) over(partition by l.numero_limpio,upper(coalesce(l.asesor,'')),l.fecha order by public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log),l.id) prev_id,
         lag(public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)) over(partition by l.numero_limpio,upper(coalesce(l.asesor,'')),l.fecha order by public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log),l.id) prev_ts,
         lag(l.tratamiento) over(partition by l.numero_limpio,upper(coalesce(l.asesor,'')),l.fecha order by public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log),l.id) prev_trat
  from public.aos_llamadas l
  where upper(coalesce(l.estado,''))='CITA CONFIRMADA' and coalesce(l.numero_limpio,'')<>''
), dups as (
  select c.id
  from conf c
  where c.prev_id is not null
    and extract(epoch from(c.call_ts-c.prev_ts)) between 0 and 5
    and regexp_replace(upper(coalesce(c.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(coalesce(c.prev_trat,'')),'[^A-Z0-9]+','','g')
    and exists(
      select 1 from public.aos_agenda_citas a
      where a.numero_limpio=c.numero_limpio
        and upper(coalesce(a.asesor,''))=upper(coalesce(c.asesor,''))
        and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-c.call_ts)))<=10
        and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-c.prev_ts)))<=10
    )
), rm as (
  select id from dups
  union
  select 37024 where exists(
    select 1 from public.aos_llamadas x
    where x.id=37024 and x.numero_limpio='957535568' and upper(x.asesor)='MIREYA' and x.fecha=date '2026-08-18'
  )
), audit_ins as (
  insert into public.aos_log_auditoria(timestamp_reg,ts,asesor,accion,referencia,detalle,tabla,usuario,registro_id,datos_old,metadata)
  select now(),now(),'SYSTEM','HOTFIX_DELETE_DUPLICATE_CALL','HOTFIX-CALLS-AGENDA-MARKETING-20260818',
         'Proven technical/fabricated CITA CONFIRMADA duplicate removed after full-row backup',
         'aos_llamadas','hotfix',l.id::text,to_jsonb(l),
         jsonb_build_object('hotfix','HOTFIX-CALLS-AGENDA-MARKETING-20260818','reason','duplicate_or_recreated_agenda_without_new_call')
  from public.aos_llamadas l join rm on rm.id=l.id
  returning 1
)
delete from public.aos_llamadas l using rm where l.id=rm.id;

-- Deterministic same-day late-uploaded Marketing lead reconciliation.
with calls as (
  select ll.id,ll.numero_limpio,ll.fecha,ll.asesor,ll.tratamiento,
         public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) call_ts
  from public.aos_llamadas ll
  where upper(coalesce(ll.estado,''))='CITA CONFIRMADA'
    and ll.lead_id_origen is null
    and coalesce(ll.numero_limpio,'')<>''
), ca as (
  select c.id call_id,a.id cita_id,a.tratamiento cita_trat,
         row_number() over(partition by c.id order by abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-c.call_ts))),a.id) rn
  from calls c
  join public.aos_agenda_citas a
    on a.numero_limpio=c.numero_limpio
   and upper(coalesce(a.asesor,''))=upper(coalesce(c.asesor,''))
   and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-c.call_ts)))<=600
), cb as (
  select c.*,ca.cita_id,coalesce(nullif(trim(c.tratamiento),''),ca.cita_trat,'') eff_trat
  from calls c join ca on ca.call_id=c.id and ca.rn=1
), tp as materialized(
  select * from public.aos_marketing_touchpoints_v2(null,null)
  where not es_duplicado_tecnico_probable
), s as (
  select cb.*,
         count(tp.lead_id) filter(where tp.lead_ts<=cb.call_ts) n_prior,
         count(tp.lead_id) filter(where tp.fecha=cb.fecha and tp.lead_ts>cb.call_ts) n_late,
         count(tp.lead_id) filter(
           where tp.fecha=cb.fecha and tp.lead_ts>cb.call_ts
             and regexp_replace(upper(coalesce(tp.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(coalesce(cb.eff_trat,'')),'[^A-Z0-9]+','','g')
             and cb.eff_trat<>''
         ) n_late_trat
  from cb left join tp on tp.numero_limpio=cb.numero_limpio
  group by cb.id,cb.numero_limpio,cb.fecha,cb.asesor,cb.tratamiento,cb.call_ts,cb.cita_id,cb.eff_trat
), late as (
  select s.id,
         (select t.lead_id from tp t where t.numero_limpio=s.numero_limpio and t.fecha=s.fecha and t.lead_ts>s.call_ts order by t.lead_ts,t.lead_id limit 1) lead_id
  from s
  where n_prior=0 and n_late=1 and (n_late_trat=1 or eff_trat='')
)
update public.aos_llamadas l
set lead_id_origen=late.lead_id,
    origen='MARKETING',
    tratamiento=coalesce(nullif(ld.tratamiento,''),l.tratamiento),
    anuncio=coalesce(nullif(ld.anuncio,''),l.anuncio)
from late join public.aos_leads ld on ld.id=late.lead_id
where l.id=late.id and late.lead_id is not null;

-- Explicitly validated Mireya paid conversions.
update public.aos_llamadas l
set lead_id_origen=v.lead_id,
    origen='MARKETING',
    tratamiento=coalesce(nullif(ld.tratamiento,''),l.tratamiento),
    anuncio=coalesce(nullif(ld.anuncio,''),l.anuncio)
from (values
  (36964::bigint,5630::bigint),
  (36948::bigint,5644::bigint),
  (37020::bigint,5655::bigint)
) v(call_id,lead_id)
join public.aos_leads ld on ld.id=v.lead_id
where l.id=v.call_id;

-- Explicitly validated Organic conversion: preserve real treatment as acquisition detail.
update public.aos_llamadas
set tratamiento='ORGANICO',
    anuncio='CRIOLIPOLISIS',
    origen='ORGANICO',
    lead_id_origen=null
where id=36968
  and numero_limpio='982942401'
  and upper(asesor)='MIREYA';

update public.aos_agenda_citas
set etiqueta_campana='ORGANICO'
where id='a949d259-f8ca-4618-bd1f-c25cb458f402'
  and numero_limpio='982942401';

-- Marketing activity list: cohort leads + prior-period paid leads converted in period + Organic.
create or replace function public.aos_marketing_leads_detalle(p_fecha_desde date default null::date, p_fecha_hasta date default null::date)
returns table(lead_id bigint, fecha date, hora_ingreso timestamp with time zone, celular text, numero_limpio text, tratamiento text, anuncio text, preguntas text, llamadas_total bigint, ultima_llamada timestamp with time zone, ultimo_estado text, ultimo_asesor text, citas_total bigint, proxima_cita_fecha date, proxima_cita_estado text, ventas_total bigint, monto_facturado numeric, estado_lead text)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_desde date;
  v_hasta date;
begin
  v_desde:=coalesce(p_fecha_desde,date_trunc('month',current_date)::date);
  v_hasta:=coalesce(p_fecha_hasta,current_date);
  return query
  with cohort as (
    select l.id l_id,l.fecha l_fecha,l.hora_ingreso l_hora,l.celular l_celular,l.numero_limpio l_num,l.tratamiento l_trat,l.anuncio l_anuncio,l.preguntas l_preg
    from public.aos_leads l
    where l.fecha between v_desde and v_hasta and coalesce(l.numero_limpio,'')<>''
  ), paid_activity as (
    select ll.lead_id_origen l_id,max(ll.fecha) activity_date,
           max(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)) activity_ts
    from public.aos_llamadas ll
    where ll.fecha between v_desde and v_hasta
      and ll.lead_id_origen is not null
      and upper(coalesce(ll.estado,''))='CITA CONFIRMADA'
    group by ll.lead_id_origen
  ), extra_paid as (
    select l.id l_id,pa.activity_date l_fecha,pa.activity_ts l_hora,l.celular l_celular,l.numero_limpio l_num,l.tratamiento l_trat,l.anuncio l_anuncio,l.preguntas l_preg
    from paid_activity pa join public.aos_leads l on l.id=pa.l_id
    where not exists(select 1 from cohort c where c.l_num=l.numero_limpio)
  ), organic as (
    select distinct on (ll.numero_limpio)
      (-ll.id)::bigint l_id,ll.fecha l_fecha,
      public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) l_hora,
      ll.numero_limpio l_celular,ll.numero_limpio l_num,
      'ORGANICO'::text l_trat,
      coalesce(nullif(ll.anuncio,''),'SIN TRATAMIENTO')::text l_anuncio,
      null::text l_preg
    from public.aos_llamadas ll
    where ll.fecha between v_desde and v_hasta
      and upper(coalesce(ll.estado,''))='CITA CONFIRMADA'
      and upper(coalesce(ll.origen,''))='ORGANICO'
      and coalesce(ll.numero_limpio,'')<>''
    order by ll.numero_limpio,public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) desc,ll.id desc
  ), recs as (
    select * from cohort
    union all select * from extra_paid
    union all select * from organic
  ), nums as (
    select distinct l_num from recs
  ), llamadas_agg as (
    select ll.numero_limpio n,
           count(*)::bigint total_llam,
           max(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)) ultima_ts,
           (array_agg(ll.estado order by public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc))[1] ult_estado,
           (array_agg(ll.asesor order by public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc))[1] ult_asesor
    from public.aos_llamadas ll
    where ll.fecha between v_desde and v_hasta
      and ll.numero_limpio in(select l_num from nums)
    group by ll.numero_limpio
  ), citas_agg as (
    select a.numero_limpio n,
           count(distinct concat_ws('|',a.fecha_cita::text,left(coalesce(a.hora_cita,''),5),upper(coalesce(a.tratamiento,'')),upper(coalesce(a.sede,''))))::bigint total_citas,
           min(a.fecha_cita) filter(where a.fecha_cita>=current_date) prox_fecha,
           (array_agg(a.estado_cita order by a.fecha_cita desc,coalesce(a.ts_creado,a.fecha_cita::timestamptz) desc))[1] prox_estado
    from public.aos_agenda_citas a
    where coalesce((a.ts_creado at time zone 'America/Lima')::date,a.fecha_cita) between v_desde and v_hasta
      and upper(coalesce(a.estado_cita,''))<>'CANCELADA'
      and a.numero_limpio in(select l_num from nums)
    group by a.numero_limpio
  ), ventas_agg as (
    select v.numero_limpio n,count(*)::bigint total_ventas,
           coalesce(sum(coalesce(v.monto::numeric,0)),0)::numeric monto_total
    from public.aos_ventas v
    where v.fecha between v_desde and v_hasta
      and v.numero_limpio in(select l_num from nums)
    group by v.numero_limpio
  )
  select r.l_id::bigint,r.l_fecha,r.l_hora,r.l_celular,r.l_num,r.l_trat,r.l_anuncio,r.l_preg,
         coalesce(la.total_llam,0)::bigint,la.ultima_ts,la.ult_estado,la.ult_asesor,
         coalesce(ca.total_citas,0)::bigint,ca.prox_fecha,ca.prox_estado,
         coalesce(va.total_ventas,0)::bigint,coalesce(va.monto_total,0)::numeric,
         case when coalesce(va.total_ventas,0)>0 then 'VENDIDO'
              when coalesce(ca.total_citas,0)>0 then 'CON CITA'
              when coalesce(la.total_llam,0)>0 then 'EN GESTION'
              else 'SIN CONTACTO' end::text
  from recs r
  left join llamadas_agg la on la.n=r.l_num
  left join citas_agg ca on ca.n=r.l_num
  left join ventas_agg va on va.n=r.l_num
  order by r.l_fecha desc,r.l_hora desc nulls last,r.l_id desc;
end;
$$;

-- Extend V2 call->appointment chain only when explicit linked-call evidence proves a manual-origin appointment belongs to Call Center.
create or replace function public.aos_marketing_call_cita_match_v2(p_desde date default null::date, p_hasta date default null::date)
returns table(cita_id text, numero_limpio text, asesor text, cita_ts timestamp with time zone, llamada_id bigint, llamada_ts timestamp with time zone, diferencia_segundos numeric, candidatos_10m bigint, metodo_match text, confidence integer)
language sql
stable
as $$
with citas as (
  select c.id,c.numero_limpio,c.asesor,coalesce(c.ts_creado,c.fecha_cita::timestamptz) cita_ts
  from public.aos_agenda_citas c
  where (
      upper(coalesce(c.origen_cita,''))='CALL_CENTER'
      or exists(
        select 1 from public.aos_llamadas lx
        where lx.numero_limpio=c.numero_limpio
          and upper(coalesce(lx.asesor,''))=upper(coalesce(c.asesor,''))
          and upper(coalesce(lx.estado,''))='CITA CONFIRMADA'
          and lx.lead_id_origen is not null
          and abs(extract(epoch from(public.aos_llamada_event_ts(lx.fecha,lx.hora_llamada,lx.created_at,lx.ult_ts,lx.ts_log)-coalesce(c.ts_creado,c.fecha_cita::timestamptz))))<=600
      )
    )
    and c.numero_limpio is not null and c.numero_limpio<>''
    and (p_desde is null or c.fecha_cita>=p_desde)
    and (p_hasta is null or c.fecha_cita<=p_hasta)
), candidates as (
  select c.id cita_id,c.numero_limpio,c.asesor,c.cita_ts,ll.id llamada_id,
         public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) llamada_ts,
         abs(extract(epoch from(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts)))::numeric diferencia_segundos,
         count(*) over(partition by c.id) candidatos_10m,
         row_number() over(partition by c.id order by abs(extract(epoch from(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts))),ll.id desc) rn
  from citas c
  join public.aos_llamadas ll
    on ll.numero_limpio=c.numero_limpio
   and upper(coalesce(ll.asesor,''))=upper(coalesce(c.asesor,''))
   and upper(coalesce(ll.estado,''))='CITA CONFIRMADA'
   and abs(extract(epoch from(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts)))<=600
), best as (
  select * from candidates where rn=1
)
select c.id::text,c.numero_limpio,c.asesor,c.cita_ts,b.llamada_id,b.llamada_ts,b.diferencia_segundos,
       coalesce(b.candidatos_10m,0)::bigint,
       case when b.llamada_id is null then 'SIN_MATCH'
            when b.candidatos_10m=1 then 'CALL_CITA_UNICO_10M'
            else 'CALL_CITA_AMBIGUO_10M' end,
       case when b.llamada_id is null then 0
            when b.candidatos_10m=1 then 95
            else 40 end
from citas c
left join best b on b.cita_id=c.id
order by c.cita_ts,c.id;
$$;

-- V2 detail: explicit lead_id takes precedence and co-temporal linked call can prove the appointment.
create or replace function public.aos_marketing_leads_detalle_v2(p_fecha_desde date default null::date, p_fecha_hasta date default null::date)
returns table(lead_id bigint, fecha date, hora_ingreso timestamp with time zone, celular text, numero_limpio text, tratamiento text, anuncio text, preguntas text, llamadas_total bigint, ultima_llamada timestamp with time zone, ultimo_estado text, ultimo_asesor text, citas_total bigint, proxima_cita_fecha date, proxima_cita_estado text, ventas_total bigint, monto_facturado numeric, estado_lead text)
language sql
stable
as $$
with params as (
  select coalesce(p_fecha_desde,date_trunc('month',current_date)::date) d,
         coalesce(p_fecha_hasta,current_date) h
), lead_timeline as (
  select l.*,
         public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at) lead_ts,
         lead(public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at)) over(partition by l.numero_limpio order by public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at),l.id) next_lead_ts
  from public.aos_leads l
  where l.numero_limpio is not null and l.numero_limpio<>''
), lp as (
  select lt.* from lead_timeline lt,params p where lt.fecha between p.d and p.h
)
select lp.id::bigint,lp.fecha,lp.hora_ingreso,lp.celular,lp.numero_limpio,lp.tratamiento,lp.anuncio,lp.preguntas,
       coalesce(la.total_llam,0)::bigint,la.ultima_ts,la.ult_estado,la.ult_asesor,
       coalesce(ca.total_citas,0)::bigint,ca.prox_fecha,ca.prox_estado,
       coalesce(va.total_ventas,0)::bigint,coalesce(va.monto_total,0)::numeric,
       case when coalesce(va.total_ventas,0)>0 then 'VENDIDO'
            when coalesce(ca.total_citas,0)>0 then 'CON CITA'
            when coalesce(la.total_llam,0)>0 then 'EN GESTION'
            else 'SIN CONTACTO' end::text
from lp
left join lateral (
  select count(*) total_llam,
         max(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)) ultima_ts,
         (array_agg(ll.estado order by public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc))[1] ult_estado,
         (array_agg(ll.asesor order by public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc))[1] ult_asesor
  from public.aos_llamadas ll
  where ll.numero_limpio=lp.numero_limpio
    and (
      ll.lead_id_origen=lp.id
      or (
        ll.lead_id_origen is null
        and public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)>=lp.lead_ts
        and (lp.next_lead_ts is null or public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)<lp.next_lead_ts)
      )
    )
) la on true
left join lateral (
  select count(distinct concat_ws('|',c.fecha_cita::text,left(coalesce(c.hora_cita,''),5),upper(coalesce(c.tratamiento,'')),upper(coalesce(c.sede,'')))) total_citas,
         min(c.fecha_cita) filter(where c.fecha_cita>=current_date) prox_fecha,
         (array_agg(c.estado_cita order by coalesce(c.ts_creado,c.fecha_cita::timestamptz) desc nulls last))[1] prox_estado
  from public.aos_agenda_citas c
  where c.numero_limpio=lp.numero_limpio
    and (
      c.lead_id_origen=lp.id
      or exists(
        select 1 from public.aos_llamadas llx
        where llx.numero_limpio=lp.numero_limpio
          and llx.lead_id_origen=lp.id
          and upper(coalesce(llx.estado,''))='CITA CONFIRMADA'
          and abs(extract(epoch from(public.aos_llamada_event_ts(llx.fecha,llx.hora_llamada,llx.created_at,llx.ult_ts,llx.ts_log)-coalesce(c.ts_creado,c.fecha_cita::timestamptz))))<=600
      )
      or (
        c.lead_id_origen is null
        and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=lp.lead_ts
        and (lp.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<lp.next_lead_ts)
      )
    )
) ca on true
left join lateral (
  select count(*) total_ventas,coalesce(sum(coalesce(v.monto::numeric,0)),0) monto_total
  from public.aos_ventas v
  where v.numero_limpio=lp.numero_limpio
    and v.fecha>=lp.fecha
    and (lp.next_lead_ts is null or v.fecha<lp.next_lead_ts::date)
) va on true
order by lp.fecha desc,lp.hora_ingreso desc nulls last,lp.id desc;
$$;
