# ASCENDA OS — GOVERNANCE FINDINGS CURRENT

**Baseline audit:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Date:** 2026-08-17 America/Lima  
**Scope:** control / no production mutation

## Purpose

Record the cross-workstream drift discovered while revalidating ASCENDA so it is not rediscovered ad hoc by future chats/agents.

| ID | Finding | Risk | State | Required action |
|---|---|---|---|---|
| GOV-01 | Bare `F#` names are ambiguous across CIA, Revenue, Sentinel and other programs. | HIGH | MITIGATED in PR #267 | Always use namespace: CIA-F*, REV-F*, WA-*, SEN-F*, K1-*, PARITY-*. |
| GOV-02 | `main` is currently not branch-protected / no required status-check protection is exposed by the GitHub branch state. | HIGH | OPEN | After the active F17 closeout workflows are normalized, enable a deliberate branch-protection policy that does not deadlock Zero-Cost CI. |
| GOV-03 | Current `cia-phase17-closeout.yml` still targets an older branch/file/migration lineage. | HIGH | OPEN / CIA-F17 | Reconstruct the F17 exact-head workflow from CURRENT before certification. |
| GOV-04 | `cia-phase17-wa-adapter.yml` is an older materializer with `contents: write` and targets the prior `server-f4.js` adapter lineage. | HIGH | OPEN / CIA-F17 | Supersede or disable this lineage during CURRENT F17 reconstruction; no manual dispatch while ambiguous. |
| GOV-05 | PR #261 was based on pre-#265 CURRENT and overlaps runtime-chain work already merged by #265. | HIGH | CONTROLLED | Do not merge as-is; rebuild/rebase from CURRENT and retain only unresolved history/replay/canary/readiness scope. |
| GOV-06 | `AGENTS.md` contains a generic Node/Railway section that still describes `app/server.js` / `node server.js` as current outer runtime while S15.2 now starts `server-phase-s-f17.js`. | HIGH | MITIGATED, PATCH PENDING | `ASCENDA_AGENT_BOOTSTRAP_CURRENT.md` is the temporary CURRENT override. Patch AGENTS carefully after functional F17 lineage is stabilized. |
| GOV-07 | `aos_memory` CURRENT keys were stale (`F16 READY`, `F17 NOT_STARTED`, old PR #97 state). | MEDIUM | FIXED | CURRENT keys updated 2026-08-17; preserve dated historical records. |
| GOV-08 | WhatsApp Revenue Hub Notion tracker contains mixed-generation checkpoints (e.g. WA-1 not closed while downstream WA-2/WA-3 are closed, plus older zero-traffic snapshots). | MEDIUM | PAUSED | Revalidate WA project independently against CURRENT Git/runtime/Supabase after CIA-F17; do not infer percentages. |
| GOV-09 | Multiple old PRs remain open after their functional state was superseded/certified, creating navigation noise. | MEDIUM | OPEN | Archive/classify stale PRs owner-by-owner after F17; do not bulk-close without verifying retained evidence/dependencies. |
| GOV-10 | Runtime/Supabase/Notion can advance independently, so a checkpoint may be correct when written but stale minutes later. | HIGH | CONTROLLED | Exact-head + live-readiness revalidation before merge/certification and Notion-last update rule. |

## CIA-F17 live evidence at this audit

Authoritative readiness remains 4/6:

- `contracts_active=true`
- `whatsapp_bridge_validated=true`
- `outbound_policy_validated=true`
- `rollback_verified=true`
- `webhook_replay_validated=false`
- `canary_passed=false`
- `ready_for_f18=false`

Live F17 storage at the checkpoint:

- `aos_cia_channel_recipient_controls_v1`: 0 rows
- `aos_cia_channel_send_requests_v1`: 0 rows
- `aos_cia_channel_send_events_v1`: 0 rows
- `aos_cia_channel_inbound_facts_v1`: 0 rows
- `aos_cia_whatsapp_bridge_v1`: 11 rows

Interpretation: S15.2 fixed the production chain, but the final governed real webhook replay/canary evidence has not yet occurred through the F17 ledgers. Do not set the readiness flags manually.

## Runner interpretation

Repository policy confirms two execution classes in code:

- Linux `ascenda-zero-cost-v2` for DB/security/release validation;
- Windows `ascenda-fast` for selected runtime/UI/materialization contracts.

The control problem is not that runners are shared; it is allowing two HIGH/CRITICAL workstreams to mutate the same CURRENT concurrently. The exclusive mutation lock is the required coordination layer.

The connected GitHub interface used for this audit does not expose a reliable live enumeration of physical self-hosted runners, so online runner count must not be inferred from workflow labels alone.
