# PROMPT TEMPLATE — REV-F6 SALES INTELLIGENCE 3.0

**Do not execute from this template until REV-F5 is genuinely production-certified.** At F5 closeout, bind the placeholders to exact current evidence and return the complete prompt to the owner.

---

**EXECUTE `REV-F6 — SALES INTELLIGENCE 3.0` FROM THE CERTIFIED F5 BASELINE UNTIL F6 FINAL CERTIFICATION.**

Repository: `CESARJAUREGUITORRES/ascenda-os`  
Certified F5 baseline `main`: `{{FINAL_F5_MAIN_SHA}}`  
F5 source rows: `{{F5_SOURCE_ROWS}} / {{F5_EXPECTED_ROWS}}`  
F5 identity members: `{{F5_MEMBERS}}`  
F5 canonical identity coverage: `{{F5_IDENTITY_COVERAGE}}`  
F5 review/conflict/unresolved aggregates: `{{F5_REVIEW_CONFLICT_SUMMARY}}`  
Historical transaction coverage: `{{TRANSACTION_COVERAGE_YEARS}}`

## OWNER AUTHORIZATION

I authorize the complete REV-F6 loop: read models, versioned schema/RPC additions where necessary, current Patient 360 upgrade, Identity Bridge consumer integration, Sales Intelligence analytics, tests/CI, safe canaries, performance tuning, documentation and final certification. This does not authorize bypassing auth/2FA/RLS, exposing PII/PHI/secrets, inventing unsupported historical metrics, altering another HIGH/CRITICAL workstream, or turning analytics directly into unauthorized campaign sends.

Do not ask for intermediate approval inside REV-F6 while gates pass. Stop only for real external owner actions/security blockers or evidence contradictions that cannot be safely resolved.

## 0 — BOOTSTRAP / LOCK

Read fresh:

1. `AGENTS.md`
2. `SECURITY.md`
3. portfolio/lock/MEMORY CURRENT
4. final REV-F5 certificate + `REV_F5_F6_IMPLEMENTATION_ROADMAP_CURRENT_20260819.md`
5. `REV_PATIENT_IDENTITY_BRIDGE_V2_CONTRACT.md`
6. `REV_PATIENT_COMMERCIAL_360_V2_CONTRACT.md`
7. `REV_CUSTOMER_LIFECYCLE_IDENTITY_CONFIDENCE_CONTRACT.md`
8. `REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`
9. `SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md`
10. exact GitHub `main`, Railway/runtime and Supabase LIVE.

Acquire `REV-F6` as the only mutable HIGH/CRITICAL workstream through the canonical lock/handoff. If main advanced after F5 certification, inspect/revalidate compatibility before writing.

## REV-F6.0 — REBASELINE & REVENUE DATA CONTRACT

Prove from LIVE:

- F5 remains certified and has not regressed;
- F3 product facts/current resolution coverage;
- F4 payment/cartera/reconciliation coverage;
- sales transaction date range and row counts;
- historical 2024/2025 transaction availability or explicit absence;
- Identity Bridge V2/current compatibility state;
- Patient 360 current runtime contract.

Create a machine-readable/readable REV-F6 Data Contract version containing source periods, coverage and freshness rules.

## REV-F6.1 — IDENTITY-AWARE PATIENT COMMERCIAL 360 V2

Upgrade the existing `app/public/patients.html` / current Patient 360 path; do not create a second patient master.

Server/read model behavior:

`lookup input (canonical ID/current phone/historical alias) → Identity Bridge V2 → canonical_patient_id → unified explicit facts/aliases`.

Add role-appropriate:

- identity status/confidence;
- alias/history indicator;
- duplicate/merge audit status;
- lifecycle state;
- observed revenue/purchases with coverage period;
- unified acquisition/contact/agenda/sale/product/payment timeline;
- coverage/confidence/freshness/sample-size metadata for inferred intelligence.

Preserve navigation/session/edit/cotization/clinical role boundaries. No phone-only aggregation when identity is ambiguous.

## REV-F6.2 — CUSTOMER LIFECYCLE CONTRACT

