# Revenue Data & Intelligence — phase gates 2026-08-15

## F1 — Sales Intelligence V2 Foundation
CLOSED 100%. Preserve admin/2FA/read-only behavior and regression checks.

## F2 — Cartera Foundation
Core merged. Operational acceptance closes inside F4 after Auth V3 visibility, candidates/reconciliation and SI/PL smoke.

## F3 — Product Canonical
PRODUCTION CERTIFIED 100%. Do not reopen without demonstrated regression.

## F4 — Revenue Operations V1
Exit only when Ventas+Producto, Cartera, Importar and Caja operate through current protected contracts; owner smoke passes; no fake data is created; legacy revenue mutations are cut over safely; recovery is fail-closed.

## F5 — Historical Client & Sales + Patient Identity
Entry requires F4=100%. CSVs: inventory → profiling → non-destructive normalization → evidence-based identity → conflict preview → human approval → idempotent import → F3/F4 reconciliation → coverage report.

## F6 — Sales Intelligence 3.0
Entry requires F5 certified. Exit requires multi-year explainable analytics, coverage/freshness/sample-size gates and production visual acceptance.

## F7 — Governed Commercial Automation
Entry requires reliable F4-F6. Exit requires validated identity, confirmed balances, consent/policy, audit, rate/contact controls, human approval where required and rollback.
