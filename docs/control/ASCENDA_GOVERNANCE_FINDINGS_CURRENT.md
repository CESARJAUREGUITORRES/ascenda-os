# ASCENDA OS — GOVERNANCE FINDINGS CURRENT

**Baseline:** `main@40b2cbf50a9ffc2d9ca1ee3fedbf457c133c4a21`  
**Captured:** 2026-08-19 America/Lima  
**Scope:** CURRENT governance/read-only evidence + documentation reconciliation

## Findings

| ID | Finding | Risk | State | Required action |
|---|---|---|---|---|
| GOV-01 | Bare `F#` names collide across CIA, Revenue and Sentinel. | HIGH | MITIGATED | Use `CIA-F*`, `REV-F*`, `SEN-F*`, `WA-*`, `K*`, `PARITY-*`. |
| GOV-02 | Multiple HIGH/CRITICAL projects could launch work on shared CURRENT/runners concurrently. | CRITICAL | MITIGATED BY LOCK | One global mutable workstream in `ASCENDA_WORKSTREAM_LOCK_CURRENT.md`. |
| GOV-03 | Runtime docs/agents historically described `node server.js` while production uses wrapper topology. | HIGH | CONTROLLED | Root AGENTS/bootstrap must track the effective runtime chain. |
| GOV-04 | Historical `docs/MEMORY.md` / `docs/adn/AGENTS.md` describe obsolete authority. | HIGH | MITIGATED | CURRENT memory/agent overlays supersede them operationally. |
| GOV-05 | Old CIA branches/PRs can predate runtime-chain changes. | HIGH | PAUSED / DO NOT MERGE AS-IS | Rebuild/revalidate from CURRENT when CIA receives lock. |
| GOV-06 | Historical KronIA branches predate multiple runtime/schema wrappers. | CRITICAL | PAUSED / EVIDENCE_ONLY | Fresh K1 from then-CURRENT. |
| GOV-07 | Revenue F5 documentation has repeatedly contained counters that did not match live production. | CRITICAL | OPEN / CONTROLLED | Exact live Supabase readback is mandatory before every F5 gate and documentation update. |
| GOV-08 | Separate product phases can appear simultaneously active in trackers. | HIGH | CONTROLLED | Global lock + explicit namespace/state. |
| GOV-09 | Stale PRs may remain open and look merge-ready despite being superseded. | MEDIUM | CLEANUP ACTIVE | Classify by evidence; close superseded work deliberately. |
| GOV-10 | Runtime/Supabase/Notion can advance independently within minutes. | HIGH | CONTROLLED | exact-head + live readiness before certification; Notion last. |
| GOV-11 | Governance/control itself can fork when concurrent control PRs are created. | HIGH | CONTROLLED | One active control lane per mutable workstream. |
| GOV-12 | Sentinel baseline can remain certified while cross-workstream changes make old regression assumptions stale. | MEDIUM | QUEUED MAINTENANCE | Treat baseline certification and CURRENT alignment as separate dimensions. |
| GOV-13 | Branch protection/required checks do not replace project ownership. | HIGH | OPEN | Complement CI with global lock and exact-head certification. |
| GOV-14 | Parity/baseline maintenance can be confused with feature phases. | HIGH | FIXED | Keep maintenance lanes distinct from product workstreams. |
| GOV-15 | A tool/RPC/local loop may report apparent success while the intended production rows are not actually persisted. | CRITICAL | MITIGATION ADOPTED | Persistence Triple-Proof: execution receipt + direct live readback + independent invariant query. |
| GOV-16 | An assistant can produce a convincing `PRODUCTION CERTIFIED` narrative without matching GitHub closeout evidence or live DB post-conditions. | CRITICAL | INCIDENT RECORDED | Certification is a property of authoritative post-conditions, never narrative/tool transcript. False claims must be explicitly superseded. |
| GOV-17 | CURRENT control docs (`AGENTS_CURRENT`, portfolio, bootstrap) can remain bound to a previous workstream after ownership has changed. | HIGH | FIX IN THIS DOC SET | Reconcile CURRENT overlays whenever the global lock moves; stale CURRENT is itself a governance defect. |
| GOV-18 | `numero_limpio` is useful across Leads/Calls/Agenda/Patients/Sales but can be mistaken for canonical identity. | HIGH | RULE ADDED | Treat as transversal bridge/supporting evidence only; F5 governed identity remains canonical patient resolution. |
| GOV-19 | Availability of 2026 sales can bias analytics into treating 2026 as complete historical business truth. | HIGH | CONTRACT ADDED | Every revenue metric carries covered period/denominator; future 2024–2025 sales follow a provenance-first ingest contract. |
| GOV-20 | `presupuesto`, `adelanto`, `venta`, `pago`, `saldo` and `facturado` can be collapsed into one revenue concept. | CRITICAL | RULE ADDED | Keep transaction/payment/cartera semantics separate; no budget-as-debt/payment inference. |

## Live REV-F5 evidence — 2026-08-19

- expected source rows: **15,498**;
- persisted source rows: **8,264**;
- complete batches: **1/6**;
- PL2024: 3,949/4,192;
- PL2025: 1,801/3,053;
- PL2026: 993/993;
- SI2024: 1,521/3,190;
- SI2025: 0/3,066;
- SI2026: 0/1,004;
- provisional clusters: 3,950;
- identity members: 0;
- link previews: 0;
- apply events: 0;
- structural duplicates: 0;
- source-row orphans: 0.

Interpretation: REV-F5 is **ACTIVE / NOT CERTIFIED**. REV-F6 remains blocked.

## REV-F5 false-certification incident

A prior narrative claimed F5 staging, identity rebuild, Review/Apply and final certification were complete. Fresh production evidence disproves those claims.

The incident demonstrates two different failure classes:

1. **execution ambiguity** — sending/constructing a payload is not proof that it persisted;
2. **certification ambiguity** — even multiple apparent `PASS` messages are not proof unless the final authoritative state reflects the declared post-conditions.

Mandatory control:

`EXECUTE → DIRECT LIVE READBACK → INDEPENDENT INVARIANT QUERY → CHECKPOINT`.

At source-batch closure add full exact-source idempotent replay.

## Cross-domain identity finding

Current schema exposes explicit links that should be preferred over fuzzy matching:

- Lead → Call: `aos_llamadas.lead_id_origen`;
- Lead/Call → Agenda: `aos_agenda_citas.lead_id_origen`, `llamada_id_origen`;
- Agenda → Sale: `venta_id_match` where available;
- Sale → Product: `aos_product_sale_fact_current_v1.sale_id`;
- Sale → Cartera: `aos_cartera_reconciliacion.venta_row_id`;
- payments/reconciliation: cotización/item/payment identifiers;
- `numero_limpio` exists across several domains as fallback evidence.

Governance decision: F5 must be the patient identity/provenance authority. CIA, WA, F6 and future historical-sales import consume it rather than create separate customer identity truth.

## Future historical sales finding

ASCENDA already has the target domains necessary to ingest 2024–2025 transactions later without architecture replacement:

`source/provenance → sale → F3 product → F5 patient → F4 payment/cartera → F6 intelligence`.

See `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`.

Until certified historical transaction files exist, do not manufacture 2024/2025 YoY revenue from patient history, Agenda or budgets.

## Current control decision

- Active mutable lock: `REV-F5-CLOSEOUT`.
- REV-F5 stays open until live F5.0–F5.10 gates pass.
- REV-F6 stays blocked.
- Other HIGH/CRITICAL feature/data workstreams remain read-only/regression-only.
- CURRENT docs must be reconciled to live truth before any future handoff.
