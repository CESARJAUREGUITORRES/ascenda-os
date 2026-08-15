# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Estado:** WA-0 RECOVERY / ARCHITECTURE BASELINE  
**Fecha:** 2026-08-14 (America/Lima)  
**Git baseline verificada:** `d19560e4985dccf702252789f34a28cd73cf0cfc`  
**Supabase live:** `ituyqwstonmhnfshnaqz`  
**Rama documental:** `audit/wa0-whatsapp-revenue-hub-2026-08-14`  
**Regla:** este documento describe y congela contratos; WA-0 no modifica runtime, schema ni datos productivos.

---

## 1. Misión

Construir una capa conversacional comercial nativa de ASCENDA que conecte Meta/WhatsApp con identidad, agentes IA, asesores humanos, catálogo, agenda, Call Center, seguimiento, ventas, atribución y analítica económica sin crear un CRM paralelo ni duplicar fuentes de verdad.

Cadena objetivo:

`Meta Ad → WhatsApp → conversación → IA/humano → agenda/seguimiento → cita → asistencia → venta → atribución → insights/costos`.

## 2. Anti-scope

WA-0 y la arquitectura V1 no autorizan:

- reemplazar `aos_agenda_citas` ni el motor actual de horarios;
- crear un segundo CRM o copiar pacientes/leads en una plataforma externa;
- atribuir una venta a marketing solo porque coincide el teléfono;
- entrenar/fine-tunear automáticamente con conversaciones clínicas sin gobierno de datos;
- permitir diagnóstico médico automático por imagen/audio;
- permitir SQL arbitrario o herramientas de escritura sin allowlist/policy;
- enviar promociones masivas sin opt-in, categoría/template correcto y presupuesto;
- depender de un único proveedor/modelo de IA;
- exponer secretos, tokens o llaves en frontend, Git, logs o Notion.

## 3. Arquitectura congelada V1

```text
Meta Ads / Click-to-WhatsApp
            ↓
     WhatsApp Cloud API
            ↓
     Secure WA Gateway
            ↓
 Identity + Touchpoint Resolver
 numero_limpio + lead_id_origen
            ↓
 Conversation State Engine
            ↓
 ┌──────────┼───────────┐
 │          │           │
AI AUTO  AI COPILOT  HUMAN ACTIVE
 │          │           │
 └──────────┼───────────┘
            ↓
      ASCENDA AI Router
 DeepSeek / Groq / Qwen / fallback
            ↓
        Policy Engine
            ↓
 Catalog · Patient · Agenda · Follow-up · Call Center
            ↓
 Appointment · Attendance · Sale
            ↓
 Attribution · Insights · FinOps
```

### Estados conversacionales base

- `NEW`
- `AI_ACTIVE`
- `HUMAN_REQUESTED`
- `HUMAN_ACTIVE`
- `AI_COPILOT`
- `WAITING_CUSTOMER`
- `APPOINTMENT_PENDING`
- `APPOINTMENT_BOOKED`
- `WON`
- `LOST`
- `CLOSED`

El estado es autoridad del Conversation Engine; el LLM no decide por sí solo que una conversación está ganada, cerrada o que una cita existe.

## 4. Fuentes de verdad que se reutilizan

| Dominio | Fuente/contrato actual | Decisión WA |
|---|---|---|
| Persona | `numero_limpio`, `aos_pacientes` | Reutilizar; no crear identidad paralela |
| Touchpoint | `aos_leads.id`, `lead_id_origen` | ID explícito tiene precedencia sobre inferencia por teléfono |
| Llamada | `aos_llamadas` | Integrar como canal de escalamiento/follow-up |
| Seguimiento | `aos_seguimientos` | Reutilizar |
| Agenda | `aos_agenda_citas` | Autoridad única de citas |
| Disponibilidad | `aos_slots_disponibles()` | Base para tool segura `search_availability` |
| Reserva pública | `aos_agendar_publica()` + `agendar.html` | Reutilizar mediante wrapper endurecido; no duplicar |
| Links agenda | `aos_links_agenda` | Reutilizar con generador server-side/controlado |
| Catálogo | `aos_catalogo_*` + producto canónico | Tool/RAG, no copiar catálogo a otro CRM |
| Venta | `aos_ventas` + contracts Revenue | Autoridad de outcome comercial |
| IA | KronIA/Maya + `aos_agentes` | Reutilizar conocimiento/herramientas, desacoplar modelos |
| WhatsApp inbound | `/webhook`, `aos_whatsapp_mensajes`, `aos_webhook_log` | Endurecer y completar en WA-1 |

## 5. Baseline live medido en WA-0

Medición read-only sobre Supabase productivo durante WA-0:

| Métrica | Valor |
|---|---:|
| `aos_whatsapp_mensajes` | 0 |
| `aos_webhook_log` | 0 |
| `aos_maya_conversaciones` | 0 |
| `aos_kronia_conversaciones` | 23 |
| `aos_llamadas` | 34,058 |
| llamadas con `lead_id_origen` | 1 |
| `aos_agenda_citas` | 2,920 |
| citas con `lead_id_origen` | 1 |
| citas con `llamada_id_origen` | 1 |
| `aos_plantillas_whatsapp` | 0 |
| `aos_meta_campanas` | 0 |
| `aos_meta_metricas` | 0 |
| `aos_links_agenda` | 26 |
| links usados | 15 |
| links expirados al corte | 25 |
| links activos | 1 |

**Interpretación:** existe código/configuración histórica de WhatsApp/Meta, pero no existe evidencia de tráfico live en las tablas WhatsApp actuales. El estado operativo se clasifica `UNVERIFIED`, no `DISCONNECTED` ni `READY`.

