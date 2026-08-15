-- ASCENDA OS CIA V3 — F16 Email delivery/provider contracts v2
-- Additive and fail-closed. No provider call is performed by SQL.
-- Internal dispatch/provider functions are service_role-only; browser access remains through the admin gateway.

begin;

alter table public.aos_cia_email_send_requests
  add column if not exists render_context jsonb not null default '{}'::jsonb;

alter table public.aos_cia_email_send_requests
  drop constraint if exists aos_cia_email_send_requests_render_context_object;
alter table public.aos_cia_email_send_requests
  add constraint aos_cia_email_send_requests_render_context_object
  check (jsonb_typeof(render_context)='object');

create table if not exists public.aos_cia_email_release_state (
  singleton boolean primary key default true check (singleton),
  gateway_active boolean not null default false,
  provider_configured boolean not null default false,
  webhook_verified boolean not null default false,
  admin_ui_gateway_only boolean not null default false,
  legacy_acl_hardened boolean not null default false,
  canary_passed boolean not null default false,
  rollback_verified boolean not null default false,
  evidence jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.aos_cia_email_release_state(singleton)
values(true)
on conflict (singleton) do nothing;

alter table public.aos_cia_email_release_state enable row level security;
revoke all on table public.aos_cia_email_release_state from public,anon,authenticated;
grant select,insert,update on table public.aos_cia_email_release_state to service_role;

create or replace function public.aos_cia_email_request_guard_v1()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.id is distinct from new.id
     or old.correlation_id is distinct from new.correlation_id
     or old.activation_id is distinct from new.activation_id
     or old.contact_key is distinct from new.contact_key
     or old.recipient_email is distinct from new.recipient_email
     or old.purpose is distinct from new.purpose
     or old.template_version_id is distinct from new.template_version_id
     or old.template_digest is distinct from new.template_digest
     or old.idempotency_key is distinct from new.idempotency_key
     or old.eligibility_status is distinct from new.eligibility_status
     or old.consent_status is distinct from new.consent_status
     or old.render_context is distinct from new.render_context
     or old.requested_by_user_id is distinct from new.requested_by_user_id
     or old.authorization_provenance is distinct from new.authorization_provenance
     or old.created_at is distinct from new.created_at then
    raise exception 'EMAIL_SEND_REQUEST_IDENTITY_IMMUTABLE';
  end if;

  if old.state is distinct from new.state then
    if not (
      (old.state = 'PREPARED' and new.state in ('QUEUED','CANCELLED')) or
      (old.state = 'QUEUED' and new.state in ('DISPATCHING','CANCELLED')) or
      (old.state = 'DISPATCHING' and new.state in ('ACCEPTED','FAILED','QUEUED','CANCELLED')) or
      (old.state = 'FAILED' and new.state in ('QUEUED','CANCELLED')) or
      (old.state = 'ACCEPTED' and new.state in ('DELIVERED','BOUNCED','COMPLAINED','FAILED')) or
      (old.state = 'DELIVERED' and new.state = 'COMPLAINED')
    ) then
      raise exception 'EMAIL_SEND_REQUEST_INVALID_TRANSITION:%->%', old.state, new.state;
    end if;
  end if;

  new.updated_at := now();
  if new.state in ('DELIVERED','BOUNCED','COMPLAINED','CANCELLED') and new.terminal_at is null then
    new.terminal_at := now();
  end if;
  return new;
end
$function$;

create or replace function public.aos_cia_email_prepare_request_v2(
  p_actor_user_id uuid,
  p_activation_id uuid,
  p_contact_key text,
  p_template_version_id uuid,
  p_render_context jsonb default '{}'::jsonb
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
  v_existing record;
  v_id uuid;
  v_context jsonb := coalesce(p_render_context,'{}'::jsonb);
begin
  if p_actor_user_id is null then return jsonb_build_object('ok',false,'error','ACTOR_REQUIRED'); end if;
  if jsonb_typeof(v_context) <> 'object' then return jsonb_build_object('ok',false,'error','INVALID_RENDER_CONTEXT'); end if;
  if pg_column_size(v_context) > 65536 then return jsonb_build_object('ok',false,'error','RENDER_CONTEXT_TOO_LARGE'); end if;

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
  select id,state,render_context into v_existing
  from public.aos_cia_email_send_requests where idempotency_key=v_key;
  if v_existing.id is not null then
    return jsonb_build_object(
      'ok',true,'request_id',v_existing.id,'idempotent',true,'state',v_existing.state,
      'context_reused',v_existing.render_context=v_context,'send_performed',false
    );
  end if;

  insert into public.aos_cia_email_send_requests(
    activation_id,contact_key,recipient_email,purpose,template_version_id,template_digest,idempotency_key,
    eligibility_status,consent_status,render_context,state,requested_by_user_id,authorization_provenance
  ) values(
    p_activation_id,trim(p_contact_key),v_elig->>'email',v_tpl.purpose,v_tpl.id,v_tpl.content_digest,v_key,
    v_elig->>'eligibility_status',v_elig->>'consent_status',v_context,'PREPARED',p_actor_user_id,
    jsonb_build_object('actor_user_id',p_actor_user_id,'via','CIA_EMAIL_ADMIN_GATEWAY_V2','prepared_only',true)
  ) returning id into v_id;

  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_id,'PREPARED',jsonb_build_object('eligibility_reason',v_elig->>'reason_code','send_performed',false));

  return jsonb_build_object('ok',true,'request_id',v_id,'idempotent',false,'state','PREPARED','send_performed',false,'eligibility',v_elig);
end
$function$;

create or replace function public.aos_cia_email_queue_request_v2(
  p_actor_user_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_req record;
  v_elig jsonb;
begin
  if p_actor_user_id is null or p_request_id is null then
    return jsonb_build_object('ok',false,'error','ACTOR_AND_REQUEST_REQUIRED');
  end if;

  select * into v_req from public.aos_cia_email_send_requests where id=p_request_id for update;
  if v_req.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;
  if v_req.state in ('QUEUED','DISPATCHING','ACCEPTED','DELIVERED','BOUNCED','COMPLAINED') then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true);
  end if;
  if v_req.state not in ('PREPARED','FAILED') then
    return jsonb_build_object('ok',false,'error','REQUEST_NOT_QUEUEABLE','state',v_req.state);
  end if;

  v_elig := public.aos_cia_email_eligibility_v1(v_req.activation_id,v_req.contact_key,v_req.purpose);
  if coalesce(v_elig->>'eligibility_status','UNKNOWN') <> 'ELIGIBLE'
     or coalesce(v_elig->>'consent_status','UNKNOWN') not in ('ALLOWED','NOT_REQUIRED') then
    update public.aos_cia_email_send_requests set state='CANCELLED' where id=v_req.id;
    insert into public.aos_cia_email_send_events(request_id,event_type,payload)
    values(v_req.id,'QUEUE_BLOCKED',jsonb_build_object('eligibility',v_elig,'actor_user_id',p_actor_user_id));
    return jsonb_build_object('ok',false,'error','EMAIL_NOT_ELIGIBLE_AT_QUEUE','request_id',v_req.id,'state','CANCELLED','eligibility',v_elig);
  end if;

  update public.aos_cia_email_send_requests set state='QUEUED',scheduled_at=coalesce(scheduled_at,now()) where id=v_req.id;
  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_req.id,'QUEUED',jsonb_build_object('actor_user_id',p_actor_user_id,'eligibility_reason',v_elig->>'reason_code'));
  return jsonb_build_object('ok',true,'request_id',v_req.id,'state','QUEUED','idempotent',false);
