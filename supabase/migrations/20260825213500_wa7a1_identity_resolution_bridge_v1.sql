-- WA-7A.1 — Identity Resolution Bridge V1
-- Minimal, read-only bridge from WhatsApp channel aliases to the existing REV Patient Identity Bridge V2.
-- No customer/person master is created. No aos_pacientes / REV canonical mutation is performed.

begin;

create or replace view public.aos_wa_identity_resolution_v1 as
with alias_counts as (
  select
    a.conversation_id,
    count(*) filter (where a.active and a.alias_type='PHONE')::integer as phone_alias_count,
    count(*) filter (where a.active and a.alias_type='BSUID')::integer as bsuid_alias_count,
    count(*) filter (where a.active and a.alias_type='PARENT_BSUID')::integer as parent_bsuid_alias_count
  from public.aos_wa_channel_aliases_v1 a
  group by a.conversation_id
), phone_aliases as (
  select
    a.id as alias_id,
    a.conversation_id,
    public.aos_rev_normalize_patient_identifier_v2('PHONE',a.alias_value) as phone_key
  from public.aos_wa_channel_aliases_v1 a
  where a.active is true
    and a.alias_type='PHONE'
), rev_hits as (
  select
    p.alias_id,
    p.conversation_id,
    p.phone_key,
    r.canonical_patient_id,
    r.status as rev_status,
    r.confidence_band,
    r.candidate_count,
    r.has_reviewed_match
  from phone_aliases p
  left join public.aos_rev_patient_identity_alias_v2 r
    on r.identifier_type='PHONE'
   and r.identifier_key=p.phone_key
), resolved as (
  select
    h.conversation_id,
    count(distinct h.alias_id) filter (where h.canonical_patient_id is not null)::integer as matched_phone_alias_count,
    count(distinct h.alias_id) filter (where h.canonical_patient_id is null)::integer as unresolved_phone_alias_count,
    count(distinct h.canonical_patient_id) filter (where h.canonical_patient_id is not null)::integer as canonical_candidate_count,
    bool_or(coalesce(h.candidate_count,0)>1 or h.rev_status='CONFLICT') as has_rev_conflict,
    bool_or(coalesce(h.has_reviewed_match,false)) as has_reviewed_match,
    min(h.canonical_patient_id) filter (where h.canonical_patient_id is not null) as only_candidate
  from rev_hits h
  group by h.conversation_id
)
select
  c.id as conversation_id,
  case
    when coalesce(a.phone_alias_count,0)=0 then 'UNRESOLVED'
    when coalesce(r.has_rev_conflict,false) then 'IDENTITY_CONFLICT'
    when coalesce(r.canonical_candidate_count,0)>1 then 'IDENTITY_CONFLICT'
    when coalesce(r.canonical_candidate_count,0)=1 then 'MATCH'
    else 'UNRESOLVED'
  end::text as resolution_status,
  case
    when coalesce(r.has_rev_conflict,false) then null
    when coalesce(r.canonical_candidate_count,0)=1 then r.only_candidate
    else null
  end::text as canonical_patient_id,
  coalesce(r.canonical_candidate_count,0)::integer as canonical_candidate_count,
  coalesce(a.phone_alias_count,0)::integer as phone_alias_count,
  coalesce(a.bsuid_alias_count,0)::integer as bsuid_alias_count,
  coalesce(a.parent_bsuid_alias_count,0)::integer as parent_bsuid_alias_count,
  coalesce(r.matched_phone_alias_count,0)::integer as matched_phone_alias_count,
  coalesce(r.unresolved_phone_alias_count,0)::integer as unresolved_phone_alias_count,
  case
    when coalesce(r.has_rev_conflict,false) or coalesce(r.canonical_candidate_count,0)>1 then null
    when coalesce(r.canonical_candidate_count,0)=1 and coalesce(r.has_reviewed_match,false) then 'HIGH'
    when coalesce(r.canonical_candidate_count,0)=1 then 'MEDIUM'
    else null
  end::text as confidence_band,
  case
    when coalesce(a.phone_alias_count,0)=0 then 'NO_PHONE_EVIDENCE'
    when coalesce(r.has_rev_conflict,false) or coalesce(r.canonical_candidate_count,0)>1 then 'REV_IDENTITY_CONFLICT'
    when coalesce(r.canonical_candidate_count,0)=1 then 'REV_PATIENT_IDENTITY_ALIAS_V2'
    else 'REV_UNRESOLVED'
  end::text as resolution_method
