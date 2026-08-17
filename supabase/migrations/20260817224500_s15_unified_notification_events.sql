-- ASCENDA S15 — unified business notification events.
-- Extends the existing in-app notification table and reuses AOS_PUSH_V1.

alter table public.aos_notificaciones add column if not exists para_user_id uuid references public.aos_usuarios(id) on delete set null;
alter table public.aos_notificaciones add column if not exists channel text not null default 'SYSTEM';
alter table public.aos_notificaciones add column if not exists event_type text;
alter table public.aos_notificaciones add column if not exists route text;
alter table public.aos_notificaciones add column if not exists entity_id text;
alter table public.aos_notificaciones add column if not exists icon text;
alter table public.aos_notificaciones add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.aos_notificaciones add column if not exists dedupe_key text;
alter table public.aos_notificaciones add column if not exists in_app_enabled boolean not null default true;
alter table public.aos_notificaciones add column if not exists push_enabled boolean not null default false;
alter table public.aos_notificaciones add column if not exists push_after timestamptz;
alter table public.aos_notificaciones add column if not exists push_status text not null default 'SKIPPED';
alter table public.aos_notificaciones add column if not exists push_claimed_at timestamptz;
alter table public.aos_notificaciones add column if not exists push_attempts integer not null default 0;
alter table public.aos_notificaciones add column if not exists updated_at timestamptz not null default now();

create unique index if not exists aos_notificaciones_dedupe_v1_uq
  on public.aos_notificaciones(dedupe_key) where dedupe_key is not null;
create index if not exists aos_notificaciones_recipient_v1_idx
  on public.aos_notificaciones(para_user_id, created_at desc);
create index if not exists aos_notificaciones_push_v1_idx
  on public.aos_notificaciones(push_status, push_after, created_at)
  where push_enabled = true;

create table if not exists public.aos_notification_policies_v1 (
  event_type text primary key,
  channel text not null,
  enabled boolean not null default true,
  in_app_enabled boolean not null default true,
  web_push_enabled boolean not null default true,
  priority text not null default 'NORMAL',
  aggregate_seconds integer not null default 0 check (aggregate_seconds between 0 and 3600),
  icon text,
  route text,
  description text,
  updated_at timestamptz not null default now()
);

insert into public.aos_notification_policies_v1(event_type,channel,in_app_enabled,web_push_enabled,priority,aggregate_seconds,icon,route,description)
values
 ('SALE_ADDED','SALES',true,true,'NORMAL',15,'/icons/channel-sales.svg','/app.html#advisor-commissions','Advisor sale and commission delta'),
 ('ADMIN_SALES_DIGEST','SALES',true,true,'NORMAL',60,'/icons/channel-sales.svg','/app.html#admin-sales','Admin grouped sales activity'),
 ('COMMISSION_ADJUSTED','COMMISSION',true,true,'ALTA',0,'/icons/channel-commission.svg','/app.html#advisor-commissions','Manual commission adjustment'),
 ('APPOINTMENT_CREATED','AGENDA',true,true,'NORMAL',15,'/icons/channel-agenda.svg','/app.html#advisor-citas','Advisor new appointment'),
 ('ADMIN_APPOINTMENT_DIGEST','AGENDA',true,true,'NORMAL',60,'/icons/channel-agenda.svg','/app.html#admin-agenda','Admin grouped new appointments'),
 ('APPOINTMENT_ATTENDED','AGENDA',true,true,'NORMAL',0,'/icons/channel-agenda.svg','/app.html#advisor-citas','Advisor appointment attended'),
 ('APPOINTMENT_NO_SHOW','AGENDA',true,true,'ALTA',0,'/icons/channel-agenda.svg','/app.html#advisor-citas','Advisor appointment no-show'),
 ('APPOINTMENT_CANCELLED','AGENDA',true,true,'ALTA',0,'/icons/channel-agenda.svg','/app.html#advisor-citas','Advisor appointment cancelled'),
 ('APPOINTMENT_RESCHEDULED','AGENDA',true,true,'NORMAL',0,'/icons/channel-agenda.svg','/app.html#advisor-citas','Advisor appointment rescheduled'),
 ('ADMIN_ATTENDED_DIGEST','AGENDA',true,true,'NORMAL',60,'/icons/channel-agenda.svg','/app.html#admin-agenda','Admin grouped attended appointments'),
 ('ADMIN_NO_SHOW_DIGEST','AGENDA',true,true,'ALTA',60,'/icons/channel-agenda.svg','/app.html#admin-agenda','Admin grouped no-shows'),
 ('INTERNAL_CHAT_MESSAGE','CHAT',false,true,'NORMAL',0,'/icons/channel-chat.svg','/app.html#advisor-coord','Web Push for internal chat; in-app chat unread remains authority'),
 ('TASK_ASSIGNED','TASKS',true,true,'NORMAL',0,'/icons/channel-tasks.svg','/app.html#advisor-coord','Task assignment'),
 ('MANUAL_NOTIFICATION','SYSTEM',true,true,'NORMAL',0,'/icons/icon-192x192.png','/app.html#advisor-coord','Manual coordination notification')
