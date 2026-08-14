create or replace function public.aos_cia_advisor_work_summary_v1(p_asesor text,p_id_asesor text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid;
  v_result jsonb;
begin
  v_uid:=public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_uid is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND'); end if;
  select jsonb_build_object(
    'ok',true,'advisor_user_id',v_uid,
    'active',count(*) filter(where assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS')),
    'visible_now',count(*) filter(where assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') and not is_snoozed),
    'snoozed',count(*) filter(where assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') and is_snoozed),
    'pinned',count(*) filter(where assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') and pinned),
    'in_progress',count(*) filter(where assignment_state='IN_PROGRESS'),
    'overdue_to_start',count(*) filter(where work_bucket='OVERDUE_TO_START'),
    'expiring_60m',count(*) filter(where work_bucket='EXPIRING_SOON'),
    'followup_overdue',count(*) filter(where work_bucket='FOLLOWUP_OVERDUE'),
    'requestable',count(*) filter(where requestable),
    'observed_at',statement_timestamp()
  ) into v_result
  from public.aos_cia_advisor_work_universe_v1(v_uid,false,true);
  return v_result;
end;
$$;

create or replace function public.aos_cia_advisor_work_list_v1(
  p_asesor text,p_id_asesor text,p_view text default 'NOW',p_limit integer default 50,p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid;
  v_view text:=upper(coalesce(p_view,'NOW'));
  v_result jsonb;
begin
  v_uid:=public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_uid is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND'); end if;
  if v_view not in ('NOW','PINNED','SNOOZED','HISTORY','ALL') then return jsonb_build_object('ok',false,'error','INVALID_VIEW'); end if;
  with src as (
    select * from public.aos_cia_advisor_work_universe_v1(v_uid,v_view in ('HISTORY','ALL'),true)
  ), filtered as (
    select * from src
    where case v_view
      when 'NOW' then assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') and not is_snoozed
      when 'PINNED' then assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') and pinned and not is_snoozed
      when 'SNOOZED' then assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') and is_snoozed
      when 'HISTORY' then assignment_state in ('COMPLETED','RELEASED','EXPIRED')
      else true end
  ), numbered as (
    select f.*,count(*) over() total_count
    from filtered f
    order by pinned desc,priority_score desc,
      case when assignment_state='IN_PROGRESS' then 0 else 1 end,
      must_start_before asc nulls last,expires_at asc nulls last,assigned_at asc,assignment_id
    limit least(greatest(coalesce(p_limit,50),1),100)
    offset greatest(coalesce(p_offset,0),0)
  )
  select jsonb_build_object(
    'ok',true,'advisor_user_id',v_uid,'view',v_view,
    'total',coalesce(max(total_count),0),
    'items',coalesce(jsonb_agg(to_jsonb(numbered)-'advisor_user_id' order by pinned desc,priority_score desc,must_start_before asc nulls last,assignment_id),'[]'::jsonb),
    'observed_at',statement_timestamp()
  ) into v_result from numbered;
  return v_result;
end;
$$;

create or replace function public.aos_cia_advisor_work_detail_v1(p_asesor text,p_id_asesor text,p_assignment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid;
  v_item jsonb;
begin
  v_uid:=public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_uid is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND'); end if;
  select to_jsonb(q)-'advisor_user_id' into v_item
  from public.aos_cia_advisor_work_universe_v1(v_uid,true,true) q
  where q.assignment_id=p_assignment_id;
  if v_item is null then return jsonb_build_object('ok',false,'error','WORK_ITEM_NOT_OWNED'); end if;
  return jsonb_build_object('ok',true,'advisor_user_id',v_uid,'item',v_item,'observed_at',statement_timestamp());
end;
$$;

create or replace function public.aos_cia_advisor_work_preference_v1(
  p_asesor text,p_id_asesor text,p_assignment_id uuid,p_action text,p_value text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid;
  v_action text:=upper(coalesce(p_action,''));
  v_owner uuid;
  v_state text;
  v_minutes integer;
begin
  v_uid:=public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_uid is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND'); end if;
  select advisor_user_id,state into v_owner,v_state from public.aos_cia_assignments where id=p_assignment_id;
  if v_owner is null or v_owner<>v_uid then return jsonb_build_object('ok',false,'error','WORK_ITEM_NOT_OWNED'); end if;
  if v_state not in ('RESERVED','ASSIGNED','IN_PROGRESS') and v_action<>'RESET' then return jsonb_build_object('ok',false,'error','WORK_ITEM_TERMINAL'); end if;
  if v_action='RESET' then
    delete from public.aos_cia_advisor_work_preferences where advisor_user_id=v_uid and assignment_id=p_assignment_id;
  elsif v_action in ('PIN','UNPIN') then
    insert into public.aos_cia_advisor_work_preferences(advisor_user_id,assignment_id,pinned)
    values(v_uid,p_assignment_id,v_action='PIN')
    on conflict(advisor_user_id,assignment_id) do update set pinned=excluded.pinned;
  elsif v_action='SNOOZE' then
    begin v_minutes:=p_value::integer; exception when others then return jsonb_build_object('ok',false,'error','INVALID_SNOOZE'); end;
    if v_minutes<1 or v_minutes>43200 then return jsonb_build_object('ok',false,'error','INVALID_SNOOZE'); end if;
    insert into public.aos_cia_advisor_work_preferences(advisor_user_id,assignment_id,snoozed_until)
    values(v_uid,p_assignment_id,statement_timestamp()+make_interval(mins=>v_minutes))
    on conflict(advisor_user_id,assignment_id) do update set snoozed_until=excluded.snoozed_until;
  elsif v_action='UNSNOOZE' then
    insert into public.aos_cia_advisor_work_preferences(advisor_user_id,assignment_id,snoozed_until)
    values(v_uid,p_assignment_id,null)
    on conflict(advisor_user_id,assignment_id) do update set snoozed_until=null;
  elsif v_action='PRIORITY' then
    if upper(coalesce(p_value,'')) not in ('HIGH','NORMAL','LOW') then return jsonb_build_object('ok',false,'error','INVALID_PRIORITY'); end if;
    insert into public.aos_cia_advisor_work_preferences(advisor_user_id,assignment_id,priority_override)
    values(v_uid,p_assignment_id,upper(p_value))
    on conflict(advisor_user_id,assignment_id) do update set priority_override=excluded.priority_override;
  else
    return jsonb_build_object('ok',false,'error','INVALID_ACTION');
  end if;
  return public.aos_cia_advisor_work_detail_v1(p_asesor,p_id_asesor,p_assignment_id);
end;
$$;

create or replace function public.aos_cia_advisor_work_f13_readiness_v1()
returns jsonb
language sql
stable
set search_path=public
as $$
with f11 as (select public.aos_cia_call_routing_f12_readiness_v1() j),
viol as (
  select
    count(*) filter(where x.state in ('RESERVED','ASSIGNED','IN_PROGRESS') and (u.id is null or not u.activo or lower(coalesce(u.rol,''))<>'asesor'))::integer invalid_active_owner,
    count(*) filter(where w.assignment_id is not null and w.advisor_user_id<>x.advisor_user_id)::integer preference_owner_mismatch,
    count(*) filter(where x.state in ('ASSIGNED','IN_PROGRESS') and x.expires_at>statement_timestamp())::integer requestable_items
  from public.aos_cia_assignments x
  left join public.aos_usuarios u on u.id=x.advisor_user_id
  left join public.aos_cia_advisor_work_preferences w on w.assignment_id=x.id
)
select jsonb_build_object(
  'ok',true,
  'ready_for_f13',coalesce((f11.j->>'ready_for_f12')::boolean,false) and viol.invalid_active_owner=0 and viol.preference_owner_mismatch=0,
  'status',case
    when not coalesce((f11.j->>'ready_for_f12')::boolean,false) then 'BLOCKED_F11_F12_HANDSHAKE'
    when viol.invalid_active_owner>0 then 'BLOCKED_INVALID_OWNER'
    when viol.preference_owner_mismatch>0 then 'BLOCKED_PREFERENCE_OWNER_MISMATCH'
    when viol.requestable_items=0 then 'READY_NO_REQUESTABLE_WORK'
    else 'READY' end,
  'violations',jsonb_build_object('invalid_active_owner',viol.invalid_active_owner,'preference_owner_mismatch',viol.preference_owner_mismatch),
  'requestable_items',viol.requestable_items,'f11_readiness',f11.j,
  'observed_at',statement_timestamp(),
  'next_phase_note','F13 may create governed requests referencing advisor_user_id + assignment_id; it must not autoassign or move ownership.'
) from f11 cross join viol;
$$;

revoke all on function public.aos_cia_advisor_work_summary_v1(text,text) from public;
revoke all on function public.aos_cia_advisor_work_list_v1(text,text,text,integer,integer) from public;
revoke all on function public.aos_cia_advisor_work_detail_v1(text,text,uuid) from public;
revoke all on function public.aos_cia_advisor_work_preference_v1(text,text,uuid,text,text) from public;
revoke all on function public.aos_cia_advisor_work_f13_readiness_v1() from public,anon,authenticated;
grant execute on function public.aos_cia_advisor_work_summary_v1(text,text) to anon,authenticated,service_role;
grant execute on function public.aos_cia_advisor_work_list_v1(text,text,text,integer,integer) to anon,authenticated,service_role;
grant execute on function public.aos_cia_advisor_work_detail_v1(text,text,uuid) to anon,authenticated,service_role;
grant execute on function public.aos_cia_advisor_work_preference_v1(text,text,uuid,text,text) to anon,authenticated,service_role;
grant execute on function public.aos_cia_advisor_work_f13_readiness_v1() to service_role;
