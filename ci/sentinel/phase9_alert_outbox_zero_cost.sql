\set ON_ERROR_STOP on

-- Seed one synthetic F8 incident through the certified F8 API.
select public.aos_sentinel_ingest_signal_v1(jsonb_build_object(
  'event_id','f9-zc-incident-001','signal_class','ERROR','environment','zero-cost','domain','SENTINEL','component','alert-router','capability','durable-outbox','failure_family','synthetic-canary','signal_fingerprint','error:sentinel:f9-outbox','incident_fingerprint','zero-cost:sentinel:alert-router:durable-outbox:synthetic-canary','severity','P1','observed_at','2026-08-17T00:00:00Z'
));

-- RLS, ACL and SECURITY DEFINER contract.
do $$
begin
  if (select count(*) from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('aos_sentinel_alert_dispatches_v1','aos_sentinel_alert_digest_items_v1','aos_sentinel_maintenance_windows_v1') and c.relrowsecurity) <> 3 then raise exception 'F9_ZC_RLS'; end if;
  if exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('aos_sentinel_alert_reserve_dispatch_v1','aos_sentinel_alert_mark_delivery_v1','aos_sentinel_alert_queue_digest_v1','aos_sentinel_alert_recent_dispatches_v1','aos_sentinel_active_maintenance_windows_v1') and (not p.prosecdef or coalesce(array_to_string(p.proconfig,','),'') not like '%search_path=%')) then raise exception 'F9_ZC_RPC_SECURITY'; end if;
  if has_function_privilege('anon','public.aos_sentinel_alert_reserve_dispatch_v1(jsonb)','EXECUTE') then raise exception 'F9_ZC_ANON_EXECUTE'; end if;
  if has_function_privilege('authenticated','public.aos_sentinel_alert_reserve_dispatch_v1(jsonb)','EXECUTE') then raise exception 'F9_ZC_AUTH_EXECUTE'; end if;
  if not has_function_privilege('service_role','public.aos_sentinel_alert_reserve_dispatch_v1(jsonb)','EXECUTE') then raise exception 'F9_ZC_SERVICE_EXECUTE'; end if;
  if has_table_privilege('anon','public.aos_sentinel_alert_dispatches_v1','SELECT') or has_table_privilege('authenticated','public.aos_sentinel_alert_dispatches_v1','SELECT') then raise exception 'F9_ZC_DIRECT_TABLE_ACCESS'; end if;
end $$;

-- First reservation and exact-attempt replay.
do $$
declare a jsonb; b jsonb; id bigint;
begin
  a:=public.aos_sentinel_alert_reserve_dispatch_v1(jsonb_build_object(
    'attempt_key','f9-attempt-a','decision_key','SEN-2026-0001:INCIDENT:P1:OPEN','incident_id','SEN-2026-0001','action','IMMEDIATE','severity','P1','status','OPEN','environment','zero-cost','domain','SENTINEL','component','alert-router','capability','durable-outbox','failure_family','synthetic-canary','signal_count',1,'reopened_count',0,'decided_at','2026-08-17T00:01:00Z','cooldown_seconds',300
  ));
  if a->>'result'<>'RESERVED' then raise exception 'F9_ZC_FIRST_RESERVE'; end if;
  id:=(a->>'dispatch_id')::bigint;
  b:=public.aos_sentinel_alert_reserve_dispatch_v1(jsonb_build_object(
    'attempt_key','f9-attempt-a','decision_key','SEN-2026-0001:INCIDENT:P1:OPEN','incident_id','SEN-2026-0001','action','IMMEDIATE','severity','P1','status','OPEN','environment','zero-cost','domain','SENTINEL','component','alert-router','capability','durable-outbox','failure_family','synthetic-canary','signal_count',1,'reopened_count',0,'decided_at','2026-08-17T00:01:00Z','cooldown_seconds',300
  ));
  if b->>'result'<>'REPLAY' or (b->>'dispatch_id')::bigint<>id then raise exception 'F9_ZC_ATTEMPT_REPLAY'; end if;
  perform public.aos_sentinel_alert_mark_delivery_v1(id,'DELIVERED','fake-1001',null,'2026-08-17T00:01:05Z');
end $$;

-- Cooldown survives process restart because it is in PostgreSQL.
do $$
declare x jsonb;
begin
  x:=public.aos_sentinel_alert_reserve_dispatch_v1(jsonb_build_object(
    'attempt_key','f9-attempt-b','decision_key','SEN-2026-0001:INCIDENT:P1:OPEN','incident_id','SEN-2026-0001','action','IMMEDIATE','severity','P1','status','OPEN','environment','zero-cost','domain','SENTINEL','decided_at','2026-08-17T00:03:00Z','cooldown_seconds',300
  ));
  if x->>'result'<>'SUPPRESSED_COOLDOWN' then raise exception 'F9_ZC_COOLDOWN_NOT_DURABLE'; end if;
  x:=public.aos_sentinel_alert_reserve_dispatch_v1(jsonb_build_object(
    'attempt_key','f9-attempt-c','decision_key','SEN-2026-0001:INCIDENT:P1:OPEN','incident_id','SEN-2026-0001','action','IMMEDIATE','severity','P1','status','OPEN','environment','zero-cost','domain','SENTINEL','decided_at','2026-08-17T00:07:00Z','cooldown_seconds',300
  ));
  if x->>'result'<>'RESERVED' then raise exception 'F9_ZC_POST_COOLDOWN_RESERVE'; end if;
