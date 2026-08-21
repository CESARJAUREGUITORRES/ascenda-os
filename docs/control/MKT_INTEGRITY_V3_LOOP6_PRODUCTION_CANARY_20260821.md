# MKT-INTEGRITY-HOTFIX-V3 — Loop 6 Production Canary

**Status:** ACTIVE / WAITING FOR REAL OPERATIONS  
**Captured:** 2026-08-21 17:40 America/Lima  
**Production main:** `a279d35034b25acba5acf2c93bd20e9903fceaed`  
**Functional PR:** #335 — MERGED  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`

## Deployment evidence

GitHub combined status for exact merge commit `a279d35034b25acba5acf2c93bd20e9903fceaed` reports Railway context `ASCENDA-OS - ascenda-os` as **success** for the production service.

The merged runtime contains:

- `app/public/calls-loop6.js`;
- exactly one loader line in `app/public/calls.html`: `<script src="/calls-loop6.js?v=20260821-loop6"></script>`;
- the governed atomic Call Center migration/RPC contract;
- rollback scripts and Impact Report.

Pre-merge PR head `1b73c1b34deec92a9ffadec8056d9256d8ede074` passed:

- Loop6 Runtime Loader Patch #7 — SUCCESS;
- Ascenda CI #2835 — SUCCESS;
- ASCENDA CIA Phase 16 Email Contracts #81 — SUCCESS.

## Synthetic / transactional validation already completed

The prompt-defined 15 DB canaries passed with rollback and zero synthetic residue. Covered: MARKETING lead resolution, late-lead safety, atomic failure rollback, double-click idempotency, converted-patient Reactivation/Follow-up/Agenda-only semantics, César Bravo non-converted case, callback, organic, identity conflict fail-closed, legacy cleanup compatibility, retry-after-timeout, NO ASISTIO-only semantics and converted-patient/new-lead acquisition blocking.

## Production baseline before real Loop 6 operations

Captured 2026-08-21 17:35:03 America/Lima:

- `aos_callcenter_actions_v1` rows: **0**;
- `journal_max_created`: **NULL**;
- max `aos_llamadas.id`: **38254**;
- Agenda rows: **3147**;
- REV-F5: 6 batches / 15,498 source rows / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events;
- repaired calls 36701, 37185, 37813, 38012, 38168 and 38186 intact.

Readback at 2026-08-21 17:40:13 America/Lima remains:

- Loop 6 journal rows: **0**.

Therefore no real post-cutover action has yet occurred. No synthetic or administrative write will be substituted for the required production evidence.

## Controlled canary and expansion rule

The first genuine Call Center action recorded in `aos_callcenter_actions_v1` after deployment is the controlled production canary. Before treating the rollout as expanded, certify that action for:

1. committed journal state / single action-level idempotency key;
2. correct explicit management semantic;
3. correct Call/Agenda cardinality;
4. direct `lead_id_origen` / `llamada_id_origen` links when applicable;
5. converted-patient actions do not create new acquisition;
6. no partial state or duplicate caused by retry/double click;
7. protected repairs, Marketing parity and REV-F5 remain intact.

If the first real action fails a gate, STOP expansion and repair/rollback within Loop 6.

If it passes, continue normal Call Center use and observe until at least **5 genuine post-cutover actions** exist.

## Final PASS gate

Loop 6 may be certified 100% only after at least five genuine post-cutover actions are read back and all downstream invariants pass. Until then:

- Loop 6 = **PRODUCTION CANARY ACTIVE / NOT YET CERTIFIED**;
- `MKT-INTEGRITY-HOTFIX-V3` remains the active lock;
- Loop 7 = **NOT STARTED**.
