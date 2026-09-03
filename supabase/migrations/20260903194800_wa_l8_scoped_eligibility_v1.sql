-- WA-L8 final consent hardening: one scoped eligibility authority, zero extra consent UX.
-- WA-7A.4 is the sole consent/suppression authority. The early L8 consent table stays
-- inert only for migration compatibility and receives no further writes.
-- No CANARY transition, provider dispatch, business-ledger mutation or hot-path trigger.

begin;

do $$
begin
  if to_regclass('public.aos_wa_marketing_eligibility_events_v1') is null
     or to_regprocedure('public.aos_wa_marketing_eligibility_check_v1(uuid,text)') is null
     or to_regprocedure('public.aos_wa_marketing_eligibility_record_v1(jsonb)') is null then
    raise exception 'WA_L8_SCOPED_ELIGIBILITY_AUTHORITY_REQUIRED';
  end if;
end $$;

-- The first L8 draft introduced a local consent ledger. It never became PROD authority.
-- Keep the empty table structurally for rollback compatibility, but make it inert.
drop function if exists public.aos_wa_l8_consent_record_v1(text,uuid,text,text,text);
revoke all on table public.aos_wa_l8_consent_events_v1 from public,anon,authenticated,service_role;
comment on table public.aos_wa_l8_consent_events_v1 is
  'WA-L8 deprecated/inert compatibility table. WA-7A.4 aos_wa_marketing_eligibility_events_v1 is the sole consent/suppression authority.';

alter table public.aos_wa_l8_preflight_decisions_v1
  add column if not exists eligibility_scope text,
  add column if not exists eligibility_status text,
  add column if not exists eligibility_reason text;

-- Current appointment templates are Utility. Unknown future templates are classified
-- conservatively as Marketing until their provider/category authority is explicit.
create or replace function public.aos_wa_l8_scope_for_send_v1(
  p_message_type text,
  p_template_name text
) returns text
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_type text:=pg_catalog.lower(pg_catalog.btrim(coalesce(p_message_type,'')));
  v_template text:=nullif(pg_catalog.btrim(coalesce(p_template_name,'')),'');
begin
  if v_type<>'template' or v_template is null then return 'SERVICE_WINDOW'; end if;
  if exists(
    select 1
    from public.aos_agenda_delivery_template_registry_v3 t
    where t.channel='WHATSAPP'
      and t.provider='META_CLOUD_API'
      and t.active is true
      and t.provider_verified is true
      and t.provider_template_name=v_template
      and t.delivery_kind in ('CONFIRMATION','REPROGRAMMATION','REMINDER_TOMORROW','REMINDER_TODAY')
  ) then return 'UTILITY'; end if;
  return 'MARKETING';
end
$$;

revoke all on function public.aos_wa_l8_scope_for_send_v1(text,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l8_scope_for_send_v1(text,text) to service_role;

-- Human/admin evidence recorder. No raw phone/BSUID is duplicated; authority is
-- conversation-scoped and append-only in WA-7A.4.
create or replace function public.aos_wa_l8_consent_record_v2(
  p_token text,
  p_conversation_id uuid,
  p_scope text,
  p_action text,
  p_source text,
  p_evidence_ref text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid;
  v_scope text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_scope,'')));
  v_action text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_action,'')));
  v_source text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_source,'')));
  v_evidence text:=nullif(pg_catalog.btrim(coalesce(p_evidence_ref,'')),'');
  v_key text;
  v_payload jsonb;
  v_result jsonb;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-whatsapp',true);
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_ADMIN_2FA_REQUIRED'); end if;
  if v_scope not in ('GLOBAL','MARKETING','UTILITY','AUTHENTICATION') then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_SCOPE_INVALID');
  end if;
  if v_action not in ('OPT_IN','OPT_OUT') then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_CONSENT_ACTION_INVALID');
  end if;
  if v_source not in ('ADMIN_EVIDENCE','CUSTOMER_REQUEST','PRIVACY_FORM','BOOKING_DISCLOSURE','OTHER_VERIFIED') then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_CONSENT_SOURCE_INVALID');
  end if;
  if v_evidence is null or pg_catalog.length(v_evidence) not between 8 and 1000 then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_CONSENT_EVIDENCE_REQUIRED');
  end if;
  if not exists(select 1 from public.aos_wa_conversations_v1 c where c.id=p_conversation_id) then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_CONVERSATION_NOT_FOUND');
  end if;

  v_key:='l8:'||pg_catalog.lower(v_scope)||':'||pg_catalog.lower(v_action)||':'||p_conversation_id::text||':'||
    pg_catalog.substring(pg_catalog.encode(extensions.digest(pg_catalog.convert_to(v_evidence||'|'||pg_catalog.clock_timestamp()::text,'UTF8'),'sha256'),'hex') from 1 for 24);
  v_payload:=pg_catalog.jsonb_build_object(
    'event_key',v_key,
    'conversation_id',p_conversation_id,
    'eligibility_scope',v_scope,
    'consent_status',case when v_action='OPT_IN' then 'ALLOWED' else 'DENIED' end,
    'suppression_status',case when v_action='OPT_IN' then 'CLEAR' else 'SUPPRESSED' end,
    'source',v_source,
    'source_ref',v_evidence,
    'policy_version','WA_L8_SCOPED_CONSENT_V1',
    'evidence',pg_catalog.jsonb_build_object(
      'action',v_action,
      'explicit_reconsent',v_action='OPT_IN',
      'raw_recipient_stored',false
    ),
    'actor_user_id',v_actor,
    'observed_at',pg_catalog.clock_timestamp()
  );
  v_result:=public.aos_wa_marketing_eligibility_record_v1(v_payload);
  return coalesce(v_result,'{}'::jsonb)||pg_catalog.jsonb_build_object('scope',v_scope,'action',v_action,'authority','WA7A4');
