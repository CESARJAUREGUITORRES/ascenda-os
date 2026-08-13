create or replace function public.aos_cia_refresh_segment_cache_v2()
returns jsonb language plpgsql security definer set search_path=public as $$
declare t timestamptz:=statement_timestamp();n integer;
begin
 if not pg_try_advisory_xact_lock(hashtext('cia_segment_cache_v2')) then return jsonb_build_object('ok',false,'busy',true);end if;
 insert into public.aos_cia_segment_runtime_cache_v2(contact_key,policy_key,policy_version,policy_status,value_tier,value_score,lifecycle,engagement,engagement_score,traits,explanation,segment_calculated_at,cache_refreshed_at)
 select contact_key,policy_key,policy_version,policy_status,value_tier,value_score,lifecycle,engagement,engagement_score,traits,explanation,segment_calculated_at,t from public.aos_cia_customer_segments_v1
 on conflict(contact_key) do update set policy_key=excluded.policy_key,policy_version=excluded.policy_version,policy_status=excluded.policy_status,value_tier=excluded.value_tier,value_score=excluded.value_score,lifecycle=excluded.lifecycle,engagement=excluded.engagement,engagement_score=excluded.engagement_score,traits=excluded.traits,explanation=excluded.explanation,segment_calculated_at=excluded.segment_calculated_at,cache_refreshed_at=excluded.cache_refreshed_at;
 get diagnostics n=row_count;return jsonb_build_object('ok',true,'rows',n,'refreshed_at',t);
end;$$;
revoke all on function public.aos_cia_refresh_segment_cache_v2() from public,anon,authenticated;
grant execute on function public.aos_cia_refresh_segment_cache_v2() to service_role;
