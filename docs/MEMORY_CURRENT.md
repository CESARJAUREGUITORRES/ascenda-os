# ASCENDA OS — MEMORY CURRENT

**Captured from exact baseline:** `main@40b2cbf50a9ffc2d9ca1ee3fedbf457c133c4a21`  
**Captured:** 2026-08-19 America/Lima  
**ACTIVE WORKSTREAM:** `REV-F5-CLOSEOUT`

## Authority

Read in order:

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`
6. `docs/control/REV_F5_LEARNING_INTERCONNECTION_CURRENT_20260819.md`
7. exact GitHub + live Supabase/Railway
8. `aos_memory`
9. Notion

Historical documents/chat checkpoints never override CURRENT or live persisted state.

## Global state

MKT Integrity V3 Loop 5 is closed; Loop 6 is not started. The owner handed the global mutable lock back to Revenue. `REV-F5-CLOSEOUT` is the only active HIGH/CRITICAL mutable workstream.

Production runtime chain remains:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`.

Do not change runtime topology as part of F5 unless a demonstrated blocker requires it and exact-chain regression evidence is added.

## REV-F5 LIVE truth

Fresh Supabase production readback proves:

- manifests: **6**;
- expected source rows: **15,498**;
- persisted source rows: **8,264**;
- remaining rows: **7,234**;
- staging-complete batches: **1 / 6**;
- provisional identity clusters: **3,950**;
- identity members: **0**;
- patient link previews: **0**;
- canonical apply events: **0**;
- structural duplicate `(batch_id, source_row_num)` keys: **0**;
- orphan source rows: **0**;
- observational canonical patients: **7,685**.

Per source:

- PL2024: **3,949 / 4,192** — missing Excel 3951–4193;
- PL2025: **1,801 / 3,053** — missing Excel 1703–1802 and 1903–3054;
- PL2026: **993 / 993** — complete;
- SI2024: **1,521 / 3,190** — missing Excel 1523–3191;
- SI2025: **0 / 3,066** — missing Excel 2–3067;
- SI2026: **0 / 1,004** — missing Excel 2–1005.

All six original private XLSX files remain source-of-truth inputs and their manifest SHA values remain the identity of each source.

## Superseded false-closeout claim

A prior assistant narrative stated that REV-F5 had reached 15,498/15,498, rebuilt 15,498 members, completed Review/Apply and was production-certified.

That narrative is **invalid** because live Supabase post-conditions do not support it and GitHub has no merged REV-F5 final-certification PR after #298.

Institutional rule:

**No tool response, local loop, assistant statement, expected counter or generated payload may close a data gate without persisted production readback + independent invariant query.**

## Persistence Triple-Proof

Every F5 data checkpoint requires:

1. execution receipt;
2. direct live persisted delta;
3. independent invariant query.

Every source-batch closure additionally requires full idempotent replay of the exact SHA-bound source with zero new inserts/conflicts.

Timeout/blocked call → read live state before retry. Never infer persistence.

## REV-F5 execution point

REV-F5 remains **ACTIVE / NOT CERTIFIED**.

Correct next sequence:

1. finish the exact missing staging ranges from live state;
2. certify each source with structural checks + full replay;
3. require 15,498/15,498 and 6/6 complete;
4. only then run identity rebuild and require 15,498 members;
5. classify MATCH/REVIEW/NEW conservatively;
6. generate fill-only enrichment preview;
7. run governed Review/Apply with 2FA, dry-run, canary and rollback proof;
8. calculate patient→sale→F3 product→F4 payment/cartera linkage;
9. state real transaction coverage for 2024–2025;
10. numeric Coverage/DQ;
11. independent F5.10 final certification.

REV-F6 stays blocked until that final audit passes.

## Cross-domain architecture to preserve

Do not create competing identity/revenue truth.

- **F3:** canonical product/service identity for sales.
- **F4:** payment/revenue/cartera/reconciliation truth.
- **F5:** historical patient identity, provenance and governed canonical enrichment.
- **F6:** intelligence derived from certified F3/F4/F5 facts.
- **CIA:** acquisition/activation attribution using governed explicit evidence.
- **WA:** conversation product consuming permitted identity/commercial context.

Existing explicit bridges include `lead_id_origen`, `llamada_id_origen`, `venta_id_match`, sale IDs, `cotizacion_id`, plan/item IDs and `numero_limpio`. Prefer explicit IDs; `numero_limpio` remains a bridge, never merge authority by itself.

## Future historical sales 2024–2025

The architecture is ready to accept future transaction exports without redesigning identity/product/revenue.

Use `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`:

`source manifest/SHA → row provenance/staging → canonical sale → F3 product → F5 patient → F4 payment/cartera → F6 intelligence`.

Do not fabricate 2024/2025 YoY from patient history or `Último presupuesto` while certified transaction sources are absent.

## Safety rules specific to F5

- no canonical patient mutation before complete provenance, preview and governed review gate;
- no merge by name alone;
- phone alone is not merge authority;
- source patient IDs/HC remain source-specific unless proven otherwise;
- fill-only enrichment by default;
- clinical notes/allergies stay outside automatic commercial apply;
- `Último presupuesto` is evidence only;
- `ADELANTO` is payment evidence only;
- every retry reconciles persisted state first;
- every gate records exact SHA, live counters, missing ranges, protected-table invariants and next step.

## Institutional learning

- one global HIGH/CRITICAL mutable workstream;
- exact-current revalidation after unrelated `main` advances;
- runner/job activity is execution state, not source of truth;
- code/pipeline completion is not data completion;
- staging completeness precedes identity rebuild;
- local/generated success must never be promoted to production certification without live post-conditions;
- production Supabase + exact GitHub/CI/deploy evidence outrank documentation;
- documentation must explicitly supersede false or stale claims rather than silently preserving them;
- Notion is reconciled last.
