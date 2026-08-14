# Phase 3 Product Canonical — CI

This suite is intentionally Zero-Cost CI V2 and must run only on:

`[self-hosted, Linux, X64, ascenda-zero-cost-v2]`

It validates additive product identity/alias/fact contracts without using production PII or mutating production. Historical source metrics are encoded only as product metadata and sale IDs.

Certification targets: 394 owner-reviewed rows, 388 product facts, 6 exclusions, 418 physical units, 43 promo/pack rows, 51 canonical product identities, locked split-payment corrections, fail-closed unknown handling, automatic backfill for post-workbook product sales, one-to-one catalog identity unification, governed review queue, RLS/ACL and recovery. The dedicated pgTAP contract currently contains 34 assertions.

Owner authorization to complete the governed F3 loop was recorded on 2026-08-14. It does not permit bypassing the exact-SHA CI, preflight, recovery or post-cutover smoke gates.

PR #97 / ASCENDA Zero-Cost CI V2 is merged into CURRENT `main` at merge commit `c8b71d2d10aa913b81044ba58e8d09674cbe7ab3`. Phase 3 is retargeted to `main`; the latest branch head is the exact preproduction candidate and must pass the dedicated self-hosted gate before production cutover.
