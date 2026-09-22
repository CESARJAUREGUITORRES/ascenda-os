begin;

create or replace function public.aos_cia_snapshot_create_admin_v1(
  p_token text,
  p_audience_id uuid,
  p_version integer default null::integer
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  auth jsonb;
  uid uuid;
  a record;
  v record;
  keys text[];
  sid uuid;
  t timestamptz:=statement_timestamp();
  mc integer;
  mh text;
  fh text;
  v_preset_key text;
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  uid:=(auth->>'user_id')::uuid;

  select id,estado,current_version into a
  from public.aos_audiencias
  where id=p_audience_id;

  if a.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND');
  end if;
  if a.estado<>'ACTIVE' then
    return jsonb_build_object('ok',false,'error','AUDIENCE_ARCHIVED');
  end if;

  select id,version,filter_dsl into v
  from public.aos_audiencia_versiones
  where audiencia_id=a.id
    and version=coalesce(p_version,a.current_version);

  if v.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND');
  end if;

  select p.preset_key into v_preset_key
  from public.aos_audience_presets p
  where p.active=true
    and p.dsl=v.filter_dsl
  order by p.preset_key
  limit 1;

  if v_preset_key is not null then
    select coalesce(array_agg(c.contact_key order by c.contact_key),array[]::text[])
      into keys
    from public.aos_cia_workspace_catalog_members_v1(v_preset_key) c;
  else
    select coalesce(array_agg(k order by k),array[]::text[])
      into keys
    from (
      select distinct unnest(
        public.aos_cia_audience_resolve_node_v2(v.filter_dsl->'root',1)
      ) k
    ) q;
  end if;

  mc:=coalesce(cardinality(keys),0);
  if mc>100000 then
    return jsonb_build_object('ok',false,'error','SNAPSHOT_TOO_LARGE','count',mc);
  end if;

  fh:=encode(extensions.digest(v.filter_dsl::text,'sha256'),'hex');

  select encode(
    extensions.digest(coalesce(string_agg(k,E'\\n' order by k),''),'sha256'),
    'hex'
  ) into mh
  from unnest(keys) k;

  insert into public.aos_audiencia_snapshots(
    audiencia_id,audiencia_version_id,filter_hash,resolved_at,created_by_user_id
  )
  values(a.id,v.id,fh,t,uid)
  returning id into sid;

  if v_preset_key is not null then
    insert into public.aos_audiencia_snapshot_miembros(
      snapshot_id,contact_key,identity_status,identity_conflict,resolved_at
    )
    select
      sid,
      k,
      null,
      coalesce(c.identity_conflict,false),
      t
    from unnest(keys) k
    left join public.aos_cia_contact_runtime_cache_v1 c
      on c.contact_key=k;
  else
    insert into public.aos_audiencia_snapshot_miembros(
      snapshot_id,contact_key,identity_status,identity_conflict,resolved_at
    )
    select
      sid,
      k,
      i.identity_status,
      coalesce(i.identity_conflict,false),
      t
    from unnest(keys) k
    left join public.aos_cia_contact_identity_v1 i
      on i.contact_key=k;
  end if;

  update public.aos_audiencia_snapshots
  set estado='READY',
      member_count=mc,
      membership_hash=mh,
      sealed_at=clock_timestamp()
  where id=sid;

  return jsonb_build_object(
    'ok',true,
    'snapshot',jsonb_build_object(
      'id',sid,
      'audience_id',a.id,
      'audience_version_id',v.id,
      'audience_version',v.version,
      'member_count',mc,
      'membership_hash',mh,
      'filter_hash',fh,
      'resolved_at',t,
      'estado','READY'
    )
  );
end;
$function$;

create or replace function public.aos_cia_activation_create_admin_v1(
  p_token text,
  p_audience_id uuid,
  p_version integer,
  p_name text,
  p_purpose text,
  p_channel text,
  p_mode text,
  p_start_now boolean default false,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  auth jsonb;
  uid uuid;
  a record;
  v record;
  cntj jsonb;
  cnt integer;
  t timestamptz:=statement_timestamp();
  snap jsonb;
  sid uuid;
  actid uuid;
  md jsonb:=coalesce(p_metadata,'{}'::jsonb);
  ch text:=upper(btrim(coalesce(p_channel,'')));
  mo text:=upper(btrim(coalesce(p_mode,'')));
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  uid:=(auth->>'user_id')::uuid;

  if char_length(btrim(coalesce(p_name,''))) not between 3 and 120 then
    return jsonb_build_object('ok',false,'error','INVALID_NAME');
  end if;
  if char_length(btrim(coalesce(p_purpose,''))) not between 2 and 120 then
    return jsonb_build_object('ok',false,'error','INVALID_PURPOSE');
  end if;
  if ch not in ('CALL','EMAIL','SMS','WHATSAPP','AUTOMATION','ANALYSIS','OTHER') then
    return jsonb_build_object('ok',false,'error','INVALID_CHANNEL');
  end if;
  if mo not in ('BATCH','DYNAMIC') then
    return jsonb_build_object('ok',false,'error','INVALID_MODE');
  end if;
  if jsonb_typeof(md)<>'object' or pg_column_size(md)>32768 then
    return jsonb_build_object('ok',false,'error','INVALID_METADATA');
  end if;

  select id,estado,current_version into a
  from public.aos_audiencias
  where id=p_audience_id;

  if a.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND');
  end if;
  if a.estado<>'ACTIVE' then
    return jsonb_build_object('ok',false,'error','AUDIENCE_ARCHIVED');
  end if;

  select id,version,filter_dsl into v
  from public.aos_audiencia_versiones
  where audiencia_id=a.id
    and version=coalesce(p_version,a.current_version);

  if v.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND');
  end if;

  sid:=null;

  if mo='BATCH' then
    snap:=public.aos_cia_snapshot_create_admin_v1(p_token,a.id,v.version);
    if not coalesce((snap->>'ok')::boolean,false) then
      return snap;
    end if;
    sid:=(snap#>>'{snapshot,id}')::uuid;
    cnt:=coalesce((snap#>>'{snapshot,member_count}')::integer,0);
  else
    cntj:=public.aos_cia_audience_count_v2(v.filter_dsl);
    if not coalesce((cntj->>'ok')::boolean,false) then
      return jsonb_build_object('ok',false,'error','COUNT_FAILED');
    end if;
    cnt:=coalesce((cntj->>'count')::integer,0);
  end if;

  insert into public.aos_audiencia_activaciones(audiencia_id,audiencia_version_id)
  values(a.id,v.id)
  returning id into actid;

  insert into public.aos_audiencia_activacion_config(
    activacion_id,snapshot_id,nombre,purpose,channel,mode,
    baseline_count,baseline_resolved_at,metadata,created_by_user_id
  )
  values(
    actid,sid,btrim(p_name),btrim(p_purpose),ch,mo,cnt,t,
    md||jsonb_build_object('context_only',true,'phase',7),
    uid
  );

  insert into public.aos_audiencia_activacion_estado(
    activacion_id,estado,updated_by_user_id
  )
  values(actid,'DRAFT',uid);

  if coalesce(p_start_now,false) then
    update public.aos_audiencia_activacion_estado
    set estado='ACTIVE',
        updated_by_user_id=uid,
        started_at=clock_timestamp(),
        ended_at=null
    where activacion_id=actid;
  end if;

  return jsonb_build_object(
    'ok',true,
    'activation_id',actid,
    'snapshot_id',sid,
    'mode',mo,
    'state',case when p_start_now then 'ACTIVE' else 'DRAFT' end,
    'baseline_count',cnt,
    'baseline_resolved_at',t,
    'context_only',true
  );
end;
$function$;

comment on function public.aos_cia_snapshot_create_admin_v1(text,uuid,integer)
is 'CIA snapshot creator. Catalog-equivalent audiences use the runtime-cache membership fast path; custom audiences retain the canonical resolver fallback.';

comment on function public.aos_cia_activation_create_admin_v1(text,uuid,integer,text,text,text,text,boolean,jsonb)
is 'CIA activation creator. BATCH activations derive baseline_count from the sealed snapshot and avoid duplicate audience resolution.';

commit;