end
$function$;

create or replace function public.aos_cia_email_claim_dispatch_v2(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_req record;
  v_tpl record;
  v_elig jsonb;
begin
  if p_request_id is null then return jsonb_build_object('ok',false,'error','REQUEST_REQUIRED','send_allowed',false); end if;

  select * into v_req from public.aos_cia_email_send_requests where id=p_request_id for update;
  if v_req.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND','send_allowed',false); end if;
  if v_req.state in ('ACCEPTED','DELIVERED','BOUNCED','COMPLAINED') then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true,'send_allowed',false,'provider_message_id',v_req.provider_message_id);
  end if;
  if v_req.state='DISPATCHING' then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state','DISPATCHING','in_progress',true,'send_allowed',false);
  end if;
  if v_req.state <> 'QUEUED' then
    return jsonb_build_object('ok',false,'error','REQUEST_NOT_QUEUED','state',v_req.state,'send_allowed',false);
  end if;

  v_elig := public.aos_cia_email_eligibility_v1(v_req.activation_id,v_req.contact_key,v_req.purpose);
  if coalesce(v_elig->>'eligibility_status','UNKNOWN') <> 'ELIGIBLE'
     or coalesce(v_elig->>'consent_status','UNKNOWN') not in ('ALLOWED','NOT_REQUIRED') then
    update public.aos_cia_email_send_requests set state='CANCELLED' where id=v_req.id;
    insert into public.aos_cia_email_send_events(request_id,event_type,payload)
    values(v_req.id,'DISPATCH_BLOCKED',jsonb_build_object('eligibility',v_elig));
    return jsonb_build_object('ok',false,'error','EMAIL_NOT_ELIGIBLE_AT_DISPATCH','request_id',v_req.id,'state','CANCELLED','send_allowed',false,'eligibility',v_elig);
  end if;

  select * into v_tpl from public.aos_cia_email_template_versions where id=v_req.template_version_id;
  if v_tpl.id is null or v_tpl.state <> 'ACTIVE' or v_tpl.content_digest <> v_req.template_digest then
    update public.aos_cia_email_send_requests set state='CANCELLED' where id=v_req.id;
    insert into public.aos_cia_email_send_events(request_id,event_type,payload)
    values(v_req.id,'DISPATCH_BLOCKED',jsonb_build_object('reason','TEMPLATE_DRIFT_OR_INACTIVE'));
    return jsonb_build_object('ok',false,'error','TEMPLATE_DRIFT_OR_INACTIVE','request_id',v_req.id,'state','CANCELLED','send_allowed',false);
  end if;

  update public.aos_cia_email_send_requests
     set state='DISPATCHING',provider='RESEND',dispatch_attempts=dispatch_attempts+1
   where id=v_req.id;
  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_req.id,'DISPATCHING',jsonb_build_object('provider','RESEND','attempt',v_req.dispatch_attempts+1));

  return jsonb_build_object(
    'ok',true,'request_id',v_req.id,'correlation_id',v_req.correlation_id,
    'recipient_email',v_req.recipient_email,'purpose',v_req.purpose,
    'subject_template',v_tpl.subject_template,'html_template',v_tpl.html_template,
    'variable_keys',to_jsonb(v_tpl.variable_keys),'render_context',v_req.render_context,
    'idempotency_key',v_req.idempotency_key,'state','DISPATCHING','send_allowed',true
  );
