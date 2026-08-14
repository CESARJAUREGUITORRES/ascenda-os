# ASCENDA OS — CIA EXECUTION PLAYBOOK V1

**Subproyecto:** Commercial Intelligence & Audience OS V3  
**Estado:** CURRENT  
**Fecha de aprendizaje:** 2026-08-13 (America/Lima)  
**Checkpoint de entrada:** `2e1116f07919fcf53bdac8cf61cbd23944863630`  
**Estado al crear este Playbook:** Fases 0–9 `100_COMPLETE`; Fase 10 `READY`.

---

# 1. PROPÓSITO

Este documento convierte los aprendizajes reales de Fases 0–9 en un protocolo obligatorio de ejecución para las Fases 10–18 y para cualquier agente/chat futuro.

No reemplaza:

- `AGENTS.md`;
- `docs/control/ASCENDA_CONTROL_MASTER.md`;
- `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`.

Los complementa con evidencia operacional adquirida durante la implementación real.

La misión del subproyecto sigue siendo construir un centro de control comercial transversal que transforme datos vivos de ASCENDA en audiencias, disponibilidad, asignaciones, trabajo de asesores, inteligencia y acciones gobernadas, sin romper los flujos productivos actuales.

La misión global de ASCENDA sigue siendo:

`CONTROLAR → ESTABILIZAR → MIGRAR A PROPIEDAD CORPORATIVA → PRODUCTIZAR COMO SaaS`

No convertir la producción actual directamente en SaaS.

---

# 2. JERARQUÍA DE FUENTES DE VERDAD

Para Commercial Intelligence & Audience OS, leer y resolver contradicciones en este orden:

1. `AGENTS.md` — reglas globales de ingeniería.
2. `docs/control/ASCENDA_CONTROL_MASTER.md` — misión y gobierno global ASCENDA.
3. `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md` — estado y arranque operativo actual.
4. `docs/control/commercial-intelligence/CIA_EXECUTION_PLAYBOOK_V1.md` — protocolo de ejecución y lecciones.
5. `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md` — arquitectura funcional madre.
6. `docs/control/commercial-intelligence/ROADMAP_STATUS.md` — estado dinámico de fases.
7. último `PHASE_XX_VALIDATION_REPORT.md` — evidencia del cierre anterior.
8. código de `staging` + migrations Git.
9. esquema y datos vivos de Supabase.

Regla: el código/schema vivo puede demostrar drift o una deuda real; en ese caso se corrige la documentación. Un documento histórico nunca debe forzar a ignorar el runtime real.

Las secciones de estado inicial del Master V3 original son históricas. El estado actual se obtiene del Roadmap + Bootstrap.

---

# 3. LOOP UNIVERSAL V2 — OBLIGATORIO

Cada fase se ejecuta con este orden. No saltar gates para acelerar.

## Gate A — Recovery / Preflight

1. leer Bootstrap, Roadmap, último Validation Report y `aos_memory`;
2. verificar `staging` HEAD real;
3. verificar Supabase live y migrations reales;
4. verificar si la fase anterior dejó objetos/deudas físicas que afecten la nueva;
5. comprobar que el flujo productivo crítico relacionado sigue sano.

## Gate B — Baseline

6. cerrar alcance y explícitamente declarar fuera de scope;
7. medir baseline real antes de cambiar nada;
8. localizar UI → RPC/API → tablas → triggers → otros consumidores;
9. verificar roles/ACL/RLS/SECURITY DEFINER cuando aplique;
10. registrar hash/definición de contratos productivos que no deben cambiar.

## Gate C — Impact / Design

11. Impact Report antes de DDL para HIGH/CRITICAL;
12. definir contrato de entrada desde fase anterior;
13. definir contrato de salida para fase siguiente;
14. definir invariantes de DB y estados;
15. definir rollback;
16. decidir si la solución requiere cache/job/index únicamente con evidencia.

## Gate D — Branch / Replayability

