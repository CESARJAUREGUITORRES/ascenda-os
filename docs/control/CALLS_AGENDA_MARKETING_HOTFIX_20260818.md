# ASCENDA OS — Calls / Agenda / Marketing Hotfix — 2026-08-18

**Status:** EXECUTION / production-safety hotfix  
**Lock:** `HOTFIX-CALLS-AGENDA-MARKETING-20260818`  
**Source main:** `957bf7b4fbd7da9b2049346b74ac5e73ea260053`  
**Supabase:** `ituyqwstonmhnfshnaqz`

## Business contract

- Agenda-only and continuation appointments are not Call Center calls and must not inflate call/conversion/productivity KPIs.
- A genuine Call Center call that produces an appointment counts once.
- A genuine conversion with no Marketing lead is classified `ORGANICO`; actual treatment remains available as acquisition detail and the row is excluded from paid-campaign CPL/CAC/ROAS cohorts.
- Repeated clicks/retries must not create duplicate appointments or duplicate conversions.
- A paid lead uploaded after an already-completed call/appointment may receive explicit origin linkage only with deterministic/high-confidence evidence; ambiguous history remains unresolved.

## Root causes verified

1. The legacy `CITA_MANUAL` flow can submit an Agenda row and an artificial `CITA CONFIRMADA` call in parallel.
2. Call Center KPIs count `aos_llamadas.estado='CITA CONFIRMADA'`, so artificial rows inflate productivity and conversion metrics.
3. Recent calls were not persisting `lead_id_origen`, so Marketing Attribution V2 could lose conversions when a lead was uploaded after the call.
4. The Marketing “Ver Leads” list was cohort-oriented and therefore omitted prior-period paid leads converted today and true organic conversions.
5. Multiple historical technical duplicates exist where two `CITA CONFIRMADA` rows were written within a few seconds for the same appointment.

## Correction

The migration:

- installs a server-side call guard for one conversion per advisor/number/day;
- classifies deterministic paid origin and true organic origin at write time;
- installs Agenda duplicate suppression for identical rapid repeats;
- removes artificial call rows created by the legacy `CITA_MANUAL` dual-write regardless of request ordering;
- reconciles future same-day late-loaded leads when a co-temporal appointment proves the relationship;
- backs up and removes only proven technical/fabricated duplicate call rows;
- backfills deterministic late-load origin links without touching ambiguous cases;
- corrects the validated Mireya acquisition set to three paid Marketing conversions plus one Organic conversion;
- makes the Marketing activity list include paid conversions worked in the selected period even if the lead entered earlier, plus explicit Organic rows;
- keeps paid cohort analytics separate from operational acquisition activity;
- extends V2 call→appointment matching only where explicit linked-call evidence exists.

## Pre-production gates

- Integrated full migration test executed under `BEGIN ... ROLLBACK`: PASS.
- Expected “Hoy” result after simulated apply: 4 target conversions visible, including 1 Organic.
- Expected Mireya confirmed calls after simulated apply: 4 rows / 4 unique numbers = 3 Marketing + 1 Organic.
- Proven duplicate/fabricated rows for the validated incident disappear in rollback simulation.
- F5 isolation in rollback: `aos_f5_patient_source_rows_v1=7064`; `aos_pacientes=7679`.

## REV-F5 isolation

REV-F5 is paused at `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_CALLS_AGENDA_MKT.md`. This hotfix must not mutate F5-owned tables. After production certification the global lock is returned immediately to `REV-F5-CLOSEOUT` and F5 resumes from the reconciled persisted checkpoint, never from the obsolete 1,000-row state.
