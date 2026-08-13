create or replace function public.aos_cia_admin_gateway_v1(p_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a text:=upper(btrim(coalesce(p_action,'')));auth jsonb;outj jsonb;uid uuid;uname text;t0 timestamptz:=clock_timestamp();lim integer;offv integer;
begin
 auth:=public.aos_cia_verify_admin_session_v1(p_token);
 if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED');end if;
 uid:=(auth->>'user_id')::uuid;uname:=auth->>'usuario';
 if pg_column_size(coalesce(p_payload,'{}'::jsonb))>65536 then outj:=jsonb_build_object('ok',false,'error','PAYLOAD_TOO_LARGE');
 elsif a='BOOTSTRAP' then outj:=public.aos_cia_gateway_bootstrap_v1();
 elsif a='VALIDATE' then outj:=jsonb_build_object('ok',true,'validation',public.aos_cia_audience_validate_v1(p_payload->'filter'));
 elsif a='COUNT' then outj:=public.aos_cia_audience_count_v2(p_payload->'filter');
 elsif a='PREVIEW' then lim:=greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));offv:=greatest(0,coalesce((p_payload->>'offset')::integer,0));outj:=public.aos_cia_audience_preview_v2(p_payload->'filter',lim,offv);
 elsif a='EXPLAIN' then outj:=public.aos_cia_audience_explain_v2(p_payload->'filter',p_payload->>'contact_key');
 elsif a='REFRESH_SEGMENTS' then outj:=public.aos_cia_refresh_segment_cache_v2();
 elsif a='REFRESH_EMAIL' then outj:=public.aos_cia_refresh_email_cache_v2();
 else outj:=jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');end if;
 perform public.aos_cia_gateway_log_v1(uid,uname,a,coalesce((outj->>'ok')::boolean,false),greatest(0,round(extract(epoch from(clock_timestamp()-t0))*1000)::integer),jsonb_build_object('resolver_version',2));
 return outj;
exception when others then
 if uid is not null then perform public.aos_cia_gateway_log_v1(uid,coalesce(uname,'?'),a,false,greatest(0,round(extract(epoch from(clock_timestamp()-t0))*1000)::integer),jsonb_build_object('error_code',sqlstate));end if;
 return jsonb_build_object('ok',false,'error','GATEWAY_ERROR','code',sqlstate);
end;$$;
revoke execute on function public.aos_cia_admin_gateway_v1(text,text,jsonb) from public;
grant execute on function public.aos_cia_admin_gateway_v1(text,text,jsonb) to anon,authenticated,service_role;
