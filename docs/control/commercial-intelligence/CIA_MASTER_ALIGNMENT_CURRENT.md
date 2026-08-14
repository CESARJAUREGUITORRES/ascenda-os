# ASCENDA OS — CIA MASTER ALIGNMENT CURRENT

**Estado:** CURRENT  
**Fecha:** 2026-08-13 (America/Lima)  
**Master arquitectónico:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`  
**Estado dinámico:** `docs/control/commercial-intelligence/ROADMAP_STATUS.md`  
**Checkpoint canónico:** `2e1116f07919fcf53bdac8cf61cbd23944863630`

---

# 1. OBJETIVO

Este documento endereza formalmente la relación entre el Master V3 original y el estado real después de completar Fases 0–9.

El Master V3 original sigue siendo **arquitectura madre vigente** para:

- visión;
- principios no negociables;
- separación Audience/Eligibility/Activation/Assignment/Work View;
- Fact Registry/DSL;
- IA/policy gate;
- performance/design system;
- compatibilidad Call Center/Email;
- testing/rollback master;
- roadmap conceptual 0–18;
- definición de éxito final.

Sin embargo, sus secciones creadas como baseline de arranque ya no representan el estado actual.

---

# 2. SECCIONES DEL MASTER ORIGINAL SUPERSEDED COMO ESTADO

Quedan marcadas conceptualmente como **HISTORICAL / SUPERSEDED FOR CURRENT STATUS**:

- encabezado `READY FOR PHASE 0`;
- sección 41 `ESTADO DE EJECUCIÓN ACTUAL`;
- sección 42 `PRIMERA ACCIÓN DESPUÉS DE APROBAR V3`.

No deben borrarse porque documentan el punto de partida y la intención original.

Para estado actual usar siempre:

1. `CIA_AGENT_BOOTSTRAP_CURRENT.md`;
2. `ROADMAP_STATUS.md`;
3. último `PHASE_XX_VALIDATION_REPORT.md`;
4. `aos_memory`;
5. `staging` + Supabase live.

---

# 3. ROADMAP MAESTRO 0–18 — ALINEACIÓN ACTUAL

El índice de 19 fases del Master **se conserva**. No se reordena.

| # | Fase | Estado actual | Dependencia principal |
|---:|---|---|---|
| 0 | Baseline & Contracts | `100_COMPLETE` | inicio |
| 1 | Identity Resolver | `100_COMPLETE` | F0 |
| 2 | Commercial Facts | `100_COMPLETE` | F1 |
| 3 | Segmentation Engine | `100_COMPLETE` | F2 |
| 4 | Audience Resolver | `100_COMPLETE` | F1–F3 |
| 5 | Panel Central Skeleton | `100_COMPLETE` | F4 |
| 6 | Audience Library Persistence | `100_COMPLETE` | F4–F5 |
| 7 | Snapshots & Activation | `100_COMPLETE` | F6 |
| 8 | Channel Context & Availability | `100_COMPLETE` | F7 |
| 9 | Assignment Engine | `100_COMPLETE` | F8 |
| 10 | Advisor Control Center | `READY` | F9 read-models |
| 11 | Call Center Integration V3 | `NOT_STARTED` | F9 + F10 |
| 12 | Advisor Work Views | `NOT_STARTED` | F9 + F11 |
| 13 | Requests & Approval Engine | `NOT_STARTED` | F9/F12 |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` | outcomes + F10/F12 |
| 15 | KronIA + Multiagent | `NOT_STARTED` | F13/F14 |
| 16 | Email Integration | `NOT_STARTED` | Audience/Activation central |
| 17 | SMS/WhatsApp/Future Channels | `NOT_STARTED` | F8/F16 patterns |
| 18 | Attribution/Learning/Hardening | `NOT_STARTED` | todas las anteriores |

---

# 4. CAMINO RESTANTE — NO DESVIARSE

## F10 Advisor Control Center

Primero observar y controlar Assignment antes de conectarlo al runtime de llamadas.

