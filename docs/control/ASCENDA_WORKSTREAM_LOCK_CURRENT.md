# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / MKT-INTEGRITY-HOTFIX-V3 ACTIVE — LOOP 6 V2 PRODUCTION CANARY 0/5 REAL OPERATIONS  
**Captured:** 2026-08-21 19:23 America/Lima  
**Functional runtime:** `7e5e7915b4c771649e50fd11e2af767819383052`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**CURRENT GATE:** `LOOP 6 V2 — post-hotfix controlled canary + minimum 5 genuine operations`  
**LOOP 7:** `NOT STARTED`

GitHub CURRENT + Supabase LIVE remain authoritative. Do not release the lock or certify Loop 6 until the expanded V2 five-real-operation gate and downstream invariants pass.

## Portfolio lock state

- `REV-RUNTIME-BRIDGE-HOTFIX`: **CLOSED / RELEASED** after owner smoke PASS for Patient 360 and Importar Ventas.
- **REV-F5:** `PRODUCTION CERTIFIED — 100%`.
- **REV-F6.0–F6.7:** `PASS / CERTIFIED — 100%`.
- **REV-F6 global:** `PRODUCTION CERTIFIED — 100%`.
- **REV-F7:** `NEXT / UNBLOCKED`, paused while MKT owns the single HIGH/CRITICAL mutable lane.

## Loop 6 runtime lineage

- PR #335 — atomic Call Center semantics + F6 decision layer: **MERGED**.
- PR #337 — 15-day reactivation + 72h ownership/recovery V2: **MERGED** at `521c013209702a7c26ddafed23799f9c36236481`.
- PR #338 — retry/idempotency precheck hotfix: **MERGED** at `7e5e7915b4c771649e50fd11e2af767819383052` using exact expected head.
- Railway status for exact functional runtime `7e5e7915b4c771649e50fd11e2af767819383052`: **SUCCESS** in context `ASCENDA-OS - ascenda-os`.

Production continues to load exactly one `app/public/calls-loop6.js` override.

## V2 server-authoritative commercial rules

1. Reactivation commercial credit requires >=15 full days since latest qualifying prior sale, clinical attention or ASISTIO/EFECTIVA appointment, using America/Lima.
2. Reactivation before 15 days may create management/Agenda but is DOWNGRADE / no new commercial `CITA CONFIRMADA`; beneficiary scope = CLINIC.
3. NO ASISTIO ownership is protected for 72 hours from the original appointment slot.
4. A different advisor may help during protection, but the Call remains non-conversion follow-up and Agenda/ownership remain with the prior advisor; executor is still audited.
5. After 72 hours, transfer is permitted only when the prior owner has no recorded post-no-show follow-up.
6. Recorded prior-owner follow-up prevents automatic transfer even after 72h.
7. Original-owner rebook does not create a second conversion.
8. Existing active PENDIENTE/CITA CONFIRMADA appointment blocks a new commercial conversion/Agenda.
9. `FOLLOWUP_CONVERSION` is distinct from `CALLBACK_INBOUND`.
10. `AGENDA_ONLY` creates Agenda only, zero commercial Call/Cita credit.
11. Browser selection is advisory; server policy may BLOCK/DOWNGRADE and is authoritative.
12. Action journal separates executor (`asesor/id_asesor`) from `credited_advisor`, `commercial_owner`, `beneficiary_scope`, eligibility and ownership-transfer state.

## V2 validation completed

Dedicated rollback canaries PASS for:

- Reactivation <15d;
- Reactivation >=15d;
- NO ASISTIO <72h support by another advisor;
- NO ASISTIO >72h without owner follow-up -> transfer + `CITA CONFIRMADA` + `FOLLOWUP_CONVERSION`;
- >72h with owner follow-up -> no transfer;
- original owner rebook -> no second conversion;
- active appointment -> BLOCK + 0 Call/0 Agenda;
- Seguimientos conversion -> `FOLLOWUP_CONVERSION` + direct links;
- AGENDA_ONLY -> Call 0 / Agenda 1;
- attempted commercial-button misuse on converted/non-eligible patient -> server BLOCK;
- retry/idempotency -> after hotfix, identical retry returns same IDs with `idempotent=true`, physical cardinality journal 1 / Call 1 / Agenda 1.

