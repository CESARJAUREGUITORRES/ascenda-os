# ASCENDA OS — WA AUTO L9 TO L11 CONTINUITY CURRENT

**Captured:** 2026-09-03 America/Lima  
**Purpose:** single operational continuity checkpoint from certified WA-L9 through final autonomous production and customer-experience validation.  
**Source baseline:** `main@bab9f0865f779217aadc7c88af4ebf0e1fb0b3ee`  
**Current lock:** `NONE`  
**Current safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**Next:** `WA-L10 · NOT STARTED · CANARY NOT AUTHORIZED`

## 1. Exact WA-L9 closeout

WA-L9 is closed and must not be reopened absent a demonstrated regression.

- issue #453 = CLOSED / completed;
- certified exact head = `b0a65d5b340896263a3f75cb66ab7850fdb3c5fa`;
- PR #454 merged with `expected_head_sha`;
- merge/deploy = `f909e972aab243af954fc8e2fb15e5a37c68d1b6`;
- Railway exact-merge = SUCCESS;
- Supabase PROD = `20260903225152 · wa_l9_shadow_demo_v1`;
- final closeout main = `bab9f0865f779217aadc7c88af4ebf0e1fb0b3ee`;
- HIGH/CRITICAL lock = NONE.

PROD readback at closeout:

- Agenda = 3209;
- Call Center = 37195;
- Leads = 6694;
- Ventas = 1393;
- Pacientes = 7760;
- WA messages = 21;
- autonomous outbound = 0;
- L9 demo runs = 0;
- L9 would-send = 0;
- L9 provider dispatch = 0;
- L9 raw-content rows = 0.

L9 shadow authority calls the exact L4 authority (which is wrapped by L8 preflight) inside a rollback-only subtransaction. It returns deterministic would-send evidence while rolling back L4/L8 side effects. Provider dispatch and raw-content storage are structurally false.

## 2. What is already built before L10

Do not duplicate these layers:

### L4 authority

- modes `AUTO_OFF | CANARY | PROD`;
- kill switch;
- active conversation allowlist;
- daily/rate/max-turn/cooldown/duplicate limits;
- provider/template/identity/safety/handoff gates;
- audit/idempotency;
- CANARY requires active allowlist;
- direct AUTO_OFF->PROD forbidden.

### L5 booking/rebooking

- real availability only;
- explicit confirmation;
- governed BOOK/REBOOK;
- correct canonical appointment continuity;
- no invented provider/slot.

### L6 attribution

Strong-key path only:

`provider touchpoint -> conversation_id -> BOOK/REBOOK -> appointment_id -> attendance -> explicit venta_id_match -> canonical venta_id`.

No revenue attribution by phone/name/username/BSUID alone.

### L7 cost

- effective-dated pricing authority;
- Meta provider billability/category/market evidence;
- Groq token rates/evidence;
- scoped conversation/journey cost;
- PARTIAL/UNKNOWN rather than fabricated precision.

### L8 security/Meta hardening

- pricing type and recipient market;
- per-business-phone/category billing observability;
- consent/opt-in/opt-out/STOP ledger;
- business-initiation preflight;
- signed webhook/idempotency/secrets;
- PHI/PII minimization;
- least privilege;
- P0 #432 regressions.

### L9 shadow

- deterministic exact-authority dry run;
- would-send evidence;
- rollback-only side effects;
- no provider dispatch;
- no raw content evidence table.

## 3. WA-L10 mission — real autonomous production canary

L10 is the first boundary permitted to create real autonomous provider traffic, but **only after separate explicit owner authorization**.

### L10 preparation allowed under SAFE-OFF

Before the owner activation gate, the active L10 implementation may:

- revalidate exact main and upstream contracts;
- audit provider/template/payment/billing readiness;
- audit live consent/STOP/identity/allowlist state;
- add minimal canary-only observability/ramp/rollback instrumentation if genuinely missing;
- extend CI for live-canary invariants without sending live traffic;
- run L9 shadow on approved non-sensitive evidence paths;
- freeze PRE fingerprints;
- verify kill-switch/operator runbook;
- verify customer-facing message economy and handoff behavior in local/staging/shadow;
- produce a complete activation checklist.

It may not:

- transition AUTO_OFF->CANARY;
- disengage kill switch for real autonomous sending;
- add live customer conversations to an autonomous allowlist for dispatch;
- autonomously call Meta/provider send;
- infer that broad owner intent equals activation consent.

### Owner activation statement required

A valid activation must explicitly authorize the production CANARY transition. The authorization should identify or approve the minimal governed cohort/selection method. It does not authorize PROD/general rollout.

### Real L10 evidence

Once authorized, collect real evidence for:

- authority ALLOW/BLOCK/HANDOFF decisions;
- L8 preflight and consent/STOP outcomes;
- provider accepted/delivered/failed statuses;
- no duplicate delivery;
- latency per autonomous turn;
- correct governed facts/pricing;
- booking/rebooking state where exercised;
- human handoff;
- attribution touchpoint/conversation/appointment/sale continuity;
- Meta + AI cost;
- provider/local reconciliation;
- PRE/POST protected-module counts/fingerprints;
- kill/rollback behavior.

Immediate stop criteria include any privacy/identity breach, consent/STOP violation, duplicate send, provider/local divergence, wrong price/fact, invalid booking mutation, unsafe clinical response, runaway loop/fan-out, material latency/P0 regression or budget breach.

## 4. WA-L11 mission — general production

