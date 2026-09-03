-- WA-L6 — Meta Campaign Context & Attribution V1
-- Evidence-driven only: no phone/name attribution, no lead/patient/Agenda/Sales mutation.

begin;

-- Extend the existing immutable WA-7A.3 adapter without changing its original column contract.
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
  coalesce(nullif(e.payload->>'evidence_version',''),'WA_7A_3_V1')::text as evidence_version,
  nullif(e.payload->>'campaign_id','')::text as provider_campaign_id,
  nullif(e.payload->>'adset_id','')::text as provider_adset_id,
  case
    when nullif(e.payload->>'ctwa_clid','') is not null
      or lower(coalesce(e.payload->>'source_type',''))='ad' then 'META_CTWA_PAID'
    when lower(coalesce(e.payload->>'source_type',''))='post' then 'META_POST_REFERRAL'
    else 'PROVIDER_REFERRAL_OTHER'
  end::text as acquisition_class
from public.aos_wa_events_v1 e
join public.aos_wa_messages_v1 m
  on m.provider_message_id=e.provider_message_id
left join public.aos_wa_identity_resolution_v1 i
  on i.conversation_id=m.conversation_id
where e.event_type='attribution.touchpoint';

comment on view public.aos_wa_attribution_touchpoints_v1 is
'WA-L6 extends WA-7A.3 immutable provider acquisition evidence with optional explicit provider campaign/adset ids and paid/referral classification. No phone/name attribution and no identity mutation.';
revoke all on public.aos_wa_attribution_touchpoints_v1 from public,anon,authenticated;
grant select on public.aos_wa_attribution_touchpoints_v1 to service_role;

-- Governance audit for the pre-existing fail-closed campaign map.
create table if not exists public.aos_wa_l6_campaign_context_audit_v1 (
  id uuid primary key default gen_random_uuid(),
  ad_id text not null,
  operation text not null check (operation in ('CREATE','UPDATE')),
  actor_id uuid not null,
  evidence_ref text not null,
  before_snapshot jsonb,
  after_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  constraint aos_wa_l6_campaign_context_audit_evidence_ck
    check (nullif(btrim(evidence_ref),'') is not null)
);

create index if not exists aos_wa_l6_campaign_context_audit_ad_idx
  on public.aos_wa_l6_campaign_context_audit_v1(ad_id,created_at desc);

alter table public.aos_wa_l6_campaign_context_audit_v1 enable row level security;
revoke all on public.aos_wa_l6_campaign_context_audit_v1 from public,anon,authenticated;
grant select on public.aos_wa_l6_campaign_context_audit_v1 to service_role;

create or replace function public.aos_wa_l6_campaign_context_audit_guard_v1()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  raise exception 'WA_L6_CAMPAIGN_AUDIT_APPEND_ONLY' using errcode='55000';
end
$$;

revoke all on function public.aos_wa_l6_campaign_context_audit_guard_v1() from public,anon,authenticated;
grant execute on function public.aos_wa_l6_campaign_context_audit_guard_v1() to service_role;

drop trigger if exists trg_aos_wa_l6_campaign_context_audit_guard_v1 on public.aos_wa_l6_campaign_context_audit_v1;
create trigger trg_aos_wa_l6_campaign_context_audit_guard_v1
before update or delete on public.aos_wa_l6_campaign_context_audit_v1
for each row execute function public.aos_wa_l6_campaign_context_audit_guard_v1();

