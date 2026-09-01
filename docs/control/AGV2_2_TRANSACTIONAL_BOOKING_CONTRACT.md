# ASCENDA OS · AGV2-2 — Unified Transactional Booking Contract

Fecha: 2026-09-01
Baseline de diseño: `main@66ac1bfaa92465f061c243578607388926970c32`
Depende de: `AGV2-1 = BUSINESS FROZEN`
Estado: `IMPLEMENTATION_IN_PROGRESS`

## Objetivo

Construir una sola frontera transaccional para crear y reprogramar citas desde:

- Agenda interna;
- WhatsApp Revenue Hub.

La UI o el canal no son autoridad de disponibilidad. Ambos deben consumir el mismo core de booking y el mismo ledger de eventos.

## Invariantes

1. `aos_agenda_citas` sigue siendo el ledger canónico CURRENT de la cita.
2. Un BOOK crea exactamente un appointment lógico.
3. Un REBOOK modifica el mismo `appointment_id`; no duplica la cita.
4. Cada mutación se registra en un event ledger append-only.
5. Toda operación exige `idempotency_key` y request hash.
6. Toda selección de slot se revalida bajo lock antes de escribir.
7. Tratamiento debe ser ACTIVO y `tipo=SERVICIO`.
8. Rol/profesional deben derivarse de authority, no de texto libre.
9. `AMBOS` significa una ruta clínica elegible u otra, nunca ambos profesionales obligatorios.
10. El teléfono debe poder resolver identidad; `IDENTITY_CONFLICT` falla cerrado.
11. Email y DNI no son bloqueantes según AGV2-1.
12. Email/WhatsApp de confirmación no se ejecutan dentro de la transacción core.
13. WhatsApp mantiene HUMAN_ONLY / SAFE-OFF: el wrapper conserva ownership y active assignment.
14. Agenda interna exige sesión fuerte/2FA y permiso de Agenda.
15. Un mismo contrato lógico gobierna ambos canales; wrappers solo autentican/derivan contexto.

## Modelo

### `aos_booking_operations_v2`

Ledger idempotente de operaciones BOOK/REBOOK.

Campos esenciales:

- `id`;
- `idempotency_key` UNIQUE;
- `request_hash`;
- `operation_type` (`BOOK`,`REBOOK`);
- `channel` (`AGENDA`,`WHATSAPP`);
- `actor_id`;
- `conversation_id` nullable;
- `appointment_id`;
- `treatment_id`;
- `professional_ref`;
- `site`, `appointment_date`, `appointment_time`;
- `identity_state`;
- `campaign_source`, `ad_id`, `lead_id`;
- `status`;
- `response`;
- timestamps.

Un replay con misma key + mismo hash devuelve el mismo resultado. Misma key + otro payload falla cerrado.

### `aos_agenda_events_v2`

Event ledger append-only del appointment.

Eventos iniciales:

- `BOOKED`;
- `RESCHEDULED`.

Cada evento conserva snapshot anterior/nuevo y contexto de actor/canal/conversación. AGV2-3 ampliará la máquina de estados sin alterar el historial de booking.

## Payload BOOK

Campos de autoridad:

- `treatment_id` requerido;
- `site` requerido;
- `date` requerido;
- `time` requerido;
- `professional_id` requerido para ruta `DOCTORA`;
- `slot_role` recomendado y requerido conceptualmente para servicios AMBOS; compatibilidad temporal: si falta, se infiere DOCTORA con professional_id y ENFERMERIA sin professional_id;
- `appointment_type` default `CONSULTA NUEVA`;
- `name`, `last_name` completables desde identidad canónica;
- `email` opcional;
- `dni` opcional.

Agenda añade teléfono en payload. WhatsApp lo deriva de la conversación y no confía en un número enviado por el browser/runtime.

## Resolución de slot

1. normalizar sede;
2. cargar tratamiento activo;
3. resolver rol elegido compatible con el tratamiento;
4. validar provider exacto para DOCTORA o SITE_POOL para ENFERMERIA;
5. consultar `aos_booking_availability_v2`;
6. verificar que el slot exacto está `disponible=true`;
7. adquirir advisory lock por provider/pool + fecha + hora + sede;
8. consultar nuevamente autoridad;
9. solo entonces escribir.

