create or replace function public.aos_cia_request_admin_readiness_v1(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_auth jsonb;
begin
  v_auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  return public.aos_cia_request_f14_readiness_v1();
end
$function$;
revoke all on function public.aos_cia_request_admin_readiness_v1(text) from public,anon,authenticated;
grant execute on function public.aos_cia_request_admin_readiness_v1(text) to anon,authenticated;