end
$$;

revoke all on function public.aos_wa_l8_consent_record_v2(text,uuid,text,text,text,text) from public;
grant execute on function public.aos_wa_l8_consent_record_v2(text,uuid,text,text,text,text) to anon,authenticated,service_role;

-- Zero-friction transactional consent: the same explicit affirmative that confirms a
-- booking may grant Utility messaging only when a versioned disclosure was shown.
-- This function does not infer consent from merely having a booking.
create or replace function public.aos_wa_l8_record_booking_utility_optin_v1(
  p_conversation_id uuid,
  p_confirmation_provider_message_id text,
  p_disclosure_version text,
  p_evidence_ref text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_provider text:=nullif(pg_catalog.btrim(coalesce(p_confirmation_provider_message_id,'')),'');
  v_disclosure text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_disclosure_version,'')));
  v_evidence text:=nullif(pg_catalog.btrim(coalesce(p_evidence_ref,'')),'');
  v_confirmed_at timestamptz;
  v_operation_id uuid;
  v_key text;
  v_result jsonb;
begin
  if v_disclosure<>'WA_L8_BOOKING_UTILITY_V1' then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_UTILITY_DISCLOSURE_VERSION_REQUIRED');
  end if;
  if v_provider is null or v_evidence is null or pg_catalog.length(v_evidence) not between 8 and 1000 then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_UTILITY_EVIDENCE_REQUIRED');
  end if;

  -- Prove the affirmative came from this customer/conversation and was accepted by L5.
  select e.created_at into v_confirmed_at
  from public.aos_wa_l5_booking_events_v1 e
  where e.conversation_id=p_conversation_id
    and e.event_type='CONFIRMED'
    and e.metadata->>'provider_message_id'=v_provider
  order by e.created_at desc
  limit 1;
  if v_confirmed_at is null or not exists(
    select 1 from public.aos_wa_messages_v1 m
    where m.conversation_id=p_conversation_id
      and m.provider_message_id=v_provider
      and m.direction='INBOUND'
  ) then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_UTILITY_CUSTOMER_CONFIRMATION_REQUIRED');
  end if;

  -- Prove the confirmed flow actually committed a WhatsApp BOOK/REBOOK.
  select o.id into v_operation_id
  from public.aos_booking_operations_v2 o
  join public.aos_wa_l5_booking_events_v1 e
    on e.operation_id=o.id and e.conversation_id=p_conversation_id and e.event_type='COMMITTED'
  where o.conversation_id=p_conversation_id
    and o.channel='WHATSAPP'
    and o.operation_type in ('BOOK','REBOOK')
    and o.status in ('BOOKED','REBOOKED')
    and e.created_at>=v_confirmed_at
  order by e.created_at asc
  limit 1;
  if v_operation_id is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_UTILITY_COMMITTED_BOOKING_REQUIRED');
  end if;

  v_key:='l8:utility:booking:'||p_conversation_id::text||':'||
    pg_catalog.substring(pg_catalog.encode(extensions.digest(pg_catalog.convert_to(v_provider||'|'||v_disclosure,'UTF8'),'sha256'),'hex') from 1 for 24);
  v_result:=public.aos_wa_marketing_eligibility_record_v1(pg_catalog.jsonb_build_object(
    'event_key',v_key,
    'conversation_id',p_conversation_id,
    'eligibility_scope','UTILITY',
    'consent_status','ALLOWED',
    'suppression_status','CLEAR',
    'source','BOOKING_DISCLOSURE',
    'source_ref',v_evidence,
    'policy_version','WA_L8_SCOPED_CONSENT_V1',
    'evidence',pg_catalog.jsonb_build_object(
      'explicit_reconsent',true,
      'disclosure_version',v_disclosure,
      'confirmation_provider_message_id',v_provider,
      'operation_id',v_operation_id,
      'raw_recipient_stored',false
    ),
    'observed_at',v_confirmed_at
  ));
  return coalesce(v_result,'{}'::jsonb)||pg_catalog.jsonb_build_object(
    'scope','UTILITY','authority','WA7A4','operation_id',v_operation_id,'disclosure_version',v_disclosure
  );
