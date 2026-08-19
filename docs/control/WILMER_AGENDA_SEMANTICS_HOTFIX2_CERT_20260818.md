# WILMER / AGENDA SEMANTICS HOTFIX-2 — PRODUCTION CERTIFICATION

**Date:** 2026-08-18 America/Lima  
**Status:** PRODUCTION CERTIFIED

## Scope

- Preserve Wilmer's 12 validated 2026-08-18 appointments in Agenda.
- Remove the corresponding non-commercial scheduling/reagenda rows from `aos_llamadas` so they cannot inflate Calls/Home/Marketing telephone-conversion KPIs.
- Preserve full call payloads in `aos_gestiones_no_comerciales`.
- Prevent future patient-continuation/reagenda `CITA CONFIRMADA` from entering `aos_llamadas`.
- Reconcile `Agenda/CITA_MANUAL first → Marketing lead later → no registered call` by attaching the direct lead to Agenda only; never fabricate a call.

## Wilmer audit

Twelve rows were validated and archived. Classification:

- `PACIENTE_CONTINUIDAD`: **9**;
- `REAGENDA_NO_COMERCIAL`: **3**.

The two new cases found after the initial ten were:

- `910303293` — repeated no-show/reagenda; current appointment 2026-08-24 preserved and linked to lead 5000;
- `982093872` — Marketing lead with prior cancelled/no-show appointments; current appointment 2026-08-22 preserved and linked to lead 4003.

All 12 appointment rows remain in `aos_agenda_citas`. Their call payloads are retained in the non-commercial archive.

## Live Lima-day certification

Using `(now() AT TIME ZONE 'America/Lima')::date = 2026-08-18`:

- Wilmer commercial calls: **103** at certification time;
- Wilmer commercial `CITA CONFIRMADA`: **0**;
- 12 target Agenda rows preserved: **12/12**;
- 12 archived non-commercial call payloads: **12/12**;
- latest Wilmer call at certification: 18:58:21, `SIN CONTACTO`.

The calls count is live and may continue increasing as Wilmer works; the invariant is that the 12 corrected scheduling rows no longer contribute.

## Future prevention proof

Transactional rollback test:

- attempted patient-continuation `CITA CONFIRMADA` persisted in `aos_llamadas`: **0**;
- corresponding non-commercial archive row: **1**;
- synthetic manual Agenda followed by a unique same-day Marketing lead received `lead_id_origen` and `origen='MARKETING'`;
- fabricated calls for that Agenda-only late-lead case: **0**.

## Historical strong Agenda-only late lead backfill

One deterministic historical case was found and repaired:

- Mireya `935740326`, ENZIMAS FACIALES;
- Agenda manual first, lead 4610 later the same day, no close registered call and no prior clinical conversion;
- Agenda now has `lead_id_origen=4610`, `origen='MARKETING'`, campaign label `ENZIMAS FACIALES`;
- no call was created.

## Production migrations

- `wilmer_agenda_semantics_hotfix2_20260818`;
- `late_lead_agenda_origin_marketing_fix_20260818`.

## REV-F5 isolation

Post-hotfix read-back:

- source batches: **6**;
- expected rows: **15,498**;
- source rows: **7,064**;
- clusters: **3,950**;
- members: **0**;
- preview: **0**;
- apply events: **0**;
- patients: **7,679**.

REV-F5-owned state is unchanged and may regain the global mutable lock immediately after this hotfix is merged.
