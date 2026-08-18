# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Estado:** CURRENT / control transversal  
**Baseline validada:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Fecha:** 2026-08-17 (America/Lima)  
**Propósito:** impedir que fases, ramas, runners, migraciones o certificaciones de workstreams distintos de ASCENDA OS se mezclen accidentalmente.

---

## 1. Regla de aislamiento

ASCENDA OS comparte repositorio, Railway y Supabase entre varios programas. Compartir infraestructura **no** convierte sus fases en una sola secuencia.

Toda tarea debe declarar un `WORKSTREAM_ID` antes de escribir código, abrir una migración, consumir un runner o cambiar producción.

Namespaces canónicos actuales:

- `CIA-F*` — Commercial Intelligence & Audience OS V3.
- `REV-F*` — Revenue Data & Intelligence Core.
- `WA-*` — ASCENDA Conversations / WhatsApp Revenue Hub.
- `SEN-F*` — Sentinel.
- `K1-*` — KronIA Identity, Session & Secrets Hardening.
- `PARITY-*` — reconciliación transversal Git ↔ Supabase migration history (`#238/#250`).

Una fase se referencia siempre con namespace. Ejemplo correcto: `CIA-F17`; ejemplo prohibido en checkpoints compartidos: `F17` sin proyecto.

---

## 2. Workstream activo de este cierre

**LOCK ACTIVO: `CIA-F17 — SMS / WhatsApp / Future Channels`.**

Estado live revalidado:

- `CIA-F0..F16`: cerradas / `100_COMPLETE` según sus gates.
- `CIA-F16`: `READY_F17_EMAIL_CERTIFIED`, `ready_for_f17=true`, todos sus release gates en true.
- `CIA-F17`: `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`, `ready_for_f18=false`, 4/6 gates.
- Gates F17 ya true: `contracts_active`, `whatsapp_bridge_validated`, `outbound_policy_validated`, `rollback_verified`.
- Gates F17 pendientes: `webhook_replay_validated`, `canary_passed`.
- `CIA-F18`: bloqueada hasta que F17 produzca `READY_F18_MULTICHANNEL_CERTIFIED` / `ready_for_f18=true`.

No iniciar una nueva fase CIA ni declarar F17 cerrada por porcentaje.

---

## 3. CURRENT runtime después de S15.2

PR `#265` fue fusionado en `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`.

Cadena productiva esperada:

`Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4`

El bootstrap `app/server-phase-s-f17.js` inserta F17 antes de F5 sin reemplazar Phase S. `app/server-f17.js` gobierna el envío WhatsApp, webhook, push/notifications y luego continúa hacia `server-f5.js`.

El pending ACL cutover de notificaciones legacy **no** debe ejecutarse antes del smoke live S15.2 definido por el release.

---

## 4. PRs y deuda que no deben confundirse con el cierre CIA-F17

- `#261` — draft F17 creado contra un CURRENT anterior. **No merge as-is.** Debe reabsorber `main@644cb0d...` y conservar únicamente el scope no resuelto por `#265`.
- `#238` — migration-history parity transversal. Es control compartido, no una nueva fase CIA.
- `#250` — baseline fundacional/blank-DB separado de #238.
- Revenue F5 — workstream `REV-F5`, no debe mutar identidad histórica mientras `CIA-F17` está en cierre salvo dependencia explícitamente aprobada.
- WhatsApp Revenue Hub `WA-*` — producto conversacional independiente; sus WA-0..WA-8 no sustituyen CIA-F17 aunque reutilicen gateway, inbox y routing.
- Sentinel `SEN-F1..F13` — baseline cerrada. No reabrir por fallos de otros owners salvo evidencia de regresión Sentinel.
- KronIA `K1-*` — rama/candidato debe reconstruirse desde CURRENT cuando su turno sea habilitado; no mezclar con el cierre CIA-F17.

---

## 5. Política de runners

ASCENDA usa runners self-hosted con funciones distintas. La regla no es “usar más runners a la vez”; la regla es **no cruzar ownership ni mutaciones**.

- `ASCENDA-FAST-*`: sintaxis, contratos runtime/UI y smokes rápidos.
- `ASCENDA-ZERO-COST-V2`: DB efímera, migrations, pgTAP/contratos, seguridad, rollback y releases HIGH/CRITICAL.
- Nunca cambiar a runners GitHub-hosted como fallback por cola/offline.
- `queued/pending` no equivale a fallo.
- Un mismo workstream puede paralelizar pruebas independientes; dos workstreams no deben competir con migraciones/releases mutantes sobre el mismo CURRENT.

### Exclusive mutation lock

Mientras `CIA-F17` esté activo:

1. se permiten auditorías read-only de otros workstreams;
2. se permiten docs/checkpoints de otros workstreams;
3. no se fusionan migraciones/runtime HIGH/CRITICAL de `REV-*`, `WA-*` o `K1-*` sin rebaseline explícito de CIA-F17;
4. cualquier merge externo que avance `main` invalida el exact-head pendiente de CIA-F17 y obliga a revalidarlo contra CURRENT.

---

## 6. Gate obligatorio antes de cambiar de proyecto

No se cambia de workstream hasta capturar:

1. `main` exact SHA;
2. PR activo y estado exact-head;
3. readiness RPC/live gates del workstream;
4. migraciones live relevantes y deuda de parity;
5. rollback/recovery conocido;
6. Notion actualizado;
7. checkpoint GitHub actualizado;
8. runner jobs pendientes identificados;
9. blockers restantes enumerados;
10. siguiente acción única y explícita.

Si falta cualquiera, el workstream queda `PAUSED_WITH_CHECKPOINT`, no “terminado”.

---

## 7. Loop de cierre CIA-F17 desde CURRENT

Orden canónico, fail-closed:

1. Releer `main` y verificar que sigue en el SHA esperado o reabsorber el nuevo CURRENT.
2. Confirmar Railway deploy/runtime S15.2 y `/api/notifications/health` actor-bound.
3. Ejecutar smoke autenticado owner para notificaciones/push requerido por el release antes de ACL cutover.
4. Rebasar/reconstruir el scope útil de `#261` sobre CURRENT; no duplicar lo ya resuelto por `#265`.
5. Certificar webhook Meta real firmado y su replay/idempotencia F17.
6. Ejecutar canary WhatsApp real estrictamente allowlisted y dentro de política/ventana autorizada.
7. Reconciliar ledgers/outcomes; `illegal_send_states=0`; probar rollback/zero-residue.
8. Exigir todos los checks exact-head aplicables en PASS; `SKIPPED`, pending o red no cuentan.
9. Reconsultar `aos_cia_f18_readiness_v1()` y exigir `ready_for_f18=true`.
10. Solo entonces cerrar `CIA-F17` a `100_COMPLETE`, actualizar Notion/memory y desbloquear `CIA-F18`.

---

## 8. Protocolo de recuperación para cualquier agente/chat

Antes de tocar ASCENDA:

1. leer `AGENTS.md`;
2. leer `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. leer **este archivo CURRENT**;
4. declarar `WORKSTREAM_ID`;
5. leer el master/checkpoint CURRENT de ese workstream;
6. verificar GitHub `main`, PRs/checks y Supabase live;
7. confirmar que no existe otro exclusive mutation lock activo;
8. ejecutar únicamente el siguiente gate del workstream elegido.

**Regla final:** GitHub + runtime/Supabase live mandan. Notion y memoria se corrigen después de validar; nunca se usa un checkpoint viejo para sobreescribir CURRENT.
