# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-09-03 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Canonical main at capture:** `bab9f0865f779217aadc7c88af4ebf0e1fb0b3ee`  
**L1-L9:** `CLOSED / CERTIFIED AT THEIR DEMONSTRATED BOUNDARIES`  
**WA-L9:** `AUTONOMOUS DEMO READY · PROD CERTIFIED · DORMANT SAFE-OFF`  
**ACTIVE HIGH/CRITICAL LOCK:** `NONE`  
**NEXT ELIGIBLE:** `WA-L10 — AUTONOMOUS PRODUCTION CANARY · NOT STARTED`  
**CANARY:** `NOT AUTHORIZED · SEPARATE EXPLICIT OWNER GATE`  
**FINAL AUTONOMY BOUNDARY:** `WA-L11 — GENERAL PRODUCTION`  
**POST-L11:** `CUSTOMER EXPERIENCE & CONVERSATION VALIDATION`

## North Star

`Meta Ads / CTWA / Business Username / Organic / QR / Web -> WhatsApp -> acquisition context -> governed channel/canonical identity -> consent/security preflight -> natural business conversation -> governed facts/pricing -> real availability -> BOOK/REBOOK -> confirmation/follow-up/handoff -> attendance -> sale -> strong-key attribution -> provider/AI cost -> learning and customer-experience improvement`.

The target is a governed autonomous Revenue Agent, not a generic chatbot and not a replacement CRM.

## Authority / architecture rules

- Canonical patient identity stays in the governed patient/REV identity stack.
- WA channel aliases do not become a second person master.
- Marketing Attribution V2 remains authoritative for marketing attribution.
- Acquisition evidence, consent, identity and reachability are separate concerns.
- Catalog/runtime price authority outranks document examples and LLM memory.
- No clinical necessity, diagnosis or treatment prescription may be inferred autonomously from commercial categories.
- Booking/rebooking must use real governed availability and explicit confirmation.
- REBOOK continuity must preserve the canonical appointment contract.
- WhatsApp/AI costs use provider/rate evidence and effective-dated authority; never fabricate invoice truth.
- Human escalation remains a first-class path.
- `AUTO_OFF -> CANARY` and `CANARY -> PROD` are separate evidence/owner gates.
- Direct `AUTO_OFF -> PROD` is structurally forbidden by L4 authority.
- P0 #432 reliability doctrine applies to every remaining phase.

## Current phase graph

`WA foundation / identity / eligibility / knowledge / playbook / Copilot / booking prerequisites ✅`

`WA-L1 ✅ -> WA-L2 ✅ -> WA-L3 ✅ -> WA-L4 ✅ -> WA-L5 ✅ -> WA-L6 ✅ -> WA-L7 ✅ -> WA-L8 ✅ -> WA-L9 ✅ -> WA-L10 NEXT -> WA-L11 BLOCKED -> POST-L11 CX/CONVERSATION VALIDATION`.

Older WA-3 / WA-4A / WA-4B / WA-4C / WA-7A.x labels remain historical implementation ancestry. They do not override the current L1-L11 closeout graph.

## Closed autonomy path

### WA-L1 — Unified BOOK/REBOOK foundation

Closed. Governed booking/rebooking contract and canonical availability/identity dependencies established.

### WA-L2 — Operational continuity / dependent wiring

Closed at certified boundary. Reuses existing WA operational foundations without creating a parallel booking/CRM truth.

### WA-L3 — Production-safe dependent layer

Closed and dormant under SAFE-OFF. Its security/performance regressions remain mandatory dependencies.

### WA-L4 — Autonomous Authority + Kill Switch

Production-certified authority layer:

- `AUTO_OFF | CANARY | PROD`;
- global kill switch;
- explicit allowlist;
- daily/rate/max-turn/cooldown/duplicate controls;
- template/provider verification;
- identity/safety/handoff gates;
- append-only audit and idempotency.

Transition invariant: CANARY requires active allowlist; PROD requires prior CANARY. No direct AUTO_OFF->PROD.

### WA-L5 — Conversational BOOK/REBOOK Wiring

Production-certified. Conversation can progress through booking readiness, sede/date/real slot, explicit confirmation and BOOK/REBOOK using governed authority. No invented provider/slot/appointment state.

### WA-L6 — Meta Campaign Context & Attribution

Production-certified. Strong-key chain:

`provider touchpoint -> conversation_id -> BOOK/REBOOK -> appointment_id -> attendance -> explicit venta_id_match -> canonical venta_id`.

No revenue attribution by phone/name/username/BSUID alone.

### WA-L7 — WhatsApp / AI Cost Intelligence

Production-certified, scoped and cold-path oriented. Effective-dated pricing authority, provider billability evidence, AI token cost and journey cost remain fail-closed when rate/currency evidence is incomplete.

