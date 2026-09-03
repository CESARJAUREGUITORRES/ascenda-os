-- WA-L8 bounded eligibility null guard.
-- Absence of a CIA recipient-control row is neutral, not SQL NULL propagation.

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
  v_cia_consent text:='UNKNOWN'; v_cia_supp text:='UNKNOWN'; v_cia_source text; v_cia_exp timestamptz;
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
    if not found then
      v_cia_consent:='UNKNOWN';v_cia_supp:='UNKNOWN';v_cia_source:=null;v_cia_exp:=null;
    elsif v_cia_exp is not null and v_cia_exp<=pg_catalog.now() then
      v_cia_consent:='UNKNOWN';v_cia_supp:='UNKNOWN';v_cia_source:=null;v_cia_exp:=null;
    end if;
  end if;

  v_cia_consent:=coalesce(v_cia_consent,'UNKNOWN');
  v_cia_supp:=coalesce(v_cia_supp,'UNKNOWN');

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

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
