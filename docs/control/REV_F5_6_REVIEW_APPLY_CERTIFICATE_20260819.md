# REV-F5.6 — REVIEW & APPLY CERTIFICATE

**Captured:** 2026-08-19 America/Lima  
**Workstream:** `REV-F5-CLOSEOUT`  
**Entry GitHub baseline:** `main@3c208712e136b4618b6618b7044096811b273f74`  
**Scope:** governed fill-only enrichment Apply for LOW-risk fields only. Identity merge, overwrite, patient creation, clinical enrichment and blocked/undefined semantics remain out of scope.

## Entry and CURRENT revalidation

REV-F5.6 started from the certified REV-F5.5 state with 15,498 source rows, 15,498 identity memberships, 8,716 clusters, 296 MATCH / 6,984 REVIEW / 1,436 NEW, 455 enrichment previews and zero F5 Apply events.

Before the first canary, `aos_pacientes` moved externally from 7,687 to **7,688** while F5 still had zero reviewed/applied previews and zero Apply events. The loop therefore stopped before mutation and rebuilt/revalidated REV-F5.3 → REV-F5.4 → REV-F5.5 against CURRENT.

Rebaseline result:

- source rows / members = **15,498 / 15,498**;
- clusters = **8,716**;
- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- unsafe AUTO reclassified = **112**;
- enrichment previews = **455** across **202** MATCH patients;
- CURRENT canonical patients = **7,688**;
- pre-Apply canonical fingerprint = `7ee00cb855f253c52c464b1d49eec289`;
- no F5 canonical mutation during rebaseline.

The new external patient did not change F5.4 classification counts or the F5.5 proposal count.

## Governance hardening

REV-F5.6 found two legacy contract gaps before production Apply:

1. the v1 admin assertion only proved that the user profile had `two_factor=true`; it did not prove a live 2FA-authenticated session;
2. the v1 Apply path was cluster-patch oriented and required literal `conflicts={}`, incompatible with the conservative F5.4 classification layer (0/296 current MATCH rows had an empty conflict JSON even though all 296 were safe under F5.4 booleans).

REV-F5.6 therefore introduced a field-level v2 path that reuses the existing F5 classification, enrichment preview and canonical Apply-event ledger.

Mutation functions now require:

- active admin user;
- hierarchy level 1;
- `two_factor=true`;
- a non-revoked, non-expired `aos_app_sessions_v3` session with `assurance_level='PASSWORD_2FA'`;
- service-role transport only (`anon=false`, `authenticated=false`, `service_role=true`);
- REV-F5.4 `MATCH` with no canonical/source strong conflict, target collision or missing target;
- F5.5 one-value provenance;
- explicit field review;
- LOW-risk live policy;
- canonical field still empty;
- optimistic review snapshot hash.

## Final field policy

The existing risk vocabulary was preserved: `LOW / MEDIUM / IDENTITY_ANCHOR / BLOCKED`.

Apply-allowed in REV-F5.6:

- `Sexo` — LOW;
- `distrito` — LOW;
- `departamento` — LOW;
- `ciudad` — LOW.

Blocked in REV-F5.6:

- `Email` — IDENTITY_ANCHOR;
- `N° documento` — IDENTITY_ANCHOR;
- `Teléfono` — IDENTITY_ANCHOR;
- `Fecha de nacimiento` — BLOCKED;
- `Dirección` — MEDIUM / not apply-allowed;
- `Ocupación` — MEDIUM / not apply-allowed;
- acquisition-source mappings — BLOCKED pending semantic contract;
- latest-visit mappings — BLOCKED pending semantic contract;
- clinical/free-text fields — BLOCKED.

After policy finalization, the 455 previews split into:

- **229 APPLY_ALLOWED**;
- **226 POLICY_BLOCKED**;
- **0 POLICY_UNDEFINED**.

The F5.5 invariant `apply_eligible=false` was evolved conservatively: `apply_eligible=true` is now permitted only after `APPROVE_FIELD`, with actor, timestamp, snapshot hash, LOW policy and one of the four allowlisted fields.

## Dry-run and canary

A single deterministic `Sexo` field was reviewed under an active `PASSWORD_2FA` admin session.

Dry-run result:

