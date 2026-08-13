# ASCENDA OS — Zero-Cost Staging Certificate

Date: 2026-08-13
Scope: Sales Intelligence V2 — Phase A
Branch: `feat/sales-intelligence-v2-phase-a`
Status: **CERTIFIED FOR CANARY PREPARATION**

## Purpose

Provide a zero-cost, reproducible preproduction gate without connecting CI to Supabase production and without copying patient PII.

## Architecture

1. GitHub Actions checks out the PR merge candidate.
2. Supabase CLI `2.101.0` starts an ephemeral local Postgres/Supabase database.
3. A minimal public schema contract compiles the production migrations under test.
4. Sales Intelligence migrations are statically checked for read-only behavior.
5. Database lint runs at error level.
6. An isolated `zcs` schema exposes immutable PII-free fixture views.
7. The final optimized RPC is compiled against the isolated fixture schema.
8. pgTAP executes deterministic regression tests.
9. EXPLAIN ANALYZE + BUFFERS enforces a performance budget.
10. Evidence is uploaded as a short-lived GitHub Actions artifact.
11. The local Supabase database is destroyed after the run.

## Certified production aggregate contract

Cutoff: `2026-08-12`

- Sales: `1,275`
- Billed: `S/555,373.27`
- Services: `882` / `S/498,040.17`
- Products: `393` / `S/57,333.10`
- Invalid `OTROS` product classifications: `0`
- YTD target: `S/800,000.00`
- YTD attainment: `69.42%`
- August 1–12: `S/56,948.80`
- July 1–12: `S/32,839.05`
- Comparable MTD variation: `+73.42%`
- August projection: `S/147,117.73`
- Required daily pace to S/100,000: `S/2,265.85`

The fixture contains no real patient names, phones, DNI, emails, addresses or clinical records.

## Run evidence

Workflow: `ASCENDA Zero-Cost Staging`
Run ID: `31735264408`
Result: **SUCCESS**

Baseline workflow: `Ascenda CI`
Run ID: `31735264685`
Result: **SUCCESS**

Database regression:
- pgTAP files: `1`
- tests: `37`
- result: **37/37 PASS**

Database lint:
- result: **No schema errors found**

Migration contracts:
- Phase A summary migration: PASS
- Phase A optimized migration: PASS
- final RPC: `STABLE`
- final RPC: `SECURITY INVOKER`
- final migration rejects direct mutation of `public.aos_ventas`
- optimized definition does not use `v.*`

Performance gate on the immutable synthetic contract:
- execution time: `10.214 ms`
- measured buffers: `1,132`
- maximum allowed execution: `250 ms`
- maximum allowed buffers: `1,500`
- result: **PASS**

Evidence artifact:
- artifact ID: `9194873960`
- SHA-256: `1c030b0b6f9e9b68f59d964b7d251dfda98f53f2f94939e8a2fccf55b2dcf41d`
- retention: 14 days

## Safety properties

- No CI secret points to Supabase production.
- No production database password is required.
- No production rows are copied into CI.
- No historical sales are modified by the Phase A migrations.
- Existing `admin-sales.html` remains the production fallback.
- `admin-sales-intelligence.html` remains a shadow/canary surface until the release gate is approved.
- The local database is deleted after every run.

## Important scope boundary

The repository does not yet contain a complete migration history from the original creation of the ASCENDA database. Therefore this gate intentionally certifies the **Sales Intelligence Phase A database contract and the migrations in its release scope**, not a full-from-zero reconstruction of every historical ASCENDA table.

This is not treated as hidden coverage. A future control task must capture/version a full schema baseline so `supabase db reset` can reconstruct the entire database from repository history.

## Certification decision

Within the declared Phase A scope, every mandatory Zero-Cost Staging gate passed. Sales Intelligence V2 Phase A is approved to move to the next release stage: **canary preparation**, with production checksum and rollback gates still mandatory before activation.