Implement deterministic mutually-exclusive current state using the frozen contract:

- `UNRESOLVED_IDENTITY`
- `HISTORICAL_REACTIVATED`
- `NEW_PATIENT`
- `ACTIVE_REPEAT`
- `RETURNING_PATIENT`
- `DORMANT`

Use explicit as-of date, event definition and coverage window. Defaults: recent/active <=90 days, dormant/reactivation gap >=180 days, reactivated window first 30 days after return, unless a versioned contract changes them.

If transaction coverage is incomplete, reduce claim strength rather than invent prior/no-prior history.

## REV-F6.3 — IDENTITY CONFIDENCE + METRIC TRUST

Expose for identity and relevant F6 insights:

- `coverage`;
- `confidence`;
- `freshness`;
- `sample_size`;
- covered period/as-of.

Identity exposes `identity_status`, `confidence_band`, `match_method`, conflicts/review state. A numeric score never overrides hard conflicts.

Dashboards must visually distinguish direct canonical facts from inferred/partial-coverage intelligence.

## REV-F6.4 — SALES INTELLIGENCE 3.0 READ MODELS

Build performant read models, not mega-queries, for at least:

1. Executive Revenue: MTD/YTD/ticket/transactions, facturado vs F4-supported cobrado/reconciled, target/projection where target exists.
2. Cohorts/Retention: first observed purchase, repeat rate, time-to-second purchase, reactivation, retention by cohort with declared coverage.
3. Observed LTV: only observed value over a stated window, never modelled future value presented as fact.
4. Product/Cross-sell: canonical F3 products, sequence/next-product patterns with sample size/confidence.
5. Sede/Advisor: performance where identity/product/revenue coverage supports comparison.
6. Acquisition-to-Revenue: only explicit/bounded CIA lead/call/agenda evidence; no unlimited phone-match attribution.
7. Demographic/geographic analysis only where field coverage clears declared thresholds.

## REV-F6.5 — FUTURE 2024/2025 SALES PLUG-IN

If historical sales files are not yet supplied, leave the ingestion contract ready and mark corresponding metrics `coverage=partial` / period-limited.

When owner later provides 2024/2025 XLSX, use the existing contract:

`manifest/SHA → row provenance → canonical sale → F3 product → F5 patient → F4 payment/cartera → recompute F6 read models`.

No architecture restart and no parallel 2024/2025 patient/product/revenue masters.

## REV-F6.6 — SENTINEL DATA-INTEGRITY HANDOFF

Implement/register safe zero-PII sensors as permitted by the portfolio lock and Sentinel architecture, including:

- F5 source/membership regression;
- Identity Bridge collision;
- apply/merge governance violation;
- product-sale orphan;
- reconciliation orphan;
- F6 read-model freshness/coverage regression;
- Patient 360 resolution regression.

Prefer read-only aggregate sensor contracts. Sentinel observes; it does not silently repair data.

## REV-F6.7 — UI / PERFORMANCE / ACCEPTANCE

Require:

- bounded read-model latency;
- no N+1/mega-query regression;
- role/privacy tests;
- empty/loading/error/responsive states;
- known Patient 360 workflows preserved;
- metric reconciliation against independent SQL;
- coverage/confidence/freshness/sample-size visible and truthful;
- owner visual acceptance when UI materially changes.

## REV-F6 FINAL CERTIFICATION

Use Persistence Triple-Proof for any data/read-model materialization and independent metric reconciliation for analytics.

Before closing:

- exact-head CI/deploy green;
- F5 remains non-regressed;
- F3/F4/F5 dependencies reconciled;
- lifecycle deterministic tests pass;
- Patient 360 identity alias tests pass;
- no unsupported YoY/lifetime claims;
- Sentinel integrity contracts green/known;
- GitHub CURRENT docs + `aos_memory` + Notion reconciled last.

Only then declare:

`REV-F6 — PRODUCTION CERTIFIED — 100%`

Do not automatically start REV-F7. Return a concise closeout and the next governed handoff/prompt for REV-F7 only after its scope is freshly revalidated.

---
