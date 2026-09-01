# ASCENDA OS · AGENDA V2 — CURRENT

Fecha de apertura: 2026-09-01
Baseline: `main@66ac1bfaa92465f061c243578607388926970c32`
Estado: `INVENTORY_AND_ARCHITECTURE`
Mutación PROD: `NO`

## Objetivo

Evolucionar Agenda desde el runtime legacy hacia una operación gobernada, rápida y coherente con la autoridad de booking ya certificada por WA-4C, sin crear una segunda verdad de disponibilidad, profesionales, tratamientos o citas.

## Autoridades que se preservan

1. `public.aos_agenda_citas` permanece como ledger canónico de citas.
2. `public.aos_booking_availability_v2(...)` es la autoridad actual de disponibilidad real.
3. La elegibilidad clínica sigue la cadena canónica:
   `servicio → procedimiento → capability/skill → profesional → horario por fecha/sede → slot/capacidad`.
4. `public.aos_professional_can_service_v1(...)` gobierna si un profesional puede realizar el tratamiento/procedimiento.
5. `public.aos_horarios_personal` es la fuente date-specific usada actualmente por `aos_agenda_dia` y `aos_booking_availability_v2`.
6. El cambio de estado ya está gobernado por `public.aos_agenda_set_status_v1(...)` con sesión fuerte/2FA y permisos de Agenda.
7. HUMAN_ONLY / SAFE-OFF de WhatsApp no cambia por este workstream.

## Readback PROD al abrir Agenda V2

- `aos_horarios_personal`: 525 filas, 520 activas.
- Cobertura date-specific observada: `2026-04-11 → 2026-09-30`.
- `aos_turnos`: 0 filas; no debe asumirse como fuente vigente de disponibilidad sin nueva evidencia.
- Existen además `aos_horarios_profesional` y `aos_config_horarios`, pero Agenda V2 no debe mezclar fuentes hasta reconciliar ownership y propósito.

## Estado legacy confirmado

`app/public/agenda.html` + `app/public/agenda.js` siguen siendo la UI/runtime principal.

El modal Nueva/Editar permite escoger manualmente, entre otros:
- paciente / teléfono / DNI / correo;
- asesor;
- sede;
- tipo de atención;
- doctora;
- fecha;
- hora libre;
- tratamiento;
- tipo de cita;
- estado;
- observación.

Esto permite combinaciones que deberían derivarse de autoridad clínica y disponibilidad, no de decisiones manuales independientes.

`agenda-governed-status-v1.js` solo sustituyó el guardado de estado legacy por una operación atómica gobernada. Creación, edición y reprogramación todavía requieren reconciliación/migración.

## Booking authority ya disponible

`aos_booking_availability_v2` actualmente:
- valida tratamiento activo y tipo SERVICIO;
- resuelve capability y procedimiento;
- valida profesional mediante `aos_professional_can_service_v1`;
- exige horario real de `aos_horarios_personal` para la fecha y sede;
- descuenta ocupación real de `aos_agenda_citas`;
- falla cerrado si la fuente de horarios está stale;
- devuelve únicamente slots reales disponibles.

Reglas técnicas CURRENT a debatir antes de congelar como regla comercial de Agenda V2:
- DOCTORA: slot de 30 min, capacidad 1, profesional exacto.
- ENFERMERIA: pool por sede, slot de 45 min, capacidad técnica actual `2 × enfermeras elegibles presentes`.
- domingo no agendable en `aos_agendar_publica_v2`.

Estas reglas existen hoy, pero NO quedan congeladas como política de negocio por este documento.

## Contrato objetivo Agenda V2

La creación/reprogramación no debe permitir inventar disponibilidad. Flujo objetivo:

1. Identidad del paciente.
2. Tratamiento/servicio exacto.
3. Sistema resuelve procedimiento y rol clínico elegible.
4. Sede.
5. Fecha.
6. Profesionales elegibles y/o pool según regla clínica.
7. Slot REAL retornado por la autoridad de booking.
8. Tipo de cita / contexto clínico-operativo.
9. Revalidación transaccional del slot.
10. Escritura idempotente de la cita con actor, origen y atribución preservados.

## Fases propuestas

### AGV2-0 — Inventory / Truth Map
Mapear UI, RPC, tablas, triggers, estados, side-effects, fuentes de horarios y todas las rutas que crean/editan/reprograman/eliminan citas.

### AGV2-1 — Canonical Booking Contract
Congelar campos obligatorios, reglas de rol, sede, fecha, capacidad, profesional, origen, owner, identidad e idempotencia.

### AGV2-2 — Governed Create/Rebook
Crear una única frontera transaccional para alta y reprogramación desde Agenda, con 2FA/permisos y revalidación de slot. El browser deja de hacer cadenas directas de writes.

### AGV2-3 — Appointment State Machine
Formalizar transiciones válidas y sus responsables: pendiente, confirmada, asistió, efectiva, no asistió, cancelada y reprogramada, incluyendo efectos clínicos y de auditoría.

### AGV2-4 — Agenda UX V2
Rehacer Nueva/Reprogramar como flujo guiado por autoridad real; reducir campos manuales redundantes e impedir combinaciones incompatibles.

### AGV2-5 — Notifications / Side Effects
Separar confirmaciones, recordatorios, email/WhatsApp y no-show de la transacción core de booking. Un fallo de mensajería nunca debe corromper una cita ya confirmada.

### AGV2-6 — Performance / Read Architecture
Eliminar lecturas duplicadas, fijar ownership de vistas día/semana/mes y medir latencia/carga de RPCs críticos.

### AGV2-7 — LIVE Certification
Con sesión 2FA real y horario laboral: crear, reprogramar y cambiar estado de citas reales allowlisted; validar readback, atribución, capacidad, auditoría y side-effects.

## Gate aplazado hasta horario laboral

No fabricar citas PROD para cerrar el workstream. El smoke real de creación/reprogramación y cambio de estado se ejecutará con una sesión legítima de usuario de Agenda durante horario laboral.

Hasta ese gate se permite: inventario read-only, contratos, pruebas locales, diseño de migraciones/UI y canaries sintéticos locales.