- mode = `DRY_RUN`;
- scope = `CANARY`;
- review snapshot hash = `802c77e0991fce2f38311e011a434703f2e198a97c045c82633f222c42143065`;
- target row before hash = `7ccfca60d309dfdd5936e0d98fae43924947b06384327979ac08737448d99df4`;
- canonical global fingerprint remained `7ee00cb855f253c52c464b1d49eec289`;
- Apply events remained 0.

### Fail-closed repair 1

The first real canary call exposed a dynamic-SQL quoting defect before the UPDATE could execute. PostgreSQL aborted the transaction. Readback proved:

- canonical fingerprint unchanged;
- Apply events = 0;
- applied previews = 0.

The field UPDATE was repaired to use the patient row already held `FOR UPDATE`; the redundant dynamic emptiness predicate was removed. A second dry-run returned the exact same snapshot and row hashes.

### Canary Apply

The repaired canary produced exactly one field mutation and one event:

- field = `Sexo`;
- scope = `CANARY`;
- before row hash = `7ccfca60d309dfdd5936e0d98fae43924947b06384327979ac08737448d99df4`;
- after row hash = `90521400b8c1598e3a21f073ea78f43838e8471fbaef82a8b034e8ba37b5a103`;
- one active canary event;
- one applied preview;
- zero current/after mismatches.

## Mandatory rollback proof

The canary was rolled back immediately before any expansion.

Rollback result:

- rollback row hash = `7ccfca60d309dfdd5936e0d98fae43924947b06384327979ac08737448d99df4`;
- rollback hash equals exact before hash;
- canonical global fingerprint returned exactly to `7ee00cb855f253c52c464b1d49eec289`;
- active Apply events returned to 0;
- applied previews returned to 0;
- the canary event remains in the private ledger with `rolled_back_at` populated.

Result: **APPLY → VERIFY → ROLLBACK EXACT PASS**.

## Progressive LOW-risk expansion

After rollback proof, expansion was limited to the 229 policy-allowed preview fields. Every field was processed sequentially as:

`active admin+2FA → field review → fresh snapshot → locked-row Apply → event ledger → invariant readback`.

Successful progressive batch sizes:

- 10;
- 50;
- 50;
- 50;
- 50;
- 19.

### Fail-closed repair 2

An attempted 50-field batch after the initial 10 exposed a legacy unique index allowing only one active event per cluster. The entire attempted batch rolled back atomically; the prior 10 remained intact.

The ledger uniqueness contract was split without weakening idempotency:

- legacy v1 events (`field_name IS NULL`) keep one active event per cluster;
- v2 field events use one active event per `(cluster_id, field_name)`.

The repaired 50-field batch then passed.

## Final LIVE result

- canonical patients = **7,688**;
- final canonical fingerprint = `eee5a57717937a4f77049b3aebd8c525`;
- total F5 Apply events = **230**;
- active events = **229**;
- rolled-back events = **1** (mandatory canary);
- active batch events = **229**;
- applied enrichment previews = **229**;
- remaining LOW-risk unapplied previews = **0**;
- blocked previews left unapplied = **226**;
- active events outside allowlist = **0**;
- invalid before/after hash events = **0**;
- current canonical vs. event `after_patch` mismatches = **0**;
- event ↔ preview mismatches = **0**;
- applied policy/review violations = **0**;
- applied-without-event rows = **0**;
- legacy cluster-level link preview applied rows = **0**.

Applied field distribution:

| Field | Active applied fields |
|---|---:|
| `Sexo` | **121** |
| `distrito` | **108** |
| `departamento` | **0** |
| `ciudad` | **0** |
| **TOTAL** | **229** |

Identity/staging invariants remain:

- source rows = **15,498**;
- identity members = **15,498**;
- F5.4 MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**.

A final replay of the LOW-risk batch engine returned:

- `processed=0`;
- active events before/after = **229 / 229**;
- applied previews before/after = **229 / 229**;
- canonical fingerprint before/after = `eee5a57717937a4f77049b3aebd8c525`.

Result: **IDEMPOTENT REPLAY PASS**.

## Gate result

- `REV-F5.6 — REVIEW & APPLY — PASS`
- `REV-F5.7 — HISTORICAL JOIN — UNBLOCKED / NOT STARTED`
- overall `REV-F5 — EN CURSO / NOT YET PRODUCTION CERTIFIED`
- `REV-F6 — BLOCKED`

This certificate authorizes no additional field classes beyond the 229 LOW-risk fills already applied. The 226 blocked previews remain governed evidence only until a later explicit contract changes their policy.
