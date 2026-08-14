-- Phase 8 EMAIL eligibility must use the exact Fact Registry email-validity semantics.

create or replace function public.aos_cia_activation_context_rows_v1(p_activation_id uuid)
returns table(contact_key text,eligibility_status text,availability_status text,is_assignable boolean,reasons text[],warnings text[],policy_key text,policy_version integer,channel text)
language plpgsql stable set search_path=public as $$
declare ctx record; begin
  select b.policy_key,b.policy_version,p.channel,p.rules,s.estado as activation_state
  into ctx
  from public.aos_audiencia_activacion_context b
  join public.aos_cia_context_policies p on p.policy_key=b.policy_key and p.version=b.policy_version
  join public.aos_audiencia_activacion_estado s on s.activacion_id=b.activation_id
  where b.activation_id=p_activation_id;
  if ctx.policy_key is null then raise exception 'CONTEXT_NOT_BOUND'; end if;

  if ctx.policy_key in ('CALL_GENERAL','CALL_PROVINCE') then
    return query
    with m as (select k.contact_key from public.aos_cia_activation_member_keys_v1(p_activation_id) k),
    base as (
      select m.contact_key,c.latest_call_status,coalesce(c.called_today,false) called_today,
             coalesce(a.has_future_appointment,false) future_appointment,s.lifecycle,
             (l.numero_limpio is not null) legacy_in_progress
      from m
      left join public.aos_cia_call_adapter_v2 c on c.contact_key=m.contact_key
      left join public.aos_cia_appointment_adapter_v2 a on a.contact_key=m.contact_key
      left join public.aos_cia_segment_runtime_cache_v2 s on s.contact_key=m.contact_key
      left join (select distinct numero_limpio from public.aos_leads_en_curso where fecha=(now() at time zone 'America/Lima')::date) l on l.numero_limpio=m.contact_key
    ), d as (
      select b.*,
        case
          when b.contact_key !~ '^[0-9]{9}$' then 'INELIGIBLE'
          when ctx.policy_key='CALL_GENERAL' and b.lifecycle is null then 'UNKNOWN'
          when ctx.policy_key='CALL_GENERAL' and b.lifecycle='DISQUALIFIED_PROSPECT' then 'INELIGIBLE'
          when ctx.policy_key='CALL_GENERAL' and b.latest_call_status in ('PROVINCIA','PROVINCIAS') then 'INELIGIBLE'
          when ctx.policy_key='CALL_PROVINCE' and coalesce(b.latest_call_status,'') not in ('PROVINCIA','PROVINCIAS') then 'INELIGIBLE'
          else 'ELIGIBLE' end elig,
        array_remove(array[
          case when b.contact_key !~ '^[0-9]{9}$' then 'PHONE_INVALID' end,
          case when ctx.policy_key='CALL_GENERAL' and b.lifecycle is null then 'SEGMENT_FRESHNESS_UNKNOWN' end,
          case when ctx.policy_key='CALL_GENERAL' and b.lifecycle='DISQUALIFIED_PROSPECT' then 'CURRENTLY_DISQUALIFIED' end,
          case when ctx.policy_key='CALL_GENERAL' and b.latest_call_status in ('PROVINCIA','PROVINCIAS') then 'CURRENT_PROVINCE_ROUTE' end,
          case when ctx.policy_key='CALL_PROVINCE' and coalesce(b.latest_call_status,'') not in ('PROVINCIA','PROVINCIAS') then 'NOT_PROVINCE_ROUTE' end,
          case when b.called_today then 'CALLED_TODAY' end,
          case when b.future_appointment then 'FUTURE_APPOINTMENT' end,
          case when b.legacy_in_progress then 'LEGACY_WORK_IN_PROGRESS' end],null) rs
      from base b
    )
    select d.contact_key,d.elig,
      case when d.elig='UNKNOWN' then 'UNKNOWN' when d.elig='INELIGIBLE' then 'UNAVAILABLE'
           when d.called_today or d.future_appointment or d.legacy_in_progress then 'UNAVAILABLE' else 'AVAILABLE' end,
      (ctx.activation_state='ACTIVE' and d.elig='ELIGIBLE' and not d.called_today and not d.future_appointment and not d.legacy_in_progress),
      d.rs,array[]::text[],ctx.policy_key,ctx.policy_version,ctx.channel
    from d;
    return;
  end if;

  if ctx.policy_key='EMAIL_GENERAL' then
    return query
    with m as (select k.contact_key from public.aos_cia_activation_member_keys_v1(p_activation_id) k),
    base as (
      select m.contact_key,p.canonical_email,e.identity_confidence,e.days_since_last,e.bounced_count,
             case
               when p.canonical_email is null or btrim(p.canonical_email)='' then null::boolean
               when lower(btrim(p.canonical_email)) ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then true
               else false end as email_valid
      from m
      left join public.aos_cia_profile_fast_v2 p on p.contact_key=m.contact_key
      left join public.aos_cia_email_runtime_cache_v2 e on e.contact_key=m.contact_key
    ), d as (
      select b.*,
        case
          when b.email_valid is distinct from true then 'INELIGIBLE'
          when b.identity_confidence is null then 'UNKNOWN'
          when b.identity_confidence<>'MEDIUM' then 'INELIGIBLE'
          else 'ELIGIBLE' end elig,
        array_remove(array[
          case when b.email_valid is distinct from true then 'EMAIL_INVALID' end,
          case when b.identity_confidence is null then 'EMAIL_FRESHNESS_UNKNOWN' end,
          case when b.identity_confidence is not null and b.identity_confidence<>'MEDIUM' then 'EMAIL_IDENTITY_UNKNOWN' end,
          case when b.days_since_last=0 then 'EMAIL_SENT_TODAY' end],null) rs,
        array_remove(array[case when coalesce(b.bounced_count,0)>0 then 'EMAIL_BOUNCE_HISTORY' end],null) ws
      from base b
    )
    select d.contact_key,d.elig,
      case when d.elig='UNKNOWN' then 'UNKNOWN' when d.elig='INELIGIBLE' then 'UNAVAILABLE'
           when d.days_since_last=0 then 'UNAVAILABLE' else 'AVAILABLE' end,
      (ctx.activation_state='ACTIVE' and d.elig='ELIGIBLE' and coalesce(d.days_since_last,-1)<>0),
      d.rs,d.ws,ctx.policy_key,ctx.policy_version,ctx.channel
    from d;
    return;
  end if;

  if ctx.policy_key in ('SMS_GENERAL','WHATSAPP_GENERAL') then
    return query
    select m.contact_key,
      case when m.contact_key ~ '^[0-9]{9}$' then 'ELIGIBLE' else 'INELIGIBLE' end,
      case when m.contact_key ~ '^[0-9]{9}$' then 'UNKNOWN' else 'UNAVAILABLE' end,
      false,
      array_remove(array[case when m.contact_key !~ '^[0-9]{9}$' then 'PHONE_INVALID' end,case when m.contact_key ~ '^[0-9]{9}$' then 'CHANNEL_HISTORY_NOT_INTEGRATED' end],null),
      array[]::text[],ctx.policy_key,ctx.policy_version,ctx.channel
    from public.aos_cia_activation_member_keys_v1(p_activation_id) m;
    return;
  end if;

  return query
  select m.contact_key,'ELIGIBLE'::text,'AVAILABLE'::text,(ctx.activation_state='ACTIVE'),array[]::text[],array[]::text[],ctx.policy_key,ctx.policy_version,ctx.channel
  from public.aos_cia_activation_member_keys_v1(p_activation_id) m;
end;
$$;