end
$function$;

create or replace function public.aos_cia_email_record_dispatch_result_v2(
  p_request_id uuid,
  p_accepted boolean,
  p_provider text,
  p_provider_message_id text default null,
  p_error_code text default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_req record;
  v_provider text := upper(trim(coalesce(p_provider,'')));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
begin
  if p_request_id is null or v_provider='' then return jsonb_build_object('ok',false,'error','REQUEST_AND_PROVIDER_REQUIRED'); end if;
  if jsonb_typeof(v_payload) <> 'object' then return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD'); end if;

  select * into v_req from public.aos_cia_email_send_requests where id=p_request_id for update;
  if v_req.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;

  if coalesce(p_accepted,false) and v_req.state in ('ACCEPTED','DELIVERED','BOUNCED','COMPLAINED') then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true);
  end if;
  if v_req.state <> 'DISPATCHING' then
    return jsonb_build_object('ok',false,'error','REQUEST_NOT_DISPATCHING','state',v_req.state);
  end if;

  if coalesce(p_accepted,false) then
    if nullif(trim(coalesce(p_provider_message_id,'')),'') is null then
      return jsonb_build_object('ok',false,'error','PROVIDER_MESSAGE_ID_REQUIRED');
    end if;
    update public.aos_cia_email_send_requests
       set state='ACCEPTED',provider=v_provider,provider_message_id=trim(p_provider_message_id),accepted_at=coalesce(accepted_at,now())
     where id=v_req.id;
    insert into public.aos_cia_email_send_events(request_id,event_type,payload)
    values(v_req.id,'PROVIDER_ACCEPTED',v_payload||jsonb_build_object('provider',v_provider,'provider_message_id',trim(p_provider_message_id)));
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state','ACCEPTED','provider_message_id',trim(p_provider_message_id));
  end if;

  update public.aos_cia_email_send_requests set state='FAILED',provider=v_provider where id=v_req.id;
  insert into public.aos_cia_email_send_events(request_id,event_type,payload)
  values(v_req.id,'PROVIDER_FAILED',v_payload||jsonb_build_object('provider',v_provider,'error_code',left(coalesce(p_error_code,'PROVIDER_ERROR'),120)));
  return jsonb_build_object('ok',true,'request_id',v_req.id,'state','FAILED');
