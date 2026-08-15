  p_evidence text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_gate text := upper(trim(coalesce(p_gate,'')));
  v_value boolean := coalesce(p_value,false);
begin
  if v_gate not in ('GATEWAY_ACTIVE','PROVIDER_CONFIGURED','WEBHOOK_VERIFIED','ADMIN_UI_GATEWAY_ONLY','LEGACY_ACL_HARDENED','CANARY_PASSED','ROLLBACK_VERIFIED') then
    return jsonb_build_object('ok',false,'error','INVALID_RELEASE_GATE');
  end if;

  update public.aos_cia_email_release_state
  set gateway_active=case when v_gate='GATEWAY_ACTIVE' then v_value else gateway_active end,
      provider_configured=case when v_gate='PROVIDER_CONFIGURED' then v_value else provider_configured end,
      webhook_verified=case when v_gate='WEBHOOK_VERIFIED' then v_value else webhook_verified end,
      admin_ui_gateway_only=case when v_gate='ADMIN_UI_GATEWAY_ONLY' then v_value else admin_ui_gateway_only end,
      legacy_acl_hardened=case when v_gate='LEGACY_ACL_HARDENED' then v_value else legacy_acl_hardened end,
      canary_passed=case when v_gate='CANARY_PASSED' then v_value else canary_passed end,
      rollback_verified=case when v_gate='ROLLBACK_VERIFIED' then v_value else rollback_verified end,
      evidence=evidence||jsonb_build_object(v_gate,jsonb_build_object('value',v_value,'evidence',left(coalesce(p_evidence,''),500),'at',now())),
      updated_at=now()
  where singleton=true;

  return jsonb_build_object('ok',true,'gate',v_gate,'value',v_value);
end
$function$;

create or replace function public.aos_cia_email_admin_gateway_v2(
  p_token text,
  p_action text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_auth jsonb;
  v_admin uuid;
  v_action text := upper(trim(coalesce(p_action,'')));
