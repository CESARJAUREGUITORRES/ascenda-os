-- Sentinel F8 Incident Engine rollback
-- Destructive by design: use only under approved rollback procedure.

begin;

revoke all on function public.aos_sentinel_get_incident_v1(text) from PUBLIC,anon,authenticated,service_role;
revoke all on function public.aos_sentinel_transition_incident_v1(text,text,timestamptz) from PUBLIC,anon,authenticated,service_role;
revoke all on function public.aos_sentinel_ingest_signal_v1(jsonb) from PUBLIC,anon,authenticated,service_role;

drop function if exists public.aos_sentinel_get_incident_v1(text);
drop function if exists public.aos_sentinel_transition_incident_v1(text,text,timestamptz);
drop function if exists public.aos_sentinel_ingest_signal_v1(jsonb);

drop table if exists public.aos_sentinel_incident_timeline_v1;
drop table if exists public.aos_sentinel_incident_signals_v1;
drop table if exists public.aos_sentinel_incidents_v1;
drop table if exists public.aos_sentinel_incident_counters_v1;

drop function if exists public.aos_sentinel_correlation_valid_v1(jsonb);
drop function if exists public.aos_sentinel_evidence_refs_valid_v1(jsonb);

commit;
