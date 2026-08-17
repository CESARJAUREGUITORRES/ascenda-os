# ASCENDA OS — MASTER CLOSEOUT LOOP CURRENT

**Status:** EXECUTABLE / fail-closed
**CURRENT baseline:** `main@fa2e8aecdc31fd7c3e420b60f6c4bfc1de39f521`
**Baseline release:** WA S14 — Web Push + notification standard
**Captured:** 2026-08-17 · America/Lima

## Goal
Close every active ASCENDA workstream with evidence, not percentages. A phase is `100_COMPLETE` only when its exact-head code, isolated tests, security boundary, rollback, production/live evidence where applicable, and control documentation are all reconciled.

## Global invariants
1. `main` is re-read before every merge/certification. If it moved, the candidate must be revalidated against CURRENT.
2. No production DDL is replayed only to repair migration history.
3. No phase can use a `SKIPPED` check as PASS.
4. No Revenue F5 canonical mutation before provenance + preview + human review.
5. No F17 broad send; webhook/canary remains allowlisted and fail-closed.
6. Sentinel remediation remains human-approved and zero-PHI/PII in owner topology.
7. KronIA K1 must be rebuilt from CURRENT; stale K1 v4 is never merged.
8. Notion is updated only after GitHub/runtime evidence is final.
9. DB-heavy gates on the shared Zero-Cost runner run serially; fast/static gates may run in parallel on compatible runners.
10. Every merge uses exact expected HEAD SHA and is followed by a post-merge main verification.

---

# LOOP 0 — FREEZE CURRENT

### Actions
- Read `main` HEAD and release message.
- Read open control/parity PRs and active phase branches.
- Read production migration-ledger checkpoint read-only.
- Mark any branch behind CURRENT as `REVALIDATE_REQUIRED`.

### Exit gate
`CURRENT_SHA_FROZEN=PASS`

Any movement of `main` invalidates only the pending candidate certificate; it does not undo already-proven local facts such as byte-identical SQL hashes.

---

# LOOP 1 — P0 MIGRATION PARITY / F16 SAFE SLICE (#238 / PR #248)

### Current work
- Six F16 migrations have content-identical production statements but version drift.
- PR #248 aligns those six filenames.
- Canonical F16 CI references must use the new production versions; otherwise the rename is incomplete.

### Required gates
1. Update all canonical F16 workflow/file references to the six production versions.
2. Run Ascenda CI against CURRENT merge-ref.
3. Run `ASCENDA CIA Phase 16 Email Contracts` against CURRENT merge-ref.
4. Run `ASCENDA F16 Resend Outcomes V3` against CURRENT merge-ref.
5. Require synthetic DB compile, lint, positive/negative contracts, server-authoritative boundary, ACL assertions, rollback and zero residue.
6. Confirm PR mergeability against CURRENT.
7. Merge only with exact HEAD SHA.
8. Post-merge: re-read `main`, rerun migration duplicate/version audit and confirm no SQL-content mutation occurred.

### Exit gates
- `F16_PARITY_SLICE=PASS`
- `DUPLICATE_LOCAL_MIGRATION_VERSION=0`
- `F16_SQL_CONTENT_CHANGED=0`
- `POST_MERGE_MAIN_HEALTH=PASS`

### Blockers
Any contract failure, missing filename, new migration collision, or CURRENT drift blocks merge.

---

# LOOP 2 — SENTINEL F13 CURRENT CLOSURE

### Required actions
1. Merge exact CURRENT `main` into the F13 integration candidate.
2. Reconcile `20260817203500_sentinel_f13_owner_hub.sql` to live ledger version `20260817203504` inside the F13 owner branch.
3. Update all F13 workflow/test references to `203504`.
4. Run syntax checks.
5. Run Hub contract.
6. Run resilience contract.
7. Run UI/Auth/2FA/privacy contract.
8. Enforce no browser service-role/token leak and no sensitive topology internals.
9. Compile migration in isolated DB.
10. Verify ACL, canary, rollback and reapply.
11. Verify zero duplicate migration versions.
12. Open/refresh F13 PR against CURRENT.
13. Merge exact HEAD only after all gates green.
14. Post-merge certify F12 human-approval boundary remains intact.

### Exit gates
- `SENTINEL_F13_CURRENT_ANCESTRY=PASS`
- `SENTINEL_F13_AUTH_2FA_BOUNDARY=PASS`
- `SENTINEL_F13_UI_PRIVACY=PASS`
- `SENTINEL_F13_READ_ONLY_RPC=PASS`
- `SENTINEL_F13_DB_ROLLBACK_REAPPLY=PASS`
- `SENTINEL_F13=100_COMPLETE`

---

# LOOP 3 — CIA F17 / WHATSAPP FUNCTIONAL CLOSURE

### Preserved state
F17 must remain fail-closed until all six readiness gates are true.

### Required actions
1. Reconcile F17 migration history semantically; do not blindly replay obsolete intermediate DDL.
2. Preserve the canonical provider-neutral WhatsApp/F17 ledger and current WA S-series runtime through S14.
3. Prove final F17 durable functions and ACLs against production semantics.
4. Represent superseded intermediate production entries only as explicit safe historical records/tombstones after equivalence and secret scan.
5. Execute authentic Meta-signed webhook E2E.
6. Execute replay/idempotency/duplicate-event evidence.
7. Execute owner-approved fixed allowlist canary only.
8. Verify rollback.
9. Re-read readiness RPC.

