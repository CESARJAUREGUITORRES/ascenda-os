-- ASCENDA OS — rollback for F4 Cartera gateway V2 Auth V3 chain hotfix.
-- Restores the immediately previous V2 implementation. This rollback is for
-- controlled recovery only and intentionally does not widen business-data access.

begin;

create or replace function public.aos_cartera_gateway_v2(
  p_token text,
  p_estado text default '',
  p_sede text default '',
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_result jsonb;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-cartera');
  if v_actor is null then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_result:=public.aos_cartera_gateway(
    p_token,p_estado,p_sede,p_limit,p_offset
  );
  if coalesce((v_result->>'ok')::boolean,false)=false then
    return v_result;
  end if;

  update public.aos_app_sessions_v3
  set last_used_at=now()
  where user_id=v_actor and revoked=false;

  return v_result || jsonb_build_object(
    'contract','F4_CARTERA_GATEWAY_V2',
    'strongAuth',true
  );
end
$function$;

revoke all on function public.aos_cartera_gateway_v2(text,text,text,integer,integer) from public;
grant execute on function public.aos_cartera_gateway_v2(text,text,text,integer,integer) to anon,authenticated;

notify pgrst, 'reload schema';

commit;
