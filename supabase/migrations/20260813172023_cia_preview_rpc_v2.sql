create or replace function public.aos_cia_audience_preview_v2(p_filter jsonb,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql stable security invoker as $$
declare
 v jsonb;keys text[];page_keys text[];
 lim integer:=greatest(1,least(coalesce(p_limit,50),100));
 offv integer:=greatest(0,coalesce(p_offset,0));
 items jsonb;seg_fresh timestamptz;email_fresh timestamptz;
begin
 v:=public.aos_cia_audience_validate_v1(p_filter);
 if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v);end if;
 keys:=public.aos_cia_audience_resolve_node_v2(p_filter->'root',1);
 select coalesce(array_agg(k order by k),array[]::text[]) into page_keys
 from(select k from unnest(keys) k order by k limit lim offset offv) q;
 select coalesce(jsonb_agg(jsonb_build_object(
  'contact_key',c.contact_key,'identity_status',c.identity_status,'identity_conflict',c.identity_conflict,
  'name',c.contact_name,'patient_state',c.patient_state,
  'branch',coalesce(c.raw_branch,a.latest_sale_branch,a.next_appointment_branch),'age_band',c.age_band,
  'value_tier',c.value_tier,'lifecycle',c.lifecycle,'engagement',c.engagement,'traits',c.traits,
  'latest_interest',a.latest_interest,'last_call_at',a.last_call_at,'latest_call_status',a.latest_call_status,
  'has_future_appointment',(a.next_appointment_at is not null),'next_appointment_at',a.next_appointment_at,
  'sale_count',a.sale_count,'revenue_lifetime',a.revenue_lifetime,
  'pending_followups',a.pending_followups,'overdue_followups',a.overdue_followups,
  'email_never_sent',c.email_never_sent) order by c.contact_key),'[]'::jsonb) into items
 from public.aos_cia_preview_core_v2(page_keys)c
 join public.aos_cia_preview_activity_v2(page_keys)a using(contact_key);
 select max(cache_refreshed_at) into seg_fresh from public.aos_cia_segment_runtime_cache_v2;
 select max(cache_refreshed_at) into email_fresh from public.aos_cia_email_runtime_cache_v2;
 return jsonb_build_object('ok',true,'count',cardinality(keys),'limit',lim,'offset',offv,'items',items,
  'resolver_version',2,'segment_cache_refreshed_at',seg_fresh,'email_cache_refreshed_at',email_fresh,
  'observed_at',statement_timestamp());
end;$$;
revoke all on function public.aos_cia_audience_preview_v2(jsonb,integer,integer) from public,anon,authenticated;
grant execute on function public.aos_cia_audience_preview_v2(jsonb,integer,integer) to service_role;
