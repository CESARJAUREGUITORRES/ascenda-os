create or replace function public.aos_cia_gateway_log_v1(p_user_id uuid,p_usuario text,p_action text,p_ok boolean,p_duration_ms integer,p_meta jsonb default '{}'::jsonb)
returns void language sql volatile security definer set search_path=public as $$
insert into public.aos_cia_gateway_audit(user_id,usuario,action,ok,duration_ms,meta)
values(p_user_id,p_usuario,p_action,p_ok,p_duration_ms,coalesce(p_meta,'{}'::jsonb));
$$;
revoke all on function public.aos_cia_gateway_log_v1(uuid,text,text,boolean,integer,jsonb) from public,anon,authenticated;
grant execute on function public.aos_cia_gateway_log_v1(uuid,text,text,boolean,integer,jsonb) to service_role;
