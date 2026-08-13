create table if not exists public.aos_cia_gateway_audit(
  id bigserial primary key,
  user_id uuid not null,
  usuario text not null,
  action text not null,
  ok boolean not null,
  duration_ms integer,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.aos_cia_gateway_audit enable row level security;
revoke all on public.aos_cia_gateway_audit from public,anon,authenticated;
grant select,insert on public.aos_cia_gateway_audit to service_role;
