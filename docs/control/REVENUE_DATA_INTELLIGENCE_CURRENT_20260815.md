# Revenue Data & Intelligence — CURRENT 2026-08-15

Canonical order: F1 Sales Intelligence V2 Foundation → F2 Cartera Foundation → F3 Product Canonical → F4 Revenue Operations V1 → F5 Historical Client & Sales + Patient Identity → F6 Sales Intelligence 3.0 → F7 Governed Commercial Automation.

## Status
- F1: CLOSED 100%.
- F2: core merged; final operational acceptance completes inside F4.
- F3: PRODUCTION CERTIFIED 100%.
- F4: IN PROGRESS. Ventas owner-visible and working; Cartera Auth V3 hotfix is current P0; Importar/Caja/final canary remain.
- F5: NEXT after F4=100%. Historical CSV ingestion is preserved.
- F6: blocked by F5 certified multi-year Patient Identity dataset.
- F7: blocked by F6 and governed policy/consent/balance gates.

## F4 remaining loop
1. isolate Cartera/F4 on `aos_app_token` Auth V3;
2. Cartera FAST + F4 FAST + baseline CI;
3. deploy exact code;
4. owner Cartera smoke + San Isidro/Pueblo Libre filters;
5. candidate matching/reconciliation smoke without creating a payment;
6. Importar preview smoke: idempotency, canonical product, REVIEW_REQUIRED, advances and possible duplicates;
7. Caja non-regression smoke without fake sale/payment;
8. verify Ventas and Sales Intelligence remain green;
9. controlled legacy-write cutover + fail-closed recovery proof;
10. Validation Report and F4=100%.

## F5 entry contract
Historical CSVs are inventoried and profiled first. Identity resolution must be evidence-based and human-in-the-loop for ambiguous cases. Imports are idempotent and preserve raw/provenance. No bulk merge by name.

## F6 target
Multi-year YoY/seasonality, cohorts, LTV, recency/frequency/repeat, demographics/geography with coverage gates, affinity/cross-sell, and attribution where source/cost data are trustworthy.

## F7 target
Only validated identity, confirmed balances, consent/policy and auditable decisions may drive reactivation, next-best-offer, reminders or agents.

Notion CURRENT: Revenue Data & Intelligence Core — Control Maestro and its phase database were updated on 2026-08-15. GitHub + Supabase live remain technical source of truth.
