begin;

alter table public.aos_cola_config enable row level security;
drop policy if exists aos_cola_config_all on public.aos_cola_config;
revoke all on table public.aos_cola_config from public, anon, authenticated;

-- Governed compatibility is now exclusively through SECURITY DEFINER queue RPCs.
-- Service/runtime authority is intentionally preserved.
grant all on table public.aos_cola_config to service_role;

commit;