end
$function$;

create or replace function public.aos_cia_email_ingest_provider_event_v2(
  p_provider_event_id text,
  p_provider_message_id text,
  p_event_type text,
  p_occurred_at timestamptz default now(),
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_req record;
  v_type text := lower(trim(coalesce(p_event_type,'')));
  v_event_id text := trim(coalesce(p_provider_event_id,''));
  v_message_id text := trim(coalesce(p_provider_message_id,''));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
begin
  if length(v_event_id) < 8 or length(v_event_id) > 255 then return jsonb_build_object('ok',false,'error','INVALID_PROVIDER_EVENT_ID'); end if;
  if v_message_id='' then return jsonb_build_object('ok',false,'error','PROVIDER_MESSAGE_ID_REQUIRED'); end if;
  if v_type not in ('email.delivered','email.bounced','email.complained','email.opened','email.clicked','email.delivery_delayed') then
    return jsonb_build_object('ok',false,'error','UNSUPPORTED_PROVIDER_EVENT');
  end if;
  if jsonb_typeof(v_payload) <> 'object' then return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD'); end if;

  select * into v_req
  from public.aos_cia_email_send_requests
  where provider='RESEND' and provider_message_id=v_message_id
  for update;
  if v_req.id is null then return jsonb_build_object('ok',false,'error','PROVIDER_MESSAGE_NOT_FOUND'); end if;

  begin
    insert into public.aos_cia_email_send_events(request_id,event_type,provider_event_id,payload,occurred_at)
    values(v_req.id,upper(replace(v_type,'.','_')),v_event_id,v_payload,coalesce(p_occurred_at,now()));
  exception when unique_violation then
    return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',true);
  end;

  if v_type='email.delivered' and v_req.state='ACCEPTED' then
    update public.aos_cia_email_send_requests set state='DELIVERED',delivered_at=coalesce(delivered_at,coalesce(p_occurred_at,now())) where id=v_req.id;
    v_req.state:='DELIVERED';
  elsif v_type='email.bounced' and v_req.state='ACCEPTED' then
    update public.aos_cia_email_send_requests set state='BOUNCED' where id=v_req.id;
    v_req.state:='BOUNCED';
  elsif v_type='email.complained' and v_req.state in ('ACCEPTED','DELIVERED') then
    update public.aos_cia_email_send_requests set state='COMPLAINED' where id=v_req.id;
    v_req.state:='COMPLAINED';
  end if;

  return jsonb_build_object('ok',true,'request_id',v_req.id,'state',v_req.state,'idempotent',false);
end
$function$;

create or replace function public.aos_cia_email_release_mark_v1(
  p_gate text,
  p_value boolean,
  p_evidence text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_gate text := upper(trim(coalesce(p_gate,'')));
  v_value boolean := coalesce(p_value,false);
begin
  if v_gate not in ('GATEWAY_ACTIVE','PROVIDER_CONFIGURED','WEBHOOK_VERIFIED','ADMIN_UI_GATEWAY_ONLY','LEGACY_ACL_HARDENED','CANARY_PASSED','ROLLBACK_VERIFIED') then
    return jsonb_build_object('ok',false,'error','INVALID_RELEASE_GATE');
  end if;

  update public.aos_cia_email_release_state
  set gateway_active=case when v_gate='GATEWAY_ACTIVE' then v_value else gateway_active end,
      provider_configured=case when v_gate='PROVIDER_CONFIGURED' then v_value else provider_configured end,
      webhook_verified=case when v_gate='WEBHOOK_VERIFIED' then v_value else webhook_verified end,
      admin_ui_gateway_only=case when v_gate='ADMIN_UI_GATEWAY_ONLY' then v_value else admin_ui_gateway_only end,
      legacy_acl_hardened=case when v_gate='LEGACY_ACL_HARDENED' then v_value else legacy_acl_hardened end,
      canary_passed=case when v_gate='CANARY_PASSED' then v_value else canary_passed end,
      rollback_verified=case when v_gate='ROLLBACK_VERIFIED' then v_value else rollback_verified end,
      evidence=evidence||jsonb_build_object(v_gate,jsonb_build_object('value',v_value,'evidence',left(coalesce(p_evidence,''),500),'at',now())),
      updated_at=now()
  where singleton=true;

  return jsonb_build_object('ok',true,'gate',v_gate,'value',v_value);
end
$function$;

create or replace function public.aos_cia_email_admin_gateway_v2(
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
  v_request uuid;
  v_contact text;
begin
  v_auth := public.aos_cia_verify_admin_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  begin v_admin := (v_auth->>'user_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end;

  if v_action='PREVIEW_ACTIVATION' then
    begin v_activation := (p_payload->>'activation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_ACTIVATION_ID'); end;
    return public.aos_cia_email_preview_activation_v1(v_activation,coalesce(p_payload->>'purpose','MARKETING'),coalesce((p_payload->>'limit')::integer,50),coalesce((p_payload->>'offset')::integer,0));
  elsif v_action='TEMPLATE_CREATE' then
    return public.aos_cia_email_template_version_create_v1(
      v_admin,p_payload->>'template_key',p_payload->>'purpose',p_payload->>'subject_template',p_payload->>'html_template',
      coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'variable_keys','[]'::jsonb))),'{}'::text[]),
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
    return public.aos_cia_email_prepare_request_v2(v_admin,v_activation,v_contact,v_template,coalesce(p_payload->'render_context','{}'::jsonb));
  elsif v_action='QUEUE_REQUEST' then
    begin v_request := (p_payload->>'request_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_REQUEST_ID'); end;
    return public.aos_cia_email_queue_request_v2(v_admin,v_request);
  elsif v_action='LIST_REQUESTS' then
    return jsonb_build_object(
      'ok',true,
      'items',coalesce((select jsonb_agg(x order by x.created_at desc) from (
        select id,correlation_id,activation_id,contact_key,purpose,template_version_id,state,provider,provider_message_id,dispatch_attempts,created_at,updated_at
        from public.aos_cia_email_send_requests
        order by created_at desc
        limit greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100))
      ) x),'[]'::jsonb)
    );
  elsif v_action='READINESS' then
    return public.aos_cia_email_f17_readiness_v1();
  end if;
  return jsonb_build_object('ok',false,'error','UNSUPPORTED_ACTION');