No existe camino `force=true`, override de capacidad o hora inventada en este contrato.

## Identidad

La identidad primaria se resuelve por teléfono con `aos_rev_resolve_patient_identity_v2`.

- `MATCH`: reutilizar paciente canónico y completar datos faltantes.
- `UNRESOLVED`: permitir BOOK con identidad mínima si nombre+apellido y teléfono son suficientes.
- `IDENTITY_CONFLICT`: falla cerrado y requiere humano.
- cualquier estado inesperado: falla cerrado.

No fusionar pacientes dentro del commit de booking.

## Wrapper Agenda

`aos_agenda_commit_booking_v2(token, idempotency_key, payload)`:

- valida `advisor-agenda` o `admin-agenda` mediante `aos_app_actor_v3`;
- exige sesión fuerte/2FA según autoridad vigente;
- deriva actor/código;
- acepta teléfono del formulario/paciente;
- llama al core;
- no escribe `aos_agenda_citas` directamente desde browser.

## Wrapper WhatsApp

`aos_wa4_commit_booking_v1(actor_id, idempotency_key, conversation_id, payload)` se mantiene como contrato de compatibilidad, pero delega en el core V2.

Antes de delegar conserva:

- conversación existente;
- owner exacto;
- estado `HUMAN_ACTIVE`/`AI_COPILOT`;
- assignment ACTIVE;
- trusted phone de conversación;
- campaña/ad/lead del contexto WA.

No envía mensajes ni fabrica una llamada de Call Center.

## REBOOK

Core separado sobre el mismo modelo:

- lock de appointment;
- teléfono/contexto deben pertenecer al appointment cuando canal=WHATSAPP;
- tratamiento se conserva;
- consultar nuevo slot con la misma autoridad;
- adquirir lock de nuevo slot;
- update atómico del mismo `aos_agenda_citas.id`;
- registrar `RESCHEDULED` con snapshots before/after;
- escribir operación idempotente `REBOOK`;
- volver a `PENDIENTE` temporalmente hasta que AGV2-3 congele una semántica distinta de estado post-rebook.

Cambiar tratamiento NO es REBOOK.

## Resultado estándar

Éxito BOOK:

```json
{
  "ok": true,
  "status": "BOOKED",
  "appointment_id": "...",
  "operation_id": "...",
  "idempotent_replay": false,
  "site": "SAN ISIDRO",
  "date": "2026-09-02",
  "time": "12:30",
  "professional_role": "DOCTORA",
  "booking_mode": "EXACT_PROVIDER",
  "professional_id": "...",
  "professional_name": "...",
  "identity_state": "MATCH"
}
```

REBOOK usa `status=REBOOKED` e incluye snapshot nuevo. Los códigos de error son estables y machine-readable.

## Side-effects

El core solo emite evento persistido. AGV2-5 será responsable de convertir `BOOKED/RESCHEDULED` en intenciones idempotentes de:

- email;
- WhatsApp template/message;
- recordatorios;
- notificaciones internas.

Esto evita que un proveedor externo convierta un BOOK exitoso en error o duplicado.

## Compatibilidad y rollout

1. Implementar tablas + core + wrappers en migración aditiva.
2. Mantener firmas de WA existentes.
3. Ejecutar full local y canaries actuales sin regresión.
4. Agregar canaries AGV2 de BOOK Agenda sintético local, BOOK WhatsApp y REBOOK.
5. Merge exact-head.
6. Aplicar PROD solo desde lineage fusionado.
7. No cambiar todavía UI legacy hasta AGV2-4.
8. Smoke LIVE con sesión real y horario laboral se reserva para AGV2-7.

## Gate AGV2-2

Se considera implementado técnicamente cuando:

- migración local rebuild PASS;
- idempotency PASS;
- slot race/revalidation PASS;
- Agenda strong-session wrapper PASS;
- WA ownership/assignment wrapper PASS;
- BOOK y REBOOK event ledger PASS;
- mismo appointment en REBOOK PASS;
- full WA-4C canaries sin regresión PASS;
- rollback disponible.
