-- ASCENDA OS CIA V3 — F16 Email preview/request contracts v1
-- No provider dispatch. No legacy ACL changes. No Email send is performed by this migration.

create or replace function public.aos_cia_email_eligibility_v1(
  p_activation_id uuid,
  p_contact_key text,
  p_purpose text default 'MARKETING'
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $function$
declare
  v_purpose text := upper(trim(coalesce(p_purpose,'')));
  v_contact text := trim(coalesce(p_contact_key,''));
  v_channel text;
  v_activation_state text;
  v_source record;
  v_control record;
  v_consent text := 'UNKNOWN';
  v_status text := 'UNKNOWN';
  v_reason text := 'UNKNOWN';
  v_freshness text := 'UNKNOWN';
  v_member boolean := false;
begin
  if p_activation_id is null then
    return jsonb_build_object('ok',false,'eligibility_status','BLOCKED','reason_code','ACTIVATION_REQUIRED','send_allowed',false);
  end if;
  if v_contact = '' then
    return jsonb_build_object('ok',false,'eligibility_status','BLOCKED','reason_code','CONTACT_REQUIRED','send_allowed',false);
  end if;
  if v_purpose not in ('AUTH','TRANSACTIONAL','MARKETING','OPERATIONAL') then
    return jsonb_build_object('ok',false,'eligibility_status','BLOCKED','reason_code','INVALID_PURPOSE','send_allowed',false);
  end if;

  select upper(trim(c.channel)), st.estado
    into v_channel, v_activation_state
  from public.aos_audiencia_activacion_config c
  join public.aos_audiencia_activacion_estado st on st.activacion_id=c.activacion_id
  where c.activacion_id=p_activation_id;

  if v_channel is null then
    return jsonb_build_object('ok',false,'eligibility_status','BLOCKED','reason_code','ACTIVATION_NOT_FOUND','send_allowed',false);
  end if;
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
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $function$
declare
  v_limit integer := greatest(1,least(coalesce(p_limit,50),100));
  v_offset integer := greatest(0,coalesce(p_offset,0));
  v_total integer;
  v_items jsonb;
begin
  select count(*)::integer into v_total
  from public.aos_cia_activation_member_keys_v1(p_activation_id);

  select coalesce(jsonb_agg(x.item order by x.contact_key),'[]'::jsonb)
    into v_items
  from (
    select m.contact_key,
           public.aos_cia_email_eligibility_v1(p_activation_id,m.contact_key,p_purpose) as item
    from public.aos_cia_activation_member_keys_v1(p_activation_id) m
    order by m.contact_key
    limit v_limit offset v_offset
  ) x;

  return jsonb_build_object(
    'ok',true,
    'activation_id',p_activation_id,
    'purpose',upper(trim(coalesce(p_purpose,'MARKETING'))),
    'total_members',v_total,
    'limit',v_limit,
    'offset',v_offset,
    'items',v_items,
    'send_allowed',false,
    'preview_only',true
  );
exception when others then
  if sqlerrm like '%ACTIVATION_NOT_FOUND%' then
    return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND','send_allowed',false);
  end if;
  raise;
end
$function$;

create or replace function public.aos_cia_email_template_version_create_v1(
  p_actor_user_id uuid,
  p_template_key text,
  p_purpose text,
  p_subject_template text,
  p_html_template text,
  p_variable_keys text[] default '{}'::text[],
  p_legacy_template_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_key text := lower(trim(coalesce(p_template_key,'')));
  v_purpose text := upper(trim(coalesce(p_purpose,'')));
  v_version integer;
  v_digest text;
  v_id uuid;
begin
  if p_actor_user_id is null then return jsonb_build_object('ok',false,'error','ACTOR_REQUIRED'); end if;
  if v_key !~ '^[a-z0-9][a-z0-9._-]{1,79}$' then return jsonb_build_object('ok',false,'error','INVALID_TEMPLATE_KEY'); end if;
  if v_purpose not in ('AUTH','TRANSACTIONAL','MARKETING','OPERATIONAL') then return jsonb_build_object('ok',false,'error','INVALID_PURPOSE'); end if;
  if nullif(trim(coalesce(p_subject_template,'')),'') is null then return jsonb_build_object('ok',false,'error','SUBJECT_REQUIRED'); end if;
  if nullif(trim(coalesce(p_html_template,'')),'') is null then return jsonb_build_object('ok',false,'error','HTML_REQUIRED'); end if;
  if length(p_subject_template) > 500 or length(p_html_template) > 500000 then return jsonb_build_object('ok',false,'error','TEMPLATE_TOO_LARGE'); end if;

  perform pg_advisory_xact_lock(hashtext('F16_EMAIL_TEMPLATE:'||v_key));
  select coalesce(max(version),0)+1 into v_version
  from public.aos_cia_email_template_versions where template_key=v_key;

  v_digest := md5(v_key||'|'||v_purpose||'|'||p_subject_template||'|'||p_html_template||'|'||array_to_string(coalesce(p_variable_keys,'{}'::text[]),','));

  insert into public.aos_cia_email_template_versions(
    template_key,version,purpose,subject_template,html_template,variable_keys,content_digest,state,legacy_template_id,created_by_user_id
  ) values(
    v_key,v_version,v_purpose,p_subject_template,p_html_template,coalesce(p_variable_keys,'{}'::text[]),v_digest,'SHADOW',p_legacy_template_id,p_actor_user_id
  ) returning id into v_id;

  return jsonb_build_object('ok',true,'template_version_id',v_id,'template_key',v_key,'version',v_version,'digest',v_digest,'state','SHADOW');
end
$function$;

create or replace function public.aos_cia_email_template_version_activate_v1(
  p_actor_user_id uuid,
  p_template_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_tpl record;
begin
  if p_actor_user_id is null then return jsonb_build_object('ok',false,'error','ACTOR_REQUIRED'); end if;
  select * into v_tpl from public.aos_cia_email_template_versions where id=p_template_version_id for update;
  if v_tpl.id is null then return jsonb_build_object('ok',false,'error','TEMPLATE_VERSION_NOT_FOUND'); end if;
  if v_tpl.state='RETIRED' then return jsonb_build_object('ok',false,'error','TEMPLATE_VERSION_RETIRED'); end if;

  update public.aos_cia_email_template_versions
     set state='RETIRED', retired_at=now()
   where template_key=v_tpl.template_key and id<>v_tpl.id and state='ACTIVE';

  update public.aos_cia_email_template_versions
     set state='ACTIVE', activated_at=coalesce(activated_at,now()), retired_at=null
   where id=v_tpl.id;

  return jsonb_build_object('ok',true,'template_version_id',v_tpl.id,'template_key',v_tpl.template_key,'version',v_tpl.version,'state','ACTIVE','actor_user_id',p_actor_user_id);
end
$function$;

create or replace function public.aos_cia_email_prepare_request_v1(
  p_actor_user_id uuid,
  p_activation_id uuid,
  p_contact_key text,
  p_template_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_tpl record;
  v_elig jsonb;
  v_activation_state text;
  v_key text;
  v_existing uuid;
  v_id uuid;
begin
  if p_actor_user_id is null then return jsonb_build_object('ok',false,'error','ACTOR_REQUIRED'); end if;

  select t.* into v_tpl
  from public.aos_cia_email_template_versions t
  where t.id=p_template_version_id;
  if v_tpl.id is null then return jsonb_build_object('ok',false,'error','TEMPLATE_VERSION_NOT_FOUND'); end if;
  if v_tpl.state <> 'ACTIVE' then return jsonb_build_object('ok',false,'error','TEMPLATE_NOT_ACTIVE'); end if;

  select st.estado into v_activation_state
  from public.aos_audiencia_activacion_estado st
  where st.activacion_id=p_activation_id;
  if v_activation_state is null then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND'); end if;
  if v_activation_state <> 'ACTIVE' then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_ACTIVE','state',v_activation_state); end if;

  v_elig := public.aos_cia_email_eligibility_v1(p_activation_id,p_contact_key,v_tpl.purpose);
  if coalesce(v_elig->>'eligibility_status','UNKNOWN') <> 'ELIGIBLE' then
    return jsonb_build_object('ok',false,'error','EMAIL_NOT_ELIGIBLE','eligibility',v_elig,'send_performed',false);
  end if;
  if coalesce(v_elig->>'consent_status','UNKNOWN') not in ('ALLOWED','NOT_REQUIRED') then
    return jsonb_build_object('ok',false,'error','CONSENT_NOT_ALLOWED','eligibility',v_elig,'send_performed',false);
  end if;

  v_key := md5(p_activation_id::text||'|'||trim(p_contact_key)||'|'||p_template_version_id::text||'|'||v_tpl.purpose);
  perform pg_advisory_xact_lock(hashtext('F16_EMAIL_REQUEST:'||v_key));
  select id into v_existing from public.aos_cia_email_send_requests where idempotency_key=v_key;
  if v_existing is not null then
    return jsonb_build_object('ok',true,'request_id',v_existing,'idempotent',true,'state','PREPARED','send_performed',false);
  end if;

  insert into public.aos_cia_email_send_requests(
    activation_id,contact_key,recipient_email,purpose,template_version_id,template_digest,idempotency_key,
    eligibility_status,consent_status,state,requested_by_user_id,authorization_provenance
  ) values(
    p_activation_id,trim(p_contact_key),v_elig->>'email',v_tpl.purpose,v_tpl.id,v_tpl.content_digest,v_key,
    v_elig->>'eligibility_status',v_elig->>'consent_status','PREPARED',p_actor_user_id,
    jsonb_build_object('actor_user_id',p_actor_user_id,'via','CIA_EMAIL_ADMIN_GATEWAY_V1','prepared_only',true)
  ) returning id into v_id;

  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_id,'PREPARED',jsonb_build_object('eligibility_reason',v_elig->>'reason_code','send_performed',false));

  return jsonb_build_object('ok',true,'request_id',v_id,'idempotent',false,'state','PREPARED','send_performed',false,'eligibility',v_elig);
end
$function$;

create or replace function public.aos_cia_email_f17_readiness_v1()
returns jsonb
language plpgsql
stable
set search_path = ''
as $function$
declare
  v_f15 jsonb;
  v_tables integer;
  v_rls integer;
  v_anon_direct boolean;
  v_auth_direct boolean;
  v_templates integer;
  v_requests integer;
  v_illegal integer;
begin
  v_f15 := public.aos_cia_kronia_f16_readiness_v1();
  select count(*)::integer into v_tables
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions','aos_cia_email_send_requests','aos_cia_email_send_events'
  ) and c.relkind='r';

  select count(*)::integer into v_rls
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions','aos_cia_email_send_requests','aos_cia_email_send_events'
  ) and c.relrowsecurity;

  v_anon_direct := has_table_privilege('anon','public.aos_cia_email_send_requests','SELECT')
                   or has_table_privilege('anon','public.aos_cia_email_send_requests','INSERT')
                   or has_table_privilege('anon','public.aos_cia_email_recipient_controls','SELECT');
  v_auth_direct := has_table_privilege('authenticated','public.aos_cia_email_send_requests','SELECT')
                   or has_table_privilege('authenticated','public.aos_cia_email_send_requests','INSERT')
                   or has_table_privilege('authenticated','public.aos_cia_email_recipient_controls','SELECT');

  select count(*)::integer into v_templates from public.aos_cia_email_template_versions where state='ACTIVE';
  select count(*)::integer into v_requests from public.aos_cia_email_send_requests;
  select count(*)::integer into v_illegal from public.aos_cia_email_send_requests where state <> 'PREPARED';

  return jsonb_build_object(
    'ok',coalesce((v_f15->>'ready_for_f16')::boolean,false) and v_tables=5 and v_rls=5 and not v_anon_direct and not v_auth_direct and v_illegal=0,
    'status','IN_PROGRESS_PREVIEW_ONLY',
    'mode','GOVERNED_EMAIL_SHADOW',
    'ready_for_f17',false,
    'delivery_enabled',false,
    'send_request_state_enabled','PREPARED_ONLY',
    'f15_readiness',v_f15,
    'schema',jsonb_build_object('private_tables',v_tables,'rls_tables',v_rls,'anon_direct_access',v_anon_direct,'authenticated_direct_access',v_auth_direct),
    'templates_active',v_templates,
    'requests_total',v_requests,
    'non_prepared_requests',v_illegal,
    'next_gate','ZERO_COST_CONTRACTS_THEN_PROVIDER_AUTH_WEBHOOK_CANARY'
  );
end
$function$;

create or replace function public.aos_cia_email_admin_gateway_v1(
  p_token text,
  p_action text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_auth jsonb;
  v_admin uuid;
  v_action text := upper(trim(coalesce(p_action,'')));
  v_activation uuid;
  v_template uuid;
  v_purpose text;
  v_contact text;
  v_limit integer;
  v_offset integer;
  v_vars text[];
  v_items jsonb;
begin
  v_auth := public.aos_cia_verify_admin_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_admin := (v_auth->>'user_id')::uuid;

  if v_action='READINESS' then
    return public.aos_cia_email_f17_readiness_v1();
  elsif v_action='PREVIEW' then
    begin v_activation := (p_payload->>'activation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_ACTIVATION_ID'); end;
    v_purpose := coalesce(nullif(upper(trim(p_payload->>'purpose')),''),'MARKETING');
    v_limit := greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));
    v_offset := greatest(0,coalesce((p_payload->>'offset')::integer,0));
    return public.aos_cia_email_preview_activation_v1(v_activation,v_purpose,v_limit,v_offset);
  elsif v_action='TEMPLATE_CREATE_VERSION' then
    select coalesce(array_agg(value),'{}'::text[]) into v_vars
    from jsonb_array_elements_text(coalesce(p_payload->'variable_keys','[]'::jsonb)) value;
    return public.aos_cia_email_template_version_create_v1(
      v_admin,p_payload->>'template_key',p_payload->>'purpose',p_payload->>'subject_template',p_payload->>'html_template',v_vars,
      case when nullif(p_payload->>'legacy_template_id','') is null then null else (p_payload->>'legacy_template_id')::uuid end
    );
  elsif v_action='TEMPLATE_ACTIVATE' then
    begin v_template := (p_payload->>'template_version_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_TEMPLATE_VERSION_ID'); end;
    return public.aos_cia_email_template_version_activate_v1(v_admin,v_template);
  elsif v_action='PREPARE_REQUEST' then
    begin v_activation := (p_payload->>'activation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_ACTIVATION_ID'); end;
    begin v_template := (p_payload->>'template_version_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_TEMPLATE_VERSION_ID'); end;
    v_contact := trim(coalesce(p_payload->>'contact_key',''));
    if v_contact='' then return jsonb_build_object('ok',false,'error','CONTACT_REQUIRED'); end if;
    return public.aos_cia_email_prepare_request_v1(v_admin,v_activation,v_contact,v_template);
  elsif v_action='REQUESTS' then
    v_limit := greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_items
    from (
      select id,correlation_id,activation_id,contact_key,purpose,template_version_id,state,dispatch_attempts,created_at,updated_at
      from public.aos_cia_email_send_requests order by created_at desc limit v_limit
    ) x;
    return jsonb_build_object('ok',true,'items',v_items,'delivery_enabled',false);
  end if;
  return jsonb_build_object('ok',false,'error','UNKNOWN_ACTION');
exception when invalid_text_representation or numeric_value_out_of_range then
  return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
end
$function$;

revoke all on function public.aos_cia_email_eligibility_v1(uuid,text,text) from public, anon, authenticated;
revoke all on function public.aos_cia_email_preview_activation_v1(uuid,text,integer,integer) from public, anon, authenticated;
revoke all on function public.aos_cia_email_template_version_create_v1(uuid,text,text,text,text,text[],uuid) from public, anon, authenticated;
revoke all on function public.aos_cia_email_template_version_activate_v1(uuid,uuid) from public, anon, authenticated;
revoke all on function public.aos_cia_email_prepare_request_v1(uuid,uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.aos_cia_email_f17_readiness_v1() from public, anon, authenticated;
revoke all on function public.aos_cia_email_admin_gateway_v1(text,text,jsonb) from public;
grant execute on function public.aos_cia_email_admin_gateway_v1(text,text,jsonb) to anon, authenticated;

comment on function public.aos_cia_email_admin_gateway_v1(text,text,jsonb) is 'F16 ADMIN gateway. PREVIEW/PREPARE only; no provider dispatch exists in this contract.';
