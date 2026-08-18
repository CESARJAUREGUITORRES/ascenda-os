-- CIA V3 F17 WhatsApp adapter governance v1 rollback.
-- Restores the Phase17 base prepare contract and removes only adapter additions.

drop function if exists public.aos_cia_channel_record_provider_event_v1(jsonb);
drop function if exists public.aos_cia_channel_ingest_inbound_v1(jsonb);
drop function if exists public.aos_cia_channel_mark_dispatch_v1(jsonb);
drop function if exists public.aos_cia_channel_register_canary_recipient_v1(jsonb);

alter table public.aos_cia_channel_recipient_controls_v1 drop column if exists expires_at;

create or replace function public.aos_cia_channel_prepare_send_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_f16 jsonb;
  v_channel text;
  v_contact_key text;
  v_purpose text;
  v_message_class text;
  v_idempotency_key text;
  v_activation_id uuid;
  v_requested_by uuid;
  v_consent text := 'UNKNOWN';
  v_suppression text := 'UNKNOWN';
  v_eligibility text;
  v_state text;
  v_row public.aos_cia_channel_send_requests_v1%rowtype;
begin
  v_f16 := public.aos_cia_email_f17_readiness_v1();
  if coalesce((v_f16->>'ready_for_f17')::boolean,false) is not true then
    raise exception 'F17_DEPENDENCY_NOT_READY' using errcode='55000';
  end if;

  v_channel := upper(trim(coalesce(p_payload->>'channel','')));
  if v_channel not in ('WHATSAPP','SMS') then
    raise exception 'CHANNEL_NOT_SUPPORTED' using errcode='22023';
  end if;

  v_contact_key := public.aos_cia_normalize_contact_key_v1(p_payload->>'recipient_contact');
  if v_contact_key is null then
    raise exception 'CONTACT_KEY_INVALID' using errcode='22023';
  end if;

  v_purpose := trim(coalesce(p_payload->>'purpose',''));
  v_message_class := upper(trim(coalesce(p_payload->>'message_class','')));
  v_idempotency_key := trim(coalesce(p_payload->>'idempotency_key',''));
  if v_purpose='' or v_message_class='' or length(v_idempotency_key) not between 16 and 200 then
    raise exception 'REQUEST_CONTRACT_INVALID' using errcode='22023';
  end if;

  if nullif(p_payload->>'activation_id','') is not null then
    v_activation_id := (p_payload->>'activation_id')::uuid;
    if not exists(select 1 from public.aos_audiencia_activaciones a where a.id=v_activation_id) then
      raise exception 'ACTIVATION_NOT_FOUND' using errcode='23503';
    end if;
  end if;

  if nullif(p_payload->>'requested_by_user_id','') is not null then
    v_requested_by := (p_payload->>'requested_by_user_id')::uuid;
  end if;

  select c.consent_status,c.suppression_status
    into v_consent,v_suppression
  from public.aos_cia_channel_recipient_controls_v1 c
  where c.contact_key=v_contact_key and c.channel=v_channel;

  v_consent := coalesce(v_consent,'UNKNOWN');
  v_suppression := coalesce(v_suppression,'UNKNOWN');
  v_eligibility := case when v_consent='ALLOWED' and v_suppression='CLEAR' then 'ALLOWED' else 'BLOCKED' end;
  v_state := case when v_eligibility='ALLOWED' then 'READY' else 'BLOCKED' end;

  insert into public.aos_cia_channel_send_requests_v1(
    activation_id,contact_key,channel,purpose,message_class,idempotency_key,
    eligibility_status,consent_status,suppression_status,state,requested_by_user_id,
    authorization_provenance,context
  ) values (
    v_activation_id,v_contact_key,v_channel,v_purpose,v_message_class,v_idempotency_key,
    v_eligibility,v_consent,v_suppression,v_state,v_requested_by,
    coalesce(p_payload->'authorization_provenance','{}'::jsonb),
    coalesce(p_payload->'context','{}'::jsonb)
  )
  on conflict (idempotency_key) do nothing
  returning * into v_row;

  if v_row.id is null then
    select * into v_row from public.aos_cia_channel_send_requests_v1 where idempotency_key=v_idempotency_key;
  end if;

  return jsonb_build_object(
    'ok',true,
    'request_id',v_row.id,
    'state',v_row.state,
    'eligibility_status',v_row.eligibility_status,
    'consent_status',v_row.consent_status,
    'suppression_status',v_row.suppression_status,
    'channel',v_row.channel,
    'contact_key',v_row.contact_key,
    'dispatch_allowed',v_row.state='READY'
  );
end
$$;

revoke all on function public.aos_cia_channel_prepare_send_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_cia_channel_prepare_send_v1(jsonb) to service_role;