  if coalesce(v_elig->>'eligibility_status','UNKNOWN') <> 'ELIGIBLE'
     or coalesce(v_elig->>'consent_status','UNKNOWN') not in ('ALLOWED','NOT_REQUIRED') then
    update public.aos_cia_email_send_requests set state='CANCELLED' where id=v_req.id;
    insert into public.aos_cia_email_send_events(request_id,event_type,payload)
    values(v_req.id,'QUEUE_BLOCKED',jsonb_build_object('eligibility',v_elig,'actor_user_id',p_actor_user_id));
    return jsonb_build_object('ok',false,'error','EMAIL_NOT_ELIGIBLE_AT_QUEUE','request_id',v_req.id,'state','CANCELLED','eligibility',v_elig);
  end if;

  update public.aos_cia_email_send_requests set state='QUEUED',scheduled_at=coalesce(scheduled_at,now()) where id=v_req.id;
  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_req.id,'QUEUED',jsonb_build_object('actor_user_id',p_actor_user_id,'eligibility_reason',v_elig->>'reason_code'));
  return jsonb_build_object('ok',true,'request_id',v_req.id,'state','QUEUED','idempotent',false);
end
$function$;

create or replace function public.aos_cia_email_claim_dispatch_v2(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_req record;
  v_tpl record;
  v_elig jsonb;
begin
  if p_request_id is null then return jsonb_build_object('ok',false,'error','REQUEST_REQUIRED','send_allowed',false); end if;

  select * into v_req from public.aos_cia_email_send_requests where id=p_request_id for update;
  if v_req.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND','send_allowed',false); end if;
  if v_req.state in ('ACCEPTED','DELIVERED','BOUNCED','COMPLAINED') then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true,'send_allowed',false,'provider_message_id',v_req.provider_message_id);
  end if;
  if v_req.state='DISPATCHING' then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state','DISPATCHING','in_progress',true,'send_allowed',false);
  end if;
  if v_req.state <> 'QUEUED' then
    return jsonb_build_object('ok',false,'error','REQUEST_NOT_QUEUED','state',v_req.state,'send_allowed',false);
  end if;

  v_elig := public.aos_cia_email_eligibility_v1(v_req.activation_id,v_req.contact_key,v_req.purpose);
  if coalesce(v_elig->>'eligibility_status','UNKNOWN') <> 'ELIGIBLE'
     or coalesce(v_elig->>'consent_status','UNKNOWN') not in ('ALLOWED','NOT_REQUIRED') then
    update public.aos_cia_email_send_requests set state='CANCELLED' where id=v_req.id;
    insert into public.aos_cia_email_send_events(request_id,event_type,payload)
