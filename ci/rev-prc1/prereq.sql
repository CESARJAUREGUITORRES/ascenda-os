\set ON_ERROR_STOP on
alter table public.aos_product_identity_v1 add column if not exists product_group text;
alter table public.aos_product_identity_v1 add column if not exists variant_label text;
