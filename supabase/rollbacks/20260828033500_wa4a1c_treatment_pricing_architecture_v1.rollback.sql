-- WA-4A.1C rollback. Does not touch canonical catalog/quotes/payments/WA-4A.1B.
begin;
drop function if exists public.aos_wa4_quote_preview_v1(jsonb,text,boolean);
drop function if exists public.aos_wa4_price_fingerprint_v1();
drop view if exists public.aos_wa4_process_entity_context_v1;
drop view if exists public.aos_wa4_topping_authority_v1;
drop view if exists public.aos_wa4_price_authority_v1;
drop table if exists public.aos_wa4_process_templates_v1;
drop table if exists public.aos_wa4_process_role_policy_v1;
commit;
