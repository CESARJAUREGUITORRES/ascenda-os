-- Sentinel F9-C — ASCENDA in-app owner notifications
-- Additive, Zero-PHI/PII, transport-neutral. Telegram remains optional/deferred.
begin;

alter table public.aos_sentinel_alert_dispatches_v1
  drop constraint if exists aos_sentinel_alert_dispatches_v1_channel_check;
alter table public.aos_sentinel_alert_dispatches_v1
  add constraint aos_sentinel_alert_dispatches_v1_channel_check
  check (channel in ('ascenda-in-app','telegram-owner'));

create table public.aos_sentinel_alert_runtime_v1 (
  id smallint primary key check (id=1),
  inapp_enabled boolean not null default true,
  telegram_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.aos_sentinel_alert_runtime_v1(id,inapp_enabled,telegram_enabled)
values(1,true,false);

create table public.aos_sentinel_owner_notification_reads_v1 (
  dispatch_id bigint not null references public.aos_sentinel_alert_dispatches_v1(dispatch_id) on delete cascade,
  actor_id uuid not null references public.aos_usuarios(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key(dispatch_id,actor_id)
);
create index aos_sentinel_owner_notification_reads_v1_actor_idx
  on public.aos_sentinel_owner_notification_reads_v1(actor_id,read_at desc);

create table public.aos_sentinel_alert_runtime_errors_v1 (
  error_id bigint generated always as identity primary key,
  operation text not null check (operation in ('route','digest-flush')),
  sqlstate_code text not null check (sqlstate_code ~ '^[0-9A-Z]{5}$'),
  occurred_at timestamptz not null default now()
);
create index aos_sentinel_alert_runtime_errors_v1_time_idx
  on public.aos_sentinel_alert_runtime_errors_v1(occurred_at desc);

alter table public.aos_sentinel_alert_runtime_v1 enable row level security;
alter table public.aos_sentinel_alert_runtime_v1 force row level security;
alter table public.aos_sentinel_owner_notification_reads_v1 enable row level security;
alter table public.aos_sentinel_owner_notification_reads_v1 force row level security;
alter table public.aos_sentinel_alert_runtime_errors_v1 enable row level security;
alter table public.aos_sentinel_alert_runtime_errors_v1 force row level security;

create or replace function public.aos_sentinel_owner_actor_v1(p_token text)
returns uuid
language sql
stable
security definer
set search_path=''
as $$
  select au.id
  from public.aos_app_sessions_v3 s
  join public.aos_usuarios au on au.id=s.user_id
  where s.token_hash=pg_catalog.encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex')
    and s.revoked=false
    and s.expires_at>pg_catalog.now()
    and s.assurance_level='PASSWORD_2FA'
    and au.activo=true
    and coalesce(au.nivel_jerarquia,99)<=2
  limit 1
$$;

create or replace function public.aos_sentinel_alert_reserve_dispatch_v2(p_request jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_attempt text; v_decision text; v_incident text; v_digest text; v_action text; v_severity text; v_status text; v_channel text;
  v_env text; v_domain text; v_component text; v_capability text; v_failure text; v_release text; v_commit text; v_deploy text;
  v_signal_count bigint; v_reopened integer; v_decided timestamptz; v_cooldown integer; v_existing bigint; v_last timestamptz; v_id bigint; k text;
begin
  if p_request is null or pg_catalog.jsonb_typeof(p_request)<>'object' then raise exception 'F9_DISPATCH_OBJECT_REQUIRED'; end if;
  for k in select pg_catalog.jsonb_object_keys(p_request) loop
    if k not in ('attempt_key','decision_key','incident_id','digest_key','action','severity','status','channel','environment','domain','component','capability','failure_family','release','commit_sha','deployment_id','signal_count','reopened_count','decided_at','cooldown_seconds') then raise exception 'F9_DISPATCH_UNAPPROVED_KEY:%',k; end if;
  end loop;
  if not (p_request ?& array['attempt_key','decision_key','action','severity','status','channel','environment','domain','decided_at','cooldown_seconds']) then raise exception 'F9_DISPATCH_REQUIRED_FIELD_MISSING'; end if;
  v_attempt:=p_request->>'attempt_key'; v_decision:=p_request->>'decision_key'; v_incident:=nullif(p_request->>'incident_id',''); v_digest:=nullif(p_request->>'digest_key','');
  v_action:=pg_catalog.upper(p_request->>'action'); v_severity:=pg_catalog.upper(p_request->>'severity'); v_status:=pg_catalog.upper(p_request->>'status'); v_channel:=pg_catalog.lower(p_request->>'channel');
  v_env:=pg_catalog.lower(p_request->>'environment'); v_domain:=pg_catalog.upper(p_request->>'domain');
  v_component:=nullif(pg_catalog.lower(coalesce(p_request->>'component','')),''); v_capability:=nullif(pg_catalog.lower(coalesce(p_request->>'capability','')),'');
  v_failure:=nullif(pg_catalog.lower(coalesce(p_request->>'failure_family','')),''); v_release:=nullif(p_request->>'release',''); v_commit:=nullif(p_request->>'commit_sha',''); v_deploy:=nullif(p_request->>'deployment_id','');
  begin
    v_signal_count:=coalesce((p_request->>'signal_count')::bigint,0); v_reopened:=coalesce((p_request->>'reopened_count')::integer,0); v_cooldown:=coalesce((p_request->>'cooldown_seconds')::integer,0); v_decided:=(p_request->>'decided_at')::timestamptz;
  exception when others then raise exception 'F9_DISPATCH_NUMERIC_OR_TIMESTAMP_INVALID'; end;
  if v_attempt is null or v_attempt !~ '^[A-Za-z0-9._:@/-]{1,240}$' or v_attempt ~ '[?#]' or v_attempt ~ '\.\.' then raise exception 'F9_ATTEMPT_KEY_INVALID'; end if;
  if v_decision is null or v_decision !~ '^[A-Za-z0-9._:@/-]{1,240}$' or v_decision ~ '[?#]' or v_decision ~ '\.\.' then raise exception 'F9_DECISION_KEY_INVALID'; end if;
  if v_action not in ('IMMEDIATE','RECOVERY','FLAPPING_SUMMARY','DIGEST') then raise exception 'F9_ACTION_INVALID'; end if;
  if v_severity not in ('P0','P1','P2') or v_status not in ('OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED') then raise exception 'F9_DISPATCH_STATE_INVALID'; end if;
  if v_channel not in ('ascenda-in-app','telegram-owner') then raise exception 'F9_CHANNEL_INVALID'; end if;
  if v_env !~ '^[a-z0-9][a-z0-9._:-]{0,63}$' or v_domain !~ '^[A-Z][A-Z0-9_]{0,63}$' then raise exception 'F9_SCOPE_INVALID'; end if;
  if v_cooldown<0 or v_cooldown>86400 or v_signal_count<0 or v_reopened<0 then raise exception 'F9_COUNTER_OR_COOLDOWN_INVALID'; end if;
  if (v_action='DIGEST' and (v_incident is not null or v_digest is null)) or (v_action<>'DIGEST' and (v_incident is null or v_digest is not null)) then raise exception 'F9_DISPATCH_TARGET_INVALID'; end if;
  if v_digest is not null and (v_digest !~ '^[A-Za-z0-9._:@/-]{1,240}$' or v_digest ~ '[?#]' or v_digest ~ '\.\.') then raise exception 'F9_DIGEST_KEY_INVALID'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sentinel:f9:attempt:'||v_attempt,0));
  select dispatch_id into v_existing from public.aos_sentinel_alert_dispatches_v1 where attempt_key=v_attempt;
  if v_existing is not null then return pg_catalog.jsonb_build_object('ok',true,'result','REPLAY','dispatch_id',v_existing); end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sentinel:f9:decision:'||v_decision,0));
  if v_cooldown>0 then
    select pg_catalog.max(delivered_at) into v_last from public.aos_sentinel_alert_dispatches_v1 where decision_key=v_decision and channel=v_channel and delivery_state='DELIVERED';
    if v_last is not null and v_decided < v_last + pg_catalog.make_interval(secs=>v_cooldown) then return pg_catalog.jsonb_build_object('ok',true,'result','SUPPRESSED_COOLDOWN','last_delivered_at',v_last); end if;
  end if;
  insert into public.aos_sentinel_alert_dispatches_v1(attempt_key,decision_key,incident_id,digest_key,action,severity,status,channel,environment,domain,component,capability,failure_family,release,commit_sha,deployment_id,signal_count,reopened_count,decided_at,cooldown_seconds)
  values(v_attempt,v_decision,v_incident,v_digest,v_action,v_severity,v_status,v_channel,v_env,v_domain,v_component,v_capability,v_failure,v_release,v_commit,v_deploy,v_signal_count,v_reopened,v_decided,v_cooldown)
  returning dispatch_id into v_id;
  return pg_catalog.jsonb_build_object('ok',true,'result','RESERVED','dispatch_id',v_id);
end;
$$;

create or replace function public.aos_sentinel_inapp_publish_dispatch_v1(p_dispatch_id bigint,p_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v public.aos_sentinel_alert_dispatches_v1%rowtype; v_at timestamptz:=coalesce(p_at,pg_catalog.clock_timestamp()); v_enabled boolean;
begin
  select inapp_enabled into v_enabled from public.aos_sentinel_alert_runtime_v1 where id=1;
  if coalesce(v_enabled,false)=false then return pg_catalog.jsonb_build_object('ok',true,'result','DISABLED','delivered',false); end if;
  select * into v from public.aos_sentinel_alert_dispatches_v1 where dispatch_id=p_dispatch_id for update;
  if not found then raise exception 'F9_DISPATCH_NOT_FOUND'; end if;
  if v.channel<>'ascenda-in-app' then raise exception 'F9_INAPP_CHANNEL_REQUIRED'; end if;
  if v.delivery_state='DELIVERED' then return pg_catalog.jsonb_build_object('ok',true,'result','REPLAY','delivered',true,'dispatch_id',v.dispatch_id); end if;
  update public.aos_sentinel_alert_dispatches_v1
    set delivery_state='DELIVERED',provider_ack_id='inapp:'||v.dispatch_id::text,retry_after_seconds=null,delivered_at=v_at,updated_at=v_at
    where dispatch_id=v.dispatch_id returning * into v;
  return pg_catalog.jsonb_build_object('ok',true,'result','DELIVERED','delivered',true,'dispatch_id',v.dispatch_id,'ack_id',v.provider_ack_id,'delivered_at',v.delivered_at);
end;
$$;

create or replace function public.aos_sentinel_set_inapp_enabled_v1(p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=''
as $$ begin
  update public.aos_sentinel_alert_runtime_v1 set inapp_enabled=coalesce(p_enabled,false),updated_at=pg_catalog.clock_timestamp() where id=1;
  return pg_catalog.jsonb_build_object('ok',true,'inapp_enabled',coalesce(p_enabled,false));
end; $$;

create or replace function public.aos_sentinel_route_incident_inapp_v1(p_incident_id text,p_old_status text default null,p_old_severity text default null,p_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  i public.aos_sentinel_incidents_v1%rowtype; v_at timestamptz:=coalesce(p_at,pg_catalog.clock_timestamp()); v_enabled boolean; v_maint boolean:=false;
  v_flap_recent timestamptz; v_changes integer:=0; v_action text; v_cooldown integer:=0; v_kind text; v_attempt text; v_decision text; v_req jsonb; v_res jsonb; v_dispatch bigint; v_bucket bigint; v_digest text; v_prior_delivered boolean:=false;
begin
  select inapp_enabled into v_enabled from public.aos_sentinel_alert_runtime_v1 where id=1;
  if coalesce(v_enabled,false)=false then return pg_catalog.jsonb_build_object('ok',true,'result','DISABLED'); end if;
  select * into i from public.aos_sentinel_incidents_v1 where incident_id=p_incident_id;
  if not found then raise exception 'F9_INCIDENT_NOT_FOUND'; end if;

  if i.severity<>'P0' then
    select exists(select 1 from public.aos_sentinel_maintenance_windows_v1 w where w.enabled and v_at between w.starts_at and w.ends_at and (w.environment is null or w.environment=i.environment) and (w.domain is null or w.domain=i.domain) and (w.component is null or w.component=i.component) and (w.capability is null or w.capability=i.capability)) into v_maint;
    if v_maint then return pg_catalog.jsonb_build_object('ok',true,'result','SUPPRESSED_MAINTENANCE'); end if;
    select pg_catalog.max(delivered_at) into v_flap_recent from public.aos_sentinel_alert_dispatches_v1 where incident_id=i.incident_id and channel='ascenda-in-app' and action='FLAPPING_SUMMARY' and delivery_state='DELIVERED';
    if v_flap_recent is not null and v_at < v_flap_recent + interval '15 minutes' then return pg_catalog.jsonb_build_object('ok',true,'result','SUPPRESSED_FLAPPING'); end if;
    if p_old_status is not null and p_old_status<>i.status then
      select count(*)::integer into v_changes from public.aos_sentinel_incident_timeline_v1 t where t.incident_id=i.incident_id and t.event_type='STATUS_CHANGED' and t.occurred_at>=v_at-interval '10 minutes';
      v_changes:=v_changes+1;
      if v_changes>=4 then v_action:='FLAPPING_SUMMARY'; v_cooldown:=900; v_kind:='FLAPPING'; end if;
    end if;
  end if;

  if v_action is null and i.status='RESOLVED' then
    if p_old_status is null or p_old_status='RESOLVED' or i.severity='P3' then return pg_catalog.jsonb_build_object('ok',true,'result','PANEL_ONLY'); end if;
    select exists(select 1 from public.aos_sentinel_alert_dispatches_v1 d where d.incident_id=i.incident_id and d.channel='ascenda-in-app' and d.delivery_state='DELIVERED' and d.action in ('IMMEDIATE','FLAPPING_SUMMARY','DIGEST')) into v_prior_delivered;
    if not v_prior_delivered then return pg_catalog.jsonb_build_object('ok',true,'result','PANEL_ONLY'); end if;
    v_action:='RECOVERY'; v_cooldown:=0; v_kind:='RECOVERY';
  end if;

  if v_action is null and i.severity='P3' then return pg_catalog.jsonb_build_object('ok',true,'result','PANEL_ONLY'); end if;
  if v_action is null and i.severity='P2' then
    v_bucket:=pg_catalog.floor(extract(epoch from v_at)/900)::bigint*900;
    v_digest:=i.environment||':'||i.domain||':'||v_bucket::text;
    insert into public.aos_sentinel_alert_digest_items_v1(digest_key,incident_id,environment,domain,bucket_start,bucket_end,queued_at,state,updated_at)
      values(v_digest,i.incident_id,i.environment,i.domain,pg_catalog.to_timestamp(v_bucket),pg_catalog.to_timestamp(v_bucket+900),v_at,'QUEUED',v_at)
      on conflict(digest_key,incident_id) do update set queued_at=excluded.queued_at,updated_at=excluded.updated_at where public.aos_sentinel_alert_digest_items_v1.state='QUEUED';
    return pg_catalog.jsonb_build_object('ok',true,'result','DIGEST_QUEUED','digest_key',v_digest);
  end if;
  if v_action is null then v_action:='IMMEDIATE'; v_cooldown:=case when i.severity='P0' then 60 else 300 end; v_kind:='INCIDENT'; end if;

  v_attempt:='inapp:'||i.incident_id||':'||v_kind||':'||i.severity||':'||i.status||':'||i.reopened_count::text||':'||(pg_catalog.floor(extract(epoch from v_at)*1000000)::bigint)::text;
  v_decision:='inapp:'||i.incident_id||':'||v_kind||':'||i.severity||':'||case when v_kind='RECOVERY' then i.reopened_count::text else i.status end;
  v_req:=pg_catalog.jsonb_build_object('attempt_key',v_attempt,'decision_key',v_decision,'incident_id',i.incident_id,'action',v_action,'severity',case when i.severity='P3' then 'P2' else i.severity end,'status',i.status,'channel','ascenda-in-app','environment',i.environment,'domain',i.domain,'component',i.component,'capability',i.capability,'failure_family',i.failure_family,'signal_count',i.signal_count,'reopened_count',i.reopened_count,'decided_at',v_at,'cooldown_seconds',v_cooldown);
  if i.correlation is not null then
    if i.correlation ? 'release' then v_req:=v_req||pg_catalog.jsonb_build_object('release',i.correlation->>'release'); end if;
    if i.correlation ? 'commit_sha' then v_req:=v_req||pg_catalog.jsonb_build_object('commit_sha',i.correlation->>'commit_sha'); end if;
    if i.correlation ? 'deployment_id' then v_req:=v_req||pg_catalog.jsonb_build_object('deployment_id',i.correlation->>'deployment_id'); end if;
  end if;
  v_res:=public.aos_sentinel_alert_reserve_dispatch_v2(v_req);
  if v_res->>'result'='RESERVED' then v_dispatch:=(v_res->>'dispatch_id')::bigint; return public.aos_sentinel_inapp_publish_dispatch_v1(v_dispatch,v_at); end if;
  return v_res;
end;
$$;

create or replace function public.aos_sentinel_inapp_flush_digests_v1(p_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_at timestamptz:=coalesce(p_at,pg_catalog.clock_timestamp()); r record; v_attempt text; v_req jsonb; v_res jsonb; v_dispatch bigint; v_count integer:=0; v_enabled boolean;
begin
  select inapp_enabled into v_enabled from public.aos_sentinel_alert_runtime_v1 where id=1;
  if coalesce(v_enabled,false)=false then return pg_catalog.jsonb_build_object('ok',true,'result','DISABLED','flushed',0); end if;
  for r in select digest_key,pg_catalog.min(environment) environment,pg_catalog.min(domain) domain,pg_catalog.min(bucket_start) bucket_start,pg_catalog.max(bucket_end) bucket_end,count(*)::integer item_count from public.aos_sentinel_alert_digest_items_v1 where state='QUEUED' and bucket_end<=v_at group by digest_key order by pg_catalog.min(bucket_end) limit 20 loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sentinel:f9:digest:'||r.digest_key,0));
    v_attempt:='inapp:digest:'||r.digest_key;
    v_req:=pg_catalog.jsonb_build_object('attempt_key',v_attempt,'decision_key',v_attempt,'digest_key',r.digest_key,'action','DIGEST','severity','P2','status','OPEN','channel','ascenda-in-app','environment',r.environment,'domain',r.domain,'decided_at',v_at,'cooldown_seconds',0);
    v_res:=public.aos_sentinel_alert_reserve_dispatch_v2(v_req);
    if v_res->>'result' in ('RESERVED','REPLAY') then
      v_dispatch:=(v_res->>'dispatch_id')::bigint;
      perform public.aos_sentinel_inapp_publish_dispatch_v1(v_dispatch,v_at);
      update public.aos_sentinel_alert_digest_items_v1 set state='SENT',claim_expires_at=null,updated_at=v_at where digest_key=r.digest_key and state in ('QUEUED','CLAIMED');
      v_count:=v_count+1;
    end if;
  end loop;
  return pg_catalog.jsonb_build_object('ok',true,'result','FLUSHED','flushed',v_count);
exception when others then
  insert into public.aos_sentinel_alert_runtime_errors_v1(operation,sqlstate_code,occurred_at) values('digest-flush',SQLSTATE,v_at);
  return pg_catalog.jsonb_build_object('ok',false,'result','DEGRADED','flushed',v_count);
end;
$$;

create or replace function public.aos_sentinel_owner_feed_v1(p_token text,p_limit integer default 30)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid; v_limit integer; v_items jsonb; v_unread bigint;
begin
  v_actor:=public.aos_sentinel_owner_actor_v1(p_token);
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','SENTINEL_OWNER_2FA_REQUIRED'); end if;
  v_limit:=least(greatest(coalesce(p_limit,30),1),50);
  perform public.aos_sentinel_inapp_flush_digests_v1(pg_catalog.clock_timestamp());
  select coalesce(pg_catalog.jsonb_agg(x.obj order by x.delivered_at desc),'[]'::jsonb) into v_items
  from (
    select d.delivered_at, pg_catalog.jsonb_build_object(
      'dispatch_id',d.dispatch_id,'action',d.action,'severity',d.severity,'status',d.status,'incident_id',d.incident_id,'digest_key',d.digest_key,
      'environment',d.environment,'domain',d.domain,'component',d.component,'capability',d.capability,'failure_family',d.failure_family,
      'release',d.release,'commit_sha',d.commit_sha,'deployment_id',d.deployment_id,'signal_count',d.signal_count,'reopened_count',d.reopened_count,
      'delivered_at',d.delivered_at,'read',exists(select 1 from public.aos_sentinel_owner_notification_reads_v1 rr where rr.dispatch_id=d.dispatch_id and rr.actor_id=v_actor),
      'incident_ids',case when d.action='DIGEST' then (select coalesce(pg_catalog.jsonb_agg(di.incident_id order by di.incident_id),'[]'::jsonb) from public.aos_sentinel_alert_digest_items_v1 di where di.digest_key=d.digest_key) else '[]'::jsonb end
    ) obj
    from public.aos_sentinel_alert_dispatches_v1 d
    where d.channel='ascenda-in-app' and d.delivery_state='DELIVERED'
    order by d.delivered_at desc limit v_limit
  ) x;
  select count(*) into v_unread from public.aos_sentinel_alert_dispatches_v1 d where d.channel='ascenda-in-app' and d.delivery_state='DELIVERED' and not exists(select 1 from public.aos_sentinel_owner_notification_reads_v1 rr where rr.dispatch_id=d.dispatch_id and rr.actor_id=v_actor);
  return pg_catalog.jsonb_build_object('ok',true,'items',v_items,'unread',v_unread,'transport','ascenda-in-app');
end;
$$;

create or replace function public.aos_sentinel_owner_mark_read_v1(p_token text,p_dispatch_id bigint)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid; v_exists boolean;
begin
  v_actor:=public.aos_sentinel_owner_actor_v1(p_token);
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','SENTINEL_OWNER_2FA_REQUIRED'); end if;
  select exists(select 1 from public.aos_sentinel_alert_dispatches_v1 d where d.dispatch_id=p_dispatch_id and d.channel='ascenda-in-app' and d.delivery_state='DELIVERED') into v_exists;
  if not v_exists then return pg_catalog.jsonb_build_object('ok',false,'error','SENTINEL_NOTIFICATION_NOT_FOUND'); end if;
  insert into public.aos_sentinel_owner_notification_reads_v1(dispatch_id,actor_id,read_at) values(p_dispatch_id,v_actor,pg_catalog.clock_timestamp()) on conflict(dispatch_id,actor_id) do update set read_at=excluded.read_at;
  return pg_catalog.jsonb_build_object('ok',true,'dispatch_id',p_dispatch_id,'read',true);
end;
$$;

create or replace function public.aos_sentinel_inapp_route_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_old_status text; v_old_severity text;
begin
  if TG_OP='UPDATE' then v_old_status:=OLD.status; v_old_severity:=OLD.severity; end if;
  perform public.aos_sentinel_route_incident_inapp_v1(NEW.incident_id,v_old_status,v_old_severity,pg_catalog.clock_timestamp());
  return NEW;
exception when others then
  insert into public.aos_sentinel_alert_runtime_errors_v1(operation,sqlstate_code,occurred_at) values('route',SQLSTATE,pg_catalog.clock_timestamp());
  return NEW;
end;
$$;

drop trigger if exists aos_sentinel_inapp_route_trg on public.aos_sentinel_incidents_v1;
create trigger aos_sentinel_inapp_route_trg
after insert or update of status,severity,signal_count,reopened_count,updated_at on public.aos_sentinel_incidents_v1
for each row execute function public.aos_sentinel_inapp_route_trigger_v1();

revoke all on public.aos_sentinel_alert_runtime_v1 from public,anon,authenticated;
revoke all on public.aos_sentinel_owner_notification_reads_v1 from public,anon,authenticated;
revoke all on public.aos_sentinel_alert_runtime_errors_v1 from public,anon,authenticated;
grant select,insert,update,delete on public.aos_sentinel_alert_runtime_v1 to service_role;
grant select,insert,update,delete on public.aos_sentinel_owner_notification_reads_v1 to service_role;
grant select,insert on public.aos_sentinel_alert_runtime_errors_v1 to service_role;

revoke all on function public.aos_sentinel_owner_actor_v1(text) from public,anon,authenticated;
revoke all on function public.aos_sentinel_alert_reserve_dispatch_v2(jsonb) from public,anon,authenticated;
revoke all on function public.aos_sentinel_inapp_publish_dispatch_v1(bigint,timestamptz) from public,anon,authenticated;
revoke all on function public.aos_sentinel_set_inapp_enabled_v1(boolean) from public,anon,authenticated;
revoke all on function public.aos_sentinel_route_incident_inapp_v1(text,text,text,timestamptz) from public,anon,authenticated;
revoke all on function public.aos_sentinel_inapp_flush_digests_v1(timestamptz) from public,anon,authenticated;
revoke all on function public.aos_sentinel_inapp_route_trigger_v1() from public,anon,authenticated;
revoke all on function public.aos_sentinel_owner_feed_v1(text,integer) from public;
revoke all on function public.aos_sentinel_owner_mark_read_v1(text,bigint) from public;

grant execute on function public.aos_sentinel_owner_actor_v1(text) to service_role;
grant execute on function public.aos_sentinel_alert_reserve_dispatch_v2(jsonb) to service_role;
grant execute on function public.aos_sentinel_inapp_publish_dispatch_v1(bigint,timestamptz) to service_role;
grant execute on function public.aos_sentinel_set_inapp_enabled_v1(boolean) to service_role;
grant execute on function public.aos_sentinel_route_incident_inapp_v1(text,text,text,timestamptz) to service_role;
grant execute on function public.aos_sentinel_inapp_flush_digests_v1(timestamptz) to service_role;
grant execute on function public.aos_sentinel_inapp_route_trigger_v1() to service_role;
grant execute on function public.aos_sentinel_owner_feed_v1(text,integer) to anon,authenticated,service_role;
grant execute on function public.aos_sentinel_owner_mark_read_v1(text,bigint) to anon,authenticated,service_role;

commit;
