# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Estado:** CURRENT  
**Baseline:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Fecha:** 2026-08-17 America/Lima

Este archivo complementa `AGENTS.md` y corrige cualquier checkpoint genérico que haya quedado atrás respecto del runtime CURRENT.

## Lectura obligatoria antes de escribir

1. `AGENTS.md`
2. `docs/control/ASCENDA_CONTROL_MASTER.md`
3. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
4. master/checkpoint CURRENT del workstream elegido
5. `SECURITY.md` si el scope toca Auth/RLS/secrets/agents/infra
6. `app/railway.json` y los archivos runtime realmente encadenados
7. Supabase live/readiness correspondiente

## Runtime CURRENT

El outer entrypoint Railway CURRENT ya no debe inferirse desde documentación histórica.

En `main@644cb0d...` el deploy S15.2 arranca mediante:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js`

Por tanto:

- `app/server.js` sigue siendo parte de la aplicación/lineage, pero no debe asumirse automáticamente como outer entrypoint de Railway.
- antes de cualquier cambio runtime, releer `app/railway.json` en CURRENT;
- no modificar un sibling/legacy suponiendo que está cargado por producción;
- cualquier avance de `main` invalida un exact-head pendiente hasta revalidación.

## Workstream lock CURRENT

Workstream activo: **`CIA-F17`**.

Hasta cerrar sus seis gates:

- `REV-*`, `WA-*`, `K1-*`: lectura, auditoría y docs permitidas; runtime/migrations HIGH/CRITICAL pausados salvo dependencia explícita;
- `SEN-F1..F13`: cerrado; no reabrir sin regresión real;
- `PARITY-*`: control transversal permitido, pero no debe reescribir ownership funcional ni replayar DDL productiva para maquillar historia.

## CIA-F17 CURRENT

- F16 input: `READY_F17_EMAIL_CERTIFIED`, `ready_for_f17=true`.
- F17: `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`, `ready_for_f18=false`.
- true: contracts, WhatsApp bridge, outbound policy, rollback.
- pending: signed webhook replay/idempotency + real allowlisted canary.
- PR #265 ya está MERGED en CURRENT y resolvió el bypass de F17 en Railway.
- PR #261 fue construido sobre un CURRENT anterior: **no merge as-is**; reconstruir/rebasar y conservar solo deuda todavía válida.
- F18 permanece bloqueada.

## Regla de certificación

Nunca declarar `100_COMPLETE` por porcentaje, por UI visual o por un CI aislado. Requiere el Definition of Done de `AGENTS.md`, readiness live, exact-head, seguridad, rollback/recovery, smoke/canary cuando aplique y checkpoint final GitHub + Supabase + Notion.
