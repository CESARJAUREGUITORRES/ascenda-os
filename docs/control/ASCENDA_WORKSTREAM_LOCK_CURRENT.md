# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Entry main:** `a0929aa029ed9c804ddd76d3c1b27dd644a3837b`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.3 — Identity Confidence + Metric Trust`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED` · fp `02ba53adb9dabfcd0a4557061be53c2f`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `LIVE PASS · terminal fp 3f4174660107661a2c4509f6f8817d7a · FINAL EXACT-HEAD CLOSEOUT PENDING`  
**REV-F6.4:** `BLOCKED until REV-F6.3 final post-merge readback`  
**REV-F7:** `BLOCKED until REV-F6 final certification`

GitHub CURRENT + Supabase LIVE are authoritative over historical checkpoints. `REV-F6-CLOSEOUT` remains the only HIGH/CRITICAL mutable Revenue lane.

## Protected certified truth

F6 remains analytics/read-model only and must preserve:

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 = `5af139243f6aed37020048af292587fe`;
- F5.10 = `2f0a365fae4caaa7be9d204e0f76679b`;
- F6.0 = `02ba53adb9dabfcd0a4557061be53c2f`;
- F6.1 = `cd313998c5b5b38d5cb9e2f08882b826`;
- F6.2 = `d977b9669b9e741e8785cd863caaf9c2`;
- F6.3 terminal = `3f4174660107661a2c4509f6f8817d7a`.

F3 owns product truth, F4 financial/payment/cartera truth, F5 patient identity/provenance. F6 derives analytics only.

## REV-F6.3 LIVE certified candidate

Pre-LIVE exact-head `3feab3c9cf9de59159196a382c8b68a3f36d6d16` passed dedicated REV-F6.3 plus F6.2/F6.1/F6.0 regressions and Ascenda CI.

Supabase LIVE migration ledger:

- `20260820180246 · rev_f6_3_identity_confidence_metric_trust_v1`.

LIVE Identity Confidence:

- canonical population **7,262**;
- HIGH **238**;
- MEDIUM **6,583**;
- LOW **441**;
- safe automatic cross-source attribution **238**;
- patients with conflict keys **441**;
- PHONE conflict keys **37**.

Metric Trust remains explicit and non-opaque: `value + coverage + confidence + freshness + sample_size + source_status + limitations + provenance`.

Frozen baseline semantics:

- Identity safe match **296/8,716 = 3.40%**;
- Sales safe linkage **208/1,299 = 16.01%**;
- F3 product resolution **397/406 = 97.78%**;
- F4 financial evidence **123/1,299 = 9.47%**, never interpreted as non-payment;
- historical transaction source availability **1/3 = 33.33%**, source availability not revenue;
- lifecycle classified evidence **543/7,262 = 7.48%**, sample_size **1,089**;
- 2024/2025 transactional sales remain `NO_CERTIFIED_SOURCE`, `value=null`, never zero revenue.

Security PASS:

- Identity Confidence view/function and F6.3 aggregate contract are browser-closed;
- governed Patient Commercial 360 remains browser-executable behind the existing lower-layer Auth V3 + PASSWORD_2FA contract;
- legacy `aos_paciente_360(text)` remains browser-closed;
- no fuzzy identity, phone-nearness authority, silent merge or aggregate PII/PHI exposure.

Terminal fingerprint replay:

- run 1: `3f4174660107661a2c4509f6f8817d7a`;
- run 2: `3f4174660107661a2c4509f6f8817d7a`.

Certificate: `docs/control/REV_F6_3_IDENTITY_CONFIDENCE_METRIC_TRUST_CERTIFICATE_20260820.md`  
Snapshot: `docs/control/REV_F6_3_IDENTITY_CONFIDENCE_METRIC_TRUST_SNAPSHOT_20260820.json`

## Remaining exit gate

Close REV-F6.3 only after:

1. final exact-head dedicated CI PASS;
2. F6.0/F6.1/F6.2 regressions + Ascenda CI PASS on that same final head;
3. merge PR #313 with exact `expected_head_sha`;
4. post-merge LIVE F6.3 fingerprint exact;
5. protected truth unchanged post-merge;
6. `aos_memory` persisted + independent readback;
7. Notion persisted + independent readback;
8. GitHub CURRENT final readback.

Only then set:

- `REV-F6.3 = PASS / CERTIFIED — 100%`;
- `REV-F6 global = 50%`;
- `REV-F6.4 — Sales Intelligence 3.0 = NEXT / UNBLOCKED`;
- `REV-F7` remains blocked until REV-F6 final certification.
