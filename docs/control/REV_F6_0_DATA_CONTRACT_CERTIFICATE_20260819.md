# REV-F6.0 — DATA CONTRACT V1 — LIVE CERTIFICATION EVIDENCE

**Date:** 2026-08-19 America/Lima  
**Workstream:** `REV-F6`  
**Gate:** `REV-F6.0 — Data Contract`  
**PR:** `#309`  
**Entry main:** `754ab44f39f10123ab83b98f97b5c01fff25bab5`  
**Pre-LIVE validated PR head:** `599da3206638786e162f0b6f001f56dffb4bb408`  
**Pre-LIVE CI run:** `32322594175`  
**Status in this commit:** `LIVE PASS / FINAL EXACT-HEAD CI + MERGE PENDING`

## 1. Pre-LIVE gates

The exact F6.0 migration and compatibility boundary passed both self-hosted lanes before any production DDL:

- `F6.0 FAST contracts` — **SUCCESS**;
- service-worker syntax — **PASS**;
- Patient-history compatibility contract — **PASS**;
- `F6.0 DB/security contracts` — **SUCCESS**;
- isolated migration apply — **PASS**;
- DB/security invariants — **PASS**;
- recovery remains fail-closed — **PASS**.

Anti-drift immediately before LIVE:

- `main` remained exactly `754ab44f39f10123ab83b98f97b5c01fff25bab5`;
- PR #309 remained mergeable;
- PR head remained exactly `599da3206638786e162f0b6f001f56dffb4bb408`.

## 2. LIVE migration receipt

Applied to Supabase production project `ituyqwstonmhnfshnaqz` via governed migration API.

Migration ledger readback:

- version: `20260820015805`;
- name: `rev_f6_0_data_contract_v1`.

The migration creates/updates only read-contract and access-control functions. It does **not** mutate patient, sale, F3, F4, identity or financial business rows.

## 3. ACL readback — PASS

### `public.aos_rev_f6_data_contract_v1()`

- anon EXECUTE = **false**;
- authenticated EXECUTE = **false**;
- service_role EXECUTE = **true**.

### `public.aos_patient_history_summary_v1(text,text)`

- anon EXECUTE = **true**;
- authenticated EXECUTE = **true**;
- authorization is enforced inside the SECURITY DEFINER function by `aos_app_actor_v3` with `advisor-patients` or `admin-patients` and `PASSWORD_2FA` required.

### legacy `public.aos_paciente_360(text)`

- anon EXECUTE = **false**;
- authenticated EXECUTE = **false**;
- service_role EXECUTE = **true**.

This closes the browser-executable legacy Patient 360 path that returned broader patient/clinical/document domains while preserving the Citas compatibility surface through the governed summary route.

## 4. Deterministic Data Contract replay

LIVE run #1 fingerprint:

`02ba53adb9dabfcd0a4557061be53c2f`

Independent LIVE replay fingerprint:

`02ba53adb9dabfcd0a4557061be53c2f`

Result: **DETERMINISTIC / PASS**.

Contract id:

`REV-F6.0_DATA_CONTRACT_V1`

## 5. Source / identity input boundary

- source batches total / MATCHED = **6 / 6**;
- source rows = **15,498**;
- expected rows = **15,498**;
- memberships = **15,498**;
- clusters = **8,716**;
- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- patient history years = **2024 / 2025 / 2026**.

Identity Coverage:

- numerator = **296** safe MATCH clusters;
- denominator = **8,716** clusters;
- coverage = **3.40%**;
- semantic = `SAFE_MATCH_CLUSTERS`.

## 6. Canonical protected domains — unchanged

Independent queries outside the contract builder reproduced the protected counts and fingerprints exactly:

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 facts = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 reconciliation = **162** / `5524a2280442224ec4e9a7cfdfffa008`.

All builder↔independent fingerprint comparisons = **true**.

No protected-domain drift was observed.

## 7. Historical JOIN / coverage boundary

- F5 historical bridge rows = **1,299**;
- distinct sales = **1,299**;
- sale identity MATCH / REVIEW / UNRESOLVED = **208 / 940 / 151**;
- Sales Linkage Coverage = **208 / 1,299 = 16.01%**.

F3:

- applicable = **406**;
- RESOLVED = **397**;
- REVIEW_REQUIRED = **3**;
- EXCLUDED = **6**;
- MISSING = **0**;
- NOT_APPLICABLE = **893**;
- Product Coverage = **97.78%** of applicable sales.

F4:

- linked = **123**;
- no reconciliation evidence = **1,176**;
- reconciliation rows = **162**;
- distinct covered sales = **123**;
- Financial Evidence Coverage = **9.47%**.

Low F4 coverage is a coverage gap, **not evidence of non-payment**.

## 8. Historical transaction semantics

- patient history 2024 = `AVAILABLE`;
- patient history 2025 = `AVAILABLE`;
- patient history 2026 = `AVAILABLE`;
- transactional sales 2024 = `NO_CERTIFIED_SOURCE`;
- transactional sales 2025 = `NO_CERTIFIED_SOURCE`;
- transactional sales 2026 = `AVAILABLE_2026-01-05_TO_2026-08-15`.

Mandatory semantic guards:

- `NO_CERTIFIED_SOURCE != 0`;
- absence of historical transaction evidence never becomes zero revenue;
- factual 2024↔2025↔2026 YoY remains unsupported;
- `Último presupuesto` is not sale/payment/debt truth;
- `ADELANTO` is not automatic balance/debt;
- phone/name/phone-nearness alone never authorize patient identity;
- F3 remains product truth;
- F4 remains financial truth;
- F5 remains identity/provenance truth.

## 9. F6 Metric Trust contract

Every derived F6 model/insight must expose, where relevant:

- `coverage`;
- `confidence`;
- `freshness`;
- `sample_size`.

Derived models must expose generation time and become stale when certified source state is newer.

## 10. Identity architecture boundary

- `aos_cia_contact_identity_v1` remains a **compatibility identity** object only;
- it is not promoted to a competing patient truth layer;
- `Identity Bridge V2` remains `CONTRACT_FROZEN_NOT_MATERIALIZED_AT_F6_0`;
- F6.1 must consume this F6.0 boundary rather than inventing a second identity system.

## 11. Exit gate state

All LIVE data-contract, ACL, deterministic replay and protected-domain gates have passed.

This commit deliberately does **not** declare terminal F6.0 completion by itself. Remaining mandatory closeout:

1. exact-head CI SUCCESS for the commit containing this certificate;
2. revalidate `main` anti-drift;
3. merge PR #309 with expected head SHA;
4. post-merge GitHub + Supabase LIVE readback;
5. persist `aos_memory` CURRENT handoff;
6. reconcile Notion CURRENT;
7. only then declare `REV-F6.0 = PASS / CERTIFIED` and `REV-F6.1 = NEXT / UNBLOCKED`.
