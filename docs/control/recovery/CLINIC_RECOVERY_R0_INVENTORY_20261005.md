# ASCENDA CLINIC / ASCENDA OS — RECOVERY-R0 INVENTORY

**Captured:** 2026-10-05  
**Mode:** READ-ONLY INVENTORY / NO PRODUCTION CUTOVER  
**Recovery branch:** `infra/clinic-db-recovery-r0-20261005`  
**Parent recovery branch:** `infra/clinic-db-recovery-20261003`  

## 1. Recovery objective

Preserve and recover the current Ascenda Clinic production state after the canonical Supabase project entered `RESTORE_FAILED`, without mixing this incident response with the later SaaS / multi-tenant / RLS redesign.

### Hard safety boundaries

- Do **not** change Railway production Supabase variables yet.
- Do **not** run bulk migrations against the new Supabase yet.
- Do **not** enable RLS globally during recovery.
- Do **not** merge the recovery branch into `main` as an application release.
- Do **not** upload clinical database dumps or PII to GitHub artifacts.
- Keep the existing Railway runtime frozen while evidence is collected.

## 2. Canonical production baseline

### GitHub

- Repository: `CESARJAUREGUITORRES/ascenda-os`
- `main` exact HEAD: `461e9eae1a1445b5d751f896700e041472935071`
- Commit: `P0 recovery: shed Caja polling during DB incident`

### Legacy Supabase — source of truth to recover

- Project ref: `ituyqwstonmhnfshnaqz`
- Name: `ascenda os`
- Region: `us-east-1`
- PostgreSQL major: 17
- Status at R0: `RESTORE_FAILED`
- SQL/public-table readback: unavailable; connection terminates by timeout.
- Migration readback: unavailable; connection terminates by timeout.

The platform still exposes metadata for seven legacy Edge Functions:

1. `f5-private-ingest-bridge`
2. `f5-recovery-run-20260815`
3. `f5-chat-recovery`
4. `f5-brotli-probe`
5. `f5-env-presence-probe`
6. `f5-github-cipher-ingest`
7. `f5-status-once`

This proves the project metadata/control plane is still partially readable even though PostgreSQL is not currently reachable.

### Replacement Supabase — recovery target

- Project ref: `gmokacpixfbrsiilsxln`
- Name: `ascenda-clinic`
- Region: `us-east-1`
- PostgreSQL major: 17
- Status at R0: `ACTIVE_HEALTHY`
- `public` business tables: 0
- Auth users: 0
- Storage buckets/objects: 0
- Project migrations: 0
- Edge Functions: 0

**Interpretation:** the replacement project is a clean recovery target and has not been contaminated by an incomplete manual rebuild.

## 3. Railway production state

- Railway project: `ASCENDA-OS`
- Project ID: `8def5cac-6aa4-42f1-96cc-8c9cf7d7d3a3`
- Production environment: `eba28532-1f35-4174-b57a-ded82178507e`
- Service: `ascenda-os`
- Service ID: `bd208ab8-1e71-4c52-94e2-0d6b2bdebce4`
- Latest deployment: `99954ee1-f95f-40d6-bb51-94cfdfda29bc`
- Deployment status: `SUCCESS`
- Exact commit: `461e9eae1a1445b5d751f896700e041472935071`
- Runtime state: online, 1/1 replica running.

Recent runtime logs continue to show database/upstream degradation rather than Railway container failure, including repeated:

- `F17_RPC_UNAVAILABLE`
- `UPSTREAM_TIMEOUT`
- template/cache fail-open behavior

### Existing staged Railway change — DO NOT COMMIT DURING RECOVERY

Production environment contains one old staged destructive patch:

- Patch: `dc0cccbd-02fa-4b49-9ded-d7cb39890301`
- Resource: `ascenda-resend-delivery-diagnostic`
- Action: delete service

This patch is unrelated to Clinic DB recovery and must remain untouched unless separately reviewed.

## 4. Existing database backup lane

Recovery branch `infra/clinic-db-recovery-20261003` is exactly two recovery commits ahead of current `main`:

- `9b1f5415fcd6d79b856d6279ecd22a4b69620e64` — add isolated Clinic DB backup workflow
- `8d11fbd04125bc2b2f4c09a09e01026af0d5672e` — remove checkout from recovery workflow

Workflow: `.github/workflows/clinic-db-recovery.yml`

The workflow:

- runs only on the isolated self-hosted Linux runner label;
- consumes `ASCENDA_CLINIC_OLD_DB_URL` only from GitHub Actions secret storage;
- attempts separate `roles.sql`, `schema.sql`, and `data.sql` dumps;
- validates non-empty files and SHA-256 locally;
- writes backup only to the self-hosted runner secure directory;
- explicitly does **not** upload the clinical dump to GitHub artifacts.

Current external blocker: the old project PostgreSQL endpoint is not accepting a database connection because the project is in `RESTORE_FAILED`.

## 5. External recovery evidence already preserved

### Historical patient/provenance universe

GitHub control certificates prove REV-F5 staging reached the six certified source manifests and a total of **15,498 source rows** before the current incident.

Expected source counts:

- Pueblo Libre 2024: 4,192
- Pueblo Libre 2025: 3,053
- Pueblo Libre 2026: 993
- San Isidro 2024: 3,190
- San Isidro 2025: 3,066
- San Isidro 2026: 1,004
- Total: 15,498

ChatGPT Library contains `ASCENDA_F5_PROFILING_6_EXCEL_2024_2026.xlsx`, which records the same six-source universe and preserves profiling/coverage evidence. It reports 15,498 source rows, 7,868 conservative candidate identities, 7,139 unique source phones, 3,188 unique source documents, 1,391 unique source emails, and a historical `aos_pacientes` count around 7.6k at that profiling cut.

