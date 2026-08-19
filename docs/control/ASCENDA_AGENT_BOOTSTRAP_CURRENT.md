# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Captured from baseline:** `main@40b2cbf50a9ffc2d9ca1ee3fedbf457c133c4a21`  
**Captured:** 2026-08-19 America/Lima  
**ACTIVE WORKSTREAM:** `REV-F5-CLOSEOUT`

## Mandatory bootstrap

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. `docs/MEMORY_CURRENT.md`;
6. `docs/adn/AGENTS_CURRENT.md`;
7. for Revenue/F5 or data-pipeline work: `docs/control/REV_F5_LEARNING_INTERCONNECTION_CURRENT_20260819.md`;
8. exact GitHub `main`, relevant branch/PR/checks, Railway deploy/runtime and live Supabase;
9. current Control Maestro/checkpoint for the selected workstream only.

Historical docs/chat output never override exact CURRENT + live production.

## Portfolio ownership

`REV-F5-CLOSEOUT` owns the single global HIGH/CRITICAL mutable lock.

MKT Integrity Loop 5 is closed; Loop 6 is not started. CIA, WA feature work, KronIA and unrelated schema/data work remain read-only/regression-only until explicit handoff.

## REV-F5 entry truth

Fresh production state at this capture:

- expected = **15,498**;
- staged = **8,264**;
- remaining = **7,234**;
- complete batches = **1/6**;
- clusters = **3,950 provisional**;
- members = **0**;
- previews = **0**;
- apply events = **0**;
- structural duplicates = **0**;
- source-row orphans = **0**.

Per batch:

- PL2024 3,949/4,192;
- PL2025 1,801/3,053;
- PL2026 993/993;
- SI2024 1,521/3,190;
- SI2025 0/3,066;
- SI2026 0/1,004.

Therefore REV-F5 is **ACTIVE / NOT CERTIFIED** and REV-F6 remains blocked.

## Mandatory data-certification rule

Do not close a data gate because a tool/RPC/local loop says `success`.

Require:

1. execution receipt;
2. direct live production readback;
3. independent invariant query.

At source-batch closure additionally require full idempotent replay of the exact SHA-bound source with zero new inserts/conflicts.

If a call times out, is truncated, is blocked by an intermediary or has ambiguous result: query the persisted state first. Never infer persistence from intent or output text.

## Recovery pattern

`OBSERVE LIVE → IDENTIFY EXACT GAP → MUTATE ONLY THAT GAP → READ BACK → VERIFY → CHECKPOINT → CONTINUE`.

If persisted content conflicts with the source, isolate the exact range, repair only that range, replay and continue. Do not restart valid history for convenience.

## Identity + interconnection boundary

- F3 owns product identity;
- F4 owns payment/revenue/cartera semantics;
- F5 owns historical/canonical patient identity + provenance;
- F6 will consume certified F3/F4/F5 facts;
- CIA owns governed acquisition attribution;
- WA owns conversation/channel UX.

Do not build another customer identity engine inside CIA/WA/F6.

Prefer explicit links (`lead_id_origen`, `llamada_id_origen`, `venta_id_match`, sale IDs, cotización/plan/item IDs). `numero_limpio` is supporting/transversal evidence, not standalone merge authority.

## Future historical sales

When 2024–2025 sales exports become available, follow `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`.

They must extend the existing domains:

`source provenance → sale fact → F3 product → F5 patient → F4 payment/cartera → F6 intelligence`.

Do not infer missing transactions from patient history, Agenda or budgets.

## Certification rule

REV-F5 may be declared `PRODUCTION CERTIFIED` only after an independent final audit proves all declared F5.0–F5.10 gates from exact-head GitHub/CI/deploy + live Supabase, and CURRENT docs/aos_memory/Notion are reconciled afterward.

Until then, any earlier 100% claim is `SUPERSEDED_BY_LIVE_TRUTH`.
