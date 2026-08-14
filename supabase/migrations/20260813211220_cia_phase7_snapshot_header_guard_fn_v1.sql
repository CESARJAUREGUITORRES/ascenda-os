-- REMOTE SYNC: already applied live as 20260813211220.
create or replace function public.aos_cia_snapshot_header_guard_v1()
returns trigger
language plpgsql
set search_path=public
as $$
declare actual_count integer; actual_hash text;
begin
  if tg_op='DELETE' then raise exception 'SNAPSHOT_IMMUTABLE'; end if;
  if tg_op='INSERT' then
    if new.estado<>'BUILDING' or new.sealed_at is not null or new.membership_hash<>'' then raise exception 'SNAPSHOT_MUST_START_BUILDING'; end if;
    if not exists(select 1 from public.aos_audiencia_versiones v where v.id=new.audiencia_version_id and v.audiencia_id=new.audiencia_id) then raise exception 'SNAPSHOT_AUDIENCE_VERSION_MISMATCH'; end if;
    return new;
  end if;
  if old.estado<>'BUILDING' or new.estado<>'READY' then raise exception 'SNAPSHOT_IMMUTABLE'; end if;
  if new.id is distinct from old.id or new.audiencia_id is distinct from old.audiencia_id or new.audiencia_version_id is distinct from old.audiencia_version_id or new.filter_hash is distinct from old.filter_hash or new.resolved_at is distinct from old.resolved_at or new.created_by_user_id is distinct from old.created_by_user_id or new.created_at is distinct from old.created_at then raise exception 'SNAPSHOT_HEADER_FIELDS_IMMUTABLE'; end if;
  select count(*)::integer,encode(digest(coalesce(string_agg(m.contact_key,E'\n' order by m.contact_key),''),'sha256'),'hex') into actual_count,actual_hash from public.aos_audiencia_snapshot_miembros m where m.snapshot_id=old.id;
  if new.member_count<>actual_count or new.membership_hash<>actual_hash or new.sealed_at is null then raise exception 'SNAPSHOT_SEAL_MISMATCH'; end if;
  return new;
end;$$;