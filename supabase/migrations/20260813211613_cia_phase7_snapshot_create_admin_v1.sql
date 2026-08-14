-- REMOTE SYNC: already applied live as 20260813211613.
-- Mutating RPC requires a valid CIA admin token before any write.
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
  select coalesce(array_agg(k order by k),array[]::text[]) into keys from (select distinct unnest(public.aos_cia_audience_resolve_node_v2(v.filter_dsl->'root',1)) k) q;
  mc:=coalesce(cardinality(keys),0);
  if mc>100000 then return jsonb_build_object('ok',false,'error','SNAPSHOT_TOO_LARGE','count',mc); end if;
  fh:=encode(digest(v.filter_dsl::text,'sha256'),'hex');
  select encode(digest(coalesce(string_agg(k,E'\n' order by k),''),'sha256'),'hex') into mh from unnest(keys) k;
  insert into public.aos_audiencia_snapshots(audiencia_id,audiencia_version_id,filter_hash,resolved_at,created_by_user_id) values(a.id,v.id,fh,t,uid) returning id into sid;
  insert into public.aos_audiencia_snapshot_miembros(snapshot_id,contact_key,identity_status,identity_conflict,resolved_at)
  select sid,k,i.identity_status,coalesce(i.identity_conflict,false),t from unnest(keys) k left join public.aos_cia_contact_identity_v1 i on i.contact_key=k;
  update public.aos_audiencia_snapshots set estado='READY',member_count=mc,membership_hash=mh,sealed_at=clock_timestamp() where id=sid;
  return jsonb_build_object('ok',true,'snapshot',jsonb_build_object('id',sid,'audience_id',a.id,'audience_version_id',v.id,'audience_version',v.version,'member_count',mc,'membership_hash',mh,'filter_hash',fh,'resolved_at',t,'estado','READY'));
end;$$;