end $$;

-- Two distinct resolve transitions use distinct durable decision keys and both may reserve.
do $$
declare a jsonb; b jsonb;
begin
  a:=public.aos_sentinel_alert_reserve_dispatch_v1(jsonb_build_object(
    'attempt_key','f9-recovery-a','decision_key','SEN-2026-0001:RECOVERY:P1:RESOLVED:2026-08-17T00:10:00.000Z','incident_id','SEN-2026-0001','action','RECOVERY','severity','P1','status','RESOLVED','environment','zero-cost','domain','SENTINEL','decided_at','2026-08-17T00:10:00Z','cooldown_seconds',0
  ));
  b:=public.aos_sentinel_alert_reserve_dispatch_v1(jsonb_build_object(
    'attempt_key','f9-recovery-b','decision_key','SEN-2026-0001:RECOVERY:P1:RESOLVED:2026-08-17T00:20:00.000Z','incident_id','SEN-2026-0001','action','RECOVERY','severity','P1','status','RESOLVED','environment','zero-cost','domain','SENTINEL','decided_at','2026-08-17T00:20:00Z','cooldown_seconds',0
  ));
  if a->>'result'<>'RESERVED' or b->>'result'<>'RESERVED' then raise exception 'F9_ZC_SECOND_RECOVERY_BLOCKED'; end if;
end $$;

-- Durable P2 digest item is idempotent.
do $$
declare a jsonb; b jsonb;
begin
  a:=public.aos_sentinel_alert_queue_digest_v1(jsonb_build_object('digest_key','zero-cost:SENTINEL:1770000000000','incident_id','SEN-2026-0001','environment','zero-cost','domain','SENTINEL','bucket_start','2026-08-17T00:30:00Z','bucket_end','2026-08-17T00:45:00Z','queued_at','2026-08-17T00:31:00Z'));
  b:=public.aos_sentinel_alert_queue_digest_v1(jsonb_build_object('digest_key','zero-cost:SENTINEL:1770000000000','incident_id','SEN-2026-0001','environment','zero-cost','domain','SENTINEL','bucket_start','2026-08-17T00:30:00Z','bucket_end','2026-08-17T00:45:00Z','queued_at','2026-08-17T00:31:00Z'));
  if (a->>'inserted')::boolean is not true or (b->>'inserted')::boolean is not false then raise exception 'F9_ZC_DIGEST_IDEMPOTENCY'; end if;
end $$;

-- Maintenance data contains only technical taxonomy and controlled reason code.
insert into public.aos_sentinel_maintenance_windows_v1(environment,domain,component,capability,reason_code,starts_at,ends_at)
values('zero-cost','SENTINEL','alert-router','durable-outbox','synthetic-maintenance','2026-08-17T00:00:00Z','2026-08-17T01:00:00Z');
do $$
declare x jsonb;
begin
  x:=public.aos_sentinel_active_maintenance_windows_v1('2026-08-17T00:40:00Z');
  if pg_catalog.jsonb_array_length(x)<>1 or x->0->>'reason_code'<>'synthetic-maintenance' then raise exception 'F9_ZC_MAINTENANCE_READ'; end if;
end $$;

-- No message/payload/credential/contact columns.
do $$
begin
  if exists(select 1 from information_schema.columns where table_schema='public' and table_name in ('aos_sentinel_alert_dispatches_v1','aos_sentinel_alert_digest_items_v1','aos_sentinel_maintenance_windows_v1') and lower(column_name) ~ '(message|mensaje|body|payload|token|secret|cookie|authorization|phone|telefono|dni|email|patient|paciente|nombre|recipient|wa_id)') then raise exception 'F9_ZC_SENSITIVE_COLUMN'; end if;
  if (select count(*) from public.aos_sentinel_alert_digest_items_v1 where digest_key='zero-cost:SENTINEL:1770000000000')<>1 then raise exception 'F9_ZC_DIGEST_COUNT'; end if;
  if (select count(*) from public.aos_sentinel_alert_dispatches_v1 where decision_key='SEN-2026-0001:INCIDENT:P1:OPEN')<>2 then raise exception 'F9_ZC_DISPATCH_COUNT'; end if;
end $$;

select 'SENTINEL_F9_ALERT_OUTBOX_FIXTURE=PASS' as certificate;
