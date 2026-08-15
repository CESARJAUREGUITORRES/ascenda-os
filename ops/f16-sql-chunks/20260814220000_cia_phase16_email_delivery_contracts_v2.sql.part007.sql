begin
  if p_request_id is null or v_provider='' then return jsonb_build_object('ok',false,'error','REQUEST_AND_PROVIDER_REQUIRED'); end if;
  if jsonb_typeof(v_payload) <> 'object' then return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD'); end if;

  select * into v_req from public.aos_cia_email_send_requests where id=p_request_id for update;
  if v_req.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;

  if coalesce(p_accepted,false) and v_req.state in ('ACCEPTED','DELIVERED','BOUNCED','COMPLAINED') then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true);
  end if;
  if v_req.state <> 'DISPATCHING' then
    return jsonb_build_object('ok',false,'error','REQUEST_NOT_DISPATCHING','state',v_req.state);
  end if;

  if coalesce(p_accepted,false) then
    if nullif(trim(coalesce(p_provider_message_id,'')),'') is null then
      return jsonb_build_object('ok',false,'error','PROVIDER_MESSAGE_ID_REQUIRED');
    end if;
    update public.aos_cia_email_send_requests
       set state='ACCEPTED',provider=v_provider,provider_message_id=trim(p_provider_message_id),accepted_at=coalesce(accepted_at,now())
     where id=v_req.id;
    insert into public.aos_cia_email_send_events(request_id,event_type,payload)
    values(v_req.id,'PROVIDER_ACCEPTED',v_payload||jsonb_build_object('provider',v_provider,'provider_message_id',trim(p_provider_message_id)));
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state','ACCEPTED','provider_message_id',trim(p_provider_message_id));
  end if;

  update public.aos_cia_email_send_requests set state='FAILED',provider=v_provider where id=v_req.id;
  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_req.id,'PROVIDER_FAILED',v_payload||jsonb_build_object('provider',v_provider,'error_code',left(coalesce(p_error_code,'PROVIDER_ERROR'),120)));
  return jsonb_build_object('ok',true,'request_id',v_req.id,'state','FAILED');
end
$function$;

create or replace function public.aos_cia_email_ingest_provider_event_v2(
  p_provider_event_id text,
  p_provider_message_id text,
  p_event_type text,
  p_occurred_at timestamptz default now(),
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
