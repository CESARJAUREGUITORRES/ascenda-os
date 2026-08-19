# ASCENDA OS — AGENTS CURRENT OVERLAY

**Applies to:** every CURRENT ASCENDA agent/chat  
**Captured:** 2026-08-19 America/Lima  
**ACTIVE WORKSTREAM:** `REV-F5-CLOSEOUT`

This overlay supersedes operational assumptions in historical `docs/adn/AGENTS.md` and earlier CURRENT snapshots while preserving them as provenance.

## Mandatory bootstrap

Before any write:

1. root `AGENTS.md` + `SECURITY.md`;
2. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
3. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
4. `docs/MEMORY_CURRENT.md`;
5. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`;
6. `docs/control/REV_F5_LEARNING_INTERCONNECTION_CURRENT_20260819.md` for REV-F5/data-pipeline work;
7. exact GitHub `main`, Railway status/runtime and live Supabase state;
8. the current project checkpoint only.

Historical chat statements never override CURRENT or live persisted state.

## Portfolio Controller

Declare `WORKSTREAM_ID=REV-F5-CLOSEOUT`. Enforce one global HIGH/CRITICAL mutable workstream. CIA, WA feature releases, KronIA and migration-governance mutation remain read-only/regression-only while F5 owns the lock.

## Revenue / Patient Identity Agent

Current production truth at this capture:

- 6 source batches / 15,498 expected rows;
- **8,264 persisted source rows**;
- **1/6 staging-complete batches**;
- 3,950 provisional clusters;
- 0 members;
- 0 link previews;
- 0 canonical apply events;
- 0 structural duplicate keys;
- 0 orphan source rows.

Do not claim REV-F5 production certification from local/tool execution output. The previous 15,498/15,498 / F5=100% narrative is superseded by live production evidence.

## Persistence Triple-Proof — mandatory for data work

A HIGH/CRITICAL data checkpoint may close only when all are true:

1. execution receipt says the intended mutation succeeded;
2. direct production readback shows the persisted delta;
3. an independent invariant query proves expected count/range/uniqueness/orphans/conflicts/protected-table state.

At batch closure also require full idempotent replay of the exact SHA-bound source with zero new inserts/conflicts.

`tool returned success` != `production persisted success`.

## Recovery loop

Use:

`OBSERVE LIVE → IDENTIFY EXACT GAP → MUTATE ONLY GAP → READ BACK → VERIFY → CHECKPOINT → CONTINUE`.

If a call times out or is blocked, reconcile persisted state before retrying. Never skip a range because an execution attempt looked successful.

## Identity rules

- historical rows are evidence, not canonical patients;
- source patient ID and HC are source-specific unless proven otherwise;
- name alone never merges;
- phone alone never merges;
- DNI+compatible name is strong evidence;
- email is strong evidence with compatible context;
- phone+name and name+DOB are supporting evidence;
- conflict/tie → human review;
- enrichment defaults to fill-only;
- clinical notes/allergies are excluded from automatic commercial apply;
- `Último presupuesto` = evidence only;
- `ADELANTO` = payment evidence only.

## Cross-domain rule

Do not build a second customer identity system in CIA, WA, F6 or historical-sales import.

Canonical responsibilities:

- F3 = product identity;
- F4 = payment/revenue/cartera truth;
- F5 = patient identity + provenance;
- F6 = intelligence derived from certified F3/F4/F5 facts;
- CIA = governed acquisition/activation attribution;
- WA = conversation/channel product consuming permitted identity context.

Prefer explicit IDs (`lead_id_origen`, `llamada_id_origen`, `venta_id_match`, sale IDs, cotización/plan/item IDs) before phone inference. `numero_limpio` is a bridge, not merge authority.

## Future 2024–2025 sales

When historical sales files arrive, use `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`.

Do not mass-insert them directly as trusted revenue. Require source SHA/provenance → sales staging/dedup → F3 product resolution → F5 patient resolution → F4 payment/cartera reconciliation → coverage report.

## Security Guardian

Use root `SECURITY.md`. Do not move PII/PHI through GitHub, logs or public artifacts. GitHub contains contracts/hashes/counts/rules, never raw patient rows.

## CI/Runner Governor

- runner activity is execution state, not source of truth;
- exact commit/diff + live production post-conditions are authority;
- another workstream PASS cannot close REV-F5;
- queued/pending is capacity evidence, not data completion;
- any unrelated `main` advance requires exact-head revalidation before the next mutable F5 gate.

## Historian / Memory Manager

At each material incident or gate:

1. freeze exact GitHub evidence;
2. read live production state;
3. record persisted counters/missing ranges/invariants;
4. update CURRENT docs;
5. update `aos_memory` only after the live baseline is proven;
6. update Notion last;
7. explicitly supersede incorrect historical claims instead of silently editing history.

Institutional lesson from REV-F5: a convincing execution transcript can still diverge from the database. Certification is a property of persisted post-conditions, not narrative completion.

## Release Certifier

REV-F5 cannot be `PRODUCTION CERTIFIED` and REV-F6 cannot be unblocked until a fresh independent final audit proves:

- 15,498/15,498 staging;
- 6/6 exact source replays;
- 15,498/15,498 identity memberships;
- exhaustive MATCH/REVIEW/NEW classification;
- fill-only enrichment rules;
- governed Review/Apply with rollback evidence;
- patient→sale→product→payment/cartera coverage;
- explicit 2024–2025 transaction-coverage statement;
- numeric coverage/DQ report;
- exact-head GitHub/CI/deploy + live Supabase reconciliation;
- CURRENT docs/aos_memory/Notion reconciled after live proof.

Until then: `REV-F5 = ACTIVE / NOT CERTIFIED`.