### WA-L8 — Security Gate + Meta 2026 Hardening

Production-certified under SAFE-OFF:

- `pricing.type` persistence;
- recipient-market-aware pricing;
- per-business-phone/category billing observability;
- consent/opt-in/opt-out/STOP evidence;
- business-initiation preflight;
- signed webhook/idempotency/secrets boundaries;
- PII/PHI minimization;
- service-role/least-privilege controls;
- P0 #432/cross-module regressions.

No unverified future Meta rate was seeded as VERIFIED authority.

### WA-L9 — AUTONOMOUS DEMO READY

**CLOSED · PRODUCTION CERTIFIED · DORMANT SAFE-OFF.**

Evidence:

- issue #453 CLOSED/completed;
- exact-head `b0a65d5b340896263a3f75cb66ab7850fdb3c5fa`;
- exact-head Ascenda CI SUCCESS;
- dedicated WA-L9 workflow SUCCESS across static/privacy, canonical WA-4C beta and CURRENT L5-L9/P0/parity;
- PR #454 merged using `expected_head_sha`;
- merge/deploy `f909e972aab243af954fc8e2fb15e5a37c68d1b6`;
- Railway exact-merge SUCCESS;
- Supabase PROD `20260903225152 · wa_l9_shadow_demo_v1`;
- L9 shadow uses exact L4+L8 authority in rollback-only execution;
- provider dispatch structurally false;
- raw content structurally not stored;
- demo runs=0, would-send=0, provider dispatch=0 after PROD deployment;
- autonomous outbound=0;
- final governance `main@bab9f0865f779217aadc7c88af4ebf0e1fb0b3ee`;
- lock NONE.

## WA-L10 — AUTONOMOUS PRODUCTION CANARY

**Status:** `NEXT ELIGIBLE · NOT STARTED · CANARY NOT AUTHORIZED`.

### Objective

Prove the full autonomous loop against a tiny, explicit, real production cohort while maintaining immediate human/kill-switch recovery and preventing uncontrolled fan-out.

### L10.0 — Entry / anti-drift / safety freeze

Before mutation:

- re-read exact `main` and workstream lock;
- verify L9 closeout lineage;
- read live L4/L8/L9 safety state;
- freeze PRE counts/fingerprints for Agenda, Call Center, Marketing, Ventas/Comisiones, Pacientes/Identity and WA;
- verify autonomous outbound remains 0;
- verify active allowlist state;
- verify provider credentials/template readiness without exposing secrets;
- verify current Meta policy/rate-card authority before live traffic.

Do not increase DB/browser timeouts to make this pass.

### L10.1 — Canary authority package

Reuse, do not duplicate:

- L4 mode/kill-switch/allowlist/budgets/idempotency;
- L8 consent/STOP/security preflight;
- L5 booking authority;
- L6 attribution;
- L7 cost;
- L9 shadow/dry-run evidence.

Any additive code must be narrowly scoped to canary observability/ramp/rollback and must remain dormant under AUTO_OFF until owner authorization.

### L10.2 — Exact-head SAFE-OFF certification

Required before owner activation gate:

- positive and fail-closed CI;
- canonical WA-4C/L5 BOOK/REBOOK regressions;
- L8 consent/security regressions;
- L6 attribution and L7 cost regressions;
- P0 #432 cross-module performance/parity;
- no raw prompt/reply storage beyond governed message ledger;
- no provider dispatch in SAFE-OFF;
- exact-head anti-drift.

### L10.3 — Explicit owner activation gate

**STOP HERE until the owner explicitly authorizes `AUTO_OFF -> CANARY`.**

Authorization must define the smallest safe cohort/conversation allowlist and does not imply PROD/general rollout.

### L10.4 — Real production canary

After explicit authorization only:

- add minimal real allowlist through governed authority;
- transition AUTO_OFF->CANARY using the certified mode function;
- keep kill/rollback path immediately available according to the certified authority/runbook;
- run a very small number of real conversations/turns;
- verify delivered provider statuses, idempotency/no duplicates, L8 preflight, costs, bookings/rebooks/handoff and attribution;
- capture redacted evidence only;
- stop/rollback immediately on safety, privacy, duplicate, provider, cost, booking, latency or cross-module regression.

### L10.5 — Canary exit / closeout

Required evidence:

- no unauthorized recipient/conversation escaped allowlist;
- no duplicate autonomous sends;
- STOP/opt-out and human handoff work;
- no identity/privacy violation;
- real booking/REBOOK semantics correct when exercised;
- provider delivery reconciles with local ledger;
- costs reconcile at demonstrated boundary;
- PRE->POST protected-module parity or explained legitimate deltas only;
- P0 #432 operational paths healthy;
- clear go/no-go decision;
- return to safe state if L11 is not immediately and separately authorized.