La adopción histórica de IDs explícitos de origen es casi nula; el nuevo canal debe persistir provenance por ID desde el primer mensaje y no reconstruirlo después por heurística.

## 6. Booking: decisión canónica

ASCENDA ya posee:

- `aos_slots_disponibles(p_id_profesional, p_fecha)`;
- `aos_agendar_publica(...)`;
- `aos_links_agenda`;
- `app/public/agendar.html`;
- horarios y agenda productivos.

Por tanto V1 define tools de negocio, no un motor de agenda nuevo:

- `search_availability(...)` → wrapper read-only sobre disponibilidad real;
- `create_appointment(...)` → wrapper de escritura idempotente/atómico sobre agenda canónica;
- `generate_booking_link(...)` → genera token/link trazable server-side.

### Provenance mínimo de booking

Toda cita originada o asistida por WhatsApp debe poder reconstruir, sin inferencia:

- `conversation_id`;
- `lead_id_origen` cuando exista;
- campaña/anuncio/touchpoint cuando exista evidencia;
- `booking_source=WHATSAPP`;
- `first_response_actor`;
- `appointment_creator`;
- `closer_actor`;
- `ai_assisted`;
- `human_assisted`;
- `handoff_count`;
- timestamps de eventos relevantes.

Esto permite medir `AI_ONLY`, `HUMAN_ONLY` y `HYBRID` sin falsear atribución.

## 7. Conversaciones, memoria e insights

No se usarán conversaciones raw como dataset de entrenamiento automático.

Capas previstas:

1. **Raw event/message ledger** — evidencia íntegra con retención definida.
2. **Working memory** — ventana limitada para el agente.
3. **Structured conversation summary** — intención, objeciones, tratamiento, resultado.
4. **Customer memory autorizada** — preferencias/datos permitidos y vigentes.
5. **CRM facts** — datos consultados desde fuentes canónicas.
6. **Eval/training dataset** — solo material curado, anonimizado y con lineage.

Los primeros mecanismos de aprendizaje serán evals, prompts, policies, RAG e insights; fine-tuning se evaluará después de obtener volumen y gobierno suficientes.

## 8. AI Router

El consumidor solicita una capacidad; nunca un modelo concreto.

Capacidades iniciales:

- `FAST_CHAT`
- `SALES_CHAT`
- `SALES_REASONING`
- `CLASSIFY`
- `SUMMARIZE`
- `TRANSCRIBE`
- `VISION`

Candidatos WA-0:

- DeepSeek V4 Flash — `FAST_CHAT` / `SALES_CHAT` candidato;
- DeepSeek V4 Pro — reasoning candidato;
- Groq GPT-OSS 20B — fast/fallback;
- Groq GPT-OSS 120B — reasoning/fallback;
- Groq Whisper Large V3 Turbo — transcripción;
- Qwen — visión/multimodal candidato;
- SiliconFlow/ModelScope — experimentación/evals, no SLA único.

El ganador se determina con benchmark ASCENDA, no por benchmark público aislado.

## 9. Seguridad / gates que bloquean exposición nueva

WA-0 detectó y documenta, sin corregir todavía:

- webhook POST sin validación de firma Meta confirmada;
- ausencia de un outbound sender WhatsApp completo identificado en CURRENT;
- varias tablas relevantes sin RLS restrictivo y con grants amplios históricos;
- RPC de agenda/KronIA ejecutables por `anon`;
- modo público `__permanent__` en agenda que debe pasar threat model antes de ampliar uso;
- generación actual de links de agenda desde navegador/direct-write;
- booking público que requiere revisión de atomicidad para evitar carrera/doble reserva;
- secretos/configuración histórica deben migrarse a env/Vault según hardening vigente.

**Dependencia:** el workstream WA debe coordinar con el hardening P0 `secure_write` ya integrado en `main`; no duplicar ni revertir sus decisiones.

## 10. Cost governance

El sistema medirá como mínimo:

- costo WhatsApp por mensaje entregado/template/categoría;
- elegibilidad de ventanas gratuitas;
- costo IA por provider/model/capability/tokens;
- costo STT por duración;
- storage/egress de multimedia;
- infraestructura incremental;
- costo email;
- spend Meta Ads por campaña;
- costo por conversación calificada;
- costo por cita;
- costo por asistencia;
- CAC por venta;
- revenue/ROAS atribuible cuando la evidencia sea suficiente.

No se optimiza para “costo cero” ficticio. Se optimiza para uso legítimo de ventanas incluidas, modelos eficientes, reutilización de infraestructura y escalamiento humano solo cuando aporta valor.

## 11. Roadmap WA

1. `WA-0` — Recovery, Impact Map & Cost Baseline.
2. `WA-1` — Secure WhatsApp Gateway.
3. `WA-2` — Conversation Store & Live Inbox.
4. `WA-3` — Boxes, Routing & Human Handoff.
5. `WA-4` — AI Sales Agent & Multi-Model Router.
6. `WA-5` — Multimedia, Audio & Knowledge.
7. `WA-6` — Agenda, Auto-Booking, Follow-up & Call Center.
8. `WA-7` — Meta Attribution, Orders & Revenue Loop.
9. `WA-8` — Canary, Production & Cost Governance.

## 12. Próximo gate

WA-0 puede cerrarse documentalmente cuando:

- Impact Map esté versionado;
- baseline económica esté versionada;
- benchmark spec esté versionada;
- hallazgos H001+ estén registrados;
- Notion refleje el checkpoint real;
- PR documental quede abierto contra `main` sin tocar runtime/schema.

**NEXT después del gate:** `WA-1 — Secure WhatsApp Gateway`, empezando por contratos de firma/idempotencia/outbound/pricing events y threat model antes de cualquier canary productivo.