from public.aos_wa_conversations_v1 c
left join alias_counts a on a.conversation_id=c.id
left join resolved r on r.conversation_id=c.id;

comment on view public.aos_wa_identity_resolution_v1 is
'WA-7A.1 read-only bridge. A WhatsApp conversation inherits canonical patient resolution only from governed PHONE aliases already resolved by REV Patient Identity Bridge V2. BSUID/username never resolve a person by themselves; conflicts remain fail-closed.';

revoke all on public.aos_wa_identity_resolution_v1 from public, anon, authenticated;
grant select on public.aos_wa_identity_resolution_v1 to service_role;

create or replace function public.aos_wa7a1_resolve_conversation_identity_v1(
  p_token text,
  p_conversation_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_wa_actor jsonb;
  v_wa_actor_id uuid;
  v_patient_actor uuid;
  v_r record;
begin
  if p_conversation_id is null then
    return jsonb_build_object('ok',false,'status','INVALID_CONVERSATION_ID');
  end if;

  v_wa_actor:=public.aos_wa3_actor_v1(p_token);
  if coalesce((v_wa_actor->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'status','WA_2FA_PANEL_REQUIRED');
  end if;
  v_wa_actor_id:=nullif(v_wa_actor->>'actor_id','')::uuid;

  v_patient_actor:=public.aos_app_actor_v3(p_token,'advisor-patients',true);
  if v_patient_actor is null then
    v_patient_actor:=public.aos_app_actor_v3(p_token,'admin-patients',true);
  end if;
  if v_patient_actor is null then
    return jsonb_build_object('ok',false,'status','PATIENT_360_PERMISSION_REQUIRED');
  end if;
  if v_patient_actor is distinct from v_wa_actor_id then
    return jsonb_build_object('ok',false,'status','ACTOR_SCOPE_MISMATCH');
  end if;

  select * into v_r
  from public.aos_wa_identity_resolution_v1
  where conversation_id=p_conversation_id;

  if not found then
    return jsonb_build_object('ok',false,'status','CONVERSATION_NOT_FOUND');
  end if;

  return jsonb_build_object(
    'ok',true,
    'status',v_r.resolution_status,
    'canonical_patient_id',v_r.canonical_patient_id,
    'canonical_candidate_count',v_r.canonical_candidate_count,
    'confidence_band',v_r.confidence_band,
    'resolution_method',v_r.resolution_method,
    'evidence',jsonb_build_object(
      'phone_alias_count',v_r.phone_alias_count,
      'bsuid_alias_count',v_r.bsuid_alias_count,
      'parent_bsuid_alias_count',v_r.parent_bsuid_alias_count,
      'matched_phone_alias_count',v_r.matched_phone_alias_count,
      'unresolved_phone_alias_count',v_r.unresolved_phone_alias_count
    )
  );
end;
$$;

comment on function public.aos_wa7a1_resolve_conversation_identity_v1(text,uuid) is
'WA-7A.1 Auth V3/2FA read bridge for Customer 360. Reuses REV identity authority; performs no patient merge or canonical mutation and exposes no raw alias values.';

revoke all on function public.aos_wa7a1_resolve_conversation_identity_v1(text,uuid) from public;
grant execute on function public.aos_wa7a1_resolve_conversation_identity_v1(text,uuid) to anon, authenticated, service_role;

select pg_notify('pgrst','reload schema');

commit;
