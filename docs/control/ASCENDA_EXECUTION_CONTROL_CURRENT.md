# ASCENDA OS — Execution Control CURRENT

**Status:** CURRENT / cross-program continuity control
**Baseline GitHub:** `main@f676208d7b64f3f3c02fc71d0e227d6b1b0655c8`
**Captured/refreshed:** 2026-08-17 · America/Lima
**Precedence:** GitHub/docs canónicos → runtime/schema live → CI/sensor evidence → Notion visual.

> This document coordinates active workstreams. It does not replace each project's Control Maestro, phase Definition of Done, Impact Report, or production release gate.

## 1. Recovery correction

The previous K1-only continuation was insufficient because `main` advanced materially while K1 was being certified. The old K1 v4 branch is diverged/stale and must not be merged or production-certified as-is.

The CURRENT system has concurrent work in Revenue F5, CIA F17 / WhatsApp, Sentinel F13, and KronIA K1. Migration-history parity is a shared blocker and must be handled as history/metadata reconciliation, never by blindly re-executing production DDL.

## 2. CURRENT program matrix

| Program | Technical state | Current gate | Rule |
|---|---|---|---|
| Revenue Data & Intelligence | F1–F4 closed; F5 active | Restore full 15,498-row staging/provenance → members → preview; no canonical apply before review | Do not infer completion from temporary transport tables |
| CIA V3 F17 multichannel | In progress, 4/6 readiness gates | Signed Meta webhook/replay E2E + real allowlisted canary; repository migration parity | F16 remains certified; no SMS/broad-send expansion |
| WhatsApp Revenue Hub | S12 integrated into CURRENT runtime; legacy WA tracker requires reconciliation | Preserve one WA/F17 transport and one canonical Audience/Identity truth | Do not build a duplicate channel stack |
| Sentinel | F12 closed; F13 active | Hub/System Map exact-head integration and final certification | Preserve zero-PHI/PII and human approval for remediation |
| KronIA V2 | K0 closed; K1 open | Rebuild K1 on CURRENT main after parity baseline; exact-SHA CRITICAL certificate | Reuse CIA F15 Tool/Agent Registry; no competing auth/session/tool registry |

## 3. Live facts that supersede stale checkpoints

### Revenue F5
Read-only production verification during this recovery found:
- staged historical rows: `1,000`;
- provisional clusters: `3,950`;
- cluster members: `0`;
- patient-link previews: `0`;
- canonical apply events: `0`;
- canonical patients observed at checkpoint: `7,672`.

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

The strong read-only content-hash audit freezes the recent production ledger (`>=20260815000000`) and compares each live `schema_migrations.statements` MD5 against the full local migration history.

Current audit result:
- remote rows: `58`;
- `EXACT_CONTENT`: `0`;
- `CONTENT_EXACT_VERSION_DRIFT`: `6`;
- `NAME_MATCH_CONTENT_MISMATCH`: `23`;
- `REMOTE_ONLY`: `29`;
- `LOCAL_ONLY`: `22`;
- `DUPLICATE_LOCAL_VERSION`: `2` before the first safe repair slice;
- no ambiguous content matches and no unsupported statement counts.

PR #248 is the first safe repair slice: six F16 files whose live statement MD5 equals the local file MD5 are renamed to the exact production versions with zero SQL-content changes. That set also removes the two duplicate local timestamps. It remains fail-closed pending the broader history plan and exact-head checks.

Observed non-trivial mismatch examples:
- F17 final adapter: repository `20260815223000_cia_phase17_whatsapp_adapter_contracts_v1.sql`; production ledger `20260817183507`. Whole-file and whitespace/comment-normalized hashes differ, so timestamp-only rename is forbidden until semantic equivalence is proven.
- Sentinel F13: repository branch file `20260817203500_sentinel_f13_owner_hub.sql`; production ledger `20260817203504`; this stays owned by the active F13 branch.
- Current F5 transport `20260817211133_f5_chat_gzip_bundle_tmp_20260817` is production-only active work and must not be generic history-repaired.

