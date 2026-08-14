-- ASCENDA CIA V3 — Phase 11 rollout control and audit guards.

create or replace function public.aos_cia_call_routing_event_append_guard_v1()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  if tg_op in ('UPDATE','DELETE') then
    raise exception 'CALL_ROUTING_EVENT_APPEND_ONLY';
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_cia_call_routing_event_append_guard_v1 on public.aos_cia_call_routing_events;
create trigger trg_cia_call_routing_event_append_guard_v1
before update or delete on public.aos_cia_call_routing_events
for each row execute function public.aos_cia_call_routing_event_append_guard_v1();

create or replace function public.aos_cia_call_routing_effective_mode_v1(p_advisor_user_id uuid)
returns jsonb
language sql
stable
set search_path = public
as $function$
with ctl as (
  select global_enabled, fallback_to_v2
  from public.aos_cia_call_routing_control
  where id=1
), cfg as (
  select mode, fallback_to_v2, enabled_at
  from public.aos_cia_call_routing_advisors
  where advisor_user_id=p_advisor_user_id
)
select jsonb_build_object(
  'global_enabled',coalesce((select global_enabled from ctl),false),
  'configured_mode',coalesce((select mode from cfg),'V2_ONLY'),
  'effective_mode',case
      when not coalesce((select global_enabled from ctl),false) then 'V2_ONLY'
      else coalesce((select mode from cfg),'V2_ONLY')
    end,
  'fallback_to_v2',true,
  'enabled_at',(select enabled_at from cfg)
);
$function$;

create or replace function public.aos_cia_call_routing_admin_v1(
  p_token text,
  p_action text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  auth jsonb;
  actor uuid;
  action_name text := upper(coalesce(p_action,''));
  advisor_id uuid;
  routing_mode text;
  enabled boolean;
  lim integer;
  result jsonb;
begin
  if pg_column_size(coalesce(p_payload,'{}'::jsonb)) > 65536 then
    return jsonb_build_object('ok',false,'error','PAYLOAD_TOO_LARGE');
  end if;

  auth := public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  actor := (auth->>'user_id')::uuid;

  if action_name='GET_STATUS' then
    return jsonb_build_object(
      'ok',true,
      'control',(select to_jsonb(c) from public.aos_cia_call_routing_control c where c.id=1),
      'advisors',coalesce((
        select jsonb_agg(jsonb_build_object(
          'advisor_user_id',u.id,'advisor_name',u.nombre,'advisor_code',u.codigo_asesor,
          'mode',coalesce(r.mode,'V2_ONLY'),'configured',r.advisor_user_id is not null,
          'enabled_at',r.enabled_at,'updated_at',r.updated_at
        ) order by u.nombre)
        from public.aos_usuarios u
        left join public.aos_cia_call_routing_advisors r on r.advisor_user_id=u.id
        where u.activo=true and lower(coalesce(u.rol,''))='asesor'
      ),'[]'::jsonb),
      'readiness',public.aos_cia_advisor_control_f11_readiness_v1(),
      'observed_at',statement_timestamp()
    );
  elsif action_name='SET_GLOBAL' then
    enabled := coalesce((p_payload->>'enabled')::boolean,false);
    update public.aos_cia_call_routing_control
       set global_enabled=enabled,
           fallback_to_v2=true,
           updated_by_user_id=actor,
           metadata=coalesce(p_payload->'metadata','{}'::jsonb),
           updated_at=clock_timestamp()
     where id=1;
    insert into public.aos_cia_call_routing_events(event_type,routing_mode,route_selected,payload)
    values('CONFIG',case when enabled then 'GLOBAL_ON' else 'GLOBAL_OFF' end,null,
           jsonb_build_object('actor_user_id',actor,'action','SET_GLOBAL','enabled',enabled));
    return jsonb_build_object('ok',true,'global_enabled',enabled);
  elsif action_name='SET_ADVISOR' then
    advisor_id := nullif(p_payload->>'advisor_user_id','')::uuid;
    routing_mode := upper(coalesce(p_payload->>'mode','V2_ONLY'));
    if routing_mode not in ('V2_ONLY','V3_CANARY','V3_PREFERRED') then
      return jsonb_build_object('ok',false,'error','INVALID_MODE');
    end if;
    if not exists(select 1 from public.aos_usuarios u where u.id=advisor_id and u.activo=true and lower(coalesce(u.rol,''))='asesor') then
      return jsonb_build_object('ok',false,'error','INVALID_ADVISOR');
    end if;
    insert into public.aos_cia_call_routing_advisors(
      advisor_user_id,mode,fallback_to_v2,enabled_at,updated_by_user_id,metadata,created_at,updated_at
    ) values(
      advisor_id,routing_mode,true,
      case when routing_mode='V2_ONLY' then null else clock_timestamp() end,
      actor,coalesce(p_payload->'metadata','{}'::jsonb),clock_timestamp(),clock_timestamp()
    )
    on conflict(advisor_user_id) do update set
      mode=excluded.mode,
      fallback_to_v2=true,
      enabled_at=case when excluded.mode='V2_ONLY' then null else coalesce(public.aos_cia_call_routing_advisors.enabled_at,clock_timestamp()) end,
      updated_by_user_id=actor,
      metadata=excluded.metadata,
      updated_at=clock_timestamp();
    insert into public.aos_cia_call_routing_events(event_type,advisor_user_id,routing_mode,payload)
    values('CONFIG',advisor_id,routing_mode,jsonb_build_object('actor_user_id',actor,'action','SET_ADVISOR'));
    return jsonb_build_object('ok',true,'advisor_user_id',advisor_id,'mode',routing_mode);
  elsif action_name='CLEAR_ADVISOR' then
    advisor_id := nullif(p_payload->>'advisor_user_id','')::uuid;
    delete from public.aos_cia_call_routing_advisors where advisor_user_id=advisor_id;
    insert into public.aos_cia_call_routing_events(event_type,advisor_user_id,routing_mode,payload)
    values('CONFIG',advisor_id,'V2_ONLY',jsonb_build_object('actor_user_id',actor,'action','CLEAR_ADVISOR'));
    return jsonb_build_object('ok',true,'advisor_user_id',advisor_id,'mode','V2_ONLY');
  elsif action_name='LIST_EVENTS' then
    lim := least(greatest(coalesce(nullif(p_payload->>'limit','')::integer,100),1),200);
    select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb)) into result
    from (
      select e.id,e.request_id,e.event_type,e.advisor_user_id,u.nombre advisor_name,
             e.routing_mode,e.route_selected,e.assignment_id,e.plan_id,e.activation_id,
             e.fallback_reason,e.latency_ms,e.payload,e.occurred_at
      from public.aos_cia_call_routing_events e
      left join public.aos_usuarios u on u.id=e.advisor_user_id
      order by e.occurred_at desc,e.id desc limit lim
    ) q;
    return result;
  else
    return jsonb_build_object('ok',false,'error','INVALID_ACTION');
  end if;
exception when others then
  return jsonb_build_object('ok',false,'error',left(sqlerrm,500));
end;
$function$;

revoke execute on function public.aos_cia_call_routing_event_append_guard_v1() from public, anon, authenticated;
revoke execute on function public.aos_cia_call_routing_effective_mode_v1(uuid) from public, anon, authenticated;
revoke execute on function public.aos_cia_call_routing_admin_v1(text,text,jsonb) from public;
grant execute on function public.aos_cia_call_routing_admin_v1(text,text,jsonb) to anon, authenticated, service_role;
grant execute on function public.aos_cia_call_routing_effective_mode_v1(uuid) to service_role;
