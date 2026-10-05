# ASCENDA CLINIC — RECOVERY-R1 SOURCE PRESERVATION MANIFEST

**Captured:** 2026-10-05  
**Recovery branch:** `infra/clinic-db-recovery-r0-20261005`  
**Scope:** metadata + cryptographic identities only. No patient rows, XLSX payloads, secrets, passwords, tokens or clinical PII are stored in this document.

## Gate objective

Prove that the six historical REV-F5 source workbooks remain independently recoverable outside the failed Supabase PostgreSQL database, and that the preserved binaries match the exact source identities accepted by the legacy recovery pipeline.

## Certified source manifest

| Source | Expected rows | Size (bytes) | SHA-256 | R1 |
|---|---:|---:|---|---|
| `PUEBLO LIBRE 2024.xlsx` | 4,192 | 524,188 | `d65df2f66f2912084fe261298ac88ede123c50eef0a74e64a1f22e437a34680c` | PASS |
| `PUEBLO LIBRE 2025.xlsx` | 3,053 | 383,350 | `80761f481735dd18665265e7348b266335167d72e597d8124b4342f31d67b050` | PASS |
| `PUEBLO LIBRE 2026.xlsx` | 993 | 127,933 | `ab9239f2dc9db03f42e8c5b2ec6182bc7e66891a52bf1ab548911194ba261f1b` | PASS |
| `SAN ISIDRO 2024.xlsx` | 3,190 | 391,976 | `8fd1ea53e98856e8569328991b0c94f9dda1ebd8cf5a34713a42c3e99df42438` | PASS |
| `SAN ISIDRO 2025.xlsx` | 3,066 | 386,080 | `a59fdb6fbf2c82d62a7bf30ce82d18a7aa52601e4a35069d01052bc52542785b` | PASS |
| `SAN ISIDRO 2026.xlsx`* | 1,004 | 131,422 | `7cbd86e4dbbd4154882240463bcb2c4424b3962a054155ef553a5fdfea174f5b` | PASS |
| **TOTAL** | **15,498** | — | — | **PASS** |

\*The Library contains both the canonical title and a duplicate `(1)` copy. R1 hash computation used a preserved duplicate binary after the first materialization attempt for the canonical title was rate-limited by the file service. Its size and cryptographic identity match the certified REV-F5 source allowlist.

## Independent cross-check

The exact six SHA-256 values above are the six source identities still embedded in the legacy Supabase recovery functions' allowlists. Therefore the files preserved outside PostgreSQL are byte-identifiable members of the same governed source universe used by REV-F5.

This is stronger evidence than filename/count matching alone.

## Preservation location

The source binaries are preserved in the user's ChatGPT Library. Multiple duplicate copies are visible for the six source workbooks. R1 materialized working copies only into the model's private recovery workspace for hashing; those copies are not committed to GitHub.

## Security boundary

Do not:

- upload the source workbooks to this public repository;
- add patient payloads or clinical fields to GitHub artifacts;
- publish the raw source of legacy recovery Edge Functions that contains embedded sensitive recovery material;
- expose service-role keys or database passwords.

Public recovery documentation may contain only non-sensitive metadata, counts, hashes, filenames and control-plane identifiers.

## R1 result

**RECOVERY-R1 / REV-F5 SOURCE PRESERVATION = PASS**

Proven:

- 6/6 historical source workbooks preserved outside failed PostgreSQL;
- 15,498 expected source rows represented by the certified six-file manifest;
- 6/6 cryptographic source identities match the legacy recovery allowlist;
- no clinical workbook payload uploaded to GitHub;
- recovery remains independent of the current `RESTORE_FAILED` database state.

## Remaining R1 work

Continue read-only inventory of independent operational evidence for:

1. current canonical patients after the historical F5 cut;
2. recent Agenda appointments;
3. Call Center calls/leads;
4. Revenue/cartera after existing exports;
5. Supabase Auth users/hashes — still dependent on official old backup or a supported Auth recovery path;
6. Storage objects — inventory not yet proven.

No schema/data write to replacement Supabase is authorized by this manifest.