-- The existing map remains read-only to runtime/browser. All writes pass this explicit 2FA authority.
create or replace function public.aos_wa_l6_campaign_context_upsert_v1(
  p_token text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid;
  v_ad text;
  v_campaign text;
  v_treatment uuid;
  v_promotion uuid;
  v_goal text;
  v_evidence text;
  v_active boolean:=true;
  v_media jsonb:='{}'::jsonb;
  v_before public.aos_wa4_campaign_context_map_v1%rowtype;
  v_after public.aos_wa4_campaign_context_map_v1%rowtype;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-marketing',true);
  if v_actor is null then
    v_actor:=public.aos_app_actor_v3(p_token,'admin-whatsapp',true);
  end if;
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_UNAUTHORIZED');
  end if;
  if p_payload is null or pg_catalog.jsonb_typeof(p_payload)<>'object' then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_PAYLOAD_INVALID');
  end if;

  v_ad:=pg_catalog.nullif(pg_catalog.btrim(p_payload->>'ad_id'),'');
  v_campaign:=pg_catalog.nullif(pg_catalog.btrim(p_payload->>'campaign_id'),'');
  v_goal:=pg_catalog.nullif(pg_catalog.upper(pg_catalog.btrim(p_payload->>'booking_goal')),'');
  v_evidence:=pg_catalog.nullif(pg_catalog.btrim(p_payload->>'evidence_ref'),'');
  if v_ad is null or pg_catalog.length(v_ad)>256 then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_AD_ID_REQUIRED');
  end if;
  if v_campaign is not null and pg_catalog.length(v_campaign)>256 then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_CAMPAIGN_ID_INVALID');
  end if;
  if v_evidence is null or pg_catalog.length(v_evidence)>1000 then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_EVIDENCE_REQUIRED');
  end if;
  if v_goal is not null and v_goal !~ '^[A-Z0-9_]{1,40}$' then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_BOOKING_GOAL_INVALID');
  end if;

  begin
    v_treatment:=(p_payload->>'treatment_entity_id')::uuid;
  exception when others then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_TREATMENT_ID_REQUIRED');
  end;
  if not exists(
    select 1 from public.aos_catalogo_servicios s
    where s.id=v_treatment
      and pg_catalog.upper(pg_catalog.coalesce(s.estado,'ACTIVO'))='ACTIVO'
      and pg_catalog.upper(pg_catalog.coalesce(s.tipo,'SERVICIO'))='SERVICIO'
  ) then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_TREATMENT_NOT_ACTIVE');
  end if;

  if pg_catalog.nullif(pg_catalog.btrim(p_payload->>'promotion_id'),'') is not null then
    begin
      v_promotion:=(p_payload->>'promotion_id')::uuid;
    exception when others then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_PROMOTION_ID_INVALID');
    end;
    if not exists(select 1 from public.aos_promociones p where p.id=v_promotion) then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_PROMOTION_NOT_FOUND');
    end if;
  end if;

  if p_payload ? 'active' then
    begin
      v_active:=(p_payload->>'active')::boolean;
    exception when others then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_ACTIVE_INVALID');
    end;
  end if;
  if p_payload ? 'media_strategy' then
    if pg_catalog.jsonb_typeof(p_payload->'media_strategy')<>'object' then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L6_MEDIA_STRATEGY_INVALID');
    end if;
    v_media:=p_payload->'media_strategy';
  end if;

  select * into v_before
  from public.aos_wa4_campaign_context_map_v1 m
  where m.ad_id=v_ad
  for update;

  insert into public.aos_wa4_campaign_context_map_v1(
    ad_id,campaign_id,treatment_entity_id,treatment_code,promotion_id,booking_goal,
    media_strategy,active,evidence_ref,created_at,updated_at
  ) values (
    v_ad,v_campaign,v_treatment,null,v_promotion,v_goal,
    v_media,v_active,v_evidence,pg_catalog.now(),pg_catalog.now()
  )
  on conflict(ad_id) do update set
    campaign_id=excluded.campaign_id,
    treatment_entity_id=excluded.treatment_entity_id,
    treatment_code=null,
    promotion_id=excluded.promotion_id,
    booking_goal=excluded.booking_goal,
    media_strategy=excluded.media_strategy,
    active=excluded.active,
    evidence_ref=excluded.evidence_ref,
    updated_at=pg_catalog.now()
  returning * into v_after;

  insert into public.aos_wa_l6_campaign_context_audit_v1(
    ad_id,operation,actor_id,evidence_ref,before_snapshot,after_snapshot
  ) values (
    v_ad,
    case when v_before.ad_id is null then 'CREATE' else 'UPDATE' end,
    v_actor,v_evidence,
    case when v_before.ad_id is null then null else pg_catalog.to_jsonb(v_before) end,
    pg_catalog.to_jsonb(v_after)
  );

  return pg_catalog.jsonb_build_object(
    'ok',true,'status','SAVED','ad_id',v_after.ad_id,'campaign_id',v_after.campaign_id,
    'treatment_entity_id',v_after.treatment_entity_id,'promotion_id',v_after.promotion_id,
    'booking_goal',v_after.booking_goal,'active',v_after.active,'evidence_ref',v_after.evidence_ref
  );
end
$$;

revoke all on function public.aos_wa_l6_campaign_context_upsert_v1(text,jsonb) from public;
grant execute on function public.aos_wa_l6_campaign_context_upsert_v1(text,jsonb) to anon,authenticated,service_role;

-- One row per conversation/touchpoint. Conversations without provider provenance remain explicitly un-attributed.
create or replace view public.aos_wa_l6_conversation_acquisition_v1
with (security_invoker=true, security_barrier=true)
as
select
  c.id as conversation_id,
  t.touchpoint_id,
  t.touchpoint_key,
  t.provider_message_id,
  t.touchpoint_at,
  pg_catalog.coalesce(t.acquisition_class,'NO_PROVIDER_ATTRIBUTION')::text as acquisition_class,
  t.ctwa_clid,
  t.ad_id,
  t.source_id,
  t.source_type,
  t.source_url,
  t.provider_lead_id,
  t.provider_campaign_id,
  t.provider_adset_id,
  m.campaign_id as governed_campaign_id,
  case
    when t.provider_campaign_id is not null and m.campaign_id is not null and t.provider_campaign_id<>m.campaign_id
      then null
    else pg_catalog.coalesce(t.provider_campaign_id,m.campaign_id)
  end::text as effective_campaign_id,
  case
    when t.provider_campaign_id is not null and m.campaign_id is not null and t.provider_campaign_id<>m.campaign_id
      then 'CONFLICT_FAIL_CLOSED'
    when t.provider_campaign_id is not null then 'PROVIDER_EVIDENCE'
    when m.campaign_id is not null then 'GOVERNED_AD_MAPPING'
    else 'UNRESOLVED'
  end::text as campaign_resolution_status,
  m.treatment_entity_id as mapped_treatment_id,
  m.promotion_id as mapped_promotion_id,
  m.booking_goal,
  m.evidence_ref as mapping_evidence_ref
from public.aos_wa_conversations_v1 c
left join public.aos_wa_attribution_touchpoints_v1 t
  on t.conversation_id=c.id
left join public.aos_wa4_campaign_context_map_v1 m
  on m.ad_id=t.ad_id and m.active is true;

revoke all on public.aos_wa_l6_conversation_acquisition_v1 from public,anon,authenticated;
grant select on public.aos_wa_l6_conversation_acquisition_v1 to service_role;

-- Strong-key-only attribution journey. Never joins on phone, name, username, BSUID or patient identity.
create or replace view public.aos_wa_l6_attribution_journey_v1
with (security_invoker=true, security_barrier=true)
as
with booking_chain as (
  select
    o.conversation_id,
    o.appointment_id,
    pg_catalog.min(o.created_at) filter (where o.operation_type='BOOK') as booked_at,
    pg_catalog.max(o.created_at) as last_booking_activity_at,
    pg_catalog.count(*) filter (where o.operation_type='BOOK')::integer as book_count,
    pg_catalog.count(*) filter (where o.operation_type='REBOOK')::integer as rebook_count,
    (pg_catalog.array_agg(o.treatment_id order by o.created_at))[1] as booking_treatment_id,
    (pg_catalog.array_agg(o.ad_id order by o.created_at) filter (where o.ad_id is not null))[1] as booking_ad_id,
    (pg_catalog.array_agg(o.campaign_source order by o.created_at) filter (where o.campaign_source is not null))[1] as booking_campaign_source,
    (pg_catalog.array_agg(o.lead_id order by o.created_at) filter (where o.lead_id is not null))[1] as booking_lead_id
  from public.aos_booking_operations_v2 o
  where o.channel='WHATSAPP' and o.conversation_id is not null
  group by o.conversation_id,o.appointment_id
), acquisition as (
  select
    a.*,
    pg_catalog.count(a.touchpoint_id) over(partition by a.conversation_id)::integer as conversation_touchpoint_count
  from public.aos_wa_l6_conversation_acquisition_v1 a
)
select
  acq.conversation_id,
  acq.touchpoint_id,
  acq.touchpoint_key,
  acq.provider_message_id,
  acq.touchpoint_at,
  acq.acquisition_class,
  acq.ctwa_clid,
  acq.ad_id as touchpoint_ad_id,
  acq.provider_campaign_id,
  acq.provider_adset_id,
  acq.governed_campaign_id,
  acq.effective_campaign_id,
  acq.campaign_resolution_status,
  acq.mapped_treatment_id,
  acq.mapped_promotion_id,
  acq.booking_goal,
  acq.mapping_evidence_ref,
  acq.conversation_touchpoint_count,
  b.appointment_id,
  b.booked_at,
  b.last_booking_activity_at,
  b.book_count,
  b.rebook_count,
  b.booking_treatment_id,
  b.booking_ad_id,
  b.booking_campaign_source,
  b.booking_lead_id,
  case
    when acq.touchpoint_id is null then null
    when b.booking_ad_id is null then null
    else b.booking_ad_id=acq.ad_id
  end as booking_ad_matches_touchpoint,
  a.estado_cita as appointment_status,
  case
    when pg_catalog.upper(pg_catalog.coalesce(a.estado_cita,'')) in ('ASISTIO','EFECTIVA') then true
    when pg_catalog.upper(pg_catalog.coalesce(a.estado_cita,'')) in ('NO ASISTIO','CANCELADA') then false
    else null
  end as attended,
  pg_catalog.nullif(pg_catalog.btrim(a.venta_id_match),'') as sale_link_venta_id,
  s.sale_row_count,
  s.sale_date,
  s.revenue_amount,
  s.revenue_currency,
  case
    when acq.touchpoint_id is null then 'NO_PROVIDER_ATTRIBUTION'
    when b.appointment_id is null then 'TOUCHPOINT_ONLY'
    when acq.conversation_touchpoint_count>1 then 'MULTIPLE_TOUCHPOINTS_REVIEW'
    when acq.campaign_resolution_status='CONFLICT_FAIL_CLOSED' then 'CAMPAIGN_ID_CONFLICT'
    when b.booking_ad_id is not null and acq.ad_id is not null and b.booking_ad_id<>acq.ad_id then 'BOOKING_AD_MISMATCH'
    when a.id is null then 'APPOINTMENT_MISSING'
    when pg_catalog.nullif(pg_catalog.btrim(a.venta_id_match),'') is null then 'APPOINTMENT_NO_EXPLICIT_SALE_LINK'
    when pg_catalog.coalesce(s.sale_row_count,0)=0 then 'SALE_LINK_UNRESOLVED'
    else 'EXPLICIT_CHAIN_COMPLETE'
  end::text as attribution_chain_status
from acquisition acq
left join booking_chain b
  on b.conversation_id=acq.conversation_id
left join public.aos_agenda_citas a
  on a.id=b.appointment_id
left join lateral (
  select
    pg_catalog.count(*)::integer as sale_row_count,
    pg_catalog.min(v.fecha) as sale_date,
    pg_catalog.sum(v.monto) as revenue_amount,
    case
      when pg_catalog.count(*)=0 then null
      when pg_catalog.count(distinct pg_catalog.coalesce(pg_catalog.nullif(pg_catalog.btrim(v.moneda),''),'PEN'))=1
        then pg_catalog.max(pg_catalog.coalesce(pg_catalog.nullif(pg_catalog.btrim(v.moneda),''),'PEN'))
      else 'MIXED'
    end::text as revenue_currency
  from public.aos_ventas v
  where v.venta_id=pg_catalog.nullif(pg_catalog.btrim(a.venta_id_match),'')
) s on true;

comment on view public.aos_wa_l6_attribution_journey_v1 is
'WA-L6 read-only strong-key journey: immutable provider touchpoint -> conversation_id -> AGV2 appointment_id -> Agenda attendance -> explicit venta_id_match -> canonical sale. No phone/name fallback; multiple touchpoints remain reviewable.';
revoke all on public.aos_wa_l6_attribution_journey_v1 from public,anon,authenticated;
grant select on public.aos_wa_l6_attribution_journey_v1 to service_role;

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
