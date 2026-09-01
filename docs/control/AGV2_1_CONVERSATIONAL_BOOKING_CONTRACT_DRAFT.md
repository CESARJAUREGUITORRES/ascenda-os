# ASCENDA OS · AGV2-1 — Conversational Booking Contract (DRAFT)

Fecha: 2026-09-01
Baseline main: `66ac1bfaa92465f061c243578607388926970c32`
Estado: `DRAFT_FOR_BUSINESS_FREEZE`
Mutación PROD: `NO`

## Objetivo

Definir cómo una conversación de WhatsApp pasa de intención comercial a una cita real, gobernada y auditable, sin duplicar la autoridad de tratamientos, profesionales, horarios o disponibilidad.

## Principio rector

El usuario no debe decidir manualmente datos que ASCENDA ya puede resolver desde autoridad canónica.

Cadena:

`contexto/campaña → tratamiento/intención → procedimiento/capability → profesional(es) elegibles → sede → horario date-specific → slot real → confirmación explícita → commit gobernado`

## Interacción comercial

La conversación no debe convertirse en un formulario largo. Primero responde lo que el prospecto pregunta, con economía de mensajes, y orienta a una cita/evaluación cuando sea apropiado.

No hardcodear “evaluación gratuita” globalmente. Solo ofrecerla como gratuita cuando la autoridad comercial vigente del tratamiento/campaña lo permita; de lo contrario usar el precio/condición canónica de consulta.

Para tratamientos genéricos (p.ej. TOXINA, MESOTERAPIA, HIFU), no inundar al prospecto con subvariantes no solicitadas. Resolver primero su intención y presentar detalles adicionales únicamente cuando sean necesarios para responder o elegir correctamente el servicio.

## Inicio del modo booking

Cuando el usuario expresa intención inequívoca de agendar, el runtime entra en un estado de booking explícito. Copy objetivo natural, no coercitivo:

> Perfecto, te ayudo a agendar. Te pediré unos datos rápidos y luego te mostraré los horarios realmente disponibles.

No exigir que el usuario responda con un formato rígido. El sistema debe tolerar lenguaje natural y repreguntar solo el campo faltante o ambiguo.

## Datos y fricción

### Tratamiento

Si ya quedó resuelto por conversación/campaña y la confianza es suficiente, no volver a preguntarlo. Si existe ambigüedad material, aclararla antes de consultar disponibilidad.

### Nombre completo

Solicitar nombres y apellidos en una sola interacción. Preservar también el valor textual completo recibido; separar campos cuando sea posible y pedir aclaración solo si es realmente necesario para persistencia canónica.

### WhatsApp / teléfono

El número inbound de la conversación es la identidad de contacto primaria. No volver a pedirlo por defecto. Si el negocio necesita un teléfono alternativo, debe solicitarse como opcional y explícitamente diferente al WhatsApp actual.

### Email

Recomendado, pero no bloqueante para una cita normal. Explicar el valor: confirmación y recordatorios por correo. Validar sintaxis antes de guardar. El booking debe poder cerrarse aunque el usuario no quiera dejar email.

### DNI / documento

No convertirlo en requisito de booking sin una regla legal/operativa explícita. Puede solicitarse opcionalmente o completarse después/en clínica. Un prospecto que no entregue DNI no debe perder un slot si el resto del contrato permite identificarlo de forma suficiente.

### Sede

Debe resolverse antes de consultar slots, porque la disponibilidad es sede-específica. Si el contexto ya determina sede, puede confirmarse en vez de repreguntarse.

### Profesional / rol clínico

No preguntar “doctora o enfermería” cuando el tratamiento ya determina capability/rol. El sistema resuelve profesionales elegibles usando `aos_booking_availability_v2` + `aos_professional_can_service_v1` + horario date-specific.

Si solo existe un profesional elegible con horario real, no presentar una falsa elección; informar el profesional en la propuesta/confirmación. Si existen varios, se puede ofrecer preferencia o primera disponibilidad según la política que se congele.

### Fecha y hora

Nunca aceptar una hora como disponibilidad por simple texto sin validarla. Primero consultar autoridad real; luego presentar fechas/slots válidos. El usuario puede elegir mediante botones/listas interactivas o lenguaje natural, pero el backend siempre valida contra la misma autoridad.

## Uso de botones/listas en WhatsApp

Usar interacción estructurada únicamente donde reduce fricción y las opciones son discretas: sede, fecha disponible, slot disponible y confirmación/reprogramación. No reemplazar con botones la conversación abierta de preguntas, objeciones, síntomas, tratamiento o precio.

Los botones son aceleradores, no un requisito: si el usuario escribe “mañana a las 4”, el sistema debe interpretar la intención, comprobar si ese slot existe y responder con resultado o alternativas.

## Confirmación previa al commit

Antes de escribir la cita, presentar un resumen mínimo: tratamiento, sede, fecha, hora y profesional/pool cuando aplique. El usuario debe realizar una acción afirmativa inequívoca.

