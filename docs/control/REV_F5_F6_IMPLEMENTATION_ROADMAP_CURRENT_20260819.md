# REV-F5 → REV-F6 IMPLEMENTATION ROADMAP CURRENT

**Captured:** 2026-08-19 America/Lima  
**Baseline:** `main@1d964d99f018cbdb671ddce90e52ece6bac0a8bd`  
**Active mutable workstream:** `REV-F5-CLOSEOUT`  
**Rule:** design/docs may advance now; production mutations outside REV-F5 remain blocked until handoff.

## Goal

Close REV-F5 against LIVE truth, make patient identity stable beyond `numero_limpio`, consolidate true duplicates safely, upgrade the existing Patient 360 instead of creating a second panel, and prepare REV-F6 intelligence + Sentinel data-integrity monitoring without creating competing sources of truth.

## Current LIVE starting point

- expected source rows: 15,498;
- persisted: 8,264;
- pending: 7,234;
- complete batches: 1/6;
- members: 0;
- previews: 0;
- apply events: 0;
- duplicates/orphans in F5 staging: 0/0;
- canonical patients observed: 7,685.

Missing ranges are defined in `ASCENDA_WORKSTREAM_LOCK_CURRENT.md` and MUST be re-derived from LIVE before every write.

## Architecture ownership

- **REV-F3:** product/service identity.
- **REV-F4:** payment/revenue/cartera/reconciliation truth.
- **REV-F5:** patient identity, historical provenance, duplicate resolution and governed enrichment.
- **REV-F6:** analytics/read-models built from certified F3/F4/F5 facts.
- **CIA:** acquisition/activation/attribution. It may consume patient identity but may not own a competing customer identity.
- **WA:** conversation/routing/booking/revenue UX. It consumes permitted identity/commercial context.
- **Sentinel:** observes integrity/health; it never becomes business truth.

## REV-F5 closeout additions

### F5-A — Finish source truth

Complete exact LIVE gaps only, through existing SHA-bound idempotent compact ingest. Every checkpoint requires Persistence Triple-Proof. Every source closes only after full idempotent replay.

### F5-B — Identity rebuild

After 15,498/15,498 + 6/6 source certification, rebuild identity and require exactly 15,498 memberships, 0 orphan memberships and auditable cluster evidence.

### F5-C — Canonical duplicate resolution

Use F5 identity evidence to classify current `aos_pacientes` duplicates into:

- `AUTO_ELIGIBLE_EXACT`: normalized name + surname + phone + document all exact, no conflicting strong field;
- `REVIEW_STRONG`: same document + compatible person evidence but changed phone/name formatting, or other strong multi-signal case;
- `BLOCK_CONFLICT`: same name/phone but conflicting document/DOB/sex, same document with incompatible person evidence, or other strong contradiction;
- `NO_MERGE`: name-only, phone-only, approximate phone, weak/fuzzy similarity.

Current read-only profile is evidence, not a fixed future denominator: 174 same-name groups; 69 span multiple phones; 57 span multiple documents; 14 groups / 29 rows currently match exact name+surname+phone+document.

**Hard prohibition:** phone numeric proximity (for example ±3) is never identity evidence.

Physical consolidation is CRITICAL. Before changing a canonical patient, require admin+2FA, dry-run, dependency inventory, rollback journal/snapshot, 1-row canary, live readback and progressive apply. Never delete provenance. Absorbed identifiers remain historical aliases.

### F5-D — Identity Bridge V2 foundation

After identity decisions are certified, create/version a governed bridge from multiple identifiers to one stable `canonical_patient_id`. Reuse the existing `aos_cia_contact_identity_v1` as input/compatibility evidence; do not create a competing identity truth.

Phone remains an accepted lookup/import key, but not the canonical identity key.

### F5-E — Enrichment / Review & Apply

Fill-only by default. Conflicting non-empty values require review. Clinical notes/allergies remain outside automatic commercial apply. `Último presupuesto` stays evidence-only. `ADELANTO` stays payment evidence only.

### F5-F — Patient→Revenue linkage

