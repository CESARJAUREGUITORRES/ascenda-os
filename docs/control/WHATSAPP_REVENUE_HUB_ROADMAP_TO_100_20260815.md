# ASCENDA Conversations — Roadmap to 100%

**Fecha:** 2026-08-15 (America/Lima)  
**Objetivo:** llevar WhatsApp Revenue Hub desde el checkpoint visible actual hasta operación comercial completa, gobernada y medible.

## 1. Checkpoint productivo real

Al cierre de la sesión de recuperación:

- WhatsApp Hub está montado dentro del shell principal ASCENDA.
- Existen 2 conversaciones y 2 mensajes inbound en el store WA.
- Existe 1 box y 1 miembro activo.
- Existe 1 assignment activo.
- Existen 4 routing events.
- `human_send_enabled=true`.
- `auto_routing_enabled=false`.
- `ai_send_enabled=false`.
- WA-4 AI control existe con Groq/GPT-OSS configurado, pero `copilot_enabled=false` y `auto_reply_enabled=false`.
- AI runs: 0.
- No hay requests outbound registrados en `aos_wa_outbound_requests_v1` al corte.
- No existe `server-wa5`; WA-5+ no están implementadas todavía.

Esto prueba inbound + store + shell + timeline, pero no certifica aún el flujo humano outbound ni AI copilot operativo.

## 2. Estado por fase

| Fase | Estado | Falta crítica |
|---|---|---|
| WA-0 Recovery/Architecture | CERRADA | mantener docs vivas |
| WA-1 Secure Gateway | OPERATIVO | recertificar outbound/delivery en canary real |
| WA-2 Conversation Store/Inbox | OPERATIVO | retirar dependencia de recovery al estabilizar WA-3 |
| WA-3 Boxes/Routing/Handoff | CORE OPERATIVO | native bootstrap estable + send humano real + boxes negocio |
| WA-4 AI Sales Copilot | INFRA DESPLEGADA / OFF | model health + grounded eval + owner canary |
| WA-5 Multimedia/Audio/Knowledge | NO INICIADA | build completo |
| WA-6 Agenda/Follow-up/Call Center | NO INICIADA | wrappers business + provenance |
| WA-7 Meta Attribution/Revenue | NO INICIADA | provenance → booking → sale → ROAS |
| WA-8 Canary/Production/FinOps | NO INICIADA | SLOs, costs, observability, scale |

## 3. Orden recomendado

### PHASE S — Stabilization & Native Operations

**Prioridad inmediata.** No avanzar a multimedia ni auto-AI hasta cerrar esta fase.

#### S1. Native WA-3 bootstrap

- identificar la causa exacta del bootstrap inicial que obligó al recovery;
- convertir lecturas auxiliares a degradación independiente;
- retry/backoff controlado;
- health endpoint agregado para bootstrap components;
- mantener recovery como safety net temporal;
- demostrar 20+ cargas/reloads sin fallback.

Exit gate: panel carga conversaciones y Routing & Handoff de forma normal; recovery no se activa en smoke repetido.

#### S2. Human outbound certification

- usar número canary allowlisted;
- owner exacto `HUMAN_ACTIVE`;
- enviar texto desde composer ASCENDA;
- persistir outbound request;
- obtener provider message id;
- mostrar mensaje outbound en timeline;
- observar status `sent/delivered/read` si Meta lo entrega;
- retry con misma idempotency key no duplica;
- fuera de allowlist debe fallar cerrado.

Exit gate: inbound ↔ outbound humano real funcionando desde ASCENDA.

#### S3. Business boxes

Sustituir `WA_TEST` por una configuración operativa controlada.

Propuesta inicial:

- `VENTAS_GENERAL` — entrada sin sede definida;
- `VENTAS_SAN_ISIDRO`;
- `VENTAS_PUEBLO_LIBRE`;
- `RECONTACTO` — seguimientos/reengagement;
- `ESCALAMIENTO_CLINICO` — solo cuando una conversación comercial requiere humano clínico.

No todos deben crearse de golpe. Empezar con `VENTAS_GENERAL` + 2 agentes canary y medir.

#### S4. Agent permissions & supervisor controls

- `whatsapp-agent` explícito por usuario;
- max_active por agente;
- prioridad;
- supervisor puede reassign/release;
- agente solo ve owned conversations;
- presence/readiness integrado con estado operativo de ASCENDA cuando sea seguro.

#### S5. Native UX polish

