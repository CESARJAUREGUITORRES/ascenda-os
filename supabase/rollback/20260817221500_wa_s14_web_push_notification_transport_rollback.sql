-- Rollback for WA S14 Web Push transport.
drop function if exists public.aos_push_dispatch_complete_v1(jsonb);
drop function if exists public.aos_push_dispatch_claim_v1(jsonb);
drop function if exists public.aos_push_targets_for_wa_v1(jsonb);
drop function if exists public.aos_push_subscription_disable_v1(jsonb);
drop function if exists public.aos_push_subscription_upsert_v1(jsonb);
drop function if exists public.aos_push_vapid_store_v1(jsonb);
drop function if exists public.aos_push_vapid_config_v1(jsonb);

do $$
declare v_secret uuid;
begin
  select private_secret_id into v_secret from public.aos_push_vapid_settings_v1 where id=1;
  if v_secret is not null then
    delete from vault.secrets where id=v_secret;
  end if;
exception when undefined_table then null;
end $$;

drop table if exists public.aos_push_dispatches_v1;
drop table if exists public.aos_push_subscriptions_v1;
drop table if exists public.aos_push_vapid_settings_v1;