Only then may L10 close and L11 become eligible.

## WA-L11 — GENERAL PRODUCTION

**Status:** `BLOCKED BY WA-L10 REAL CANARY EVIDENCE`.

### Objective

Move from tiny allowlisted canary to governed general autonomous production without losing kill-switch, consent, human escalation, cost, attribution or performance controls.

### L11 entry gates

- L10 CLOSED/PASS with real evidence;
- explicit owner authorization for general production/ramp;
- official current Meta terms/rate/billing verification;
- operational owner/on-call and rollback runbook;
- provider credential/payment health;
- stable real-conversation quality and latency;
- no unresolved P0/cross-module regression.

### L11 controlled ramp

Do not jump directly to unrestricted traffic. Expand scope in bounded stages with:

- explicit cohort/ramp criteria;
- budgets/rate limits;
- kill-switch and rollback;
- provider/invoice reconciliation;
- human handoff capacity;
- performance/error monitoring;
- conversation-quality review;
- booked/attended/sale attribution and cost KPIs.

### L11 exit gate

`GENERAL PRODUCTION CERTIFIED` only when:

- autonomous authority is demonstrably correct under real load;
- customer safety/privacy/consent are preserved;
- provider delivery and billing reconcile;
- booking/rebooking and attribution are correct;
- no cross-module or P0 performance regression exists;
- human escalation/kill path is tested;
- operating runbook and ownership are complete;
- final exact-head/deploy/PROD evidence is recorded in GitHub + Notion.

## Post-L11 — Customer Experience & Conversation Validation

This is the business/UX validation layer after technical production certification.

### Real-customer experience dimensions

1. **Naturalness:** conversational, concise, non-robotic, no canned-loop feeling.
2. **Intent comprehension:** understands treatment interest, objection, timing, branch/date and continuity without repeatedly asking known facts.
3. **Memory quality:** retains conversation context within governed bounds and does not hallucinate prior facts.
4. **Message economy:** one useful outbound provider message per turn by default where UX permits; no gratuitous bubble splitting.
5. **Fact/pricing integrity:** only governed current business facts/prices; uncertainty fails closed/escalates.
6. **Booking UX:** minimum friction from intent to real slot to confirmation.
7. **REBOOK UX:** natural-language rescheduling preserves the correct appointment and state.
8. **Human handoff:** clear, fast and context-preserving transfer.
9. **STOP/consent:** opt-out immediately respected; no continued autonomous persuasion.
10. **Identity/privacy:** no unsafe disclosure or name-only binding.
11. **Latency:** first useful response and end-to-end turn latency remain acceptable under real traffic.
12. **Reliability:** no duplicate sends, loops, orphan actions or provider/local divergence.
13. **Commercial outcome:** qualified conversation -> booking -> attendance -> sale.
14. **Cost:** WhatsApp + AI cost per qualified conversation / booking / attendance / sale.
15. **Customer/operator feedback:** structured qualitative review of clarity, trust, usefulness and friction.

### Evidence method

- real consented customers/pilots only;
- start with small cohorts;
- redact evidence and protect PHI/PII;
- pair quantitative funnel/latency/cost metrics with reviewed transcripts/conversation samples;
- never create synthetic PROD rows and label them customer evidence;
- iterate copy/prompt/playbook only through governed versioned changes and re-certify relevant gates.

## Meta 2026 checkpoint before L10/L11

Before live canary/general production, recheck official Meta sources and the clinic’s Billing Hub/WABA card.

Known current operational constraints from the 2026-09-03 audit:

- charging is based on delivered message + recipient market/category;
- service/utility billing rules change materially on 2026-10-01 according to announced/corroborated rate-card changes;
- first 1,000 monthly Service messages per business phone number are expected to be free under the new model;
- Peru USD 0.0300 Utility/Auth/Service for Oct was strongly corroborated but not directly fetched from Meta due official endpoint 429;
- therefore do not mark that future rate VERIFIED until official WABA/Billing Hub evidence is obtained;
- Meta terms have an announced 2026-09-23 update: re-read before canary.

## Standard remaining-phase loop

`REVALIDATE CURRENT -> DISCOVER -> NECESSITY GATE -> BUILD MINIMUM -> SAFE-OFF CONTRACT/SECURITY/P0 TESTS -> EXACT-HEAD CI -> ANTI-DRIFT -> MERGE expected_head_sha -> RAILWAY -> MERGED-LINEAGE SUPABASE -> PROD READBACK/PARITY -> OWNER ACTIVATION GATE WHEN REQUIRED -> REAL CANARY/RAMP -> CLOSEOUT -> NOTION LAST -> NEXT BOUNDARY`.