end
$$;

revoke all on function public.aos_wa_l8_record_booking_utility_optin_v1(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l8_record_booking_utility_optin_v1(uuid,text,text,text) to service_role;

-- Final scoped preflight. Customer service responses inside 24h remain natural.
-- Outside 24h a template is mandatory and its category-specific eligibility must pass.
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
  v_reconsent_at timestamptz;
  v_window boolean:=false;
  v_scope text;
  v_elig jsonb:='{}'::jsonb;
  v_elig_status text;
  v_elig_reason text;
  v_decision text:='PASS';
  v_reason text:='WA_L8_SERVICE_WINDOW_OK';
  v_id uuid;
begin
  if coalesce(p_idempotency_key,'') !~ '^[A-Za-z0-9._:-]{16,120}$' then
    return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_INVALID_IDEMPOTENCY_KEY');
  end if;
  select * into v_existing from public.aos_wa_l8_preflight_decisions_v1 where idempotency_key=p_idempotency_key;
  if v_existing.id is not null then
    return pg_catalog.jsonb_build_object(
      'ok',v_existing.decision='PASS','replay',true,'preflight_id',v_existing.id,
      'decision',v_existing.decision,'reason',v_existing.reason_code,
      'service_window_open',v_existing.service_window_open,
      'eligibility_scope',v_existing.eligibility_scope,
      'eligibility_status',v_existing.eligibility_status,
      'eligibility_reason',v_existing.eligibility_reason
    );
  end if;
  if v_kind not in ('PHONE','BSUID') or v_address is null then
    return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_INVALID_RECIPIENT');
  end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id;
  if v_conv.id is null then return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_CONVERSATION_NOT_FOUND'); end if;
  v_hash:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(v_kind||':'||v_address,'UTF8'),'sha256'),'hex');
  v_scope:=public.aos_wa_l8_scope_for_send_v1(v_type,v_template);

  select coalesce(m.provider_timestamp,m.received_at,m.created_at)
    into v_last_inbound
  from public.aos_wa_messages_v1 m
  where m.conversation_id=p_conversation_id and m.direction='INBOUND'
  order by m.created_at desc
  limit 1;

  -- Uses WA-L8 partial STOP index; later ordinary messages do not erase opt-out.
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

  if v_stop_at is not null then
    select pg_catalog.max(e.observed_at) into v_reconsent_at
    from public.aos_wa_marketing_eligibility_events_v1 e
    where e.conversation_id=p_conversation_id
      and e.consent_status='ALLOWED'
      and e.suppression_status='CLEAR'
      and coalesce((e.evidence->>'explicit_reconsent')::boolean,false) is true
      and e.observed_at>v_stop_at
      and (
        e.eligibility_scope='GLOBAL'
        or (v_scope='SERVICE_WINDOW' and e.eligibility_scope in ('UTILITY','MARKETING','AUTHENTICATION'))
        or e.eligibility_scope=v_scope
      );
  end if;

  v_window:=(v_last_inbound is not null and v_last_inbound>=pg_catalog.now()-interval '24 hours');

  if v_conv.contact_address_type<>v_kind or v_conv.contact_address<>v_address then
    v_decision:='HANDOFF';v_reason:='WA_L8_RECIPIENT_CONVERSATION_MISMATCH';
  elsif v_stop_at is not null and v_reconsent_at is null then
    v_decision:='BLOCK';v_reason:='WA_L8_OPT_OUT_ACTIVE';
  elsif v_window then
    v_decision:='PASS';v_reason:='WA_L8_SERVICE_WINDOW_OK';
  elsif v_type<>'template' or v_template is null then
    v_decision:='BLOCK';v_reason:='WA_L8_TEMPLATE_REQUIRED_OUTSIDE_24H';
  else
    v_elig:=public.aos_wa_marketing_eligibility_check_v1(p_conversation_id,v_scope);
    v_elig_status:=v_elig->>'eligibility_status';
    v_elig_reason:=v_elig->>'reason_code';
    if coalesce((v_elig->>'send_allowed')::boolean,false) then
      v_decision:='PASS';v_reason:='WA_L8_SCOPED_ELIGIBILITY_OK';
    else
      v_decision:='BLOCK';v_reason:='WA_L8_SCOPED_ELIGIBILITY_REQUIRED';
    end if;
  end if;

  begin
    insert into public.aos_wa_l8_preflight_decisions_v1(
      idempotency_key,conversation_id,recipient_hash,message_type,template_name,decision,reason_code,
      service_window_open,last_inbound_at,latest_stop_at,consent_action,consent_at,
      eligibility_scope,eligibility_status,eligibility_reason
    ) values(
      p_idempotency_key,p_conversation_id,v_hash,v_type,v_template,v_decision,v_reason,
      v_window,v_last_inbound,v_stop_at,null,v_reconsent_at,
      v_scope,v_elig_status,v_elig_reason
    ) returning id into v_id;
  exception when unique_violation then
    select * into v_existing from public.aos_wa_l8_preflight_decisions_v1 where idempotency_key=p_idempotency_key;
    return pg_catalog.jsonb_build_object(
      'ok',v_existing.decision='PASS','replay',true,'preflight_id',v_existing.id,
      'decision',v_existing.decision,'reason',v_existing.reason_code,
      'service_window_open',v_existing.service_window_open,
      'eligibility_scope',v_existing.eligibility_scope,
      'eligibility_status',v_existing.eligibility_status,
      'eligibility_reason',v_existing.eligibility_reason
    );
  end;

  return pg_catalog.jsonb_build_object(
    'ok',v_decision='PASS','replay',false,'preflight_id',v_id,'decision',v_decision,'reason',v_reason,
    'service_window_open',v_window,'last_inbound_at',v_last_inbound,'latest_stop_at',v_stop_at,
    'explicit_reconsent_at',v_reconsent_at,'eligibility_scope',v_scope,
    'eligibility_status',v_elig_status,'eligibility_reason',v_elig_reason
  );
