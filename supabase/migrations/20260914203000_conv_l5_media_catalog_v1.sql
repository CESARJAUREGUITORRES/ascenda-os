-- CONV-L5 governed commercial media catalog. Additive, read-only to runtime callers.
create table if not exists public.aos_conv_l5_media_catalog_v1 (
  id uuid primary key default gen_random_uuid(),
  media_type text not null check (media_type in ('image','video','document')),
  title text not null,
  description text,
  public_url text not null check (public_url ~ '^https://'),
  treatment_id uuid,
  tags text[] not null default '{}',
  active boolean not null default true,
  approved_for_whatsapp boolean not null default false,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_conv_l5_media_active on public.aos_conv_l5_media_catalog_v1(active,approved_for_whatsapp,sort_order);
create index if not exists idx_conv_l5_media_treatment on public.aos_conv_l5_media_catalog_v1(treatment_id) where active and approved_for_whatsapp;

revoke all on table public.aos_conv_l5_media_catalog_v1 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_conv_l5_media_catalog_v1 to service_role;

comment on table public.aos_conv_l5_media_catalog_v1 is 'CONV-L5 governed commercial media allowlist. Only active + approved_for_whatsapp assets may be exposed by the conversation tool.';