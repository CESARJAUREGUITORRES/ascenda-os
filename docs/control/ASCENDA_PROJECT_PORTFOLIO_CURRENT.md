# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Captured:** 2026-08-19 America/Lima  
**GitHub entry baseline:** `main@754ab44f39f10123ab83b98f97b5c01fff25bab5`  
**ACTIVE PORTFOLIO OWNER:** `REV-F6-CLOSEOUT`

## Current owner state

REV-F5 is **PRODUCTION CERTIFIED — 100%** and its lock is released. Revenue now owns the single HIGH/CRITICAL mutable lane under `REV-F6-CLOSEOUT`; the active gate is **REV-F6.0 Data Contract**.

## Program map

| Program | Certified / closed input | Remaining | Portfolio state |
|---|---|---|---|
| Revenue | REV-F1..F5 closed; F5 terminal fp `2f0a365fae4caaa7be9d204e0f76679b` | REV-F6.0→F6.7, then F7 | **ACTIVE — F6.0 IN PROGRESS** |
| MKT Integrity / Call Center | prior closed loops preserved | later loops | **PAUSED / READ-ONLY** |
| WhatsApp + Notifications | certified notification/conversation baseline preserved | roadmap items outside Revenue | **PAUSED / REGRESSION-ONLY** |
| CIA | prior certified phases preserved | CIA-F17/F18 and later activation work | **PAUSED / READ-ONLY until Revenue handoff** |
| Sentinel | observability foundation preserved | regression/deferred maintenance + future F6.6 handoff | **REGRESSION-ONLY** |
| KronIA | prior closed baseline preserved | later hardening | **PAUSED** |
| Migration governance | safe owner slices | parity/baseline maintenance | **MAINTENANCE ONLY** |

## Revenue CURRENT

- REV-F1 Sales Intelligence V2 Foundation — **CLOSED**;
- REV-F2 Cartera/Reconciliation Foundation — **CLOSED**;
- REV-F3 Producto Canónico — **CLOSED**;
- REV-F4 Revenue Operations Integration V1 — **CLOSED**;
- REV-F5 Historical + Patient Identity — **PRODUCTION CERTIFIED — 100%**;
- REV-F6 Sales Intelligence 3.0 — **ACTIVE**;
- REV-F6.0 Data Contract — **IN PROGRESS**;
- REV-F6.1 Patient Commercial 360 V2 — **BLOCKED until F6.0 PASS**;
- REV-F7 Governed Revenue Signals & CIA Handoff — **BLOCKED until F6 certification**.

## Certified upstream truth boundary

Do not create competing truth layers:

- F3 = product identity/facts;
- F4 = payment/revenue/cartera/reconciliation truth;
- F5 = patient identity + provenance;
- F6 = derived intelligence/read models;
- CIA = governed audience/activation/assignment/channel/attribution;
- WA = conversation/channel product;
- Sentinel = observability/integrity, not autonomous business-data repair.

F6.0 entry LIVE:

- 6/6 historical patient batches MATCHED;
- 15,498 / 15,498 source rows and memberships;
- 8,716 identity clusters;
- 296 MATCH / 6,984 REVIEW / 1,436 NEW;
- 7,688 canonical patients;
- 1,299 canonical sales, current certified range 2026-01-05 → 2026-08-15;
- F3: 406 applicable facts, 397 RESOLVED;
- F4: 162 reconciliation rows / 123 linked sales;
- Identity Bridge V2: frozen contract, not materialized at F6.0.

## F6.0 security/current correction

Preflight discovered legacy `aos_paciente_360(text)` exposed to browser roles under SECURITY DEFINER and returning domains that Citas does not consume. F6.0 owns a fail-closed cutover to a minimum Auth V3 + PASSWORD_2FA patient-commercial history summary while preserving the existing UI contract through the production service-worker bridge.

No F6.0 gate may be certified until direct LIVE ACL/function readback proves the legacy browser path is closed and protected patient/sales/F3/F4 fingerprints remain unchanged.

## Historical-sales boundary

Patient history 2024/2025 does not create transactional revenue facts. Until certified transaction sources are ingested:

- 2024 sales = `NO_CERTIFIED_SOURCE`;
- 2025 sales = `NO_CERTIFIED_SOURCE`;
- missing source ≠ zero;
- unsupported historical YoY/revenue remains prohibited.

Future historical sales follow:

`source SHA/provenance → sales staging → canonical sale → F3 product → F5 patient → F4 payment/cartera → F6 intelligence`.

## Global lock rule

At most one HIGH/CRITICAL feature/data workstream mutates shared CURRENT at a time. Other workstreams may run read-only, documentation or regression work only when it cannot alter production state or compete for mutable DB/release ownership.
