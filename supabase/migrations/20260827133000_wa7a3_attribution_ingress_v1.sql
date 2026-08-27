-- WA-7A.3 — Attribution Ingress V1
-- Reuses the existing WA event ledger as immutable provenance storage.
-- No new customer/person/touchpoint table; no aos_leads, aos_pacientes or REV mutation.

begin;

-- Production drift reconciliation: WA-1 designed this ledger as append-only for runtime,
-- but broad service_role grants were later observed in production. Restore least privilege.
revoke update, delete, truncate, references, trigger on table public.aos_wa_events_v1 from service_role;
grant select, insert on table public.aos_wa_events_v1 to service_role;

create or replace function public.aos_wa7a3_touchpoint_immutable_guard_v1()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if old.event_type='attribution.touchpoint' then
    raise exception 'WA7A3_TOUCHPOINT_IMMUTABLE' using errcode='55000';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end
$$;

revoke all on function public.aos_wa7a3_touchpoint_immutable_guard_v1() from public, anon, authenticated;
grant execute on function public.aos_wa7a3_touchpoint_immutable_guard_v1() to service_role;

drop trigger if exists trg_aos_wa7a3_touchpoint_immutable_guard_v1 on public.aos_wa_events_v1;
create trigger trg_aos_wa7a3_touchpoint_immutable_guard_v1
before update or delete on public.aos_wa_events_v1
for each row execute function public.aos_wa7a3_touchpoint_immutable_guard_v1();

create or replace view public.aos_wa_attribution_touchpoints_v1
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
'WA-7A.3 private read-only adapter from immutable WhatsApp attribution events to conversation and optional WA-7A.1 canonical patient resolution. It exposes no phone, BSUID or username and performs no Marketing/REV/customer mutation.';
comment on function public.aos_wa7a3_touchpoint_immutable_guard_v1() is
'WA-7A.3 guard: accepted attribution.touchpoint evidence cannot be updated or deleted; runtime also lacks UPDATE/DELETE/TRUNCATE on the WA event ledger.';

revoke all on public.aos_wa_attribution_touchpoints_v1 from public, anon, authenticated;
grant select on public.aos_wa_attribution_touchpoints_v1 to service_role;

select pg_notify('pgrst','reload schema');

commit;