Input:
- `aos_cia_assignment_advisor_workload_v1()`;
- `aos_cia_assignment_plan_summary_v1(plan_id)`;
- list/events F9.

Output para F11:
- control plane administrativo confiable;
- carga/capacidad/depletion visibles;
- capacidad de diagnosticar ownership antes de routing.

## F11 Call Center Integration V3

Primera fase que puede conectar Assignment con siguiente contacto del Call Center.

Obligatorio:
- V3 paralela;
- feature flag;
- fallback V2;
- rollout por usuarios;
- hashes/baselines pre/post;
- rollback inmediato;
- no big bang.

## F12 Advisor Work Views

Personalización dentro de ownership autorizado. No autoasignación.

## F13 Requests & Approval

Gobernanza estructurada para pedir/cambiar recursos y ejecutar tras revalidación.

## F14 Commercial Intelligence Shadow

Recomendaciones con evidence/confidence/sample size; sin autoacciones.

## F15 KronIA + Multiagent

Orquestación sobre tools/contracts; Policy Gate; no SQL write arbitrario.

## F16 Email

Consume la arquitectura central, migra de forma progresiva y mantiene flows existentes como fallback durante transición.

## F17 SMS/WhatsApp

Mismo Audience Engine; provider/backend específico; no duplicar audiencias por canal.

## F18 Attribution/Learning/Hardening

Cerrar cadena:

`Audience → Activation → Assignment/Channel → Contact → Appointment → Attendance → Sale → Revenue`

más observabilidad, resiliencia, seguridad, jobs y paquete reusable.

---

# 5. DECISIONES DEL MASTER CONFIRMADAS POR LA IMPLEMENTACIÓN

Las siguientes decisiones originales demostraron ser correctas y quedan reforzadas:

- no big-bang;
- read-only first;
- `numero_limpio` como bridge temporal;
- facts 1:1 por contacto;
- no SQL arbitrario desde IA/frontend;
- una sola audiencia multicanal;
- Snapshot para reproducibilidad;
- leases en Assignment;
- feature flag/fallback para Call Center;
- SHADOW antes de autonomía IA;
- no Redis/Kafka/Temporal sin evidencia;
- `aos_usuarios.id` como identidad de ownership;
- GitHub + `aos_memory` como continuidad dual.

---

# 6. DECISIONES DEL MASTER REFINADAS POR APRENDIZAJE REAL

## Realtime vs cache

No basta clasificar facts como realtime/batch: cada cache debe demostrar cobertura contra el universo y exponer freshness. UNKNOWN falla cerrado.

## Performance

Evitar mega-vistas incluso si conceptualmente son elegantes. El planner debe resolver por dominios/facts necesarios.

## Seguridad

No basta RLS teórico. Verificar grants reales y write-path side effects de funciones usadas en índices/triggers.

## Testing

Añadir dos gates que la experiencia demostró críticos:

- handshake fase anterior → fase actual;
- output fase actual → fase siguiente.

## Replayability

Migration versionada significa también timestamp/nombre compatible con `schema_migrations` real.

## Timezone

La timezone operacional de Zi Vital es `America/Lima`; evitar `CURRENT_DATE` implícito cuando el significado sea “hoy en clínica”.

---

# 7. ESTADO ACTUAL DE LA MISIÓN

Hasta Fase 9 ya existen físicamente y están certificados:

- identidad comercial;
- facts;
- segmentación;
- Audience Resolver;
- panel central;
- biblioteca versionada;
- snapshots/activations;
- context/availability;
- Assignment Engine.

Lo que falta no es rehacer ese cerebro, sino conectar control operativo, experiencia de asesores, approvals, intelligence, KronIA, canales y outcomes sobre esos contratos.

La siguiente fase correcta es **Fase 10 — Advisor Control Center**.

No saltar directamente a F11 solo porque Assignment ya existe: primero debe existir observabilidad/control suficiente para operar y revertir el routing cuando se conecte Call Center.