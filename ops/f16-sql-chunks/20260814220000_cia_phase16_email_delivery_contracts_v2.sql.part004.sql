  end if;

  insert into public.aos_cia_email_send_requests(
    activation_id,contact_key,recipient_email,purpose,template_version_id,template_digest,idempotency_key,
    eligibility_status,consent_status,render_context,state,requested_by_user_id,authorization_provenance
  ) values(
    p_activation_id,trim(p_contact_key),v_elig->>'email',v_tpl.purpose,v_tpl.id,v_tpl.content_digest,v_key,
    v_elig->>'eligibility_status',v_elig->>'consent_status',v_context,'PREPARED',p_actor_user_id,
    jsonb_build_object('actor_user_id',p_actor_user_id,'via','CIA_EMAIL_ADMIN_GATEWAY_V2','prepared_only',true)
  ) returning id into v_id;

  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_id,'PREPARED',jsonb_build_object('eligibility_reason',v_elig->>'reason_code','send_performed',false));

  return jsonb_build_object('ok',true,'request_id',v_id,'idempotent',false,'state','PREPARED','send_performed',false,'eligibility',v_elig);
end
$function$;

create or replace function public.aos_cia_email_queue_request_v2(
  p_actor_user_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_req record;
  v_elig jsonb;
begin
  if p_actor_user_id is null or p_request_id is null then
    return jsonb_build_object('ok',false,'error','ACTOR_AND_REQUEST_REQUIRED');
  end if;

  select * into v_req from public.aos_cia_email_send_requests where id=p_request_id for update;
  if v_req.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;
  if v_req.state in ('QUEUED','DISPATCHING','ACCEPTED','DELIVERED','BOUNCED','COMPLAINED') then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true);
  end if;
  if v_req.state not in ('PREPARED','FAILED') then
    return jsonb_build_object('ok',false,'error','REQUEST_NOT_QUEUEABLE','state',v_req.state);
  end if;

  v_elig := public.aos_cia_email_eligibility_v1(v_req.activation_id,v_req.contact_key,v_req.purpose);
