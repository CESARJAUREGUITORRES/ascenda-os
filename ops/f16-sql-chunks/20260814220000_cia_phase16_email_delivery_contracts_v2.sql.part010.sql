  v_activation uuid;
  v_template uuid;
  v_request uuid;
  v_contact text;
begin
  v_auth := public.aos_cia_verify_admin_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  begin v_admin := (v_auth->>'user_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end;

  if v_action='PREVIEW_ACTIVATION' then
    begin v_activation := (p_payload->>'activation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_ACTIVATION_ID'); end;
    return public.aos_cia_email_preview_activation_v1(v_activation,coalesce(p_payload->>'purpose','MARKETING'),coalesce((p_payload->>'limit')::integer,50),coalesce((p_payload->>'offset')::integer,0));
  elsif v_action='TEMPLATE_CREATE' then
    return public.aos_cia_email_template_version_create_v1(
      v_admin,p_payload->>'template_key',p_payload->>'purpose',p_payload->>'subject_template',p_payload->>'html_template',
      coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'variable_keys','[]'::jsonb))),'{}'::text[]),
      case when nullif(p_payload->>'legacy_template_id','') is null then null else (p_payload->>'legacy_template_id')::uuid end
    );
  elsif v_action='TEMPLATE_ACTIVATE' then
    begin v_template := (p_payload->>'template_version_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_TEMPLATE_VERSION_ID'); end;
    return public.aos_cia_email_template_version_activate_v1(v_admin,v_template);
  elsif v_action='PREPARE_REQUEST' then
    begin v_activation := (p_payload->>'activation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_ACTIVATION_ID'); end;
    begin v_template := (p_payload->>'template_version_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_TEMPLATE_VERSION_ID'); end;
    v_contact := trim(coalesce(p_payload->>'contact_key',''));
    if v_contact='' then return jsonb_build_object('ok',false,'error','CONTACT_REQUIRED'); end if;
    return public.aos_cia_email_prepare_request_v2(v_admin,v_activation,v_contact,v_template,coalesce(p_payload->'render_context','{}'::jsonb));
  elsif v_action='QUEUE_REQUEST' then
    begin v_request := (p_payload->>'request_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_REQUEST_ID'); end;
    return public.aos_cia_email_queue_request_v2(v_admin,v_request);
  elsif v_action='LIST_REQUESTS' then
    return jsonb_build_object(
      'ok',true,
      'items',coalesce((select jsonb_agg(x order by x.created_at desc) from (
        select id,correlation_id,activation_id,contact_key,purpose,template_version_id,state,provider,provider_message_id,dispatch_attempts,created_at,updated_at
        from public.aos_cia_email_send_requests
        order by created_at desc
        limit greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100))
      ) x),'[]'::jsonb)
    );
  elsif v_action='READINESS' then
    return public.aos_cia_email_f17_readiness_v1();
  end if;
  return jsonb_build_object('ok',false,'error','UNSUPPORTED_ACTION');
exception when invalid_text_representation then
