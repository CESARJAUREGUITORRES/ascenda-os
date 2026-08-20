# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**F6.2 certification merge:** `main@60b19256928844aedd9438da2ed2584f60078217`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED` · fp `02ba53adb9dabfcd0a4557061be53c2f`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `NEXT / UNBLOCKED — Identity Confidence + Metric Trust`  
**REV-F7:** `BLOCKED until REV-F6 certification`

This remains the single mutable Revenue execution pointer. GitHub CURRENT + Supabase LIVE are authoritative over historical checkpoints.

## One-lock rule

`REV-F6-CLOSEOUT` remains the only HIGH/CRITICAL mutable Revenue lane until F6.7 or explicit owner handoff. Other workstreams may run regression/read-only checks only.

## Certified upstream truth boundary

F6 is analytics/read-model only and preserves:

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 = `5af139243f6aed37020048af292587fe`;
- F5.10 = `2f0a365fae4caaa7be9d204e0f76679b`;
- F6.0 = `02ba53adb9dabfcd0a4557061be53c2f`;
- F6.1 = `cd313998c5b5b38d5cb9e2f08882b826`.

F3 owns product truth, F4 owns financial/payment/cartera truth, F5 owns patient identity/provenance, F6 only derives analytics/read models.

## REV-F6.2 terminal LIVE proof

Contract: `REV-F6.2_CUSTOMER_LIFECYCLE_FINAL_V1`  
Terminal fingerprint: `d977b9669b9e741e8785cd863caaf9c2` — reproduced identically before certification merge and again from independent post-merge atomic readbacks.

LIVE business date is explicit `America/Lima` and equals the Lima timezone expression.

Lifecycle summary as-of 2026-08-20:

- canonical/non-fused population = **7,262**;
- classified = **543**;
- insufficient activity evidence = **6,719**;
- qualifying event rows = **1,089**;
- `HISTORICAL_REACTIVATED` = **1**;
- `NEW_PATIENT` = **129**;
- `ACTIVE_REPEAT` = **90**;
- `RETURNING_PATIENT` = **137**;
- `DORMANT` = **186**.

Hard invariants:

- lifecycle events targeting `FUSIONADO` = **0**;
- Agenda identity rows targeting `FUSIONADO` = **0**;
- Agenda RESOLVED rows with `candidate_count <> 1` = **0**;
- PHONE conflict keys = **37**;
- PHONE conflict fail-closed = **37/37**;
- conflict violations = **0**.

Real LIVE canaries:

- `ACTIVE_REPEAT` expected = actual;
- `DORMANT` expected = actual;
- `HISTORICAL_REACTIVATED` expected = actual, gap **372 days**;
- future confirmed appointment LIVE eligible subjects = **0**, therefore real canary N/A; exact-head isolated fixture remains PASS.

Security remains fail-closed: lifecycle internal views/functions and F6.1 private base are browser closed; governed Patient Commercial 360 remains browser executable; legacy Patient 360 remains browser closed.

Historical rule remains frozen: 2024/2025 patient history may support lifecycle, but 2024/2025 transactional sales remain `NO_CERTIFIED_SOURCE`, never zero revenue and never inferred historical revenue.

## Implementation / certification sequencing

Implementation PR #311 merged with `expected_head_sha=3eb30e39c8184d4acd2cf7dcc7548d35f65c5fa3` to `main@1532cb20e087a5f2025b29bf86d4d828b7445f68`. Final certificate/snapshot/control artifacts were closed via certification PR #312 and merged to `main@60b19256928844aedd9438da2ed2584f60078217` after exact-head F6.2 + F6.1 + F6.0 workflows all returned SUCCESS.

Authoritative artifacts:

- `docs/control/REV_F6_2_CUSTOMER_LIFECYCLE_CERTIFICATE_20260820.md`
- `docs/control/REV_F6_2_CUSTOMER_LIFECYCLE_SNAPSHOT_20260820.json`

## Final gate — PASS

Post-merge closeout completed on 2026-08-20:

1. certificate + snapshot + CURRENT confirmed in GitHub;
2. Supabase LIVE post-merge atomic readbacks reconstructed exact terminal fp `d977b9669b9e741e8785cd863caaf9c2`;
3. business date Lima, lifecycle distribution, `FUSIONADO=0/0`, Agenda identity invariants and 37/37 PHONE conflict fail-closed revalidated;
4. protected truth and F6.0 input fingerprint remained exact; F6.1 Identity Bridge certified cardinalities remained exact;
5. `aos_memory` CURRENT and next-action were persisted and independently read back;
6. Notion CURRENT was reconciled and independently read back at REV-F6 progress **37.5%**.

Therefore:

- `REV-F6.2 = PASS / CERTIFIED — 100%`;
- `REV-F6.3 — Identity Confidence + Metric Trust = NEXT / UNBLOCKED`;
- `REV-F6-CLOSEOUT` remains the single mutable Revenue lock;
- `REV-F7` remains blocked until REV-F6 final certification.
