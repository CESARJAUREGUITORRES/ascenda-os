-- ASCENDA OS — Phase 3 emergency recovery
-- Disables automatic product resolution without mutating historical sales,
-- Auth, Caja, Cartera, patient data or owner-confirmed Phase 3 evidence.

begin;

drop trigger if exists trg_aos_product_sync_sale_v1 on public.aos_ventas;

revoke all on function public.aos_product_resolve_sale_v1(bigint) from public, anon, authenticated, service_role;
revoke all on function public.aos_product_backfill_unlocked_v1() from public, anon, authenticated, service_role;
revoke all on function public.aos_product_sync_sale_trigger_v1() from public, anon, authenticated, service_role;

-- Preserve normalization for forensic/read-only use by service only.
revoke all on function public.aos_product_normalize_alias_v2(text) from public, anon, authenticated;
grant execute on function public.aos_product_normalize_alias_v2(text) to service_role;

-- Preserve evidence tables but keep them browser-inaccessible.
revoke all on table public.aos_product_identity_v1 from public, anon, authenticated;
revoke all on table public.aos_product_alias_v2 from public, anon, authenticated;
revoke all on table public.aos_product_sale_fact_v1 from public, anon, authenticated;
revoke all on table public.aos_product_sale_fact_current_v1 from public, anon, authenticated;

grant select on table public.aos_product_identity_v1 to service_role;
grant select on table public.aos_product_alias_v2 to service_role;
grant select on table public.aos_product_sale_fact_v1 to service_role;
grant select on table public.aos_product_sale_fact_current_v1 to service_role;

commit;
