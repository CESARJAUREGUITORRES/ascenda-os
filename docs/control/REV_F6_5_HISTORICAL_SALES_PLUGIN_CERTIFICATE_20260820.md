# REV-F6.5 — Historical Sales Plug-in — TERMINAL CERTIFICATE 2026-08-20

**Status:** TERMINAL CANDIDATE — LIVE HARDENING PASS / FINAL EXACT-HEAD CI PENDING  
**Workstream:** REV — Revenue Data & Intelligence Core  
**Phase:** REV-F6.5 — Historical Sales Plug-in  
**Terminal hardening PR:** #316  
**Entry main for hardening:** `70bd591a2f4da7a39e41819416af40af4a694b29`  
**Validated hardening head before this certificate:** `74c9c0d98d4d75609775c380b60b20c1d72707e1`

## 1. Certified boundary

REV-F6.5 provides the dynamic Historical Sales Plug-in contract without fabricating historical revenue. The governed future pipeline remains:

`MANIFEST/SHA -> ROW PROVENANCE -> STAGING -> DEDUP/VALIDATION -> AOS_VENTAS-COMPATIBLE CANONICAL SALE -> F3 PRODUCT -> F5 PATIENT -> F4 FINANCIAL -> RECOMPUTE F6`.

No parallel historical patient/product/revenue master is introduced. A source manifest proves source coverage, not revenue. 2024/2025 values remain null until canonical transactional evidence exists.

## 2. Terminal cross-workstream fingerprint hardening

Post-merge verification of PR #315 found that the REV-F6.0 certification fingerprint included mutable cardinality/freshness from `aos_cia_contact_identity_v1`. That compatibility view spans patient, lead, call, appointment and sale activity, so normal CIA/WA activity could invalidate the REV-F6 chain without changing Revenue truth.

PR #316 corrects this by retaining all compatibility metrics visibly while excluding only these volatile observations from the REV certification hash:

- `compatibility_identity.rows`
- `compatibility_identity.with_canonical_patient`
- `compatibility_identity.identity_conflicts`
- `freshness_sources.cia_identity_updated_at`

Fingerprint semantic: `REVENUE_TRUTH_EXCLUDES_MUTABLE_CIA_COMPATIBILITY_CARDINALITY`.

A synthetic no-write LIVE probe proved both conditions simultaneously:

- legacy full-payload hash reacts to synthetic CIA churn: **true**;
- isolated Revenue hash remains stable under the same synthetic churn: **true**.

## 3. Exact-head CI before LIVE hardening

Exact-head `74c9c0d98d4d75609775c380b60b20c1d72707e1` passed all seven required workflows:

- Ascenda CI #2679 — SUCCESS
- REV-F6.0 #48 — SUCCESS
- REV-F6.1 #48 — SUCCESS
- REV-F6.2 #27 — SUCCESS
- REV-F6.3 #18 — SUCCESS
- REV-F6.4 #13 — SUCCESS
- REV-F6.5 #5 — SUCCESS

The dedicated F6.5 DB job passed migration, F6.3/F6.4 post-isolation rebaseline, fixtures A–J, F6.5 invariants, cross-workstream isolation, full idempotent replay and recovery to the pre-hardening F6.4 boundary.

## 4. Supabase LIVE migrations

Active terminal migration ledger:

- `20260820201634` — `rev_f6_5_historical_sales_plugin_v1`
- `20260820211638` — `rev_f6_5_rev_f6_0_fingerprint_isolation_v1`

No historical source manifest was registered in LIVE and no historical business sale row was fabricated by either migration.

## 5. Final LIVE fingerprint chain

The post-hardening chain was reproduced twice with exact equality:

- REV-F6.0: `f81a1b8fcfe010cd5254c4ab2e6048d2`
- REV-F6.3: `186a1da2c29b498dad26223ae264adea`
- REV-F6.4: `54c07961f191147860f6acd3a3e85c2a`
- REV-F6.5: `88957cec3d785e4931a8f834c0259a91`

A governed `aos_rev_historical_recompute_v1()` replay preserved F6.3, F6.4 and F6.5 fingerprints exactly and did not mutate protected business truth.

## 6. Protected truth and legitimate LIVE growth

At the terminal hardening deployment boundary LIVE contained:

- patients: **7,690**;
- canonical sales: **1,299**;
- F3 product facts: **406**;
- F4 reconciliation rows: **162**;
- F6.4 sales fact rows: **1,299**.

The previous F6.5 checkpoint contained 7,688 patients. The two-row increase was investigated before applying the hardening: exactly **2 patient rows were created after the PR #315 merge**, with the first at `2026-08-20 20:47:40.27904+00` and the latest at `2026-08-20 21:06:21.982437+00`. They are legitimate subsequent LIVE activity and were not created by this hardening. They were not deleted or rolled back.

The hardening preserved **7,690 -> 7,690** patients and **1,299 -> 1,299 / 406 -> 406 / 162 -> 162** across governed recompute.

## 7. Historical coverage truth

Current LIVE coverage remains:

- 2024: `value=null`, `source_status=NO_CERTIFIED_SOURCE`;
- 2025: `value=null`, `source_status=NO_CERTIFIED_SOURCE`;
- 2026: available through the canonical 1,299-sale read model.

`NO_CERTIFIED_SOURCE` is not interpreted as zero revenue.

## 8. Security / ACL

Terminal LIVE ACL readback PASS:

- F6.0 internal contract anon EXECUTE: false;
- isolated fingerprint helper authenticated EXECUTE: false;
- F6.0 service_role EXECUTE: true;
- historical manifest anon/authenticated SELECT: false;
- source registration anon EXECUTE: false;
- recompute authenticated EXECUTE: false;
- internal Sales Intelligence V3 anon EXECUTE: false;
- governed Sales Intelligence V3 gateway anon EXECUTE: true through the existing authorization boundary;
- legacy `aos_paciente_360(text)` anon EXECUTE: false.

## 9. Performance

Post-hardening LIVE `EXPLAIN ANALYZE` execution times:

- global 2026: **3.211 ms**;
- San Isidro: **138.042 ms**;
- Pueblo Libre: **10.591 ms**.

All are below the `<1000 ms` certification target. No timeout increase was used.

## 10. Remaining terminal gate

This certificate is the terminal candidate to be committed atomically with its snapshot. After that commit, its new exact-head must again pass Ascenda CI + REV-F6.0 through REV-F6.5. PR #316 may then merge only with `expected_head_sha` equal to that final certificate commit. Post-merge LIVE must reproduce the fingerprint chain, ACL, performance, historical no-source semantics and current protected truth. `aos_memory`, Notion and GitHub CURRENT are reconciled last.

Only after those gates declare:

`REV-F6.5 — PASS / CERTIFIED — 100%`

`REV-F6 global = 75%`

`REV-F6.6 — Sentinel Data-Integrity Handoff = NEXT / UNBLOCKED`