on conflict(event_type) do update set
 channel=excluded.channel,enabled=true,in_app_enabled=excluded.in_app_enabled,web_push_enabled=excluded.web_push_enabled,
 priority=excluded.priority,aggregate_seconds=excluded.aggregate_seconds,icon=excluded.icon,route=excluded.route,
 description=excluded.description,updated_at=now();

create or replace function public.aos_notification_resolve_user_v1(p_ref text)
returns uuid
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  v_ref text := upper(trim(coalesce(p_ref,'')));
  v_norm text;
  v_id uuid;
begin
  if v_ref='' or v_ref in ('NO APLICA','N/A','NA') then return null; end if;
  if v_ref='ADMIN' then
    select id into v_id from public.aos_usuarios
     where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
     order by coalesce(nivel_jerarquia,999),created_at nulls last limit 1;
    return v_id;
  end if;
  v_norm := regexp_replace(v_ref,'[[:space:]._-]+','','g');
  select id into v_id from public.aos_usuarios
   where activo=true and (
     regexp_replace(upper(trim(coalesce(nombre,''))),'[[:space:]._-]+','','g')=v_norm
     or regexp_replace(upper(trim(coalesce(codigo_asesor,''))),'[[:space:]._-]+','','g')=v_norm
   )
   order by coalesce(nivel_jerarquia,999),created_at nulls last limit 1;
  return v_id;
end;
$$;

create or replace function public.aos_notification_sale_commission_v1(p_tipo text,p_monto numeric)
returns numeric
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare v numeric:=0; v_tipo text:=upper(trim(coalesce(p_tipo,''))); v_monto numeric:=coalesce(p_monto,0);
begin
  if v_tipo='SERVICIO' then return round(v_monto*0.005,2); end if;
  if v_tipo='PRODUCTO' then
    select coalesce(max(tc.comision::numeric),0) into v
      from public.aos_tabla_comisiones tc
     where tc.tipo='PRODUCTO' and tc.monto_min::numeric<=v_monto and tc.activo=true;
    return coalesce(v,0);
  end if;
  return 0;
end;
$$;