end
$$;

revoke all on function public.aos_wa_l8_autonomous_preflight_v1(uuid,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l8_autonomous_preflight_v1(uuid,text,text,text,text,text) to service_role;

create or replace function public.aos_wa_l8_security_status_v1()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'ok',true,
    'mode',a.mode,
    'kill_switch_engaged',a.kill_switch_engaged,
    'auto_reply_enabled',ai.auto_reply_enabled,
    'ai_send_enabled',r.ai_send_enabled,
    'auto_routing_enabled',r.auto_routing_enabled,
    'human_send_enabled',r.human_send_enabled,
    'scoped_eligibility_events',(select pg_catalog.count(*) from public.aos_wa_marketing_eligibility_events_v1),
    'deprecated_l8_consent_events',(select pg_catalog.count(*) from public.aos_wa_l8_consent_events_v1),
    'preflight_decisions',(select pg_catalog.count(*) from public.aos_wa_l8_preflight_decisions_v1),
    'pricing_type_events',(select pg_catalog.count(*) from public.aos_wa_events_v1 e where e.event_type='message.status' and nullif(e.payload->>'pricing_type','') is not null),
    'pricing_authority_rows',(select pg_catalog.count(*) from public.aos_wa_l7_pricing_authority_v1),
    'autonomous_outbound',(select pg_catalog.count(*) from public.aos_wa_messages_v1 m where m.direction='OUTBOUND' and m.send_origin='AUTO'),
    'browser_message_write',(
      pg_catalog.has_table_privilege('anon','public.aos_wa_messages_v1','INSERT')
      or pg_catalog.has_table_privilege('anon','public.aos_wa_messages_v1','UPDATE')
      or pg_catalog.has_table_privilege('anon','public.aos_wa_messages_v1','DELETE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_wa_messages_v1','INSERT')
      or pg_catalog.has_table_privilege('authenticated','public.aos_wa_messages_v1','UPDATE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_wa_messages_v1','DELETE')
    ),
    'browser_booking_write',(
      pg_catalog.has_table_privilege('anon','public.aos_booking_operations_v2','INSERT')
      or pg_catalog.has_table_privilege('anon','public.aos_booking_operations_v2','UPDATE')
      or pg_catalog.has_table_privilege('anon','public.aos_booking_operations_v2','DELETE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_booking_operations_v2','INSERT')
      or pg_catalog.has_table_privilege('authenticated','public.aos_booking_operations_v2','UPDATE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_booking_operations_v2','DELETE')
    )
  )
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1
$$;

revoke all on function public.aos_wa_l8_security_status_v1() from public,anon,authenticated;
grant execute on function public.aos_wa_l8_security_status_v1() to service_role;

comment on function public.aos_wa_l8_record_booking_utility_optin_v1(uuid,text,text,text) is
  'Records Utility opt-in only after L5 explicit customer confirmation + committed WhatsApp booking + versioned disclosure. No extra consent message required.';
comment on function public.aos_wa_l8_consent_record_v2(text,uuid,text,text,text,text) is
  'Admin/verified scoped consent adapter into sole WA-7A.4 eligibility authority.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
