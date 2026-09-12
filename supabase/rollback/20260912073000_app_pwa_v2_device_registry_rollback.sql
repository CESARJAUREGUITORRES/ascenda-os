-- APP-PWA-V2 #517 rollback for 20260912073000_app_pwa_v2_device_registry.sql
-- Use only before any production dependency is attached to these objects.

drop function if exists public.aos_effective_presence_v1(jsonb);
drop function if exists public.aos_app_presence_touch_v1(jsonb);
drop function if exists public.aos_device_upsert_v1(jsonb);

alter table if exists public.aos_push_subscriptions_v1
  drop column if exists device_id;

drop table if exists public.aos_app_presence_v1;
drop table if exists public.aos_devices_v1;
