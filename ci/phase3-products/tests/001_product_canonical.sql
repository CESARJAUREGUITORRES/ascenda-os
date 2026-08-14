\set ON_ERROR_STOP on

begin;
select plan(28);

select ok(to_regclass('public.aos_product_identity_v1') is not null,'identity table exists');
select ok(to_regclass('public.aos_product_alias_v2') is not null,'alias table exists');
select ok(to_regclass('public.aos_product_sale_fact_v1') is not null,'sale fact table exists');
select ok(to_regclass('public.aos_product_sale_fact_current_v1') is not null,'sanitized fact view exists');

select ok((select relrowsecurity from pg_class where oid='public.aos_product_identity_v1'::regclass),'identity RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.aos_product_alias_v2'::regclass),'alias RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.aos_product_sale_fact_v1'::regclass),'fact RLS enabled');
select ok(not has_table_privilege('anon','public.aos_product_identity_v1','SELECT'),'anon cannot select identities directly');
select ok(not has_table_privilege('anon','public.aos_product_alias_v2','INSERT'),'anon cannot write aliases directly');
select ok(not has_table_privilege('authenticated','public.aos_product_sale_fact_v1','UPDATE'),'authenticated cannot write facts directly');
select ok(not has_function_privilege('anon','public.aos_product_resolve_sale_v1(bigint)','EXECUTE'),'resolver is not anon callable');
select ok(not has_function_privilege('authenticated','public.aos_product_backfill_unlocked_v1()','EXECUTE'),'backfill is not browser callable');

select is((select count(*)::bigint from public.aos_product_identity_v1 where product_key like 'F3:%'),51::bigint,'51 owner canonical product identities');
select is((select count(*)::bigint from public.aos_product_identity_v1 where product_key like 'F3:%' and lifecycle_status='CURRENT_UNCATALOGED'),3::bigint,'3 current uncataloged owner identities');
select is((select count(*)::bigint from public.aos_product_identity_v1 where product_key like 'F3:%' and lifecycle_status='LEGACY'),8::bigint,'8 legacy owner identities');

select is((select count(*)::bigint from public.aos_product_sale_fact_v1 where resolution_source='OWNER_XLSX_2026'),394::bigint,'394 workbook sale facts seeded');
select is((select count(*)::bigint from public.aos_product_sale_fact_v1 where resolution_source='OWNER_XLSX_2026' and resolution_status='RESOLVED'),388::bigint,'388 product rows resolved');
select is((select count(*)::bigint from public.aos_product_sale_fact_v1 where resolution_source='OWNER_XLSX_2026' and resolution_status='EXCLUDED'),6::bigint,'6 rows explicitly excluded');
select is((select coalesce(sum(physical_qty),0)::numeric from public.aos_product_sale_fact_v1 where resolution_source='OWNER_XLSX_2026'),418::numeric,'418 physical product units');
select is((select count(*)::bigint from public.aos_product_sale_fact_v1 where resolution_source='OWNER_XLSX_2026' and is_pack=true),43::bigint,'43 promo/pack rows');
select is((select count(distinct product_key)::bigint from public.aos_product_sale_fact_v1 where resolution_source='OWNER_XLSX_2026' and resolution_status='RESOLVED'),51::bigint,'51 canonical products represented in owner facts');
select is((select count(*)::bigint from public.aos_product_sale_fact_v1 where resolution_source='OWNER_XLSX_2026' and locked=true),394::bigint,'all owner facts locked against auto overwrite');

select is((select canonical_name from public.aos_product_sale_fact_v1 f join public.aos_product_identity_v1 i using(product_key) where f.sale_id=909),'PERFECT FORM B 90GR','sale 909 corrected to Perfect Form B');
select is((select canonical_name from public.aos_product_sale_fact_v1 f join public.aos_product_identity_v1 i using(product_key) where f.sale_id=1644),'LYNDHARIAL GOTAS','sale 1644 corrected to Lyndharial Gotas');
select is((select physical_qty from public.aos_product_sale_fact_v1 where sale_id=1632),0::numeric,'sale 1632 does not double count split payment');
select is((select physical_qty from public.aos_product_sale_fact_v1 where sale_id=1638),0::numeric,'sale 1638 does not double count split payment');
select is((select descripcion from public.aos_ventas where id=909),'PERFECT- B 90GR','migration preserves original sale description');

insert into public.aos_ventas(id,fecha,tratamiento,descripcion,sede,tipo)
values (99999,current_date,'COMPRA DE PRODUCTO','LIFTIN B','SAN ISIDRO','PRODUCTO');
select ok((select resolution_status='RESOLVED' from public.aos_product_sale_fact_v1 where sale_id=99999),'new Liftin B sale resolves automatically');

insert into public.aos_ventas(id,fecha,tratamiento,descripcion,sede,tipo)
values (99998,current_date,'COMPRA DE PRODUCTO','ZZZ NEVER SEEN PRODUCT','SAN ISIDRO','PRODUCTO');
select ok((select resolution_status='REVIEW_REQUIRED' from public.aos_product_sale_fact_v1 where sale_id=99998),'unknown product fails closed to review');

select * from finish();
rollback;
