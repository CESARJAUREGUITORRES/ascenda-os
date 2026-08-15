# Revenue Data & Intelligence — CURRENT 2026-08-15

Canonical order: F1 Sales Intelligence V2 Foundation → F2 Cartera Foundation → F3 Product Canonical → F4 Revenue Operations V1 → F5 Historical Client & Sales + Patient Identity → F6 Sales Intelligence 3.0 → F7 Governed Commercial Automation.

## Status
- F1: CLOSED 100%.
- F2: technical core merged; operational acceptance is incorporated into the now-certified F4 boundary.
- F3: PRODUCTION CERTIFIED 100%.
- F4: **PRODUCTION CERTIFIED 100%** on 2026-08-15. Owner Cartera + Sales Intelligence canary passed; Auth V3 consumption verified; legacy Revenue mutations revoked; V4/V2 secure paths remain active; recovery remains fail-closed.
- F5: **CURRENT / NEXT EXECUTION**. Historical client/sales consolidation + Patient Identity is now unlocked.
- F6: blocked until F5 certifies the multi-year Patient Identity dataset.
- F7: blocked until F6 and governed policy/consent/balance gates.

## F4 closure evidence
- production code baseline before docs-only certification: `main` `7bfc2081d2608284c009291b44c4f2bb6def35d4`;
- PR #146 exact head passed Ascenda CI, F4, Sales Intelligence, Cartera, Cartera Hardening, WA-1, WA-2 and WA-3;
- owner visual canary: Cartera 162 active / 162 pending / S/0 confirmed; Sales Intelligence V2 active read-only;
- latest owner session: `PASSWORD_2FA`, active, backend `last_used_at` advanced;
- final cutover migration: `f4_revenue_operations_final_cutover_20260815`;
- legacy `aos_editar_venta`, `aos_importar_ventas`, `aos_grabar_venta_caja`, `aos_cartera_reconcile` no longer executable by `anon/authenticated`;
- secure V4/V2 replacements remain executable and validate Auth V3 internally;
- postflight: 1,293 sales; 162 Cartera pending; 0 confirmed debt; S/0 confirmed balance;
- final certification persisted in `F4_REVENUE_OPERATIONS_VALIDATION_REPORT_20260815.md`.

## F5 entry contract
Historical CSV/Excel sources are inventoried and profiled before any import. Identity resolution must be evidence-based and human-in-the-loop for ambiguous cases. Imports must be idempotent and preserve raw evidence/provenance. No bulk patient merge by name.

F5 execution order:
1. inventory files, years and source systems;
2. profile quality/coverage and column semantics;
3. non-destructive normalization;
4. duplicate/conflict detection;
5. patient identity resolution using phone/document/email and corroborating evidence;
6. merge preview + exception queue;
7. human approval of ambiguous identity;
8. idempotent historical import with provenance;
9. post-import reconciliation against canonical product and Cartera;
10. coverage/conflict report and F5 certification.

## F6 target
Multi-year YoY/seasonality, cohorts, LTV, recency/frequency/repeat, demographics/geography with coverage gates, affinity/cross-sell, and attribution where source/cost data are trustworthy.

## F7 target
Only validated identity, confirmed balances, consent/policy and auditable decisions may drive reactivation, next-best-offer, reminders or agents.

Notion CURRENT must mirror this checkpoint. GitHub + Supabase live remain the technical source of truth.
