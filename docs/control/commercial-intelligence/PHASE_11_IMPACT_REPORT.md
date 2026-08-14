# ASCENDA OS — FASE 11 IMPACT REPORT

**Fase:** Call Center Integration V3  
**Estado:** IN_PROGRESS / PRE-DDL  
**Fecha:** 2026-08-14 (America/Lima)  
**Riesgo:** CRITICAL  
**Baseline staging:** `76e5b3b609cb52f4b9a0b8c2289dea4a1fca2c64`  
**Input F10:** `aos_cia_advisor_control_f11_readiness_v1()`  
**Hashes routing baseline:**
- `aos_siguiente_lead` = `76412bac81e20ec6cfdc4f8c0db89e8c`
- `aos_siguiente_lead_v2` = `cb69781d1457ed73de8f8d52f0f83a00`

---

## 1. Objetivo

Conectar F8/F9/F10 con el runtime actual del Call Center mediante una ruta V3 **paralela, reversible y canary por asesor**, preservando V2 como fallback inmediato.

Cadena objetivo:

`F8 available_now → F9 assignment lease → F10 readiness → F11 router/claim/consume → F12 Advisor Work Views`

F11 no redefine eligibility ni ownership.

---

## 2. Estado operacional al baseline

- F10 readiness = `READY_NO_ACTIVE_OWNERSHIP`;
- `f11_engineering_ready=true`;
- active advisors = 6;
- active assignment leases = 0;
- assignment plans = 0;
- `aos_leads_en_curso` = 0 al momento del baseline;
- Call Center último 24h = 349 llamadas;
- `calls.js` llama directamente `aos_siguiente_lead_v2`;
- `aos_siguiente_lead_v2` sigue envolviendo la lógica madre `aos_siguiente_lead`.

---

## 3. Arquitectura propuesta

### 3.1 Rollout policy

Nueva configuración privada por `aos_usuarios.id` UUID.

Ausencia de fila = `V2_ONLY`.

Modos permitidos:
- `V2_ONLY` — ruta legacy exclusivamente;
- `V3_CANARY` — intenta V3 y hace fallback automático a V2;
- `V3_PREFERRED` — V3 es ruta principal, fallback V2 permanece habilitado durante F11.

No se permite `V3_NO_FALLBACK` en F11.

### 3.2 Dispatcher público compatible

Nuevo RPC público y contract-compatible con `aos_siguiente_lead_v2`.

Responsabilidades:
1. resolver `codigo_asesor + nombre` contra `aos_usuarios.id` activo/rol asesor;
2. leer rollout mode privado;
3. si V2_ONLY → delegar intacto a `aos_siguiente_lead_v2`;
4. si V3 → validar F10 readiness;
5. seleccionar únicamente leases F9 del asesor con plan ACTIVE + Activation ACTIVE + channel CALL;
6. revalidar disponibilidad F8;
7. respetar claim legacy `aos_leads_en_curso` para no colisionar con V2;
8. priorizar IN_PROGRESS y luego ASSIGNED por deadline/source rank;
9. al entregar ASSIGNED, transicionar a IN_PROGRESS mediante el motor F9;
10. devolver la misma forma base que `aos_siguiente_lead_v2` más metadata `routingV3`;
11. ante cualquier bloqueo/no-work/error V3, fallback a V2 cuando policy lo permita;
12. auditar route selected/fallback reason/latency.

### 3.3 Consume/completion

El POST actual a `aos_llamadas` **no se reemplaza**.

Después de una escritura exitosa de llamada, `calls.js` notificará a un RPC F11 únicamente cuando `CC.lead.assignmentId` exista.

Ese RPC:
- valida que assignment pertenece al `codigo_asesor` activo;
- COMPLETED solo si sigue IN_PROGRESS/ASSIGNED;
- es idempotente para estados terminales;
- no impide que la llamada quede guardada si el ack F11 falla;
- audita el resultado.

Cita confirmada y seguimiento usan el mismo ack después de que sus writes legacy hayan terminado correctamente.

### 3.4 Fallback / rollback

Rollback operativo inmediato:
- cambiar flag a `V2_ONLY` para un asesor;
- o deshabilitar globalmente V3 desde control ADMIN;
- dispatcher vuelve a V2 sin modificar `aos_siguiente_lead*`.

Rollback de código:
- `calls.js` puede volver a invocar `aos_siguiente_lead_v2` directamente.

No se altera la lógica madre V2 durante F11.

---

## 4. Persistencia nueva

Solo objetos CIA F11:

- rollout/config por advisor UUID;
- global kill switch/default mode;
- routing audit/events append-only.

No agregar triggers/índices sobre:
- `aos_llamadas`;
- `aos_leads`;
- `aos_agenda_citas`;
- `aos_ventas`;
- `aos_leads_en_curso`.

