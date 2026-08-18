# CIA V3 — Execution Playbook V1

**Status:** CURRENT  
**Workstream:** Commercial Intelligence & Audience OS V3  
**Revalidated:** 2026-08-17 America/Lima  
**Control issue:** #268

## Purpose

This playbook prevents cross-project drift while CIA V3 is being certified inside the shared ASCENDA repository and runtime. It does not grant production authorization by itself.

## A. Universal recovery loop

Before every CIA implementation or resume:

1. Read `AGENTS.md`.
2. Read `CIA_AGENT_BOOTSTRAP_CURRENT.md` and `CIA_MASTER_ALIGNMENT_CURRENT.md`.
3. Fetch CURRENT `main`; never reuse an old SHA from chat memory.
4. Query production Supabase readiness for the current input/output handshake.
5. Read the active CIA phase in Notion and compare it with GitHub/Supabase.
6. Inventory open CIA issues/PRs and classify each as CURRENT, stale, superseded or separate-workstream.
7. Stop if control sources disagree; synchronize them before code changes.
8. Create a fresh branch from CURRENT for the smallest owned scope.

## B. Single-workstream release lane

ASCENDA may have many projects under development, but only one HIGH/CRITICAL production certification lane is active at a time.

During a CIA release freeze:

- CIA owns the release lane until its exact-head post-deploy smoke completes.
- Unrelated HIGH/CRITICAL runtime, migration, Auth, RLS, secret or infrastructure merges wait.
- Other projects may continue read-only research, documentation and isolated development branches.
- A queued self-hosted job is not a product failure.
- Do not bypass the self-hosted lane with paid hosted runners to gain speed.
- If CURRENT `main` changes after a release branch is certified, the certification is stale until equivalence is re-proven or the branch is rebuilt from CURRENT.

The physical runner can be shared; the **release authority cannot be shared concurrently**.

## C. Workstream ownership test

Before editing a shared runtime file, answer all four:

1. Which product/workstream owns the behavior?
2. Which other workstreams physically traverse the file?
3. Does this change alter their contracts or only insert a dependency boundary?
4. Which project records the phase progress?

Physical runtime proximity is not phase ownership.

Examples:

- CIA F17 owns governed multichannel policy/ledger/readiness.
- WhatsApp Hub owns inbox/routing/boxes/handoff/chat UX.
- S14/S15 owns Web Push and notification inbox/pump.
- Sentinel owns observability/control-plane certification.
- Revenue F5 owns historical sales/patient consolidation.

A change may need a shared wrapper but must be counted only in the owning roadmap.

## D. HIGH/CRITICAL implementation loop

1. Recovery + fresh baseline.
2. Input readiness handshake PASS.
3. Impact Report before implementation.
4. Closed scope and explicit anti-scope.
5. Fresh isolated branch from CURRENT.
6. Versioned/replayable migration for DDL.
7. Deterministic implementation with fail-closed guards.
8. Unit/contracts/static security.
9. Zero-Cost ephemeral DB/runtime tests.
10. ACL/RLS/role negative tests.
11. Performance/write-path regression where applicable.
12. Rollback/recovery proof and zero residue.
13. Re-fetch CURRENT before opening/finalizing PR.
14. Exact-head CI. No weakening tests to turn a gate green.
15. Freeze unrelated HIGH/CRITICAL merges.
16. Production read-only preflight.
17. Controlled canary/additive rollout.
18. Production smoke and reconciliation.
19. Readiness/output handshake to next phase.
20. Update GitHub validation/control docs.
21. Update `aos_memory`.
22. Update Notion last.
23. Release the workstream freeze.

## E. F17 CURRENT closeout loop

Fresh production state at this playbook revision: F17 has 4/6 release gates.

Already true:

- `contracts_active`
- `whatsapp_bridge_validated`
- `outbound_policy_validated`
- `rollback_verified`

Still false:

- `webhook_replay_validated`
- `canary_passed`

Required sequence:

1. Start a fresh CIA-only F17 closeout branch from CURRENT `main`.
2. Do not merge PR #261 wholesale; it is stale and overlaps S15/runtime work already superseded by #265.
3. Reuse only CIA-owned, independently verified replay/canary/history pieces.
4. Prove the signed Meta webhook reaches the F17 boundary only after the inner signature acceptance.
5. Replay the same provider event and prove idempotency/no duplicate side effects.
6. Execute exactly one allowlist canary; no broad-send activation.
7. Verify the F17 ledger links policy → dispatch → provider event/inbound as intended without generic message-body persistence.
8. Reconcile the F17-owned slice of migration-history parity tracked in #238 without replaying live historical DDL merely to repair metadata.
9. Run exact-head Zero-Cost + runtime chain + rollback/recovery.
10. Deploy only the CIA-owned delta and run post-deploy smoke.
11. Query `aos_cia_f18_readiness_v1()` fresh. F17 closes only if its certified READY status and `ready_for_f18=true` are authoritative.
12. Close the F17 validation issue/PR and synchronize memory/Notion.

## F. #238 versus #250

Do not conflate these problems:

- **#238 migration-history parity:** remote/local migration identity/content reconciliation. It is a release-integrity concern for F17 closeout. Repair history metadata safely; never blindly re-run production DDL.
- **#250 blank-DB baseline:** ASCENDA predates the tracked migration chain, so a totally empty database cannot currently rebuild the entire historical system. This is a separate foundational program and must be solved with a schema-only, data-free, secret-free baseline strategy.

#250 is not evidence that CIA F17 policy/webhook/canary functionality failed.

## G. Phase-completion semantics

Never collapse these states:

- `ZERO-COST CERTIFIED`: isolated tests/rollback pass.
- `CANARY CERTIFIED`: minimal real integration pass.
- `PRODUCTION CERTIFIED`: deployed release + smoke + reconciliation pass.
- `100_COMPLETE`: every declared gate, next-phase handshake, documentation, memory and Notion synchronized.

## H. F18 entry rule

F18 remains blocked until F17 returns `ready_for_f18=true`. Once unlocked, F18 owns CIA-wide attribution/outcomes, learning feedback, resiliency/jobs, security hardening, observability integration, documentation and final end-to-end certification. It must not absorb unfinished work from other ASCENDA roadmaps merely because those systems share runtime or data.
