# REV-F6.3 — Identity Confidence + Metric Trust

**Status:** PASS / CERTIFIED — 100% candidate pending final exact-head CI + merge/post-merge readback  
**Date (America/Lima):** 2026-08-20  
**Entry main:** `a0929aa029ed9c804ddd76d3c1b27dd644a3837b`  
**Implementation PR:** #313  
**Pre-certificate exact head:** `3feab3c9cf9de59159196a382c8b68a3f36d6d16`  
**LIVE migration ledger:** `20260820180246 · rev_f6_3_identity_confidence_metric_trust_v1`  
**Terminal fingerprint:** `3f4174660107661a2c4509f6f8817d7a` (reproduced twice independently)

## Pre-LIVE exact-head CI

All PASS on `3feab3c9cf9de59159196a382c8b68a3f36d6d16`:

- REV-F6.3 dedicated: run `32397892096` — SUCCESS;
- REV-F6.2 regression: run `32397892532` — SUCCESS;
- REV-F6.1 regression: run `32397892203` — SUCCESS;
- REV-F6.0 regression: run `32397892200` — SUCCESS;
- Ascenda CI: run `32397892177` / #2649 — SUCCESS.

## LIVE persistence Triple-Proof

1. **Execution receipt:** Supabase `apply_migration` returned success for `rev_f6_3_identity_confidence_metric_trust_v1`.
2. **Direct readback:** Identity Confidence, Metric Trust, ACL and governed Patient Commercial 360 objects exist and return the expected contracts.
3. **Independent invariants:** protected patient/sales/F3/F4 fingerprints and F6.2 lifecycle remained exact after DDL.

No patient merge and no business-row mutation occurred.

## Identity Confidence LIVE

Canonical population: **7,262**.

- HIGH: **238**;
- MEDIUM: **6,583**;
- LOW: **441**;
- UNRESOLVED aggregate canonical rows: **0**;
- safe for automatic cross-source attribution: **238**;
- patients with conflict keys: **441**;
- PHONE conflict keys: **37**.

Authority remains `canonical_patient_id`. Conflicts remain fail-closed; no fuzzy matching, name-only authority, phone-nearness authority or silent merge is permitted.

## Metric Trust LIVE

Reusable envelope fields are explicit and separate: `value`, `coverage`, `confidence`, `freshness`, `sample_size`, `source_status`, `source_period`, `limitations`, `data_quality_flags`, `provenance`, `trust_level`.

Observed baseline examples:

- Identity safe match: **296/8,716 = 3.40%**, LOW coverage;
- Sales safe linkage: **208/1,299 = 16.01%**, LOW coverage;
- F3 product resolution: **397/406 = 97.78%**, HIGH trust;
- F4 financial evidence: **123/1,299 = 9.47%**, LOW coverage; missing evidence is **not non-payment**;
- Historical transactional source availability: **1/3 = 33.33%**, source availability only, not revenue;
- Lifecycle classified evidence: **543/7,262 = 7.48%**, sample_size **1,089**, LOW coverage;
- 2024 transactional sales: `value=null`, `NO_CERTIFIED_SOURCE`, trust `UNAVAILABLE`;
- 2025 transactional sales: `value=null`, `NO_CERTIFIED_SOURCE`, trust `UNAVAILABLE`.

`NO_CERTIFIED_SOURCE != 0` is preserved.

## Security / ACL

PASS:

- `aos_rev_identity_confidence_current_v1`: no anon/authenticated SELECT;
- `aos_rev_identity_confidence_by_patient_v1(text)`: no anon/authenticated EXECUTE;
- `aos_rev_f6_3_contract_v1()`: no anon/authenticated EXECUTE;
- governed `aos_patient_commercial_360_v2(text,text,text)`: browser executable and retains lower-layer Auth V3 + PASSWORD_2FA boundary;
- legacy `aos_paciente_360(text)`: browser closed;
- no aggregate contract returns raw PII/PHI.

## Protected truth after LIVE migration

- patients: **7,688** · `eee5a57717937a4f77049b3aebd8c525`;
- sales: **1,299** · `20104fd91fbf427e39566e7b84d7ec4f`;
- F3: **406** · `e3c8499026d13401c4a733b4da16b6c8`;
- F4: **162** · `5524a2280442224ec4e9a7cfdfffa008`;
- F6.0: `02ba53adb9dabfcd0a4557061be53c2f`;
- F6.1 certified input: `cd313998c5b5b38d5cb9e2f08882b826`;
- F6.2 certified input: `d977b9669b9e741e8785cd863caaf9c2`.

F6.2 LIVE remains: canonical **7,262**, classified **543**, insufficient **6,719**, qualifying events **1,089**, states `1 / 129 / 90 / 137 / 186` for HISTORICAL_REACTIVATED / NEW_PATIENT / ACTIVE_REPEAT / RETURNING_PATIENT / DORMANT.

## Terminal fingerprint

`REV-F6.3_IDENTITY_CONFIDENCE_METRIC_TRUST_V1`

- replay 1: `3f4174660107661a2c4509f6f8817d7a`;
- replay 2: `3f4174660107661a2c4509f6f8817d7a`.

Dynamic `generated_at` is excluded from the fingerprint payload.

## Remaining closeout gates

This certificate is a terminal LIVE evidence artifact. REV-F6.3 becomes formally closed only after:

1. certificate/snapshot/CURRENT final exact-head CI PASS;
2. PR #313 merge with exact `expected_head_sha`;
3. post-merge LIVE fingerprint exact;
4. `aos_memory` persisted + independent readback;
5. Notion persisted + independent readback;
6. GitHub CURRENT final readback.

After those gates: `REV-F6.3 = PASS / CERTIFIED — 100%`, `REV-F6 = 50%`, `REV-F6.4 = NEXT / UNBLOCKED`, while REV-F7 remains blocked.