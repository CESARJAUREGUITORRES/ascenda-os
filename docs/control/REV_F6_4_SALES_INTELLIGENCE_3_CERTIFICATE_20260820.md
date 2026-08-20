# REV-F6.4 — Sales Intelligence 3.0 Certification

**Status:** PRE-MERGE CERTIFICATION EVIDENCE PASS — terminal merge still requires final exact-head CI + expected_head_sha + post-merge LIVE readback  
**Date:** 2026-08-20 America/Lima  
**Entry main:** `10c8ebccb0be1d8e538491de834cb7457f453de9`  
**Certification candidate head:** `c2db4e86dc1cb0be6e7cdce064243a704f97d944`  
**PR:** #314

## Scope

REV-F6.4 adds a zero-PII, read-model-only Sales Intelligence 3.0 layer over certified Revenue truth. It does not mutate patient, sale, F3, F4, F5 identity or upstream F6 truth.

## LIVE migrations

- `20260820191924` — `rev_f6_4_sales_intelligence_3_v1`
- `20260820192121` — `rev_f6_4_live_performance_baseline_decouple_v1`
- `20260820192333` — `rev_f6_4_dashboard_cache_performance_v1`

## LIVE deterministic contract

`aos_rev_f6_4_contract_v1()` reproduced twice:

`b0f06d841c74ceeb231451aecdeceef2`

Read models:

- sales fact: 1,299
- monthly aggregate: 72
- MATCH-only patient observed value: 66
- cohorts: 8
- product transitions: 34
- explicit acquisition rows: 0
- bounded dashboard cache rows: 22

## Semantic truth

- 2024 transactional sales: `value = null`, `source_status = NO_CERTIFIED_SOURCE`.
- 2025 transactional sales: `value = null`, `source_status = NO_CERTIFIED_SOURCE`.
- 2026 canonical sales: 1,299 rows; billed amount 561,889.27 under stored `aos_ventas` amount semantics.
- safe patient attribution: 208 / 1,299; REVIEW 940; UNRESOLVED 151.
- F3 resolved product sales: 397 / 1,299.
- F4-linked evidence: 123 / 1,299; this is evidence coverage, never confirmed collected cash.
- explicit acquisition-to-revenue rows: 0; absence is `NO_DEFENDABLE_ATTRIBUTION`, never zero conversion.
- observed patient value is observed-window value, never future/predicted LTV.

## Performance incident and correction

The first LIVE implementation violated the <1000 ms certification contract: representative calls were ~1.4–3.0 seconds. Certification was stopped fail-closed.

Root cause: repeated heavy Metric Trust baseline/read-model aggregation on every dashboard request. Corrective architecture:

1. decouple the already-certified 2024/2025 `NO_CERTIFIED_SOURCE` semantic from the expensive full baseline call until REV-F6.5 supplies the dynamic historical coverage contract;
2. preserve the deep calculation as a service-only base;
3. materialize a bounded zero-PII cache for the real 2026 filter space (22 global/sede/advisor combinations);
4. keep controlled refresh deterministic and rebuild the cache from governed read models.

Post-fix LIVE EXPLAIN evidence:

- global 2026: ~53 ms;
- San Isidro: ~6 ms;
- Pueblo Libre: ~1 ms observed in repeated readback.

All are below the 1000 ms contract without increasing timeouts.

## Security

Verified LIVE:

- raw Sales Intelligence fact/read models are browser-closed;
- `authenticated` cannot execute the service-only F6.4 contract or internal V3 RPC;
- `service_role` retains required execution;
- browser gateway remains the existing admin + 2FA authorization boundary;
- aggregate certification payload contains no raw PII/PHI.

## Protected truth

Unchanged after LIVE apply and performance correction:

- patients: 7,688; fingerprint `eee5a57717937a4f77049b3aebd8c525`
- sales: 1,299; fingerprint `20104fd91fbf427e39566e7b84d7ec4f`
- F3: 406; fingerprint `e3c8499026d13401c4a733b4da16b6c8`
- F4: 162; fingerprint `5524a2280442224ec4e9a7cfdfffa008`
- F6.0: `02ba53adb9dabfcd0a4557061be53c2f`
- F6.1: `cd313998c5b5b38d5cb9e2f08882b826`
- F6.2: `d977b9669b9e741e8785cd863caaf9c2`
- F6.3: `3f4174660107661a2c4509f6f8817d7a`

## Exact-head CI before this certificate commit

At `c2db4e86dc1cb0be6e7cdce064243a704f97d944`:

- Ascenda CI #2667 — SUCCESS
- REV-F6.0 #41 — SUCCESS
- REV-F6.1 #42 — SUCCESS
- REV-F6.2 #21 — SUCCESS
- REV-F6.3 #12 — SUCCESS
- REV-F6.4 #7 — SUCCESS

The F6.4 Zero-Cost job independently passed migration + performance hotfixes + DB/security/semantic/performance invariants + deterministic refresh replay + recovery to the certified F6.3 boundary.

## Merge gate

This document is certification evidence, not permission to skip the terminal gate. After committing this certificate/snapshot:

1. rerun all required workflows on the new exact head;
2. merge PR #314 only with that exact `expected_head_sha`;
3. perform post-merge LIVE fingerprint/performance/security/protected-truth readback;
4. only then record `REV-F6.4 PASS / CERTIFIED — 100%`, `REV-F6 global = 62.5%` and unlock REV-F6.5.
