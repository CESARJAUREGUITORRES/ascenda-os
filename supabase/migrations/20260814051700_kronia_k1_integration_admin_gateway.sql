-- K1 — narrow administrative gateway for Integration metadata/state changes.
-- Secret values are never returned to browser roles.

create or replace function public.aos_kronia_admin_desactivar_integracion(
  p_token text,
  p_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ident jsonb;
  v_user text;
  v_count integer;
begin
  v_ident := public.aos_kronia_verify_token(p_token);
  if coalesce((v_ident->>'ok')::boolean,false)=false then
    return v_ident;
  end if;

  if upper(coalesce(v_ident->>'rol','')) <> 'ADMIN' then
    return jsonb_build_object('ok',false,'error','Administrador requerido');
  end if;

  v_user := v_ident->>'usuario';

  update public.aos_integraciones
  set estado='pendiente', api_key=null, api_secret=null, cuenta=null, updated_at=now()
  where id=p_id;
  get diagnostics v_count=row_count;

  if v_count <> 1 then
    return jsonb_build_object('ok',false,'error','Integración no encontrada');
  end if;

  insert into public.aos_kronia_acciones(
    usuario,rol,accion,objeto_tipo,objeto_id,cambios,resultado,exitoso
  ) values (
    v_user,'ADMIN','integration_disable','integracion',p_id::text,
    jsonb_build_object('estado','pendiente'),
    'Integración desactivada mediante gateway K1',true
  );

  return jsonb_build_object('ok',true,'id',p_id,'estado','pendiente');
exception when others then
  insert into public.aos_security_log(usuario,accion,detalles)
  values (coalesce(v_user,'unknown'),'integration_admin_error',
          jsonb_build_object('integration_id',p_id,'sqlstate',sqlstate));
  return jsonb_build_object('ok',false,'error','No se pudo actualizar la integración');
end;
$$;

revoke all on function public.aos_kronia_admin_desactivar_integracion(text,uuid) from public;
grant execute on function public.aos_kronia_admin_desactivar_integracion(text,uuid) to anon,authenticated;

comment on function public.aos_kronia_admin_desactivar_integracion(text,uuid) is
'K1 token-bound ADMIN gateway. Does not expose integration credentials.';
