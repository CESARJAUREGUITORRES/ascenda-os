# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Certification main:** `c3da45ce18ebad9d89ba42181299da86625ce8e2`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.4 — Sales Intelligence 3.0`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED` · fp `02ba53adb9dabfcd0a4557061be53c2f`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `PASS / CERTIFIED — 100%` · fp `3f4174660107661a2c4509f6f8817d7a`  
**REV-F6 global:** `50%`  
**REV-F6.4:** `NEXT / UNBLOCKED`  
**REV-F6.5:** `BLOCKED until REV-F6.4 certification`  
**REV-F6.6:** `BLOCKED`  
**REV-F6.7:** `BLOCKED`  
**REV-F7:** `BLOCKED until REV-F6 final certification`

GitHub CURRENT + Supabase LIVE are authoritative over historical checkpoints. `REV-F6-CLOSEOUT` remains the only HIGH/CRITICAL mutable Revenue lane.

## REV-F6.3 final certification

Implementation/certification PR **#313** was merged with exact expected head `440b068c422b546d24c3b47748ba9347d492a848` to certification main `c3da45ce18ebad9d89ba42181299da86625ce8e2`.

Final exact-head CI on `440b068c422b546d24c3b47748ba9347d492a848`:

- REV-F6.3 run #5 / `32401302561` — SUCCESS;
- REV-F6.2 run #14 / `32401302456` — SUCCESS;
- REV-F6.1 run #35 / `32401302457` — SUCCESS;
- REV-F6.0 run #34 / `32401302464` — SUCCESS;
- Ascenda CI #2652 / `32401302460` — SUCCESS.

Supabase LIVE migration ledger:

- `20260820180246 · rev_f6_3_identity_confidence_metric_trust_v1`.

Terminal fingerprint:

- pre-merge replay 1: `3f4174660107661a2c4509f6f8817d7a`;
- pre-merge replay 2: `3f4174660107661a2c4509f6f8817d7a`;
- post-merge LIVE: `3f4174660107661a2c4509f6f8817d7a`.

## Identity Confidence LIVE

- canonical population **7,262**;
- HIGH **238**;
- MEDIUM **6,583**;
- LOW **441**;
- aggregate canonical UNRESOLVED **0**;
- safe automatic cross-source attribution **238**;
- patients with conflict keys **441**;
- PHONE conflict keys **37**.

Authority remains `canonical_patient_id`. Strong alias conflict remains fail-closed. No fuzzy identity, phone-nearness authority, name-only identity, or silent patient merge is permitted.

## Metric Trust V1

Every relevant trust envelope keeps these dimensions separate:

`value + coverage + confidence + freshness + sample_size + source_status + source_period + limitations + data_quality_flags + provenance + trust_level`.

Frozen observed baselines:

- Identity safe match **296/8,716 = 3.40%** — LOW coverage;
- Sales safe linkage **208/1,299 = 16.01%** — LOW coverage;
- F3 product resolution **397/406 = 97.78%** — HIGH trust;
- F4 financial evidence **123/1,299 = 9.47%** — LOW coverage and **not non-payment**;
- Historical transaction source availability **1/3 = 33.33%** — source availability, not revenue;
- Lifecycle classified evidence **543/7,262 = 7.48%**, sample_size **1,089** — LOW coverage;
- 2024 transactional sales = `NO_CERTIFIED_SOURCE`, `value=null`, never zero revenue;
- 2025 transactional sales = `NO_CERTIFIED_SOURCE`, `value=null`, never zero revenue.

## Protected certified truth

Post-migration and post-merge readback remained exact:

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 = `5af139243f6aed37020048af292587fe`;
- F5.10 = `2f0a365fae4caaa7be9d204e0f76679b`;
- F6.0 = `02ba53adb9dabfcd0a4557061be53c2f`;
- F6.1 = `cd313998c5b5b38d5cb9e2f08882b826`;
- F6.2 = `d977b9669b9e741e8785cd863caaf9c2`;
- F6.3 = `3f4174660107661a2c4509f6f8817d7a`.

F3 owns product truth, F4 financial/payment/cartera truth, F5 patient identity/provenance. F6 derives analytics only.

## Security boundary

PASS:

- Identity Confidence view/function and F6.3 aggregate contract are browser-closed;
- governed Patient Commercial 360 remains browser-executable behind existing Auth V3 + PASSWORD_2FA semantics;
- legacy `aos_paciente_360(text)` remains browser-closed;
- no aggregate raw PII/PHI exposure.

## CURRENT next gate — REV-F6.4

REV-F6.4 must consume F6.0/F6.1/F6.2/F6.3 without replacing their truth. Sales Intelligence 3.0 must be set-based/preaggregated where appropriate, must propagate Metric Trust, and must not infer 2024/2025 revenue from absent transactional sources.

At F6.4 entry:

- `REV-F6.4 = NEXT / UNBLOCKED`;
- `REV-F6.5/F6.6/F6.7 = BLOCKED` according to dependency order;
- `REV-F7 = BLOCKED until REV-F6 final certification`;
- `REV-F6-CLOSEOUT` remains the single mutable Revenue lock.
