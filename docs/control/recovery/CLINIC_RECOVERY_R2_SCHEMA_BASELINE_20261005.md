# ASCENDA CLINIC — RECOVERY-R2 SCHEMA BASELINE ASSESSMENT

**Captured:** 2026-10-05  
**Mode:** read-only / no target DB mutations  
**Replacement project:** `gmokacpixfbrsiilsxln`  

## Question

Can the replacement Supabase be safely rebuilt by replaying the repository's `supabase/migrations/` directory from an empty database?

## Result

**NO — NOT YET SAFE.**

`supabase/migrations/` is an incremental production history for later Ascenda OS work, not a proven complete bootstrap of the original Clinic database.

## Evidence

### 1. Core production tables are assumed by later migrations

Repository migrations alter/query central tables such as:

- `public.aos_pacientes`
- `public.aos_ventas`
- `public.aos_agenda_citas`
- `public.aos_llamadas`
- `public.aos_leads`

without a currently proven production migration baseline that creates their exact original production definitions first.

Examples of later production migrations include booking attribution additions to `aos_agenda_citas`, Call Center/Marketing functions over `aos_llamadas` / `aos_leads`, and historical/revenue joins over `aos_ventas`.

### 2. GitHub contains synthetic CI schema contracts, but they are not production dumps

CI fixtures/contracts do create minimal versions of core tables. Examples:

- `ci/rev-f6-0/schema_contract.sql`
- `ci/rev-f6-1/schema_contract.sql`
- `ci/rev-f5-11/schema_contract.sql`
- `ci/phase4-revenue/schema_contract.sql`
- `ci/zero-cost-staging/schema_contract.sql`
- multiple WhatsApp/booking fixtures

These files are explicitly synthetic/minimal test substrates. They are valuable for reconstructing contracts and dependencies but must not be mistaken for exact production DDL.

For example, `ci/zero-cost-staging/schema_contract.sql` describes itself as a `Minimal synthetic schema contract` and contains only a limited subset of production tables.

### 3. No complete checked-in production pg_dump/schema snapshot was found in R2 search

R2 searches did not find a repository file representing a complete `pg_dump --schema-only` of the legacy Clinic database.

### 4. Legacy DB cannot currently answer schema introspection

The legacy project `ituyqwstonmhnfshnaqz` remains `RESTORE_FAILED`; database migration/table queries terminate by timeout.

Therefore exact live column/constraint/index/trigger/policy drift cannot currently be reconciled against repository contracts.

## Recovery consequence

Do **not** run the repository migration directory against empty replacement project `gmokacpixfbrsiilsxln` yet.

Doing so could produce:

- missing foundational tables;
- incomplete columns/defaults/constraints;
- triggers/functions created against wrong table shapes;
- inconsistent sequence/identity state;
- mismatched grants/RLS/policies;
- false confidence because CI fixtures are intentionally narrower than production.

## Safe R2 paths

Priority order:

### Path A — preferred

Obtain official legacy DB restore/logical dump and derive exact `schema.sql` from it.

Then:

1. inspect schema-only dump;
2. compare with repository migrations/contracts;
3. restore exact baseline into isolated target;
4. reconcile migration ledger/drift;
5. run contract tests before any data import.

### Path B — contingency if official schema is unrecoverable

Construct a governed production-compatible baseline from evidence, but only through a dedicated recovery package:

1. enumerate every referenced production table/object from code + migrations;
2. infer candidate DDL from the strongest CI contracts and migration expectations;
3. build it in disposable PostgreSQL first;
4. run repository CI/contracts against it;
5. produce an explicit `KNOWN_GAPS` report;
6. never claim compatibility until all required runtime paths pass.

This path is a last resort because CI contracts prove behavior subsets, not exact historic production DDL.

## Current replacement project rule

`gmokacpixfbrsiilsxln` remains deliberately empty during R2.

No schema migration, Edge Function deployment, Auth recreation or Railway cutover is authorized by this assessment.

## R2 gate

**R2 / DIRECT MIGRATION REPLAY = BLOCKED (correct fail-closed result).**

**R2 / SCHEMA EVIDENCE COLLECTION = PASS.**

Next preferred transition:

`legacy connectivity/support -> exact schema dump -> isolated restore -> contract test -> R2 PASS`

If that remains unavailable, begin the contingency baseline builder in a disposable environment, not in the clean replacement project.