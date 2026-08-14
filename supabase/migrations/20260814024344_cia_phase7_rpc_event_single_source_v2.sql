-- ASCENDA CIA Phase 7 — single source of lifecycle audit events.
-- Applied live as schema_migrations version 20260814024344.
-- RPCs mutate state only; DB trigger emits CREATE/START/PAUSE/RESUME/COMPLETE/CANCEL.

create or replace function public.aos_cia_activation_create_admin_v1(
  p_token text,p_audience_id uuid,p_version integer,p_name text,p_purpose text,p_channel text,p_mode text,p_start_now boolean default false,p_metadata jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  auth jsonb; uid uuid; a record; v record; cntj jsonb; cnt integer; t timestamptz:=statement_timestamp();
  snap jsonb; sid uuid; actid uuid; md jsonb:=coalesce(p_metadata,'{}'::jsonb); ch text:=upper(btrim(coalesce(p_channel,''))); mo text:=upper(btrim(coalesce(p_mode,'')));
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  uid:=(auth->>'user_id')::uuid;
  if char_length(btrim(coalesce(p_name,''))) not between 3 and 120 then return jsonb_build_object('ok',false,'error','INVALID_NAME'); end if;
  if char_length(btrim(coalesce(p_purpose,''))) not between 2 and 120 then return jsonb_build_object('ok',false,'error','INVALID_PURPOSE'); end if;
  if ch not in ('CALL','EMAIL','SMS','WHATSAPP','AUTOMATION','ANALYSIS','OTHER') then return jsonb_build_object('ok',false,'error','INVALID_CHANNEL'); end if;
  if mo not in ('BATCH','DYNAMIC') then return jsonb_build_object('ok',false,'error','INVALID_MODE'); end if;
  if jsonb_typeof(md)<>'object' or pg_column_size(md)>32768 then return jsonb_build_object('ok',false,'error','INVALID_METADATA'); end if;
  select id,estado,current_version into a from public.aos_audiencias where id=p_audience_id;
  if a.id is null then return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND'); end if;
  if a.estado<>'ACTIVE' then return jsonb_build_object('ok',false,'error','AUDIENCE_ARCHIVED'); end if;
  select id,version,filter_dsl into v from public.aos_audiencia_versiones where audiencia_id=a.id and version=coalesce(p_version,a.current_version);
  if v.id is null then return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND'); end if;
  cntj:=public.aos_cia_audience_count_v2(v.filter_dsl);
  if not coalesce((cntj->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','COUNT_FAILED'); end if;
  cnt:=coalesce((cntj->>'count')::integer,0);
  sid:=null;
  if mo='BATCH' then
    snap:=public.aos_cia_snapshot_create_admin_v1(p_token,a.id,v.version);
    if not coalesce((snap->>'ok')::boolean,false) then return snap; end if;
    sid:=(snap#>>'{snapshot,id}')::uuid;
    cnt:=coalesce((snap#>>'{snapshot,member_count}')::integer,0);
  end if;
  insert into public.aos_audiencia_activaciones(audiencia_id,audiencia_version_id) values(a.id,v.id) returning id into actid;
  insert into public.aos_audiencia_activacion_config(activacion_id,snapshot_id,nombre,purpose,channel,mode,baseline_count,baseline_resolved_at,metadata,created_by_user_id)
  values(actid,sid,btrim(p_name),btrim(p_purpose),ch,mo,cnt,t,md||jsonb_build_object('context_only',true,'phase',7),uid);
  insert into public.aos_audiencia_activacion_estado(activacion_id,estado,updated_by_user_id) values(actid,'DRAFT',uid);
  if coalesce(p_start_now,false) then
    update public.aos_audiencia_activacion_estado set estado='ACTIVE',updated_by_user_id=uid,started_at=clock_timestamp(),ended_at=null where activacion_id=actid;
  end if;
  return jsonb_build_object('ok',true,'activation_id',actid,'snapshot_id',sid,'mode',mo,'state',case when p_start_now then 'ACTIVE' else 'DRAFT' end,'baseline_count',cnt,'baseline_resolved_at',t,'context_only',true);
end;$$;

create or replace function public.aos_cia_activation_transition_admin_v1(p_token text,p_activation_id uuid,p_action text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  auth jsonb; uid uuid; st record; act text:=upper(btrim(coalesce(p_action,''))); ns text; ev text; t timestamptz:=clock_timestamp();
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  uid:=(auth->>'user_id')::uuid;
  select * into st from public.aos_audiencia_activacion_estado where activacion_id=p_activation_id for update;
  if st.activacion_id is null then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND'); end if;
  if act='START' and st.estado='DRAFT' then ns:='ACTIVE';ev:='START';
  elsif act='PAUSE' and st.estado='ACTIVE' then ns:='PAUSED';ev:='PAUSE';
  elsif act='RESUME' and st.estado='PAUSED' then ns:='ACTIVE';ev:='RESUME';
  elsif act='COMPLETE' and st.estado in ('ACTIVE','PAUSED') then ns:='COMPLETED';ev:='COMPLETE';
  elsif act='CANCEL' and st.estado in ('DRAFT','ACTIVE','PAUSED') then ns:='CANCELLED';ev:='CANCEL';
  else return jsonb_build_object('ok',false,'error','INVALID_TRANSITION','current_state',st.estado,'action',act); end if;
  update public.aos_audiencia_activacion_estado
  set estado=ns,updated_by_user_id=uid,
      started_at=case when ns in ('ACTIVE','PAUSED','COMPLETED') then coalesce(st.started_at,t) else st.started_at end,
      ended_at=case when ns in ('COMPLETED','CANCELLED') then t else null end
  where activacion_id=p_activation_id;
  return jsonb_build_object('ok',true,'activation_id',p_activation_id,'from_state',st.estado,'state',ns,'event',ev,'updated_at',t);
end;$$;