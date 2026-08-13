create or replace function public.aos_cia_gateway_bootstrap_v1()
returns jsonb language sql stable security definer set search_path=public as $$
select jsonb_build_object(
 'ok',true,
 'registry',coalesce((select jsonb_agg(to_jsonb(r) order by r.category,r.label) from public.aos_audience_filter_registry r where r.active and r.ui_visible),'[]'::jsonb),
 'presets',coalesce((select jsonb_agg(to_jsonb(p) order by p.category,p.name) from public.aos_audience_presets p where p.active),'[]'::jsonb),
 'summary',jsonb_build_object(
   'contacts',(select count(*) from public.aos_cia_contact_identity_v1),
   'segments',coalesce((select jsonb_object_agg(value_tier,n) from (select value_tier,count(*) n from public.aos_cia_segment_runtime_cache_v2 group by value_tier)s),'{}'::jsonb),
   'identity_conflicts',(select count(*) from public.aos_cia_contact_identity_v1 where identity_conflict)),
 'freshness',jsonb_build_object(
   'segment_cache_refreshed_at',(select max(cache_refreshed_at) from public.aos_cia_segment_runtime_cache_v2),
   'email_cache_refreshed_at',(select max(cache_refreshed_at) from public.aos_cia_email_runtime_cache_v2),
   'operational_facts','LIVE'),
 'resolver_version',2,'phase',5);
$$;
revoke all on function public.aos_cia_gateway_bootstrap_v1() from public,anon,authenticated;
grant execute on function public.aos_cia_gateway_bootstrap_v1() to service_role;
