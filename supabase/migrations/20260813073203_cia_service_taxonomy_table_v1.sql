-- ASCENDA OS — CIA Phase 4 service taxonomy table
begin;
create table if not exists public.aos_service_family_taxonomy_v1(
 raw_family text primary key,
 canonical_category text not null,
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.aos_service_family_taxonomy_v1 enable row level security;
revoke all on public.aos_service_family_taxonomy_v1 from public,anon,authenticated;
grant select on public.aos_service_family_taxonomy_v1 to service_role;
commit;
