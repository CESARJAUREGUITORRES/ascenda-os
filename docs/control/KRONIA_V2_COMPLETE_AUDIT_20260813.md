# ASCENDA OS — KRONIA V2 COMPLETE AUDIT & RECONSTRUCTION BASELINE

**Estado:** CURRENT / AUDIT COMPLETE — NO PRODUCTION CHANGES  
**Fecha local:** 2026-08-13 (America/Lima)  
**Rama:** `audit/kronia-v2-complete-20260813`  
**Baseline:** `main` @ `0747d8c26ef0c467f9667ac6240df09457e75a6c`  
**Supabase operativo:** `ituyqwstonmhnfshnaqz`  
**Clasificación global:** CRITICAL (Auth/RLS/GRANT/secrets) + HIGH (KronIA tools, commercial/clinical writes)  
**Objetivo:** reconstruir KronIA como capa conversacional multimodal, orquestadora y gobernada de ASCENDA, unificando texto, voz, tools, modales, alarmas y agentes sin ampliar autonomía sobre una base insegura.

---

## 1. RESUMEN EJECUTIVO

KronIA ya posee componentes valiosos: chat, voz, historial corto, búsqueda contextual, ejecución de RPC allowlisted, Chrome extension, Brain/cerebro, agentes, notificaciones y tablas de auditoría. Sin embargo, estos componentes pertenecen a varias generaciones de arquitectura y no forman hoy un sistema coherente de conversación/acción.

La auditoría concluye que **no debe continuarse ampliando KronIA de forma incremental sobre la arquitectura actual**. La ruta correcta es una reconstrucción compatible por capas:

1. cerrar primero identidad, permisos, secretos y bypasses directos;
2. crear un Tool Gateway tipado y server-authoritative;
3. convertir confirmaciones en propuestas persistidas y verificables;
4. crear un UI Action Bridge reutilizable para abrir modales ASCENDA desde texto o voz;
5. unificar conversación escrita y hablada en una sesión multimodal;
6. introducir voz realtime con WebRTC, turn detection e interrupciones;
7. crear un Watch/Alarm Engine determinista;
8. reconciliar y versionar el sistema de agentes;
9. recién después ampliar autonomía.

KronIA debe evolucionar de **chat que puede llamar RPCs** a **control plane conversacional de ASCENDA**.

---

## 2. SUPERFICIE AUDITADA

### Código productivo
- `app/server.js`
- `app/public/app.html`
- `app/public/kronia-core.js`
- `app/public/cerebro.html`
- `app/public/admin-sales.html`
- `app/public/agents.html`
- `chrome-extension/*`
- `electron-app/*`
- `app/railway.json`
- configuración/runtime asociado

### Gobierno y arquitectura
- `AGENTS.md`
- `SECURITY.md`
- `docs/control/ASCENDA_CONTROL_MASTER.md`
- `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`
- memoria técnica y sesiones históricas relevantes

### Supabase
- funciones/RPC KronIA y `aos_editar_venta`
- tablas KronIA
- tablas de agentes
- integraciones y usuarios
- grants, RLS y policies
- tareas, mensajes, notificaciones y telemetría

### Investigación histórica recuperada
- patrones RUFLO/Jarvis guardados en `aos_memory`
- jerarquía coordinador/workers
- messaging mesh
- verificación claim/evidence/consensus
- memoria compartida
- scanner de seguridad
- optimización de costos

---

## 3. ARQUITECTURA ACTUAL REAL

### 3.1 Chat escrito
`app/public/kronia-core.js` envía preguntas a `/api/kronia/chat` y conserva una ventana corta de historial local. El backend carga contexto mediante heurísticas/regex, consulta Supabase y llama Groq. Algunas respuestas pueden contener una acción propuesta que el frontend muestra para confirmar.

### 3.2 Voz principal
El shell principal usa `MediaRecorder`: captura un clip completo, lo envía a `/api/kronia/whisper`, recibe texto y recién después entra al mismo chat. Es push-to-talk, no realtime.

### 3.3 Brain/cerebro (Brime referido operativamente)
El Brain usa un pipeline diferente:
- Web Speech API / `SpeechRecognition`;
- `continuous = false`;
- resultados intermedios;
- texto final → `kronia.chat()`;
- salida por `speechSynthesis` del navegador;
- además conserva una ruta MediaRecorder/Whisper.

