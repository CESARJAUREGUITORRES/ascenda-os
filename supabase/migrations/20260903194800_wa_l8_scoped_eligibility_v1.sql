-- WA-L8 final consent hardening: one scoped eligibility authority, zero extra consent UX.
-- WA-7A.4 is the sole consent/suppression authority. The early L8 consent table stays
-- inert only for migration compatibility and receives no further writes.
-- No CANARY transition, provider dispatch, business-ledger mutation or hot-path trigger.

begin;

do $$
begin
  if to_regclass('public.aos_wa_marketing_eligibility_events_v1') is null
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
    pg_catalog.substr(
      pg_catalog.encode(
        extensions.digest(pg_catalog.convert_to(v_evidence||'|'||pg_catalog.clock_timestamp()::text,'UTF8'),'sha256'),
        'hex'
      ),1,24
    );
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
-- This function never infers consent merely from the existence of an appointment.
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
    pg_catalog.substr(
      pg_catalog.encode(
        extensions.digest(pg_catalog.convert_to(v_provider||'|'||v_disclosure,'UTF8'),'sha256'),
        'hex'
      ),1,24
    );
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

-- Security/readback surface; no raw PII or message bodies are returned.
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
