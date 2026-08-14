# Phase 3 Product Canonical — CI

This suite is intentionally Zero-Cost CI V2 and must run only on:

`[self-hosted, Linux, X64, ascenda-zero-cost-v2]`

It validates additive product identity/alias/fact contracts without using production PII or mutating production. Historical source metrics are encoded only as product metadata and sale IDs.

Certification targets: 394 owner-reviewed rows, 388 product facts, 6 exclusions, 418 physical units, 43 promo/pack rows, 51 canonical product identities, locked split-payment corrections, fail-closed unknown handling, RLS/ACL and recovery.
