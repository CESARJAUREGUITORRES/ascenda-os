-- MKT-INTEGRITY-HOTFIX-V3 / LOOP 2
-- Reversible schema-only rollback. DO NOT run during normal operation.
-- Drops only objects created by Loop 2, in reverse dependency order.

begin;

drop function if exists public.aos_marketing_leads_detalle_v3_summary(date,date,text,text);
drop function if exists public.aos_marketing_leads_detalle_v3_paged(date,date,text,text,integer,integer);
drop function if exists public.aos_marketing_touchpoint_rollup_v3_preview(date,date);
drop function if exists public.aos_marketing_attribution_v3_preview(date,date);
drop function if exists public.aos_marketing_acquisition_customers_v3_preview();
drop function if exists public.aos_marketing_agenda_lead_match_v3_preview(date,date);
drop function if exists public.aos_marketing_call_lead_match_v3_preview(date,date);
drop function if exists public.aos_marketing_treatment_family_v3(text);

commit;

-- Post-rollback gates (execute separately):
-- 1) compare V2 pg_get_functiondef hashes with Loop 1 BEFORE manifest;
-- 2) verify no app/public reference to *_v3_* shadow RPCs;
-- 3) re-read REV-F5 7,064/15,498 + 3,950 clusters + zero members/preview/apply;
-- 4) never touch aos_llamadas/aos_agenda_citas/aos_leads/aos_ventas as part of this rollback.
