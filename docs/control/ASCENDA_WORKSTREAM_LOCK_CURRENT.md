# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 REACTIVATED  
**Owner assignment:** 2026-08-18 Lima — resume definitive REV-F5 closeout from reconciled persisted state  
**Certified hotfix merge:** `main@41e1dbb97a6862ea2137ae13004ed50612263dba` / PR #283  
**Previous lock:** `HOTFIX-CALLS-AGENDA-MARKETING-20260818` — CLOSED / PRODUCTION CERTIFIED  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**NEXT LOCK:** `UNASSIGNED` until REV-F5 is production-certified.

## Owner authorization and handback

The owner explicitly authorized a temporary pause of REV-F5, execution of the Calls–Agenda–Marketing hotfix, and immediate reactivation of REV-F5 after certification. That hotfix is now closed and the global mutable lock is returned to `REV-F5-CLOSEOUT` without requiring further owner confirmation.

Canonical hotfix evidence:

- `docs/control/CALLS_AGENDA_MARKETING_HOTFIX_20260818.md`;
- `docs/control/CALLS_AGENDA_MARKETING_HOTFIX_CERT_20260818.md`;
- production migrations `calls_agenda_marketing_hotfix_20260818` and `calls_agenda_marketing_direct_trace_links_20260818`;
- PR #283 merged at `41e1dbb97a6862ea2137ae13004ed50612263dba`.

The hotfix certified Mireya at four genuine conversions for 2026-08-18: three paid Marketing + one Organic; Agenda-only/manual continuation no longer persists artificial Call Center calls; rapid duplicates are server-guarded; validated paid links resolve through direct IDs at confidence 100; eight proven duplicate/fabricated call rows were fully audited before deletion.

## Global rule

At most **one HIGH/CRITICAL feature/data workstream may mutate ASCENDA at a time**.

Canonical namespaces remain `CIA-F*`, `REV-F*`, `WA-*`, `SEN-F*`, `K*`, `PARITY-*`, `BASELINE-*`, `CONTROL-*`.

While `REV-F5-CLOSEOUT` owns the lock:

- Revenue F5 historical ingest, identity rebuild, preview, governed apply, reconciliation and certification may mutate only within the approved F5 closeout gates;
- Calls / Agenda / Marketing hotfix is closed and regression-only;
- WhatsApp Revenue Hub V2, CIA, KronIA and other HIGH/CRITICAL programs remain read-only/documentation-only unless REV-F5 explicitly requires a regression check;
- Sentinel remains closed/regression-only;
- no competing migrations, materializers, canaries or production data imports may be intentionally started;
- shared runners are execution capacity, never source of truth;
- any advance of `main` requires exact-head revalidation before the next REV-F5 write.

## REV-F5 resume state — live revalidated after hotfix

Production Supabase project `ituyqwstonmhnfshnaqz` immediately before this handback:

- source manifests: **6**;
- expected source rows: **15,498**;
- `aos_f5_patient_source_rows_v1`: **7,064**;
- rows still pending ingestion: **8,434**;
- `aos_f5_identity_clusters_v1`: **3,950** provisional;
- `aos_f5_identity_cluster_members_v1`: **0**;
- `aos_f5_patient_link_preview_v1`: **0**;
- `aos_f5_canonical_apply_events_v1`: **0**;
- `aos_pacientes`: **7,679**;
- temporary F5 private transport rows: **0**;
- temporary chat gzip rows: **0**;
- temporary chat PGP rows: **0**;
- temporary chat credential rows: **0**.

These values exactly match the recoverable pause checkpoint. The hotfix did not mutate F5-owned tables or the patient population.

**Resume rule:** reconcile persisted state first, then continue F5.1 from **7,064/15,498 or any higher idempotently persisted state discovered at the next read-back**. Never restart from the obsolete 1,000-row snapshot and never duplicate a previously persisted source row.

## Mandatory REV-F5 closeout sequence

1. F5.0 exact-current rebaseline and lock confirmation.
2. F5.1 complete the remaining source rows through one private idempotent path.
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

This handback control commit itself advances `main` beyond hotfix merge `41e1dbb...`. Before the next REV-F5 write, re-read current `main`, inspect any runner/deploy activity, and certify exact-head compatibility. A timeout never proves that nothing persisted; always reconcile live F5 source rows before retry.

## Handoff rule

REV-F5 releases the lock only after F5.10 is certified from exact GitHub + live Supabase invariants + rollback/recovery + final control/memory reconciliation, or after another explicit owner-authorized recoverable pause.
