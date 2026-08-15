# ASCENDA Conversations — WA-0 Impact Map

**Fecha:** 2026-08-14  
**Baseline Git:** `d19560e4985dccf702252789f34a28cd73cf0cfc`  
**Modo:** read-only production discovery  
**Propósito:** identificar consumidores, contratos, riesgos y dependencias antes de escribir WA-1.

---

## 1. Cadena de impacto

```text
Meta App / WABA
  ↓ webhook
app/server.js:/webhook
  ├─ aos_webhook_log
  └─ aos_whatsapp_mensajes
       ↓
Identity Resolver
  ├─ numero_limpio → persona
  └─ lead_id_origen → touchpoint
       ↓
Conversation Engine [nuevo, additive]
  ↓
AI/Human Routing [nuevo, additive]
  ├─ KronIA/Maya knowledge/tools
  ├─ catálogo
  ├─ pacientes
  ├─ agenda
  └─ follow-up/call center
       ↓
aos_agenda_citas
       ↓
attendance / ventas
       ↓
Marketing Attribution V2 + Revenue Intelligence
```

## 2. Componentes productivos encontrados

### WhatsApp / Meta

| Componente | Evidencia CURRENT | Estado WA-0 |
|---|---|---|
| `GET /webhook` | verificación challenge | Existe |
| `POST /webhook` | parsea eventos `messages` | Existe |
| `aos_webhook_log` | raw payload ledger | Existe, 0 filas al corte |
| `aos_whatsapp_mensajes` | inbound normalizado | Existe, 0 filas al corte |
| referral Meta | `headline` + `source_id` | Existe en parser |
| outbound `/messages` | no identificado como sender completo | GAP |
| firma `X-Hub-Signature-256` | no encontrada en POST CURRENT | GAP CRITICAL |
| `aos_meta_config` | configuración presente | Configurado ≠ operativo verificado |
| `aos_meta_campanas` | tabla | 0 filas al corte |
| `aos_meta_metricas` | tabla | 0 filas al corte |
| `aos_plantillas_whatsapp` | tabla | 0 filas al corte |

### IA

| Componente | Uso actual | Riesgo/decisión |
|---|---|---|
| KronIA | contexto + tools + auditoría | Reutilizar; desacoplar provider/model |
| Maya | recepcionista / inbound simulado | Reutilizar conocimiento; no usar tabla como Conversation Store canónico |
| Groq Whisper | audio → texto | Reutilizar inicialmente |
| Llama Groq legacy | runtime aún contiene modelos en retiro | Migrar detrás de AI Router |
| `aos_agentes` | metadata/config de agentes | Reutilizar con contrato gobernado |
| `aos_agente_logs` | auditoría de ejecuciones | Reutilizar/expandir |

### Agenda

| Componente | Función | Decisión |
|---|---|---|
| `aos_slots_disponibles()` | disponibilidad real | Reutilizar bajo wrapper tool |
| `aos_agendar_publica()` | reserva pública | Reutilizar lógica, endurecer contrato |
| `aos_links_agenda` | tokens/prefill/expiración | Reutilizar con generación server-side |
| `agendar.html` | autoservicio paciente | Mantener y hacer trazable |
| `aos_agenda_citas` | cita canónica | No duplicar |
| horarios profesionales | supply real | No duplicar |

### Comercial / atribución

| Componente | Papel |
|---|---|
| `aos_leads` | touchpoint/origen |
| `aos_llamadas` | contacto humano/call center |
| `aos_seguimientos` | follow-up |
| `aos_pacientes` | persona |
| `aos_ventas` | outcome financiero/comercial |
| `aos_siguiente_lead_v2` | cola del asesor + origen V2 |
| Marketing Attribution V2 | reglas de certeza/provenance |

## 3. Baseline de provenance

Medición live WA-0:

- llamadas: `34,058`;
- llamadas con `lead_id_origen`: `1`;
- citas: `2,920`;
- citas con `lead_id_origen`: `1`;
- citas con `llamada_id_origen`: `1`.

**Consecuencia de arquitectura:** no se intentará reparar el nuevo canal mediante match por teléfono después del hecho. WhatsApp debe registrar explicit IDs desde el ingreso cuando existan y mantener `UNRESOLVED/NO ATRIBUIBLE` cuando la evidencia no alcance.

## 4. Booking — contrato deseado

### 4.1 `search_availability`

**Write:** ninguno.  
**Fuente:** horarios + `aos_slots_disponibles`.  
**Input:** profesional/tipo, sede, fecha/rango, tratamiento si aplica.  
**Output:** slots canónicos con IDs/timestamps.  
**Regla:** el LLM solo verbaliza slots devueltos por ASCENDA.

### 4.2 `create_appointment`

**Write:** controlado.  
**Fuente:** `aos_agenda_citas`.  
**Requisitos antes de exponer:** auth/actor, idempotency key, recheck atómico de slot, provenance, audit, rollback/recovery.

**Output:** `appointment_id`, slot confirmado y metadata de provenance.  
**Regla:** la respuesta al paciente ocurre después de commit confirmado.

### 4.3 `generate_booking_link`

**Write:** controlado a `aos_links_agenda`.  
**Requisitos:** token criptográficamente adecuado, TTL, scope, usage policy, prefill mínimo, `conversation_id`/touchpoint provenance, revocación/auditoría.

