-- Sentinel F8 Incident Engine persistence
-- BRANCH / ZERO-COST ONLY until explicit production authorization.
-- Stores sanitized technical metadata and typed evidence references only. No raw payloads / PHI / PII.

begin;

create table public.aos_sentinel_incident_counters_v1 (
  year integer primary key check (year between 2000 and 9999),
  last_sequence bigint not null default 0 check (last_sequence >= 0)
);

create table public.aos_sentinel_incidents_v1 (
  incident_id text primary key check (incident_id ~ '^SEN-[0-9]{4}-[0-9]{4,}$'),
  incident_fingerprint text not null check (incident_fingerprint ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  environment text not null check (environment in ('production','zero-cost','development')),
  domain text not null check (domain ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  component text not null check (component ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  capability text not null check (capability ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  failure_family text not null check (failure_family ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  severity text not null check (severity in ('P0','P1','P2','P3')),
  status text not null check (status in ('OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED')),
  opened_at timestamptz not null,
  updated_at timestamptz not null,
  last_signal_at timestamptz not null,
  resolved_at timestamptz,
  signal_count bigint not null default 1 check (signal_count >= 1),
  reopened_count integer not null default 0 check (reopened_count >= 0),
  signal_classes text[] not null default '{}'::text[],
  signal_fingerprints text[] not null default '{}'::text[],
  evidence_refs jsonb not null default '[]'::jsonb,
  correlation jsonb,
  check ((status='RESOLVED' and resolved_at is not null) or (status<>'RESOLVED' and resolved_at is null))
);

create unique index aos_sentinel_incidents_v1_active_fingerprint_uq
  on public.aos_sentinel_incidents_v1(environment,incident_fingerprint)
  where status<>'RESOLVED';
create index aos_sentinel_incidents_v1_updated_idx on public.aos_sentinel_incidents_v1(updated_at desc);
create index aos_sentinel_incidents_v1_status_severity_idx on public.aos_sentinel_incidents_v1(status,severity,updated_at desc);

create table public.aos_sentinel_incident_signals_v1 (
  event_id text primary key check (event_id ~ '^[A-Za-z0-9._:@/-]{1,200}$' and event_id !~ '[?#]' and event_id !~ '\.\.'),
  incident_id text not null references public.aos_sentinel_incidents_v1(incident_id) on delete cascade,
  signal_class text not null check (signal_class in ('ERROR','AVAILABILITY','BUSINESS_HEALTH','DEPENDENCY','DEPLOYMENT_CHANGE','SECURITY','USER_REPORTED')),
  signal_fingerprint text not null check (signal_fingerprint ~ '^[a-z0-9][a-z0-9._:-]{0,199}$'),
  severity text not null check (severity in ('P0','P1','P2','P3')),
  observed_at timestamptz not null,
  evidence_refs jsonb not null default '[]'::jsonb,
  correlation jsonb,
  recorded_at timestamptz not null default now()
);
create index aos_sentinel_incident_signals_v1_incident_idx on public.aos_sentinel_incident_signals_v1(incident_id,observed_at);

create table public.aos_sentinel_incident_timeline_v1 (
  timeline_id bigint generated always as identity primary key,
  incident_id text not null references public.aos_sentinel_incidents_v1(incident_id) on delete cascade,
  event_type text not null check (event_type in ('INCIDENT_OPENED','SIGNAL_ATTACHED','SEVERITY_ESCALATED','STATUS_CHANGED','INCIDENT_REOPENED')),
  occurred_at timestamptz not null,
  details jsonb not null default '{}'::jsonb
);
create index aos_sentinel_incident_timeline_v1_incident_idx on public.aos_sentinel_incident_timeline_v1(incident_id,timeline_id);

alter table public.aos_sentinel_incident_counters_v1 enable row level security;
alter table public.aos_sentinel_incidents_v1 enable row level security;
alter table public.aos_sentinel_incident_signals_v1 enable row level security;
alter table public.aos_sentinel_incident_timeline_v1 enable row level security;

create or replace function public.aos_sentinel_evidence_refs_valid_v1(p_refs jsonb)
returns boolean
language plpgsql
immutable
set search_path=''
as $$
declare
  v jsonb;
  v_kind text;
  v_id text;
begin
  if p_refs is null then return true; end if;
  if pg_catalog.jsonb_typeof(p_refs)<>'array' then return false; end if;
  for v in select value from pg_catalog.jsonb_array_elements(p_refs)
  loop
    if pg_catalog.jsonb_typeof(v)<>'object' then return false; end if;
    if not (v ? 'kind') or not (v ? 'id') then return false; end if;
    if (select count(*) from pg_catalog.jsonb_object_keys(v))<>2 then return false; end if;
    v_kind:=v->>'kind'; v_id:=v->>'id';
    if v_kind not in ('sentinel-signal','sentry-issue','github-commit','github-pr','railway-deployment','uptime-monitor','ci-run','trace') then return false; end if;
    if v_id is null or v_id !~ '^[A-Za-z0-9._:@/-]{1,200}$' or v_id ~ '[?#]' or v_id ~ '\.\.' then return false; end if;
  end loop;
  return true;
end;
$$;

create or replace function public.aos_sentinel_correlation_valid_v1(p_corr jsonb)
returns boolean
language plpgsql
immutable
set search_path=''
as $$
declare
  k text;
  v text;
begin
  if p_corr is null then return true; end if;
  if pg_catalog.jsonb_typeof(p_corr)<>'object' then return false; end if;
  for k in select pg_catalog.jsonb_object_keys(p_corr)
  loop
    if k not in ('release','commit_sha','deployment_id','request_id','trace_id','confidence') then return false; end if;
  end loop;
  if p_corr ? 'release' then
    v:=p_corr->>'release';
    if not (v='ascenda-os@unknown' or v ~ '^ascenda-os@[0-9a-f]{7,40}$') then return false; end if;
  end if;
  if p_corr ? 'commit_sha' and (p_corr->>'commit_sha') !~ '^[0-9a-f]{7,40}$' then return false; end if;
  if p_corr ? 'deployment_id' and ((p_corr->>'deployment_id') !~ '^[A-Za-z0-9._:@/-]{1,200}$' or (p_corr->>'deployment_id') ~ '[?#]' or (p_corr->>'deployment_id') ~ '\.\.') then return false; end if;
  if p_corr ? 'request_id' and (p_corr->>'request_id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then return false; end if;
  if p_corr ? 'trace_id' and ((p_corr->>'trace_id') !~ '^[0-9a-f]{32}$' or (p_corr->>'trace_id') ~ '^0+$') then return false; end if;
  if p_corr ? 'confidence' and (p_corr->>'confidence') not in ('EXACT','STRONG','WEAK','UNKNOWN') then return false; end if;
  return true;
end;
$$;

alter table public.aos_sentinel_incidents_v1
  add constraint aos_sentinel_incidents_v1_evidence_safe_chk check (public.aos_sentinel_evidence_refs_valid_v1(evidence_refs)),
  add constraint aos_sentinel_incidents_v1_correlation_safe_chk check (public.aos_sentinel_correlation_valid_v1(correlation));
alter table public.aos_sentinel_incident_signals_v1
  add constraint aos_sentinel_incident_signals_v1_evidence_safe_chk check (public.aos_sentinel_evidence_refs_valid_v1(evidence_refs)),
  add constraint aos_sentinel_incident_signals_v1_correlation_safe_chk check (public.aos_sentinel_correlation_valid_v1(correlation));

create or replace function public.aos_sentinel_ingest_signal_v1(p_signal jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_event_id text; v_class text; v_env text; v_domain text; v_component text; v_capability text; v_failure text;
  v_signal_fp text; v_incident_fp text; v_severity text; v_observed timestamptz; v_evidence jsonb; v_corr jsonb;
  v_existing_id text; v_incident_id text; v_resolved_id text; v_resolved_at timestamptz;
  v_incident public.aos_sentinel_incidents_v1%rowtype;
  v_now timestamptz:=pg_catalog.clock_timestamp(); v_year integer; v_seq bigint; v_old_severity text; v_next_severity text;
  v_reopened boolean:=false; v_created boolean:=false; v_merged_evidence jsonb; v_result jsonb; k text;
begin
  if p_signal is null or pg_catalog.jsonb_typeof(p_signal)<>'object' then raise exception 'F8_SIGNAL_OBJECT_REQUIRED'; end if;
  for k in select pg_catalog.jsonb_object_keys(p_signal)
  loop
    if k not in ('event_id','signal_class','environment','domain','component','capability','failure_family','signal_fingerprint','incident_fingerprint','severity','observed_at','evidence_refs','correlation') then raise exception 'F8_SIGNAL_UNAPPROVED_KEY:%',k; end if;
  end loop;
  if not (p_signal ?& array['event_id','signal_class','environment','domain','component','capability','failure_family','signal_fingerprint','incident_fingerprint','severity','observed_at']) then raise exception 'F8_SIGNAL_REQUIRED_FIELD_MISSING'; end if;

  v_event_id:=p_signal->>'event_id'; v_class:=pg_catalog.upper(p_signal->>'signal_class'); v_env:=pg_catalog.lower(p_signal->>'environment');
  v_domain:=pg_catalog.upper(p_signal->>'domain'); v_component:=pg_catalog.lower(p_signal->>'component'); v_capability:=pg_catalog.lower(p_signal->>'capability');
  v_failure:=pg_catalog.lower(p_signal->>'failure_family'); v_signal_fp:=pg_catalog.lower(p_signal->>'signal_fingerprint'); v_incident_fp:=pg_catalog.lower(p_signal->>'incident_fingerprint');
  v_severity:=pg_catalog.upper(p_signal->>'severity'); v_evidence:=coalesce(p_signal->'evidence_refs','[]'::jsonb); v_corr:=p_signal->'correlation';
  begin v_observed:=(p_signal->>'observed_at')::timestamptz; exception when others then raise exception 'F8_SIGNAL_INVALID_TIMESTAMP'; end;

  if v_event_id is null or v_event_id !~ '^[A-Za-z0-9._:@/-]{1,200}$' or v_event_id ~ '[?#]' or v_event_id ~ '\.\.' then raise exception 'F8_EVENT_ID_INVALID'; end if;
  if v_class is null or v_class not in ('ERROR','AVAILABILITY','BUSINESS_HEALTH','DEPENDENCY','DEPLOYMENT_CHANGE','SECURITY','USER_REPORTED') then raise exception 'F8_SIGNAL_CLASS_INVALID'; end if;
  if v_env is null or v_env not in ('production','zero-cost','development') then raise exception 'F8_ENVIRONMENT_INVALID'; end if;
  if v_domain is null or v_domain !~ '^[A-Z][A-Z0-9_]{0,63}$' then raise exception 'F8_DOMAIN_INVALID'; end if;
  if v_component is null or v_capability is null or v_failure is null or v_component !~ '^[a-z0-9][a-z0-9._:-]{0,199}$' or v_capability !~ '^[a-z0-9][a-z0-9._:-]{0,199}$' or v_failure !~ '^[a-z0-9][a-z0-9._:-]{0,199}$' then raise exception 'F8_TAXONOMY_INVALID'; end if;
  if v_signal_fp is null or v_incident_fp is null or v_signal_fp !~ '^[a-z0-9][a-z0-9._:-]{0,199}$' or v_incident_fp !~ '^[a-z0-9][a-z0-9._:-]{0,199}$' then raise exception 'F8_FINGERPRINT_INVALID'; end if;
  if v_severity is null or v_severity not in ('P0','P1','P2','P3') then raise exception 'F8_SEVERITY_INVALID'; end if;
  if not public.aos_sentinel_evidence_refs_valid_v1(v_evidence) then raise exception 'F8_EVIDENCE_INVALID'; end if;
  if not public.aos_sentinel_correlation_valid_v1(v_corr) then raise exception 'F8_CORRELATION_INVALID'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sentinel:event:'||v_event_id,0));
  select s.incident_id into v_existing_id from public.aos_sentinel_incident_signals_v1 s where s.event_id=v_event_id;
  if v_existing_id is not null then
    select pg_catalog.to_jsonb(i) into v_result from public.aos_sentinel_incidents_v1 i where i.incident_id=v_existing_id;
    return pg_catalog.jsonb_build_object('ok',true,'replay',true,'mutated',false,'reopened',false,'incident',v_result);
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('sentinel:incident:'||v_env||':'||v_incident_fp,0));
  select i.incident_id into v_incident_id from public.aos_sentinel_incidents_v1 i
    where i.environment=v_env and i.incident_fingerprint=v_incident_fp and i.status<>'RESOLVED'
    order by i.updated_at desc limit 1 for update;

  if v_incident_id is null then
    select i.incident_id,i.resolved_at into v_resolved_id,v_resolved_at from public.aos_sentinel_incidents_v1 i
      where i.environment=v_env and i.incident_fingerprint=v_incident_fp and i.status='RESOLVED'
      order by i.resolved_at desc nulls last limit 1 for update;
    if v_resolved_id is not null and v_resolved_at is not null and v_observed>=v_resolved_at and v_observed<=v_resolved_at+interval '60 minutes' then
      v_incident_id:=v_resolved_id; v_reopened:=true;
      update public.aos_sentinel_incidents_v1 set status='OPEN',resolved_at=null,reopened_count=reopened_count+1,updated_at=v_now where incident_id=v_incident_id;
      insert into public.aos_sentinel_incident_timeline_v1(incident_id,event_type,occurred_at,details)
        values(v_incident_id,'INCIDENT_REOPENED',v_now,pg_catalog.jsonb_build_object('event_id',v_event_id));
    end if;
  end if;

  if v_incident_id is null then
    v_year:=extract(year from v_observed)::integer;
    insert into public.aos_sentinel_incident_counters_v1(year,last_sequence) values(v_year,1)
      on conflict(year) do update set last_sequence=public.aos_sentinel_incident_counters_v1.last_sequence+1
      returning last_sequence into v_seq;
    v_incident_id:=pg_catalog.format('SEN-%s-%s',v_year,pg_catalog.lpad(v_seq::text,4,'0'));
    insert into public.aos_sentinel_incidents_v1(
      incident_id,incident_fingerprint,environment,domain,component,capability,failure_family,severity,status,opened_at,updated_at,last_signal_at,resolved_at,
      signal_count,reopened_count,signal_classes,signal_fingerprints,evidence_refs,correlation
    ) values(
      v_incident_id,v_incident_fp,v_env,v_domain,v_component,v_capability,v_failure,v_severity,'OPEN',v_observed,v_now,v_observed,null,
      1,0,array[v_class],array[v_signal_fp],v_evidence,v_corr
    );
    insert into public.aos_sentinel_incident_timeline_v1(incident_id,event_type,occurred_at,details)
      values(v_incident_id,'INCIDENT_OPENED',v_now,pg_catalog.jsonb_build_object('event_id',v_event_id,'signal_class',v_class,'severity',v_severity));
    v_created:=true;
  else
    select * into v_incident from public.aos_sentinel_incidents_v1 where incident_id=v_incident_id for update;
    if v_incident.environment<>v_env or v_incident.domain<>v_domain or v_incident.component<>v_component or v_incident.capability<>v_capability or v_incident.failure_family<>v_failure or v_incident.incident_fingerprint<>v_incident_fp then raise exception 'F8_INCIDENT_FINGERPRINT_SCOPE_CONTRADICTION'; end if;
    v_old_severity:=v_incident.severity;
    if pg_catalog.array_position(array['P0','P1','P2','P3']::text[],v_severity)<pg_catalog.array_position(array['P0','P1','P2','P3']::text[],v_old_severity) then v_next_severity:=v_severity; else v_next_severity:=v_old_severity; end if;
    select coalesce(jsonb_agg(x.value order by x.value::text),'[]'::jsonb) into v_merged_evidence
      from (select distinct value from pg_catalog.jsonb_array_elements(v_incident.evidence_refs||v_evidence)) x;
    update public.aos_sentinel_incidents_v1 set
      severity=v_next_severity,updated_at=v_now,last_signal_at=greatest(last_signal_at,v_observed),signal_count=signal_count+1,
      signal_classes=(select array_agg(x order by x) from (select distinct pg_catalog.unnest(signal_classes||array[v_class]) as x) q),
      signal_fingerprints=(select array_agg(x order by x) from (select distinct pg_catalog.unnest(signal_fingerprints||array[v_signal_fp]) as x) q),
      evidence_refs=v_merged_evidence,correlation=case when v_corr is null then correlation else v_corr end
      where incident_id=v_incident_id;
    if v_next_severity<>v_old_severity then
      insert into public.aos_sentinel_incident_timeline_v1(incident_id,event_type,occurred_at,details)
        values(v_incident_id,'SEVERITY_ESCALATED',v_now,pg_catalog.jsonb_build_object('from',v_old_severity,'to',v_next_severity,'event_id',v_event_id));
    end if;
  end if;

  insert into public.aos_sentinel_incident_signals_v1(event_id,incident_id,signal_class,signal_fingerprint,severity,observed_at,evidence_refs,correlation,recorded_at)
    values(v_event_id,v_incident_id,v_class,v_signal_fp,v_severity,v_observed,v_evidence,v_corr,v_now);
  insert into public.aos_sentinel_incident_timeline_v1(incident_id,event_type,occurred_at,details)
    values(v_incident_id,'SIGNAL_ATTACHED',v_now,pg_catalog.jsonb_build_object('event_id',v_event_id,'signal_fingerprint',v_signal_fp));
  select pg_catalog.to_jsonb(i) into v_result from public.aos_sentinel_incidents_v1 i where i.incident_id=v_incident_id;
  return pg_catalog.jsonb_build_object('ok',true,'replay',false,'mutated',true,'reopened',v_reopened,'created',v_created,'incident',v_result);
end;
$$;

create or replace function public.aos_sentinel_transition_incident_v1(p_incident_id text,p_target_status text,p_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v public.aos_sentinel_incidents_v1%rowtype;
  v_target text:=pg_catalog.upper(coalesce(p_target_status,''));
  v_at timestamptz:=coalesce(p_at,pg_catalog.clock_timestamp());
  v_from text;
  v_allowed boolean:=false;
begin
  select * into v from public.aos_sentinel_incidents_v1 where incident_id=p_incident_id for update;
  if not found then raise exception 'F8_INCIDENT_NOT_FOUND'; end if;
  if v_target not in ('OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED') then raise exception 'F8_STATUS_INVALID'; end if;
  if v_target=v.status then return pg_catalog.jsonb_build_object('ok',true,'mutated',false,'incident',pg_catalog.to_jsonb(v)); end if;
  v_from:=v.status;
  v_allowed:=(v_from='OPEN' and v_target in ('ACK','INVESTIGATING','MITIGATED','RESOLVED'))
    or (v_from='ACK' and v_target in ('INVESTIGATING','MITIGATED','RESOLVED'))
    or (v_from='INVESTIGATING' and v_target in ('MITIGATED','RESOLVED'))
    or (v_from='MITIGATED' and v_target in ('INVESTIGATING','RESOLVED'));
  if not v_allowed then raise exception 'F8_STATUS_TRANSITION_INVALID:%->%',v_from,v_target; end if;
  update public.aos_sentinel_incidents_v1 set status=v_target,updated_at=v_at,resolved_at=case when v_target='RESOLVED' then v_at else null end
    where incident_id=p_incident_id returning * into v;
  insert into public.aos_sentinel_incident_timeline_v1(incident_id,event_type,occurred_at,details)
    values(p_incident_id,'STATUS_CHANGED',v_at,pg_catalog.jsonb_build_object('from',v_from,'to',v_target));
  return pg_catalog.jsonb_build_object('ok',true,'mutated',true,'incident',pg_catalog.to_jsonb(v));
end;
$$;

create or replace function public.aos_sentinel_get_incident_v1(p_incident_id text)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'incident',pg_catalog.to_jsonb(i),
    'signals',coalesce((select jsonb_agg(pg_catalog.to_jsonb(s) order by s.recorded_at,s.event_id) from public.aos_sentinel_incident_signals_v1 s where s.incident_id=i.incident_id),'[]'::jsonb),
    'timeline',coalesce((select jsonb_agg(pg_catalog.to_jsonb(t) order by t.timeline_id) from public.aos_sentinel_incident_timeline_v1 t where t.incident_id=i.incident_id),'[]'::jsonb)
  ) from public.aos_sentinel_incidents_v1 i where i.incident_id=p_incident_id;
$$;

revoke all on table public.aos_sentinel_incident_counters_v1 from PUBLIC,anon,authenticated,service_role;
revoke all on table public.aos_sentinel_incidents_v1 from PUBLIC,anon,authenticated,service_role;
revoke all on table public.aos_sentinel_incident_signals_v1 from PUBLIC,anon,authenticated,service_role;
revoke all on table public.aos_sentinel_incident_timeline_v1 from PUBLIC,anon,authenticated,service_role;
revoke all on function public.aos_sentinel_evidence_refs_valid_v1(jsonb) from PUBLIC,anon,authenticated,service_role;
revoke all on function public.aos_sentinel_correlation_valid_v1(jsonb) from PUBLIC,anon,authenticated,service_role;
revoke all on function public.aos_sentinel_ingest_signal_v1(jsonb) from PUBLIC,anon,authenticated;
revoke all on function public.aos_sentinel_transition_incident_v1(text,text,timestamptz) from PUBLIC,anon,authenticated;
revoke all on function public.aos_sentinel_get_incident_v1(text) from PUBLIC,anon,authenticated;
grant execute on function public.aos_sentinel_ingest_signal_v1(jsonb) to service_role;
grant execute on function public.aos_sentinel_transition_incident_v1(text,text,timestamptz) to service_role;
grant execute on function public.aos_sentinel_get_incident_v1(text) to service_role;

comment on table public.aos_sentinel_incidents_v1 is 'Sentinel canonical incident metadata only; Zero-PHI/PII; no raw signal payloads.';
comment on function public.aos_sentinel_ingest_signal_v1(jsonb) is 'Sentinel F8 transactional ingest; service_role only; event-idempotent and fingerprint-serialized.';

commit;
