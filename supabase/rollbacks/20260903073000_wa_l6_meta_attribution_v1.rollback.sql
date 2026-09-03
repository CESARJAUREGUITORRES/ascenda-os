-- WA-L6 recovery. Existing WA-7A.3 touchpoint semantics and pre-L6 campaign map are preserved.

begin;

do $$
begin
  if to_regclass('public.aos_wa_l6_campaign_context_audit_v1') is not null
     and exists(select 1 from public.aos_wa_l6_campaign_context_audit_v1) then
    raise exception 'WA_L6_RECOVERY_BLOCKED_HISTORY';
  end if;
end
$$;

drop view if exists public.aos_wa_l6_attribution_journey_v1;
drop view if exists public.aos_wa_l6_conversation_acquisition_v1;
drop function if exists public.aos_wa_l6_campaign_context_upsert_v1(text,jsonb);
drop trigger if exists trg_aos_wa_l6_campaign_context_audit_guard_v1 on public.aos_wa_l6_campaign_context_audit_v1;
drop function if exists public.aos_wa_l6_campaign_context_audit_guard_v1();
drop table if exists public.aos_wa_l6_campaign_context_audit_v1;

-- CREATE OR REPLACE cannot remove appended columns from a view. L6-owned dependents are
-- already gone, so explicitly drop the adapter and recreate the certified WA-7A.3 shape.
drop view if exists public.aos_wa_attribution_touchpoints_v1;
create view public.aos_wa_attribution_touchpoints_v1
with (security_invoker=true, security_barrier=true)
as
select
  e.id as touchpoint_id,
  e.event_key as touchpoint_key,
  e.provider_message_id,
  m.conversation_id,
  case when i.resolution_status='MATCH' then i.canonical_patient_id else null end::text as canonical_patient_id,
  coalesce(i.resolution_status,'UNRESOLVED')::text as identity_resolution_status,
  i.confidence_band::text as identity_confidence_band,
  nullif(e.payload->>'ctwa_clid','')::text as ctwa_clid,
  nullif(e.payload->>'source_id','')::text as source_id,
  nullif(e.payload->>'source_type','')::text as source_type,
  nullif(e.payload->>'source_url','')::text as source_url,
  nullif(e.payload->>'ad_id','')::text as ad_id,
  nullif(e.payload->>'provider_lead_id','')::text as provider_lead_id,
  nullif(e.payload->>'campaign_source','')::text as campaign_source,
  nullif(e.payload->>'headline','')::text as headline,
  nullif(e.payload->>'body','')::text as body,
  nullif(e.payload->>'media_type','')::text as media_type,
  coalesce(m.provider_timestamp,e.created_at) as touchpoint_at,
  e.created_at as persisted_at,
  coalesce(nullif(e.payload->>'evidence_version',''),'WA_7A_3_V1')::text as evidence_version
from public.aos_wa_events_v1 e
join public.aos_wa_messages_v1 m
  on m.provider_message_id=e.provider_message_id
left join public.aos_wa_identity_resolution_v1 i
  on i.conversation_id=m.conversation_id
where e.event_type='attribution.touchpoint';

comment on view public.aos_wa_attribution_touchpoints_v1 is
'WA-7A.3 private derived attribution adapter over sanitized WA evidence. Read-only; identity and attribution remain separate facts.';
revoke all on public.aos_wa_attribution_touchpoints_v1 from public,anon,authenticated;
grant select on public.aos_wa_attribution_touchpoints_v1 to service_role;
select pg_catalog.pg_notify('pgrst','reload schema');
commit;
