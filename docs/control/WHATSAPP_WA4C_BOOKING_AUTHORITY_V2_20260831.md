# WA-4C Booking Authority V2 — 2026-08-31

## Frozen authority chain

1. **Panel Equipo = skill authority**
   - `aos_perfiles_profesional.servicios` defines what each clinical professional is authorized to perform.
   - A visible professional without the required capability is never an eligible booking provider.

2. **Catalog = clinical-role authority**
   - `aos_catalogo_servicios.requiere_doctora` / `requiere_enfermeria` determine the required clinical role for the exact active service entity.
   - Dual-role or role-unspecified entities fail closed and require human resolution.

3. **Horarios = presence/site authority**
   - `aos_horarios_personal` is the date-specific source of truth for who is actually working, at which site, and during which attention window.
   - Static profile sede never overrides a date-specific shift.

4. **Canonical resolver = cross-authority decision**
   - `aos_booking_availability_v2()` intersects exact service role + Team skill + date/site schedule + occupied appointments.
   - Trailing slots that overrun the attention window are not emitted.

5. **WhatsApp + public Agenda use the same authority**
   - WA-4C `wa4-booking-resolver.js` consumes `aos_booking_availability_v2`.
   - `agendar-v2.html` consumes the same RPC and writes through `aos_agendar_publica_v2`.

## Booking modes

### DOCTORA — `EXACT_PROVIDER`

- Exact doctor is required.
- Doctor must have the capability selected in Panel Equipo.
- Doctor must have an active shift on the requested date and site.
- Appointment stores the exact doctor.

### ENFERMERIA — `SITE_POOL`

- Patient does **not** select or get promised an individual nurse.
- Eligible pool members are nurses who:
  1. have the capability selected in Panel Equipo; and
  2. are working at that site/date/time.
- Pool capacity is `2 × eligible nurses on shift` per 45-minute arrival slot.
- Booking stores `tipo_atencion=ENFERMERIA`; the individual nurse is assigned operationally at attention time.

## Current attention-window rule

- Nursing L–V: stored attention window remains `11:00–19:30` while labor shift is `10:30–20:30`.
- Saturday: attention `10:00–17:30`; labor shift `09:30–18:30`.
- Holiday: attention `10:00–15:30`; labor shift `09:30–16:30`.
- No slot may start if its configured interval would finish after the attention-window end.

## Fail-closed conditions

- Treatment entity not active.
- Exact service cannot map to a governed Team capability.
- Dual clinical role.
- No eligible professional for capability.
- No date-specific shift at requested site.
- Role-specific schedule source stale.
- Slot no longer available at revalidation.
- WhatsApp identity conflict or actor/assignment ownership failure.

## Safety boundary

WA-4C remains `HUMAN_ONLY / SAFE-OFF` until exact-head CI, merge-lineage, deployment and LIVE canaries are certified. This authority refactor does not enable autonomous send, routing or booking confirmation.
