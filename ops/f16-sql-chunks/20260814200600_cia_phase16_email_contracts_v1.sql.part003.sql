  elsif nullif(trim(coalesce(v_source.canonical_email,'')),'') is null then
    v_status := 'BLOCKED'; v_reason := 'EMAIL_MISSING';
  elsif coalesce(v_source.email_valid,false) is not true then
    v_status := 'BLOCKED'; v_reason := 'EMAIL_INVALID';
  elsif coalesce(v_control.global_suppressed,false) then
    v_status := 'BLOCKED'; v_reason := 'GLOBAL_SUPPRESSION';
  elsif v_purpose='MARKETING' and v_consent='BLOCKED' then
    v_status := 'BLOCKED'; v_reason := 'MARKETING_CONSENT_BLOCKED';
  elsif coalesce(v_source.email_bounced_count,0) > 0 then
    v_status := 'UNKNOWN'; v_reason := 'BOUNCE_REVIEW_REQUIRED';
  elsif v_purpose='MARKETING' and v_consent <> 'ALLOWED' then
    v_status := 'UNKNOWN'; v_reason := 'MARKETING_CONSENT_UNKNOWN';
  elsif v_freshness='UNKNOWN' then
    v_status := 'UNKNOWN'; v_reason := 'FRESHNESS_UNKNOWN';
  else
    v_status := 'ELIGIBLE'; v_reason := 'ELIGIBLE_PREVIEW';
  end if;

  return jsonb_build_object(
    'ok',true,
    'activation_id',p_activation_id,
    'activation_state',v_activation_state,
    'channel',v_channel,
    'contact_key',v_contact,
    'email',v_source.canonical_email,
    'email_valid',coalesce(v_source.email_valid,false),
    'bounced_count',coalesce(v_source.email_bounced_count,0),
    'consent_status',v_consent,
    'global_suppressed',coalesce(v_control.global_suppressed,false),
    'control_source',coalesce(v_control.source,'UNKNOWN'),
    'eligibility_status',v_status,
    'reason_code',v_reason,
    'freshness_status',v_freshness,
    'facts_observed_at',v_source.facts_observed_at,
    'send_allowed',false,
    'preview_only',true
  );
end
$function$;

create or replace function public.aos_cia_email_preview_activation_v1(
  p_activation_id uuid,
  p_purpose text default 'MARKETING',
  p_limit integer default 50,
  p_offset integer default 0