`aos_leads_en_curso` solo se usa mediante INSERT/compatibility claim ya existente.

---

## 5. Seguridad

- Config/admin writes únicamente vía CIA ADMIN token/gateway.
- Tablas F11 con RLS deny-by-default y sin policies browser.
- Router público solo acepta advisor activo y par `codigo_asesor + nombre` coherente.
- El browser no puede activar su propio flag.
- Internal functions no deben quedar ejecutables para `anon/authenticated`.
- `SECURITY DEFINER` siempre `search_path=public` y identifiers/acciones whitelisted.
- Payloads/audit limitados; no secretos.

Nota: el Call Center legacy usa anon key + identidad local por `codigo_asesor`; F11 no empeorará ese modelo. Una migración de autenticación corporativa del asesor no forma parte de esta fase.

---

## 6. Semántica de tiempo

- `p_hoy` validado contra `America/Lima`;
- el dispatcher no confiará en `CURRENT_DATE` server para decisiones de clinic-day;
- expiraciones/deadlines usan `timestamptz`/`clock_timestamp()`;
- se probarán fronteras de medianoche Lima.

---

## 7. Anti-scope

F11 NO:
- crea otro Assignment Engine;
- redefine F8 eligibility/availability;
- crea Work Views F12;
- hace rollout global automático;
- elimina `aos_siguiente_lead` ni `aos_siguiente_lead_v2`;
- modifica reglas/tier legacy de V2;
- cambia `aos_cola_config`;
- cambia esquema de `aos_llamadas`;
- convierte routing V3 en única ruta sin fallback.

---

## 8. Plan de QA

### Legacy invariants
- hashes `aos_siguiente_lead*` antes/después idénticos;
- V2 direct contract unchanged;
- calls write-path real PASS.

### V3 rollback-only
- Audience/Activation CALL → F8 available → F9 plan/leases → F10 readiness READY;
- advisor flag V3_CANARY;
- route V3 entrega solo ownership propio;
- ASSIGNED → IN_PROGRESS al claim;
- `aos_leads_en_curso` compatibility claim;
- consume → COMPLETED;
- second consume idempotent;
- unavailable/expired/invalid lease no se entrega;
- another advisor ownership no se entrega;
- no ownership → fallback V2;
- readiness BLOCKED → fallback V2;
- kill switch → V2;
- flag V2_ONLY → V2;
- all QA rollback-only / zero residue.

### Concurrency
- dos requests concurrentes no pueden claimar el mismo assignment;
- GLOBAL ownership permanece único;
- legacy claim conflict evita doble llamada.

### Performance
Targets:
- dispatcher V2_ONLY overhead <100 ms sobre llamada V2 equivalente;
- V3 route normal P95 <1.5 s;
- admin/readiness/audit <1.5 s.

### Frontend
- `calls.js` conserva save legacy primero;
- ack de assignment es best-effort y no rompe guardado;
- loading/error/fallback visual no expone detalles internos;
- 0 `alert/confirm/prompt` nuevos;
- no secretos nuevos.

---

## 9. Output contract hacia F12

F12 recibirá:
- assignment F9 como ownership autoritativo;
- routing audit F11 que demuestra qué assignment fue servido/consumido;
- estados IN_PROGRESS/COMPLETED actualizados desde trabajo real;
- V3 feature rollout observable por advisor UUID;
- V2 fallback preservado.

F12 podrá construir Work Views dentro del ownership sin inferir trabajo desde el historial bruto de llamadas.

---

## 10. Gates F11

- P11-G01 Recovery + F10 handshake
- P11-G02 Legacy routing baseline/hashes
- P11-G03 Impact Report / scope / rollback
- P11-G04 Rollout config + kill switch
- P11-G05 RLS/ACL/admin authorization
- P11-G06 V3 candidate contract from F8/F9
- P11-G07 Advisor identity mapping UUID↔codigo/name
- P11-G08 Claim compatibility with `aos_leads_en_curso`
- P11-G09 Assignment START lifecycle
- P11-G10 Consume/COMPLETE lifecycle + idempotency
- P11-G11 F10 readiness block/fallback
- P11-G12 V2_ONLY + no-ownership fallback
- P11-G13 Concurrency / anti-double-claim
- P11-G14 America/Lima boundary semantics
- P11-G15 Performance
- P11-G16 Frontend dispatcher/ack
- P11-G17 Admin rollout observability/control
- P11-G18 Write-path safety + real Call Center smoke
- P11-G19 Replayability Git↔schema_migrations
- P11-G20 Functional PR/CI/staging smoke
- P11-G21 Validation Report/Roadmap/aos_memory/Notion
- P11-G22 F11→F12 output handshake

**F11 solo puede ser `100_COMPLETE` con P11-G01..G22 PASS.**
