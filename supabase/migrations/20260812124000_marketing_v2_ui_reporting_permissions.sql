-- Marketing Attribution V2 — UI read-only reporting surface.
-- Exposes only aggregate/paged reporting RPCs already needed by the existing browser architecture.
-- Internal reconstruction/matcher functions remain unavailable to anon.

grant execute on function public.aos_marketing_historico_v2_preview(integer) to anon;
grant execute on function public.aos_marketing_cohortes_ltv_v2_preview(integer) to anon;
grant execute on function public.aos_marketing_anuncios_v2_preview(integer,integer,text,integer,integer,text) to anon;
grant execute on function public.aos_marketing_campanas_v2_preview(integer,integer,text,integer,integer,text) to anon;
grant execute on function public.aos_marketing_attribution_summary_v2_preview(integer,integer) to anon;
grant execute on function public.aos_marketing_periodos_v2_preview() to anon;
grant execute on function public.aos_marketing_leads_detalle_v2_paged(date,date,text,text,integer,integer) to anon;
