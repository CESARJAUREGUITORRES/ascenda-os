# ASCENDA OS — GOVERNANCE FINDINGS CURRENT

**Baseline:** `main@26171abe38bb4bb6f6364aff6624ddc3d0d39580`  
**Captured:** 2026-08-22 America/Lima  
**Scope:** global CURRENT governance + WhatsApp Revenue Hub V2 handoff

## Findings

| ID | Finding | Risk | State | Required action |
|---|---|---|---|---|
| GOV-01 | Bare `F#` names collide across CIA, Revenue and Sentinel. | HIGH | MITIGATED | Use `CIA-F*`, `REV-F*`, `SEN-F*`, `WA-*`, `K*`, `PARITY-*`. |
| GOV-02 | Multiple HIGH/CRITICAL projects can mutate shared CURRENT concurrently. | CRITICAL | MITIGATED BY LOCK | One global mutable owner in `ASCENDA_WORKSTREAM_LOCK_CURRENT.md`. |
| GOV-03 | Runtime docs can lag the actual Railway wrapper/preload topology. | HIGH | ACTIVE CONTROL | `app/railway.json` + exact deploy outrank prose; update CURRENT on each topology/preload change. |
| GOV-04 | Historical memory/agent docs can describe obsolete authority. | HIGH | MITIGATED | CURRENT overlays supersede historical snapshots. |
| GOV-05 | Stale branches/PRs can remain green against old runtime/schema. | HIGH | CONTROLLED | Rebuild/revalidate from exact CURRENT before merge. |
| GOV-06 | KronIA/CIA historical branches predate later wrappers/data contracts. | CRITICAL | PAUSED / EVIDENCE ONLY | Fresh work starts from then-CURRENT. |
| GOV-07 | Data-phase narrative can diverge from live persisted rows. | CRITICAL | MITIGATED | Persistence Triple-Proof + exact live readback. |
| GOV-08 | Separate project trackers can each appear ACTIVE. | HIGH | CONTROLLED | Global lock is authoritative across project-local trackers. |
| GOV-09 | Stale open PRs can look merge-ready. | MEDIUM | CONTROLLED | Explicitly classify/close superseded candidates. |
| GOV-10 | GitHub/runtime/Supabase/Notion can advance independently within minutes. | HIGH | CONTROLLED | exact-head + live revalidation; Notion last. |
| GOV-11 | Governance can fork through competing control writes. | HIGH | CONTROLLED | One control lane under the current owner. |
| GOV-12 | A previously certified subsystem may need regression checks after unrelated runtime changes. | HIGH | ACTIVE CONTROL | Certification is preserved, but current compatibility must be revalidated before dependent release. |
| GOV-13 | Branch protection/checks do not replace project ownership. | HIGH | OPEN | Global lock + expected-head merge + exact-head certification. |
| GOV-14 | Maintenance/parity lanes can be confused with feature phases. | HIGH | FIXED | Keep namespaces/states distinct. |
| GOV-15 | Tool/RPC success may not equal production persistence. | CRITICAL | MITIGATION ADOPTED | execution receipt + direct live readback + independent invariant. |
| GOV-16 | A persuasive 100% narrative can be false without authoritative post-conditions. | CRITICAL | INCIDENT LEARNING FROZEN | Certification is a property of exact GitHub/runtime/live DB/evidence, never narrative. |
| GOV-17 | CURRENT docs can remain bound to an older workstream after a handoff. | HIGH | WA-V2-0 RECONCILING | Reconcile all global CURRENT overlays when lock moves. |
| GOV-18 | `numero_limpio` is useful but can be mistaken for canonical identity. | HIGH | RULE FROZEN | Supporting bridge only; F5 governed canonical identity remains authority. |
| GOV-19 | Incomplete historical sales coverage can be interpreted as zero. | HIGH | CONTRACT FROZEN | Every revenue claim carries coverage/period; missing source != zero. |
| GOV-20 | Budget/payment/sale/balance concepts can collapse into one revenue meaning. | CRITICAL | RULE FROZEN | Preserve F4 transaction/payment/cartera semantics. |
| GOV-21 | A project may retain a terminal human-evidence gate while the owner explicitly reprioritizes another workstream. | HIGH | CONTROLLED BY PAUSE CHECKPOINT | Preserve exact recoverable checkpoint; PAUSED != CLOSED; move lock only by explicit owner directive. |
| GOV-22 | WhatsApp can build a second CRM now that richer patient/sales/email data exists. | CRITICAL | PROHIBITED | WA consumes F5/F6/CIA/Email/Agenda/Revenue contracts; no duplicate truth layer. |
| GOV-23 | Historical WhatsApp send success can be mistaken for current Meta credential readiness. | HIGH | OPEN GATE | Recertify current provider/WABA/token health and allowlisted outbound before production selling. |
| GOV-24 | Phone coincidence can falsely attribute WhatsApp revenue to Meta campaigns. | CRITICAL | PROHIBITED | Require explicit referral/touchpoint/ad lineage; phone-only attribution never authoritative. |
| GOV-25 | AI could answer from generic model knowledge instead of approved live business facts. | HIGH | V2 CONTROL | Knowledge Fabric authority + evidence refs; generic LLM knowledge last. |