### Supabase Preview correction
Per-PR Supabase Preview branches are currently disabled in the GitHub integration. On PR #248 the Supabase Preview check is `SKIPPED`, not PASS and not a migration-error signal. Therefore parity closure must use deterministic content audit + clean local replay/current-main gates, unless preview branching is deliberately re-enabled later.

### Required parity method
1. Freeze a production migration-ledger snapshot (read-only).
2. Inventory repository migration filename/version/content on CURRENT main + active release branches.
3. Map by exact version, migration name and statement-content hash.
4. Classify each delta as:
   - content-identical, version-only drift → safe filename/version repair after ownership check;
   - same-name/content-mismatch → semantic/replay analysis; no automatic repair;
   - production-only active work → wait for owning branch; do not repair under it;
   - production-only superseded/transient history → candidate explicit historical tombstone only after durable-state proof and secret scan;
   - repository-only unapplied migration → forward/stale classification;
   - ambiguous → blocked pending exact evidence.
5. Never re-run already-live DDL solely to satisfy migration history.
6. Never commit ephemeral credentials/payload transport from live statements into Git.
7. Require a clean local migration replay and exact-head CI before closing #238.
8. A skipped Supabase Preview can never count as PASS.

## 5. KronIA K1 reconstruction rule

Do **not** continue from stale K1 v4. Build a fresh K1 candidate from the CURRENT main only after the parity baseline is stable.

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
2. Finish #238 by evidence class, not bulk timestamp repair.
3. Keep active F5/F13 production-only migrations with their owning workstreams.
4. Validate every accepted history repair through deterministic audit + clean local replay + exact-head CI.
5. Merge only coherent repair slices with zero unclassified side effects.

### Loop B — KronIA K1
1. Fresh branch from CURRENT main.
2. Port only verified K1 hardening primitives.
3. Allocate migration versions strictly above the stable live/repo maximum with no collisions.
4. Re-run complete exact-SHA K1 CRITICAL certificate, CURRENT regressions and rollback.
5. Provider-side secret rotation/revocation evidence + real 2FA/email smoke remain release requirements.
6. Production cutover only after explicit CRITICAL release gate.

### Loop C — F17 / WhatsApp
1. Preserve F17 4/6 current gate state.
2. Complete semantic/history reconciliation of the F17 migration family without replaying obsolete intermediate DDL.
3. Obtain authentic Meta-signed webhook E2E + replay evidence.
4. Execute owner-authorized fixed allowlist canary only; no broad send.
5. Require `READY_F18_MULTICHANNEL_CERTIFIED` / `ready_for_f18=true` and clean exact-head repository health.
6. Reconcile the legacy WhatsApp tracker to the actual S-series through S12; do not duplicate F17 contracts.

### Loop D — Revenue F5
1. Complete private staging to 15,498 with exact file/row provenance.
2. Build identity members and conflict-safe preview.
3. Keep canonical mutation at zero until human review gate.
4. Reconcile product/cartera only after preview quality gates.

### Loop E — Sentinel F13
1. Sync F13 branch with CURRENT main.
2. Reconcile F13 migration filename/version to the already-live ledger entry within the F13 owner branch.
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
- No live transport credentials or payloads copied into repository history.
- Sentinel remediation remains human-approved; no auto-merge/auto-deploy.
- Notion is updated last and must never overrule GitHub/runtime evidence.

## 8. Immediate checkpoint

**P0:** finish migration-history classification/repair (#238) in coherent slices, while preserving active F5 and Sentinel F13 ownership.

**Then:** rebuild KronIA K1 on the new clean CURRENT baseline and resume its exact-SHA CRITICAL closure loop. F17 real webhook/canary, Revenue F5 provenance/preview and Sentinel F13 exact-head closure continue as independent guarded workstreams.