17. branch desde `staging` actual;
18. migration-first por defecto;
19. los filenames de migrations deben coincidir con `schema_migrations` real;
20. si una limitación de herramientas obliga a micro-migrations live, reconciliar Git en el mismo loop antes del cierre;
21. ningún objeto importante puede existir solamente en producción al certificar la fase.

## Gate E — Implementation

22. cambios aditivos/backward-compatible primero;
23. invariantes importantes también en DB, no solo UI/RPC;
24. actor/ownership por IDs canónicos verificables, no nombres;
25. navegador nunca recibe SQL libre ni acceso directo a tablas CIA privadas;
26. AI nunca crea SQL arbitrario;
27. mantener separación de responsabilidades entre Audience / Context / Activation / Assignment / Work View.

## Gate F — QA

28. contract tests;
29. source reconciliation: derived count = cálculo directo cuando exista comparación;
30. edge cases;
31. tests adversariales que intenten romper invariantes;
32. test de rol `anon`, `authenticated`, ADMIN/asesor según alcance;
33. E2E rollback-only para mutaciones cuando sea posible;
34. comprobar cero residuos QA;
35. probar conexión fase anterior → fase actual;
36. probar contrato fase actual → fase siguiente.

## Gate G — Performance / Operational Safety

37. medir cold y warm cuando la diferencia sea relevante;
38. medir escenario normal y un escenario grande/complex;
39. `EXPLAIN (ANALYZE, BUFFERS)` antes de nuevos índices;
40. todo índice/trigger/function usado por una tabla operativa debe pasar WRITE-PATH SAFETY TEST como el rol real que escribe;
41. comprobar timezone explícita `America/Lima` en ventanas de día;
42. comprobar freshness/cobertura de caches contra universo actual;
43. comprobar flujos productivos críticos después del cambio.

## Gate H — Frontend

44. diseño ASCENDA;
45. loading/empty/error;
46. desktop/tablet/mobile;
47. 0 `alert/confirm/prompt` en workflows normales;
48. 0 filtrado masivo en browser;
49. gateway/RPC controlado como superficie de datos;
50. fase futura no debe aparecer funcionalmente antes de su engine.

## Gate I — Git / Integration

51. diff completo contra `staging`;
52. eliminar helpers/experimentos muertos;
53. PR funcional;
54. CI SUCCESS;
55. merge a `staging`;
56. smoke post-merge live;
57. verificar que contratos legacy protegidos siguen idénticos cuando corresponda.

## Gate J — Closure

58. Validation Report → `100_COMPLETE` solo con evidencia;
59. Roadmap actualizado;
60. PR documental + CI + merge;
61. `aos_memory` actualizado;
62. lectura cruzada final GitHub + Supabase;
63. siguiente fase pasa a `READY` solamente cuando su input está probado.

---

# 4. QUÉ FUNCIONÓ BIEN EN LOS LOOPS

## 4.1 Contratos antes de UI

Las fases más estables fueron aquellas donde primero se fijó semántica y luego interfaz. Fact Registry, DSL, tri-state, Snapshot/Activation y Context/Availability evitaron que el frontend se convirtiera en fuente de verdad.

**Regla permanente:** no crear pantalla para una capacidad cuya semántica backend todavía no esté cerrada.

## 4.2 Separación por capas

La separación:

`Identity → Facts → Segmentation → Audience → Activation → Context → Assignment`

permitió corregir una capa sin reescribir las anteriores.

**Regla permanente:** la fase nueva consume el contrato anterior; no reconstruye su lógica.

## 4.3 QA rollback-only

Los E2E mutantes ejecutados dentro de subtransacciones y revertidos al final permitieron probar CREATE/UPDATE/leases/lifecycle/guards con datos reales sin contaminar producción.

**Regla permanente:** preferir QA rollback-only sobre seeds persistentes en producción.

## 4.4 Comparación contra fuente directa

Detectar diferencias entre resultado derivado y consulta directa permitió descubrir bugs reales de root DSL, timezone, defaults y distribución.

**Regla permanente:** un count no se certifica solo porque “parece razonable”. Debe reconciliar cuando exista una verdad directa comparable.

## 4.5 Guards de DB

