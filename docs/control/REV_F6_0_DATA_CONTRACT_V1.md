# REV-F6.0 — DATA CONTRACT V1

**Status:** IMPLEMENTED / PENDING LIVE CERTIFICATION  
**Entry baseline:** `main@754ab44f39f10123ab83b98f97b5c01fff25bab5`  
**Workstream:** `REV-F6-CLOSEOUT`  
**Contract:** `REV-F6.0_DATA_CONTRACT_V1`

## Purpose

REV-F6.0 freezes the executable input boundary for Sales Intelligence 3.0. It does not create a second patient, product, sales or financial truth layer and does not start Patient Commercial 360 V2.

Truth ownership is fixed:

- **REV-F5 / `aos_f5_*` + `aos_pacientes`** = patient identity and provenance;
- **`aos_ventas`** = canonical persisted sales ledger currently certified for 2026 only;
- **REV-F3 / `aos_product_sale_fact_current_v1`** = product truth;
- **REV-F4 / `aos_cartera_reconciliacion`** = payment/revenue/cartera evidence truth;
- **`aos_cia_contact_identity_v1`** = compatibility identity view only, not a new authority;
- **Identity Bridge V2** = frozen design contract, **not materialized at F6.0**;
- **Patient Commercial 360 V2** = F6.1 target read model, not created in this phase.

## Entry LIVE state

The F6.0 preflight revalidated:

- F5 source batches = **6/6 MATCHED**;
- source rows = **15,498 / 15,498**;
- identity memberships = **15,498 / 15,498**;
- identity clusters = **8,716**;
- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- canonical patients = **7,688**;
- sales = **1,299**, date range **2026-01-05 → 2026-08-15**;
- sale identity MATCH / REVIEW / UNRESOLVED = **208 / 940 / 151**;
- F3 = **406 applicable facts**, **397 RESOLVED / 3 REVIEW_REQUIRED / 6 EXCLUDED / 0 MISSING**;
- F4 = **162 reconciliation rows / 123 linked sales**, payment-linked rows 0, confirmed-balance rows 0;
- `aos_cia_contact_identity_v1` = **11,796 rows / 7,069 with canonical_patient_id / 23 conflicts**;
- Identity Bridge V2 materialized LIVE = **false**.

Protected F5 fingerprints remain the mandatory entry gate:

- patients `eee5a57717937a4f77049b3aebd8c525`;
- sales `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 `e3c8499026d13401c4a733b4da16b6c8`;
- F4 `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 `5af139243f6aed37020048af292587fe`;
- F5.8 `4ce1695532a57655179558ed2b5f78aa`;
- F5.9 `5070c701d216eb839572bd70f530c2e6`;
- F5.10 terminal `2f0a365fae4caaa7be9d204e0f76679b`.

## Metric Trust contract

Every F6-derived insight that can affect interpretation or action must carry or inherit:

- `coverage`;
- `confidence`;
- `freshness`;
- `sample_size`.

Rules:

1. `0 observed` is not the same as `NO SOURCE`.
2. Unsupported denominators must not render as 100%.
3. Derived read models must expose `generated_at` and source freshness.
4. A derived model becomes stale when its certified source state is newer than its generation checkpoint.
5. No global score may average away a critical low-coverage domain.

## Historical period semantics

- patient history 2024 = `AVAILABLE`;
- patient history 2025 = `AVAILABLE`;
- patient history 2026 = `AVAILABLE`;
- transactional sales 2024 = `NO_CERTIFIED_SOURCE`;
- transactional sales 2025 = `NO_CERTIFIED_SOURCE`;
- transactional sales 2026 = `AVAILABLE` only for the certified current range.

`NO_CERTIFIED_SOURCE` never means zero sales or zero revenue. 2024↔2025↔2026 factual YoY remains disabled until certified transactional sources are ingested under the historical-sales contract.

## Semantic guards

- name alone does not authorize identity;
- phone alone does not authorize identity;
- phone numeric proximity is prohibited as identity authority;
- `Último presupuesto` is not sale/payment/debt truth;
- `ADELANTO` is not automatic debt;
- clinical notes/allergies are outside automatic commercial enrichment;
- F3 remains the only product truth layer;
- F4 remains the only financial/cartera truth layer;
- F5 remains the only patient identity/provenance truth layer.

## F6.0 security finding and cutover

Preflight discovered that legacy `public.aos_paciente_360(text)` was `SECURITY DEFINER`, callable by `anon` and `authenticated`, used last-9-digit phone matching, and returned more information than the Citas panel consumes, including patient record / clinical-note / document domains.

F6.0 closes this path before certification:

1. legacy `aos_paciente_360(text)` becomes **service_role-only** and gets an empty `search_path`;
2. new `aos_patient_history_summary_v1(token, phone)` requires Auth V3 + `PASSWORD_2FA` + `advisor-patients` or `admin-patients`;
3. the summary returns only the minimum commercial history used by Citas: purchases, appointments and non-free-text call status;
4. call observations, patient record, clinical notes and documents are excluded;
5. the production service worker intercepts the legacy UI RPC name, injects the existing app token and routes to the secure summary;
6. there is **no fallback** to the weak legacy RPC;
7. recovery remains fail-closed and never reopens browser access to the legacy function.

## Machine-readable contract

`public.aos_rev_f6_data_contract_v1()` is service-role-only and returns:

- truth-layer ownership;
- certified source state;
- protected row counts/fingerprints;
- coverage numerators/denominators;
- historical source availability;
- Metric Trust requirements;
- freshness sources;
- compatibility identity state;
- semantic guards;
- deterministic `contract_fingerprint` over the payload.

The `as_of` timestamp is intentionally outside the fingerprinted payload.

## Exit gate

REV-F6.0 may be declared `PASS / CERTIFIED` only after:

1. exact-head FAST + Zero-Cost DB/security CI succeeds;
2. `main` is revalidated before LIVE DDL;
3. exact migration is applied to Supabase LIVE;
4. legacy Patient 360 browser privileges are closed by direct readback;
5. new summary ACL/Auth V3/security-definer contract is directly read back;
6. the data contract is generated twice with the same fingerprint;
7. independent LIVE invariants confirm protected F5 domains did not mutate;
8. final evidence is committed and exact-head CI succeeds again;
9. PR merges with expected head SHA;
10. post-merge GitHub + LIVE fingerprint readback passes;
11. GitHub CURRENT, `aos_memory` and Notion are reconciled.

Only then: `REV-F6.1 — Patient Commercial 360 V2 = NEXT / UNBLOCKED / NOT STARTED`.