- badge unread en sidebar;
- nombre/número/source/campaign en conversation card;
- timestamps claros;
- queue age;
- state pill;
- owner/box visible;
- composer normal cuando corresponde;
- keyboard send + multiline;
- empty/error/recovery states diferenciados;
- mobile/responsive básico.

## 4. WA-4 — AI Sales Copilot

### 4.1 Provider/model readiness

- verificar `/api/wa4/health` en deploy actual;
- confirmar GPT-OSS fast/reasoning/safety account readiness;
- confirmar secrets solo server-side;
- registrar provider fallback policy.

### 4.2 Knowledge grounding

Conectar únicamente fuentes autorizadas:

- catálogo canónico;
- tratamientos/servicios;
- precios aprobados;
- preguntas frecuentes;
- sedes/horarios;
- políticas/promociones vigentes;
- restricciones comerciales;
- protocolo de escalamiento clínico.

No copiar el catálogo a un vector store sin necesidad. Primero retrieval estructurado + RAG selectivo.

### 4.3 Sales intent taxonomy

Clasificar al menos:

- información general;
- precio;
- disponibilidad;
- tratamiento específico;
- comparación;
- objeción de precio;
- seguimiento;
- desea agendar;
- solicita humano;
- postventa;
- evento adverso/consulta clínica → escalamiento.

### 4.4 Copilot UI

Panel del agente:

- “Sugerir respuesta”;
- respuesta propuesta editable;
- fuentes/facts usados;
- warning/escalamiento;
- regenerate con motivo;
- accept/edit/reject feedback.

### 4.5 Evals

Dataset curado y anonimizado. Métricas:

- factuality catálogo/precio;
- intent accuracy;
- escalation recall;
- hallucination rate;
- persuasion/helpfulness;
- latency;
- estimated cost.

### 4.6 Canary

- copilot solo exact owner;
- nunca auto-send;
- 20–50 conversaciones internas/canary evaluadas;
- AI run audit >0 y reconciliable.

Exit gate WA-4: copilot útil, grounded y seguro con human approval obligatorio.

## 5. WA-5 — Multimedia, Audio & Knowledge

### 5.1 Message/media model

Extender soporte real para:

- image;
- audio/voice note;
- document;
- video opcional;
- sticker/location/contact si aportan negocio.

### 5.2 Private media pipeline

`Meta media id → server fetch → validate → private storage → short-lived signed URL → UI`.

- no blobs públicos;
- retention policy;
- size/type limits;
- malware validation para documentos cuando corresponda;
- no guardar media duplicada innecesariamente.

### 5.3 Audio

- transcript automático mediante capability `TRANSCRIBE`;
- transcript ligado al message id;
- duración/costo medidos;
- agente puede leer sin escuchar todo;
- opcional “resumir audio”.

### 5.4 Vision

- capability separada;
- solo tareas autorizadas;
- en entorno clínico: no diagnóstico ni interpretación médica autónoma;
- cualquier imagen con síntomas/resultados médicos → escalamiento.

### 5.5 Agent send media

- fotos de producto/tratamiento aprobadas;
- documentos/brochure;
- audio humano si Meta/API/policy y UX lo justifican;
- media templates si aplican.

Exit gate WA-5: recibir, mostrar y responder multimedia bajo controles de privacidad/costo.

## 6. WA-6 — Agenda, Booking, Follow-up & Call Center

### 6.1 Availability tool

Wrapper read-only sobre fuente canónica:

- sede;
- profesional;
- fecha;
- tratamiento si condiciona recursos;
- slots reales.

### 6.2 Create appointment tool

- idempotent writer;
- conflict/race protection;
- provenance conversation_id;
- lead/campaign IDs cuando existan;
- actor creator;
- AI/human assisted flags.

### 6.3 Booking UX

El chatbot/agente puede:

- ofrecer slots;
- confirmar selección;
- reservar;
- entregar link de autoagenda trazable;
- reschedule/cancel bajo policy.

### 6.4 Follow-up automation

Estados como:

- preguntó precio y no agendó;
- ofreció slot y no respondió;
- cita pendiente de confirmación;
- no-show;
- post-atención comercial;
- cartera/recontacto cuando corresponda.

Usar `aos_seguimientos`/fuentes existentes, no una tabla paralela sin justificación.

### 6.5 Call Center handoff

Si WhatsApp no resuelve:

- create call task;
- preserve conversation provenance;
- llamada y WhatsApp quedan dentro del mismo customer journey.

Exit gate WA-6: conversación puede terminar en cita/seguimiento/llamada sin salir de ASCENDA.

## 7. WA-7 — Meta Attribution, Sales & Revenue Loop

