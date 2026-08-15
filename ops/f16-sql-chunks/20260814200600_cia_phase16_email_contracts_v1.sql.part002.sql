  if v_channel <> 'EMAIL' then
    return jsonb_build_object('ok',true,'eligibility_status','BLOCKED','reason_code','CHANNEL_NOT_EMAIL','activation_state',v_activation_state,'send_allowed',false);
  end if;

  select exists(
    select 1 from public.aos_cia_activation_member_keys_v1(p_activation_id) m
    where m.contact_key=v_contact
  ) into v_member;
  if not v_member then
    return jsonb_build_object('ok',true,'eligibility_status','BLOCKED','reason_code','NOT_ACTIVATION_MEMBER','activation_state',v_activation_state,'send_allowed',false);
  end if;

  select s.contact_key,s.identity_conflict,s.canonical_email,s.email_valid,
         s.email_bounced_count,s.facts_observed_at,s.email_last_event_at
    into v_source
  from public.aos_cia_audience_source_v1_1 s
  where s.contact_key=v_contact;

  if v_source.contact_key is null then
    return jsonb_build_object('ok',true,'eligibility_status','BLOCKED','reason_code','CONTACT_SOURCE_NOT_FOUND','activation_state',v_activation_state,'send_allowed',false);
  end if;

  if v_source.facts_observed_at is null then
    v_freshness := 'UNKNOWN';
  elsif v_source.facts_observed_at >= now() - interval '2 days' then
    v_freshness := 'FRESH';
  elsif v_source.facts_observed_at >= now() - interval '7 days' then
    v_freshness := 'AGING';
  else
    v_freshness := 'STALE';
  end if;

  select c.marketing_consent,c.global_suppressed,c.suppression_reason,c.source,c.source_updated_at
    into v_control
  from public.aos_cia_email_recipient_controls c
  where c.contact_key=v_contact;

  if v_purpose='MARKETING' then
    v_consent := coalesce(v_control.marketing_consent,'UNKNOWN');
  else
    v_consent := 'NOT_REQUIRED';
  end if;

  if coalesce(v_source.identity_conflict,false) then
    v_status := 'BLOCKED'; v_reason := 'IDENTITY_CONFLICT';
