\set ON_ERROR_STOP on

DO $$
DECLARE
  r1 jsonb; r2 jsonb; r3 jsonb; rr jsonb; ro jsonb; g jsonb;
  id1 text; id2 text;
  bad_ok boolean:=false;
  n integer;
BEGIN
  -- Objects + RLS.
  IF to_regclass('public.aos_sentinel_incidents_v1') IS NULL THEN RAISE EXCEPTION 'F8_DB_INCIDENT_TABLE_MISSING'; END IF;
  IF to_regclass('public.aos_sentinel_incident_signals_v1') IS NULL THEN RAISE EXCEPTION 'F8_DB_SIGNAL_TABLE_MISSING'; END IF;
  IF to_regclass('public.aos_sentinel_incident_timeline_v1') IS NULL THEN RAISE EXCEPTION 'F8_DB_TIMELINE_TABLE_MISSING'; END IF;
  IF to_regclass('public.aos_sentinel_incident_counters_v1') IS NULL THEN RAISE EXCEPTION 'F8_DB_COUNTER_TABLE_MISSING'; END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace nsp ON nsp.oid=c.relnamespace
    WHERE nsp.nspname='public' AND c.relname IN ('aos_sentinel_incidents_v1','aos_sentinel_incident_signals_v1','aos_sentinel_incident_timeline_v1','aos_sentinel_incident_counters_v1')
      AND c.relrowsecurity IS NOT TRUE
  ) THEN RAISE EXCEPTION 'F8_DB_RLS_DISABLED'; END IF;

  -- No direct table privileges for app roles or service_role; mutation/read happens through protected RPCs.
  IF has_table_privilege('anon','public.aos_sentinel_incidents_v1','SELECT') THEN RAISE EXCEPTION 'F8_DB_ANON_DIRECT_SELECT'; END IF;
  IF has_table_privilege('authenticated','public.aos_sentinel_incidents_v1','SELECT') THEN RAISE EXCEPTION 'F8_DB_AUTH_DIRECT_SELECT'; END IF;
  IF has_table_privilege('service_role','public.aos_sentinel_incidents_v1','SELECT') THEN RAISE EXCEPTION 'F8_DB_SERVICE_DIRECT_SELECT'; END IF;
  IF has_function_privilege('anon','public.aos_sentinel_ingest_signal_v1(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'F8_DB_ANON_INGEST_EXECUTE'; END IF;
  IF has_function_privilege('authenticated','public.aos_sentinel_ingest_signal_v1(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'F8_DB_AUTH_INGEST_EXECUTE'; END IF;
  IF NOT has_function_privilege('service_role','public.aos_sentinel_ingest_signal_v1(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'F8_DB_SERVICE_INGEST_MISSING'; END IF;
  IF NOT has_function_privilege('service_role','public.aos_sentinel_transition_incident_v1(text,text,timestamp with time zone)','EXECUTE') THEN RAISE EXCEPTION 'F8_DB_SERVICE_TRANSITION_MISSING'; END IF;
  IF NOT has_function_privilege('service_role','public.aos_sentinel_get_incident_v1(text)','EXECUTE') THEN RAISE EXCEPTION 'F8_DB_SERVICE_GET_MISSING'; END IF;

  -- No obvious sensitive/raw payload columns.
  SELECT count(*) INTO n FROM information_schema.columns
  WHERE table_schema='public'
    AND table_name IN ('aos_sentinel_incidents_v1','aos_sentinel_incident_signals_v1','aos_sentinel_incident_timeline_v1')
    AND lower(column_name) ~ '(patient|paciente|phone|telefono|dni|email|message_body|request_body|payload|prompt|token|cookie|secret|password|authorization)';
  IF n<>0 THEN RAISE EXCEPTION 'F8_DB_SENSITIVE_COLUMN_FOUND'; END IF;

  r1:=public.aos_sentinel_ingest_signal_v1(jsonb_build_object(
    'event_id','sql-wa-001','signal_class','AVAILABILITY','environment','zero-cost','domain','WHATSAPP',
    'component','human-outbound','capability','provider-status-progression','failure_family','provider-stall',
    'signal_fingerprint','availability:whatsapp:provider-stall',
    'incident_fingerprint','zero-cost:whatsapp:human-outbound:provider-status-progression:provider-stall',
    'severity','P2','observed_at','2026-08-16T22:59:00Z',
    'evidence_refs',jsonb_build_array(jsonb_build_object('kind','sentinel-signal','id','sql-wa-availability-001')),
    'correlation',jsonb_build_object('release','ascenda-os@01958565af1a5ffe426ffb0ac9e0588c77341175','commit_sha','01958565af1a5ffe426ffb0ac9e0588c77341175','deployment_id','dep-zero-cost','confidence','EXACT')
  ));
  id1:=r1->'incident'->>'incident_id';
  IF id1<>'SEN-2026-0001' OR (r1->>'replay')::boolean THEN RAISE EXCEPTION 'F8_DB_FIRST_ID_OR_REPLAY_FAILED:%',r1; END IF;

  -- Replay exact event is a no-op.
  r2:=public.aos_sentinel_ingest_signal_v1(jsonb_build_object(
    'event_id','sql-wa-001','signal_class','AVAILABILITY','environment','zero-cost','domain','WHATSAPP',
    'component','human-outbound','capability','provider-status-progression','failure_family','provider-stall',
    'signal_fingerprint','availability:whatsapp:provider-stall',
    'incident_fingerprint','zero-cost:whatsapp:human-outbound:provider-status-progression:provider-stall',
    'severity','P2','observed_at','2026-08-16T22:59:00Z'
  ));
  IF NOT (r2->>'replay')::boolean OR (r2->'incident'->>'signal_count')::int<>1 OR r2->'incident'->>'incident_id'<>id1 THEN RAISE EXCEPTION 'F8_DB_REPLAY_FAILED:%',r2; END IF;

  -- Different class converges and escalates severity.
  r3:=public.aos_sentinel_ingest_signal_v1(jsonb_build_object(
    'event_id','sql-wa-002','signal_class','BUSINESS_HEALTH','environment','zero-cost','domain','WHATSAPP',
    'component','human-outbound','capability','provider-status-progression','failure_family','provider-stall',
    'signal_fingerprint','business-health:whatsapp:outbound-receipt-stall',
    'incident_fingerprint','zero-cost:whatsapp:human-outbound:provider-status-progression:provider-stall',
    'severity','P1','observed_at','2026-08-16T23:01:00Z',
    'evidence_refs',jsonb_build_array(jsonb_build_object('kind','sentinel-signal','id','sql-wa-business-002'))
  ));
  IF r3->'incident'->>'incident_id'<>id1 OR r3->'incident'->>'severity'<>'P1' OR (r3->'incident'->>'signal_count')::int<>2 THEN RAISE EXCEPTION 'F8_DB_CONVERGENCE_ESCALATION_FAILED:%',r3; END IF;

  -- Lifecycle and exact from/to timeline.
  PERFORM public.aos_sentinel_transition_incident_v1(id1,'ACK','2026-08-16T23:03:00Z');
  PERFORM public.aos_sentinel_transition_incident_v1(id1,'INVESTIGATING','2026-08-16T23:04:00Z');
  PERFORM public.aos_sentinel_transition_incident_v1(id1,'MITIGATED','2026-08-16T23:05:00Z');
  PERFORM public.aos_sentinel_transition_incident_v1(id1,'RESOLVED','2026-08-16T23:10:00Z');
  BEGIN
    PERFORM public.aos_sentinel_transition_incident_v1(id1,'ACK','2026-08-16T23:11:00Z');
  EXCEPTION WHEN OTHERS THEN
    IF position('F8_STATUS_TRANSITION_INVALID' in SQLERRM)>0 THEN bad_ok:=true; ELSE RAISE; END IF;
  END;
  IF NOT bad_ok THEN RAISE EXCEPTION 'F8_DB_INVALID_TRANSITION_ACCEPTED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aos_sentinel_incident_timeline_v1 WHERE incident_id=id1 AND event_type='STATUS_CHANGED' AND details=jsonb_build_object('from','ACK','to','INVESTIGATING')) THEN RAISE EXCEPTION 'F8_DB_TIMELINE_FROM_TO_MISSING'; END IF;

  -- Reopen inside 60m keeps same ID.
  rr:=public.aos_sentinel_ingest_signal_v1(jsonb_build_object(
    'event_id','sql-wa-003','signal_class','ERROR','environment','zero-cost','domain','WHATSAPP',
    'component','human-outbound','capability','provider-status-progression','failure_family','provider-stall',
    'signal_fingerprint','error:whatsapp:provider-stall',
    'incident_fingerprint','zero-cost:whatsapp:human-outbound:provider-status-progression:provider-stall',
    'severity','P2','observed_at','2026-08-16T23:24:00Z',
    'evidence_refs',jsonb_build_array(jsonb_build_object('kind','sentry-issue','id','ASCENDA-OS-SQL-003'))
  ));
  IF rr->'incident'->>'incident_id'<>id1 OR NOT (rr->>'reopened')::boolean OR rr->'incident'->>'status'<>'OPEN' THEN RAISE EXCEPTION 'F8_DB_REOPEN_FAILED:%',rr; END IF;

  PERFORM public.aos_sentinel_transition_incident_v1(id1,'RESOLVED','2026-08-16T23:30:00Z');

  -- Outside window creates a new ID.
  ro:=public.aos_sentinel_ingest_signal_v1(jsonb_build_object(
    'event_id','sql-wa-004','signal_class','BUSINESS_HEALTH','environment','zero-cost','domain','WHATSAPP',
    'component','human-outbound','capability','provider-status-progression','failure_family','provider-stall',
    'signal_fingerprint','business-health:whatsapp:outbound-receipt-stall',
    'incident_fingerprint','zero-cost:whatsapp:human-outbound:provider-status-progression:provider-stall',
    'severity','P2','observed_at','2026-08-17T01:44:00Z'
  ));
  id2:=ro->'incident'->>'incident_id';
  IF id2<>'SEN-2026-0002' OR id2=id1 OR (ro->>'reopened')::boolean THEN RAISE EXCEPTION 'F8_DB_OUTSIDE_WINDOW_NEW_ID_FAILED:%',ro; END IF;

  -- Protected read RPC is stable/consultable.
  g:=public.aos_sentinel_get_incident_v1(id1);
  IF g->'incident'->>'incident_id'<>id1 OR jsonb_array_length(g->'signals')<>3 OR jsonb_array_length(g->'timeline')<8 THEN RAISE EXCEPTION 'F8_DB_GET_INCIDENT_FAILED:%',g; END IF;

  -- Bad evidence reference must be rejected.
  bad_ok:=false;
  BEGIN
    PERFORM public.aos_sentinel_ingest_signal_v1(jsonb_build_object(
      'event_id','sql-bad-001','signal_class','ERROR','environment','zero-cost','domain','EMAIL',
      'component','resend-gateway','capability','send-and-webhook-progression','failure_family','provider-stall',
      'signal_fingerprint','error:email:provider-stall','incident_fingerprint','zero-cost:email:resend-gateway:send-and-webhook-progression:provider-stall',
      'severity','P2','observed_at','2026-08-16T23:00:00Z',
      'evidence_refs',jsonb_build_array(jsonb_build_object('kind','sentry-issue','id','https://example.test/issue?token=bad'))
    ));
  EXCEPTION WHEN OTHERS THEN
    IF position('F8_EVIDENCE_INVALID' in SQLERRM)>0 THEN bad_ok:=true; ELSE RAISE; END IF;
  END;
  IF NOT bad_ok THEN RAISE EXCEPTION 'F8_DB_UNSAFE_EVIDENCE_ACCEPTED'; END IF;
END $$;

SELECT 'SENTINEL_F8_PERSISTENCE_BASE_FIXTURE=PASS' AS certificate;
