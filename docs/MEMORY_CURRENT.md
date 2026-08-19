# ASCENDA OS — MEMORY CURRENT

**Captured from exact baseline:** `main@1d964d99f018cbdb671ddce90e52ece6bac0a8bd`  
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
7. `docs/control/REV_F5_F6_IMPLEMENTATION_ROADMAP_CURRENT_20260819.md`
8. `docs/control/REV_PATIENT_IDENTITY_BRIDGE_V2_CONTRACT.md`
9. `docs/control/REV_PATIENT_COMMERCIAL_360_V2_CONTRACT.md`
10. `docs/control/REV_CUSTOMER_LIFECYCLE_IDENTITY_CONFIDENCE_CONTRACT.md`
11. exact GitHub + live Supabase/Railway
12. `aos_memory`
13. Notion

Historical documents/chat checkpoints never override CURRENT or live persisted state.

## Global state

MKT Integrity V3 Loop 5 is closed; Loop 6 is not started. `REV-F5-CLOSEOUT` is the only active HIGH/CRITICAL mutable workstream. Other programs remain read-only/regression-only unless needed as sensors for F5.

Production runtime chain remains:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`.

## REV-F5 LIVE truth at registered baseline

- manifests: **6**;
- expected source rows: **15,498**;
- persisted source rows: **8,264**;
- remaining rows: **7,234**;
- staging-complete batches: **1 / 6**;
- provisional identity clusters: **3,950**;
- identity members: **0**;
- patient link previews: **0**;
- canonical apply events: **0**;
- structural duplicate keys: **0**;
- orphan source rows: **0**;
- observational canonical patients: **7,685**.

Per source:

- PL2024: **3,949 / 4,192** — missing Excel 3951–4193;
- PL2025: **1,801 / 3,053** — missing Excel 1703–1802 and 1903–3054;
- PL2026: **993 / 993** — complete;
- SI2024: **1,521 / 3,190** — missing Excel 1523–3191;
- SI2025: **0 / 3,066** — missing Excel 2–3067;
- SI2026: **0 / 1,004** — missing Excel 2–1005.

Always rederive LIVE before mutation.

## Persistence rule

Every HIGH/CRITICAL data checkpoint uses Persistence Triple-Proof:

1. execution receipt;
2. direct live persisted readback;
3. independent invariant query.

Every source batch closes only after full idempotent replay of the SHA-bound source with zero new inserts/conflicts.

## Identity / duplicate audit learning

Current read-only duplicate profile at registration:

- 174 same normalized name+surname groups;
- 69 of those span multiple phones;
- 57 span multiple documents;
- 110 duplicate name+surname+phone groups;
- 30 of those contain >1 non-empty document;
- 27 duplicate name+surname+document groups;
- 15 of those contain >1 non-empty phone;
- 14 groups / 29 patient rows currently match exact name+surname+phone+document.

Interpretation: repeated names are not automatically duplicates. The exact four-signal set is a high-confidence candidate pool, not permission for silent merge.

The legacy duplicate detector contains a prohibited approximate-phone heuristic based on numeric proximity and the legacy merge RPC is phone-pair-centric. Neither becomes F5 batch authority without a versioned dependency/security/rollback audit.

## Identity Bridge V2 decision

`numero_limpio/contact_key` remains important for Excel imports, search and compatibility but is no longer the identity target.

Target:

`identifier → governed alias/evidence → canonical_patient_id → unified history`.

A canonical patient may retain multiple current/historical phone aliases. Old and new phone can therefore resolve to the same patient after governed review. Shared phone/homonym conflicts remain explicit.

Existing `aos_cia_contact_identity_v1` has a useful phone/contact compatibility view and must be reused rather than replaced by a competing CIA identity. F5 owns richer identity semantics.

## Patient Commercial 360 V2

The existing `app/public/patients.html` / `aos_paciente_360` remains the product surface. Do not create a second patient master.

V2 target:

- canonical identity + historical aliases;
- identity confidence/review/conflict state;
- customer lifecycle;
- acquisition/contact/agenda/sales/product/payment timeline;
- observed revenue with explicit transaction coverage;
- merge/audit status;
- metric trust: coverage, confidence, freshness, sample size;
- role-gated clinical boundary.

Phone lookup remains backward compatible but resolves server-side to canonical identity before history aggregation.

## REV-F6 prepared contracts

REV-F6 remains BLOCKED until actual F5.10 PASS. Once unblocked it must implement:

- identity-aware Patient Commercial 360 V2;
- lifecycle: `NEW_PATIENT`, `RETURNING_PATIENT`, `HISTORICAL_REACTIVATED`, `ACTIVE_REPEAT`, `DORMANT`, `UNRESOLVED_IDENTITY`;
- Identity Confidence Contract;
- metric trust fields `coverage`, `confidence`, `freshness`, `sample_size`;
- Sales Intelligence read models from certified F3/F4/F5 facts;
- future 2024/2025 sales as a plug-in through the existing historical-sales ingest contract, not a redesign.

## Sentinel data integrity

Registered design: `docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md`.

Sentinel should eventually detect aggregate zero-PII failures such as source batch mismatch, membership mismatch, identity collision, canonical apply without governance, product-sale orphan, reconciliation orphan and stale/low-coverage F6 read models. Sentinel observes and routes; it does not silently repair business data.

## Cross-domain ownership

- F3 = product identity.
- F4 = payment/revenue/cartera truth.
- F5 = patient identity, provenance and duplicate resolution.
- F6 = intelligence/read models.
- CIA = governed acquisition/activation attribution.
- WA = conversation/channel product consuming permitted context.
- Sentinel = observability/integrity.

Prefer explicit IDs (`lead_id_origen`, `llamada_id_origen`, `venta_id_match`, sale/cotization/plan/item IDs) before identity-bridge fallback.

## Future historical sales 2024–2025

Use `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`:

`source manifest/SHA → row provenance/staging → canonical sale → F3 product → F5 patient → F4 payment/cartera → F6 intelligence`.

Do not fabricate 2024/2025 YoY from patient history or `Último presupuesto` while certified transaction ledgers are absent.

## Execution prompts

- Definitive F5 closeout prompt: `docs/control/prompts/REV_F5_CLOSEOUT_EXECUTION_PROMPT.md`.
- F6 template returned only after real F5.10 certification: `docs/control/prompts/REV_F6_EXECUTION_PROMPT_TEMPLATE.md`.

At F5.10 PASS the executing agent must bind the F6 template to the final exact SHA/LIVE counts and return it to the owner; do not silently start F6.

## Safety rules specific to F5

- no merge by name alone;
- no merge by phone alone;
- approximate/numeric-near phone is prohibited identity evidence;
- physical patient merge is CRITICAL: admin+2FA, dependency audit, dry-run, canary, immutable event and rollback/recovery;
- preserve absorbed aliases/provenance;
- source patient IDs/HC remain source-specific unless proven otherwise;
- fill-only enrichment by default;
- clinical notes/allergies stay outside automatic commercial apply;
- `Último presupuesto` is evidence only;
- `ADELANTO` is payment evidence only;
- every retry reconciles persisted state first;
- Notion is reconciled last.
