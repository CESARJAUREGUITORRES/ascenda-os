security definer
set search_path = ''
as $function$
declare
  v_tpl record;
  v_elig jsonb;
  v_activation_state text;
  v_key text;
  v_existing record;
  v_id uuid;
  v_context jsonb := coalesce(p_render_context,'{}'::jsonb);
begin
  if p_actor_user_id is null then return jsonb_build_object('ok',false,'error','ACTOR_REQUIRED'); end if;
  if jsonb_typeof(v_context) <> 'object' then return jsonb_build_object('ok',false,'error','INVALID_RENDER_CONTEXT'); end if;
  if pg_column_size(v_context) > 65536 then return jsonb_build_object('ok',false,'error','RENDER_CONTEXT_TOO_LARGE'); end if;

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
  select id,state,render_context into v_existing
  from public.aos_cia_email_send_requests where idempotency_key=v_key;
  if v_existing.id is not null then
    return jsonb_build_object(
      'ok',true,'request_id',v_existing.id,'idempotent',true,'state',v_existing.state,
      'context_reused',v_existing.render_context=v_context,'send_performed',false
    );
