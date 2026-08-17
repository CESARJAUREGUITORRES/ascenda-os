-- ASCENDA S15 — normalize legacy direct inserts into aos_notificaciones.
-- Native S15 events already carry event_type and bypass this bridge.

insert into public.aos_notification_policies_v1(event_type,channel,in_app_enabled,web_push_enabled,priority,aggregate_seconds,icon,route,description)
values
 ('AGENT_ALERT','AGENTS',true,true,'ALTA',30,'/icons/channel-agent.svg','/app.html#admin-chats','Legacy AI agent alerts normalized into S15'),
 ('LEGACY_NOTIFICATION','SYSTEM',true,true,'NORMAL',15,'/icons/icon-192x192.png','/app.html#admin-chats','Compatibility bridge for old direct notification inserts')
on conflict(event_type) do update set
 channel=excluded.channel,enabled=true,in_app_enabled=excluded.in_app_enabled,web_push_enabled=excluded.web_push_enabled,
 priority=excluded.priority,aggregate_seconds=excluded.aggregate_seconds,icon=excluded.icon,route=excluded.route,
 description=excluded.description,updated_at=now();

create or replace function public.aos_notification_legacy_bridge_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  pol public.aos_notification_policies_v1%rowtype;
  ev text;
  target uuid;
  is_agent boolean:=upper(coalesce(new.de,''))='AGENTES_AI'
    or upper(coalesce(new.titulo,'')) like '%BRUNO%'
    or upper(coalesce(new.titulo,'')) like '%LEÓN%'
    or upper(coalesce(new.titulo,'')) like '%LEON%';
begin
  if nullif(trim(coalesce(new.event_type,'')),'') is not null then return new; end if;

  ev:=case when is_agent then 'AGENT_ALERT' else 'LEGACY_NOTIFICATION' end;
  select * into pol from public.aos_notification_policies_v1 where event_type=ev and enabled=true;
  if not found then return new; end if;

  target:=public.aos_notification_resolve_user_v1(new.para);
  new.para_user_id:=coalesce(new.para_user_id,target);
  new.channel:=pol.channel;
  new.event_type:=ev;
  new.route:=coalesce(nullif(new.route,''),pol.route);
  new.icon:=coalesce(nullif(new.icon,''),pol.icon);
  new.entity_id:=coalesce(nullif(new.entity_id,''),coalesce(new.id::text,gen_random_uuid()::text));
  new.dedupe_key:=coalesce(nullif(new.dedupe_key,''),'legacy:'||coalesce(new.id::text,gen_random_uuid()::text));
  new.in_app_enabled:=true;
  new.push_enabled:=pol.web_push_enabled;
  new.push_after:=coalesce(new.push_after,now()+make_interval(secs=>pol.aggregate_seconds));
  new.push_status:=case when pol.web_push_enabled then 'PENDING' else 'SKIPPED' end;
  new.updated_at:=now();
  new.metadata:=coalesce(new.metadata,'{}'::jsonb)||jsonb_build_object('legacy_bridge',true,'legacy_source',coalesce(new.de,'UNKNOWN'));
  return new;
end;
$$;

drop trigger if exists trg_aos_notification_legacy_bridge_v1 on public.aos_notificaciones;
create trigger trg_aos_notification_legacy_bridge_v1
before insert on public.aos_notificaciones
for each row execute function public.aos_notification_legacy_bridge_v1();

comment on function public.aos_notification_legacy_bridge_v1() is 'S15 compatibility normalizer for direct legacy notification inserts such as Bruno/Leon agent alerts.';
