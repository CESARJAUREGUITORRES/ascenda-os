# ASCENDA OS — GOVERNANCE FINDINGS CURRENT

**Baseline:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Captured:** 2026-08-17 20:03 America/Lima  
**Scope:** control/read-only except metadata/docs reconciliation

## Findings

| ID | Finding | Risk | State | Required action |
|---|---|---|---|---|
| GOV-01 | Bare `F#` names collide across CIA, Revenue and Sentinel. | HIGH | MITIGATED | Use `CIA-F*`, `REV-F*`, `SEN-F*`, `WA-*`, `K*`, `PARITY-*`. |
| GOV-02 | Multiple HIGH/CRITICAL projects were able to launch work on shared CURRENT/runners concurrently. | CRITICAL | MITIGATED BY LOCK | One global mutable workstream in `ASCENDA_WORKSTREAM_LOCK_CURRENT.md`. |
| GOV-03 | Runtime docs/agents still described `node server.js` while S15.2 runs `server-phase-s-f17.js`. | HIGH | FIXED IN #267 | Root `AGENTS.md` + bootstrap now document actual wrapper chain. |
| GOV-04 | Historical `docs/MEMORY.md` / `docs/adn/AGENTS.md` describe GAS/Sheets generation and `aos_codigo_fuente` authority. | HIGH | MITIGATED | `MEMORY_CURRENT.md` + `AGENTS_CURRENT.md`; historical docs preserved as evidence only. |
| GOV-05 | PR #261 predates merged #265 and overlaps runtime-chain work already in CURRENT. | HIGH | PAUSED / DO NOT MERGE AS-IS | Rebuild remaining F17 scope from CURRENT when CIA lock begins. |
| GOV-06 | KronIA PR #175/#94 and prior K1 branches predate multiple runtime/schema wrappers. | CRITICAL | PAUSED / EVIDENCE_ONLY | Fresh K1 from CURRENT when KronIA receives lock. |
| GOV-07 | Revenue F5 Notion had both an old 15498/15498 claim and a later live correction. | HIGH | FIXED | Live state is 1000/15498, 3950 clusters, 0 members, 0 previews at this capture. |
| GOV-08 | WhatsApp tracker showed WA1 and WA4 simultaneously `En curso`. | HIGH | FIXED / PAUSED | Both paused by portfolio lock; when WA resumes, WA1 is revalidated/closed first. |
| GOV-09 | Multiple stale PRs remain open and appear merge-like despite being superseded. | MEDIUM | CLEANUP ACTIVE | Close only after owner/evidence classification; do not bulk-close unknown work. |
| GOV-10 | Runtime/Supabase/Notion can advance independently within minutes. | HIGH | CONTROLLED | exact-head + live-readiness before merge/certification; Notion last. |
| GOV-11 | During this audit another control PR (#267) and Sentinel maintenance PR (#271) were created concurrently, proving the governance layer itself could fork. | HIGH | CONTROLLED | Consolidate realignment into #267; keep Sentinel maintenance draft/paused until portfolio lock permits it or production-safety incident demands it. |
| GOV-12 | Sentinel F1–F13 is certified, but cross-workstream runtime changes can make old Sentinel regression assumptions stale. | MEDIUM | QUEUED MAINTENANCE | Regression findings may be recorded, but do not reopen Sentinel baseline or mutate runtime during another lock. |
| GOV-13 | Git branch protection/required checks are not a sufficient substitute for project ownership because multiple legitimate workflows share one repo. | HIGH | OPEN | After control PR merge, define branch-protection checks that complement, not replace, workstream lock. |
| GOV-14 | #238 parity and #250 blank-DB baseline were being treated like feature phases. | HIGH | FIXED | They are maintenance lanes; no parallel history rewrite while feature project owns lock. |

## Live CIA-F17 evidence

- status `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`
- ready_for_f18 = false
- true: contracts, WhatsApp bridge, outbound policy, rollback
- false: signed webhook replay/idempotency, real allowlisted canary
- illegal send states = 0
- browser direct governed-table access = false
- send requests/events/inbound ledgers = 0 at capture
- WA facts/messages = 11

Interpretation: #265/S15.2 fixed the runtime-chain bypass, but real governed F17 evidence has not yet completed the last 2 gates.

## Live REV-F5 evidence

- 1000/15498 source rows
- 3950 provisional clusters
- 0 members
- 0 previews
- 7675 canonical patients

Interpretation: F5 must not be run/rebuilt in parallel with CIA closeout and must not mutate canonical patients before review gate.

## Runner interpretation

Repository workflows expose at least:

- Linux `ascenda-zero-cost-v2` for DB/security/release validation;
- Windows `ascenda-fast` for selected runtime/UI contracts.

The coordination defect was not merely runner count; it was **ownership of shared mutable CURRENT**. The portfolio lock serializes HIGH/CRITICAL work even when multiple physical runners exist.

## Current control decision

- Active lock until this PR closes: `CONTROL-REALIGNMENT`.
- Next: `CIA-F17/F18-CLOSEOUT`.
- Revenue, WhatsApp and KronIA paused.
- Sentinel closed/regression-only; PR #271 is maintenance evidence, not permission for concurrent mutation.
