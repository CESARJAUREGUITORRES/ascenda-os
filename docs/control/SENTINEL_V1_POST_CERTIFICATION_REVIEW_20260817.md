# Sentinel V1 — Post-Certification Review & Maintenance Backlog

**Fecha:** 2026-08-17 (America/Lima)  
**Baseline histórica:** `SENTINEL V1 F1–F13 = 100_COMPLETE` en `main@15de6f0358c53f9088a20d44e579dafae99fa041`  
**CURRENT auditado:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Mantenimiento activo:** `Sentinel V1.1 CURRENT Alignment`

## 1. Decisión principal

Una certificación es **SHA-scoped**, no una promesa eterna de que todo `main` futuro seguirá idéntico.

A partir de V1.1 Sentinel mantiene dos estados independientes:

- `CERTIFIED_BASELINE`: evidencia histórica inmutable de que una versión concreta pasó sus gates.
- `CURRENT_ALIGNED`: evidencia de que los contratos Sentinel siguen representando el `main` vigente.

Una nueva feature de ASCENDA no invalida retrospectivamente la baseline; sí puede mover `CURRENT_ALIGNED` a `DRIFTED/REVALIDATING` hasta que Sentinel absorba la nueva topología.

## 2. Hallazgo que originó V1.1

Tras el cierre V1, S15.2 activó un bootstrap nuevo de Railway:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → server-phase2.js → server.js`

Railway preservó el preload runtime-only de Sentry:

`NODE_OPTIONS='--require ./sentinel-sentry-init.cjs'`

Por tanto, Sentry no estaba caído. Sin embargo, el contrato F4 seguía codificando tres supuestos del snapshot F2 original:

1. `41` HTML públicos;
2. cadena runtime de `8` archivos;
3. entrypoint Railway directo `server-phase-s.js`.

CURRENT tiene `42` HTML porque F13 añadió `admin-sentinel.html`, y S15.2 añadió los boundaries F17. El workflow F4 falló con `F2_PUBLIC_HTML_DRIFT expected=41 actual=42` y bloqueó correctamente el false-green.

## 3. Qué funcionó bien

- La deriva fue detectada automáticamente por un gate antiguo en vez de quedar oculta.
- `UNKNOWN/no false-green` sigue siendo la decisión correcta ante evidencia desactualizada.
- El preload de Sentry está desacoplado del entrypoint concreto y sobrevivió al wrapper F17.
- La separación transport-neutral de F9 permitió que S15/S15.1 evolucionaran el centro general de notificaciones sin convertir Telegram en dependencia.
- `expected-head` + rebase a CURRENT evitó merges sobre snapshots superados durante F13.
- El production smoke de F13 detectó un fallo de infraestructura del runner (`node` ausente en host) y la solución portable con `node:22-alpine` evitó un falso fallo de producto.
- La paridad F13 se reparó por identidad/versionado (`203504`) sin reejecutar DDL ya live.

## 4. Qué debe cambiar permanentemente

### P0 — CURRENT alignment machine-readable

Implementado en V1.1 mediante `sentinel/maintenance/current-alignment-v1.json`. El snapshot F2 V1 permanece histórico; el overlay CURRENT contiene el entrypoint, cadena y superficie pública vigentes.

### P0 — No hardcodear inventarios históricos en gates downstream

Los downstream checks no deben asumir para siempre `41 HTML` o `chain.length=8`. Deben validar contra un contrato CURRENT versionado y fallar cuando ese contrato no corresponda al base SHA del PR.

### P0 — Cross-workstream triggers

Cambios en Railway/bootstrap/F17 o superficies que afectan topología deben volver a disparar F4/F13 aunque no toquen `sentinel/**`. V1.1 amplía estos triggers.

### P1 — Registry generator/digest

Siguiente mejora recomendada: generar el overlay CURRENT desde inventario real y guardar digest de la lista de superficies/runtime. Evita edición manual de contadores y reduce drift silencioso.

### P1 — Estado visible en Sentinel Hub

Mostrar separadamente:

- `Baseline V1: CERTIFIED`
- `CURRENT: ALIGNED | REVALIDATING | DRIFTED`
- `aligned_to_sha`
- `last_revalidated_at`

Esto impide interpretar un certificado histórico como estado vivo del sistema.

### P1 — Freshness de topología

Un registry/overlay demasiado antiguo debe degradar el Hub a `UNKNOWN` y generar hallazgo de mantenimiento antes de que otro workflow falle incidentalmente.

### P1 — Impact map de cambios

Formalizar qué paths externos deben disparar qué regresiones Sentinel. Ejemplo: `app/railway.json`, wrappers runtime y auth/notification boundaries deben relacionarse con F4/F9/F13.

## 5. Estado de las 13 fases después de la auditoría

Las fases **no se reabren retrospectivamente**: F1–F13 siguen `CERTIFIED_BASELINE / 100_COMPLETE` para el SHA certificado.

En CURRENT, V1.1 abrió una revalidación de mantenimiento sobre:

- **F2**: topología histórica correcta como snapshot, pero requiere overlay CURRENT.
- **F4**: sensor Sentry funcional; contrato CURRENT estaba desactualizado y se corrige en V1.1.
- **F9**: S15.1 ya ejecutó `Sentinel F9 In-App Owner Alerts Certificate` con PASS; no hay evidencia de regresión.
- **F13**: debe volver a ejecutar FAST/Linux/DB/production smoke ante cambios de topología/runtime adyacentes; V1.1 amplía sus triggers.

F1/F3/F5–F8/F10–F12 no presentan evidencia actual que obligue a reabrir su certificación. Se mantienen sus invariantes y se revalidan por regresión cuando un path de impacto lo requiera.

## 6. Deudas Sentinel no bloqueantes

1. `F9-T Telegram`: `DEFERRED / NON-BLOCKING`; `ascenda-in-app` sigue siendo el canal owner canónico.
2. Revisar periódicamente índices Sentinel que Supabase marque como `unused_index`; hoy son INFO, no justificación para borrarlos sin evidencia de carga real.
3. Evolucionar el Hub para mostrar baseline/current/freshness.
4. Generar automáticamente el overlay CURRENT y su digest.
5. Añadir política de recertificación por cambio material, no por calendario arbitrario.

## 7. Deudas de ASCENDA que NO deben mezclarse con Sentinel

- Migration-history parity global de otros owners (#238 y sucesores) continúa como control-plane transversal. La paridad específica F13 ya está resuelta.
- Supabase Security Advisor mantiene hallazgos generales fuera de `aos_sentinel_*` (incluida protección de contraseñas filtradas y políticas RLS/permisivas de otros dominios). Deben ir a su workstream de seguridad y no cerrarse desde Sentinel sin ownership/impact report.
- Performance Advisor reporta múltiples recomendaciones de otros dominios; las observaciones Sentinel actuales son INFO sobre índices no usados, no fallos funcionales.
- PR #261 pertenece al cierre F17/runtime y sigue abierto; puede mover nuevamente la topología. V1.1 debe rebasarse/revalidarse si #261 u otro cambio llega a `main` antes del merge.

## 8. Definition of Done de mantenimiento V1.1

V1.1 puede declararse `CURRENT_ALIGNED` solo cuando:

- el overlay coincide con el base SHA exacto;
- F4 CURRENT contract PASS;
- F9 In-App permanece PASS o existe evidencia equivalente posterior al último cambio relevante;
- F13 FAST/Linux/DB/production smoke PASS;
- Ascenda CI PASS;
- Railway conserva health + Sentry preload runtime-only;
- Supabase conserva el boundary F13 y no aparece hallazgo Sentinel-owned material;
- merge se realiza con expected-head sobre CURRENT;
- post-merge read-back confirma `main`, Railway y Supabase;
- Notion se actualiza al final y se verifica por read-back.

## 9. Regla para futuras versiones

El cierre de una baseline ya no será el final del sistema de control. Sentinel se considera un producto operativo con mantenimiento continuo:

`CERTIFY baseline → observe CURRENT → detect drift → revalidate overlay → regress affected phases → merge expected-head → update Hub/Notion`.

Esto preserva tanto la auditabilidad histórica como la verdad técnica actual.