Por tanto existen **dos STT, dos semánticas de turno y una TTS browser-dependent**, sin una sesión de audio realtime común.

### 3.4 Tools
El backend mantiene una whitelist de RPC y permite confirmar acciones. Sin embargo, el LLM propone acciones en formato JSON embebido en texto y la autoridad efectiva todavía depende demasiado de parámetros generados por el modelo y del cliente.

### 3.5 Agentes
Existe infraestructura de agentes, conexiones, tareas y mensajería. La base viva contiene una generación antigua de agentes, mientras `aos_memory` describe una generación posterior con Dante/Nico/Valentina/Marco/Camila/León/Sofía/Hugo/Luna/Bruno/Elena. No existe hoy un registry canónico versionado que resuelva esa divergencia.

---

## 4. HALLAZGOS CRITICAL

### K-C01 — Rol falsificable en la frontera legacy de KronIA
`validarSesionKronia()` valida usuario activo e ID asesor opcional, pero la autorización no deriva de manera autoritativa el rol server-side. El body del caller puede aportar `rol`.

**Impacto:** una identidad válida puede intentar presentarse con un rol superior si otro control no lo impide.

### K-C02 — Bypass directo de Tool Gateway por RPC SECURITY DEFINER
Baseline medido:
- 19 funciones scoped auditadas;
- 19 son `SECURITY DEFINER`;
- 16 son ejecutables por `anon`;
- 16 son ejecutables por `authenticated`.

Varias funciones de edición aceptan `p_rol`/`p_usuario` como argumentos y confían en esos valores. `aos_kronia_editar_paciente` no recibe un rol autoritativo equivalente.

**Impacto:** el diseño de confirmación en Node puede ser evitado mediante llamada directa a PostgREST/RPC mientras esos grants permanezcan.

### K-C03 — Tabla de tokens KronIA sin aislamiento suficiente
`aos_kronia_tokens` tiene RLS desactivado y privilegios amplios. Los tokens se persisten junto con identidad/contexto de sesión.

**Impacto:** exposición, manipulación o revocación no autorizada de sesiones si la superficie REST queda alcanzable.

### K-C04 — Integraciones/API keys expuestas por policy/grants heredados
`aos_integraciones` contiene credenciales de proveedores. Aunque RLS está habilitado, las policies/grants auditados permiten una superficie excesiva para `anon`.

**Impacto:** potencial lectura o alteración de secretos/proveedores.

### K-C05 — Identidad/usuarios con policy demasiado permisiva
`aos_usuarios` conserva superficie de escritura/lectura heredada para `anon`.

**Impacto:** compromete la premisa de que rol, estado y permisos sean autoridad confiable.

### K-C06 — Audit logs no son evidencia inmutable
Tablas de conversación/acciones/auditoría mantienen permisos de mutación demasiado amplios.

**Impacto:** una acción puede no disponer de evidencia append-only confiable; esto invalida auditoría fuerte y no repudio operacional.

### K-C07 — Endpoints de agentes sin gate autoritativo visible
En el router inspeccionado, rutas como `/api/agents/tick`, `/status`, `/run` y `/chat` se atienden bajo CORS amplio y no muestran un gate de sesión equivalente antes de invocar la lógica del agente.

**Impacto:** potencial ejecución/orquestación no autorizada. Debe confirmarse con test HTTP negativo en staging antes de cierre.

### K-C08 — Secretos/configuración sensible en runtime source
El servidor conserva configuración sensible heredada que debe migrarse a variables de entorno/secret manager y rotarse cuando corresponda.

**Regla:** ningún valor secreto se reproduce en este documento.

---

## 5. HALLAZGOS HIGH

### K-H01 — Confirmación no está ligada a una propuesta server-side
El frontend recibe `rpc + params` y los reenvía al confirmar. No existe un `proposal_id` server-side con digest, objeto, versión, usuario, sesión, expiración e idempotency key.

### K-H02 — El modelo produce pseudo-tool calls dentro de texto
La salida se parsea buscando JSON/acción. Esto es menos robusto que tools tipadas con schema y policy enforcement.

### K-H03 — Falta optimistic concurrency
Una propuesta puede basarse en un estado de venta/cita/paciente que cambió antes de la confirmación.

