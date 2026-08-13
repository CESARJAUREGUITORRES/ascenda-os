-- ASCENDA OS — CIA Phase 4 product alias registry
begin;
create or replace function public.aos_cia_normalize_item_label_v1(p_raw text)
returns text language sql immutable parallel safe as $$
with s0 as (select upper(btrim(coalesce(p_raw,''))) s),
s1 as (select regexp_replace(regexp_replace(s,'\s*\(?PROMO\)?\s*$','','i'),'\s+[0-9]+\s*(ML|MG|G|GR|CAPS|CAP|UN|UND)\s*$','','i') s from s0)
select nullif(regexp_replace(s,'[^A-Z0-9ÁÉÍÓÚÜÑ]+','','g'),'') from s1;
$$;
create table if not exists public.aos_product_alias_overrides(
 alias_text text primary key,
 canonical_short_name text not null,
 reason text not null default 'LEGACY_ALIAS',
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.aos_product_alias_overrides enable row level security;
revoke all on function public.aos_cia_normalize_item_label_v1(text) from public,anon,authenticated;
revoke all on public.aos_product_alias_overrides from public,anon,authenticated;
grant execute on function public.aos_cia_normalize_item_label_v1(text) to service_role;
grant select on public.aos_product_alias_overrides to service_role;
commit;
