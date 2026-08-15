-- ASCENDA OS CIA V3 — F16 Resend provider outcome coverage v3
-- Additive hardening: cover asynchronous failed/suppressed events and make
-- bounce/complaint/suppression feed the canonical Email suppression control.
-- No provider call is performed by SQL.

begin;

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
declare
  v_req record;
  v_type text := lower(trim(coalesce(p_event_type,'')));
  v_event_id text := trim(coalesce(p_provider_event_id,''));
  v_message_id text := trim(coalesce(p_provider_message_id,''));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_suppression_reason text;
begin
  if length(v_event_id) < 8 or length(v_event_id) > 255 then
    return jsonb_build_object('ok',false,'error','INVALID_PROVIDER_EVENT_ID');
  end if;
  if v_message_id='' then
    return jsonb_build_object('ok',false,'error','PROVIDER_MESSAGE_ID_REQUIRED');
  end if;
  if v_type not in (
    'email.delivered','email.bounced','email.complained','email.opened','email.clicked','email.delivery_delayed',
    'email.failed','email.suppressed'
  ) then
    return jsonb_build_object('ok',false,'error','UNSUPPORTED_PROVIDER_EVENT');
  end if;
  if jsonb_typeof(v_payload) <> 'object' then
    return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
  end if;

  select * into v_req
  from public.aos_cia_email_send_requests
  where provider='RESEND' and provider_message_id=v_message_id
  for update;
  if v_req.id is null then
    return jsonb_build_object('ok',false,'error','PROVIDER_MESSAGE_NOT_FOUND');
  end if;

  begin
    insert into public.aos_cia_email_send_events(request_id,event_type,provider_event_id,payload,occurred_at)
    values(v_req.id,upper(replace(v_type,'.','_')),v_event_id,v_payload,coalesce(p_occurred_at,now()));
  exception when unique_violation then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true);
  end;

  if v_type='email.delivered' and v_req.state='ACCEPTED' then
    update public.aos_cia_email_send_requests
       set state='DELIVERED',delivered_at=coalesce(delivered_at,coalesce(p_occurred_at,now()))
     where id=v_req.id;
    v_req.state:='DELIVERED';
  elsif v_type='email.bounced' and v_req.state='ACCEPTED' then
    update public.aos_cia_email_send_requests set state='BOUNCED' where id=v_req.id;
    v_req.state:='BOUNCED';
  elsif v_type='email.complained' and v_req.state in ('ACCEPTED','DELIVERED') then
    update public.aos_cia_email_send_requests set state='COMPLAINED' where id=v_req.id;
    v_req.state:='COMPLAINED';
  elsif v_type in ('email.failed','email.suppressed') and v_req.state in ('DISPATCHING','ACCEPTED') then
    update public.aos_cia_email_send_requests set state='FAILED' where id=v_req.id;
    v_req.state:='FAILED';
  end if;

  if v_type in ('email.bounced','email.complained','email.suppressed') then
    v_suppression_reason := upper(replace(v_type,'email.','RESEND_'));
    insert into public.aos_cia_email_recipient_controls(
      contact_key,marketing_consent,global_suppressed,suppression_reason,source,source_updated_at,updated_by_user_id
    ) values(
      v_req.contact_key,'UNKNOWN',true,v_suppression_reason,'RESEND_WEBHOOK',coalesce(p_occurred_at,now()),null
    )
    on conflict (contact_key) do update
      set global_suppressed=true,
          suppression_reason=excluded.suppression_reason,
          source='RESEND_WEBHOOK',
          source_updated_at=excluded.source_updated_at,
          updated_by_user_id=null;
  end if;

  return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',false);
end
$function$;

revoke all on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) to service_role;

comment on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) is
  'F16 service-role Resend outcome ingestion after cryptographic webhook verification. Covers delivery, bounce, complaint, delayed/open/click, failed and suppressed; provider suppression outcomes fail closed into recipient controls.';

commit;
