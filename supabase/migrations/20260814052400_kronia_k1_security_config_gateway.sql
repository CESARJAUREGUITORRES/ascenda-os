-- K1 — Security configuration boundary.
-- aos_configuracion was browser-writable with RLS off. That allowed the global
-- 2FA switch and lockout settings to be modified without an authoritative ADMIN.

begin;

-- K1 requires 2FA globally enabled. Preserve the row and force the secure value
-- before removing direct browser mutation.
update public.aos_configuracion
set valor='true',updated_at=now()
where clave='seg_2fa_habilitado';
insert into public.aos_configuracion(clave,valor,updated_at)
select 'seg_2fa_habilitado','true',now()
where not exists(select 1 from public.aos_configuracion where clave='seg_2fa_habilitado');

create or replace function public.aos_kronia_admin_config_safe(
  p_token text,
  p_clave text,
  p_valor text
) returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog'
as $function$
declare
  v_auth jsonb;
  v_actor public.aos_usuarios%rowtype;
  v_key text:=lower(trim(coalesce(p_clave,'')));
  v_value text:=trim(coalesce(p_valor,''));
  v_int integer;
begin
  v_auth:=public.aos_kronia_verify_token(p_token);
  if not coalesce((v_auth->>'ok')::boolean,false) or upper(coalesce(v_auth->>'rol',''))<>'ADMIN' then
    return jsonb_build_object('ok',false,'error','ADMIN_SESSION_REQUIRED');
  end if;
  select u.* into v_actor from public.aos_usuarios u
  where u.codigo_asesor=v_auth->>'id_asesor' and u.activo=true
    and lower(coalesce(u.rol,''))='admin' and coalesce(u.nivel_jerarquia,99) in (1,2)
  limit 1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','ADMIN_IDENTITY_REQUIRED'); end if;

  if v_key not in (
    'seg_2fa_habilitado','max_intentos_login','bloqueo_minutos','sesion_timeout_min',
    'max_intentos_2fa','bloqueo_minutos_2fa','alert_email_min','alert_cambios_rol',
    'alert_intentos_fallidos','timezone'
  ) then return jsonb_build_object('ok',false,'error','CONFIG_KEY_NOT_ALLOWED'); end if;

  -- Security-policy knobs are owner-level only.
  if v_key in ('seg_2fa_habilitado','max_intentos_login','bloqueo_minutos','sesion_timeout_min','max_intentos_2fa','bloqueo_minutos_2fa')
     and v_actor.nivel_jerarquia<>1 then
    return jsonb_build_object('ok',false,'error','OWNER_LEVEL_REQUIRED');
  end if;

  if v_key='seg_2fa_habilitado' then
    if lower(v_value)<>'true' then return jsonb_build_object('ok',false,'error','TWO_FACTOR_CANNOT_BE_DISABLED'); end if;
    v_value:='true';
  elsif v_key in ('alert_cambios_rol','alert_intentos_fallidos') then
    if lower(v_value) not in ('true','false') then return jsonb_build_object('ok',false,'error','BOOLEAN_REQUIRED'); end if;
    v_value:=lower(v_value);
  elsif v_key='timezone' then
    if length(v_value)<3 or length(v_value)>64 or v_value !~ '^[A-Za-z_]+/[A-Za-z_]+$' then
      return jsonb_build_object('ok',false,'error','TIMEZONE_INVALID');
    end if;
  else
    begin v_int:=v_value::integer; exception when invalid_text_representation then return jsonb_build_object('ok',false,'error','INTEGER_REQUIRED'); end;
    if (v_key='max_intentos_login' and (v_int<3 or v_int>10))
       or (v_key='bloqueo_minutos' and (v_int<5 or v_int>120))
       or (v_key='sesion_timeout_min' and (v_int<15 or v_int>1440))
       or (v_key='max_intentos_2fa' and (v_int<1 or v_int>10))
       or (v_key='bloqueo_minutos_2fa' and (v_int<1 or v_int>60))
       or (v_key='alert_email_min' and (v_int<1 or v_int>60)) then
      return jsonb_build_object('ok',false,'error','VALUE_OUT_OF_RANGE');
    end if;
    v_value:=v_int::text;
  end if;

  update public.aos_configuracion set valor=v_value,updated_at=now() where clave=v_key;
  if not found then
    insert into public.aos_configuracion(clave,valor,updated_at) values(v_key,v_value,now());
  end if;
  insert into public.aos_security_log(usuario,accion,detalles,ip)
  values(v_actor.nombre,'K1_ADMIN_CONFIG_UPDATE',jsonb_build_object('actor_id',v_actor.id,'clave',v_key),'k1-config-gateway');
  return jsonb_build_object('ok',true,'clave',v_key,'valor',v_value);
end;
$function$;

revoke insert,update,delete on table public.aos_configuracion from anon,authenticated;
grant select on table public.aos_configuracion to anon,authenticated;
revoke all on function public.aos_kronia_admin_config_safe(text,text,text) from public;
grant execute on function public.aos_kronia_admin_config_safe(text,text,text) to anon,authenticated,service_role;

comment on function public.aos_kronia_admin_config_safe(text,text,text) is
'K1 token-bound configuration gateway. Security knobs are owner-level; global 2FA cannot be disabled.';

commit;
