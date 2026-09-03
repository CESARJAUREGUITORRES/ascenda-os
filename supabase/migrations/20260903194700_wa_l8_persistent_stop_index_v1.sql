-- WA-L8 persistent customer STOP hardening.
-- Keeps opt-out effective even when later inbound messages exist, without adding
-- triggers or scanning a conversation's full history on the autonomous hot path.

begin;

create index if not exists aos_wa_l8_message_stop_idx
  on public.aos_wa_messages_v1(conversation_id,created_at desc)
  where direction='INBOUND'
    and pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            pg_catalog.translate(pg_catalog.lower(pg_catalog.btrim(coalesce(message_body,''))),'áéíóúüñ','aeiouun'),
            '[[:punct:]]',' ','g'),
          '[[:space:]]+',' ','g')
        ~ '^(stop|baja|cancelar suscripcion|no quiero mensajes|no me escriban|no mas mensajes)$';

create or replace function public.aos_wa_l8_autonomous_preflight_v1(
  p_conversation_id uuid,
  p_recipient_kind text,
  p_recipient_address text,
  p_message_type text,
  p_template_name text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_kind text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_recipient_kind,'')));
  v_address text:=public.aos_wa_l4_normalize_subject_v1(v_kind,p_recipient_address);
  v_type text:=pg_catalog.lower(pg_catalog.btrim(coalesce(p_message_type,'')));
  v_template text:=nullif(pg_catalog.btrim(coalesce(p_template_name,'')),'');
  v_hash text;
  v_existing public.aos_wa_l8_preflight_decisions_v1%rowtype;
  v_last_inbound timestamptz;
  v_stop_at timestamptz;
  v_consent_action text;
  v_consent_at timestamptz;
  v_window boolean:=false;
  v_decision text:='PASS';
  v_reason text:='WA_L8_SERVICE_WINDOW_OK';
  v_id uuid;
begin
  if coalesce(p_idempotency_key,'') !~ '^[A-Za-z0-9._:-]{16,120}$' then
    return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_INVALID_IDEMPOTENCY_KEY');
  end if;
  select * into v_existing from public.aos_wa_l8_preflight_decisions_v1 where idempotency_key=p_idempotency_key;
  if v_existing.id is not null then
    return pg_catalog.jsonb_build_object('ok',v_existing.decision='PASS','replay',true,'preflight_id',v_existing.id,
      'decision',v_existing.decision,'reason',v_existing.reason_code,'service_window_open',v_existing.service_window_open);
  end if;

  if v_kind not in ('PHONE','BSUID') or v_address is null then
    return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_INVALID_RECIPIENT');
  end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id;
  if v_conv.id is null then return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_CONVERSATION_NOT_FOUND'); end if;
  v_hash:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(v_kind||':'||v_address,'UTF8'),'sha256'),'hex');

  -- Latest inbound uses the certified conversation index and stops after one row.
  select coalesce(m.provider_timestamp,m.received_at,m.created_at)
    into v_last_inbound
  from public.aos_wa_messages_v1 m
  where m.conversation_id=p_conversation_id and m.direction='INBOUND'
  order by m.created_at desc
  limit 1;

  -- Persistent customer STOP uses the small partial index above. A later ordinary
  -- inbound does not erase the opt-out. A later evidence-backed OPT_IN may supersede it.
  select coalesce(m.provider_timestamp,m.received_at,m.created_at)
    into v_stop_at
  from public.aos_wa_messages_v1 m
  where m.conversation_id=p_conversation_id
    and m.direction='INBOUND'
    and pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            pg_catalog.translate(pg_catalog.lower(pg_catalog.btrim(coalesce(m.message_body,''))),'áéíóúüñ','aeiouun'),
            '[[:punct:]]',' ','g'),
          '[[:space:]]+',' ','g')
        ~ '^(stop|baja|cancelar suscripcion|no quiero mensajes|no me escriban|no mas mensajes)$'
  order by m.created_at desc
  limit 1;

  select c.action,c.created_at into v_consent_action,v_consent_at
  from public.aos_wa_l8_consent_events_v1 c
  where c.recipient_hash=v_hash
  order by c.created_at desc
  limit 1;

  v_window:=(v_last_inbound is not null and v_last_inbound>=pg_catalog.now()-interval '24 hours');

  if v_conv.contact_address_type<>v_kind or v_conv.contact_address<>v_address then
    v_decision:='HANDOFF';v_reason:='WA_L8_RECIPIENT_CONVERSATION_MISMATCH';
  elsif (v_consent_action='OPT_OUT' and (v_stop_at is null or v_consent_at>=v_stop_at))
     or (v_stop_at is not null and (v_consent_at is null or v_consent_action<>'OPT_IN' or v_consent_at<=v_stop_at)) then
    v_decision:='BLOCK';v_reason:='WA_L8_OPT_OUT_ACTIVE';
  elsif v_window then
    v_decision:='PASS';v_reason:='WA_L8_SERVICE_WINDOW_OK';
  elsif v_type<>'template' or v_template is null then
    v_decision:='BLOCK';v_reason:='WA_L8_TEMPLATE_REQUIRED_OUTSIDE_24H';
  elsif v_consent_action='OPT_IN' and (v_stop_at is null or v_consent_at>v_stop_at) then
    v_decision:='PASS';v_reason:='WA_L8_BUSINESS_INITIATED_OPT_IN_OK';
  else
    v_decision:='BLOCK';v_reason:='WA_L8_BUSINESS_INITIATED_OPT_IN_REQUIRED';
  end if;

  begin
    insert into public.aos_wa_l8_preflight_decisions_v1(
      idempotency_key,conversation_id,recipient_hash,message_type,template_name,decision,reason_code,
      service_window_open,last_inbound_at,latest_stop_at,consent_action,consent_at)
    values(p_idempotency_key,p_conversation_id,v_hash,v_type,v_template,v_decision,v_reason,
      v_window,v_last_inbound,v_stop_at,v_consent_action,v_consent_at)
    returning id into v_id;
  exception when unique_violation then
    select * into v_existing from public.aos_wa_l8_preflight_decisions_v1 where idempotency_key=p_idempotency_key;
    return pg_catalog.jsonb_build_object('ok',v_existing.decision='PASS','replay',true,'preflight_id',v_existing.id,
      'decision',v_existing.decision,'reason',v_existing.reason_code,'service_window_open',v_existing.service_window_open);
  end;

  return pg_catalog.jsonb_build_object('ok',v_decision='PASS','replay',false,'preflight_id',v_id,'decision',v_decision,
    'reason',v_reason,'service_window_open',v_window,'last_inbound_at',v_last_inbound,
    'consent_action',v_consent_action,'consent_at',v_consent_at,'latest_stop_at',v_stop_at);
end
$$;

revoke all on function public.aos_wa_l8_autonomous_preflight_v1(uuid,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l8_autonomous_preflight_v1(uuid,text,text,text,text,text) to service_role;

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
