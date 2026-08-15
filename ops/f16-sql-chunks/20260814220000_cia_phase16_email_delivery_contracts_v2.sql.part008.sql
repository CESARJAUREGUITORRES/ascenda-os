declare
  v_req record;
  v_type text := lower(trim(coalesce(p_event_type,'')));
  v_event_id text := trim(coalesce(p_provider_event_id,''));
  v_message_id text := trim(coalesce(p_provider_message_id,''));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
begin
  if length(v_event_id) < 8 or length(v_event_id) > 255 then return jsonb_build_object('ok',false,'error','INVALID_PROVIDER_EVENT_ID'); end if;
  if v_message_id='' then return jsonb_build_object('ok',false,'error','PROVIDER_MESSAGE_ID_REQUIRED'); end if;
  if v_type not in ('email.delivered','email.bounced','email.complained','email.opened','email.clicked','email.delivery_delayed') then
    return jsonb_build_object('ok',false,'error','UNSUPPORTED_PROVIDER_EVENT');
  end if;
  if jsonb_typeof(v_payload) <> 'object' then return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD'); end if;

  select * into v_req
  from public.aos_cia_email_send_requests
  where provider='RESEND' and provider_message_id=v_message_id
  for update;
  if v_req.id is null then return jsonb_build_object('ok',false,'error','PROVIDER_MESSAGE_NOT_FOUND'); end if;

  begin
    insert into public.aos_cia_email_send_events(request_id,event_type,provider_event_id,payload,occurred_at)
    values(v_req.id,upper(replace(v_type,'.','_')),v_event_id,v_payload,coalesce(p_occurred_at,now()));
  exception when unique_violation then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true);
  end;

  if v_type='email.delivered' and v_req.state='ACCEPTED' then
    update public.aos_cia_email_send_requests set state='DELIVERED',delivered_at=coalesce(delivered_at,coalesce(p_occurred_at,now())) where id=v_req.id;
    v_req.state:='DELIVERED';
  elsif v_type='email.bounced' and v_req.state='ACCEPTED' then
    update public.aos_cia_email_send_requests set state='BOUNCED' where id=v_req.id;
    v_req.state:='BOUNCED';
  elsif v_type='email.complained' and v_req.state in ('ACCEPTED','DELIVERED') then
    update public.aos_cia_email_send_requests set state='COMPLAINED' where id=v_req.id;
    v_req.state:='COMPLAINED';
  end if;

  return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',false);
end
$function$;

create or replace function public.aos_cia_email_release_mark_v1(
  p_gate text,
  p_value boolean,
