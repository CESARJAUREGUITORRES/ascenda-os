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
**REV-F6.3:** `IN PROGRESS · PRE-LIVE`  
**REV-F6.4:** `BLOCKED until REV-F6.3 certification`  
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
- F6.2 = `d977b9669b9e741e8785cd863caaf9c2`.

F3 owns product truth, F4 financial/payment/cartera truth, F5 patient identity/provenance. F6 derives analytics only.

## REV-F6.3 contract

F6.3 formalizes two reusable, explainable layers without a second patient truth:

1. **Identity Confidence** by `canonical_patient_id`: `HIGH / MEDIUM / LOW / UNRESOLVED`, based only on governed F5/F6.1 evidence. Alias conflict is fail-closed and cannot auto-authorize cross-source attribution. `FUSIONADO` cannot become an active subject.
2. **Metric Trust** envelopes carrying `value + coverage + confidence + freshness + sample_size`, plus source status/period, limitations, provenance, data-quality flags and an auditable trust level. No opaque probability score.

Frozen semantics:

- coverage always includes numerator + denominator + semantic;
- freshness = `CURRENT / STALE / UNKNOWN`;
- `NO_CERTIFIED_SOURCE != 0` remains mandatory;
- F4 coverage `9.47%` means financial evidence availability, never non-payment;
- 2024/2025 transactional sales remain `NO_CERTIFIED_SOURCE`, never zero revenue;
- no fuzzy matching, phone-nearness authority or silent identity merge;
- no new browser-facing internal trust endpoints and no new PHI exposure.

Candidate implementation lives on branch `data/rev-f6-3-identity-confidence-metric-trust-20260820`. No F6.3 DDL may be applied LIVE until exact-head FAST + isolated DB/security/semantic + replay/recovery and affected upstream regressions are PASS and `main`/LIVE protected fingerprints are revalidated.

## Exit gate

Close REV-F6.3 only after:

1. exact-head dedicated CI PASS;
2. F6.0/F6.1/F6.2 regression PASS;
3. anti-drift `main` + protected LIVE truth PASS;
4. exact F6.3 migration receipt + direct readback + independent invariants;
5. deterministic F6.3 terminal fingerprint reproduced twice;
6. certificate + snapshot committed;
7. final exact-head CI PASS;
8. merge with exact `expected_head_sha`;
9. post-merge LIVE fingerprint exact;
10. `aos_memory` persisted/read back;
11. Notion persisted/read back;
12. GitHub CURRENT final readback.

Only then set:

- `REV-F6.3 = PASS / CERTIFIED — 100%`;
- `REV-F6 global = 50%`;
- `REV-F6.4 — Sales Intelligence 3.0 = NEXT / UNBLOCKED`;
- `REV-F7` remains blocked until REV-F6 final certification.
