# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / MKT-INTEGRITY-HOTFIX-V3 ACTIVE — LOOP 6 V2.2 PRODUCTION CANARY 0/5 GENUINE OPERATIONS  
**Captured:** 2026-08-21 20:17:57 America/Lima  
**Functional runtime:** `f6adba60358d7d45ef547ba29f0189767b0355e9`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**CURRENT GATE:** `LOOP 6 V2.2 — fresh post-Ruben controlled canary + minimum 5 genuine operations`  
**LOOP 7:** `NOT STARTED`

GitHub CURRENT + Supabase LIVE remain authoritative. Do not release the MKT lock or certify Loop 6 until the V2.2 five-genuine-operation gate and downstream invariants pass.

## Portfolio lock state
- `REV-RUNTIME-BRIDGE-HOTFIX`: CLOSED / RELEASED after owner smoke PASS for Patient 360 + Importar Ventas.
- REV-F5: PRODUCTION CERTIFIED — 100%.
- REV-F6.0–F6.7 / REV-F6 global: PRODUCTION CERTIFIED — 100%.
- REV-F7: NEXT / UNBLOCKED, paused while MKT owns the single HIGH/CRITICAL mutable lane.

## Loop 6 runtime lineage
- PR #335 — atomic Call Center semantics + F6 decision layer: MERGED.
- PR #337 — 15-day reactivation + 72h ownership/recovery V2: MERGED at `521c013209702a7c26ddafed23799f9c36236481`.
- PR #338 — retry/idempotency precheck: MERGED at `7e5e7915b4c771649e50fd11e2af767819383052`.
- First real V2 canary exposed legacy/stale-runtime bypass on Ruben `997883711`.
- PR #340 — V2.2 legacy-bypass fail-closed + cache-bust + Ruben evidence/rollback: MERGED at `f6adba60358d7d45ef547ba29f0189767b0355e9`.
- Railway exact-commit status for `f6adba60358d7d45ef547ba29f0189767b0355e9`: SUCCESS (`ASCENDA-OS - ascenda-os`).

## V2.2 fail-closed guarantees
1. Non-governed `CITA CONFIRMADA` Call inserts are rejected server-side with `AOS_LOOP6_RUNTIME_REQUIRED`.
2. Non-governed `CITA_MANUAL` / `CALL_CENTER*` Agenda inserts are rejected server-side.
3. Canonical Loop 6 core sets transaction-local `aos.loop6_governed_write=1` before governed writes.
4. Frontend loads exactly one `calls-loop6.js?v=20260821-loop6-v2.2`.
5. Runtime build marker = `v2.2`; unsafe SPA early-return removed so overrides re-arm after panel reinjection.
6. Legacy `ccConfirmarCita()` / `guardarCitaManual()` fail closed unless exact v2.2 runtime is active.
7. Post-deploy rollback canary: legacy Call 0 / legacy Agenda 0 / governed journal 1 + Call 1 + Agenda 1; all synthetic data rolled back.

## Frozen business rules
- Reactivation credit requires >=15 full days from latest qualifying sale / clinical attention / ASISTIO-EFECTIVA, America/Lima.
- <15d Reactivation = management/Agenda allowed but no new commercial `CITA CONFIRMADA`; beneficiary CLINIC.
- NO ASISTIO ownership protected 72h from original slot.
- Other advisor may help during protection but no new conversion; original owner remains.
- >72h transfers only if prior owner has no recorded follow-up.
- Prior-owner follow-up blocks transfer; original-owner rebook creates no second conversion.
- Active PENDIENTE/CITA CONFIRMADA blocks duplicate conversion.
- `FOLLOWUP_CONVERSION` distinct from `CALLBACK_INBOUND`.
- `AGENDA_ONLY` = Agenda only, zero commercial Call/Cita credit.
- Server policy is authoritative over browser selection.
- Journal separates executor, credited advisor, commercial owner, beneficiary, eligibility and ownership transfer.

## Ruben first-canary incident — repaired
Ruben Carlos Dominguez Munoz / `997883711`:
- unique Marketing lead `5884` CAPILAR;
- Mireya follow-up `SEG-1787354621097-4zle` / call `38301` preceded conversion;
- legacy Agenda `2c581c52-89e9-465f-89be-0e3818eda309` originally persisted without direct links/journal;
- strong evidence showed no prior sale, attention or attended/effective appointment.

Certified repair:
- Call `38384` = `CITA CONFIRMADA / FOLLOWUP_CONVERSION / MARKETING / lead 5884 / MIREYA`;
- Agenda now links Call `38384` + lead `5884`, `origen_cita=CALL_CENTER`;
- Seguimiento = COMPLETADO + lead 5884;
- journal `repair-ruben-997883711-20260821-193506` = COMPLETE, creditedAdvisor MIREYA;
- Mireya panel observed at 3 citas after repair (call count dynamic during concurrent work).

Three pre-hotfix Wilmer legacy Agenda rows remain documented without automatic KPI because evidence did not justify new commercial credit: `7d530a24-fe05-43bc-b7ab-a83428050532`, `dc99e863-1e97-49e3-8000-cc420b71bc8a`, `92949454-4c1e-4273-bb7c-9b2b9288e0b2`.

## Protected invariants after V2.2 deploy
- protected repaired Calls `36701,37185,37813,38012,38168,38186`: 6/6 intact;
- removed Alberto/Alan duplicate Agenda IDs: 0 present;
- no new unlinked legacy Call Center Agenda after fail-closed activation;
- REV-F5 = 6 batches / 15,498 source / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events;
- F6 Identity/Lifecycle remain service-role-only;
- Acquisition = V2 56 / V3 57.

## New authoritative V2.2 production baseline
Captured after PR #340 Railway exact-commit SUCCESS and post-deploy fail-closed rollback canary:
- UTC: `2026-08-22T01:17:57.749075+00:00`
- America/Lima: **2026-08-21 20:17:57**
- action journal total: **1**, exclusively Ruben repair audit row;
- policy events: **0**;
- max `aos_llamadas.id`: **38397**;
- Agenda rows: **3152**;
- genuine post-baseline V2.2 operations: **0 / 5**.

Evidence: `docs/control/MKT_INTEGRITY_V3_LOOP6_V22_PRODUCTION_CANARY_20260821.md`.

For terminal certification count only genuine customer actions with `created_at > 2026-08-22T01:17:57.749075+00:00`. Exclude repair/test/admin keys, including `repair-ruben-997883711-20260821-193506`.

## Controlled canary -> terminal gate
The first genuine action after the V2.2 baseline is the new controlled production canary. It must pass server eligibility, executor/credited-owner semantics, Call/Agenda cardinality, direct links, idempotency, no false Marketing acquisition and protected invariants.

If first action fails: STOP Loop 6 again and repair inside the same lane. If PASS: continue ordinary use until >=5 genuine V2.2 actions exist, then execute terminal certification.

Loop 6 remains **PRODUCTION CANARY ACTIVE / NOT YET CERTIFIED**. Active lock remains `MKT-INTEGRITY-HOTFIX-V3`. Loop 7 remains **NOT STARTED**.
