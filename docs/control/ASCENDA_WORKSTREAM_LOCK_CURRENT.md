# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-19 America/Lima  
**Entry baseline:** `main@754ab44f39f10123ab83b98f97b5c01fff25bab5`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F5.10 terminal fingerprint:** `2f0a365fae4caaa7be9d204e0f76679b`  
**CURRENT GATE:** `REV-F6.0 — DATA CONTRACT / LIVE PASS / FINAL EXACT-HEAD CI + MERGE + POST-MERGE READBACK PENDING`  
**REV-F6.1:** `BLOCKED until the REV-F6.0 terminal conditions below are satisfied`  
**REV-F7:** `BLOCKED until REV-F6 certification`

This is the single mutable Revenue execution pointer. GitHub CURRENT + Supabase LIVE remain authoritative over historical checkpoints.

## One-lock rule

At most one HIGH/CRITICAL mutable workstream may alter shared Revenue/current-state contracts. While `REV-F6-CLOSEOUT` owns the lane, other HIGH/CRITICAL workstreams remain read-only/regression/documentation-only unless explicitly required by F6 validation.

## Certified upstream boundary

REV-F1 through REV-F5 are closed. REV-F6 preserves these truth owners:

- F3 = canonical product truth;
- F4 = payment/revenue/cartera truth;
- F5 = patient identity + provenance truth;
- `aos_ventas` = canonical persisted sales ledger;
- `aos_cia_contact_identity_v1` = compatibility identity view only;
- F6 = derived intelligence/read models only.

Protected F5 state remains unchanged after the F6.0 LIVE migration:

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 fp = `5af139243f6aed37020048af292587fe`;
- F5.8 fp = `4ce1695532a57655179558ed2b5f78aa`;
- F5.9 fp = `5070c701d216eb839572bd70f530c2e6`;
- F5.10 terminal fp = `2f0a365fae4caaa7be9d204e0f76679b`.

## REV-F6.0 LIVE certification evidence

Pre-LIVE exact-head validated:

- PR #309 pre-LIVE head = `599da3206638786e162f0b6f001f56dffb4bb408`;
- CI run = `32322594175`;
- FAST contracts = **PASS**;
- DB/security contracts = **PASS**;
- isolated migration + security invariants + fail-closed recovery = **PASS**;
- `main` anti-drift before LIVE = **PASS**, still `754ab44f39f10123ab83b98f97b5c01fff25bab5`.

Supabase LIVE migration:

- ledger version = `20260820015805`;
- migration = `rev_f6_0_data_contract_v1`;
- business-row mutation = **0 by scope and protected-domain readback**.

Data Contract deterministic fingerprint:

`02ba53adb9dabfcd0a4557061be53c2f`

The fingerprint was produced twice in independent LIVE calls and remained identical.

### Source / identity boundary

- batches = **6 / 6 MATCHED**;
- source rows / memberships = **15,498 / 15,498**;
- clusters = **8,716**;
- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- Identity Coverage = **296 / 8,716 = 3.40%**.

### Sales / F3 / F4 coverage

- canonical sales = **1,299**, range **2026-01-05 → 2026-08-15**;
- sale identity MATCH / REVIEW / UNRESOLVED = **208 / 940 / 151**;
- Sales Linkage Coverage = **16.01%**;
- F3 RESOLVED / REVIEW_REQUIRED / EXCLUDED / MISSING / NOT_APPLICABLE = **397 / 3 / 6 / 0 / 893**;
- F3 Product Coverage = **97.78%** of 406 applicable sales;
- F4 linked / no reconciliation evidence = **123 / 1,176**;
- F4 reconciliation rows = **162**;
- F4 Financial Evidence Coverage = **9.47%**.

Low F4 coverage is a coverage gap, not proof of non-payment.

## REV-F6.0 security boundary — LIVE PASS

The legacy `aos_paciente_360(text)` had been browser-executable under `SECURITY DEFINER` while exposing broader patient/clinical/document domains than Citas consumes. F6.0 closes that path.

LIVE ACL readback:

- `aos_rev_f6_data_contract_v1()` → anon **false**, authenticated **false**, service_role **true**;
- `aos_patient_history_summary_v1(text,text)` → browser-callable compatibility gateway, with internal Auth V3 + `PASSWORD_2FA` + `advisor-patients`/`admin-patients` authorization;
- legacy `aos_paciente_360(text)` → anon **false**, authenticated **false**, service_role **true**;
- service-worker routing has no weak fallback;
- recovery remains fail-closed.

## Historical transaction semantics

- patient history 2024 / 2025 / 2026 = **AVAILABLE / AVAILABLE / AVAILABLE**;
- transactional sales 2024 = **NO_CERTIFIED_SOURCE**;
- transactional sales 2025 = **NO_CERTIFIED_SOURCE**;
- transactional sales 2026 = **AVAILABLE only 2026-01-05 → 2026-08-15**;
- `NO_CERTIFIED_SOURCE != 0`;
- unsupported 2024↔2025↔2026 factual YoY remains prohibited.

## Metric Trust boundary

All relevant F6-derived insights must expose or inherit:

`coverage + confidence + freshness + sample_size`

No-source, zero-observed, not-applicable and unknown states remain distinct.

Identity Bridge V2 remains **contract-frozen but not materialized LIVE** at F6.0; F6.1 must consume the certified F3/F4/F5/F6.0 boundary rather than create a competing identity truth layer.

## REV-F6.0 terminal transition rule

The LIVE gates are PASS, but terminal certification is fail-closed until all of these are true:

1. the PR head containing `REV_F6_0_DATA_CONTRACT_CERTIFICATE_20260819.md` passes exact-head CI;
2. `main` is revalidated unchanged before merge;
3. PR #309 is merged using that exact expected head SHA;
4. post-merge GitHub readback confirms the merged certificate/contract;
5. post-merge Supabase readback reproduces `02ba53adb9dabfcd0a4557061be53c2f` and all four protected fingerprints;
6. `aos_memory` CURRENT is persisted/read back;
7. Notion CURRENT is reconciled/read back.

**When and only when all seven conditions are satisfied, interpret this CURRENT pointer as:**

- `REV-F6.0 = PASS / CERTIFIED`;
- `REV-F6.1 = NEXT / UNBLOCKED`;
- `REV-F6-CLOSEOUT` remains the active Revenue lock;
- `REV-F7` remains blocked.

## REV-F6 roadmap

1. F6.0 Data Contract — **LIVE PASS / terminal closeout pending**.
2. F6.1 Patient Commercial 360 V2 — blocked until terminal F6.0 PASS.
3. F6.2 Customer Lifecycle.
4. F6.3 Identity Confidence + Metric Trust.
5. F6.4 Sales Intelligence 3.0.
6. F6.5 Historical-sales plug-in, only for certified sources.
7. F6.6 Sentinel Data Integrity handoff.
8. F6.7 Final certification.

`REV-F6-CLOSEOUT` remains assigned until F6.7 or an explicit owner handoff. F6.0 completion does not release the global Revenue F6 lane.