The retry canary found an ordering defect before final certification: retry was hitting active-appointment policy before the journal. PR #338 fixes this with a narrow precheck wrapper; the underlying V2 policy implementation remains isolated/service-role-only.

## Protected repair baseline

These repaired calls must remain intact throughout terminal certification:

- `36701` Alan Valencia
- `37185` Marco Antonio Salcedo Soto
- `37813` Julia Vera Condezo
- `38012` Carlos Eduardo Hernández Franchi
- `38168` Alberto Miguel Machuca Bonilla
- `38186` Lidia Edith Fernandez Salguero

Repaired direct links must remain intact. Removed duplicate Agenda rows for Alberto and Alan must not reappear.

## Post-canary invariants

After all rollback canaries:

- action journal = **0**;
- policy events = **0**;
- synthetic Calls = **0**;
- synthetic Agenda rows = **0**;
- repaired calls/direct links intact;
- removed duplicates = **0**;
- REV-F5 = **6 batches / 15,498 source rows / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events**;
- F6 Identity/Lifecycle remain service-role-only;
- Acquisition = **V2 56 / V3 57 / V2-only 0 / sole V3-only 973438607 -> lead 2135**;
- August Attribution checkpoint = **V2 22 rows / S/6,538; V3 35 rows / S/13,747**.

## V2 production canary baseline

Captured **after Railway SUCCESS for functional runtime `7e5e7915b4c771649e50fd11e2af767819383052`**:

- UTC: `2026-08-22T00:23:02.593121+00:00`
- America/Lima: **2026-08-21 19:23:02**
- `aos_callcenter_actions_v1`: **0 rows**
- `aos_callcenter_policy_events_v1`: **0 rows**
- max `aos_llamadas.id`: **38343**
- Agenda rows: **3148**

Evidence: `docs/control/MKT_INTEGRITY_V3_LOOP6_V2_PRODUCTION_CANARY_20260821.md`.

Only genuine actions with `created_at > 2026-08-22T00:23:02.593121+00:00` qualify for the V2 terminal gate.

## Controlled canary -> expansion

The first genuine qualifying V2 action is the controlled production canary. It must pass:

1. correct server-side eligibility decision;
2. correct executor vs credited advisor / owner;
3. correct Call/Agenda cardinality;
4. correct direct links;
5. no duplicate/partial state;
6. no false Marketing acquisition;
7. repaired data, REV-F5 and F6 security unchanged.

If first qualifying action fails: **STOP expansion** and repair inside Loop 6.

If PASS: continue ordinary Call Center use until at least **5 genuine post-baseline actions** exist.

## Loop 6 final PASS rule

Do not certify Loop 6 100% until:

- >=5 genuine actions exist after the V2 baseline;
- every action passes semantic/cardinality/direct-link/idempotency/credit-ownership readback;
- no false Marketing acquisition is introduced;
- Acquisition/Attribution deltas are explainable only by genuine eligible events;
- REV-F5 remains exact;
- six repaired calls/direct links remain intact and removed duplicates stay absent;
- security grants/F6 private boundaries remain unchanged;
- final certificate + CURRENT + Notion are reconciled.

Until then:

- **Loop 6 = V2 PRODUCTION CANARY ACTIVE / NOT YET CERTIFIED**;
- **active lock remains `MKT-INTEGRITY-HOTFIX-V3`**;
- **Loop 7 = NOT STARTED**.

## Single-lane rule

While this CURRENT is active:

- mutate only `MKT-INTEGRITY-HOTFIX-V3` as the HIGH/CRITICAL lane;
- REV-F7, CIA, WA, Sentinel hardening and other HIGH/CRITICAL functional work remain paused unless read-only/control;
- any incompatible `main` advance requires exact-head revalidation before the next functional mutation.