### Exit gates
All must be true:
- `contracts_active`
- `whatsapp_bridge_validated`
- `outbound_policy_validated`
- `rollback_verified`
- `webhook_replay_validated`
- `canary_passed`
- `ready_for_f18=true`
- `READY_F18_MULTICHANNEL_CERTIFIED`

Only then may F18 start.

---

# LOOP 4 — REVENUE F5 RECOVERY / PROVENANCE / PREVIEW

### Safety invariant
Canonical patient/sales mutation remains `0` until the human review gate.

### Required actions
1. Restore complete expected historical staging set with exact source/file/row provenance.
2. Reconcile temporary/private transports under F5 ownership; do not generic-history-repair them.
3. Build deterministic identity members.
4. Separate true identity links, conflicts and false positives.
5. Generate patient-link/reconciliation preview.
6. Produce quantitative quality report and conflict samples.
7. Human review/approval gate.
8. Only after approval: bounded canonical apply with rollback ledger.
9. Verify totals, idempotency and no unintended sales/patient mutation.

### Exit gates before apply
- `F5_PROVENANCE_COMPLETE=PASS`
- `F5_IDENTITY_MEMBERS=PASS`
- `F5_PREVIEW=PASS`
- `F5_HUMAN_REVIEW=APPROVED`

### Exit gates after controlled apply
- `F5_APPLY_IDEMPOTENT=PASS`
- `F5_ROLLBACK=PASS`
- `F5_RECONCILIATION=100_COMPLETE`

---

# LOOP 5 — KRONIA K1 REBUILD ON CURRENT

### Entry gate
Loops 1 and 2 must be closed; migration baseline must be stable enough that K1 does not branch from known parity debt. F17/F5 boundaries must be incorporated as CURRENT interfaces even if their independent external gates remain open.

### Required actions
1. Create a fresh K1 branch from CURRENT main. Never reuse stale K1 v4 as merge candidate.
2. Port only verified K1 hardening primitives.
3. Reuse canonical Auth V3.
4. Reuse CIA F15 Tool/Agent Registry lineage; no second registry.
5. Preserve F17/WA S14, Sentinel, Revenue F5/F4 and current runtime boundaries.
6. Allocate collision-free migration versions above CURRENT stable maximum.
7. Run authorization negative tests, secret boundary tests, PII-safe browser projections and recovery fail-closed tests.
8. Run rollback.
9. Run security diff/CRITICAL scan at exact candidate SHA.
10. Require 0 unresolved HIGH/CRITICAL in K1 scope.
11. Complete real 2FA/email smoke and provider-side secret rotation/revocation evidence where the release requires it.
12. Merge exact SHA and execute post-merge smoke.

### Exit gates
- `K1_CURRENT_COMPATIBILITY=PASS`
- `K1_SECURITY_HIGH_CRITICAL_OPEN=0`
- `K1_ROLLBACK=PASS`
- `K1_2FA_EMAIL_SMOKE=PASS`
- `K1_EXACT_SHA_CRITICAL_CERT=PASS`
- `KRONIA_K1=100_COMPLETE`

---

# LOOP 6 — FUNDATIONAL REBUILD BASELINE (#250)

This is separate from #238. Do not block safe parity slices on a fictional assumption that all historical ASCENDA migrations can rebuild a blank database today.

### Required outcome
Create a sanitized, schema-only reproducible ASCENDA baseline with no user data, PHI/PII, tokens, provider secrets or transient transport payloads; then prove clean rebuild + forward migrations in isolated infrastructure.

### Exit gates
- `ASCENDA_SCHEMA_BASELINE_SANITIZED=PASS`
- `BLANK_DB_REBUILD=PASS`
- `FORWARD_MIGRATION_REPLAY=PASS`

---

# LOOP 7 — FINAL CROSS-PROGRAM CERTIFICATION

For every phase marked 100%:
1. Capture final `main` SHA.
2. Capture relevant production/live checksum/read-only evidence.
3. Capture CI run IDs and conclusions.
4. Capture rollback proof.
5. Verify no open P0/P1 blocker belongs to that phase.
6. Update GitHub control/index.
7. Update Notion last.

### Global terminal gate
`ASCENDA_ACTIVE_PHASES_CERTIFIED_CURRENT=PASS`

This gate means the active roadmap is reconciled with the CURRENT system. It does not falsely mark future roadmap phases as complete before they are implemented.

---

## Execution queue at this baseline
1. **NOW:** #248 F16 parity slice — canonical references + three PR gates.
2. **NEXT on Zero-Cost runner:** Sentinel F13 CURRENT integration/certification.
3. **THEN:** remaining #238 history slices by ownership/evidence class.
4. **THEN:** F17 webhook/replay + real allowlist canary → F18 unlock.
5. **IN PARALLEL where independent:** Revenue F5 provenance/preview, with canonical mutation locked.
6. **AFTER stable CURRENT:** fresh KronIA K1 rebuild and CRITICAL certification.
7. **SEPARATE foundational work:** #250 reproducible schema baseline.
