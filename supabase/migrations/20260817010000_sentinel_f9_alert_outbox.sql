-- Sentinel F9 durable alert state / outbox
-- Zero-PHI/PII. No rendered Telegram message, token, chat target or arbitrary payload is stored.

begin;

create table public.aos_sentinel_alert_dispatches_v1 (
  dispatch_id bigint generated always as identity primary key,
  attempt_key text not null unique check (attempt_key ~ '^[A-Za-z0-9._:@/-]{1,240}$' and attempt_key !~ '[?#]' and attempt_key !~ '\.\.'),
  decision_key text not null check (decision_key ~ '^[A-Za-z0-9._:@/-]{1,240}$' and decision_key !~ '[?#]' and decision_key !~ '\.\.'),
  incident_id text references public.aos_sentinel_incidents_v1(incident_id) on delete cascade,
  digest_key text,
  action text not null check (action in ('IMMEDIATE','RECOVERY','FLAPPING_SUMMARY','DIGEST')),
  severity text not null check (severity in ('P0','P1','P2')),
  status text not null check (status in ('OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED')),
  channel text not null check (channel='telegram-owner'),
  environment text not null check (environment ~ '^[a-z0-9][a-z0-9._:-]{0,63}$'),
  domain text not null check (domain ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  component text,
  capability text,
  failure_family text,
  release text,
  commit_sha text,
  deployment_id text,
  signal_count bigint not null default 0 check (signal_count >= 0),
  reopened_count integer not null default 0 check (reopened_count >= 0),
  decided_at timestamptz not null,
  cooldown_seconds integer not null default 0 check (cooldown_seconds between 0 and 86400),
  delivery_state text not null default 'RESERVED' check (delivery_state in ('RESERVED','DELIVERED','FAILED','UNAVAILABLE','RETRY_LATER')),
  provider_message_id text,
  retry_after_seconds integer check (retry_after_seconds is null or retry_after_seconds between 1 and 86400),
  delivered_at timestamptz,
  updated_at timestamptz not null default now(),
  check ((action='DIGEST' and incident_id is null and digest_key is not null) or (action<>'DIGEST' and incident_id is not null and digest_key is null)),
  check (component is null or component ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  check (capability is null or capability ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  check (failure_family is null or failure_family ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  check (release is null or release='ascenda-os@unknown' or release ~ '^ascenda-os@[0-9a-f]{7,40}$'),
  check (commit_sha is null or commit_sha ~ '^[0-9a-f]{7,40}$'),
  check (deployment_id is null or (deployment_id ~ '^[A-Za-z0-9._:@/-]{1,200}$' and deployment_id !~ '[?#]' and deployment_id !~ '\.\.')),
  check (provider_message_id is null or provider_message_id ~ '^[A-Za-z0-9._:@/-]{1,200}$'),
  check ((delivery_state='DELIVERED' and delivered_at is not null) or delivery_state<>'DELIVERED')
);

create index aos_sentinel_alert_dispatches_v1_decision_idx
  on public.aos_sentinel_alert_dispatches_v1(decision_key, delivered_at desc nulls last, decided_at desc);
create index aos_sentinel_alert_dispatches_v1_incident_idx
  on public.aos_sentinel_alert_dispatches_v1(incident_id, decided_at desc) where incident_id is not null;
create index aos_sentinel_alert_dispatches_v1_state_idx
  on public.aos_sentinel_alert_dispatches_v1(delivery_state, updated_at);

create table public.aos_sentinel_alert_digest_items_v1 (
  digest_key text not null check (digest_key ~ '^[A-Za-z0-9._:@/-]{1,240}$' and digest_key !~ '[?#]' and digest_key !~ '\.\.'),
  incident_id text not null references public.aos_sentinel_incidents_v1(incident_id) on delete cascade,
  environment text not null check (environment ~ '^[a-z0-9][a-z0-9._:-]{0,63}$'),
  domain text not null check (domain ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  bucket_start timestamptz not null,
  bucket_end timestamptz not null,
  queued_at timestamptz not null,
  state text not null default 'QUEUED' check (state in ('QUEUED','CLAIMED','SENT')),
  claim_expires_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key(digest_key,incident_id),
  check (bucket_end > bucket_start),
  check ((state='CLAIMED' and claim_expires_at is not null) or state<>'CLAIMED')
);
create index aos_sentinel_alert_digest_items_v1_due_idx
  on public.aos_sentinel_alert_digest_items_v1(state,bucket_end,claim_expires_at);

create table public.aos_sentinel_maintenance_windows_v1 (
  window_id bigint generated always as identity primary key,
  environment text check (environment is null or environment ~ '^[a-z0-9][a-z0-9._:-]{0,63}$'),
  domain text check (domain is null or domain ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  component text check (component is null or component ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  capability text check (capability is null or capability ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  reason_code text not null check (reason_code ~ '^[a-z0-9][a-z0-9._:-]{0,99}$'),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index aos_sentinel_maintenance_windows_v1_active_idx
  on public.aos_sentinel_maintenance_windows_v1(enabled,starts_at,ends_at);

alter table public.aos_sentinel_alert_dispatches_v1 enable row level security;
alter table public.aos_sentinel_alert_digest_items_v1 enable row level security;
alter table public.aos_sentinel_maintenance_windows_v1 enable row level security;

create or replace function public.aos_sentinel_alert_reserve_dispatch_v1(p_request jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_attempt text; v_decision text; v_incident text; v_digest text; v_action text; v_severity text; v_status text;
  v_env text; v_domain text; v_component text; v_capability text; v_failure text; v_release text; v_commit text; v_deploy text;
  v_signal_count bigint; v_reopened integer; v_decided timestamptz; v_cooldown integer; v_existing bigint; v_last timestamptz; v_id bigint; k text;
begin
  if p_request is null or pg_catalog.jsonb_typeof(p_request)<>'object' then raise exception 'F9_DISPATCH_OBJECT_REQUIRED'; end if;
  for k in select pg_catalog.jsonb_object_keys(p_request) loop
    if k not in ('attempt_key','decision_key','incident_id','digest_key','action','severity','status','environment','domain','component','capability','failure_family','release','commit_sha','deployment_id','signal_count','reopened_count','decided_at','cooldown_seconds') then raise exception 'F9_DISPATCH_UNAPPROVED_KEY:%',k; end if;
  end loop;
  if not (p_request ?& array['attempt_key','decision_key','action','severity','status','environment','domain','decided_at','cooldown_seconds']) then raise exception 'F9_DISPATCH_REQUIRED_FIELD_MISSING'; end if;

  v_attempt:=p_request->>'attempt_key'; v_decision:=p_request->>'decision_key'; v_incident:=nullif(p_request->>'incident_id',''); v_digest:=nullif(p_request->>'digest_key','');
  v_action:=pg_catalog.upper(p_request->>'action'); v_severity:=pg_catalog.upper(p_request->>'severity'); v_status:=pg_catalog.upper(p_request->>'status');
  v_env:=pg_catalog.lower(p_request->>'environment'); v_domain:=pg_catalog.upper(p_request->>'domain');
  v_component:=nullif(pg_catalog.lower(coalesce(p_request->>'component','')),''); v_capability:=nullif(pg_catalog.lower(coalesce(p_request->>'capability','')),'');
  v_failure:=nullif(pg_catalog.lower(coalesce(p_request->>'failure_family','')),''); v_release:=nullif(p_request->>'release',''); v_commit:=nullif(p_request->>'commit_sha',''); v_deploy:=nullif(p_request->>'deployment_id','');
  v_signal_count:=coalesce((p_request->>'signal_count')::bigint,0); v_reopened:=coalesce((p_request->>'reopened_count')::integer,0); v_cooldown:=coalesce((p_request->>'cooldown_seconds')::integer,0);
  begin v_decided:=(p_request->>'decided_at')::timestamptz; exception when others then raise exception 'F9_DISPATCH_INVALID_TIMESTAMP'; end;

  if v_attempt is null or v_attempt !~ '^[A-Za-z0-9._:@/-]{1,240}$' or v_attempt ~ '[?#]' or v_attempt ~ '\.\.' then raise exception 'F9_ATTEMPT_KEY_INVALID'; end if;
  if v_decision is null or v_decision !~ '^[A-Za-z0-9._:@/-]{1,240}$' or v_decision ~ '[?#]' or v_decision ~ '\.\.' then raise exception 'F9_DECISION_KEY_INVALID'; end if;
  if v_action not in ('IMMEDIATE','RECOVERY','FLAPPING_SUMMARY','DIGEST') then raise exception 'F9_ACTION_INVALID'; end if;
  if v_severity not in ('P0','P1','P2') or v_status not in ('OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED') then raise exception 'F9_DISPATCH_STATE_INVALID'; end if;
  if v_env !~ '^[a-z0-9][a-z0-9._:-]{0,63}$' or v_domain !~ '^[A-Z][A-Z0-9_]{0,63}$' then raise exception 'F9_SCOPE_INVALID'; end if;
  if v_cooldown<0 or v_cooldown>86400 or v_signal_count<0 or v_reopened<0 then raise exception 'F9_COUNTER_OR_COOLDOWN_INVALID'; end if;
  if (v_action='DIGEST' and (v_incident is not null or v_digest is null)) or (v_action<>'DIGEST' and (v_incident is null or v_digest is not null)) then raise exception 'F9_DISPATCH_TARGET_INVALID'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sentinel:f9:attempt:'||v_attempt,0));
  select dispatch_id into v_existing from public.aos_sentinel_alert_dispatches_v1 where attempt_key=v_attempt;
  if v_existing is not null then return pg_catalog.jsonb_build_object('ok',true,'result','REPLAY','dispatch_id',v_existing); end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sentinel:f9:decision:'||v_decision,0));
  if v_cooldown>0 then
    select max(delivered_at) into v_last from public.aos_sentinel_alert_dispatches_v1 where decision_key=v_decision and delivery_state='DELIVERED';
    if v_last is not null and v_decided < v_last + pg_catalog.make_interval(secs=>v_cooldown) then
      return pg_catalog.jsonb_build_object('ok',true,'result','SUPPRESSED_COOLDOWN','last_delivered_at',v_last);
    end if;
  end if;

  insert into public.aos_sentinel_alert_dispatches_v1(
    attempt_key,decision_key,incident_id,digest_key,action,severity,status,channel,environment,domain,component,capability,failure_family,release,commit_sha,deployment_id,signal_count,reopened_count,decided_at,cooldown_seconds
  ) values(
    v_attempt,v_decision,v_incident,v_digest,v_action,v_severity,v_status,'telegram-owner',v_env,v_domain,v_component,v_capability,v_failure,v_release,v_commit,v_deploy,v_signal_count,v_reopened,v_decided,v_cooldown
  ) returning dispatch_id into v_id;
  return pg_catalog.jsonb_build_object('ok',true,'result','RESERVED','dispatch_id',v_id);
end;
$$;

create or replace function public.aos_sentinel_alert_mark_delivery_v1(p_dispatch_id bigint,p_state text,p_provider_message_id text default null,p_retry_after_seconds integer default null,p_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_state text:=pg_catalog.upper(coalesce(p_state,'')); v_at timestamptz:=coalesce(p_at,pg_catalog.clock_timestamp()); v public.aos_sentinel_alert_dispatches_v1%rowtype;
begin
  if v_state not in ('DELIVERED','FAILED','UNAVAILABLE','RETRY_LATER') then raise exception 'F9_DELIVERY_STATE_INVALID'; end if;
  if p_provider_message_id is not null and (p_provider_message_id !~ '^[A-Za-z0-9._:@/-]{1,200}$' or p_provider_message_id ~ '[?#]' or p_provider_message_id ~ '\.\.') then raise exception 'F9_PROVIDER_MESSAGE_ID_INVALID'; end if;
  if p_retry_after_seconds is not null and (p_retry_after_seconds<1 or p_retry_after_seconds>86400) then raise exception 'F9_RETRY_AFTER_INVALID'; end if;
  select * into v from public.aos_sentinel_alert_dispatches_v1 where dispatch_id=p_dispatch_id for update;
  if not found then raise exception 'F9_DISPATCH_NOT_FOUND'; end if;
  if v.delivery_state='DELIVERED' then return pg_catalog.jsonb_build_object('ok',true,'replay',true,'dispatch_id',v.dispatch_id,'state',v.delivery_state); end if;
  update public.aos_sentinel_alert_dispatches_v1 set delivery_state=v_state,provider_message_id=case when v_state='DELIVERED' then p_provider_message_id else null end,retry_after_seconds=case when v_state='RETRY_LATER' then p_retry_after_seconds else null end,delivered_at=case when v_state='DELIVERED' then v_at else null end,updated_at=v_at where dispatch_id=p_dispatch_id returning * into v;
  return pg_catalog.jsonb_build_object('ok',true,'replay',false,'dispatch_id',v.dispatch_id,'state',v.delivery_state,'delivered_at',v.delivered_at,'retry_after_seconds',v.retry_after_seconds);
end;
$$;

create or replace function public.aos_sentinel_alert_queue_digest_v1(p_item jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_key text; v_incident text; v_env text; v_domain text; v_start timestamptz; v_end timestamptz; v_queued timestamptz; v_inserted boolean;
begin
  if p_item is null or pg_catalog.jsonb_typeof(p_item)<>'object' then raise exception 'F9_DIGEST_OBJECT_REQUIRED'; end if;
  if not (p_item ?& array['digest_key','incident_id','environment','domain','bucket_start','bucket_end','queued_at']) then raise exception 'F9_DIGEST_REQUIRED_FIELD_MISSING'; end if;
  if exists(select 1 from pg_catalog.jsonb_object_keys(p_item) k where k not in ('digest_key','incident_id','environment','domain','bucket_start','bucket_end','queued_at')) then raise exception 'F9_DIGEST_UNAPPROVED_KEY'; end if;
  v_key:=p_item->>'digest_key'; v_incident:=p_item->>'incident_id'; v_env:=pg_catalog.lower(p_item->>'environment'); v_domain:=pg_catalog.upper(p_item->>'domain');
  begin v_start:=(p_item->>'bucket_start')::timestamptz; v_end:=(p_item->>'bucket_end')::timestamptz; v_queued:=(p_item->>'queued_at')::timestamptz; exception when others then raise exception 'F9_DIGEST_INVALID_TIMESTAMP'; end;
  if v_key !~ '^[A-Za-z0-9._:@/-]{1,240}$' or v_key ~ '[?#]' or v_key ~ '\.\.' then raise exception 'F9_DIGEST_KEY_INVALID'; end if;
  if v_incident !~ '^SEN-[0-9]{4}-[0-9]{4,}$' or v_env !~ '^[a-z0-9][a-z0-9._:-]{0,63}$' or v_domain !~ '^[A-Z][A-Z0-9_]{0,63}$' or v_end<=v_start then raise exception 'F9_DIGEST_SCOPE_INVALID'; end if;
  insert into public.aos_sentinel_alert_digest_items_v1(digest_key,incident_id,environment,domain,bucket_start,bucket_end,queued_at)
  values(v_key,v_incident,v_env,v_domain,v_start,v_end,v_queued)
  on conflict(digest_key,incident_id) do nothing;
  get diagnostics v_inserted = row_count;
  return pg_catalog.jsonb_build_object('ok',true,'inserted',v_inserted,'digest_key',v_key,'incident_id',v_incident);
end;
$$;

create or replace function public.aos_sentinel_alert_recent_dispatches_v1(p_incident_id text)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'dispatch_id',d.dispatch_id,'attempt_key',d.attempt_key,'decision_key',d.decision_key,'action',d.action,'severity',d.severity,'status',d.status,
    'decided_at',d.decided_at,'cooldown_seconds',d.cooldown_seconds,'delivery_state',d.delivery_state,'delivered_at',d.delivered_at,'retry_after_seconds',d.retry_after_seconds
  ) order by d.dispatch_id),'[]'::jsonb)
  from public.aos_sentinel_alert_dispatches_v1 d where d.incident_id=p_incident_id;
$$;

create or replace function public.aos_sentinel_active_maintenance_windows_v1(p_at timestamptz default null)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'window_id',w.window_id,'environment',w.environment,'domain',w.domain,'component',w.component,'capability',w.capability,'reason_code',w.reason_code,'starts_at',w.starts_at,'ends_at',w.ends_at
  ) order by w.window_id),'[]'::jsonb)
  from public.aos_sentinel_maintenance_windows_v1 w
  where w.enabled and coalesce(p_at,pg_catalog.clock_timestamp()) between w.starts_at and w.ends_at;
$$;

revoke all on table public.aos_sentinel_alert_dispatches_v1 from PUBLIC,anon,authenticated,service_role;
revoke all on table public.aos_sentinel_alert_digest_items_v1 from PUBLIC,anon,authenticated,service_role;
revoke all on table public.aos_sentinel_maintenance_windows_v1 from PUBLIC,anon,authenticated,service_role;
revoke all on function public.aos_sentinel_alert_reserve_dispatch_v1(jsonb) from PUBLIC,anon,authenticated;
revoke all on function public.aos_sentinel_alert_mark_delivery_v1(bigint,text,text,integer,timestamptz) from PUBLIC,anon,authenticated;
revoke all on function public.aos_sentinel_alert_queue_digest_v1(jsonb) from PUBLIC,anon,authenticated;
revoke all on function public.aos_sentinel_alert_recent_dispatches_v1(text) from PUBLIC,anon,authenticated;
revoke all on function public.aos_sentinel_active_maintenance_windows_v1(timestamptz) from PUBLIC,anon,authenticated;
grant execute on function public.aos_sentinel_alert_reserve_dispatch_v1(jsonb) to service_role;
grant execute on function public.aos_sentinel_alert_mark_delivery_v1(bigint,text,text,integer,timestamptz) to service_role;
grant execute on function public.aos_sentinel_alert_queue_digest_v1(jsonb) to service_role;
grant execute on function public.aos_sentinel_alert_recent_dispatches_v1(text) to service_role;
grant execute on function public.aos_sentinel_active_maintenance_windows_v1(timestamptz) to service_role;

comment on table public.aos_sentinel_alert_dispatches_v1 is 'Sentinel F9 technical delivery ledger only; no rendered messages, credentials, PHI or PII.';
comment on table public.aos_sentinel_alert_digest_items_v1 is 'Sentinel F9 P2 digest queue storing technical incident IDs only.';
comment on table public.aos_sentinel_maintenance_windows_v1 is 'Sentinel F9 technical maintenance scopes; reason_code is controlled slug, not free text.';

commit;
