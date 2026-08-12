# ASCENDA OS — JANUARY 2026 RECONCILIATION

**Updated:** 2026-08-12 (America/Lima)

This document contains only non-PII control information. Patient-level matrices and identity evidence belong in Supabase/private sources, not GitHub.

## Financial gate

January transactional reconciliation is certified at:

- **191 sales**
- **S/91,029.60**
- daily row counts reconciled
- daily totals reconciled
- transaction-level operational fields reconciled for the January source

Do not change January financial facts unless new primary evidence proves an error.

## Attendance reconstruction rule

For the historical 2026 pass:

1. A recorded sale is evidence that the customer was physically present at a clinic site on that date.
2. Advances, balances and partial payments made through the clinic count as presence.
3. `MERCADOPAGO` on a **service** still counts as clinic presence.
4. Automatic web exclusion: `COMPRA DE PRODUCTO + MERCADOPAGO` when the operation is an online product sale.
5. Clinic staff purchases remain sales but **do not count as patient visits**.
6. Visit grain is **patient + date + site**, not sale row. Multiple financial rows on the same day can belong to one visit.

## January attendance baseline before final write

Derived from the certified January sales:

- 94 physical-presence sale events after excluding the single online product/MercadoPago case
- 1 of those events belongs to clinic staff and is excluded from the patient-visit metric
- **93 patient visits** to represent historically
- 82 patient visits already have a compatible Agenda record
- 11 patient visits do not have a compatible Agenda record
- 78 matched visits already have `ASISTIO` or `EFECTIVA`
- 3 matched visits are `PENDIENTE` despite compatible on-site sales evidence
- 1 matched visit has ambiguous `NO ASISTIO` history and requires a separate historical attendance record rather than overwriting an arbitrary scheduled time
- 9 patient/date/site combinations have more than one compatible appointment; do not collapse these automatically because some represent distinct treatments or legitimate multiple bookings

## Planned final Agenda remediation

Current guarded plan:

- **3 appointment status updates**: `PENDIENTE -> ASISTIO`
- **11 historical appointment inserts** for patient visits with no compatible appointment
- **1 additional historical attendance insert** for the ambiguous `NO ASISTIO` case, without inventing a time
- **0 patient-visit insert** for the clinic-staff purchase
- **15 Agenda changes total**
- **0 changes to January sale count or revenue**

Historical appointments must not invent a time. Use `hora_cita = NULL` when the source proves the date/site/presence but not the hour.

## Identity rule

Identity cleanup is longitudinal and must not block the sales/attendance close when the visit itself is already evidenced.

- Do not overwrite a cleaner canonical phone/DNI from a suspicious spreadsheet cell.
- Name + repeated phone + existing patient history can be stronger evidence than a single historical DNI cell known to suffer spreadsheet autofill corruption.
- Conflicting identities remain explicitly flagged for the later master-filiation pass.
- Patient merges are separate HIGH-risk operations and require their own dependency check.
- PII and patient-level identity matrices must not be committed to GitHub.

## Supabase persistence model

The monthly reconciliation should persist private matrices in Supabase using dedicated control tables for:

- monthly reconciliation status and checksums
- identity-resolution matrix
- visit-evidence matrix
- change/snapshot/rollback log

These tables should have RLS enabled and no broad client policies.

## Current operational blocker on 2026-08-12

At the final write gate, Supabase production began returning widespread database timeouts. Evidence includes:

- admin SQL connector: `Connection terminated due to connection timeout`
- Postgres logs: repeated `canceling statement due to statement timeout`
- live REST/RPC traffic from ASCENDA returning HTTP `522` across multiple endpoints

The Supabase management plane still reports the project as `ACTIVE_HEALTHY`, but the data plane is not healthy enough for a guarded production write.

**Safety decision:** do not execute the January write transaction while even read-only preflight queries cannot complete. Resume with preflight -> snapshot -> guarded transaction -> post-check when the database connection layer is stable.

## January close target

After the guarded write succeeds and post-checks pass, set January to:

`VALIDATED_SALES_VISITS`

This means sales and historical patient visits are complete for the month. Master identity/filiation and product canonicalization remain separate later phases and do not block moving to February.