exception when invalid_text_representation then
  return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
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
  v_illegal integer;
  v_release record;
  v_ready boolean;
begin
  v_f15 := public.aos_cia_kronia_f16_readiness_v1();

  select count(*)::integer into v_tables
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions',
    'aos_cia_email_send_requests','aos_cia_email_send_events','aos_cia_email_release_state'
  ) and c.relkind='r';

  select count(*)::integer into v_rls
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions',
    'aos_cia_email_send_requests','aos_cia_email_send_events','aos_cia_email_release_state'
  ) and c.relrowsecurity;

  select exists(
    select 1 from information_schema.table_privileges
    where table_schema='public' and table_name like 'aos_cia_email_%' and grantee='anon'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')
  ) into v_anon_direct;
  select exists(
    select 1 from information_schema.table_privileges
    where table_schema='public' and table_name like 'aos_cia_email_%' and grantee='authenticated'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')
  ) into v_auth_direct;

  select count(*)::integer into v_illegal
  from public.aos_cia_email_send_requests
  where eligibility_status <> 'ELIGIBLE' and state in ('QUEUED','DISPATCHING','ACCEPTED','DELIVERED');

  select * into v_release from public.aos_cia_email_release_state where singleton=true;
  v_ready := coalesce((v_f15->>'ready_for_f16')::boolean,false)
             and v_tables=6 and v_rls=6 and not v_anon_direct and not v_auth_direct and v_illegal=0
             and coalesce(v_release.gateway_active,false)
             and coalesce(v_release.provider_configured,false)
             and coalesce(v_release.webhook_verified,false)
             and coalesce(v_release.admin_ui_gateway_only,false)
             and coalesce(v_release.legacy_acl_hardened,false)
             and coalesce(v_release.canary_passed,false)
             and coalesce(v_release.rollback_verified,false);

  return jsonb_build_object(
    'ok',true,
    'status',case when v_ready then 'READY_F17_EMAIL_CERTIFIED' else 'IN_PROGRESS_DELIVERY_GOVERNANCE' end,
    'ready_for_f17',v_ready,
    'delivery_enabled',coalesce(v_release.gateway_active,false) and coalesce(v_release.provider_configured,false),
    'f15_ready',coalesce((v_f15->>'ready_for_f16')::boolean,false),
    'governed_tables',v_tables,'rls_tables',v_rls,
    'browser_direct_table_access',jsonb_build_object('anon',v_anon_direct,'authenticated',v_auth_direct),
    'illegal_send_states',v_illegal,
    'release_gates',jsonb_build_object(
      'gateway_active',coalesce(v_release.gateway_active,false),
      'provider_configured',coalesce(v_release.provider_configured,false),
      'webhook_verified',coalesce(v_release.webhook_verified,false),
      'admin_ui_gateway_only',coalesce(v_release.admin_ui_gateway_only,false),
      'legacy_acl_hardened',coalesce(v_release.legacy_acl_hardened,false),
      'canary_passed',coalesce(v_release.canary_passed,false),
      'rollback_verified',coalesce(v_release.rollback_verified,false)
    )
  );
