# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / MKT-INTEGRITY-HOTFIX-V3 ACTIVE — LOOP 6 V2.3 PRODUCTION CANARY 0/5 GENUINE OPERATIONS  
**Captured:** 2026-08-21 21:27:02 America/Lima  
**Functional runtime:** `0318597188fbd358b9b207181426094154766d55`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**CURRENT GATE:** `LOOP 6 V2.3 — minimum 5 genuine post-cutover Call Center operations + terminal readback`  
**LOOP 7:** `NOT STARTED`

GitHub CURRENT + Supabase LIVE remain authoritative. Do not release the MKT lock or certify Loop 6 terminally until five genuine customer operations after the V2.3 baseline are observed and audited. Synthetic canaries, repairs and administrative actions do not count.

## Portfolio lock state
- `REV-RUNTIME-BRIDGE-HOTFIX`: CLOSED / RELEASED.
- REV-F5: PRODUCTION CERTIFIED — 100%.
- REV-F6.0–F6.7 / REV-F6 global: PRODUCTION CERTIFIED — 100%.
- REV-F7: NEXT / UNBLOCKED, paused while MKT owns the single HIGH/CRITICAL mutable lane.

## Loop 6 runtime lineage
- PR #335 — atomic Call Center semantics + F6 decision layer: MERGED.
- PR #337 — 15-day reactivation + 72h ownership/recovery V2: MERGED at `521c013209702a7c26ddafed23799f9c36236481`.
- PR #338 — retry/idempotency precheck: MERGED at `7e5e7915b4c771649e50fd11e2af767819383052`.
- PR #340 — V2.2 legacy-bypass fail-closed + cache-bust + Rubén repair evidence: MERGED at `f6adba60358d7d45ef547ba29f0189767b0355e9`.
- PR #342 — V2.3 automatic queue semantics + Carlos repair + frontend hardening: MERGED at `0318597188fbd358b9b207181426094154766d55`.
- Railway exact-commit status for `0318597188fbd358b9b207181426094154766d55`: SUCCESS (`ASCENDA-OS - ascenda-os`).

## V2.3 exact-head CI certification
Premerge exact head: `62f9289e8df8085a22ec6eab6881d6e650ba53d8`.
All required gates passed on the same head:
- Ascenda CI: SUCCESS.
- Loop6 Runtime Loader Patch: SUCCESS.
- ASCENDA CIA Phase 16 Email Contracts: SUCCESS.
- Sentinel F6 Business Health Certificate: SUCCESS.

The runtime patcher was hardened to be idempotent when re-run over an already materialized V2.3 runtime. The post-commit success modal JavaScript syntax defect found by CI was corrected before merge.

## V2.3 Call Center contract
### Normal queue
- No semantic selector is shown to the advisor for the normal queue happy path.
- Browser does not choose authoritative `action_type`.
- `aos_callcenter_confirm_queue_appointment_v1` validates lead↔phone and derives the allowed action server-side.
- New / unconverted eligible lead -> governed commercial Call + Agenda + direct links + journal.
- Follow-up source -> server derives FOLLOWUP conversion semantics.
- Converted patient -> automatic commercial conversion is blocked and explicit patient exception flow is required.
- Identity conflict -> fail closed / REVIEW.
- Active appointment -> no duplicate conversion.

### Agenda Manual
Exactly three semantic choices remain available:
1. `COMMERCIAL` — commercial manual call.
2. `CALLBACK` — callback / inbound / follow-up.
3. `AGENDA_ONLY` — Agenda only, zero commercial Call/Cita credit.

### Post-commit UX
- Success UI appears only after the governed queue commit succeeds.
- Success modal has one forward action: `CONTINUAR LLAMADAS`.
- No Cancel button is exposed after a successful commit.
- `loadLead()` is not executed inside the queue commit block; the next lead loads only after the advisor confirms the post-commit success modal.

## Frozen business rules
- Reactivation credit requires >=15 full days from latest qualifying sale / clinical attention / ASISTIO-EFECTIVA, America/Lima.
- <15d Reactivation = management/Agenda allowed but no new commercial `CITA CONFIRMADA`; beneficiary CLINIC.
- NO ASISTIO ownership protected 72h from original slot.
- Other advisor may help during protection but no new conversion; original owner remains.
- >72h transfers only if prior owner has no recorded follow-up.
- Prior-owner follow-up blocks transfer; original-owner rebook creates no second conversion.
- Active PENDIENTE/CITA CONFIRMADA blocks duplicate conversion.
- `FOLLOWUP_CONVERSION` remains distinct from `CALLBACK_INBOUND`.
- `AGENDA_ONLY` = Agenda only, zero commercial Call/Cita credit.
- Server policy is authoritative.
- Journal separates executor, credited advisor, commercial owner, beneficiary, eligibility and ownership transfer.