Los guards de inmutabilidad, append-only, lifecycle, anti-double-ownership y validación de targets protegen incluso frente a callers server-side que omitan el gateway.

**Regla permanente:** todo invariante de integridad crítico debe vivir en DB además de la capa de aplicación.

## 4.6 Cierre dual GitHub + `aos_memory`

Los checkpoints permitieron recuperar continuidad entre chats y evitar depender de memoria conversacional.

**Regla permanente:** una fase no está cerrada hasta que GitHub y `aos_memory` dicen lo mismo.

---

# 5. ERRORES / INCIDENTES QUE SE CONVIERTEN EN GUARDRAILS

## 5.1 Mega-vista Audience Resolver — ~30.4 s

En la validación física de Fase 4/5, el resolver genérico basado en una mega-vista transversal materializaba dominios innecesarios y llevaba una consulta a ~30.4 s.

Corrección: Resolver V2 domain-aware / set-based + caches únicamente donde semánticamente correspondía.

**Guardrail:** no unir todos los dominios “por comodidad”. Resolver solo lo requerido por el filtro/acción.

## 5.2 Índices funcionales rompieron Call Center — HTTP 401

Índices sobre tablas operativas llamaban `aos_cia_normalize_contact_key_v1(numero_limpio)`. Al endurecer EXECUTE de esa función, INSERT de `aos_llamadas` falló porque PostgreSQL necesitaba ejecutar la función para mantener el índice.

Corrección: retirar esos índices y reemplazar por índices de expresión nativa que no dependían de una función CIA privada. Se verificó INSERT como rol real y tráfico `201` real.

**Guardrail:** ningún índice/trigger en write-path operacional puede depender de una función cuyo ACL no sea compatible con el writer. Siempre ejecutar WRITE-PATH SAFETY TEST después de DDL sobre tablas operativas.

## 5.3 Default privileges de funciones

Crear funciones nuevas puede dejar EXECUTE más abierto de lo esperado.

**Guardrail:** después de CREATE FUNCTION/RPC, auditar grants reales. No asumir mínimo privilegio por intención.

## 5.4 Auth heredada / KronIA token

Se detectó un emisor KronIA `SECURITY DEFINER` cuyo contrato no era adecuado para autorizar un panel ADMIN nuevo.

Corrección: CIA Admin Session separada, token hashado y verificación server-side; posterior hardening single-use 2FA.

**Guardrail:** nunca reutilizar auth solo porque existe. Auditar emisión, claims, grants, expiración, replay y actor derivado.

## 5.5 Drift migrations Git ↔ Supabase

Aplicaciones físicas registraron timestamps distintos a nombres provisionales de archivos Git en varios loops.

Corrección: alinear filenames con `schema_migrations` antes del PR/cierre.

**Guardrail:** replayability es un gate propio. Una migration “equivalente” con otro timestamp sigue siendo deuda.

## 5.6 Cache stale contra universo actual

Antes de Fase 8 el universo había crecido mientras Segment/Email caches aún tenían el conteo anterior.

Corrección: freshness explícita, refresh y UNKNOWN fail-closed.

**Guardrail:** comparar cobertura del cache con el universo canónico antes de usar ausencia como FALSE.

## 5.7 Snapshot `digest()` / `search_path`

Fase 8 descubrió que el primer BATCH real de Fase 7 no podía sellarse: `pgcrypto` estaba en `extensions` y el guard llamaba `digest()` bajo `search_path=public`.

Corrección: `extensions.digest(...)` calificado.

**Guardrail:** el cierre de una fase debe incluir handshake real con el consumidor de la siguiente cuando haya funciones/extensiones que aún no se ejercitaron materialmente.

## 5.8 Doble fuente de eventos Activation

Al añadir event emitter DB, los RPC todavía insertaban eventos manualmente.

Corrección: DB quedó como única fuente de lifecycle events.

**Guardrail:** una señal de auditoría tiene un solo productor autoritativo.

## 5.9 Timezone server vs Lima

Fase 8 encontró una diferencia de cita futura entre `CURRENT_DATE` server-side y el día real de Lima.

