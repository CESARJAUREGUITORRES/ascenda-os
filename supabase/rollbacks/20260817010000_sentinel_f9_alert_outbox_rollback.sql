begin;

drop function if exists public.aos_sentinel_active_maintenance_windows_v1(timestamptz);
drop function if exists public.aos_sentinel_alert_recent_dispatches_v1(text);
drop function if exists public.aos_sentinel_alert_queue_digest_v1(jsonb);
drop function if exists public.aos_sentinel_alert_mark_delivery_v1(bigint,text,text,integer,timestamptz);
drop function if exists public.aos_sentinel_alert_reserve_dispatch_v1(jsonb);
drop table if exists public.aos_sentinel_maintenance_windows_v1;
drop table if exists public.aos_sentinel_alert_digest_items_v1;
drop table if exists public.aos_sentinel_alert_dispatches_v1;

commit;