create or replace function public.aos_notification_format_v1(p_event_type text,p_metadata jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  e text:=upper(trim(coalesce(p_event_type,'')));
  m jsonb:=coalesce(p_metadata,'{}'::jsonb);
  c integer:=1;
  amount numeric:=0;
  commission numeric:=0;
  adj numeric:=0;
  title text;
  body text;
  patient text:=trim(coalesce(m->>'last_patient',m->>'patient',''));
  treatment text:=trim(coalesce(m->>'last_treatment',m->>'treatment',''));
  sede text:=trim(coalesce(m->>'last_sede',m->>'sede',''));
  dt text:=trim(concat_ws(' ',nullif(m->>'date',''),nullif(m->>'time','')));
  reason text:=trim(coalesce(m->>'reason',''));
  plus text;
begin
  begin c:=greatest(1,coalesce((m->>'count')::integer,1)); exception when others then c:=1; end;
  begin amount:=coalesce((m->>'amount')::numeric,0); exception when others then amount:=0; end;
  begin commission:=coalesce((m->>'commission')::numeric,0); exception when others then commission:=0; end;
  begin adj:=coalesce((m->>'adjustment')::numeric,0); exception when others then adj:=0; end;

  if e='SALE_ADDED' then
    if c=1 then
      title:='Venta registrada · S/ '||to_char(amount,'FM999999990D00');
      body:=trim(concat_ws(' · ',nullif(patient,''),nullif(treatment,''),'Comisión +S/ '||to_char(commission,'FM999999990D00')));
    else
      title:=c||' ventas registradas · S/ '||to_char(amount,'FM999999990D00');
      body:='Tu comisión aumentó +S/ '||to_char(commission,'FM999999990D00');
    end if;
  elsif e='ADMIN_SALES_DIGEST' then
    title:='Ventas actualizadas · '||c||case when c=1 then ' registro' else ' registros' end;
    body:='S/ '||to_char(amount,'FM999999990D00')||' registrados en el sistema';
  elsif e='COMMISSION_ADJUSTED' then
    plus:=case when adj>=0 then '+' else '' end;
    title:='Comisión ajustada · '||plus||'S/ '||to_char(adj,'FM999999990D00');
    body:=coalesce(nullif(reason,''),'Se actualizó tu comisión');
  elsif e='APPOINTMENT_CREATED' then
    if c=1 then
      title:='Nueva cita agendada';
      body:=trim(concat_ws(' · ',nullif(patient,''),nullif(dt,''),nullif(sede,'')));
    else
      title:=c||' nuevas citas agendadas';
      body:='Tu agenda fue actualizada';
    end if;
  elsif e='ADMIN_APPOINTMENT_DIGEST' then
    title:='Agenda actualizada · '||c||case when c=1 then ' cita' else ' citas' end;
    body:='Se registraron nuevas citas en el sistema';
  elsif e='APPOINTMENT_ATTENDED' then
    title:='Tu cita asistió';
    body:=trim(concat_ws(' · ',nullif(patient,''),nullif(treatment,''),nullif(sede,'')));
  elsif e='APPOINTMENT_NO_SHOW' then
    title:='Tu cita no asistió';
    body:=trim(concat_ws(' · ',nullif(patient,''),'Revisa el seguimiento'));
  elsif e='APPOINTMENT_CANCELLED' then
    title:='Cita cancelada';
    body:=trim(concat_ws(' · ',nullif(patient,''),nullif(dt,''),nullif(sede,'')));
  elsif e='APPOINTMENT_RESCHEDULED' then
    title:='Cita reagendada';
    body:=trim(concat_ws(' · ',nullif(patient,''),nullif(dt,''),nullif(sede,'')));
  elsif e='ADMIN_ATTENDED_DIGEST' then
    title:='Atenciones · '||c||case when c=1 then ' asistencia' else ' asistencias' end;
    body:='Se actualizaron citas como asistidas';
  elsif e='ADMIN_NO_SHOW_DIGEST' then
    title:='Seguimiento · '||c||case when c=1 then ' inasistencia' else ' inasistencias' end;
    body:='Hay citas no asistidas para revisar';
  elsif e='INTERNAL_CHAT_MESSAGE' then
    title:='Chat · '||coalesce(nullif(m->>'sender',''),'ASCENDA');
    body:=left(regexp_replace(coalesce(m->>'preview','Nuevo mensaje'),'[[:cntrl:]]+',' ','g'),140);
  elsif e='TASK_ASSIGNED' then
    title:='Nueva tarea · '||left(coalesce(nullif(m->>'task_title',''),'Pendiente'),90);
    body:=trim(concat_ws(' · ',nullif('Prioridad '||coalesce(m->>'priority','NORMAL'),'Prioridad '),case when coalesce(m->>'due_date','')<>'' then 'Vence '||m->>'due_date' else null end));
  elsif e='MANUAL_NOTIFICATION' then
    title:=left(coalesce(nullif(m->>'title',''),'Notificación ASCENDA'),120);
    body:=left(coalesce(m->>'body',''),320);
  else
    title:=left(coalesce(nullif(m->>'title',''),'ASCENDA'),120);
    body:=left(coalesce(m->>'body',''),320);
  end if;
  return jsonb_build_object('title',coalesce(nullif(title,''),'ASCENDA'),'body',coalesce(body,''));
end;
$$;

create or replace function public.aos_notification_emit_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  e text:=upper(trim(coalesce(p_payload->>'event_type','')));
  pol public.aos_notification_policies_v1%rowtype;
  uid uuid;
  uname text;
  meta jsonb:=coalesce(p_payload->'metadata','{}'::jsonb);
  oldmeta jsonb;
  fmt jsonb;
  key text:=trim(coalesce(p_payload->>'dedupe_key',''));
  group_key text:=lower(trim(coalesce(p_payload->>'group_key','all')));
  entity text:=left(nullif(trim(coalesce(p_payload->>'entity_id','')),''),180);
  bucket bigint;
  n_id uuid;
  push_at timestamptz;
  p_count integer:=1; old_count integer:=0;
  p_amount numeric:=0; old_amount numeric:=0;
  p_comm numeric:=0; old_comm numeric:=0;
  is_broadcast boolean:=coalesce((p_payload->>'broadcast')::boolean,false);
  inapp boolean;
  webpush boolean;
  pri text;
  typ text;
begin
  if e='' then return jsonb_build_object('ok',false,'error','EVENT_TYPE_REQUIRED'); end if;
  select * into pol from public.aos_notification_policies_v1 where event_type=e and enabled=true;
  if not found then return jsonb_build_object('ok',false,'error','NOTIFICATION_POLICY_NOT_FOUND','event_type',e); end if;

  if coalesce(p_payload->>'recipient_user_id','')<>'' then
    begin uid:=(p_payload->>'recipient_user_id')::uuid; exception when others then uid:=null; end;
  else
    uid:=public.aos_notification_resolve_user_v1(p_payload->>'recipient_name');
  end if;
  if uid is null and not is_broadcast then return jsonb_build_object('ok',true,'skipped',true,'reason','RECIPIENT_NOT_RESOLVED'); end if;
  if uid is not null then select nombre into uname from public.aos_usuarios where id=uid and activo=true; end if;
  if uid is not null and uname is null then return jsonb_build_object('ok',true,'skipped',true,'reason','RECIPIENT_INACTIVE'); end if;

  if not (meta ? 'count') then meta:=jsonb_set(meta,'{count}','1'::jsonb,true); end if;
  begin p_count:=greatest(1,coalesce((meta->>'count')::integer,1)); exception when others then p_count:=1; end;
  begin p_amount:=coalesce((meta->>'amount')::numeric,0); exception when others then p_amount:=0; end;
  begin p_comm:=coalesce((meta->>'commission')::numeric,0); exception when others then p_comm:=0; end;

  if key='' then
    if pol.aggregate_seconds>0 then
      bucket:=floor(extract(epoch from clock_timestamp())/pol.aggregate_seconds)::bigint*pol.aggregate_seconds;
      key:=lower(e)||':'||coalesce(uid::text,'broadcast')||':'||group_key||':'||bucket::text;
      push_at:=to_timestamp(bucket+pol.aggregate_seconds);
    else
      key:=lower(e)||':'||coalesce(uid::text,'broadcast')||':'||coalesce(entity,gen_random_uuid()::text);
      push_at:=now();
    end if;
  else
    push_at:=case when pol.aggregate_seconds>0 then now()+make_interval(secs=>pol.aggregate_seconds) else now() end;
  end if;

  inapp:=case when p_payload ? 'in_app_enabled' then coalesce((p_payload->>'in_app_enabled')::boolean,pol.in_app_enabled) else pol.in_app_enabled end;
  webpush:=case when p_payload ? 'web_push_enabled' then coalesce((p_payload->>'web_push_enabled')::boolean,pol.web_push_enabled) else pol.web_push_enabled end;
  pri:=upper(coalesce(nullif(trim(p_payload->>'priority'),''),pol.priority,'NORMAL'));
  typ:=case when pri in ('URGENTE','CRITICAL','CRITICA') then 'URGENTE' when pri in ('ALTA','HIGH','MEDIA','ALERTA') then 'ALERTA' else 'INFO' end;
  fmt:=public.aos_notification_format_v1(e,meta);

  insert into public.aos_notificaciones(
    titulo,contenido,tipo,de,para,prioridad,created_at,para_user_id,channel,event_type,route,entity_id,icon,metadata,dedupe_key,
    in_app_enabled,push_enabled,push_after,push_status,push_attempts,updated_at
  ) values(
    fmt->>'title',fmt->>'body',typ,coalesce(nullif(p_payload->>'from',''),'ASCENDA'),
    case when is_broadcast then null else uname end,pri,now(),uid,pol.channel,e,
    coalesce(nullif(p_payload->>'route',''),pol.route),entity,coalesce(nullif(p_payload->>'icon',''),pol.icon),meta,key,
    inapp,webpush,push_at,case when webpush then 'PENDING' else 'SKIPPED' end,0,now()
  )
  on conflict(dedupe_key) where dedupe_key is not null do nothing
  returning id into n_id;

  if n_id is null then
    select id,metadata into n_id,oldmeta from public.aos_notificaciones where dedupe_key=key for update;
    begin old_count:=greatest(0,coalesce((oldmeta->>'count')::integer,0)); exception when others then old_count:=0; end;
    begin old_amount:=coalesce((oldmeta->>'amount')::numeric,0); exception when others then old_amount:=0; end;
    begin old_comm:=coalesce((oldmeta->>'commission')::numeric,0); exception when others then old_comm:=0; end;
    meta:=coalesce(oldmeta,'{}'::jsonb)||meta;
    meta:=jsonb_set(meta,'{count}',to_jsonb(old_count+p_count),true);
    meta:=jsonb_set(meta,'{amount}',to_jsonb(old_amount+p_amount),true);
    meta:=jsonb_set(meta,'{commission}',to_jsonb(old_comm+p_comm),true);
    fmt:=public.aos_notification_format_v1(e,meta);
    update public.aos_notificaciones set
      titulo=fmt->>'title',contenido=fmt->>'body',metadata=meta,updated_at=now(),
      push_status=case when push_enabled then 'PENDING' else push_status end,
      push_claimed_at=null
    where id=n_id;
  end if;
  return jsonb_build_object('ok',true,'id',n_id,'event_type',e,'dedupe_key',key);
end;
$$;

create or replace function public.aos_notification_push_claim_v1(p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare lim integer:=least(50,greatest(1,coalesce((p_payload->>'limit')::integer,20))); out_rows jsonb;
begin
  with pick as (
    select n.id from public.aos_notificaciones n
     where n.push_enabled=true
       and coalesce(n.push_after,n.created_at,now())<=now()
       and (n.expira_at is null or n.expira_at>now())
       and (n.push_status='PENDING' or (n.push_status='CLAIMED' and n.push_claimed_at<now()-interval '2 minutes'))
     order by case n.prioridad when 'URGENTE' then 0 when 'ALTA' then 1 else 2 end,n.created_at
     for update skip locked limit lim
  ), claimed as (
    update public.aos_notificaciones n set push_status='CLAIMED',push_claimed_at=now(),push_attempts=n.push_attempts+1,updated_at=now()
      from pick where n.id=pick.id
      returning n.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'recipient_user_id',c.para_user_id,'channel',c.channel,'event_type',c.event_type,
    'title',c.titulo,'body',c.contenido,'priority',c.prioridad,'route',c.route,'entity_id',c.entity_id,
    'icon',c.icon,'dedupe_key',coalesce(c.dedupe_key,'notif:'||c.id::text),'created_at',c.created_at,
    'subscriptions',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'user_id',s.user_id,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth))
      from public.aos_push_subscriptions_v1 s
      where s.active=true and (c.para_user_id is null or s.user_id=c.para_user_id)
        and coalesce((s.channel_preferences->>upper(c.channel))::boolean,true)=true),'[]'::jsonb)
  ) order by c.created_at),'[]'::jsonb) into out_rows from claimed c;
  return jsonb_build_object('ok',true,'rows',out_rows);
