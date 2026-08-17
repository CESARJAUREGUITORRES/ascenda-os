# ASCENDA OS — Execution Control CURRENT

**Status:** CURRENT / cross-program continuity control  
**Baseline GitHub:** `main@d31722d9ac62770f3e7d5adfa72ee5de8937a3d0`  
**Captured:** 2026-08-17 · America/Lima  
**Precedence:** GitHub/docs canónicos → runtime/schema live → CI/sensor evidence → Notion visual.

> This document coordinates active workstreams. It does not replace each project's Control Maestro, phase Definition of Done, Impact Report, or production release gate.

## 1. Recovery correction

The previous K1-only continuation was insufficient because `main` advanced materially while K1 was being certified. The old K1 v4 branch is now diverged/stale and must not be merged or production-certified as-is.

The CURRENT system has concurrent work in Revenue F5, CIA F17 / WhatsApp, Sentinel F13, and KronIA K1. Migration-history parity is a shared blocker and must be handled as history/metadata reconciliation, never by blindly re-executing production DDL.

## 2. CURRENT program matrix

| Program | Technical state | Current gate | Rule |
|---|---|---|---|
| Revenue Data & Intelligence | F1–F4 closed; F5 active | Restore full 15,498-row staging/provenance → members → preview; no canonical apply before review | Do not infer completion from temporary transport tables |
| CIA V3 F17 multichannel | In progress | Signed Meta webhook/replay E2E + real allowlisted canary; repository migration parity | F16 remains certified; no SMS/broad-send expansion |
| WhatsApp Revenue Hub | S11 already integrated into CURRENT runtime; legacy WA tracker requires reconciliation | Preserve one WA/F17 transport and one canonical Audience/Identity truth | Do not build a duplicate channel stack |
| Sentinel | F12 closed; F13 active | Hub/System Map exact-head integration and final certification | Preserve zero-PHI/PII and human approval for remediation |
| KronIA V2 | K0 closed; K1 open | Rebuild K1 on CURRENT main after parity baseline; exact-SHA CRITICAL certificate | Reuse CIA F15 Tool/Agent Registry; no competing auth/session/tool registry |

## 3. Live facts that supersede stale checkpoints

### Revenue F5
Read-only production verification during this recovery found:
- staged historical rows: `1,000`;
- provisional clusters: `3,950`;
- cluster members: `0`;
- patient-link previews: `0`;
- canonical apply events: `0`.

PR #222 is merged and provides a safe recovery mechanism, but its contract explicitly does not itself certify provenance/preview/apply completion.

### CIA F17
`aos_cia_f18_readiness_v1()` remains fail-closed:
- true: `contracts_active`, `whatsapp_bridge_validated`, `outbound_policy_validated`, `rollback_verified`;
- false: `webhook_replay_validated`, `canary_passed`;
- `ready_for_f18=false`.

Issue #238 tracks repository ↔ production migration-history parity separately from F17 functional behavior.

### Sentinel
F12 was merged by PR #244 and subsequently closed at `100_COMPLETE` in GitHub. F13 is the active phase. Production already contains `sentinel_f13_owner_hub`, while the active F13 branch still requires exact migration-version reconciliation before final merge/certification.

## 4. Migration-history parity — P0 control-plane blocker

CURRENT `main` has green application/runtime checks and Railway deployment, but Supabase Preview is red with:

`Remote migration versions not found in local migrations directory.`

Observed concrete mismatch examples:
- F17 adapter: repository file `20260815223000_cia_phase17_whatsapp_adapter_contracts_v1.sql`; production ledger version `20260817183507`, same migration name/scope.
- Sentinel F13 active branch: repository file `20260817203500_sentinel_f13_owner_hub.sql`; production ledger version `20260817203504`, same migration name/scope.

Additional temporary F5 transport migrations were applied live after the CURRENT main commit and are being treated as an active concurrent workstream, not as candidates for blind history repair.