Important limitation: R0 has found the profiling workbook and checkpoints, but has **not yet certified presence of all six original XLSX binaries** in the Library. Original-source recovery remains an explicit R1 search item.

### Sales / products / financial evidence

The Library contains multiple 2026 sales CSVs with transaction/customer/treatment/payment/site fields, plus:

- `ASCENDA_OS_PRODUCTOS_2026_AUDITADO_Y_RECONCILIADO.xlsx`
- `ASCENDA_OS_REVISION_PRODUCTOS_UNIDADES_ADELANTOS_2026-08-13.xlsx`

The reconciled product workbook records 394 audited product-labelled sales at the August cut and preserves corrections, physical-unit reconciliation, grouped payments/promos, and cartera review cases.

These files are usable as disaster-recovery evidence but do not replace a full PostgreSQL physical/logical backup.

### Agenda / workforce evidence

The Library contains `HORARIOS - 2026 - OCTUBRE.pdf`, preserving October staff scheduling evidence. This is useful for rebuilding operational configuration but is not a replacement for the canonical appointment ledger.

### Call Center / Commercial Intelligence

GitHub contains schema/contracts/migrations and extensive checkpoints for Call Center, Agenda, Commercial Intelligence and Audience OS. Library checkpoints also preserve historical counts and governed semantics. However, no standalone full current export of calls/leads/audiences has yet been certified in R0.

## 6. Authentication boundary

Supabase Auth passwords are not stored as plaintext. Recovery priority for Auth is therefore:

1. recover/restore the old `auth` schema and password hashes if the old backup becomes accessible;
2. otherwise recreate accounts in the replacement project and require password reset.

Do not attempt to reconstruct user passwords from application data.

## 7. Support state

Gmail currently contains two Supabase support acknowledgements for this incident:

- Ticket `SU-491573` — `Production project stuck in RESTORE_FAILED - complete outage`
- Ticket `SU-493637` — `Production project stuck in RESTORE_FAILED – database inaccessible`

At R0 both visible messages are acknowledgement/queue notices, not a human remediation response. The notices state that Free-plan requests have no guaranteed response time.

## 8. Recovery coverage matrix

| Domain | GitHub structure/contracts | External data evidence | Dependency on legacy backup |
|---|---|---|---|
| Application/runtime | HIGH | n/a | LOW |
| DB schema/RPC logic | HIGH | n/a | MEDIUM (baseline/drift proof) |
| Historical patient provenance | HIGH | HIGH/PARTIAL | MEDIUM |
| Canonical patient current state | HIGH structure | PARTIAL | HIGH |
| Sales 2026 | HIGH structure | HIGH/PARTIAL | MEDIUM |
| Product reconciliation | HIGH | HIGH | LOW/MEDIUM |
| Cartera/advances | HIGH structure | PARTIAL | MEDIUM/HIGH |
| Agenda schema | HIGH | PARTIAL schedules | HIGH for latest appointments |
| Call Center/leads | HIGH structure | PARTIAL checkpoints | HIGH for latest operations |
| Commercial Intelligence/Audiences | HIGH and derivable | PARTIAL checkpoints | MEDIUM/HIGH |
| Edge Functions | 7 legacy functions readable from Supabase metadata | source retrievable individually | LOW/MEDIUM |
| Auth users/password hashes | platform structure only | NONE outside old Auth | VERY HIGH |
| Storage objects | platform structure only | not yet inventoried | HIGH until proven otherwise |

## 9. Recovery strategy — frozen decision

Do **not** combine disaster recovery with SaaS/RLS redesign.

### Recovery lane R

`legacy evidence -> clean replacement Supabase -> 1:1 compatibility -> data restore/reconcile -> application canary -> production cutover`

Only after a certified R closeout may the system enter:

### SaaS/security lane S

`tenant/workspace model -> RBAC -> table-by-table RLS -> shadow tests -> canary -> enforcement`

## 10. Next gates

### R1 — SOURCE PRESERVATION

- Wait for / monitor Supabase support while preserving the old project unchanged.
- Retry the isolated logical dump only when old PostgreSQL connectivity returns or Supabase provides a supported backup endpoint.
- Find and certify the six original F5 XLSX files by filename + SHA-256 if available.
- Inventory any other independent exports for calls, leads, agenda, patients, ventas, cartera and storage.
- Snapshot every readable legacy Edge Function source into the recovery evidence set without deploying it to the new project yet.

### R2 — SCHEMA BASELINE

- Derive an ordered, reproducible recovery schema from GitHub migrations/contracts.
- Detect dependencies and migration drift before applying anything.
- Build only in a disposable/non-production recovery context first.

### R3 — DATA REHYDRATION

Priority order:
1. official old DB backup/dump if recovered;
2. canonical data exports;
3. certified source/provenance files;
4. controlled reconstruction with explicit reconciliation reports.

### R4 — CUTOVER

No Railway Supabase variable changes until:

- schema gate PASS;
- data count/reconciliation gate PASS;
- Auth strategy PASS;
- booking/call-center/admin smoke PASS;
- rollback point exists;
- exact target project and keys are independently verified.

## R0 GATE

**RECOVERY-R0 INVENTORY = PASS**

Reason:

- legacy outage isolated to Supabase database/restoration path;
- current application/runtime preserved;
- clean replacement target verified;
- recovery branch/workflow preserved;
- multiple independent data/provenance sources found;
- exact high-risk domains identified;
- no production mutation performed during R0.

**Next mutable action:** none. Proceed to R1 source preservation and evidence collection while waiting for legacy database connectivity/support.