### K-H04 — Falta disambiguation contract
Consultas como “busca la venta de X del martes” pueden devolver múltiples candidatos sin un protocolo estructurado de selección antes de editar.

### K-H05 — Intención de ejecución detectada por regex
Verbos como cambiar/corregir/reprogramar activan ramas heurísticas. Esto genera falsos positivos, falsos negativos y fragilidad lingüística.

### K-H06 — Context routing por regex
El backend decide qué contexto cargar por palabras. Riesgos: overfetch, gasto de tokens, PII innecesaria y falta de evidencia explícita de por qué se consultó cada dominio.

### K-H07 — No existe Policy Gate por tool/campo
La whitelist está a nivel RPC. Falta clasificar:
- intent;
- objeto;
- campos;
- sensibilidad;
- rol;
- sede;
- lectura/propuesta/escritura;
- confirmación requerida;
- 2FA/approval;
- rollback.

### K-H08 — No hay protección fuerte contra replay
Una confirmación capturada o repetida no está anclada a un nonce/idempotency key y estado esperado.

### K-H09 — Falta DLP/prompt-injection boundary
Contenido recuperado de fuentes internas/externas puede entrar al prompt. Debe ser tratado como datos, nunca como instrucciones de autoridad.

### K-H10 — Los jobs históricos permiten `sql_query`
El nuevo Watch/Alarm Engine no debe heredar la capacidad genérica de SQL arbitrario de tareas antiguas.

---

## 6. HALLAZGOS VOICE / BRIME-BRAIN

### K-V01 — No existe conversación realtime
Actualmente la voz se transforma a texto por clips o por SpeechRecognition del navegador. No existe stream continuo bidireccional de audio con sesión persistente.

### K-V02 — Dos pipelines STT divergentes
Web Speech y Whisper generan diferencias de calidad, latencia, endpointing y compatibilidad.

### K-V03 — `continuous=false`
El Brain fragmenta el diálogo por diseño. Una pausa puede cerrar el turno aunque el pensamiento del usuario no haya terminado.

### K-V04 — No existe turn detection semántica/VAD compartida
Faltan reglas consistentes para:
- inicio de habla;
- fin de turno;
- silencio;
- ruido;
- backchannel;
- falsa interrupción.

### K-V05 — No existe barge-in real
Si KronIA habla y el usuario la interrumpe, el sistema no mantiene de forma robusta qué audio llegó a escuchar el usuario ni trunca el contexto de manera coherente.

### K-V06 — TTS del navegador
`speechSynthesis` depende de navegador/SO/voz instalada y no ofrece un contrato uniforme de latencia, voz ni sincronización.

### K-V07 — Estado multimodal fragmentado
Texto, voz, Tool, modal y agentes no comparten un único `conversation_id`/event stream.

### K-V08 — Acciones sensibles no tienen UX de voz segura
Una orden hablada de edición financiera o clínica necesita pasar a una superficie visual confirmable; no debe ejecutarse por “sí” ambiguo sin propuesta visible y política de aprobación.

---

## 7. OBSERVABILIDAD Y LIVENESS

Baseline observado:
- KronIA: 141 conversaciones históricas;
- 108 ejecuciones registradas en el objeto agente;
- `aos_kronia_acciones`: 0 filas;
- tokens/costos KronIA recientes en ledger: 0;
- `aos_agente_tareas`: 59;
- `aos_agente_mensajes`: 720;
- `aos_notificaciones`: 27;
- `aos_log_notificaciones`: 0;
- múltiples tareas se declaran activas pero su última ejecución conocida quedó meses atrás.

Conclusión: **estado configurado != estado vivo**. Deben existir health/heartbeat/last_success/last_failure/queue_depth y SLO explícitos.

---

## 8. SESGOS ARQUITECTÓNICOS DETECTADOS

