-- CANONICAL PHASE 7 GATEWAY CHECKPOINT. Applied live as 20260813214912.
-- Every action requires an existing CIA admin session token before access.
create or replace function public.aos_cia_phase7_admin_gateway_v1(p_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  auth jsonb; uid uuid; uname text; a text:=upper(btrim(coalesce(p_action,''))); outj jsonb; started timestamptz:=clock_timestamp();
  lim integer; offv integer; idtxt text; xid uuid; aid uuid; ver integer;
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  uid:=(auth->>'user_id')::uuid; uname:=auth->>'usuario';
  if pg_column_size(coalesce(p_payload,'{}'::jsonb))>65536 then outj:=jsonb_build_object('ok',false,'error','PAYLOAD_TOO_LARGE');
  elsif a='BOOTSTRAP' then
    outj:=jsonb_build_object('ok',true,'phase',7,'context_only',true,'summary',jsonb_build_object('activations',(select count(*) from public.aos_audiencia_activaciones),'snapshots',(select count(*) from public.aos_audiencia_snapshots),'active',(select count(*) from public.aos_audiencia_activacion_estado where estado='ACTIVE'),'paused',(select count(*) from public.aos_audiencia_activacion_estado where estado='PAUSED')));
  elsif a='LIST_ACTIVATIONS' then
    lim:=greatest(1,least(case when coalesce(p_payload->>'limit','')~'^[0-9]+$' then (p_payload->>'limit')::integer else 50 end,100));
    offv:=greatest(0,case when coalesce(p_payload->>'offset','')~'^[0-9]+$' then (p_payload->>'offset')::integer else 0 end);
    outj:=public.aos_cia_activation_list_internal_v1(coalesce((p_payload->>'include_terminal')::boolean,true),lim,offv);
  elsif a in ('GET_ACTIVATION','PREVIEW_ACTIVATION','TRANSITION_ACTIVATION') then
    idtxt:=coalesce(p_payload->>'activation_id','');
    if idtxt !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then outj:=jsonb_build_object('ok',false,'error','INVALID_ACTIVATION_ID');
    else
      xid:=idtxt::uuid;
      if a='GET_ACTIVATION' then outj:=public.aos_cia_activation_get_internal_v1(xid);
      elsif a='PREVIEW_ACTIVATION' then
        lim:=greatest(1,least(case when coalesce(p_payload->>'limit','')~'^[0-9]+$' then (p_payload->>'limit')::integer else 50 end,100));
        offv:=greatest(0,case when coalesce(p_payload->>'offset','')~'^[0-9]+$' then (p_payload->>'offset')::integer else 0 end);
        outj:=public.aos_cia_activation_preview_internal_v1(xid,lim,offv);
      else outj:=public.aos_cia_activation_transition_admin_v1(p_token,xid,p_payload->>'action'); end if;
    end if;
  elsif a='CREATE_ACTIVATION' then
    idtxt:=coalesce(p_payload->>'audience_id','');
    if idtxt !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then outj:=jsonb_build_object('ok',false,'error','INVALID_AUDIENCE_ID');
    else
      aid:=idtxt::uuid;
      ver:=case when coalesce(p_payload->>'version','')~'^[0-9]+$' then (p_payload->>'version')::integer else null end;
      outj:=public.aos_cia_activation_create_admin_v1(p_token,aid,ver,p_payload->>'name',p_payload->>'purpose',p_payload->>'channel',p_payload->>'mode',coalesce((p_payload->>'start_now')::boolean,false),coalesce(p_payload->'metadata','{}'::jsonb));
    end if;
  elsif a='LIST_SNAPSHOTS' then
    lim:=greatest(1,least(case when coalesce(p_payload->>'limit','')~'^[0-9]+$' then (p_payload->>'limit')::integer else 50 end,100));
    offv:=greatest(0,case when coalesce(p_payload->>'offset','')~'^[0-9]+$' then (p_payload->>'offset')::integer else 0 end);
    idtxt:=coalesce(p_payload->>'audience_id','');
    if idtxt='' then outj:=public.aos_cia_snapshot_list_internal_v1(null,lim,offv);
    elsif idtxt !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then outj:=jsonb_build_object('ok',false,'error','INVALID_AUDIENCE_ID');
    else outj:=public.aos_cia_snapshot_list_internal_v1(idtxt::uuid,lim,offv); end if;
  else outj:=jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED'); end if;
  insert into public.aos_cia_gateway_audit(user_id,usuario,action,ok,duration_ms,meta)
  values(uid,uname,'P7_'||a,coalesce((outj->>'ok')::boolean,false),greatest(0,round(extract(epoch from(clock_timestamp()-started))*1000)::integer),jsonb_build_object('phase',7,'activation_id',coalesce(outj->>'activation_id',p_payload->>'activation_id'),'context_only',true));
  return outj;
exception when others then
  if uid is not null then insert into public.aos_cia_gateway_audit(user_id,usuario,action,ok,duration_ms,meta) values(uid,coalesce(uname,'?'),'P7_'||a,false,greatest(0,round(extract(epoch from(clock_timestamp()-started))*1000)::integer),jsonb_build_object('phase',7,'error_code',sqlstate)); end if;
  return jsonb_build_object('ok',false,'error','GATEWAY_ERROR','code',sqlstate);
end;$$;
