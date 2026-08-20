# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Entry main:** `10c8ebccb0be1d8e538491de834cb7457f453de9`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.4 — Sales Intelligence 3.0`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED` · fp `02ba53adb9dabfcd0a4557061be53c2f`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `PASS / CERTIFIED — 100%` · fp `3f4174660107661a2c4509f6f8817d7a`  
**REV-F6 global:** `50%`  
**REV-F6.4:** `IN PROGRESS / PRE-LIVE`  
**REV-F6.5:** `BLOCKED until REV-F6.4 certification`  
**REV-F6.6:** `BLOCKED`  
**REV-F6.7:** `BLOCKED`  
**REV-F7:** `BLOCKED until REV-F6 final certification`

GitHub CURRENT + Supabase LIVE are authoritative over historical checkpoints. `REV-F6-CLOSEOUT` remains the only HIGH/CRITICAL mutable Revenue lane.

## REV-F6.4 entry

F6.4 started from exact `main@10c8ebccb0be1d8e538491de834cb7457f453de9` after independent LIVE revalidation of the certified F6.3 boundary.

Entry proof:

- Supabase SQL available;
- F6.3 LIVE fp `3f4174660107661a2c4509f6f8817d7a`;
- patients **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F6.0 `02ba53adb9dabfcd0a4557061be53c2f`;
- F6.1 `cd313998c5b5b38d5cb9e2f08882b826`;
- F6.2 `d977b9669b9e741e8785cd863caaf9c2`.

Current certified linkage boundary is **208 MATCH / 940 REVIEW / 151 UNRESOLVED** sales. Patient-level intelligence must use MATCH-only evidence. Executive billed revenue can use all certified 2026 sale rows but must disclose patient-link coverage.

F4 currently gives **123/1,299** linked financial-evidence rows and no certified confirmed-cash amount. F6.4 must not present F4 linkage as collected cash.

Current explicit acquisition→sale lineage through `Agenda.venta_id_match + lead_id_origen` is zero in LIVE, so the acquisition-to-revenue metric must remain `NO_DEFENDABLE_ATTRIBUTION`, never fabricated zero conversion.

## F6.4 architecture

Sales Intelligence 3.0 uses bounded materialized read models plus set-based aggregate RPCs. It consumes F3/F4/F5/F6.0–F6.3 and does not create competing patient/product/revenue truth.

Required domains:

- Executive Revenue;
- cohorts/retention;
- observed value/LTV;
- canonical product + cross-sell;
- sede/advisor performance;
- acquisition-to-revenue only with explicit lineage;
- demographic/geographic dimensions only above declared coverage thresholds.

Metric Trust remains explicit. 2024/2025 transactional sales remain `NO_CERTIFIED_SOURCE != zero`.

## Security / mutation boundary

F6.4 is additive analytical schema. No mutation of `aos_pacientes`, `aos_ventas`, F3, F4, F5 identity/classification or F6.0–F6.3 certified source truth is authorized.

Raw read models are browser-closed/service-only. Existing admin + PASSWORD_2FA Sales Intelligence gateway semantics remain the browser trust boundary.

## Exit gate

Do not mark F6.4 PASS until:

- exact-head FAST + Zero-Cost DB/security/semantic/performance and upstream regressions PASS;
- LIVE migration/readback/reconciliation PASS;
- protected truth unchanged;
- security/no-PII invariants PASS;
- F6.4 deterministic fingerprint reproduced twice;
- exact-head PR merge with `expected_head_sha`;
- post-merge LIVE fingerprint exact;
- `aos_memory` + Notion + CURRENT reconciled.

Until then:

- `REV-F6.4 = IN PROGRESS`;
- `REV-F6.5/F6.6/F6.7 = BLOCKED`;
- `REV-F7 = BLOCKED`.
