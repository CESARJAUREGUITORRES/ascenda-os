-- Rollback for Sentinel F9 digest incident FK performance hotfix.

begin;

drop index if exists public.aos_sentinel_alert_digest_items_v1_incident_idx;

commit;
