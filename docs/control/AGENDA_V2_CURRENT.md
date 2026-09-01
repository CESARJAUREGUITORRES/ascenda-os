# ASCENDA OS · AGENDA V2 — CURRENT

Fecha de apertura: 2026-09-01
Baseline: `main@66ac1bfaa92465f061c243578607388926970c32`
Estado: `AGV2-0_INVENTORY_ACTIVE`
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

## AGV2-0 — mapa inicial de superficies de escritura

La cita canónica no se escribe únicamente desde `agenda.js`. El inventario de repo confirma múltiples superficies legacy:

| Superficie | Ruta observada | Riesgo / decisión V2 |
| --- | --- | --- |
| `app/public/agenda.js` | PATCH directo de `aos_agenda_citas` | edición debe migrar a frontera gobernada |
| `app/public/agenda.js` | DELETE directo de `aos_agenda_citas` | eliminación física debe salir del browser; preferir cancelación/state machine salvo caso administrativo explícito |
| `app/public/agenda.js` | reprogramación por `PATCH original + POST nueva` en paralelo | no atómico; migrar a una sola transacción de rebook |
| `app/public/citas.js` / `citas.html` | PATCH/DELETE directos | deben consumir la misma autoridad que Agenda V2 |
| `app/public/citas.html` | reprogramación directa PATCH + POST | segunda ruta legacy de booking; eliminar divergencia |
| `app/public/calls.js` / `calls.html` | POST de cita desde Call Center legacy | ya existe Loop6 governed runtime; mantener únicamente ruta gobernada/postload |
| `app/public/attendance.html` | puede crear `aos_agenda_citas` directamente | revisar ownership: asistencia no debe inventar booking fuera del contrato canónico |
| `app/public/admin-agenda.html` | POST/DELETE directo de `aos_horarios_personal` | horarios requieren frontera administrativa y auditoría propias |

Principio AGV2: no corregir cada pantalla con reglas distintas. Todas las superficies que creen/reprogramen/editen una cita deben converger en un único contrato transaccional.

## Boundary de seguridad encontrado en PROD

`aos_agenda_citas` tiene RLS habilitado, pero conserva políticas legacy permisivas `ALL / true` para `anon` y `authenticated`. Además, los roles `anon` y `authenticated` conservan privilegios de tabla incluyendo `SELECT/INSERT/UPDATE/DELETE`.

Esto significa que la seguridad efectiva actual depende parcialmente de triggers de runtime/origen y de que la UI use rutas gobernadas; no existe todavía un boundary de tabla suficientemente cerrado para Agenda V2.

Agenda V2 debe eliminar esta dependencia gradualmente y sin romper Call Center, WhatsApp, asistencia o integraciones legacy:

1. inventariar cada writer legítimo;
2. darle RPC/función gobernada propia o consolidada;
3. certificar cada writer;
4. retirar writes directos del browser;
5. recién entonces endurecer grants/RLS de la tabla canónica.

No revocar ACL/RLS en PROD durante AGV2-0: podría cortar writers existentes no reconciliados.

## Triggers y side-effects actuales de `aos_agenda_citas`

El ledger tiene side-effects que obligan a que Create/Rebook/State sean transacciones diseñadas, no simples PATCH/POST:

- Loop6 guard para INSERT de origen `CITA_MANUAL` / `CALL_CENTER*`.
- WA-4 governed booking guard para INSERT/UPDATE de origen `WHATSAPP`.
- dedupe de agenda en INSERT.
- cleanup de llamadas legacy para ciertas citas manuales.
- notificaciones en INSERT y en cambios de `estado_cita`.
- asignación de historia clínica al pasar a `ASISTIO`.
- autocreación/enriquecimiento de paciente desde la cita.
- auditoría general INSERT/UPDATE/DELETE.
- dirty marker de Revenue/Sentinel.

Por lo tanto, una operación de Agenda V2 debe preservar deliberadamente los side-effects válidos y retirar los accidentales/duplicados solo con pruebas.

## Status authority CURRENT

`aos_agenda_set_status_v1(...)` ya implementa una frontera fuerte para estados:

- exige sesión 2FA válida para `advisor-agenda` o `admin-agenda`;
- acepta solo `PENDIENTE`, `CITA CONFIRMADA`, `ASISTIO`, `EFECTIVA`, `NO ASISTIO`, `CANCELADA`;
- bloquea la fila con `FOR UPDATE`;
- para `ASISTIO/EFECTIVA` exige autoridad de profesional clínico y crea/actualiza `aos_atenciones`;
- al volver a `PENDIENTE/CITA CONFIRMADA`, preserva atención si ya existen notas clínicas y limpia solo cuando no existen;
- registra auditoría `AGENDA_STATUS_GOVERNED`.

AGV2-3 debe construir la state machine sobre esta base y definir explícitamente qué transiciones entre estados son legales; el RPC actual valida el estado destino, pero todavía no congela una matriz completa `estado anterior → estado nuevo`.

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

## Patrón transaccional reutilizable

`aos_agendar_publica_v2` ya demuestra varias piezas correctas que AGV2-2 puede reutilizar conceptualmente:

- advisory lock de booking;
- llamada a la autoridad de disponibilidad dentro de la operación;
- revalidación del slot inmediatamente antes de insertar;
- fallo `SLOT_NO_LONGER_AVAILABLE` si cambió la disponibilidad;
- resolución de profesional exacto o pool según rol.

No reutilizar ciegamente sus semánticas de token/origen/atribución porque son de agenda pública; el booking interno necesita actor 2FA, owner/asesor y origen interno explícitos.

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

## Próximo gate de arquitectura

Antes de escribir AGV2-2 hay que cerrar AGV2-1 con decisión humana sobre estas reglas de negocio que el código actual no debe imponer por accidente:

- duración/capacidad por procedimiento, no solo por rol;
- cuándo se exige profesional exacto y cuándo pool;
- si una cita puede cambiar de tratamiento sin rebooking;
- reglas de reprogramación y conservación de historial/origen;
- cancelación vs eliminación física;
- estados y transiciones válidas;
- qué datos del paciente son obligatorios al agendar;
- ownership de la cita: asesor, sede, canal y atribución;
- horarios especiales, bloqueos, feriados y excepciones.

## Gate aplazado hasta horario laboral

No fabricar citas PROD para cerrar el workstream. El smoke real de creación/reprogramación y cambio de estado se ejecutará con una sesión legítima de usuario de Agenda durante horario laboral.

Hasta ese gate se permite: inventario read-only, contratos, pruebas locales, diseño de migraciones/UI y canaries sintéticos locales.