**Output:** URL segura a `agendar.html`.

## 5. Handoff humano

Invariant obligatorio:

> Una conversación no puede tener simultáneamente a la IA y a un humano enviando respuestas automáticas.

Estados mínimos:

- `AI_ACTIVE` → IA puede responder bajo policy;
- `HUMAN_REQUESTED` → IA detiene envíos y entra queue;
- `HUMAN_ACTIVE` → solo humano envía;
- `AI_COPILOT` → IA sugiere, humano decide el envío.

Todo takeover/release debe producir evento auditable con actor y timestamp.

## 6. Persistencia conversacional

Entidades V1 recomendadas, a validar en WA-2:

- conversation;
- message;
- event;
- assignment/ownership;
- handoff;
- summary/memory;
- tool execution;
- cost/pricing event;
- attribution/provenance link.

No se reutilizará `aos_maya_conversaciones` ni `aos_kronia_conversaciones` como fuente canónica universal: son logs/conversaciones específicas de agente y no poseen el contrato omnicanal/ownership requerido.

## 7. Hallazgos WA-0

### H001 — CRITICAL — Webhook signature

POST `/webhook` no muestra validación confirmada de firma Meta. WA-1 debe validar autenticidad antes de procesar/persistir eventos.

### H002 — HIGH — Model deprecation

Runtime contiene modelos Groq Llama en proceso de retiro para Free/Developer. AI Router debe eliminar acoplamiento directo.

### H003 — HIGH — Hybrid booking attribution

La agenda no modela todavía contribución IA/humano/conversación de forma suficiente para este canal.

### H004 — HIGH — Conversation data governance

Raw chat clínico/comercial no puede convertirse automáticamente en entrenamiento.

### H005 — HIGH — FinOps ledger

Falta ledger por mensaje/provider/capability/campaña/conversación/resultado.

### H006 — HIGH — Media retention

Audio/fotos exigen ACL, signed access, retention y cost controls.

### H007 — MEDIUM — Direct API vs BSP

Baseline recomienda Meta Cloud API directa porque el sistema ya posee integración; añadir BSP requiere justificar feature/SLA que compense nueva dependencia/costo.

### H008 — HIGH — Meta live readiness unverified

La configuración existe, pero tablas live muestran 0 eventos. Estado de publicación, permisos y token production-ready debe verificarse antes del canary.

### H009 — CRITICAL — Public booking exposure

`aos_agendar_publica`/`aos_slots_disponibles` y otras RPC relacionadas presentan superficie `anon` que debe integrarse con el hardening de identidad/RLS antes de convertirse en tools del agente.

### H010 — HIGH — Atomic booking

El flujo público requiere validación de concurrencia/idempotencia antes de reutilizarse para booking automático; el slot debe revalidarse bajo una operación atómica.

### H011 — HIGH — Browser-side link write

La UI actual genera/actualiza `aos_links_agenda` desde navegador. El nuevo canal debe usar generador server-side/RPC autorizada, no replicar direct-write.

### H012 — HIGH — WhatsApp operational state unverified

0 mensajes + 0 raw webhook logs al corte impiden certificar que el canal actual esté realmente recibiendo producción.

### H013 — CRITICAL — RLS/GRANT surface

Múltiples objetos relacionados con WhatsApp/agenda/CRM conservan superficie histórica amplia. WA no debe abrir nuevas escrituras hasta coordinar con el P0 `secure_write`/Auth hardening CURRENT.

### H014 — HIGH — Outbound sender gap

No se identificó sender completo de WhatsApp Cloud API en CURRENT para texto/media/template/status. WA-1 debe definir un outbound contract idempotente y auditable.

### H015 — HIGH — Explicit origin adoption

Histórico casi no usa `lead_id_origen`; el nuevo canal debe capturarlo desde el nacimiento y distinguir persona vs touchpoint.

## 8. Riesgo por fase

| Fase | Riesgo | Razón |
|---|---|---|
| WA-0 | LOW/HIGH read-only discovery | no writes productivos |
| WA-1 | CRITICAL | webhook, secretos, outbound, security boundary |
| WA-2 | HIGH | PII, realtime, retention, ownership |
| WA-3 | HIGH | routing y exclusión IA/humano |
| WA-4 | HIGH | tools/LLM writes/guardrails |
| WA-5 | HIGH | multimedia clínica/PII |
| WA-6 | HIGH/CRITICAL | appointment writes y doble reserva |
| WA-7 | HIGH | atribución, órdenes, conversion data |
| WA-8 | CRITICAL | cutover/canary/production budgets |

## 9. Dependency gates

WA-1 no puede declararse production-ready hasta que:

1. firma Meta y replay/idempotencia estén definidos/probados;
2. secretos estén en secret manager/env;
3. ACL/RLS/secure_write contracts estén coordinados con CURRENT;
4. outbound sender tenga audit + retries + dedup;
5. raw payload retention esté definida;
6. delivery/status events y pricing ledger estén modelados;
7. Zero-Cost CI V2 pase;
8. exista canary aislado y rollback.

WA-6 no puede exponer `create_appointment` hasta que atomicidad, idempotencia, role authorization y provenance estén certificados.