1. **UI-first bias:** se intentó sentir “Jarvis” antes de tener un runtime conversacional robusto.
2. **LLM-authority bias:** el modelo decide demasiado sobre qué RPC/params ejecutar.
3. **client-trust bias:** rol y propuesta viajan desde navegador con más autoridad de la permitida.
4. **single-turn bias:** historial corto y voz por turnos aislados en vez de event sourcing conversacional.
5. **regex bias:** lenguaje natural se traduce a intención/contexto con patrones frágiles.
6. **active-flag bias:** `activo=true` se interpretó como agente operativo sin heartbeat real.
7. **append-a-feature bias:** varias generaciones se agregaron sin retirar/consolidar la anterior.
8. **provider-coupling bias:** voz, texto y agentes no pasan por una abstracción de proveedor/telemetría común.
9. **audit-exists bias:** crear una tabla de logs no equivale a tener auditoría confiable si puede mutarse o no recibe eventos.
10. **reuse-by-DOM bias:** reutilizar un modal no debe significar automatizar clicks; debe convertirse en un componente/renderer con contrato.

---

## 9. COMPONENTES A CONSERVAR / REFACTORIZAR / RETIRAR

### CONSERVAR
- concepto `KroniaCore` compartido;
- endpoint conceptual de conversación;
- búsqueda/RPC de dominio como base semántica;
- `aos_editar_venta` como capacidad de negocio, luego de hardening/versionado;
- modal de edición de venta como referencia UX;
- `aos_agente_mensajes` como idea de bus de coordinación;
- Commercial Intelligence V3 y su Governance Gate;
- sistema de paneles/roles/2FA nuevo como patrón de autorización;
- auditoría de ediciones como intención funcional.

### REFACTORIZAR
- `kronia-core.js` → SDK interno multimodal/event-driven;
- Brain/Brime → cliente realtime del mismo runtime;
- acciones → Tool Registry tipado;
- confirmación → Proposal/Approval Engine persistido;
- modales por página → Modal Registry/UI Action Bridge;
- agentes → Capability Registry versionado + health;
- tareas → Watch/Job Engine tipado;
- tokens → sesiones opacas/rotables con storage seguro y hash cuando aplique;
- telemetría → unified usage ledger.

### RETIRAR PROGRESIVAMENTE
- rol confiado desde body;
- ejecución directa `anon` de Tools sensibles;
- API keys consultables desde browser role;
- pseudo-tool JSON parseado desde texto;
- SpeechRecognition como pipeline principal productivo;
- `speechSynthesis` como única TTS productiva;
- SQL arbitrario en nuevos agentes/watches;
- duplicado de `kronia-core.js` entre web y extensión;
- CORS global indiscriminado en rutas privilegiadas.

---

## 10. ARQUITECTURA OBJETIVO — KRONIA CONTROL PLANE

```text
TEXT / VOICE / UI
       │
       ▼
UNIFIED CONVERSATION SESSION
conversation_id · identity · role · panels · sede · channel
       │
       ▼
AI / INTENT ROUTER
       │
       ├──────── READ TOOLS ────────► Facts / RPC / Search
       │
       ├──────── AGENT DELEGATION ─► Capability Registry
       │
       └──────── MUTATION INTENT
                    │
                    ▼
              TOOL REGISTRY
                    │
                    ▼
              POLICY GATE
         ALLOW / APPROVAL / BLOCK
                    │
                    ▼
          PERSISTED PROPOSAL
    current · proposed · diff · digest
                    │
                    ▼
             UI ACTION BRIDGE
       ASCENDA modal / voice summary
                    │
             approve/edit/reject
                    │
                    ▼
           SECURE EXECUTION GATEWAY
 identity server-side · expected version · idempotency
                    │
                    ▼
            VERIFY POST-STATE
                    │
                    ▼
        APPEND-ONLY AUDIT + TELEMETRY
```

---

## 11. ACTION / MODAL CONTRACT

KronIA no debe “hacer click” en un panel. Debe emitir comandos UI tipados.

Ejemplo conceptual:

```json
{
  "type": "OPEN_EDITOR",
  "renderer": "sales.editor",
  "object_id": "...",
  "proposal_id": "..."
}
```

El shell ASCENDA resuelve `sales.editor` desde un **Modal Registry** compartido.

### Flujo de ejemplo — cambiar método de pago
1. Usuario: “Busca la venta de Ana del 7 de agosto”.
2. KronIA usa `sales.search` read-only.
3. Si hay >1 match, abre selector de candidatos.
4. Usuario: “la segunda; cambia Yape por tarjeta”.
5. Tool Gateway lee estado actual.
6. Proposal Engine crea diff persistido.
7. Policy Gate determina `REQUIRE_APPROVAL`.
8. UI abre modal ASCENDA mostrando antes/después.
9. Usuario puede aprobar, cancelar o editar más campos.
10. Gateway ejecuta con identidad derivada server-side.
11. Verifica estado final.
12. KronIA confirma por texto/voz el resultado real.
13. Audit append-only registra propuesta, decisión, ejecución y resultado.

