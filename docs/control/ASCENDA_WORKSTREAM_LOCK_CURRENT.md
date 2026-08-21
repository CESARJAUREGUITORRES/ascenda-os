# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / MKT-INTEGRITY-HOTFIX-V3 ACTIVE — LOOP 6 PRODUCTION CANARY 0/5 REAL OPERATIONS  
**Captured:** 2026-08-21 17:40 America/Lima  
**Production main:** `a279d35034b25acba5acf2c93bd20e9903fceaed`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**CURRENT GATE:** `LOOP 6 — post-cutover real-operation canary + minimum 5 genuine operations`  
**LOOP 7:** `NOT STARTED`

GitHub CURRENT + Supabase LIVE remain authoritative. Do not release the lock or certify Loop 6 until the five-real-operation gate and downstream invariants pass.

## Portfolio lock state

- `REV-RUNTIME-BRIDGE-HOTFIX`: **CLOSED / RELEASED** after owner smoke PASS for Patient 360 and Importar Ventas.
- **REV-F5:** `PRODUCTION CERTIFIED — 100%`.
- **REV-F6.0–F6.7:** `PASS / CERTIFIED — 100%`.
- **REV-F6 global:** `PRODUCTION CERTIFIED — 100%`.
- **REV-F7:** `NEXT / UNBLOCKED`, paused while MKT owns the single HIGH/CRITICAL mutable lane.

## Loop 6 implementation / deployment

Functional PR **#335** — `MKT Loop 6 — atomic Call Center semantics + patient decision layer` — is **MERGED**.

Exact merge:

- PR head: `1b73c1b34deec92a9ffadec8056d9256d8ede074`;
- production main: `a279d35034b25acba5acf2c93bd20e9903fceaed`.

Pre-merge gates on the exact PR head:

- Loop6 Runtime Loader Patch #7 — **SUCCESS**;
- Ascenda CI #2835 — **SUCCESS**;
- ASCENDA CIA Phase 16 Email Contracts #81 — **SUCCESS**.

Railway deployment status for exact merge `a279d35034b25acba5acf2c93bd20e9903fceaed` is **SUCCESS** in context `ASCENDA-OS - ascenda-os`.

The production merge contains:

- governed F6-backed patient-state preparation;
- atomic Call + Agenda persistence;
- durable action idempotency journal `aos_callcenter_actions_v1`;
- direct linkage before COMMIT;
- explicit `LLAMADA_MANUAL_COMERCIAL`, `CALLBACK_INBOUND`, `REACTIVACION`, `SEGUIMIENTO_PACIENTE` and `AGENDA_ONLY` semantics;
- existing-patient decision modal;
- identity conflict fail-closed / REVIEW;
- cleanup compatibility that preserves explicit real commercial calls;
- `app/public/calls-loop6.js`;
- exactly one `calls-loop6.js?v=20260821-loop6` loader in `app/public/calls.html`;
- rollback scripts and Impact Report.

## Validation completed before production real-use gate

The prompt-defined **15 DB canaries PASS** in transactions/rollback with zero synthetic residue.

Coverage included:

- Marco, Julia and Carlos MARKETING / late-lead cases;
- Lidia forced atomic failure rollback;
- Alberto double-click idempotency;
- Alan converted-patient Reactivation and Agenda-only;
- César Bravo correctly non-converted;
- synthetic Agenda-only call delta 0;
- callback/inbound semantic;
- organic new patient;
- synthetic shared-phone identity conflict → REVIEW;
- legacy ambiguous cleanup vs explicit commercial call preservation;
- retry-after-timeout idempotency;
- old lead + NO ASISTIO-only not treated as converted;
- converted patient + new Meta lead blocked from new acquisition.

## Protected repair baseline

These repaired calls must remain intact throughout final certification:

- `36701` Alan Valencia
- `37185` Marco Antonio Salcedo Soto
- `37813` Julia Vera Condezo
- `38012` Carlos Eduardo Hernández Franchi
- `38168` Alberto Miguel Machuca Bonilla
- `38186` Lidia Edith Fernandez Salguero

Repaired direct links must remain intact. Removed duplicate Agenda rows for Alberto and Alan must not reappear.

## Production canary baseline

Captured before real Loop 6 use at **2026-08-21 17:35:03 America/Lima**:

- `aos_callcenter_actions_v1`: **0 rows**;
- `journal_max_created`: **NULL**;
- max `aos_llamadas.id`: **38254**;
- Agenda rows: **3147**;
- REV-F5: **6 batches / 15,498 source rows / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events**;
- six protected repaired calls intact.

Readback at **17:40:13 America/Lima** remains **0 journal rows**. No genuine post-cutover operation has yet occurred.

Evidence: `docs/control/MKT_INTEGRITY_V3_LOOP6_PRODUCTION_CANARY_20260821.md`.

## Controlled canary → expansion

The **first genuine** post-cutover row in `aos_callcenter_actions_v1` is the controlled production canary.

It must pass all of the following before expansion is treated as healthy:

1. one committed action-level idempotency key;
2. correct explicit management semantic;
3. correct Call/Agenda cardinality;
4. correct direct links when applicable;
5. existing-patient actions create no new acquisition;
6. no partial state / duplicate on retry;
7. Marketing, protected repair data and REV-F5 remain intact.

If the first real action fails: **STOP expansion** and repair/rollback inside Loop 6.

If PASS: continue ordinary Call Center use and observe until at least **5 genuine post-cutover actions** exist.

## Loop 6 final PASS rule

Do not certify Loop 6 100% until:

- >=5 genuine post-cutover actions exist in the Loop 6 journal;
- each action passes semantic/cardinality/direct-link/idempotency readback;
- no false Marketing acquisition is introduced;
- acquisition/attribution changes, if any, are explainable only by genuine eligible business events;
- REV-F5 remains exact;
- six repaired calls/direct links remain intact and removed duplicates stay absent;
- security grants/F6 private boundaries remain unchanged;
- final CURRENT + certificate + Notion are reconciled.

Until then:

- **Loop 6 = PRODUCTION CANARY ACTIVE / NOT YET CERTIFIED**;
- **active lock remains `MKT-INTEGRITY-HOTFIX-V3`**;
- **Loop 7 = NOT STARTED**.

## Single-lane rule

While this CURRENT is active:

- mutate only `MKT-INTEGRITY-HOTFIX-V3` as the HIGH/CRITICAL lane;
- REV-F7, CIA, WA, Sentinel hardening and other HIGH/CRITICAL functional work remain paused unless read-only/control;
- any incompatible `main` advance requires exact-head revalidation before the next functional mutation.