Certify patient → sale → F3 product → F4 payment/revenue/cartera using explicit IDs first and identity bridge evidence second. Do not manufacture historical revenue where transaction sources are absent.

### F5-G — F5.10 terminal gate

REV-F5 may close only when exact-head GitHub/CI/deploy and LIVE DB independently prove every declared gate. Then update CURRENT docs, `aos_memory`, Notion last, release the lock and emit the REV-F6 prompt.

## Existing Patient 360 — upgrade, do not replace

Current product surface is `app/public/patients.html`; current RPC includes `aos_paciente_360`. The V2 target keeps this UX and adds:

1. stable canonical patient identity;
2. historical identifier aliases, especially old/new phones;
3. identity confidence + review state;
4. lifecycle state;
5. acquisition/contact/agenda/sales/product/payment timeline;
6. coverage/freshness/sample-size metadata;
7. duplicate-resolution evidence and merge history;
8. role-gated clinical sections separated from commercial context.

Backward compatibility: lookup by phone continues, but server-side resolution becomes `identifier → canonical_patient_id → all aliases/history`.

## REV-F6 internal roadmap

### REV-F6.0 — Rebaseline & Data Contract
Require F5 PRODUCTION CERTIFIED, acquire lock, revalidate F3/F4/F5 coverage, exact-head and historical transaction coverage.

### REV-F6.1 — Identity-aware Patient Commercial 360 V2
Implement read models/RPCs that resolve canonical patient + aliases and enrich the current panel. No second patient master.

### REV-F6.2 — Customer Lifecycle Contract
Implement deterministic lifecycle states: `NEW_PATIENT`, `RETURNING_PATIENT`, `HISTORICAL_REACTIVATED`, `ACTIVE_REPEAT`, `DORMANT`, `UNRESOLVED_IDENTITY`, with explicit precedence and evidence windows.

### REV-F6.3 — Identity Confidence / Metric Trust Contract
Every relevant metric/read-model exposes `coverage`, `confidence`, `freshness`, `sample_size` and coverage period. No exact-looking insight without denominator and source window.

### REV-F6.4 — Sales Intelligence 3.0
Executive Revenue, cohorts/retention, observed LTV, product/cross-sell, advisor/sede performance, acquisition-to-revenue facts where attribution is defendable.

### REV-F6.5 — Historical-sales plug-in contract
When 2024/2025 sales XLSX arrive, ingest via `REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`; reuse F3/F4/F5 and recompute affected F6 read models idempotently.

### REV-F6.6 — Sentinel data-integrity handoff
Register aggregate/zero-PII integrity signals. Implementation in Sentinel remains regression/read-only until Sentinel or the active Revenue scope explicitly owns the needed mutation.

### REV-F6.7 — Certification
Performance/read-model tests, metric reconciliation, coverage/freshness display, role/privacy checks, visual acceptance and exact live certification before REV-F7.

## Sentinel integrity targets

At minimum:

- F5 batch complete flag vs expected/staged mismatch;
- `identity_members != source_rows` after rebuild;
- duplicate membership / orphan membership;
- canonical apply event missing governed preview/review;
- product sale fact orphaned from sale;
- reconciliation row orphaned from sale/payment/cotization evidence;
- identity bridge identifier collision mapping to multiple canonical patients;
- F6 read model freshness/coverage below declared contract.

Signals contain counts/status/contract IDs only — no names, phones, emails, documents, clinical notes or message payloads.

## Future 2024–2025 sales

Do not redesign when files arrive. Expected path:

`XLSX → manifest/SHA → row provenance → sales staging → canonical sale → F3 product → F5 patient identity → F4 financial evidence → F6 intelligence`.

Existing 2026 intelligence remains valid for its declared window; 2024/2025 additions expand coverage and trigger deterministic recomputation rather than manual rebuilding.

## Exit contract

F5 completion must return to the owner:

1. final certification summary;
2. exact `main` SHA and LIVE post-conditions;
3. unresolved review/conflict inventory without PII;
4. historical transaction coverage statement;
5. the exact `REV-F6` execution prompt from `docs/control/prompts/REV_F6_EXECUTION_PROMPT_TEMPLATE.md`, rebound to the final F5-certified baseline.
