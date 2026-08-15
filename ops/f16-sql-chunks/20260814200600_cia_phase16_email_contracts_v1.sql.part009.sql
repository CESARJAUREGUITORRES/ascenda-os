    'ready_for_f17',false,
    'delivery_enabled',false,
    'send_request_state_enabled','PREPARED_ONLY',
    'f15_readiness',v_f15,
    'schema',jsonb_build_object('private_tables',v_tables,'rls_tables',v_rls,'anon_direct_access',v_anon_direct,'authenticated_direct_access',v_auth_direct),
    'templates_active',v_templates,
    'requests_total',v_requests,
    'non_prepared_requests',v_illegal,
    'next_gate','ZERO_COST_CONTRACTS_THEN_PROVIDER_AUTH_WEBHOOK_CANARY'
  );
end
$function$;

create or replace function public.aos_cia_email_admin_gateway_v1(
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
  v_activation uuid;
  v_template uuid;
  v_purpose text;
  v_contact text;
  v_limit integer;
  v_offset integer;
  v_vars text[];
  v_items jsonb;
begin
  v_auth := public.aos_cia_verify_admin_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_admin := (v_auth->>'user_id')::uuid;

  if v_action='READINESS' then
    return public.aos_cia_email_f17_readiness_v1();
  elsif v_action='PREVIEW' then