## Current portfolio decision

Explicit owner directive on 2026-08-22 moves the mutable lane to:

`WHATSAPP-REVENUE-HUB-V2 / WA-V2-0`

Previous `MKT-INTEGRITY-HOTFIX-V3 / LOOP 6 V2.3` is **PAUSED / RECOVERABLE**, not closed. Fresh handoff readback found **0/5** qualifying genuine post-cutover operations, so no qualifying customer action was interrupted.

## Certified upstream truth now available to WhatsApp

Live entry snapshot:

- canonical patients = **7,702**;
- canonical sales = **1,331**;
- leads = **5,880**;
- F5 source rows = **15,498**;
- F5 identity memberships = **15,498**;
- F5 clusters/previews = **8,716 / 8,716**;
- CIA contact/email facts = **11,911**;
- canonical-linked CIA contacts = **7,083**.

Governance: WhatsApp integrates these sources. It does not recreate patient identity, sales, email, Agenda or acquisition truth.

## WhatsApp exact-current finding

Live revalidation at handoff:

- 15 canonical messages = 11 inbound / 4 outbound;
- 2 conversations;
- 25 events;
- 9 outbound requests;
- 11 routing events;
- 2 active boxes;
- 2 active memberships for the same current operational actor;
- 1 active assignment;
- 0 AI runs;
- human send ON;
- auto routing OFF;
- AI send OFF;
- Copilot OFF;
- auto reply OFF.

Notifications S13–S15.5 remain CLOSED / certified / regression-only.

Historical outbound results include 4 ACCEPTED, 4 `META_190` failures and 1 `META_SEND_REJECTED`; therefore current Meta provider readiness remains an explicit pre-selling gate.

Explicit campaign provenance is currently absent from all 15 WA messages (`campaign_source`, `ad_id`, `lead_id`, `raw_referral` = 0 populated). WA-7A owns this gap.

## Runtime governance

Exact entry main: `26171abe38bb4bb6f6364aff6624ddc3d0d39580`.

Railway exact commit status: SUCCESS.

Current start command is defined in `app/railway.json` and preloads Sentry plus backend-only email compatibility before `server-phase-s-f17.js`.

Effective chain:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`.

A runtime-chain/preload change is HIGH/CRITICAL and requires exact-chain regression evidence.

## Certification control

For every HIGH/CRITICAL phase:

`REVALIDATE → BUILD ISOLATED → EXACT-HEAD TEST → ANTI-DRIFT → MERGE EXPECTED HEAD → EXACT DEPLOY → LIVE READBACK → SECURITY/ROLLBACK/CANARY → CURRENT → aos_memory → Notion LAST`.

Never certify by percentage or historical green evidence.
