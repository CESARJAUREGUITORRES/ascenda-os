-- Marketing Attribution V2 — cleanup of an exploratory KPI RPC approach.
-- Final UI derives KPI/embudo from the already-loaded Historico V2 payload plus lightweight investment data.
-- These drops are idempotent and prevent slow/unused reporting functions from remaining exposed.

drop function if exists public.aos_marketing_kpis_v2_preview(integer,integer);
drop function if exists public.aos_marketing_kpis_v2_anio_preview(integer);
