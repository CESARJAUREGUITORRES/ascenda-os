-- Sentinel F9 performance hotfix: cover digest incident foreign key.
-- Additive, no data rewrite, no PHI/PII.

begin;

create index if not exists aos_sentinel_alert_digest_items_v1_incident_idx
  on public.aos_sentinel_alert_digest_items_v1(incident_id);

commit;
