# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Captured:** 2026-08-27 America/Lima  
**Current main before closeout docs:** `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6`  
**ACTIVE PORTFOLIO OWNER:** `WHATSAPP-REVENUE-HUB-V2`  
**ACTIVE HIGH/CRITICAL GATE:** `WA-4A — KNOWLEDGE FABRIC`

## Current owner state

WhatsApp Revenue Hub V2 retains the sole HIGH/CRITICAL mutable lane.

`WA-7A.4 — Marketing Eligibility Foundation` is `TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`.

The next mutable gate is `WA-4A — Knowledge Fabric`.

## Program map

| Program | Certified / preserved input | Remaining | Portfolio state |
|---|---|---|---|
| WhatsApp Revenue Hub V2 | WA-V2-0, WA-3/3.5 offline, WA-7A.0/1/2/3 closed, WA-7A.4 TEST-certified | WA-4A/B/C, WA-5, WA-6, WA-7B/C/D, WA-8, WA-9..14 + queued PROD promotions | **ACTIVE / SOLE MUTABLE OWNER** |
| Revenue | REV-F1..F6 preserved/certified | REV-F7 and later | PAUSED / READ-ONLY while WA owns lock |
| MKT Integrity / Call Center | prior Loop 6 V2.3 checkpoint preserved | terminal genuine-op gate | PAUSED / RECOVERABLE |
| CIA / Email / Acquisition | certified facts/adapters; CIA-F17 recipient controls reused as WA dependency | later activation work | READ-ONLY DEPENDENCY SOURCE |
| Sentinel | observability/integrity foundation preserved | regression/deferred maintenance | REGRESSION-ONLY |
| KronIA | prior baseline preserved | later hardening | PAUSED |
| Migration governance | existing safe owner slices | parity/baseline maintenance | MAINTENANCE ONLY |

## Truth ownership

- F3 = product/catalog identity and facts;
- F4 = payment/revenue/cartera/reconciliation truth;
- F5 = patient identity + provenance;
- F6 = derived intelligence/read models;
- CIA = governed audience/channel/acquisition controls/facts;
- Email = governed email channel facts/events;
- WA = governed WhatsApp conversation/channel product;
- Sentinel = observation/integrity.

WA integrates these sources and must not duplicate them.

## WhatsApp foundation status

Preserved rules:

`channel alias != canonical patient identity != acquisition touchpoint != marketing eligibility != knowledge evidence`.

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.

`ATTRIBUTION EVIDENCE != CONSENT`.

WA-7A.4 exact TEST head `ac58ceced7b6d06bec1792bbb4aa27d97f8e3db3` passed dedicated Zero-Cost run `33103975948` and Ascenda CI `33103975951`, then PR #378 merged with expected head to `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6`.

Production was intentionally not mutated by WA-7A.4. Its migration/table/view are absent in PROD; the migration + rollback are queued for controlled promotion after Supabase renewal/recovery.

Current production preserved readback after merge:

- canonical patients = 7702;
- leads = 6061;
- WA messages = 21;
- WA conversations = 2;
- WA events = 39;
- real attribution touchpoints = 0.

Railway automatic deployment for the merge = SUCCESS. No WA-7A.4 app/runtime change was introduced.

## TEST-first operating model while Supabase PROD is constrained

Until production recovery/promotion is explicitly entered, new WhatsApp phases follow:

`discover → necessity gate → isolated TEST build → contract/security/regression tests → exact-head Zero-Cost CI → anti-drift → merge expected head → prove PROD unchanged → TEST certificate / PROD-ready queue → CURRENT → Notion LAST → next lock`.

Queued migrations/runtime packages are promoted later in certified order under a separate PROD recovery loop.

## WA-4A immediate execution

WA-4A owns governed Knowledge Fabric discovery/build.

It may read/reuse certified catalog, business rules, FAQ/protocol, CIA, Agenda, Revenue and other approved source contracts, but it must not create duplicate patient/product/revenue truth.

Knowledge authority must be evidence-backed and freshness-aware. Generic LLM knowledge is never authoritative over governed ASCENDA facts.

Existing WA4/Copilot infrastructure remains SAFE-OFF. No autonomous AI send, campaign activation, auto-reply or auto-routing is authorized by this handoff.

## Global rule

At most one HIGH/CRITICAL feature/data workstream mutates shared CURRENT at a time. While WA-4A owns the lane, all other programs remain read-only/regression-only unless WA-4A requires a narrowly documented dependency.