### Required parity method
1. Freeze a production migration-ledger snapshot (read-only).
2. Inventory every repository migration filename/version on CURRENT main + active release branches.
3. Map by migration name/content/checksum where possible.
4. Classify each delta as:
   - same DDL, different version → rename/reconcile history metadata;
   - production-only active work → wait for owning branch to materialize; do not repair under it;
   - repository-only unapplied migration → normal forward migration candidate;
   - ambiguous → blocked pending exact evidence.
5. Never re-run already-live DDL solely to satisfy Preview.
6. Re-run Supabase Preview and exact-head CI after reconciliation.
7. Close #238 only when remote/local history is reproducibly clean.

## 5. KronIA K1 reconstruction rule

Do **not** continue from stale K1 v4. Build a fresh K1 candidate from the CURRENT main only after the parity snapshot is stable.

Required runtime compatibility must be discovered from CURRENT code; prior certified topology is evidence, not an assumption. K1 must preserve all subsequently merged outer boundaries, including Sentinel/Phase S/F17/WhatsApp/F5/F4/Auth V3 as they exist at rebuild time.

K1 scope remains:
- server-authoritative Auth V3 identity/session;
- private secrets/credential boundary;
- PII-safe Team/browser projections;
- protected KronIA/Studio/email/admin control-plane endpoints;
- browser/Chrome canonical app token and no persistent sensitive history;
- fail-closed recovery, negative authorization tests and rollback;
- 0 unresolved HIGH/CRITICAL within K1 scope before release.

K1 must converge with existing CIA F15 Tool Registry / Agent Registry instead of introducing a second registry.

## 6. Execution order

### Loop A — Control + parity
1. Keep this CURRENT index synchronized with live evidence.
2. Reconcile #238 without schema/data re-execution.
3. Ensure active F5/F13 production-only migrations are represented by their owning branches using exact live versions.
4. Require Supabase Preview green on an exact CURRENT candidate.

### Loop B — KronIA K1
1. Fresh branch from CURRENT main.
2. Port only verified K1 hardening primitives.
3. Allocate migration versions strictly above the stable live/repo maximum with no collisions.
4. Re-run complete exact-SHA K1 CRITICAL certificate, CURRENT regressions and rollback.
5. Provider-side secret rotation/revocation evidence + real 2FA/email smoke remain release requirements.
6. Production cutover only after explicit CRITICAL release gate.

### Loop C — F17 / WhatsApp
1. Preserve F17 4/6 current gate state.
2. Obtain authentic Meta-signed webhook E2E + replay evidence.
3. Execute owner-authorized fixed allowlist canary only; no broad send.
4. Require `READY_F18_MULTICHANNEL_CERTIFIED` / `ready_for_f18=true` and clean exact-head repository health.
5. Reconcile WhatsApp phase tracker to the actual S-series/runtime work; do not duplicate F17 contracts.

### Loop D — Revenue F5
1. Complete private staging to 15,498 with exact file/row provenance.
2. Build identity members and conflict-safe preview.
3. Keep canonical mutation at zero until human review gate.
4. Reconcile product/cartera only after preview quality gates.

### Loop E — Sentinel F13
1. Sync F13 branch with CURRENT main.
2. Reconcile F13 migration filename/version to the already-live ledger entry before merge.
3. Run Hub/System Map DB/runtime/UI/security/recovery exact-head gates.
4. Merge only with no regression of F12 human-approval boundary.
5. Close Sentinel program only after post-merge certification + Notion finalization.

## 7. Non-negotiable anti-collision rules

- One canonical Auth V3 authority.
- One canonical Audience/Activation/Contact Identity truth.
- One provider-neutral F17 channel ledger; no duplicate WhatsApp truth.
- One CIA/KronIA Tool/Agent Registry lineage.
- No production DDL replay for migration-history cosmetics.
- No F5 canonical patient/sales mutation before reviewed preview.
- Sentinel remediation remains human-approved; no auto-merge/auto-deploy.
- Notion is updated last and must never overrule GitHub/runtime evidence.

## 8. Immediate checkpoint

**P0:** complete migration-history inventory/parity mapping (#238), while preserving active F5 and Sentinel F13 ownership.  
**Then:** rebuild KronIA K1 on the new clean CURRENT baseline and resume its exact-SHA CRITICAL closure loop.
