-- K1-G — authority changes revoke all existing app/admin sessions.
-- Prevents a pre-promotion PASSWORD session from becoming an ADMIN session by
-- live role re-derivation, while ordinary profile edits do not force logout.

begin;

create or replace function public.aos_k1_revoke_sessions_on_authority_change_v3()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  if old.rol is distinct from new.rol
     or old.nivel_jerarquia is distinct from new.nivel_jerarquia
     or old.two_factor is distinct from new.two_factor
     or old.email is distinct from new.email
     or old.activo is distinct from new.activo then
    update public.aos_app_sessions_v3 set revoked=true
      where user_id=new.id and revoked=false;
    update public.aos_cia_admin_sessions set revoked=true
      where user_id=new.id and revoked=false;
  end if;
  return new;
end
$function$;

revoke all on function public.aos_k1_revoke_sessions_on_authority_change_v3() from public,anon,authenticated;
drop trigger if exists trg_k1_revoke_sessions_on_authority_change_v3 on public.aos_usuarios;
create trigger trg_k1_revoke_sessions_on_authority_change_v3
after update of rol,nivel_jerarquia,two_factor,email,activo on public.aos_usuarios
for each row execute function public.aos_k1_revoke_sessions_on_authority_change_v3();

-- Production audit storage predates K1 and uses `tabla` plus `ts` /
-- `timestamp_reg` rather than `modulo` / `created_at`. Re-materialize the K1
-- admin feed against the canonical production shape instead of depending on
-- columns that do not exist in production.
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
        select id,usuario,accion,coalesce(nullif(tabla,''),'AUDIT') as modulo,
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