Luego el commit debe revalidar el slot de forma transaccional e idempotente. Si el slot dejó de estar libre, no crear la cita y ofrecer nuevas opciones.

## Post-booking

Tras commit exitoso:

1. `aos_agenda_citas` refleja la cita con origen/atribución correctos.
2. El ledger de booking conserva `conversation_id`, actor/origen e idempotencia.
3. WhatsApp confirma dentro del flujo permitido.
4. Si existe email válido, se encola confirmación transaccional por email.
5. Un fallo de WhatsApp/email posterior NO revierte ni corrompe una cita confirmada; las notificaciones son side-effects/outbox.
6. La cita queda disponible para recordatorios y seguimiento posterior.

## Reprogramación conversacional

El sistema debe detectar intención de reprogramar en lenguaje natural: “no podré ir”, “se me complicó”, “puede ser otro día”, “quiero mover mi cita”, etc. Las expresiones reales aportadas por operación se convertirán en canaries/corpus de regresión.

Flujo objetivo:

`mensaje → RESCHEDULE_INTENT → resolver cita activa del paciente/conversación → si hay ambigüedad preguntar cuál → conservar tratamiento/reglas clínicas → consultar nuevos slots reales → elección → confirmación explícita → rebook transaccional`

No borrar silenciosamente la cita anterior ni crear una nueva sin vínculo. Debe preservarse historial de reprogramación y evitar doble conteo de “citas generadas”.

AGV2-1 debe congelar si se usará:

- un mismo appointment lógico + event ledger de cambios, o
- fila anterior marcada `REAGENDADA/REPROGRAMADA` + nueva fila vinculada por relación explícita.

La métrica debe distinguir `booking_created` de `rebooking`.

## Continuidad y seguimiento

La conversación de WhatsApp debe mantener el contexto del mismo número/conversación. Una respuesta a un recordatorio no abre un lead nuevo si la identidad canónica permite asociarla al mismo paciente/cita.

El seguimiento posterior puede ofrecer reprogramación o recuperar riesgo de no-show, pero ninguna modificación de agenda se realiza sin una confirmación explícita del usuario.

## Email transaccional

La infraestructura actual ya contempla clases como `confirmacion_cita`, `recordatorio_manana`, `recordatorio_hoy`, `reprogramacion` y `no_asistencia`. AGV2 no debe enviar correo dentro de la transacción de booking. Debe persistir un evento/outbox y permitir que el worker de email lo despache y audite por separado.

## Economía de conversación / WhatsApp Cost Intelligence

Objetivo adicional: poder saber cuánto costó una conversación hasta cada outcome.

Fuentes CURRENT existentes:

- `aos_wa_messages_v1`: `conversation_id`, dirección, estado, `pricing_category`, `pricing_model`, `billable`.
- `aos_wa_ai_runs_v1`: tokens, modelo, latencia y `estimated_cost_usd`.
- `aos_wa_attribution_touchpoints_v1`: campaña/anuncio/origen y paciente canónico.
- `aos_wa4_booking_actions_v1`: vínculo de conversación con el commit de booking.

Para costo exacto de Meta falta una autoridad de pricing versionada por fecha/mercado/categoría y/o persistir el costo efectivo por evento. `billable=true/false` por sí solo no es un importe.

### Popup objetivo por conversación

Mostrar como mínimo:

- mensajes inbound/outbound;
- mensajes Meta billables/no billables/unknown;
- costo Meta acumulado;
- consumo IA y costo IA estimado;
- costo total de conversación;
- cita generada/reprogramada;
- asistió/no-show;
- venta y facturación atribuida cuando exista;
- costo por booking, costo por asistencia y costo de conversación hasta venta.

A nivel agregado, permitir cortes por campaña/anuncio, orgánico, tratamiento, bot/humano y periodo.

## Datos CURRENT verificados al redactar este draft

- Dra. Carolina Zimic tiene horario date-specific vigente observado en septiembre.
- Dra. Pamela y Dra. Yessica están visibles como perfiles, pero no presentan horario date-specific futuro en el readback actual; por tanto no deben aparecer como disponibilidad real mientras eso siga así.
- El sistema de email ya registra envíos recientes de `confirmacion_cita`, `recordatorio_manana`, `recordatorio_hoy`, `bienvenida` y `no_asistencia`.
- El ledger WA ya contiene campos de pricing/billable, pero la muestra actual todavía tiene eventos con pricing desconocido y no existen aún AI cost runs persistidos en PROD.

## Pendientes de freeze empresarial

1. Si la cita debe preguntar preferencia profesional cuando existen varios elegibles o priorizar primera disponibilidad.
2. Regla exacta de “evaluación gratuita” por tratamiento/campaña/consulta.
3. Modelo canónico de reprogramación (same logical appointment + event ledger vs linked rows).
4. Cuándo pedir DNI y en qué casos sí sería obligatorio.
5. Política de email: confirmación, recordatorios, reprogramación y evitar duplicación con bienvenida.
6. Cantidad máxima de fechas/slots a mostrar en una interacción antes de paginar/listar.
