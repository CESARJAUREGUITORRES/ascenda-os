# REV-F6.4 — Sales Intelligence 3.0 V1

**Status:** IMPLEMENTATION / PRE-LIVE  
**Entry main:** `10c8ebccb0be1d8e538491de834cb7457f453de9`  
**Owning workstream:** `REV-F6-CLOSEOUT`  
**Risk:** HIGH (read-model / analytics schema)  
**Production business-row writes:** NONE

## Objective

Build a performant, explainable Sales Intelligence 3.0 read layer from certified F3/F4/F5/F6.0–F6.3 facts. F6.4 does not create a second revenue, product or patient truth and does not infer 2024/2025 transactional revenue where no certified transactional source exists.

## Architecture

F6.4 materializes bounded, zero-PII analytical read models:

- `aos_rev_si_sales_fact_v1`: one row per 2026 sale with F5 identity linkage state, F3 product state and F4 evidence state.
- `aos_rev_si_monthly_v1`: monthly sede/advisor aggregation.
- `aos_rev_si_patient_value_v1`: MATCH-only observed patient value; this is observed value, never predicted lifetime value.
- `aos_rev_si_cohort_month_v1`: safe-identity cohort/repeat/time-to-second facts.
- `aos_rev_si_product_transition_v1`: canonical F3 next-product transitions with sample counts.
- `aos_rev_si_acquisition_fact_v1`: explicit `Agenda.venta_id_match + lead_id_origen` lineage only. Phone proximity/phone-only attribution is prohibited.

Primary service contract: `aos_rev_sales_intelligence_v3(anio,sede,asesor)`.  
Browser gateway: `aos_rev_sales_intelligence_v3_gateway(token,anio,sede,asesor)`, preserving the existing Sales Intelligence admin + 2FA gate.  
Refresh contract: `aos_rev_si_refresh_v1()`.  
Deterministic certification contract: `aos_rev_f6_4_contract_v1()`.

Patient Commercial 360 is augmented, not replaced. The certified F6.3 gateway is preserved privately and the public governed wrapper adds only bounded observed Sales Intelligence metadata.

## Metric semantics

### Executive Revenue
`aos_ventas.monto` remains observed billed revenue. F4 linkage is exposed as financial-evidence coverage. Because current certified F4 contains no confirmed collected-cash amount, `confirmed_collected_amount` remains `null`; `F4_LINKED != collected cash`.

Targets and projection are emitted only where a configured target exists.

### Cohorts / retention
Only `patient_link_status='MATCH'` contributes patient-level cohort/retention metrics. REVIEW and UNRESOLVED sales remain in executive billed revenue but cannot be silently attributed to a canonical patient.

### Observed LTV
The label is explicitly `OBSERVED_VALUE_NOT_LIFETIME_PREDICTION`. No future value model is presented as fact.

### Product / cross-sell
Only canonical F3 `RESOLVED` product facts support canonical product and next-product patterns. Samples remain explicit.

### Sede / Advisor
Performance uses direct sale fields. It does not imply patient-level attribution quality.

### Acquisition-to-Revenue
Only explicit sale lineage through `Agenda.venta_id_match` plus `lead_id_origen` qualifies. If no qualifying evidence exists, output is `NO_DEFENDABLE_ATTRIBUTION` with `value=null`, not zero.

### Demographic / geographic
The V1 contract requires field coverage >=70% and a minimum cell size of 5 before a dimension is enabled. Low-coverage dimensions remain disabled rather than appearing exact.

### Historical source
2024 and 2025 remain `NO_CERTIFIED_SOURCE`, `value=null`, and never mean zero revenue.

## Performance gate

Architecture target: `MATERIALIZED_READ_MODELS_PLUS_SET_BASED_AGGREGATION`.  
Certification threshold for the aggregate V3 RPC on the current data scale: max 1000 ms across repeated isolated-test calls. The target is a gate, not a timeout workaround.

## Security

All raw materialized read models and internal analytical functions are `service_role` only. Aggregate models contain no name, phone, email, document, clinical notes or message payloads. Browser access remains via existing admin Sales Intelligence authorization/2FA semantics.

## Impact Report
**Project / phase:** REV-F6.4 — Sales Intelligence 3.0  
**Objective:** performant governed revenue intelligence read models.  
**Risk:** HIGH

### Code/runtime
No Node runtime topology change and no frontend redesign in F6.4.

### Data/RPC/triggers
Additive materialized views/RPCs only. No patient/sale/F3/F4/F5 mutation. Refresh replaces derived MV contents only.

### Consumers/dependencies
Consumes certified F6.0/F6.1/F6.2/F6.3 and F3/F4/F5. Existing Sales Intelligence V2 remains backward-compatible during F6.4.

### Security/roles/sensitive data
Raw read models browser-closed. Aggregate V3 gateway reuses existing admin+2FA Sales Intelligence authorization. No raw PII/PHI in aggregate contracts.

### Tests
FAST static contract; Zero-Cost exact migration compile; upstream F6.3 regression; semantic reconciliation; ACL/PII negatives; refresh replay; performance; recovery.

### Rollback
Drop F6.4 functions/materialized views and restore the exact F6.3 Patient Commercial 360 public wrapper.

### Portfolio-lock impact
`REV-F6-CLOSEOUT` remains the only HIGH/CRITICAL mutable Revenue lane.

## Certification gates

1. Exact-head F6.4 CI + upstream F6.0/F6.1/F6.2/F6.3 + Ascenda CI green.
2. LIVE preflight anti-drift for protected patients/sales/F3/F4 and F6.0–F6.3 fingerprints.
3. Versioned F6.4 migration applied.
4. Direct LIVE readback + independent metric reconciliation.
5. ACL/no-PII/security invariants.
6. Performance gate.
7. F6.4 fingerprint reproduced twice.
8. Exact-head merge with `expected_head_sha`.
9. Post-merge LIVE fingerprint exact.
10. `aos_memory`, Notion and CURRENT synchronized last.

Only then: `REV-F6.4 PASS / CERTIFIED — 100%` and `REV-F6 global = 62.5%`.