**Guardrail:** toda lógica operacional diaria debe declarar timezone. Para Zi Vital: `America/Lima`.

## 5.10 CONTINUOUS top-up desbalanceado

Fase 9 detectó que un top-up podía asignar el reemplazo al target equivocado y dejar 53/50 en vez de recuperar 52/51.

Corrección: déficit contra distribución acumulada objetivo.

**Guardrail:** probar algoritmos de distribución después de release/expiry/top-up, no solo distribución inicial.

---

# 6. APRENDIZAJES FASE POR FASE

## Fase 0 — Baseline & Contracts

Acierto: inventario, Fact Registry, frontend contract y protocolo antes de runtime.

Aprendizaje: una baseline solo sirve si se vuelve referencia verificable. Registrar cifras, queries y contratos, no narrativa genérica.

## Fase 1 — Identity Resolver

Acierto: `contact_key` derivado, conflictos explícitos y cero merge destructivo.

Aprendizaje: identidad ambigua debe permanecer ambigua; no escoger un paciente por conveniencia. Email tampoco es merge key automático.

También se aprendió a sincronizar una feature branch cuando `staging` avanza en paralelo en vez de forzar un PR divergente.

## Fase 2 — Commercial Facts

Acierto: facts 1:1 por contacto y separación `latest / ever / never / UNKNOWN`.

Aprendizaje: ausencia de evidencia no siempre es FALSE. Email histórico fragmentado exige resolver y conservar UNKNOWN.

## Fase 3 — Segmentation Engine

Acierto: Value Tier, Lifecycle, Engagement y Traits separados del legacy `etiqueta_vip`.

Aprendizaje: clasificaciones batch/versionadas sí pueden cachearse, pero deben exponer freshness y no mezclarse con hechos realtime.

## Fase 4 — Audience Resolver

Acierto: DSL whitelisted, sin SQL libre; `MATCH/MISS/UNKNOWN`; `never_contains` con evidencia incompleta.

Aprendizaje: negativos comerciales son más difíciles que positivos. “Nunca compró X” necesita saber si el historial completo fue reconciliado.

## Fase 5 — Panel Central Skeleton

Acierto: antes de construir UI se pagó la deuda física de Fases 1–4 y se benchmarkeó runtime real.

Aprendizajes mayores:
- no certificar SQL solo por simulación si la siguiente fase depende físicamente de él;
- no subir timeouts para ocultar una arquitectura lenta;
- proteger write-path operacional al optimizar lectura;
- auth ADMIN requiere prueba server-side, no `role` del browser.

## Fase 6 — Audience Library Persistence

Acierto: definición/versiones separadas de snapshots; optimistic concurrency; archive en lugar de delete; audit append-only.

Aprendizaje: persistencia reusable exige replayability y QA sin residuos, no solo CRUD funcional.

## Fase 7 — Snapshots & Activation

Acierto: Snapshot como objeto inmutable; Activation separada; BATCH vs DYNAMIC; lifecycle auditado por DB.

Aprendizaje: una función no ejercitada en el escenario material real puede ocultar deuda (caso `digest`). La fase siguiente debe verificar handshake anterior.

## Fase 8 — Channel Context & Availability

Acierto: `Total → Eligible → Available Now`, policies por contexto y UNKNOWN no assignable.

Aprendizaje: reglas de una cola no deben universalizarse. PROVINCIA, cita futura, cadencia y disponibilidad dependen de policy/purpose. Freshness y timezone son parte de semántica, no detalles técnicos.

## Fase 9 — Assignment Engine

Acierto: `available_keys` como única entrada; UUID de usuario; leases; GLOBAL/ACTIVATION; idempotency; advisory lock; DB guards; read-model para Fase 10.

Aprendizaje: un algoritmo que reparte bien inicialmente puede fallar en reposición. Siempre probar el ciclo completo `assign → start/release/expire → top-up → close`.

---

# 7. REGLAS DE OPERACIÓN PARA FASES 10–18

## No reconstruir capas anteriores

