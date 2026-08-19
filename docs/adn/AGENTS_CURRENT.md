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
6. `docs/control/REV_F5_LEARNING_INTERCONNECTION_CURRENT_20260819.md`;
7. `docs/control/REV_F5_F6_IMPLEMENTATION_ROADMAP_CURRENT_20260819.md`;
8. patient identity/360/lifecycle contracts under `docs/control/REV_PATIENT_*` and `REV_CUSTOMER_LIFECYCLE_IDENTITY_CONFIDENCE_CONTRACT.md` when relevant;
9. exact GitHub `main`, Railway status/runtime and live Supabase state;
10. the current project checkpoint only.

Historical chat statements never override CURRENT or live persisted state.

## Portfolio Controller

Declare `WORKSTREAM_ID=REV-F5-CLOSEOUT`. Enforce one global HIGH/CRITICAL mutable workstream. CIA, WA feature releases, KronIA and unrelated Sentinel mutation remain read-only/regression-only while F5 owns the lock.

## Revenue / Patient Identity Agent

Current production truth at the registered baseline:

- 6 source batches / 15,498 expected rows;
- **8,264 persisted source rows**;
- **1/6 staging-complete batches**;
- 3,950 provisional clusters;
- 0 members;
- 0 link previews;
- 0 canonical apply events;
- 0 structural duplicate keys;
- 0 orphan source rows.

Always rederive LIVE before write. Do not claim REV-F5 production certification from local/tool execution output.

## Persistence Triple-Proof

A HIGH/CRITICAL data checkpoint closes only when all are true:

1. execution receipt;
2. direct production readback showing the persisted delta;
3. independent invariant query proving expected count/range/uniqueness/orphans/conflicts/protected-table state.

At batch closure also require full idempotent replay of the exact SHA-bound source with zero new inserts/conflicts.

`tool returned success` != `production persisted success`.

## Recovery loop

`OBSERVE LIVE → IDENTIFY EXACT GAP → MUTATE ONLY GAP → READ BACK → VERIFY → CHECKPOINT → CONTINUE`.

If a call times out or is blocked, reconcile persisted state before retrying.

## Canonical identity / duplicate rules

Historical rows are evidence, not canonical patients. The durable subject is `canonical_patient_id` once F5 certifies it.

- source patient ID/HC remain source-scoped unless proven global;
- name alone never merges;
- phone alone never merges;
- approximate/numeric-near phone is not evidence; phone ±3 heuristics are prohibited;
- exact normalized name+surname+phone+valid document with no strong conflicts may be `AUTO_ELIGIBLE_EXACT`, but physical merge remains CRITICAL/governed;
- same valid document + compatible person evidence with changed phone can be `REVIEW_STRONG`/verified after review;
- conflicting document/DOB/sex or identifier already bound elsewhere = `BLOCK_CONFLICT`;
- absorbed phones/emails/source IDs remain aliases/provenance;
- no physical merge without admin+2FA, dependency audit, dry-run, canary, immutable audit event and rollback/recovery.

Current read-only duplicate profile at registration: 174 same-name groups; 69 span multiple phones; 57 span multiple documents; 14 groups/29 rows matched exact name+surname+phone+document. Recompute before action.

Legacy `aos_duplicados_paciente`/`aos_fusionar_pacientes` are evidence/legacy tools, not the new F5 batch authority until audited/versioned.

## Identity Bridge V2

Reuse existing `aos_cia_contact_identity_v1` for compatibility evidence but do not let its phone-centric contact key become the final identity model.

Target:

`phone/document/email/source-scoped ID/HC → governed alias/evidence → canonical_patient_id or REVIEW/CONFLICT/UNRESOLVED`.

CIA, WA, imports, Patient 360 and F6 consume this same identity; none creates a second customer identity truth.

## Patient Commercial 360 V2

Evolve existing `app/public/patients.html` / `aos_paciente_360`; do not create another patient panel/master.

Phone lookup remains supported, but backend resolution becomes:

`lookup identifier → Identity Bridge V2 → canonical_patient_id → all permitted aliases/history`.

V2 adds identity confidence/review state, lifecycle, commercial timeline, canonical product/revenue facts and metric trust (`coverage`, `confidence`, `freshness`, `sample_size`), while preserving role-gated PHI.

## REV-F6 lifecycle / trust contract

Prepare after real F5 certification:

- `NEW_PATIENT`
- `RETURNING_PATIENT`
- `HISTORICAL_REACTIVATED`
- `ACTIVE_REPEAT`
- `DORMANT`
- `UNRESOLVED_IDENTITY`

Every inferred/aggregate insight must carry period/coverage, confidence, freshness and sample size. Incomplete transaction history must reduce claim strength.

## Cross-domain rule

Canonical responsibilities:

- F3 = product identity;
- F4 = payment/revenue/cartera truth;
- F5 = patient identity + provenance + duplicate resolution;
- F6 = intelligence/read models from certified F3/F4/F5;
- CIA = governed acquisition/activation attribution;
- WA = conversation/channel product consuming permitted identity context;
- Sentinel = observation/integrity, never business truth.

Prefer explicit IDs (`lead_id_origen`, `llamada_id_origen`, `venta_id_match`, sale IDs, cotización/plan/item IDs) before identity-bridge fallback.

## Future 2024–2025 sales

Use `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`:

`source SHA/provenance → sales staging/dedup → canonical sale → F3 product → F5 patient → F4 payment/cartera → F6 recomputation`.

No parallel historical customer/product/revenue architecture and no unsupported YoY while ledgers are absent.

## Sentinel data-integrity handoff

Use `docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md`. Signals are aggregate/zero-PII and should detect source batch mismatch, membership mismatch, identity collision, apply without governance, product-sale orphan, reconciliation orphan and F6 freshness/coverage regression.

Sentinel observes and routes to the owning workstream; it does not silently repair production.

## Security Guardian

Use root `SECURITY.md`. Do not move PII/PHI through GitHub, logs or public artifacts. Never store real credentials in skills/docs/examples/prompts; use authorized auth/secret stores.

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
5. update `aos_memory` only after live baseline is proven;
6. update Notion last;
7. explicitly supersede incorrect historical claims.

## Release Certifier

REV-F5 cannot be `PRODUCTION CERTIFIED` and REV-F6 cannot be unblocked until a fresh independent final audit proves:

- 15,498/15,498 staging and 6/6 full source replays;
- 15,498/15,498 identity memberships;
- exhaustive MATCH/REVIEW/NEW plus duplicate resolution states;
- governed Identity Bridge V2 semantics / explicit conflicts;
- fill-only enrichment;
- governed Review/Apply and any physical patient consolidation with rollback evidence;
- patient→sale→F3 product→F4 payment/cartera coverage;
- explicit 2024–2025 transaction coverage statement;
- numeric coverage/DQ report;
- exact-head GitHub/CI/deploy + live Supabase reconciliation;
- CURRENT docs/aos_memory/Notion reconciled after live proof.

At real F5.10 PASS, return the rebound REV-F6 execution prompt from `docs/control/prompts/REV_F6_EXECUTION_PROMPT_TEMPLATE.md`; do not silently start F6.
