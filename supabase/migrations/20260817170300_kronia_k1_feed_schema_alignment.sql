-- K1-D — align sanitized feed with the live aos_log_auditoria schema.

begin;

create or replace function public.aos_kronia_feed_v3(
  p_token text,p_feed text,p_limit integer default 50
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_i jsonb; v_limit integer:=greatest(1,least(coalesce(p_limit,50),200)); v_rows jsonb;
begin
  v_i:=public.aos_kronia_identity_v3(p_token,true,null);
  if not coalesce((v_i->>'ok')::boolean,false) then return v_i; end if;
  case lower(coalesce(p_feed,''))
    when 'agent_logs' then
      select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows from (
        select id,agente_id,accion,input_resumen,output_resumen,exitoso,duracion_ms,created_at
        from public.aos_agente_logs order by created_at desc limit v_limit
      ) x;
    when 'audit' then
      select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows from (
        select id,coalesce(usuario,asesor) as usuario,accion,tabla as modulo,
               coalesce(ts,timestamp_reg) as created_at
        from public.aos_log_auditoria
        order by coalesce(ts,timestamp_reg) desc nulls last limit v_limit
      ) x;
    when 'kronia_actions' then
      select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows from (
        select id,usuario,rol,accion,objeto_tipo,objeto_id,exitoso,session_id,created_at
        from public.aos_kronia_acciones order by created_at desc limit v_limit
      ) x;
    else return jsonb_build_object('ok',false,'error','FEED_NOT_ALLOWED');
  end case;
  return jsonb_build_object('ok',true,'rows',v_rows);
end
$function$;

revoke all on function public.aos_kronia_feed_v3(text,text,integer) from public;
grant execute on function public.aos_kronia_feed_v3(text,text,integer) to anon,authenticated,service_role;

commit;