---

## 12. VOICE V2 TARGET

La voz debe ser otro transporte de la misma conversación, no otro chatbot.

### Estado de sesión
`IDLE → LISTENING → UNDERSTANDING → TOOLING / CONFIRMING → SPEAKING → LISTENING`

Estados adicionales: `PAUSED`, `INTERRUPTED`, `RECONNECTING`, `ERROR`.

### Requisitos mínimos
- WebRTC en navegador;
- streaming bidireccional;
- VAD/semantic turn detection;
- barge-in;
- transcript parcial/final;
- sincronización transcript/audio;
- un solo `conversation_id` para voz y texto;
- tools tipadas;
- UI commands recibidos durante la conversación;
- aprobación visual para HIGH/CRITICAL;
- reconexión y recuperación de sesión;
- métricas P50/P95 de latencia.

### Stacks actuales a evaluar en PoC
- OpenAI Realtime + Agents SDK: camino directo speech-to-speech, tools, approvals, interruptions y WebRTC browser.
- LiveKit Agents: capa realtime/provider-portable con WebRTC, turn handling, observabilidad y frontend state/data.
- Pipecat: pipeline modular para máximo control/proveedor, con mayor ownership operativo.

**Recomendación de auditoría:** no seleccionar por marketing. Implementar benchmark controlado de 2 candidatos con el mismo Tool Gateway y medir latencia, español PE, interrupciones, costo, trazabilidad y recuperación.

---

## 13. WATCH / ALARM ENGINE TARGET

No reutilizar `sql_query` arbitrario como lenguaje de alarmas.

Objetos propuestos:
- `aos_watch_rules`
- `aos_watch_runs`
- `aos_watch_events`
- `aos_watch_deliveries`
- `aos_watch_acknowledgements`

Cada regla define:
- fact/tool fuente;
- condición tipada;
- ventana temporal;
- frecuencia/event trigger;
- severidad;
- destinatario/rol;
- cooldown/dedup;
- evidence payload;
- estado/expiración;
- creador y approval requerido.

Ejemplo: “Avísame si mañana Pueblo Libre baja de 70% de ocupación”. KronIA crea primero una propuesta de Watch; el sistema muestra la regla, frecuencia y destinatario; tras aprobación se activa.

---

## 14. AGENT ORCHESTRATION V2

### Problema
La base viva y la memoria describen generaciones diferentes de agentes.

### Target
`Agent Capability Registry` versionado:
- canonical_agent_id;
- display_name;
- domain;
- capabilities;
- allowed_tools;
- provider/model policy;
- input/output schema;
- escalation target;
- autonomy level;
- active_version;
- health state.

KronIA es coordinadora/orquestadora, pero **no obtiene permisos extra por ser orquestadora**. Cada tool conserva policy propia.

### Patrones RUFLO recuperables
- coordinator/workers;
- mesh messaging;
- claim/evidence/consensus para decisiones críticas;
- memory layers;
- security scanner;
- cost optimizer.

No copiar código externo a producción sin revisión de licencia, mantenimiento, threat model y compatibilidad.

---

## 15. ROADMAP DE RECONSTRUCCIÓN

### K0 — Complete Baseline & Security Audit
**Estado:** COMPLETE DOCUMENTARY BASELINE.  
Salida: este documento, matriz de exposición, contratos objetivo. Producción sin cambios.

### K1 — Identity, Session & Secrets Hardening
- autoridad server-side;
- secrets fuera de browser/database surface pública;
- revoke public execution de tools sensibles mediante migración compatible;
- hardening token/session;
- CORS/rate limits;
- append-only audit baseline;
- pruebas negativas por rol.

### K2 — Tool Registry + Proposal/Approval Engine
- tools tipadas;
- schema validation;
- policy gate;
- proposal persistence/digest/expiry;
- idempotency;
- optimistic concurrency;
- disambiguation.

### K3 — UI Action Bridge + Modal Registry
- extraer editor de venta como primer renderer;
- OPEN_VIEW / OPEN_EDITOR / OPEN_CONFIRMATION / SHOW_DIFF;
- contratos responsive;
- sin DOM automation frágil.

