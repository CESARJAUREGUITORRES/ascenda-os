begin
  if p_actor_user_id is null then return jsonb_build_object('ok',false,'error','ACTOR_REQUIRED'); end if;

  select t.* into v_tpl
  from public.aos_cia_email_template_versions t
  where t.id=p_template_version_id;
  if v_tpl.id is null then return jsonb_build_object('ok',false,'error','TEMPLATE_VERSION_NOT_FOUND'); end if;
  if v_tpl.state <> 'ACTIVE' then return jsonb_build_object('ok',false,'error','TEMPLATE_NOT_ACTIVE'); end if;

  select st.estado into v_activation_state
  from public.aos_audiencia_activacion_estado st
  where st.activacion_id=p_activation_id;
  if v_activation_state is null then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND'); end if;
  if v_activation_state <> 'ACTIVE' then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_ACTIVE','state',v_activation_state); end if;

  v_elig := public.aos_cia_email_eligibility_v1(p_activation_id,p_contact_key,v_tpl.purpose);
  if coalesce(v_elig->>'eligibility_status','UNKNOWN') <> 'ELIGIBLE' then
    return jsonb_build_object('ok',false,'error','EMAIL_NOT_ELIGIBLE','eligibility',v_elig,'send_performed',false);
  end if;
  if coalesce(v_elig->>'consent_status','UNKNOWN') not in ('ALLOWED','NOT_REQUIRED') then
    return jsonb_build_object('ok',false,'error','CONSENT_NOT_ALLOWED','eligibility',v_elig,'send_performed',false);
  end if;

  v_key := md5(p_activation_id::text||'|'||trim(p_contact_key)||'|'||p_template_version_id::text||'|'||v_tpl.purpose);
  perform pg_advisory_xact_lock(hashtext('F16_EMAIL_REQUEST:'||v_key));
  select id into v_existing from public.aos_cia_email_send_requests where idempotency_key=v_key;
  if v_existing is not null then
    return jsonb_build_object('ok',true,'request_id',v_existing,'idempotent',true,'state','PREPARED','send_performed',false);
  end if;

  insert into public.aos_cia_email_send_requests(
    activation_id,contact_key,recipient_email,purpose,template_version_id,template_digest,idempotency_key,
    eligibility_status,consent_status,state,requested_by_user_id,authorization_provenance
  ) values(
    p_activation_id,trim(p_contact_key),v_elig->>'email',v_tpl.purpose,v_tpl.id,v_tpl.content_digest,v_key,
    v_elig->>'eligibility_status',v_elig->>'consent_status','PREPARED',p_actor_user_id,
    jsonb_build_object('actor_user_id',p_actor_user_id,'via','CIA_EMAIL_ADMIN_GATEWAY_V1','prepared_only',true)
  ) returning id into v_id;

  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_id,'PREPARED',jsonb_build_object('eligibility_reason',v_elig->>'reason_code','send_performed',false));

  return jsonb_build_object('ok',true,'request_id',v_id,'idempotent',false,'state','PREPARED','send_performed',false,'eligibility',v_elig);
end
$function$;