end;
$$;

create or replace function public.aos_notification_push_complete_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare nid uuid; st text:=upper(trim(coalesce(p_payload->>'status','FAILED'))); err text:=left(nullif(trim(coalesce(p_payload->>'error_code','')),''),160); attempts integer;
begin
  begin nid:=(p_payload->>'notification_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_NOTIFICATION_ID'); end;
  if st not in ('DELIVERED','PARTIAL','SKIPPED','FAILED') then st:='FAILED'; end if;
  update public.aos_notificaciones set push_status=st,push_claimed_at=null,updated_at=now(),metadata=case when err is null then metadata else jsonb_set(metadata,'{last_push_error}',to_jsonb(err),true) end where id=nid returning push_attempts into attempts;
  if attempts is null then return jsonb_build_object('ok',false,'error','NOTIFICATION_NOT_FOUND'); end if;
  return jsonb_build_object('ok',true,'status',st,'attempts',attempts);
end;
$$;

create or replace function public.aos_mis_notificaciones_v1(p_usuario text,p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare uid uuid:=public.aos_notification_resolve_user_v1(p_usuario); is_admin boolean:=false; rows jsonb;
begin
  if uid is not null then select (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1) into is_admin from public.aos_usuarios where id=uid; end if;
  select coalesce(jsonb_agg(row_to_json(x) order by x.created_at desc),'[]'::jsonb) into rows from (
    select n.id,n.titulo,n.contenido,n.tipo,n.prioridad,n.created_at,n.channel,n.event_type,n.route,n.entity_id,n.icon,n.para,
      (n.leido_por ? p_usuario) as leido
    from public.aos_notificaciones n
    where n.in_app_enabled=true and (n.expira_at is null or n.expira_at>now())
      and (
        n.para_user_id=uid
        or (n.para_user_id is null and n.para is null)
        or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(trim(coalesce(p_usuario,''))))
        or (n.para_user_id is null and upper(coalesce(n.para,''))='ADMIN' and is_admin)
      )
    order by n.created_at desc limit least(100,greatest(1,coalesce(p_limit,50)))
  ) x;
  return jsonb_build_object('ok',true,'rows',rows);
