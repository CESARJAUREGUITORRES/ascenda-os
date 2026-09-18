-- ASCENDA OS · Call Center Hopper F1
-- Purpose: optimize the already-existing CIA Assignment engine as the Call Center hopper.
-- No routing behavior changes. No new queue table. No production activation.
-- Architecture mapping:
--   Audience -> List/Segment
--   Activation -> Campaign/Snapshot
--   aos_cia_assignments -> Hopper/Work queue
--   Advisor Work -> Agent claim/lease
--
-- The hot claim path in aos_cia_call_routing_try_v3_v1 filters by advisor/state,
-- excludes expired work, and orders by deadline/rank/age. This partial covering
-- index makes that path deterministic and cheap when V3 is enabled after canary.

create index if not exists idx_cia_assignments_claim_hotpath_v1
on public.aos_cia_assignments (
  advisor_user_id,
  state,
  must_start_before,
  source_rank,
  assigned_at,
  id
)
include (
  plan_id,
  activation_id,
  contact_key,
  expires_at
)
where state in ('ASSIGNED','IN_PROGRESS');

comment on index public.idx_cia_assignments_claim_hotpath_v1 is
'CC-HOPPER-F1: covering index for governed advisor assignment claim; no routing mutation';
