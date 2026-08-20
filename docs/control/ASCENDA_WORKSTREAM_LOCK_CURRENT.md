# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-19 America/Lima  
**Entry baseline:** `main@9fb146358979bdff0e4af37c8c44d09e8babf4f9`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED` · fp `02ba53adb9dabfcd0a4557061be53c2f`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · PR #310 MERGED · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**CURRENT GATE:** `REV-F6.2 — CUSTOMER LIFECYCLE / IN PROGRESS`  
**REV-F6.3:** `BLOCKED until REV-F6.2 terminal certification`  
**REV-F7:** `BLOCKED until REV-F6 certification`

This is the single mutable Revenue execution pointer. GitHub CURRENT + Supabase LIVE are authoritative over historical checkpoints.

## One-lock rule

`REV-F6-CLOSEOUT` remains the only HIGH/CRITICAL mutable Revenue lane until F6.7 or explicit owner handoff. Other workstreams may run regression/read-only checks only.

## Certified upstream truth boundary

F6.2 is read-model/analytics only and must preserve:

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 = `5af139243f6aed37020048af292587fe`;
- F5.10 = `2f0a365fae4caaa7be9d204e0f76679b`;
- F6.0 = `02ba53adb9dabfcd0a4557061be53c2f`;
- F6.1 = `cd313998c5b5b38d5cb9e2f08882b826`.

F3 owns product truth, F4 owns financial/payment/cartera truth, F5 owns patient identity/provenance, F6 only derives analytics/read models.

## REV-F6.1 terminal handoff

PR #310 merged with exact expected head to `main@9fb146358979bdff0e4af37c8c44d09e8babf4f9`. Post-merge LIVE reproduced F6.1 terminal fp `cd313998c5b5b38d5cb9e2f08882b826`; real old/current phone aliases converge to the same canonical patient; PHONE conflicts are **37/37 fail-closed**; 0 bad RESOLVED aliases; 0 orphan targets; legacy `aos_paciente_360` remains browser-closed. `aos_memory` and Notion were reconciled to `REV-F6.2 NEXT / UNBLOCKED`.

## REV-F6.2 contract

Lifecycle is derived from `canonical_patient_id` plus qualifying observed patient activity. Required non-null states:

1. `UNRESOLVED_IDENTITY`
2. `HISTORICAL_REACTIVATED`
3. `NEW_PATIENT`
4. `ACTIVE_REPEAT`
5. `RETURNING_PATIENT`
6. `DORMANT`

Default thresholds are explicit and versioned:

- active/recent ≤ **90 days**;
- dormant/reactivation gap ≥ **180 days**;
- reactivation window = first **30 days** after return.

Qualifying activity V1:

- F5-reviewed historical appointment evidence;
- Agenda `ASISTIO` / `EFECTIVA` resolved safely through Identity Bridge V2;
- canonical F5-matched sale.

Patient registration alone is **not** a qualifying lifecycle event. A known canonical patient with no qualifying activity is not force-labelled: `lifecycle_state = null` + `classification_status = INSUFFICIENT_ACTIVITY_EVIDENCE`.

Historical patient activity may support lifecycle recency/reactivation, but **2024/2025 transactional sales remain `NO_CERTIFIED_SOURCE`, never revenue zero and never historical revenue evidence**.

## Entry LIVE profile for F6.2

At explicit as-of `2026-08-19` before F6.2 mutation:

- active/non-fused canonical patients = **7,262**;
- patients with safely linked qualifying activity = **551**;
- patients without qualifying activity evidence = **6,718**;
- safely linked qualifying event rows = **1,096**;
- F5 historical-appointment patients = **272**;
- canonical-sale patients = **66**;
- safely resolved attended/effective Agenda patients = **351**;
- qualifying event window = **2024-03-08 → 2026-08-17**.

These counts are evidence/coverage, not a mandate to classify patients without sufficient history.

## F6.2 exit gate

F6.2 closes only after all of the following pass on one exact head:

1. deterministic mutually-exclusive lifecycle semantics + explicit thresholds/as-of;
2. unresolved/conflicting identity → `UNRESOLVED_IDENTITY` and no patient-level repeat/lifetime claim;
3. insufficient activity evidence fails closed without invented lifecycle state;
4. historical reactivation uses patient-history evidence without manufacturing historical revenue;
5. future confirmed appointment prevents a false `DORMANT` state;
6. Patient Commercial 360 consumes F6.2 through the existing governed gateway; private F6.1 base has no browser bypass;
7. isolated DB/security/semantic tests + full replay + fail-closed recovery PASS;
8. protected F3/F4/F5/F6.0/F6.1 truth fingerprints remain unchanged LIVE;
9. deterministic F6.2 terminal fingerprint is reproduced independently;
10. certificate + final exact-head CI + expected-head merge + post-merge LIVE + `aos_memory` + Notion readback PASS.

Only then set `REV-F6.2 = PASS / CERTIFIED — 100%` and `REV-F6.3 = NEXT / UNBLOCKED`.
