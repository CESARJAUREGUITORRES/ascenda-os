# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Estado:** LIVE CORE / STABILIZATION BEFORE WA-4 CANARY  
**Fecha:** 2026-08-15 (America/Lima)  
**Último checkpoint funcional observado:** shell integrado + inbox + timeline inbound visible  
**Supabase:** `ituyqwstonmhnfshnaqz`

## 1. North Star

Convertir WhatsApp en una capa conversacional nativa de ASCENDA, no en un CRM paralelo:

`Meta Ad / Organic → WhatsApp → conversación → IA/humano → agenda/seguimiento/call center → cita → asistencia → venta → atribución → insights/costos`.

## 2. Estado productivo medido

Checkpoint de base al cierre de la recuperación:

| Métrica | Valor |
|---|---:|
| mensajes WA ledger | 2 |
| conversaciones | 2 |
| boxes | 1 |
| members activos | 1 |
| assignments activos | 1 |
| routing events | 4 |
| AI runs | 0 |
| outbound requests | 0 |

Controles:

- `human_send_enabled=true`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- WA-4 `copilot_enabled=false`;
- WA-4 `auto_reply_enabled=false`;
- budget AI diario: USD 0.50;
- router WA-4: Groq con GPT-OSS fast/reasoning/safety configurado en control.

Evidencia visible:

- `zi vital` / `51960618468` visible en inbox;
- estado `HUMAN_ACTIVE`;
- mensaje inbound real `ASCENDA INBOUND REAL 02` visible en timeline;
- segunda conversación de prueba visible;
- WhatsApp Hub dentro del shell principal ASCENDA;
- recovery automático WA-3 probado.

## 3. Runtime actual

Railway entra por:

`server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → server-phase2.js → server.js`.

La composición por wrappers es una estrategia de migración segura. No consolidar todavía durante stabilization. La consolidación modular se evaluará después de WA-8.

## 4. Fases

### WA-0 — Recovery & Architecture

**Estado:** CLOSED.

Arquitectura, impact map, cost baseline y benchmark spec existentes.

### WA-1 — Secure WhatsApp Gateway

**Estado:** LIVE / inbound real demostrado.

Invariantes:

- webhook firmado;
- secrets server-side;
- message/event ledger;
- idempotencia;
- outbound gobernado/canary;
- no retorno al POST unsigned.

**Pendiente de esta nueva etapa:** recertificar human outbound real desde el Hub y delivery receipts.

### WA-2 — Conversation Store & Live Inbox

**Estado:** LIVE.

- conversation projection activa;
- inbox/timeline visibles;
- stores privados;
- same-origin APIs;
- fallback read-only probado.

### WA-3 — Boxes, Routing & Human Handoff

**Estado:** CORE LIVE / STABILIZATION.

Probado:

- box/membership;
- assignment activo;
- `HUMAN_ACTIVE`;
- routing events;
- administración autorizada;
- panel central ASCENDA.

Pendiente:

1. estabilizar bootstrap nativo sin depender de recovery;
2. probar composer/send humano real;
3. delivery/read status;
4. crear boxes de negocio;
5. otorgar `whatsapp-agent` explícitamente a agentes canary;
6. probar claim/reassign/release con usuarios reales autorizados.

### WA-4 — AI Sales Agent & Multi-Model Router

**Estado:** INFRA DEPLOYED / OFF.

Existe control/router/audit schema; no hay AI runs aún.

Siguiente gate WA-4:

- provider health;
- grounded knowledge;
- safety/escalation evals;
- exact-owner copilot;
- human approval mandatory;
- no auto-send.

### WA-5 — Multimedia, Audio & Knowledge

**Estado:** NOT STARTED.

No existe `server-wa5` al checkpoint.

Scope:

- image/audio/document receive;
- private media storage;
- STT/transcript;
- approved media outbound;
- vision limitada y escalamiento clínico.

### WA-6 — Agenda, Booking, Follow-up & Call Center

**Estado:** NOT STARTED.

Reutilizar fuentes ASCENDA:

