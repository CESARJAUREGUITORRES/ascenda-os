# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Captured from control baseline:** `main@40b2cbf50a9ffc2d9ca1ee3fedbf457c133c4a21`  
**Captured:** 2026-08-19 America/Lima  
**ACTIVE PORTFOLIO OWNER:** `REV-F5-CLOSEOUT`

## Owner state

MKT Integrity V3 Loop 5 is merged/PASS. Loop 6 is **NOT STARTED**. The owner explicitly handed the mutable HIGH/CRITICAL lane back to Revenue and ordered REV-F5 to continue before REV-F6.

## Runtime

Railway runtime topology is not part of the current F5 change scope. Preserve the effective chain unless a demonstrated F5 blocker requires runtime mutation:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`.

## Program map

| Program | Closed / validated input | Remaining | Portfolio state |
|---|---|---|---|
| Revenue | REV-F1..F4 closed; F5 source model/RPCs exist | REV-F5 live closeout, then F6/F7 | **ACTIVE — F5 NOT CERTIFIED** |
| MKT Integrity / Call Center | Loops 1–5 PASS | Loop 6+ not started | **PAUSED / READ-ONLY** |
| WhatsApp + Notifications | S15.5 notification infrastructure certified | WA roadmap items outside current F5 scope | **PAUSED / REGRESSION-ONLY** |
| CIA | CIA-F0..F16 closed | CIA-F17/F18 | **PAUSED / READ-ONLY** |
| Sentinel | SEN-F1..F13 closed | regression/deferred maintenance | **FROZEN / REGRESSION-ONLY** |
| KronIA | K0 closed | K1–K8 | **PAUSED** |
| Migration governance | safe owner slices | parity/baseline maintenance | **MAINTENANCE ONLY** |

## REV-F5 production truth

Fresh Supabase live state:

- source batches: 6;
- expected rows: **15,498**;
- persisted rows: **8,264**;
- remaining: **7,234**;
- complete batches: **1/6**;
- provisional identity clusters: 3,950;
- members: 0;
- previews: 0;
- apply events: 0;
- structural duplicate source keys: 0;
- orphan source rows: 0.

Batch state:

| Source | Staged / Expected |
|---|---:|
| PL2024 | 3,949 / 4,192 |
| PL2025 | 1,801 / 3,053 |
| PL2026 | 993 / 993 |
| SI2024 | 1,521 / 3,190 |
| SI2025 | 0 / 3,066 |
| SI2026 | 0 / 1,004 |

Any prior claim that F5 reached 15,498/15,498, rebuilt identity or unblocked REV-F6 is superseded by this live evidence.

## Revenue architecture preserved

Do not create competing truth layers.

- REV-F3 = product identity/facts;
- REV-F4 = payment/revenue/cartera/reconciliation truth;
- REV-F5 = patient identity + provenance + governed enrichment;
- REV-F6 = intelligence over certified F3/F4/F5;
- CIA = governed acquisition/activation attribution;
- WA = conversation/channel product consuming permitted identity context.

Cross-domain explicit keys already exist (`lead_id_origen`, `llamada_id_origen`, `venta_id_match`, sale IDs, cotización/plan/item IDs). `numero_limpio` remains useful supporting evidence, not standalone merge authority.

## Current Revenue next gate

1. finish exact missing source ranges from live state;
2. certify 6/6 batches using persistence triple-proof + complete source replay;
3. require 15,498/15,498 before identity rebuild;
4. execute F5.3–F5.10 with governed review/apply and cross-domain coverage;
5. only then mark REV-F5 production-certified and hand the lock to REV-F6.

## Future historical sales input

2024–2025 transaction files can be incorporated later without changing this architecture. Follow `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`:

`source SHA/provenance → sales staging → canonical sale → F3 product → F5 patient → F4 payment/cartera → F6 intelligence`.

Until those transaction sources are certified, patient history does not justify unsupported 2024/2025 revenue or YoY claims.

## Global lock rule

At most one HIGH/CRITICAL feature/data workstream mutates shared CURRENT at a time. Other workstreams may run read-only/documentation/regression work that cannot alter production state or compete for mutable DB/release ownership.
