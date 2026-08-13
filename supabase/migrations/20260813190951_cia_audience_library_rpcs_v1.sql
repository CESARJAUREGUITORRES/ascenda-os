-- ASCENDA CIA Phase 6 — internal audience library contracts.

create or replace function public.aos_cia_admin_user_ok_v1(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1 from public.aos_usuarios u
    where u.id=p_user_id and u.activo=true and lower(coalesce(u.rol,''))='admin'
  );
$$;

revoke all on function public.aos_cia_admin_user_ok_v1(uuid) from public, anon, authenticated;
grant execute on function public.aos_cia_admin_user_ok_v1(uuid) to service_role;

create or replace function public.aos_cia_audience_library_list_v1(
  p_include_archived boolean default false,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  lim integer:=greatest(1,least(coalesce(p_limit,50),100));
  offv integer:=greatest(0,coalesce(p_offset,0));
  total integer;
  items jsonb;
begin
  select count(*)::integer into total
  from public.aos_audiencias a
  where p_include_archived or a.estado='ACTIVE';

  select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into items
  from (
    select
      a.id,a.nombre,a.descripcion,a.tipo,a.estado,a.schema_version,a.current_version,
      a.created_at,a.updated_at,a.archived_at,
      v.id as current_version_id,v.filter_dsl,v.count_cache,v.resolved_at,v.reason as current_reason,v.created_at as version_created_at,
      cu.nombre as created_by,uu.nombre as updated_by
    from public.aos_audiencias a
    join public.aos_audiencia_versiones v on v.audiencia_id=a.id and v.version=a.current_version
    left join public.aos_usuarios cu on cu.id=a.created_by_user_id
    left join public.aos_usuarios uu on uu.id=a.updated_by_user_id
    where p_include_archived or a.estado='ACTIVE'
    order by (a.estado='ACTIVE') desc,a.updated_at desc,a.nombre
    limit lim offset offv
  ) q;

  return jsonb_build_object('ok',true,'items',items,'total',total,'limit',lim,'offset',offv);
end;
$$;

create or replace function public.aos_cia_audience_library_get_v1(p_audience_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare outj jsonb;
begin
  select jsonb_build_object(
    'ok',true,
    'audience',jsonb_build_object(
      'id',a.id,'nombre',a.nombre,'descripcion',a.descripcion,'tipo',a.tipo,'estado',a.estado,
      'schema_version',a.schema_version,'current_version',a.current_version,
      'created_at',a.created_at,'updated_at',a.updated_at,'archived_at',a.archived_at,
      'created_by',cu.nombre,'updated_by',uu.nombre
    ),
    'current',jsonb_build_object(
      'id',cv.id,'version',cv.version,'filter_dsl',cv.filter_dsl,'reason',cv.reason,
      'count_cache',cv.count_cache,'resolved_at',cv.resolved_at,'created_at',cv.created_at
    ),
    'versions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',v.id,'version',v.version,'filter_dsl',v.filter_dsl,'reason',v.reason,
        'count_cache',v.count_cache,'resolved_at',v.resolved_at,'created_at',v.created_at,'created_by',vu.nombre
      ) order by v.version desc)
      from public.aos_audiencia_versiones v
      left join public.aos_usuarios vu on vu.id=v.created_by_user_id
      where v.audiencia_id=a.id
    ),'[]'::jsonb)
  ) into outj
  from public.aos_audiencias a
  join public.aos_audiencia_versiones cv on cv.audiencia_id=a.id and cv.version=a.current_version
  left join public.aos_usuarios cu on cu.id=a.created_by_user_id
  left join public.aos_usuarios uu on uu.id=a.updated_by_user_id
  where a.id=p_audience_id;

  return coalesce(outj,jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND'));
end;
$$;

create or replace function public.aos_cia_audience_library_create_v1(
  p_user_id uuid,
  p_name text,
  p_description text,
  p_filter jsonb,
  p_reason text default 'CREATE'
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  nm text:=btrim(coalesce(p_name,''));
  ds text:=coalesce(p_description,'');
  rs text:=left(coalesce(p_reason,'CREATE'),500);
  valj jsonb;
  cntj jsonb;
  cnt integer;
  aid uuid;
  vid uuid;
begin
  if not public.aos_cia_admin_user_ok_v1(p_user_id) then return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED'); end if;
  if char_length(nm) not between 3 and 120 then return jsonb_build_object('ok',false,'error','INVALID_NAME'); end if;
  if char_length(ds)>1000 then return jsonb_build_object('ok',false,'error','DESCRIPTION_TOO_LONG'); end if;
  if p_filter is null then return jsonb_build_object('ok',false,'error','FILTER_REQUIRED'); end if;
  valj:=public.aos_cia_audience_validate_v1(p_filter);
  if not coalesce((valj->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'error','DSL_INVALID','validation',valj); end if;
  cntj:=public.aos_cia_audience_count_v2(p_filter);
  if not coalesce((cntj->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','COUNT_FAILED'); end if;
  cnt:=coalesce((cntj->>'count')::integer,0);

  insert into public.aos_audiencias(nombre,descripcion,created_by_user_id,updated_by_user_id)
  values(nm,ds,p_user_id,p_user_id) returning id into aid;

  insert into public.aos_audiencia_versiones(audiencia_id,version,filter_dsl,reason,count_cache,resolved_at,created_by_user_id)
  values(aid,1,p_filter,rs,cnt,now(),p_user_id) returning id into vid;

  insert into public.aos_audiencia_audit(audiencia_id,audiencia_version_id,action,actor_user_id,after_state)
  values(aid,vid,'CREATE',p_user_id,jsonb_build_object('nombre',nm,'version',1,'count_at_save',cnt));

  return public.aos_cia_audience_library_get_v1(aid) || jsonb_build_object('operation','CREATE');
exception
  when unique_violation then return jsonb_build_object('ok',false,'error','NAME_CONFLICT');
  when check_violation then return jsonb_build_object('ok',false,'error','CONSTRAINT_VIOLATION');
end;
$$;

create or replace function public.aos_cia_audience_library_update_v1(
  p_user_id uuid,
  p_audience_id uuid,
  p_expected_version integer,
  p_name text,
  p_description text,
  p_filter jsonb,
  p_reason text default 'UPDATE'
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  a public.aos_audiencias%rowtype;
  oldv public.aos_audiencia_versiones%rowtype;
  nm text;
  ds text;
  fdsl jsonb;
  rs text:=left(coalesce(p_reason,'UPDATE'),500);
  valj jsonb;
  cntj jsonb;
  cnt integer;
  newver integer;
  vid uuid;
begin
  if not public.aos_cia_admin_user_ok_v1(p_user_id) then return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED'); end if;
  if p_expected_version is null then return jsonb_build_object('ok',false,'error','EXPECTED_VERSION_REQUIRED'); end if;

  select * into a from public.aos_audiencias where id=p_audience_id for update;
  if a.id is null then return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND'); end if;
  if a.estado<>'ACTIVE' then return jsonb_build_object('ok',false,'error','AUDIENCE_ARCHIVED'); end if;
  if a.current_version<>p_expected_version then
    return jsonb_build_object('ok',false,'error','VERSION_CONFLICT','current_version',a.current_version,'expected_version',p_expected_version);
  end if;
  select * into oldv from public.aos_audiencia_versiones where audiencia_id=a.id and version=a.current_version;

  nm:=btrim(coalesce(p_name,a.nombre));
  ds:=coalesce(p_description,a.descripcion);
  fdsl:=coalesce(p_filter,oldv.filter_dsl);
  if char_length(nm) not between 3 and 120 then return jsonb_build_object('ok',false,'error','INVALID_NAME'); end if;
  if char_length(ds)>1000 then return jsonb_build_object('ok',false,'error','DESCRIPTION_TOO_LONG'); end if;
  valj:=public.aos_cia_audience_validate_v1(fdsl);
  if not coalesce((valj->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'error','DSL_INVALID','validation',valj); end if;
  cntj:=public.aos_cia_audience_count_v2(fdsl);
  if not coalesce((cntj->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','COUNT_FAILED'); end if;
  cnt:=coalesce((cntj->>'count')::integer,0);
  newver:=a.current_version+1;

  insert into public.aos_audiencia_versiones(audiencia_id,version,filter_dsl,reason,count_cache,resolved_at,created_by_user_id)
  values(a.id,newver,fdsl,rs,cnt,now(),p_user_id) returning id into vid;

  update public.aos_audiencias
  set nombre=nm,descripcion=ds,current_version=newver,updated_by_user_id=p_user_id
  where id=a.id;

  insert into public.aos_audiencia_audit(audiencia_id,audiencia_version_id,action,actor_user_id,before_state,after_state)
  values(a.id,vid,'VERSION_CREATE',p_user_id,
    jsonb_build_object('nombre',a.nombre,'version',a.current_version),
    jsonb_build_object('nombre',nm,'version',newver,'count_at_save',cnt));

  return public.aos_cia_audience_library_get_v1(a.id) || jsonb_build_object('operation','VERSION_CREATE');
exception
  when unique_violation then return jsonb_build_object('ok',false,'error','NAME_CONFLICT');
  when check_violation then return jsonb_build_object('ok',false,'error','CONSTRAINT_VIOLATION');
end;
$$;

create or replace function public.aos_cia_audience_library_duplicate_v1(
  p_user_id uuid,
  p_source_audience_id uuid,
  p_name text,
  p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  src public.aos_audiencias%rowtype;
  sv public.aos_audiencia_versiones%rowtype;
  nm text:=btrim(coalesce(p_name,''));
  ds text;
  cntj jsonb;
  cnt integer;
  aid uuid;
  vid uuid;
begin
  if not public.aos_cia_admin_user_ok_v1(p_user_id) then return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED'); end if;
  select * into src from public.aos_audiencias where id=p_source_audience_id;
  if src.id is null then return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND'); end if;
  select * into sv from public.aos_audiencia_versiones where audiencia_id=src.id and version=src.current_version;
  if char_length(nm) not between 3 and 120 then return jsonb_build_object('ok',false,'error','INVALID_NAME'); end if;
  ds:=coalesce(p_description,src.descripcion);
  if char_length(ds)>1000 then return jsonb_build_object('ok',false,'error','DESCRIPTION_TOO_LONG'); end if;
  cntj:=public.aos_cia_audience_count_v2(sv.filter_dsl);
  if not coalesce((cntj->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','COUNT_FAILED'); end if;
  cnt:=coalesce((cntj->>'count')::integer,0);

  insert into public.aos_audiencias(nombre,descripcion,created_by_user_id,updated_by_user_id)
  values(nm,ds,p_user_id,p_user_id) returning id into aid;
  insert into public.aos_audiencia_versiones(audiencia_id,version,filter_dsl,reason,count_cache,resolved_at,created_by_user_id)
  values(aid,1,sv.filter_dsl,'DUPLICATE',cnt,now(),p_user_id) returning id into vid;
  insert into public.aos_audiencia_audit(audiencia_id,audiencia_version_id,action,actor_user_id,after_state)
  values(aid,vid,'DUPLICATE',p_user_id,jsonb_build_object('source_audience_id',src.id,'source_version',src.current_version,'nombre',nm,'count_at_save',cnt));
  return public.aos_cia_audience_library_get_v1(aid) || jsonb_build_object('operation','DUPLICATE');
exception when unique_violation then return jsonb_build_object('ok',false,'error','NAME_CONFLICT');
end;
$$;

create or replace function public.aos_cia_audience_library_archive_v1(
  p_user_id uuid,
  p_audience_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare a public.aos_audiencias%rowtype;
begin
  if not public.aos_cia_admin_user_ok_v1(p_user_id) then return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED'); end if;
  select * into a from public.aos_audiencias where id=p_audience_id for update;
  if a.id is null then return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND'); end if;
  if a.estado='ARCHIVED' then return public.aos_cia_audience_library_get_v1(a.id) || jsonb_build_object('operation','ARCHIVE','no_change',true); end if;
  update public.aos_audiencias set estado='ARCHIVED',archived_at=now(),archived_by_user_id=p_user_id,updated_by_user_id=p_user_id where id=a.id;
  insert into public.aos_audiencia_audit(audiencia_id,action,actor_user_id,before_state,after_state)
  values(a.id,'ARCHIVE',p_user_id,jsonb_build_object('estado','ACTIVE'),jsonb_build_object('estado','ARCHIVED'));
  return public.aos_cia_audience_library_get_v1(a.id) || jsonb_build_object('operation','ARCHIVE');
end;
$$;

create or replace function public.aos_cia_audience_library_restore_v1(
  p_user_id uuid,
  p_audience_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare a public.aos_audiencias%rowtype;
begin
  if not public.aos_cia_admin_user_ok_v1(p_user_id) then return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED'); end if;
  select * into a from public.aos_audiencias where id=p_audience_id for update;
  if a.id is null then return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND'); end if;
  if a.estado='ACTIVE' then return public.aos_cia_audience_library_get_v1(a.id) || jsonb_build_object('operation','RESTORE','no_change',true); end if;
  update public.aos_audiencias set estado='ACTIVE',archived_at=null,archived_by_user_id=null,updated_by_user_id=p_user_id where id=a.id;
  insert into public.aos_audiencia_audit(audiencia_id,action,actor_user_id,before_state,after_state)
  values(a.id,'RESTORE',p_user_id,jsonb_build_object('estado','ARCHIVED'),jsonb_build_object('estado','ACTIVE'));
  return public.aos_cia_audience_library_get_v1(a.id) || jsonb_build_object('operation','RESTORE');
exception when unique_violation then return jsonb_build_object('ok',false,'error','NAME_CONFLICT');
end;
$$;

revoke all on function public.aos_cia_audience_library_list_v1(boolean,integer,integer) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_library_get_v1(uuid) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_library_create_v1(uuid,text,text,jsonb,text) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_library_update_v1(uuid,uuid,integer,text,text,jsonb,text) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_library_duplicate_v1(uuid,uuid,text,text) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_library_archive_v1(uuid,uuid) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_library_restore_v1(uuid,uuid) from public, anon, authenticated;

grant execute on function public.aos_cia_audience_library_list_v1(boolean,integer,integer) to service_role;
grant execute on function public.aos_cia_audience_library_get_v1(uuid) to service_role;
grant execute on function public.aos_cia_audience_library_create_v1(uuid,text,text,jsonb,text) to service_role;
grant execute on function public.aos_cia_audience_library_update_v1(uuid,uuid,integer,text,text,jsonb,text) to service_role;
grant execute on function public.aos_cia_audience_library_duplicate_v1(uuid,uuid,text,text) to service_role;
grant execute on function public.aos_cia_audience_library_archive_v1(uuid,uuid) to service_role;
grant execute on function public.aos_cia_audience_library_restore_v1(uuid,uuid) to service_role;
