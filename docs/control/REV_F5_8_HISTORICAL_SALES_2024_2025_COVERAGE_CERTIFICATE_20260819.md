# REV-F5.8 — Historical Sales 2024–2025 Coverage Certificate

**Status:** PASS — NO CERTIFIED TRANSACTIONAL SOURCE FOR 2024–2025  
**Date:** 2026-08-19 America/Lima  
**Baseline:** `main@d1f165fa436165ad6b7b60b2b7bdf007939b9166`  
**Scope:** locate and certify the real 2024–2025 sales source without fabricating YoY, revenue, debt or payment facts.

## 1. Certified conclusion

ASCENDA currently has certified **patient-history coverage for 2024–2026**, but it does **not** have a persisted, auditable **transactional sales ledger for 2024 or 2025** in the certified production domains inspected by REV-F5.8.

Therefore:

- 2024 sales coverage = **NOT AVAILABLE / NO CERTIFIED TRANSACTIONAL SOURCE**;
- 2025 sales coverage = **NOT AVAILABLE / NO CERTIFIED TRANSACTIONAL SOURCE**;
- this state must **not** be interpreted as `sales = 0` for business analytics;
- no 2024↔2025↔2026 YoY revenue comparison may be exposed as factual until a real 2024/2025 transactional source is ingested and certified;
- `Último presupuesto`, appointments, patient creation dates, clinical history, calls or other non-transactional evidence must not be promoted into sale/payment/debt facts.

This is a coverage limitation, not a data-fabrication opportunity.

## 2. Patient-history evidence already persisted

The six historical Excel sources are already persisted in F5 staging and remain authoritative for patient identity/provenance:

- `PUEBLO LIBRE 2024.xlsx` — 4,192 rows;
- `PUEBLO LIBRE 2025.xlsx` — 3,053 rows;
- `PUEBLO LIBRE 2026.xlsx` — 993 rows;
- `SAN ISIDRO 2024.xlsx` — 3,190 rows;
- `SAN ISIDRO 2025.xlsx` — 3,066 rows;
- `SAN ISIDRO 2026.xlsx` — 1,004 rows;
- total = **15,498 rows**.

For 2024–2025 specifically:

- batches = **4**;
- rows = **13,501**.

Their original 27-column payload is a patient export. The persisted raw keys include patient/contact/demographic/appointment/history fields such as `ID del paciente`, `F. creación de paciente`, `Teléfono`, `Nombres`, `Apellidos`, `Email`, `N° documento`, `Sexo`, `Fecha de nacimiento`, `Dirección`, `Ocupación`, `¿Cómo nos conoció?`, `N° HC`, `Última cita`, `Próxima cita` and `Último presupuesto`.

REV-F5.8 verified that these patient exports do **not** contain canonical transaction keys such as sale id, sale date, sale amount, currency, payment amount/status, product/service sold or advisor-as-sale-fact.

`Último presupuesto` remains evidence only; it is not a sale, payment or debt fact.

## 3. Transactional-domain audit

The following persisted production domains were profiled by year:

### `aos_ventas`

- 2024 = **0 rows**;
- 2025 = **0 rows**;
- 2026 = **1,299 rows**;
- current date range = **2026-01-05 → 2026-08-15**;
- current 2026 amount total = **561,889.27** in the table's stored amount semantics.

### Sales backups

- `aos_ventas_backup_enero_20260812` = 191 rows, all January 2026;
- `aos_ventas_backup_julio_20260808` = 192 rows, all July 2026;
- no 2024/2025 rows.

### Reconciliation ledger

`aos_recon_meses` contains only 2026 monthly source certifications:

- January through July 2026 = validated monthly CSV sales/visits;
- August 2026 = operational audit cutoff;
- 2024 = **0 reconciled months**;
- 2025 = **0 reconciled months**.

`aos_recon_visitas` also contains only 2026 evidence.

### Other financial / transactional candidates

- `aos_cotizaciones` = 2026 only;
- `aos_pagos` = 2026 only;
- `aos_caja_sesiones` = 2026 only;
- `aos_comprobantes` = no certified 2024/2025 transaction rows observed;
- `aos_documentos_fiscales` = no certified 2024/2025 transaction rows observed;
- `aos_import_ventas_batches` contains only small operational import batches created in August 2026 and provides no 2024/2025 source ledger.

These sources cannot be combined to manufacture missing 2024/2025 sales.

## 4. GitHub evidence

The existing contract `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md` already defines the only permitted future pipeline:

`SOURCE FILE → MANIFEST/SHA → ROW PROVENANCE → SALES STAGING → DEDUP/VALIDATION → aos_ventas-compatible canonical sale → F3 product resolution → F5 patient identity resolution → F4 payment/cartera reconciliation → F6 intelligence`.

It explicitly prohibits:

- inferring missing sales from patient `Último presupuesto`, Agenda, calls or treatment history;
- direct mass insert without staging/provenance;
- phone-only patient merge;
- budget-as-sale or budget-as-debt inference;
- YoY dashboards until both historical years have certified transactional coverage.

REV-F5.8 found no repository artifact representing an already-certified 2024/2025 sales ledger.

## 5. Deterministic evidence fingerprint

The independent LIVE evidence query returned:

- candidate transactional rows observed for 2024 = **0**;
- candidate transactional rows observed for 2025 = **0**;
- canonical `aos_ventas` rows 2024–2025 = **0**;
- `aos_recon_meses` rows 2024–2025 = **0**;
- F5 patient-history batches 2024–2025 = **4**;
- F5 patient-history rows 2024–2025 = **13,501**;
- patient exports have no transaction keys = **true**;
- evidence fingerprint = **`4ce1695532a57655179558ed2b5f78aa`**.

The aggregate `tx_rows_2026_across_sources` used in that fingerprint is only a control signal across overlapping candidate tables and must **not** be interpreted as a unique-sale count. The canonical 2026 sale count remains `aos_ventas = 1,299`.

## 6. F5.8 gate result

**REV-F5.8 = PASS** because the phase requirement is to locate/audit the real source and either ingest it safely **or explicitly certify its absence**.

Certified state:

- real persisted 2024 transactional sales source = **NOT FOUND**;
- real persisted 2025 transactional sales source = **NOT FOUND**;
- 2024/2025 patient-history source = **AVAILABLE AND CERTIFIED**;
- 2024/2025 revenue/YoY analytics = **UNSUPPORTED / MUST REMAIN DISABLED OR COVERAGE-LABELED**;
- no patient, sale, F3, F4 or financial facts were mutated by REV-F5.8.

## 7. Future source arrival rule

If a real 2024/2025 sales export becomes available later, do **not** reinterpret this certificate as permanent absence. Reopen REV-F5.8 intake against the existing ingest contract and require:

1. file manifest + exact SHA-256;
2. row/schema/date-range profiling;
3. idempotent staging with provenance;
4. canonical sale dedup/reconciliation;
5. F3 product resolution;
6. F5 patient resolution;
7. F4 payment/cartera reconciliation;
8. independent readback + replay/fingerprint;
9. only then enable historical YoY for the certified period.

## 8. Next gate

`REV-F5.9 — Coverage & Data Quality Report` is **UNBLOCKED / NEXT**.

REV-F5 remains **IN PROGRESS / NOT YET PRODUCTION CERTIFIED** and REV-F6 remains blocked until REV-F5.10 final certification.
