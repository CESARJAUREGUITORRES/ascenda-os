# ASCENDA CLINIC — RECOVERY-R1 OPERATIONAL EVIDENCE COVERAGE

**Captured:** 2026-10-05  
**Mode:** read-only evidence assessment  

## Purpose

Separate what can be reconstructed from independently preserved files/checkpoints from what still requires the failed legacy database or an official Supabase backup.

## Independent evidence found

### Historical patient/provenance

**Coverage: HIGH**

- 6/6 original REV-F5 XLSX binaries are preserved outside PostgreSQL.
- All six SHA-256 identities match the governed legacy recovery allowlist.
- Historical source universe: 15,498 rows.
- Profiling and REV-F5 checkpoints are independently preserved.

### Sales / Revenue / Products through historical audit cuts

**Coverage: HIGH/PARTIAL**

Preserved artifacts include:

- monthly 2026 sales CSVs for January through July in multiple Library locations/copies;
- audited/reconciled product workbook;
- product/unit/advance review workbooks;
- historical reconciliation metadata and correction decisions.

Known audited August cut evidence exists in reconciliation workbooks, but R1 does not claim a complete post-cut live transaction ledger.

### Agenda workforce configuration

**Coverage: PARTIAL**

- October 2026 staff scheduling PDF is independently preserved.
- GitHub contains booking/Agenda schema, RPCs, frontend/runtime contracts and historical canary evidence.

This does **not** replace the latest canonical `aos_agenda_citas` rows.

### Call Center / Marketing / Commercial Intelligence

**Coverage: STRUCTURE HIGH / LIVE DATA PARTIAL**

- GitHub preserves Call Center, Marketing Integrity and Commercial Intelligence implementation/contracts.
- Library preserves detailed execution checkpoints, historical IDs, counts and semantics.
- No independent full recent raw export of `aos_llamadas`, `aos_leads` or audience runtime tables was certified during R1.

### Recent file scan

A Library inventory restricted to files created after 2026-09-01 found Clinic-relevant operational material consisting primarily of:

- October staff schedule;
- control/checkpoint text for Clinic workstreams.

No post-September full database export or current raw patient/agenda/call-center CSV/XLSX was identified in that scan.

## Hard recovery dependencies

The following remain **HIGH dependency on the legacy Supabase backup/database** unless another independent export is found:

1. current canonical patient rows after historical reconstruction/apply;
2. latest appointments and status transitions;
3. latest Call Center calls/leads/assignment state;
4. latest audience materializations/activation state;
5. Supabase Auth user/password hashes and identity metadata;
6. Storage object inventory and object payloads;
7. post-export-cut financial mutations not represented in independent source files.

## Reconstruction policy

Do not fill hard gaps from chat memory or historical checkpoints.

For each domain use:

1. official legacy backup/dump when available;
2. exact independently preserved export;
3. certified source/provenance reconstruction;
4. otherwise mark the domain `UNRECOVERED / REQUIRES RECONCILIATION`.

No fabricated current rows are allowed.

## R1 evidence result

- Historical F5 source recovery: **PASS**.
- Sales/product fallback: **PARTIAL PASS with strong historical coverage**.
- Agenda current-state fallback: **PARTIAL only**.
- Call Center/leads current-state fallback: **PARTIAL only**.
- Auth fallback without old backup: **FAIL for password-hash preservation; reset path remains available**.
- Storage fallback: **NOT YET PROVEN**.

This boundary is intentional: recovery confidence is preferred over falsely reconstructing live state.