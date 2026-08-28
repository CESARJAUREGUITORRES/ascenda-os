# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Captured:** 2026-08-28 America/Lima  
**Current functional main:** `99a2413a7fb13e5e18ec8f4b5e3ed0b49d159880`  
**ACTIVE PORTFOLIO OWNER:** `WHATSAPP-REVENUE-HUB-V2`  
**ACTIVE HIGH/CRITICAL GATE:** `WA-4B — SALES PLAYBOOK ENGINE`

## Current owner state
WhatsApp Revenue Hub V2 retains the sole HIGH/CRITICAL mutable lane.

`WA-7A.4 — Marketing Eligibility Foundation` remains `TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`.

`WA-4A / WA-4A.1 / WA-4A.1B / WA-4A.1C` are now certified at their demonstrated TEST-first boundaries. The next mutable gate is `WA-4B — Sales Playbook Engine`.

## Program map

| Program | Certified / preserved input | Remaining | Portfolio state |
|---|---|---|---|
| WhatsApp Revenue Hub V2 | WA-V2-0; WA-3/3.5 offline; WA-7A.0/1/2/3 closed; WA-7A.4 TEST-certified; WA-4A/4A.1/4A.1B/4A.1C TEST-certified | WA-4B/C, WA-5, WA-6, WA-7B/C/D, WA-8, WA-9..14 + queued PROD promotions | **ACTIVE / SOLE MUTABLE OWNER** |
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
Preserved separations:

`channel alias != canonical patient identity != acquisition touchpoint != marketing eligibility != knowledge evidence`.

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.

`ATTRIBUTION EVIDENCE != CONSENT`.

`LIVE PRICE AUTHORITY != DOCUMENT EXAMPLE PRICE`.

`COMMERCIAL PHASE != CLINICAL LIFECYCLE`.

`PROCESS TEMPLATE != PATIENT-SPECIFIC PRESCRIPTION`.

`ADVISOR RECOMMENDATION != AUTONOMOUS SEND`.

## WA-4A / Knowledge Fabric family
### WA-4A
Governed Knowledge Fabric established evidence-backed authority, provenance/freshness/conflict semantics and least-data behavior. Generic LLM knowledge remains non-authoritative.

### WA-4A.1
Zi Vital clinic knowledge is role-aware with public/advisor/owner/clinical boundaries. General business/clinical knowledge is governed instead of copied into prompts.

### WA-4A.1B
Commercial Knowledge Graph is certified over CURRENT 167 active services + 50 active products. It provides Domain / Approach / Commercial Phase / Clinical Lifecycle / Zi Vital-function semantics while preserving explicit clinical-evidence debt rather than inventing formulas.

### WA-4A.1C
PR #385 exact head `8354b65c5eaab022f7e4991e15ee48111205c799` passed dedicated Zero-Cost/DB/lint/rollback run `33140086173` plus Ascenda CI `33140086255`, then merged with `expected_head_sha` to `99a2413a7fb13e5e18ec8f4b5e3ed0b49d159880`.

Certified TEST architecture:
- 8 structural `STRUCTURAL_NOT_PRESCRIPTIVE` process templates;
- 8 non-auto-assignable process/component roles;
- 217/217 active catalog entities covered in isolated TEST context;
- live catalog price authority with stale/anomaly fail-closed state;
- topping authority separating paid add-ons from zero-price benefit candidates;
- private read-only quote preview;
- COMPLETE vs PROGRESSIVE preserves canonical scope/total;
- no patient/lead/sales/REV/catalog/quote/payment/plan mutation;
- rollback preserves canonical sources and WA-4A.1B.

Post-merge PROD readback remains intentionally unchanged: 167 services, 50 products, 20 toppings, 7 offer-above-base review rows, fingerprint `4f2bdff1a36dc1c621c237a8da655155`, and all WA-4A.1C feature DDL remains absent. Therefore WA-4A.1C is `TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`.

Railway is not part of this closeout because PR #385 does not alter Node/browser runtime; it contains migration/CI/control artifacts only.

## TEST-first operating model while PROD promotion remains deferred
New WhatsApp phases continue:

`discover → necessity gate → isolated TEST build → contract/security/regression tests → exact-head Zero-Cost CI → anti-drift → merge expected head → prove PROD unchanged where applicable → TEST certificate / PROD-ready queue → CURRENT → Notion LAST → next lock`.

Queued migrations/runtime packages are promoted later in certified order under a separate PROD recovery/promotion loop.

## WA-4B immediate execution
WA-4B owns the Sales Playbook Engine.

Necessity gate already established:
- existing Knowledge Fabric and WA-4A.1B already contain commercial rules and approved language;
- WA-4A.1C already contains structural process roles and governed price/preview contracts;
- therefore **no second sales-knowledge master or price/quote master is justified**.

WA-4B should build the minimum orchestration layer that turns governed evidence + conversation context into structured advisor guidance.

Expected advisor-only outputs may include:
- commercial stage/objective;
- recommended next action;
- approved talking points;
- objection-handling strategy;
- quote/payment framing when applicable;
- governed continuity/product/topping candidates when contextually eligible;
- clinical/policy escalation reason;
- evidence refs and freshness/conflict state;
- `send_authority = HUMAN_ONLY`.

Existing WA4/Copilot infrastructure remains SAFE-OFF. No autonomous AI send, campaign activation, auto-reply or auto-routing is authorized by this handoff.

## Global rule
At most one HIGH/CRITICAL feature/data workstream mutates shared CURRENT at a time. While WA-4B owns the lane, all other programs remain read-only/regression-only unless WA-4B requires a narrowly documented dependency.
