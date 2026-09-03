-- WA-L8 P0 final hardening.
-- WA-7A.4 remains the sole consent/suppression evidence authority, but its global
-- projection is never used on the autonomous hot path. This migration resolves one
-- conversation + one scope with indexed LIMIT 1 reads only.

begin;

create or replace function public.aos_wa_l8_scoped_eligibility_check_v1(
  p_conversation_id uuid,
  p_scope text
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_scope text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_scope,'')));
  v_alias_count integer:=0;
  v_phone_alias text;
  v_contact_key text;
  v_g_consent text:='UNKNOWN'; v_g_supp text:='UNKNOWN'; v_g_source text; v_g_event text; v_g_exp timestamptz;
  v_s_consent text:='UNKNOWN'; v_s_supp text:='UNKNOWN'; v_s_source text; v_s_event text; v_s_exp timestamptz;
  v_cia_consent text; v_cia_supp text; v_cia_source text; v_cia_exp timestamptz;
  v_consent text; v_supp text; v_send boolean:=false; v_reason text;
begin
  if v_scope not in ('MARKETING','UTILITY','AUTHENTICATION','CALL') then
    raise exception 'WA_L8_SCOPE_INVALID' using errcode='22023';
  end if;
  if not exists(select 1 from public.aos_wa_conversations_v1 c where c.id=p_conversation_id) then
    raise exception 'WA_L8_CONVERSATION_NOT_FOUND' using errcode='23503';
  end if;

  select pg_catalog.count(*)::integer into v_alias_count
  from public.aos_wa_channel_aliases_v1 a
  where a.conversation_id=p_conversation_id
    and a.active is true
    and a.alias_type in ('PHONE','BSUID','PARENT_BSUID');

  select a.alias_value into v_phone_alias
  from public.aos_wa_channel_aliases_v1 a
  where a.conversation_id=p_conversation_id
    and a.active is true
    and a.alias_type='PHONE'
  order by a.last_seen_at desc
  limit 1;

  if v_phone_alias is not null then
    v_contact_key:=public.aos_cia_normalize_contact_key_v1(v_phone_alias);
  end if;

  select e.consent_status,e.suppression_status,e.source,e.event_key,e.expires_at
    into v_g_consent,v_g_supp,v_g_source,v_g_event,v_g_exp
  from public.aos_wa_marketing_eligibility_events_v1 e
  where e.conversation_id=p_conversation_id and e.eligibility_scope='GLOBAL'
  order by e.observed_at desc,e.created_at desc
  limit 1;
  if not found then v_g_consent:='UNKNOWN';v_g_supp:='UNKNOWN';v_g_source:=null;v_g_event:=null;v_g_exp:=null; end if;

  select e.consent_status,e.suppression_status,e.source,e.event_key,e.expires_at
    into v_s_consent,v_s_supp,v_s_source,v_s_event,v_s_exp
  from public.aos_wa_marketing_eligibility_events_v1 e
  where e.conversation_id=p_conversation_id and e.eligibility_scope=v_scope
  order by e.observed_at desc,e.created_at desc
  limit 1;
  if not found then v_s_consent:='UNKNOWN';v_s_supp:='UNKNOWN';v_s_source:=null;v_s_event:=null;v_s_exp:=null; end if;

  if v_g_exp is not null and v_g_exp<=pg_catalog.now() then v_g_consent:='UNKNOWN';v_g_supp:='UNKNOWN'; end if;
  if v_s_exp is not null and v_s_exp<=pg_catalog.now() then v_s_consent:='UNKNOWN';v_s_supp:='UNKNOWN'; end if;

  if v_contact_key is not null then
    select c.consent_status,c.suppression_status,c.source,c.expires_at
      into v_cia_consent,v_cia_supp,v_cia_source,v_cia_exp
    from public.aos_cia_channel_recipient_controls_v1 c
    where c.contact_key=v_contact_key and c.channel='WHATSAPP'
    limit 1;
    if v_cia_exp is not null and v_cia_exp<=pg_catalog.now() then
      v_cia_consent:=null;v_cia_supp:=null;v_cia_source:=null;v_cia_exp:=null;
    end if;
  end if;

  v_consent:=case
    when v_g_consent='DENIED' or v_s_consent='DENIED' then 'DENIED'
    when v_s_consent='ALLOWED' then 'ALLOWED'
    when v_g_consent='ALLOWED' then 'ALLOWED'
    else 'UNKNOWN' end;
  v_supp:=case
    when v_g_supp='SUPPRESSED' or v_s_supp='SUPPRESSED' then 'SUPPRESSED'
    when v_s_supp='CLEAR' and v_s_consent='ALLOWED' then 'CLEAR'
    when v_g_supp='CLEAR' and v_g_consent='ALLOWED' then 'CLEAR'
    else 'UNKNOWN' end;

  v_send:=v_alias_count>0
    and not (v_g_supp='SUPPRESSED' or v_s_supp='SUPPRESSED' or v_g_consent='DENIED' or v_s_consent='DENIED')
    and not (v_cia_supp='SUPPRESSED' or v_cia_consent='DENIED')
    and ((v_s_consent='ALLOWED' and v_s_supp='CLEAR')
      or (v_s_consent='UNKNOWN' and v_g_consent='ALLOWED' and v_g_supp='CLEAR'));

  v_reason:=case
    when v_alias_count=0 then 'UNREACHABLE'
    when v_g_supp='SUPPRESSED' or v_s_supp='SUPPRESSED' then 'WA_SUPPRESSED'
    when v_g_consent='DENIED' or v_s_consent='DENIED' then 'WA_DENIED'
    when v_cia_supp='SUPPRESSED' then 'CIA_SUPPRESSED'
    when v_cia_consent='DENIED' then 'CIA_DENIED'
    when v_send then 'ELIGIBLE_EXPLICIT'
    else 'CONSENT_UNKNOWN' end;

  return pg_catalog.jsonb_build_object(
    'conversation_id',p_conversation_id,
    'eligibility_scope',v_scope,
    'reachability_status',case when v_alias_count>0 then 'REACHABLE' else 'UNREACHABLE' end,
    'reachability_alias_count',v_alias_count,
    'consent_status',v_consent,
    'suppression_status',v_supp,
    'eligibility_status',case when v_send then 'ELIGIBLE' when v_reason in ('UNREACHABLE','WA_SUPPRESSED','WA_DENIED','CIA_SUPPRESSED','CIA_DENIED') then 'NOT_ELIGIBLE' else 'UNKNOWN' end,
    'reason_code',v_reason,
    'send_allowed',v_send,
    'global_event_key',v_g_event,
    'scope_event_key',v_s_event,
    'global_source',v_g_source,
    'scope_source',v_s_source,
    'cia_source',v_cia_source
  );
end
$$;

revoke all on function public.aos_wa_l8_scoped_eligibility_check_v1(uuid,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l8_scoped_eligibility_check_v1(uuid,text) to service_role;

-- Replace only the final eligibility read. All prior STOP / 24h / scope semantics remain.
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
    v_elig:=public.aos_wa_l8_scoped_eligibility_check_v1(p_conversation_id,v_scope);
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

comment on function public.aos_wa_l8_scoped_eligibility_check_v1(uuid,text) is
  'P0-bounded WA-7A.4 eligibility resolver: one conversation/scope, indexed latest evidence only; no global eligibility projection on autonomous hot path.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
