    values(v_req.id,'DISPATCH_BLOCKED',jsonb_build_object('eligibility',v_elig));
    return jsonb_build_object('ok',false,'error','EMAIL_NOT_ELIGIBLE_AT_DISPATCH','request_id',v_req.id,'state','CANCELLED','send_allowed',false,'eligibility',v_elig);
  end if;

  select * into v_tpl from public.aos_cia_email_template_versions where id=v_req.template_version_id;
  if v_tpl.id is null or v_tpl.state <> 'ACTIVE' or v_tpl.content_digest <> v_req.template_digest then
    update public.aos_cia_email_send_requests set state='CANCELLED' where id=v_req.id;
    insert into public.aos_cia_email_send_events(request_id,event_type,payload)
    values(v_req.id,'DISPATCH_BLOCKED',jsonb_build_object('reason','TEMPLATE_DRIFT_OR_INACTIVE'));
    return jsonb_build_object('ok',false,'error','TEMPLATE_DRIFT_OR_INACTIVE','request_id',v_req.id,'state','CANCELLED','send_allowed',false);
  end if;

  update public.aos_cia_email_send_requests
     set state='DISPATCHING',provider='RESEND',dispatch_attempts=dispatch_attempts+1
   where id=v_req.id;
  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_req.id,'DISPATCHING',jsonb_build_object('provider','RESEND','attempt',v_req.dispatch_attempts+1));

  return jsonb_build_object(
    'ok',true,'request_id',v_req.id,'correlation_id',v_req.correlation_id,
    'recipient_email',v_req.recipient_email,'purpose',v_req.purpose,
    'subject_template',v_tpl.subject_template,'html_template',v_tpl.html_template,
    'variable_keys',to_jsonb(v_tpl.variable_keys),'render_context',v_req.render_context,
    'idempotency_key',v_req.idempotency_key,'state','DISPATCHING','send_allowed',true
  );
end
$function$;

create or replace function public.aos_cia_email_record_dispatch_result_v2(
  p_request_id uuid,
  p_accepted boolean,
  p_provider text,
  p_provider_message_id text default null,
  p_error_code text default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_req record;
  v_provider text := upper(trim(coalesce(p_provider,'')));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
