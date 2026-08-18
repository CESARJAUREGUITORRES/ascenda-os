# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / explicit owner assignment  
**Owner assignment:** 2026-08-17 Lima — execute the definitive REV-F5 closeout now  
**Baseline before handoff:** `main@101b44bb8d69d9c9066a2910c68b42b3dbd6aea0`  
**Previous lock:** `WA-NOTIFICATIONS-CLOSEOUT` — CLOSED / regression-only after S15.5 physical certification  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**NEXT LOCK:** `UNASSIGNED` until REV-F5 is production-certified.

## Handoff evidence

WhatsApp/Notifications S15.5 is closed and no longer owns the global mutable lock. The certified closeout includes PR #281 merge `101b44bb8d69d9c9066a2910c68b42b3dbd6aea0`, exact Railway deploy success, fresh PWA subscription, closed-PWA Web Push `DELIVERED`, Windows notification/deep-link proof, no duplicate notification, and final legacy notification ACL cutover.

The owner subsequently issued an explicit command to execute the definitive Revenue F5 closeout while no other HIGH/CRITICAL workstream is intentionally mutating ASCENDA. That command is the authorization for this handoff.

## Global rule

At most **one HIGH/CRITICAL feature/data workstream may mutate ASCENDA at a time**.

Canonical namespaces: `CIA-F*`, `REV-F*`, `WA-*`, `SEN-F*`, `K*`, `PARITY-*`, `BASELINE-*`, `CONTROL-*`.

While `REV-F5-CLOSEOUT` owns the lock:

- Revenue F5 historical ingest, identity rebuild, preview, governed apply, reconciliation and certification may mutate only within the approved F5 closeout gates;
- WhatsApp Revenue Hub V2, CIA, KronIA and other HIGH/CRITICAL programs remain read-only/documentation-only unless REV-F5 explicitly requires a regression check;
- Sentinel remains closed/regression-only;
- no competing migrations, materializers, canaries, deploys or production data imports may be intentionally started;
- shared runners are execution capacity, never source of truth;
- an unrelated advance of `main` invalidates pending exact-head REV-F5 certification until its diff is revalidated.

## REV-F5 live baseline at lock acquisition

Production Supabase rebaseline immediately before the handoff:

- six source manifests / 15,498 expected rows;
- `aos_f5_patient_source_rows_v1 = 1,000`;
- 14,498 source rows still pending ingestion;
- `aos_f5_identity_clusters_v1 = 3,950` provisional;
- `aos_f5_identity_cluster_members_v1 = 0`;
- `aos_f5_patient_link_preview_v1 = 0`;
- `aos_f5_canonical_apply_events_v1 = 0`;
- `aos_pacientes = 7,675`;
- temporary F5 private transport = 0 rows / 0 payload bytes;
- duplicate `(batch_id, source_row_num)` keys = 0;
- orphan source rows = 0.

The six original XLSX sources were recovered from the private file library and their SHA-256 values match the production manifest exactly:

- `PUEBLO LIBRE 2024.xlsx` — `d65df2f66f2912084fe261298ac88ede123c50eef0a74e64a1f22e437a34680c` — 4,192 rows;
- `PUEBLO LIBRE 2025.xlsx` — `80761f481735dd18665265e7348b266335167d72e597d8124b4342f31d67b050` — 3,053 rows;
- `PUEBLO LIBRE 2026.xlsx` — `ab9239f2dc9db03f42e8c5b2ec6182bc7e66891a52bf1ab548911194ba261f1b` — 993 rows;
- `SAN ISIDRO 2024.xlsx` — `8fd1ea53e98856e8569328991b0c94f9dda1ebd8cf5a34713a42c3e99df42438` — 3,190 rows;
- `SAN ISIDRO 2025.xlsx` — `a59fdb6fbf2c82d62a7bf30ce82d18a7aa52601e4a35069d01052bc52542785b` — 3,066 rows;
- `SAN ISIDRO 2026.xlsx` — `7cbd86e4dbbd4154882240463bcb2c4424b3962a054155ef553a5fdfea174f5b` — 1,004 rows.

Any older checkpoint claiming F5 `15,498/15,498` or `100%` is superseded until production live evidence proves those gates again.

## Mandatory REV-F5 closeout sequence

1. F5.0 exact-current rebaseline and lock acquisition.
2. F5.1 complete the remaining 14,498 source rows through one private idempotent path.
3. F5.2 certify all six batches at exactly 15,498/15,498 with zero structural duplicate/orphan/mismatch defects.
4. F5.3 rebuild identity from complete provenance and require 15,498 members.
5. F5.4 classify every cluster as MATCH / REVIEW / NEW with auditable evidence.
6. F5.5 generate fill-only enrichment preview; no silent overwrite of non-null canonical values.
7. F5.6 dry-run, limited canary, rollback proof and governed Review & Apply.
8. F5.7 certify patient → sale → canonical product F3 → payment/revenue/cartera F4 linkage according to available evidence.
9. F5.8 audit transactional sales sources for 2024–2025; integrate if real and accessible, otherwise document the coverage limitation and prohibit unsupported YoY claims.
10. F5.9 emit numeric Coverage & Data Quality Report.
11. F5.10 independent final exact-head/live certification; only then `REV-F5 = PRODUCTION CERTIFIED — 100%` and F6 may be unblocked.

## Safety invariants

- no merge by name alone;
- source-specific patient ID and HC are not global identity keys without evidence;
- phone alone does not authorize a merge;
- `Último presupuesto` is evidence only, never automatic payment/debt/balance;
- `ADELANTO` is payment evidence, never automatic debt;
- clinical notes/allergies stay out of automatic commercial enrichment;
- every retry reconciles persisted state first and must be idempotent;
- do not cancel or duplicate a valid active runner job; identify run/branch/SHA/checkpoint first;
- never expose patient PII, service-role keys, tokens or source workbooks in GitHub/public artifacts.

## Runner / main-moving policy

Before each write gate, re-read `main` and classify relevant runner/deploy activity. A mutable job owned by another workstream blocks the next REV-F5 write. A timeout never proves that nothing was persisted; reconcile live state before retry. If `main` moves, stop new REV-F5 mutations, inspect the diff, revalidate compatibility and repeat affected gates before continuing.

## Handoff rule

Do not move this lock automatically. REV-F5 releases it only after F5.10 is certified from exact GitHub + CI/deploy evidence + live Supabase invariants + rollback/recovery + final GitHub CURRENT + `aos_memory` + Notion reconciliation, or after an explicit owner directive that safely aborts/pauses the workstream with a recoverable checkpoint.
