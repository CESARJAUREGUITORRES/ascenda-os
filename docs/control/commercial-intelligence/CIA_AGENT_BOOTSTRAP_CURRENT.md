# CIA V3 — Agent Bootstrap CURRENT

**Workstream:** Commercial Intelligence & Audience OS V3  
**Supabase production:** `ituyqwstonmhnfshnaqz`  
**GitHub repository:** `CESARJAUREGUITORRES/ascenda-os`  
**Revalidated:** 2026-08-17 America/Lima  
**Control issue:** #268

## 1. Read this before any CIA change

For CIA work, read in this order:

1. `AGENTS.md` for global ASCENDA safety rules.
2. this file.
3. `CIA_MASTER_ALIGNMENT_CURRENT.md`.
4. `CIA_EXECUTION_PLAYBOOK_V1.md`.
5. `ROADMAP_STATUS.md`.
6. the current phase Impact/Validation Report.
7. GitHub CURRENT `main` and active CIA PRs/checks.
8. production Supabase readiness RPCs.
9. Notion **Commercial Intelligence & Audience OS V3 — Control Maestro** and **Fases CIA V3**.

GitHub + Supabase live override stale documentation. Any discrepancy must be corrected before implementation continues.

## 2. Current authoritative state

Fresh production evidence on 2026-08-17:

- F0–F16: closed.
- F16 Email: `READY_F17_EMAIL_CERTIFIED`, `ready_for_f17=true`, all 7 release gates true, `illegal_send_states=0`, browser direct access false.
- F17 Multichannel: `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`, `ready_for_f18=false`.
- F17 gates true: `contracts_active`, `whatsapp_bridge_validated`, `outbound_policy_validated`, `rollback_verified`.
- F17 gates false: `webhook_replay_validated`, `canary_passed`.
- F18: not started; blocked by F17 readiness.

Current GitHub production baseline at this revalidation: `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073` (PR #265 merged).

## 3. Project boundaries — do not mix ownership

CIA V3 owns:

- contact commercial identity/facts used by audiences;
- segmentation and Audience Engine;
- snapshots/activation/context/availability;
- assignment/advisor work/request/approval;
- Commercial Intelligence shadow + governed orchestration integration;
- channel-governance contracts for Email/WhatsApp/SMS/future channels;
- attribution/learning/hardening in F18.

CIA V3 does **not** own these separate workstreams:

- **WhatsApp Hub / WA1–WA4 / Phase S UI:** transport, inbox, routing, boxes, human handoff and chat UX. CIA may consume its transport but must not redefine its product roadmap.
- **S14/S15/S15.2 notifications/Web Push:** notification product/runtime. Physical runtime may currently pass through `server-f17.js`, but notification requirements are not CIA F17 phase progress.
- **Revenue Data & Intelligence Core / F5 historical:** sales/patient historical consolidation and revenue provenance.
- **KronIA V2 K1:** identity/session/secrets hardening for KronIA.
- **Sentinel:** observability/security control plane. F18 may consume certified observability evidence, but Sentinel phase numbering is not CIA phase numbering.
- **Cartera/Sales Intelligence legacy project:** separate roadmap even when it shares tables/RPCs.

A cross-workstream dependency must be recorded as a dependency, not silently absorbed into the CIA phase.

## 4. Current runtime chain

The generic runtime paragraph in older `AGENTS.md` is historical for this CURRENT deployment. After PR #265, Railway production uses:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → core`

This physical chain does **not** merge the ownership of those projects. Treat each wrapper as a trust boundary.

## 5. Active F17 closeout blockers

Do not claim F17 100% while any of these remain:

1. `webhook_replay_validated=false` in production readiness.
2. `canary_passed=false` in production readiness.
3. issue #238 migration-history parity remains open; it is release-integrity debt for final F17 certification.
4. draft PR #261 is stale/unmergeable after #265 and must not be merged as-is. Reuse only verified CIA-only pieces on a fresh branch from CURRENT.
5. final exact-head CI/deploy/smoke/rollback evidence must be captured after the last CIA-only merge.

Issue #250 (blank-DB/pre-history baseline) is foundational repository debt and must remain separately tracked. It must not be disguised as an F17 functional failure.

## 6. Single-workstream release rule

While CIA F17/F18 is the active closeout lane:

- no unrelated HIGH/CRITICAL runtime or migration release may share the same certification window;
- the single self-hosted runner may queue other read-only/documentation work, but release certification is serialized;
- before every CIA merge, re-read CURRENT `main` and verify no unrelated runtime drift;
- after a CIA release candidate is frozen, unrelated production merges wait until CIA post-deploy smoke completes;
- queued/pending runner state is not a failure.

## 7. Next legitimate action

Create one fresh **CIA-only F17 closeout branch from CURRENT main**. Do not revive #261 wholesale. Port only the remaining verified CIA F17 pieces needed to prove signed webhook replay/idempotency and the fixed allowlist canary, reconcile #238 for the F17-owned migration slice, then require `aos_cia_f18_readiness_v1()` to return a certified READY status with `ready_for_f18=true` before opening F18.
