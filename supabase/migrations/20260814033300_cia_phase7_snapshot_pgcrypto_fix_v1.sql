-- ASCENDA CIA compatibility fix discovered during Phase 8 certification.
-- pgcrypto is installed in schema `extensions`; Phase 7 snapshot functions use search_path=public.
-- Qualify digest calls only. No change to snapshot semantics, auth, Call Center or operational writes.

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
  select count(*)::integer,
         encode(extensions.digest(coalesce(string_agg(m.contact_key,E'\n' order by m.contact_key),''),'sha256'),'hex')
  into actual_count,actual_hash
  from public.aos_audiencia_snapshot_miembros m where m.snapshot_id=old.id;
  if new.member_count<>actual_count or new.membership_hash<>actual_hash or new.sealed_at is null then raise exception 'SNAPSHOT_SEAL_MISMATCH'; end if;
  return new;
end;
$$;

create or replace function public.aos_cia_snapshot_create_admin_v1(p_token text,p_audience_id uuid,p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  auth jsonb; uid uuid; a record; v record; keys text[]; sid uuid; t timestamptz:=statement_timestamp(); mc integer; mh text; fh text;
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  uid:=(auth->>'user_id')::uuid;
  select id,estado,current_version into a from public.aos_audiencias where id=p_audience_id;
  if a.id is null then return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND'); end if;
  if a.estado<>'ACTIVE' then return jsonb_build_object('ok',false,'error','AUDIENCE_ARCHIVED'); end if;
  select id,version,filter_dsl into v from public.aos_audiencia_versiones where audiencia_id=a.id and version=coalesce(p_version,a.current_version);
  if v.id is null then return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND'); end if;
  select coalesce(array_agg(k order by k),array[]::text[]) into keys
  from (select distinct unnest(public.aos_cia_audience_resolve_node_v2(v.filter_dsl->'root',1)) k) q;
  mc:=coalesce(cardinality(keys),0);
  if mc>100000 then return jsonb_build_object('ok',false,'error','SNAPSHOT_TOO_LARGE','count',mc); end if;
  fh:=encode(extensions.digest(v.filter_dsl::text,'sha256'),'hex');
  select encode(extensions.digest(coalesce(string_agg(k,E'\n' order by k),''),'sha256'),'hex') into mh from unnest(keys) k;
  insert into public.aos_audiencia_snapshots(audiencia_id,audiencia_version_id,filter_hash,resolved_at,created_by_user_id)
  values(a.id,v.id,fh,t,uid) returning id into sid;
  insert into public.aos_audiencia_snapshot_miembros(snapshot_id,contact_key,identity_status,identity_conflict,resolved_at)
  select sid,k,i.identity_status,coalesce(i.identity_conflict,false),t
  from unnest(keys) k left join public.aos_cia_contact_identity_v1 i on i.contact_key=k;
  update public.aos_audiencia_snapshots
  set estado='READY',member_count=mc,membership_hash=mh,sealed_at=clock_timestamp()
  where id=sid;
  return jsonb_build_object('ok',true,'snapshot',jsonb_build_object('id',sid,'audience_id',a.id,'audience_version_id',v.id,'audience_version',v.version,'member_count',mc,'membership_hash',mh,'filter_hash',fh,'resolved_at',t,'estado','READY'));
end;
$$;