- F10 consume read-models F9.
- F11 consume F9 ownership y conecta Call Center mediante V3 paralela.
- F12 opera dentro del ownership F9; no reasigna.
- F13 gobierna solicitudes; no reemplaza Assignment.
- F14 observa/recomienda; no ejecuta ownership por su cuenta.
- F15 orquesta mediante policy gate.
- F16 usa Audience/Activation central; no crea un segundo modelo Email.
- F17 reutiliza Audience/Context; no crea audiencias WA/SMS paralelas.
- F18 mide outcomes y endurece; no reescribe historia para “mejorar métricas”.

## Boundary rule

Cada fase debe declarar:

`INPUT CONTRACT ← esta fase → OUTPUT CONTRACT`

antes de escribir código.

## Fail closed

Cuando una dependencia requerida está UNKNOWN/stale/no autorizada, no asumir elegibilidad, disponibilidad, ownership ni aprobación.

---

# 8. ROADMAP RESTANTE — DIRECCIÓN CORRECTA

## Fase 10 — Advisor Control Center

Read/control plane administrativo sobre F9. Carga, estados, deadlines, capacidad, depletion. No routing Call Center.

## Fase 11 — Call Center Integration V3

Primera integración de ownership F9 con `next lead`, en ruta paralela, feature flag y fallback V2. Esta fase es HIGH/CRITICAL operacional.

## Fase 12 — Advisor Work Views

Vistas personales dentro del universo asignado. No cambia ownership.

## Fase 13 — Requests & Approval Engine

Solicitud estructurada → aprobación/rechazo → revalidación → ejecución atómica.

## Fase 14 — Commercial Intelligence Shadow

Oportunidades, afinidad y agotamiento en SHADOW, con confidence/sample size y evaluación contra outcomes.

## Fase 15 — KronIA + Multiagent

Dante/León/Sofía/Valentina/Nico coordinados por tools estructuradas + Policy Gate. Sin SQL write arbitrario.

## Fase 16 — Email Integration

Email consume audiencias/activaciones centrales manteniendo flows actuales hasta migración controlada.

## Fase 17 — SMS / WhatsApp / Future Channels

Provider específico, channel facts y tracking sobre el mismo motor central.

## Fase 18 — Attribution, Learning & Hardening

Base/Activation/Assignment/Channel → cita → asistencia → venta → revenue; resiliencia, seguridad, observabilidad y paquete reusable.

---

# 9. CHECKLIST DE INCIDENTE OPERACIONAL

Si un usuario productivo reporta error durante un loop:

1. pausar cambios no esenciales de la fase;
2. localizar error real en logs/DB;
3. determinar si el loop lo causó;
4. restaurar operación con el rollback más estrecho posible;
5. probar como el rol real del usuario;
6. confirmar tráfico real posterior;
7. documentar RCA;
8. convertir RCA en guardrail permanente;
9. recién después continuar la fase.

No sacrificar disponibilidad de clínica para completar una fase.

---

# 10. DEFINITION OF 100_COMPLETE — CIA

`100_COMPLETE` significa simultáneamente:

- alcance implementado;
- input de fase anterior probado;
- output de fase siguiente listo;
- invariantes DB protegidos;
- seguridad/roles probados;
- performance medida;
- UI/responsive probada si aplica;
- no regresión de flujos críticos;
- migrations replayables;
- cero residuos QA;
- PR funcional merged;
- CI verde;
- staging smoke PASS;
- Validation Report final;
- Roadmap actualizado;
- PR de cierre merged;
- `aos_memory` sincronizado y releído.

Si uno de estos puntos falta y aplica, la fase es `VALIDATING`, no 100%.

---

# 11. REGLA DE CONTINUIDAD

Un agente nuevo nunca debe empezar preguntando “¿en qué íbamos?” si tiene acceso a GitHub/Supabase.

Debe reconstruir:

1. checkpoint;
2. fase actual;
3. contratos de entrada/salida;
4. prohibiciones;
5. schema/runtime live;
6. último incidente/guardrail relevante;
7. solo entonces ejecutar.

La memoria conversacional es comodidad; GitHub + Supabase son continuidad.