end;
$$;

create or replace function public.aos_admin_notificaciones_v1(p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare aid uuid; aname text; rows jsonb;
begin
  select id,nombre into aid,aname from public.aos_usuarios where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1) order by coalesce(nivel_jerarquia,999),created_at nulls last limit 1;
  select coalesce(jsonb_agg(row_to_json(x) order by x.created_at desc),'[]'::jsonb) into rows from (
    select n.id,n.titulo,n.contenido,n.tipo,n.prioridad,n.created_at,n.channel,n.event_type,n.route,n.entity_id,n.icon,n.para,
      case when aname is null then false else (n.leido_por ? aname) end as leido
    from public.aos_notificaciones n
    where n.in_app_enabled=true and (n.expira_at is null or n.expira_at>now())
      and (n.para_user_id=aid or (n.para_user_id is null and (n.para is null or upper(coalesce(n.para,''))='ADMIN')))
    order by n.created_at desc limit least(100,greatest(1,coalesce(p_limit,50)))
  ) x;
  return jsonb_build_object('ok',true,'rows',rows,'admin_user_id',aid,'admin_name',aname);
end;
$$;

-- Preserve the existing manual-notification signature, but bind direct recipients to real user IDs
-- and enable Web Push. Broadcast notifications remain one shared row and target all active subscriptions.
create or replace function public.aos_enviar_notificacion(p_titulo text,p_contenido text default null,p_para text default null,p_tipo text default 'INFO',p_prioridad text default 'NORMAL',p_expira timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare out jsonb; uid uuid; pri text:=upper(coalesce(nullif(trim(p_prioridad),''),case when upper(coalesce(p_tipo,''))='URGENTE' then 'URGENTE' when upper(coalesce(p_tipo,''))='ALERTA' then 'ALTA' else 'NORMAL' end));
begin
  uid:=public.aos_notification_resolve_user_v1(p_para);
  out:=public.aos_notification_emit_v1(jsonb_build_object(
    'event_type','MANUAL_NOTIFICATION','recipient_user_id',uid,'recipient_name',p_para,'broadcast',(p_para is null),
    'priority',pri,'from','ADMIN','dedupe_key','manual:'||gen_random_uuid()::text,
    'metadata',jsonb_build_object('title',left(coalesce(p_titulo,''),120),'body',left(coalesce(p_contenido,''),320))
  ));
  if p_expira is not null and coalesce(out->>'id','')<>'' then update public.aos_notificaciones set expira_at=p_expira where id=(out->>'id')::uuid; end if;
  return out;
end;
$$;

-- Upgrade advisor coordination payload to identity-backed notifications and channel metadata.
create or replace function public.aos_mis_mensajes(p_usuario text)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare v_result jsonb; uid uuid:=public.aos_notification_resolve_user_v1(p_usuario); is_admin boolean:=false;
begin
  if uid is not null then select (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1) into is_admin from public.aos_usuarios where id=uid; end if;
  select jsonb_build_object(
    'canales',(select coalesce(jsonb_agg(row_to_json(c) order by c.ultimo_mensaje_at desc nulls last),'[]'::jsonb) from (
      select ch.id,ch.nombre,ch.tipo,ch.ultimo_mensaje,ch.ultimo_mensaje_at,ch.cerrado,ch.participantes,
        (select count(*) from public.aos_mensajes m where m.canal=ch.id and not (m.leido_por ? p_usuario) and m.de<>p_usuario) as no_leidos
      from public.aos_canales ch where (ch.participantes ? p_usuario) and (ch.cerrado=false or ch.cerrado is null)
    ) c),
    'grupos',(select coalesce(jsonb_agg(row_to_json(g)),'[]'::jsonb) from (
      select g.id,g.nombre,g.color,g.tipo,jsonb_array_length(g.miembros) as n_miembros from public.aos_grupos g where g.activo=true and g.miembros ? p_usuario
    ) g),
    'tareas',(select coalesce(jsonb_agg(row_to_json(t)),'[]'::jsonb) from (
      select id,titulo,estado,prioridad,items,fecha_limite,vencida,tiempo_estimado_min,asignado_grupo,created_at from public.aos_tareas
      where (asignado_a=p_usuario or asignado_grupo in (select g.id from public.aos_grupos g where g.miembros ? p_usuario)) and estado<>'COMPLETADA'
      order by case when vencida then 0 else 1 end,case prioridad when 'URGENTE' then 0 when 'ALTA' then 1 else 2 end,fecha_limite asc nulls last
    ) t),
    'notificaciones',(select coalesce(jsonb_agg(row_to_json(n) order by n.created_at desc),'[]'::jsonb) from (
      select n.id,n.titulo,n.contenido,n.tipo,n.prioridad,n.created_at,n.channel,n.event_type,n.route,n.entity_id,n.icon,(n.leido_por ? p_usuario) as leido
      from public.aos_notificaciones n
      where n.in_app_enabled=true and (n.expira_at is null or n.expira_at>now()) and (
        n.para_user_id=uid or (n.para_user_id is null and n.para is null)
        or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(p_usuario))
        or (n.para_user_id is null and upper(coalesce(n.para,''))='ADMIN' and is_admin)
      ) order by n.created_at desc limit 30
    ) n)
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.aos_notification_sales_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare uid uuid; comm numeric; patient text; adm record;
begin
  uid:=public.aos_notification_resolve_user_v1(new.asesor);
  comm:=public.aos_notification_sale_commission_v1(new.tipo,new.monto);
  patient:=trim(concat_ws(' ',nullif(new.nombres,''),nullif(new.apellidos,'')));
  if uid is not null then
    perform public.aos_notification_emit_v1(jsonb_build_object(
      'event_type','SALE_ADDED','recipient_user_id',uid,'entity_id',new.id::text,'group_key','advisor',
      'metadata',jsonb_build_object('count',1,'amount',coalesce(new.monto,0),'commission',comm,'last_patient',patient,'last_treatment',coalesce(new.tratamiento,new.descripcion,''),'last_sede',coalesce(new.sede,''))
    ));
  end if;
  for adm in select id from public.aos_usuarios where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1) loop
    perform public.aos_notification_emit_v1(jsonb_build_object(
      'event_type','ADMIN_SALES_DIGEST','recipient_user_id',adm.id,'entity_id',new.id::text,'group_key','all-sales',
      'metadata',jsonb_build_object('count',1,'amount',coalesce(new.monto,0),'commission',0,'last_sede',coalesce(new.sede,''))
    ));
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_aos_notification_sale_v1 on public.aos_ventas;
create trigger trg_aos_notification_sale_v1 after insert on public.aos_ventas for each row execute function public.aos_notification_sales_trigger_v1();