## Rollback canary certification
The V2.3 backend / policy suite passed rollback canaries covering:
- healthy Marketing queue conversion;
- converted patient >=15d exception path;
- converted patient <15d downgrade;
- active appointment duplicate block;
- NO ASISTIO <72h ownership protection;
- NO ASISTIO >72h eligible transfer;
- PHONE identity conflict fail-closed;
- Agenda Manual commercial;
- Agenda Manual callback/inbound;
- Agenda-only 0 Call / 1 Agenda;
- legacy fail-closed Call and Agenda;
- retry/idempotency cardinality;
- Follow-up -> FOLLOWUP_CONVERSION derivation;
- Carlos second-run idempotency;
- Rubén regression.

All synthetic canaries were executed in rollback and left zero synthetic residue.

## Rubén regression — frozen PASS
Rubén Carlos Dominguez Munoz / `997883711`:
- Call `38384` = `CITA CONFIRMADA / FOLLOWUP_CONVERSION / MARKETING / lead 5884 / MIREYA`;
- Agenda `2c581c52-89e9-465f-89be-0e3818eda309` links Call `38384` + lead `5884`;
- journal `repair-ruben-997883711-20260821-193506` = COMPLETE;
- current cardinality at baseline: 1 Call / 1 Agenda / 1 journal.

## Carlos repair — frozen PASS
Carlos Alonso Aguilar Uceda / `941764266`:
- prior Call `38396` remains `SIN CONTACTO` and was not overwritten;
- governed repair Call `38437` = `CITA CONFIRMADA / MARKETING / lead 5894 / MIREYA`;
- Agenda `53039d52-4392-4557-a50f-58da21090ab7` links Call `38437` + lead `5894`;
- journal `repair-carlos-941764266-20260821-v23` = COMPLETE;
- repair second-run proved idempotency: exactly 1 commercial Call / 1 Agenda / 1 journal.

## Wilmer legacy review
Three pre-hotfix Wilmer Agenda rows remain REVIEW / NO AUTO CREDIT because the audit found no contemporaneous recorded follow-up and no auditable WhatsApp evidence proving the required management. No KPI was fabricated.

## Protected invariants at V2.3 baseline
- protected repaired Calls `36701,37185,37813,38012,38168,38186`: 6/6 intact;
- removed Alberto/Alan duplicate Agenda IDs: 0 present;
- REV-F5 = 6 batches / 15,498 source / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events;
- Rubén = 1 Call / 1 Agenda / 1 journal;
- Carlos = 1 commercial Call / 1 Agenda / 1 journal + prior Call intact;
- policy events = 0;
- no synthetic V2.3 canary residue.

## Authoritative V2.3 production baseline
Captured after PR #342 merge + Railway exact-commit SUCCESS:
- UTC: `2026-08-22T02:27:02.696935+00:00`
- America/Lima: **2026-08-21 21:27:02**
- action journal total: **2** — Rubén repair + Carlos repair;
- policy events: **0**;
- max `aos_llamadas.id`: **38437**;
- Agenda rows: **3153**;
- genuine post-cutover V2.3 operations: **0 / 5**.

For terminal certification, count only genuine customer actions with `created_at > 2026-08-22T02:27:02.696935+00:00`. Exclude repair/test/canary/admin keys and synthetic operations.

## Terminal 5-operation gate
The first genuine operation after the V2.3 baseline is the controlled live canary. For each of the first five genuine operations audit:
1. executor/advisor;
2. patient/prospect classification;
3. effective semantic action;
4. Call cardinality and state;
5. Agenda cardinality and direct links;
6. lead/origin attribution;
7. credited advisor/commercial owner/beneficiary;
8. eligibility/ownership rule;
9. idempotency / no duplicate on retry;
10. KPI and Marketing attribution correctness.

If any of the first five genuine operations violates the contract: STOP Loop 6 and repair inside the same MKT lane. If all five pass, execute terminal invariant readback and certify Loop 6 100%, then release the MKT lock. Do not auto-start Loop 7.

Loop 6 remains **PRODUCTION CANARY ACTIVE / TERMINAL HUMAN-EVIDENCE GATE 0/5**. Active lock remains `MKT-INTEGRITY-HOTFIX-V3`. Loop 7 remains **NOT STARTED**.
