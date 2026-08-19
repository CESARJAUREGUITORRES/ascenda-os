# WILMER VALID RECOVERY CORRECTION — PRODUCTION CERTIFICATION

**Date:** 2026-08-18 America/Lima  
**Status:** PRODUCTION CERTIFIED

## Corrected business rule

A prior `NO ASISTIO` or `CANCELADA` appointment does **not** make a lead/patient non-commercial by itself.

A Call Center `CITA CONFIRMADA` remains a valid commercial conversion when:

- it comes from a Marketing lead, current or historical, and there is a real call/management event that produces a new appointment;
- the lead had prior appointments but never converted clinically (`NO ASISTIO` / `CANCELADA` only), so the advisor is legitimately recovering the lead;
- it is a manually entered organic number in Call Center with no prior lead/patient history, producing a real call and appointment.

A `CITA CONFIRMADA` is excluded from commercial Calls KPIs only when there is evidence of actual patient continuity before the event, including prior sale, clinical attention, assisted/effective appointment, or explicit operational text such as session/control/debt/application/antiguo.

## Wilmer correction

Two records removed too aggressively by HOTFIX-2 were restored from their full audit payloads:

- call `37045`, number `910303293`, CAPILAR, Marketing lead `5000`;
- call `37060`, number `982093872`, ENZIMAS FACIALES, Marketing lead `4003`.

Both are valid lead-recovery conversions. Their appointments remain in Agenda and were restored to `origen_cita='CALL_CENTER'` with direct `llamada_id_origen` + `lead_id_origen` traceability.

The other ten Wilmer 2026-08-18 records remain excluded because they are proven patient continuity/sessions with prior clinical or commercial conversion evidence.

At certification time (Lima day 2026-08-18):

- Wilmer commercial calls: **107** (live count; can continue increasing);
- Wilmer commercial `CITA CONFIRMADA`: **2**;
- restored calls: **2/2**;
- other ten excluded calls present in `aos_llamadas`: **0**.

## Preventive rollback gates

1. Marketing lead + prior `NO ASISTIO` only + real new call => persists as Marketing conversion.
2. New manual organic number with no history => persists as `ORGANICO`; treatment remains measurable via `anuncio`.
3. Prior real patient sale => call is suppressed from commercial calls and archived as patient continuity.

All three gates passed under transaction rollback.

## Production migration

`wilmer_valid_recovery_correction_20260818`

## REV-F5 isolation

No REV-F5-owned state changed:

- source rows: **7,064 / 15,498**;
- clusters: **3,950**;
- members: **0**;
- preview: **0**;
- apply events: **0**;
- patients: **7,679**.

REV-F5 remains/reclaims the sole mutable workstream after this correction.