create or replace function public.aos_notification_commission_adjust_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare uid uuid;
begin
  uid:=public.aos_notification_resolve_user_v1(new.asesor);
  if uid is not null then
    perform public.aos_notification_emit_v1(jsonb_build_object(
      'event_type','COMMISSION_ADJUSTED','recipient_user_id',uid,'entity_id',new.id::text,'dedupe_key','commission-adjust:'||new.id::text,
      'metadata',jsonb_build_object('count',1,'adjustment',coalesce(new.ajuste,0),'reason',coalesce(new.motivo,''))
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_aos_notification_commission_adjust_v1 on public.aos_ajustes_comision;
create trigger trg_aos_notification_commission_adjust_v1 after insert on public.aos_ajustes_comision for each row execute function public.aos_notification_commission_adjust_trigger_v1();

create or replace function public.aos_notification_agenda_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare uid uuid; patient text; st text; oldst text; ev text; adm_ev text; adm record;
begin
  uid:=public.aos_notification_resolve_user_v1(coalesce(nullif(new.id_asesor,''),new.asesor));
  patient:=trim(concat_ws(' ',nullif(new.nombre,''),nullif(new.apellido,'')));
  if tg_op='INSERT' then
    if uid is not null then
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','APPOINTMENT_CREATED','recipient_user_id',uid,'entity_id',new.id,'group_key','advisor',
        'metadata',jsonb_build_object('count',1,'last_patient',patient,'date',coalesce(new.fecha_cita::text,''),'time',coalesce(new.hora_cita,''),'last_sede',coalesce(new.sede,''),'last_treatment',coalesce(new.tratamiento,''))
      ));
    end if;
    for adm in select id from public.aos_usuarios where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1) loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','ADMIN_APPOINTMENT_DIGEST','recipient_user_id',adm.id,'entity_id',new.id,'group_key','all-appointments',
        'metadata',jsonb_build_object('count',1,'last_sede',coalesce(new.sede,''))
      ));
    end loop;
    return new;
  end if;

  st:=upper(trim(coalesce(new.estado_cita,''))); oldst:=upper(trim(coalesce(old.estado_cita,'')));
  if st=oldst then return new; end if;
  if st in ('ASISTIO','EFECTIVA') and oldst not in ('ASISTIO','EFECTIVA') then ev:='APPOINTMENT_ATTENDED'; adm_ev:='ADMIN_ATTENDED_DIGEST';
  elsif st='NO ASISTIO' then ev:='APPOINTMENT_NO_SHOW'; adm_ev:='ADMIN_NO_SHOW_DIGEST';
  elsif st='CANCELADA' then ev:='APPOINTMENT_CANCELLED';
  elsif st='REAGENDADA' then ev:='APPOINTMENT_RESCHEDULED';
  else return new; end if;

  if uid is not null then
    perform public.aos_notification_emit_v1(jsonb_build_object(
      'event_type',ev,'recipient_user_id',uid,'entity_id',new.id,'dedupe_key','agenda:'||lower(ev)||':'||new.id||':'||md5(st),
      'metadata',jsonb_build_object('count',1,'last_patient',patient,'date',coalesce(new.fecha_cita::text,''),'time',coalesce(new.hora_cita,''),'last_sede',coalesce(new.sede,''),'last_treatment',coalesce(new.tratamiento,''))
    ));
  end if;
  if adm_ev is not null then
    for adm in select id from public.aos_usuarios where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1) loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type',adm_ev,'recipient_user_id',adm.id,'entity_id',new.id,'group_key','all-attendance','metadata',jsonb_build_object('count',1)
      ));
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_aos_notification_agenda_insert_v1 on public.aos_agenda_citas;
create trigger trg_aos_notification_agenda_insert_v1 after insert on public.aos_agenda_citas for each row execute function public.aos_notification_agenda_trigger_v1();
drop trigger if exists trg_aos_notification_agenda_update_v1 on public.aos_agenda_citas;
create trigger trg_aos_notification_agenda_update_v1 after update of estado_cita on public.aos_agenda_citas for each row execute function public.aos_notification_agenda_trigger_v1();

