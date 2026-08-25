-- WA-7A.2 rollback — safe only before identity verification/lineage evidence exists.
-- Once evidence exists, deleting lineage would be destructive and rollback must fail closed.

begin;

do $$
begin
  if exists(
    select 1 from public.aos_wa_events_v1
    where event_type in ('identity.meta_pair','identity.system_change','identity.contact_disclosure','identity.status_binding')
  ) then
    raise exception 'WA7A2_ROLLBACK_BLOCKED_IDENTITY_EVIDENCE_EXISTS';
  end if;
  if exists(
    select 1 from public.aos_wa_channel_aliases_v1
    where evidence_event_key is not null or superseded_by is not null or valid_to is not null
  ) then
    raise exception 'WA7A2_ROLLBACK_BLOCKED_ALIAS_LINEAGE_EXISTS';
  end if;
end
$$;

drop trigger if exists trg_aos_wa7a2_apply_identity_event_v1 on public.aos_wa_events_v1;
drop function if exists public.aos_wa7a2_apply_identity_event_v1();
drop function if exists public.aos_wa7a2_normalize_phone_v1(text);

drop index if exists public.aos_wa_channel_aliases_v1_evidence_idx;
drop index if exists public.aos_wa_channel_aliases_v1_lineage_idx;

alter table public.aos_wa_channel_aliases_v1 drop constraint if exists aos_wa_channel_aliases_v1_no_self_supersede_chk;
alter table public.aos_wa_channel_aliases_v1 drop constraint if exists aos_wa_channel_aliases_v1_superseded_fk;
alter table public.aos_wa_channel_aliases_v1 drop constraint if exists aos_wa_channel_aliases_v1_verification_status_chk;

alter table public.aos_wa_channel_aliases_v1
  drop column if exists supersession_reason,
  drop column if exists superseded_by,
  drop column if exists valid_to,
  drop column if exists evidence_event_key,
  drop column if exists verification_observed_at,
  drop column if exists verification_source,
  drop column if exists verification_status;

select pg_notify('pgrst','reload schema');
commit;
