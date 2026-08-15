    begin v_activation := (p_payload->>'activation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_ACTIVATION_ID'); end;
    v_purpose := coalesce(nullif(upper(trim(p_payload->>'purpose')),''),'MARKETING');
    v_limit := greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));
    v_offset := greatest(0,coalesce((p_payload->>'offset')::integer,0));
    return public.aos_cia_email_preview_activation_v1(v_activation,v_purpose,v_limit,v_offset);
  elsif v_action='TEMPLATE_CREATE_VERSION' then
    select coalesce(array_agg(value),'{}'::text[]) into v_vars
    from jsonb_array_elements_text(coalesce(p_payload->'variable_keys','[]'::jsonb)) value;
    return public.aos_cia_email_template_version_create_v1(
      v_admin,p_payload->>'template_key',p_payload->>'purpose',p_payload->>'subject_template',p_payload->>'html_template',v_vars,
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
    return public.aos_cia_email_prepare_request_v1(v_admin,v_activation,v_contact,v_template);
  elsif v_action='REQUESTS' then
    v_limit := greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_items
    from (
      select id,correlation_id,activation_id,contact_key,purpose,template_version_id,state,dispatch_attempts,created_at,updated_at
      from public.aos_cia_email_send_requests order by created_at desc limit v_limit
    ) x;
    return jsonb_build_object('ok',true,'items',v_items,'delivery_enabled',false);
  end if;
  return jsonb_build_object('ok',false,'error','UNKNOWN_ACTION');
exception when invalid_text_representation or numeric_value_out_of_range then
  return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
end
$function$;

revoke all on function public.aos_cia_email_eligibility_v1(uuid,text,text) from public, anon, authenticated;
revoke all on function public.aos_cia_email_preview_activation_v1(uuid,text,integer,integer) from public, anon, authenticated;
revoke all on function public.aos_cia_email_template_version_create_v1(uuid,text,text,text,text,text[],uuid) from public, anon, authenticated;
revoke all on function public.aos_cia_email_template_version_activate_v1(uuid,uuid) from public, anon, authenticated;
revoke all on function public.aos_cia_email_prepare_request_v1(uuid,uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.aos_cia_email_f17_readiness_v1() from public, anon, authenticated;
revoke all on function public.aos_cia_email_admin_gateway_v1(text,text,jsonb) from public;
grant execute on function public.aos_cia_email_admin_gateway_v1(text,text,jsonb) to anon, authenticated;