end
$function$;

revoke all on function public.aos_cia_email_prepare_request_v2(uuid,uuid,text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_email_queue_request_v2(uuid,uuid) from public,anon,authenticated;
revoke all on function public.aos_cia_email_claim_dispatch_v2(uuid) from public,anon,authenticated;
revoke all on function public.aos_cia_email_record_dispatch_result_v2(uuid,boolean,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_email_release_mark_v1(text,boolean,text) from public,anon,authenticated;
revoke all on function public.aos_cia_email_admin_gateway_v2(text,text,jsonb) from public;
revoke all on function public.aos_cia_email_f17_readiness_v1() from public,anon,authenticated;

grant execute on function public.aos_cia_email_claim_dispatch_v2(uuid) to service_role;
grant execute on function public.aos_cia_email_record_dispatch_result_v2(uuid,boolean,text,text,text,jsonb) to service_role;
grant execute on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) to service_role;
grant execute on function public.aos_cia_email_release_mark_v1(text,boolean,text) to service_role;
grant execute on function public.aos_cia_email_admin_gateway_v2(text,text,jsonb) to anon,authenticated,service_role;
grant execute on function public.aos_cia_email_f17_readiness_v1() to service_role;

comment on function public.aos_cia_email_claim_dispatch_v2(uuid) is 'F16 service-role dispatch claim. Revalidates eligibility before provider delivery and returns one idempotent provider intent.';
comment on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) is 'F16 service-role provider outcome ingestion after server cryptographic webhook verification.';
comment on table public.aos_cia_email_release_state is 'F16 production release evidence gates. Defaults false; F17 readiness cannot pass before real canary/rollback/ACL evidence.';

commit;