L11 is blocked until L10 closes PASS using real canary evidence.

L11 is not simply `mode=PROD`. It is a controlled operational transition that must prove:

- owner authorization for general rollout;
- current Meta terms/rate/billing verified;
- provider/payment credentials healthy;
- staged traffic ramp;
- kill/rollback remains functional;
- human escalation capacity exists;
- conversation quality stable;
- no duplicate/retry storm;
- booking/REBOOK reliable;
- cost/attribution reconcile;
- P0 #432 performance remains healthy;
- operating owner/on-call/runbook established.

A general-production certificate requires exact-head CODE PASS, Railway deploy PASS, merged-lineage Supabase PASS and real production behavior PASS.

## 5. Customer Experience & Conversation Validation after L11

Technical autonomy certification is necessary but not sufficient for a good customer product. After L11, run a separate customer-experience program against real consented customers.

### Scorecard

For each reviewed conversation or cohort measure:

- **Naturalness:** human-like but professional; no robotic scripts or excessive enthusiasm.
- **Relevance:** answers the actual client question before over-selling.
- **Conciseness:** avoids unnecessary multi-bubble fragmentation.
- **Context retention:** does not ask repeatedly for facts already provided.
- **Intent progression:** detects information-seeking, objection, buying intent, scheduling readiness and handoff need.
- **Fact integrity:** uses governed service/product/process/pricing sources only.
- **Clinical boundary:** escalates medical diagnosis/risk rather than inventing clinical advice.
- **Booking friction:** number of turns and failures from intent to confirmed real appointment.
- **REBOOK continuity:** preserves correct appointment and makes rescheduling understandable.
- **Handoff quality:** human receives enough context without forcing customer repetition.
- **Privacy/identity:** minimum-data, no unsafe disclosure, no name-only binding.
- **Consent/STOP:** immediate respectful stop; no further persuasion.
- **Latency:** time to first useful answer and total turn completion.
- **Reliability:** duplicate sends, loops, orphan actions, provider/local mismatch.
- **Commercial outcome:** qualified conversations, bookings, attendance, sales.
- **Cost efficiency:** provider + AI cost per qualified conversation/booked/attended/sale.
- **Trust:** customer qualitative feedback and operator review.

### Conversation review taxonomy

Review samples across:

1. new Meta lead asking basic information;
2. price-first customer;
3. uncertain/educational customer;
4. objection on price/timing/trust;
5. customer asking for a specific sede/date;
6. successful BOOK;
7. unavailable slot -> alternative path;
8. natural-language REBOOK;
9. existing patient with identity/privacy boundary;
10. clinical question requiring escalation;
11. customer asks for human;
12. STOP/opt-out;
13. repeated/ambiguous message;
14. provider failure/retry boundary;
15. campaign/referral -> booking -> attendance/sale attribution when naturally present.

### Evidence rules

- real customer evidence only after proper production gate;
- consented/authorized cohort;
- redacted transcript review;
- no copying raw PHI/PII into analytical notes unnecessarily;
- no synthetic rows described as customers;
- improvements are versioned, tested and re-certified if they change authority, booking, consent, provider dispatch or hot paths.

## 6. Meta 2026 checkpoint

Before any live L10/L11 traffic:

- re-read current official WhatsApp Business Messaging Policy and applicable terms;
- specifically recheck the announced 2026-09-23 terms update;
- read the clinic WABA Billing Hub/rate card if accessible;
- confirm billing currency/payment health;
- do not promote future October pricing to VERIFIED authority from third-party corroboration alone.

Operational rate knowledge retained from the 2026-09-03 audit:

- current Peru public list: Marketing USD 0.0703, Utility USD 0.0200, Authentication USD 0.0200;
- PEN card evidence: Marketing PEN 0.2339, Utility/Auth PEN 0.0665;
- announced Oct model materially expands billable service/utility messages;
- first 1,000 monthly Service messages per business phone number expected free;
- Peru Oct USD 0.0300 Utility/Auth/Service strongly corroborated but not directly retrieved from the official developer card due HTTP 429;
- actual invoice authority remains Meta/WABA billing evidence.

## 7. AI cost / message economy

Groq public rate baseline verified during L7/L8:

- GPT-OSS 20B: USD 0.075/M input, USD 0.30/M output;
- GPT-OSS 120B: USD 0.15/M input, USD 0.60/M output.

Provider message cost can dominate inference cost under the Oct Meta model. Default conversation design should therefore use one complete useful outbound message per turn where that improves UX; do not split responses into multiple provider messages just to imitate chat style.

## 8. Do not forget the legacy CI anomaly

`.github/workflows/f16-provider-outcomes-test-adapt.yml` has produced instant failures with no jobs across unrelated historical commits including L8/L9 governance commits. It is legacy noise, not evidence that L9 failed. Do not use it as a substitute for relevant exact-head gates, and do not silently call it green. If it is ever remediated, do so under its own justified scope rather than contaminating L10/L11.

## 9. Resume protocol

Any future agent/chat resuming this project must state and verify before mutation:

1. exact current `main`;
2. current HIGH/CRITICAL lock;
3. L9 remains closed;
4. whether L10 has actually started;
5. whether explicit CANARY authorization exists;
6. current live `AUTO_OFF/CANARY/PROD` + kill-switch state;
7. active allowlist count;
8. latest Meta terms/rate evidence;
9. relevant Railway/Supabase health;
10. next exact gate.

If any of those disagree with this document, exact current GitHub/runtime evidence wins and this document must be refreshed before proceeding.