### K4 — Unified Conversation + AI Gateway
- conversation/event ledger;
- provider/model router;
- context minimization;
- token/cost/latency ledger;
- evidence/source metadata;
- eval harness.

### K5 — Brime/Brain Realtime Voice
- WebRTC;
- VAD/turn detection;
- barge-in;
- transcript streaming;
- same conversation/tools/UI events;
- browser/mobile test matrix.

### K6 — Watch & Alarm Engine
- typed watches;
- scheduler/event triggers;
- dedup/cooldown;
- delivery + acknowledge/escalate;
- KronIA create/inspect/pause watches through approval policy.

### K7 — Agent Registry & Orchestrator Reconciliation
- canonicalize generations;
- capabilities;
- typed messages;
- heartbeat;
- retries/circuit breakers;
- remove arbitrary new SQL tasks.

### K8 — Multimodal Rollout & Hardening
- staged rollout;
- shadow mode;
- canary admins;
- observability/SLOs;
- rollback drills;
- security/eval regression;
- controlled broader activation.

---

## 16. ACCEPTANCE GATES

No declarar KronIA V2 lista hasta que:

- [ ] K-G01 identidad/rol no dependen del body del navegador;
- [ ] K-G02 ninguna Tool de escritura sensible puede ejecutarse directamente por `anon`;
- [ ] K-G03 secretos no son legibles por roles browser;
- [ ] K-G04 proposal/approval es server-authoritative y replay-safe;
- [ ] K-G05 auditoría es append-only y reconciliable;
- [ ] K-G06 Tool Registry valida schema/campos/rol/policy;
- [ ] K-G07 editor de venta funciona desde panel y desde KronIA con el mismo renderer;
- [ ] K-G08 voz y texto comparten `conversation_id`;
- [ ] K-G09 barge-in/turn detection pasan matriz de pruebas;
- [ ] K-G10 una acción por voz HIGH requiere confirmación visual efectiva;
- [ ] K-G11 token/cost/latency ledger registra cada llamada AI;
- [ ] K-G12 agentes tienen registry/version/health canónico;
- [ ] K-G13 Watches no ejecutan SQL arbitrario;
- [ ] K-G14 CI + staging + negative auth tests verdes;
- [ ] K-G15 rollback de Auth/Tools/Voice documentado y probado;
- [ ] K-G16 security scan sin hallazgos HIGH/CRITICAL abiertos en scope;
- [ ] K-G17 E2E texto: buscar→proponer→editar modal→confirmar→verificar;
- [ ] K-G18 E2E voz: hablar→buscar→modal→aprobar→ejecutar→respuesta hablada;
- [ ] K-G19 alarm: crear→activar→trigger→dedup→delivery→ack;
- [ ] K-G20 producción activada gradualmente con observación posterior.

---

## 17. DECISIÓN DE ARQUITECTURA

**No hacer ahora:**
- conectar un nuevo modelo realtime directamente a RPC productivas;
- ampliar permisos de KronIA;
- hacer que voz ejecute escrituras sin UI;
- reusar SQL jobs legacy como engine de alarmas;
- fusionar cambios directamente a `main`.

**Hacer ahora:** iniciar K1 en branch aislada con Impact Report CRITICAL, migrations backward-compatible, tests de bypass/grants/secrets y cero cambio funcional visible para usuarios hasta cerrar los gates de seguridad.

---

## 18. CONCLUSIÓN

La visión de KronIA tipo “Jarvis” es técnicamente viable con la base actual, pero el salto no se consigue agregando más prompts o una voz más natural. El núcleo debe ser un sistema gobernado de **identidad + conversación + tools + propuestas + UI + eventos + agentes + auditoría**.

La base funcional existente reduce el trabajo: búsquedas, ventas, editor, Brain, agentes y datos ya existen. La reconstrucción debe aprovecharlos como activos, pero eliminar la autoridad implícita del navegador, la fragmentación de voz y la ejecución no tipada.

**Próximo gate autorizado por este audit:** preparar K1 — Identity, Session & Secrets Hardening en branch no productiva. No aplicar cambios CRITICAL a producción sin staging, pruebas, rollback y autorización de release correspondiente.
