# ASCENDA OS · AGV2-1 — Conversational Booking Contract

Fecha de freeze: 2026-09-01
Baseline main de apertura: `66ac1bfaa92465f061c243578607388926970c32`
Estado: `BUSINESS_FROZEN`
Mutación PROD: `NO`

## Objetivo

Definir cómo una conversación de WhatsApp pasa de intención comercial a una cita real, gobernada y auditable, sin duplicar la autoridad de tratamientos, profesionales, horarios o disponibilidad.

## Principio rector

El usuario no debe decidir manualmente datos que ASCENDA ya puede resolver desde autoridad canónica.

Cadena canónica:

`contexto/campaña → tratamiento/intención → procedimiento/capability → profesional(es) elegibles → sede → horario date-specific → slot real → confirmación explícita → commit gobernado`

Agenda interna y WhatsApp deben converger en la misma autoridad transaccional de booking. La UI y la conversación pueden ser distintas; las reglas y el commit no.

## Interacción comercial

La conversación no debe convertirse en un formulario largo. Primero responde exactamente lo que el prospecto pregunta, con economía de mensajes, y orienta a cita/evaluación cuando sea apropiado.

No hardcodear “evaluación gratuita”. Solo comunicar gratuidad cuando la autoridad comercial vigente del tratamiento/campaña/consulta la confirme. Si la autoridad no lo puede demostrar, se comunica el precio/condición canónica o se evita afirmar gratuidad.

Para tratamientos genéricos como TOXINA, MESOTERAPIA o HIFU, no inundar al prospecto con subvariantes no solicitadas. Resolver primero intención y presentar variantes solo cuando sean necesarias para contestar, cotizar o elegir correctamente el servicio.

## Inicio del modo booking

Cuando el usuario expresa intención inequívoca de agendar, el runtime entra en estado explícito de booking.

Copy objetivo natural:

> Perfecto, te ayudo a agendar. Te pediré unos datos rápidos y luego te mostraré los horarios realmente disponibles.

No exigir formato rígido. El sistema tolera lenguaje natural y repregunta únicamente el campo faltante o ambiguo.

## Datos y fricción

### Tratamiento

Si ya quedó resuelto por conversación/campaña con confianza suficiente, no volver a preguntarlo. Si existe ambigüedad material, aclararla antes de disponibilidad.

### Nombre completo

Solicitar nombres y apellidos en una sola interacción cuando aún no estén confiablemente disponibles. Para una identidad canónica ya conocida, reutilizar lo existente y solo completar faltantes. Al commit debe existir nombre y apellido suficientes para la cita; no duplicar preguntas si la autoridad ya los posee.

### WhatsApp / teléfono

El número inbound de la conversación es la identidad de contacto primaria para WhatsApp. No volver a pedirlo por defecto. Un teléfono alternativo es opcional y debe presentarse explícitamente como diferente al WhatsApp actual.

### Email

Recomendado, no bloqueante. Explicar su utilidad: confirmación y recordatorios por correo. Validar sintaxis antes de persistir. Rechazar un email inválido como dato, pero no cancelar el booking si el usuario prefiere continuar sin email.

### DNI / documento

Opcional durante el booking normal. Puede completarse después o en clínica. Solo podrá convertirse en obligatorio para un servicio concreto si en el futuro existe una regla legal/operativa versionada en la autoridad canónica; nunca por inferencia del bot.

### Sede

Debe resolverse antes de consultar slots porque disponibilidad es sede-específica. Si campaña/contexto ya determina sede, confirmar en lugar de repreguntar.

### Profesional / rol clínico

No preguntar “doctora o enfermería” cuando el tratamiento ya determina capability/rol. El sistema resuelve elegibilidad mediante `aos_booking_availability_v2`, `aos_professional_can_service_v1`, skills/procedimientos y horario date-specific.

Regla congelada de elección profesional:

1. Por defecto priorizar la **primera disponibilidad real** compatible con tratamiento, sede y fecha/preferencia temporal del paciente.
2. Si solo existe un profesional elegible con horario real, no presentar una falsa elección: se informa quién atenderá en la propuesta/confirmación.
3. Si existen varios elegibles, no forzar una pregunta adicional. Se ofrece primera disponibilidad; si el paciente expresa preferencia por profesional, esa preferencia se respeta únicamente si el profesional es elegible y tiene slot real.
4. Agenda interna sí puede exponer un filtro opcional de profesional para operación, pero el backend valida la misma autoridad.

### Tipo de cita

Para un prospecto nuevo que llega por interés comercial, WhatsApp usa por defecto `CONSULTA NUEVA`, salvo que contexto canónico demuestre que corresponde `APLICACION` o `CONTROL`. El bot no debe convertir automáticamente “quiero toxina/HIFU/etc.” en APLICACION.

### Fecha y hora

Nunca aceptar una hora como disponible por simple texto sin validarla. Primero consultar autoridad real; luego presentar fechas/slots válidos. Si el usuario escribe “mañana a las 4”, interpretar intención y comprobar el slot; si no existe, ofrecer alternativas reales.

## Botones y listas

