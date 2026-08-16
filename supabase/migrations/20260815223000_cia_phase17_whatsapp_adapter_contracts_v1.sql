-- CIA V3 F17 — WhatsApp adapter governance contracts v1
-- Adds canary-only controls, dispatch transitions and minimal inbound/provider-event ingestion.

alter table public.aos_cia_channel_recipient_controls_v1
  add column if not exists expires_at timestamptz;

-- Source-aware prepare: SYSTEM_CANARY controls are NEVER valid for ordinary sends.
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
  v_control_source text := 'UNSET';
  v_expires_at timestamptz;
  v_canary boolean := coalesce((p_payload->'context'->>'canary')::boolean,false);
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

  select c.consent_status,c.suppression_status,c.source,c.expires_at
    into v_consent,v_suppression,v_control_source,v_expires_at
  from public.aos_cia_channel_recipient_controls_v1 c
  where c.contact_key=v_contact_key and c.channel=v_channel;

  v_consent := coalesce(v_consent,'UNKNOWN');
  v_suppression := coalesce(v_suppression,'UNKNOWN');
  v_control_source := coalesce(v_control_source,'UNSET');

  -- Expired controls fail closed. SYSTEM_CANARY is valid only in an explicit canary context.
  if v_expires_at is not null and v_expires_at <= now() then
    v_consent := 'UNKNOWN';
    v_suppression := 'UNKNOWN';
  elsif v_control_source='SYSTEM_CANARY' and v_canary is not true then
    v_consent := 'UNKNOWN';
    v_suppression := 'UNKNOWN';
  end if;

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
    coalesce(p_payload->'context','{}'::jsonb) || jsonb_build_object('recipient_control_source',v_control_source)
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

-- Service-only registration of a fixed allowlist canary recipient.
create or replace function public.aos_cia_channel_register_canary_recipient_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_channel text := upper(trim(coalesce(p_payload->>'channel','')));
  v_contact_key text;
  v_requested_by uuid;
  v_ttl integer := greatest(5,least(120,coalesce((p_payload->>'ttl_minutes')::integer,30)));
  v_expires timestamptz;
begin
  if v_channel <> 'WHATSAPP' then
    raise exception 'CANARY_CHANNEL_NOT_ALLOWED' using errcode='22023';
  end if;
  if coalesce((p_payload->>'allowlist_verified')::boolean,false) is not true then
    raise exception 'CANARY_ALLOWLIST_NOT_VERIFIED' using errcode='42501';
  end if;
  v_contact_key := public.aos_cia_normalize_contact_key_v1(p_payload->>'recipient_contact');
  if v_contact_key is null then raise exception 'CONTACT_KEY_INVALID' using errcode='22023'; end if;
  if nullif(p_payload->>'requested_by_user_id','') is not null then v_requested_by := (p_payload->>'requested_by_user_id')::uuid; end if;
  v_expires := now() + make_interval(mins => v_ttl);

  insert into public.aos_cia_channel_recipient_controls_v1(
    contact_key,channel,consent_status,suppression_status,source,evidence,updated_by_user_id,expires_at,updated_at
  ) values (
    v_contact_key,'WHATSAPP','ALLOWED','CLEAR','SYSTEM_CANARY',
    jsonb_build_object('scope','fixed_allowlist_canary','ttl_minutes',v_ttl),v_requested_by,v_expires,now()
  )
  on conflict(contact_key,channel) do update set
    consent_status='ALLOWED',suppression_status='CLEAR',source='SYSTEM_CANARY',
    evidence=excluded.evidence,updated_by_user_id=excluded.updated_by_user_id,
    expires_at=excluded.expires_at,updated_at=now();

  return jsonb_build_object('ok',true,'contact_key',v_contact_key,'channel','WHATSAPP','source','SYSTEM_CANARY','expires_at',v_expires);
end
$$;

create or replace function public.aos_cia_channel_mark_dispatch_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_request_id uuid := (p_payload->>'request_id')::uuid;
  v_outcome text := upper(trim(coalesce(p_payload->>'outcome','')));
  v_provider text := nullif(trim(coalesce(p_payload->>'provider','')),'');
  v_provider_message_id text := nullif(trim(coalesce(p_payload->>'provider_message_id','')),'');
  v_row public.aos_cia_channel_send_requests_v1%rowtype;
begin
  if v_outcome not in ('ACCEPTED','FAILED') then raise exception 'DISPATCH_OUTCOME_INVALID' using errcode='22023'; end if;
  select * into v_row from public.aos_cia_channel_send_requests_v1 where id=v_request_id for update;
  if v_row.id is null then raise exception 'REQUEST_NOT_FOUND' using errcode='23503'; end if;
  if v_row.state='BLOCKED' then raise exception 'BLOCKED_REQUEST_CANNOT_DISPATCH' using errcode='42501'; end if;

  if v_outcome='ACCEPTED' then
    if v_provider is null or v_provider_message_id is null then raise exception 'PROVIDER_ACCEPTANCE_REQUIRED' using errcode='22023'; end if;
    if v_row.state='ACCEPTED' and v_row.provider_message_id=v_provider_message_id then
      return jsonb_build_object('ok',true,'idempotent',true,'request_id',v_row.id,'state',v_row.state,'provider_message_id',v_row.provider_message_id);
    end if;
    if v_row.state not in ('READY','DISPATCHING') then raise exception 'INVALID_DISPATCH_TRANSITION' using errcode='55000'; end if;
    update public.aos_cia_channel_send_requests_v1
      set state='ACCEPTED',provider=v_provider,provider_message_id=v_provider_message_id,
          dispatch_attempts=dispatch_attempts+1,accepted_at=coalesce(accepted_at,now()),updated_at=now()
      where id=v_row.id returning * into v_row;
  else
    if v_row.state='FAILED' then
      return jsonb_build_object('ok',true,'idempotent',true,'request_id',v_row.id,'state',v_row.state);
    end if;
    if v_row.state not in ('READY','DISPATCHING') then raise exception 'INVALID_DISPATCH_TRANSITION' using errcode='55000'; end if;
    update public.aos_cia_channel_send_requests_v1
      set state='FAILED',provider=coalesce(v_provider,provider),dispatch_attempts=dispatch_attempts+1,
          terminal_at=coalesce(terminal_at,now()),updated_at=now(),
          context=context || jsonb_build_object('dispatch_error_code',nullif(trim(coalesce(p_payload->>'error_code','')),''))
      where id=v_row.id returning * into v_row;
  end if;

  return jsonb_build_object('ok',true,'idempotent',false,'request_id',v_row.id,'state',v_row.state,'provider_message_id',v_row.provider_message_id);
