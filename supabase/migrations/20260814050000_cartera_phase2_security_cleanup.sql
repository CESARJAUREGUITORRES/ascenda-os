-- ASCENDA OS — FASE 2 Cartera — forward cleanup.
-- Hace segura una actualizacion incluso si un entorno efimero ejecuto una
-- revision anterior de la migracion de Cartera con firmas distintas.

begin;

drop trigger if exists trg_aos_cartera_sync_venta on public.aos_ventas;

drop function if exists public.aos_cartera_reconcile(
  text,uuid,text,text,numeric,numeric,text,text,text
);
drop function if exists public.aos_abonar_cotizacion_v2(
  text,text,numeric,text,text,text,text,text,text,text,text,text
);

-- Restaura exactamente el emisor certificado por FASE 1. Cartera reutiliza su
-- token opaco; no ensancha el contrato de autenticacion ni sus destinatarios.
create or replace function public.aos_sales_intelligence_claim_session(
  p_login_usuario text,
  p_password text,
  p_usuario text,
  p_codigo text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  c record;
  u record;
  v_token text;
  v_hash text;
  v_exp timestamptz;
begin
  select au.id, au.nombre, sia.twofa_subject
    into u
  from public.aos_sales_intelligence_access sia
  join public.aos_usuarios au on au.id=sia.user_id
  where sia.enabled=true
    and lower(sia.login_usuario)=lower(trim(coalesce(p_login_usuario,'')))
    and sia.password_digest=encode(
      extensions.digest(coalesce(p_password,''),'sha256'),
      'hex'
    )
    and au.activo=true
    and au.two_factor=true
    and au.nivel_jerarquia in (1,2)
    and lower(coalesce(au.rol,''))='admin'
    and coalesce(au.paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[]
  limit 1;

  if u.id is null then
    return jsonb_build_object('ok',false,'error','PROOF_INVALID');
  end if;

  select ac.id, ac.usuario
    into c
  from public.aos_auth_codes ac
  where upper(ac.usuario)=upper(u.twofa_subject)
    and upper(ac.usuario)=upper(p_usuario)
    and ac.codigo=p_codigo
    and ac.usado=true
    and ac.created_at>now()-interval '5 minutes'
    and ac.expira_at>now()
  order by ac.created_at desc
  limit 1
  for update;

  if c.id is null then
    return jsonb_build_object('ok',false,'error','PROOF_INVALID');
  end if;

  if exists (
    select 1 from public.aos_cia_admin_sessions s
    where s.source_auth_code_id=c.id
  ) then
    return jsonb_build_object('ok',false,'error','PROOF_ALREADY_CLAIMED');
  end if;

  update public.aos_cia_admin_sessions
  set revoked=true
  where user_id=u.id and revoked=false;

  v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_exp:=now()+interval '8 hours';

  begin
    insert into public.aos_cia_admin_sessions(
      token_hash,user_id,usuario,expires_at,source_auth_code_id
    ) values (
      v_hash,u.id,u.nombre,v_exp,c.id
    );
  exception when unique_violation then
    return jsonb_build_object('ok',false,'error','PROOF_ALREADY_CLAIMED');
  end;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (u.nombre,'SALES_INTELLIGENCE_SESSION_CLAIMED',
          jsonb_build_object('user_id',u.id,'expires_at',v_exp));

  return jsonb_build_object(
    'ok',true,
    'token',v_token,
    'expires_at',v_exp,
    'panel','admin-sales-intelligence'
  );
end;
$function$;

revoke all on function public.aos_sales_intelligence_claim_session(text,text,text,text)
  from public;
grant execute on function public.aos_sales_intelligence_claim_session(text,text,text,text)
  to anon,authenticated,service_role;

commit;