Usar interacción estructurada solo cuando reduce fricción y las opciones son discretas: sede, fecha, slot, confirmar y reprogramar. Preguntas abiertas, objeciones, síntomas, tratamiento y precio siguen siendo conversacionales.

Regla congelada de paginación WhatsApp:

- mostrar inicialmente hasta **3 fechas** próximas relevantes;
- al elegir fecha, mostrar inicialmente hasta **5 slots** reales, ordenados cronológicamente;
- incluir `Ver más`/lista adicional cuando existan más opciones;
- la Agenda interna puede mostrar más resultados por pantalla, pero consume la misma lista canónica y nunca genera horarios propios.

Los botones son aceleradores, no requisito. El texto libre sigue siendo válido y siempre se revalida.

## Confirmación previa al commit

Antes de escribir la cita mostrar resumen mínimo:

- tratamiento;
- sede;
- fecha;
- hora;
- profesional exacto cuando aplique o modalidad de atención/pool cuando corresponda.

Debe existir una acción afirmativa inequívoca del usuario/operador. Después el commit vuelve a validar el slot dentro de la transacción. Si dejó de estar disponible, no crea la cita y exige reselección.

## Reprogramación — modelo congelado

Se adopta **un mismo appointment lógico (`aos_agenda_citas.id`) + event ledger append-only**.

Reprogramar NO crea una segunda cita lógica ni elimina la anterior. Actualiza fecha/hora/sede/profesional del mismo appointment bajo lock transaccional y registra un evento `RESCHEDULED` con snapshot anterior/nuevo, actor, canal, conversación y motivo cuando exista.

Consecuencias:

- `booking_created` y `rebooking` son métricas distintas;
- no se inflan citas generadas;
- se conserva trazabilidad completa;
- el tratamiento no cambia durante una reprogramación. Cambiar tratamiento es una edición clínica/comercial diferente y debe volver a resolver autoridad.

El sistema debe detectar intención de reprogramar en lenguaje natural y resolver la cita activa por identidad/conversación. Si hay más de una candidata, pregunta cuál antes de mutar.

## Post-booking y notificaciones

El commit de booking/rebooking termina primero. Email y WhatsApp son side-effects posteriores y nunca forman parte de la transacción core.

Política congelada:

1. con email válido, encolar `confirmacion_cita` después de BOOK;
2. con email válido, encolar `reprogramacion` después de REBOOK;
3. mantener recordatorios transaccionales `recordatorio_manana` y `recordatorio_hoy` según scheduler vigente, evitando doble envío por clave idempotente;
4. `bienvenida` es un evento de relación/onboarding y no se dispara por cada cita; nunca debe duplicar una confirmación;
5. `no_asistencia` pertenece al flujo posterior de estado/no-show, no al commit de booking;
6. un fallo de Resend/Meta nunca revierte la cita confirmada; el side-effect se reintenta por separado.

## Continuidad

La conversación mantiene contexto del mismo número/conversación. Una respuesta a recordatorio no abre un lead nuevo cuando la identidad canónica permite asociarla a paciente/cita existente. Ninguna modificación de agenda se ejecuta sin confirmación explícita.

## WhatsApp Cost Intelligence

El recorrido objetivo debe permitir:

`campaña/anuncio → conversación → mensajes/costo Meta → AI runs/costo IA → BOOK/REBOOK → asistencia/no-show → venta → facturación`

Fuentes CURRENT:

- `aos_wa_messages_v1`: conversación, dirección, estado, pricing category/model y billable;
- `aos_wa_ai_runs_v1`: tokens, modelo, latencia y costo IA estimado;
- `aos_wa_attribution_touchpoints_v1`: campaña/anuncio/origen/paciente;
- `aos_wa4_booking_actions_v1`: vínculo booking-conversación.

Costo Meta exacto requiere autoridad de pricing versionada y/o costo efectivo por evento; `billable` por sí solo no es importe.

Popup objetivo por conversación: mensajes, billable/non-billable/unknown, costo Meta, costo IA, costo total, BOOK/REBOOK, asistencia/no-show, venta/facturación atribuida, costo por booking/asistencia/venta.

## Reglas comerciales cerradas

1. Profesional: primera disponibilidad por defecto; preferencia solo cuando el paciente la expresa y es válida.
2. Evaluación gratuita: solo si autoridad comercial la demuestra; nunca hardcoded.
3. Reprogramación: mismo appointment + event ledger append-only.
4. DNI: opcional salvo futura regla canónica explícita.
5. Email: opcional para booking; confirmación/reprogramación/recordatorios como side-effects idempotentes; bienvenida separada.
6. Opciones WhatsApp: 3 fechas iniciales y 5 slots iniciales, con `Ver más`.
7. Tipo de cita comercial inbound: `CONSULTA NUEVA` por defecto salvo contexto canónico contrario.
8. Teléfono WhatsApp: reutilizar inbound; no repreguntar por defecto.

## Gate

`AGV2-1 = BUSINESS FROZEN`.

Cualquier cambio posterior de estas reglas requiere una versión nueva del contrato y regresión de Agenda + WhatsApp.
