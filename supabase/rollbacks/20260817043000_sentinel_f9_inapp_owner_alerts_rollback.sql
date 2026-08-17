begin;
drop trigger if exists aos_sentinel_inapp_route_trg on public.aos_sentinel_incidents_v1;
drop function if exists public.aos_sentinel_inapp_route_trigger_v1();
drop function if exists public.aos_sentinel_owner_mark_read_v1(text,bigint);
drop function if exists public.aos_sentinel_owner_feed_v1(text,integer);
drop function if exists public.aos_sentinel_inapp_flush_digests_v1(timestamptz);
drop function if exists public.aos_sentinel_route_incident_inapp_v1(text,text,text,timestamptz);
drop function if exists public.aos_sentinel_set_inapp_enabled_v1(boolean);
drop function if exists public.aos_sentinel_inapp_publish_dispatch_v1(bigint,timestamptz);
drop function if exists public.aos_sentinel_alert_reserve_dispatch_v2(jsonb);
drop function if exists public.aos_sentinel_owner_actor_v1(text);
drop table if exists public.aos_sentinel_owner_notification_reads_v1;
drop table if exists public.aos_sentinel_alert_runtime_errors_v1;
drop table if exists public.aos_sentinel_alert_runtime_v1;
do $$ begin
  if not exists(select 1 from public.aos_sentinel_alert_dispatches_v1 where channel='ascenda-in-app') then
    alter table public.aos_sentinel_alert_dispatches_v1 drop constraint if exists aos_sentinel_alert_dispatches_v1_channel_check;
    alter table public.aos_sentinel_alert_dispatches_v1 add constraint aos_sentinel_alert_dispatches_v1_channel_check check(channel='telegram-owner');
  end if;
end $$;
commit;