end
$$;

create or replace function public.aos_cia_channel_ingest_inbound_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_channel text := upper(trim(coalesce(p_payload->>'channel','')));
  v_provider_message_id text := trim(coalesce(p_payload->>'provider_message_id',''));
  v_contact_key text;
  v_identity_status text := 'UNRESOLVED';
  v_id uuid;
begin
  if v_channel not in ('WHATSAPP','SMS') or v_provider_message_id='' then raise exception 'INBOUND_CONTRACT_INVALID' using errcode='22023'; end if;
  v_contact_key := public.aos_cia_normalize_contact_key_v1(p_payload->>'sender_contact');
  if v_contact_key is not null then
    if exists(select 1 from public.aos_cia_contact_identity_v1 i where i.contact_key=v_contact_key and i.identity_conflict is true) then
      v_identity_status := 'CONFLICT';
    elsif exists(select 1 from public.aos_cia_contact_identity_v1 i where i.contact_key=v_contact_key) then
      v_identity_status := 'RESOLVED';
    end if;
  end if;

  insert into public.aos_cia_channel_inbound_facts_v1(
    channel,provider_message_id,contact_key,identity_status,conversation_ref,message_type,provider_timestamp,attribution_ref
  ) values (
    v_channel,v_provider_message_id,v_contact_key,v_identity_status,
    nullif(trim(coalesce(p_payload->>'conversation_ref','')),''),
    upper(trim(coalesce(p_payload->>'message_type','UNKNOWN'))),
    case when nullif(p_payload->>'provider_timestamp','') is null then null else (p_payload->>'provider_timestamp')::timestamptz end,
    coalesce(p_payload->'attribution_ref','{}'::jsonb)
  )
  on conflict(channel,provider_message_id) do nothing
  returning id into v_id;

  return jsonb_build_object('ok',true,'inserted',v_id is not null,'id',v_id,'contact_key',v_contact_key,'identity_status',v_identity_status);
end
$$;

create or replace function public.aos_cia_channel_record_provider_event_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_channel text := upper(trim(coalesce(p_payload->>'channel','')));
  v_provider_message_id text := trim(coalesce(p_payload->>'provider_message_id',''));
  v_request_id uuid;
  v_result jsonb;
begin
  if v_channel not in ('WHATSAPP','SMS') or v_provider_message_id='' then raise exception 'PROVIDER_EVENT_CONTRACT_INVALID' using errcode='22023'; end if;
  select r.id into v_request_id
  from public.aos_cia_channel_send_requests_v1 r
  where r.channel=v_channel and r.provider_message_id=v_provider_message_id
  order by r.created_at desc limit 1;

  if v_request_id is null then
    return jsonb_build_object('ok',true,'linked',false,'inserted',false,'provider_message_id',v_provider_message_id);
  end if;

  v_result := public.aos_cia_channel_record_event_v1(jsonb_build_object(
    'request_id',v_request_id,
    'channel',v_channel,
    'event_key',p_payload->>'event_key',
    'event_type',p_payload->>'event_type',
    'provider_message_id',v_provider_message_id,
    'status',p_payload->>'status',
    'payload',coalesce(p_payload->'payload','{}'::jsonb),
    'occurred_at',coalesce(p_payload->>'occurred_at',now()::text)
  ));
  return v_result || jsonb_build_object('linked',true,'request_id',v_request_id);
end
$$;

revoke all on function public.aos_cia_channel_register_canary_recipient_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_channel_mark_dispatch_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_channel_ingest_inbound_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_channel_record_provider_event_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_cia_channel_register_canary_recipient_v1(jsonb) to service_role;
grant execute on function public.aos_cia_channel_mark_dispatch_v1(jsonb) to service_role;
grant execute on function public.aos_cia_channel_ingest_inbound_v1(jsonb) to service_role;
grant execute on function public.aos_cia_channel_record_provider_event_v1(jsonb) to service_role;

comment on function public.aos_cia_channel_register_canary_recipient_v1(jsonb) is 'F17 service-only fixed-allowlist canary control. SYSTEM_CANARY expires and cannot authorize ordinary sends.';
comment on function public.aos_cia_channel_mark_dispatch_v1(jsonb) is 'F17 service-only provider dispatch state transition with idempotent acceptance.';
comment on function public.aos_cia_channel_ingest_inbound_v1(jsonb) is 'F17 service-only minimal inbound fact ingestion; stores no message body.';
comment on function public.aos_cia_channel_record_provider_event_v1(jsonb) is 'F17 service-only provider event linkage/dedup against governed outbound requests.';