create or replace function public.aos_notification_message_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare member text; uid uuid; preview text;
begin
  preview:=left(regexp_replace(coalesce(new.mensaje,''),'[[:cntrl:]]+',' ','g'),140);
  for member in select jsonb_array_elements_text(coalesce((select participantes from public.aos_canales where id=new.canal),'[]'::jsonb)) loop
    if upper(trim(member))=upper(trim(new.de)) then continue; end if;
    uid:=public.aos_notification_resolve_user_v1(member);
    if uid is not null then
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','INTERNAL_CHAT_MESSAGE','recipient_user_id',uid,'entity_id',new.id::text,'dedupe_key','chat:'||new.id::text||':'||uid::text,
        'in_app_enabled',false,'metadata',jsonb_build_object('count',1,'sender',new.de,'preview',preview,'channel_id',new.canal)
      ));
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_aos_notification_message_v1 on public.aos_mensajes;
create trigger trg_aos_notification_message_v1 after insert on public.aos_mensajes for each row execute function public.aos_notification_message_trigger_v1();

create or replace function public.aos_notification_task_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare member text; uid uuid;
begin
  if coalesce(trim(new.asignado_a),'')<>'' then
    uid:=public.aos_notification_resolve_user_v1(new.asignado_a);
    if uid is not null then
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','TASK_ASSIGNED','recipient_user_id',uid,'entity_id',new.id::text,'dedupe_key','task:'||new.id::text||':'||uid::text,
        'priority',coalesce(new.prioridad,'NORMAL'),'metadata',jsonb_build_object('count',1,'task_title',new.titulo,'priority',coalesce(new.prioridad,'NORMAL'),'due_date',coalesce(new.fecha_limite::text,''))
      ));
    end if;
  end if;
  if coalesce(trim(new.asignado_grupo),'')<>'' then
    for member in select jsonb_array_elements_text(coalesce((select miembros from public.aos_grupos where id=new.asignado_grupo),'[]'::jsonb)) loop
      uid:=public.aos_notification_resolve_user_v1(member);
      if uid is not null then
        perform public.aos_notification_emit_v1(jsonb_build_object(
          'event_type','TASK_ASSIGNED','recipient_user_id',uid,'entity_id',new.id::text,'dedupe_key','task:'||new.id::text||':'||uid::text,
          'priority',coalesce(new.prioridad,'NORMAL'),'metadata',jsonb_build_object('count',1,'task_title',new.titulo,'priority',coalesce(new.prioridad,'NORMAL'),'due_date',coalesce(new.fecha_limite::text,''))
        ));
      end if;
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_aos_notification_task_v1 on public.aos_tareas;
create trigger trg_aos_notification_task_v1 after insert on public.aos_tareas for each row execute function public.aos_notification_task_trigger_v1();

revoke all on public.aos_notification_policies_v1 from anon,authenticated;
grant select on public.aos_notification_policies_v1 to service_role;

revoke all on function public.aos_notification_resolve_user_v1(text) from public,anon,authenticated;
revoke all on function public.aos_notification_sale_commission_v1(text,numeric) from public,anon,authenticated;
revoke all on function public.aos_notification_format_v1(text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_notification_emit_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_notification_push_claim_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_notification_push_complete_v1(jsonb) from public,anon,authenticated;

grant execute on function public.aos_notification_resolve_user_v1(text) to service_role;
grant execute on function public.aos_notification_sale_commission_v1(text,numeric) to service_role;
grant execute on function public.aos_notification_format_v1(text,jsonb) to service_role;
grant execute on function public.aos_notification_emit_v1(jsonb) to service_role;
grant execute on function public.aos_notification_push_claim_v1(jsonb) to service_role;
grant execute on function public.aos_notification_push_complete_v1(jsonb) to service_role;

comment on table public.aos_notification_policies_v1 is 'S15 event registry controlling ASCENDA in-app and Web Push notification behavior.';
comment on function public.aos_notification_emit_v1(jsonb) is 'S15 canonical notification event projector with dedupe and aggregation.';