### 7.1 Capture source at ingress

Persistir cuando Meta lo entregue:

- referral;
- CTWA source;
- ad id;
- campaign/source metadata;
- lead id.

### 7.2 Identity/touchpoint resolver

Orden de autoridad:

1. explicit lead/campaign IDs;
2. explicit conversation provenance;
3. deterministic contact identity;
4. phone matching solo como apoyo, nunca como prueba única de attribution.

### 7.3 Outcome stitching

`conversation → appointment → attendance → sale`.

Persistir:

- first response actor;
- appointment creator;
- closer;
- AI assisted;
- human assisted;
- handoff count;
- sale/revenue id.

### 7.4 Revenue analytics

Dashboard:

- conversations by campaign/ad;
- qualified rate;
- appointment rate;
- show rate;
- close rate;
- revenue;
- revenue per conversation;
- CAC/ROAS cuando spend/evidencia sean suficientes;
- AI_ONLY/HUMAN_ONLY/HYBRID comparisons.

Exit gate WA-7: una venta puede rastrearse de manera explicable a la conversación/touchpoint sin inferencia engañosa.

## 8. WA-8 — Production Scale, Observability & FinOps

### 8.1 SLOs

Objetivos iniciales sugeridos:

- webhook accepted latency;
- inbox freshness;
- API p95;
- projection lag;
- send acceptance latency;
- error budget.

Valores exactos deben fijarse después de medir baseline real.

### 8.2 Operational dashboard

- gateway health;
- signature rejects;
- messages/hour;
- queue depth/age;
- active agents;
- first response time;
- handoff rate;
- outbound delivery funnel;
- AI health/cost;
- media failures;
- booking failures;
- attribution coverage.

### 8.3 Cost governance

Cost per:

- WhatsApp message/template;
- conversation;
- AI suggestion;
- transcription minute;
- media storage/egress;
- booked appointment;
- acquired customer.

Budgets + kill switches.

### 8.4 Load/performance

- polling vs Realtime decision basada en medición;
- pagination/windowed message loading;
- server caching solo donde sea seguro;
- connection/process monitoring;
- rate guards per user/IP/business action.

### 8.5 Disaster/recovery drill

- Meta unavailable;
- Supabase partial failure;
- AI provider unavailable;
- service worker stale;
- runtime layer crash;
- failed deploy;
- revoked/expired token.

Exit gate WA-8: operación medible, recoverable y escalable.

## 9. Mejora arquitectónica posterior — Runtime Consolidation

Cadena actual:

`server-f5 → server-wa4 → server-wa3 → server-wa2 → server-f4 → server-phase2 → server.js`.

Esta cadena fue útil para introducir seguridad de forma aditiva sin romper producción. Sin embargo, después de WA-8 conviene crear un **front controller modular** que mantenga los mismos contratos externos y reduzca child processes/hops.

No ejecutar esta consolidación antes de cerrar funcionalidad y canaries.

## 10. Potenciadores de negocio recomendados

Después del core 100%:

- smart prioritization por intención/valor/urgencia;
- SLA alerts para chats sin responder;
- supervisor wallboard;
- snippets/quick replies;
- campaign-aware opening context;
- next-best-action;
- offer recommendation grounded en catálogo;
- conversation summary automática al cierre;
- CRM memory autorizada por paciente;
- quality scoring de agentes;
- lost reason taxonomy;
- reactivation campaigns gobernadas;
- no-show rescue;
- abandoned-booking rescue;
- A/B testing de scripts AI/humano;
- multilingual sales support;
- unified customer timeline WhatsApp + llamadas + agenda + ventas + email.

## 11. Prioridad de ejecución inmediata

Orden recomendado para la siguiente sesión:

1. **S1 native bootstrap WA-3**;
2. **S2 human outbound real + delivery receipts**;
3. **S3/S4 boxes + agentes canary**;
4. **WA-4 health + copilot canary**;
5. **WA-5 audio/image**;
6. **WA-6 booking/follow-up**;
7. **WA-7 attribution/revenue**;
8. **WA-8 production/FinOps**.

No habilitar auto-reply AI antes de completar como mínimo S1/S2, WA-4 evals y las policies de WA-6 cuando el bot vaya a ejecutar acciones de negocio.

## 12. North Star

ASCENDA Conversations estará al 100% cuando WhatsApp deje de ser un canal aislado y se convierta en una capa operativa completa del sistema:

`lead → conversation → qualification → human/AI → appointment/follow-up → attendance → sale → attribution → learning → optimization`.