- `aos_slots_disponibles()`;
- agenda canónica;
- booking link;
- `aos_seguimientos`;
- call center.

No crear motor paralelo de agenda.

### WA-7 — Meta Attribution, Orders & Revenue Loop

**Estado:** NOT STARTED.

Objetivo:

`conversation_id / explicit provenance → appointment → attendance → sale → revenue/ROAS`.

Nunca atribuir revenue solo por coincidencia telefónica.

### WA-8 — Canary, Production & Cost Governance

**Estado:** NOT STARTED.

Incluye:

- SLOs;
- observability;
- cost controls;
- load testing;
- disaster/recovery drills;
- scale rollout.

## 5. Incidente shell/inbox 2026-08-15 — CLOSED

Causa combinada:

1. WA-2 nació como shadow page, no panel integrado;
2. `sessionStorage` era tab-scoped;
3. bootstrap WA-3 abortaba toda la cadena si fallaba una lectura;
4. service worker/cache podía mantener asset anterior.

Solución:

- `wa-shell-integration.js`;
- sidebar `WhatsApp Hub`;
- same-origin iframe bridge temporal;
- token bridge allowlisted en service worker;
- recovery WA-3 → WA-2 read-only;
- diagnostics persistentes;
- explicit asset version bump.

Documento completo:

`docs/control/WHATSAPP_SHELL_INBOX_RECOVERY_20260815.md`

## 6. Reusable knowledge

Playbook extraído de este trabajo:

`docs/control/WHATSAPP_CONNECTION_REUSABLE_PLAYBOOK_V1.md`

Este documento debe consultarse antes de integrar WhatsApp Cloud API en otro producto/proyecto.

## 7. Roadmap maestro vigente

`docs/control/WHATSAPP_REVENUE_HUB_ROADMAP_TO_100_20260815.md`

Prioridad inmediata:

1. WA-3 native bootstrap stabilization;
2. human outbound real;
3. business boxes + agents;
4. WA-4 copilot canary;
5. WA-5 multimedia/audio;
6. WA-6 booking/follow-up/call center;
7. WA-7 attribution/revenue;
8. WA-8 production/FinOps.

## 8. Fuentes de verdad existentes

No duplicar:

| Dominio | Fuente |
|---|---|
| persona | `numero_limpio`, `aos_pacientes` |
| leads/provenance | `aos_leads`, `lead_id_origen` + WA provenance |
| llamadas | `aos_llamadas` |
| seguimientos | `aos_seguimientos` |
| agenda | `aos_agenda_citas` |
| disponibilidad | `aos_slots_disponibles()` |
| booking | contratos existentes de agenda/link público |
| catálogo/producto | `aos_catalogo_*` + producto canónico |
| ventas | `aos_ventas` + Revenue contracts |
| IA | KronIA/Maya + WA-4 router/capabilities |
| WhatsApp message truth | `aos_wa_messages_v1` |
| WhatsApp conversation truth | `aos_wa_conversations_v1` |
| WhatsApp ownership truth | WA-3 assignments/routing tables |

## 9. Reglas no negociables

- no secretos en frontend/Git/docs;
- no diagnóstico médico autónomo;
- no SQL arbitrario por IA;
- no auto-reply AI hasta pasar gates;
- no CRM paralelo;
- no agenda paralela;
- no attribution falsa por teléfono;
- writes idempotentes/auditados;
- recovery fail-closed;
- preserve evidence on rollback;
- shell integration forma parte del Definition of Done.

## 10. NEXT

**NEXT oficial:** `PHASE S — WA-3 Stabilization & Human Outbound Certification`.

Exit gate de Phase S:

- 20+ loads/reloads sin recovery;
- Routing & Handoff carga nativamente;
- inbound real visible;
- human outbound desde ASCENDA aceptado por Meta;
- message id + timeline outbound;
- delivery/read/failure observable;
- idempotency retry probado;
- canary recipient guard probado;
- primer business box + agentes canary configurados.

Solo después se activa WA-4 Copilot canary.
