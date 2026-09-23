-- P0 communications recovery · bounded push drain
-- The foreground incident shield now permits the generic push claim lane.
-- Keep each DB claim intentionally small while Supabase/PostgREST is degraded.
-- This changes only the maximum claim batch; delivery, dedupe and recipient
-- semantics remain unchanged.

create or replace function public.aos_notification_push_claim_v1(
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  lim integer:=least(5,greatest(1,coalesce((p_payload->>'limit')::integer,5)));
  out_rows jsonb;
begin
  with pick as (
    select n.id
      from public.aos_notificaciones n
     where n.push_enabled=true
       and coalesce(n.push_after,n.created_at,now())<=now()
       and (n.expira_at is null or n.expira_at>now())
       and (n.push_status='PENDING' or (n.push_status='CLAIMED' and n.push_claimed_at<now()-interval '2 minutes'))
     order by case n.prioridad when 'URGENTE' then 0 when 'ALTA' then 1 else 2 end,n.created_at
     for update skip locked
     limit lim
  ), claimed as (
    update public.aos_notificaciones n
       set push_status='CLAIMED',
           push_claimed_at=now(),
           push_attempts=n.push_attempts+1,
           updated_at=now()
      from pick
     where n.id=pick.id
     returning n.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,
    'recipient_user_id',c.para_user_id,
    'channel',c.channel,
    'event_type',c.event_type,
    'title',c.titulo,
    'body',c.contenido,
    'priority',c.prioridad,
    'route',c.route,
    'entity_id',c.entity_id,
    'icon',c.icon,
    'dedupe_key',coalesce(c.dedupe_key,'notif:'||c.id::text),
    'created_at',c.created_at,
    'subscriptions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',s.id,'user_id',s.user_id,'endpoint',s.endpoint,
        'p256dh',s.p256dh,'auth',s.auth
      ))
      from public.aos_push_subscriptions_v1 s
      where s.active=true
        and (c.para_user_id is null or s.user_id=c.para_user_id)
        and coalesce((s.channel_preferences->>upper(c.channel))::boolean,true)=true
    ),'[]'::jsonb)
  ) order by c.created_at),'[]'::jsonb)
    into out_rows
    from claimed c;

  return jsonb_build_object('ok',true,'rows',out_rows);
end;
$function$;

comment on function public.aos_notification_push_claim_v1(jsonb) is
'Generic notification push claim. P0 2026-09-23 caps each claim at 5 while critical push is allowed through foreground incident mode.';
