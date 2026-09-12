# Sentinel V1.1 — CURRENT Alignment Impact Report

**Estado:** OPEN / FAIL-CLOSED  
**Fecha:** 2026-08-17 (America/Lima)  
**Riesgo:** HIGH  
**Base histórica certificada:** `main@15de6f0358c53f9088a20d44e579dafae99fa041`  
**CURRENT al abrir mantenimiento:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Branch:** `fix/sentinel-v11-current-alignment-20260817`

## Motivo

Sentinel V1 quedó correctamente certificado en su SHA histórico, pero ASCENDA siguió evolucionando después del cierre. S15.2 activó `server-phase-s-f17.js` como nuevo bootstrap productivo de Railway, preservando el preload de Sentry y añadiendo F17 a la cadena runtime. Además, F13 había añadido `app/public/admin-sentinel.html` después del snapshot F2 original.

La regresión F4 en CURRENT detectó esta deriva con `F2_PUBLIC_HTML_DRIFT expected=41 actual=42`. La investigación confirmó que no existe caída funcional de Sentry: Railway conserva `NODE_OPTIONS='--require ./sentinel-sentry-init.cjs'`; el problema es un contrato F2/F4 congelado con supuestos históricos (`41 HTML`, `chain.length===8`, entrypoint directo `server-phase-s.js`).

## Decisión arquitectónica

No se reescribe ni invalida retrospectivamente la certificación V1. Se separan dos dimensiones:

1. `CERTIFIED_BASELINE` — evidencia histórica inmutable por SHA.
2. `CURRENT_ALIGNED` — revalidación continua contra el `main` vigente.

V1.1 añadirá un overlay machine-readable de alineación CURRENT y eliminará hardcodes topológicos del contrato F4. Los checks deberán fallar cuando CURRENT derive de ese overlay, no cuando cambie un número legítimamente por evolución del sistema.

## Scope permitido

- crear contrato/overlay CURRENT V1.1;
- actualizar F4 contract para el entrypoint productivo actual manteniendo privacy/cost/kill-switch;
- actualizar el test F4 para validar runtime/current overlay en lugar de números históricos;
- documentar aprendizajes post-certificación y backlog de mantenimiento;
- ejecutar F2/F4/F9/F13 + Ascenda CI cuando corresponda;
- actualizar Notion únicamente después de evidencia GitHub/runtime.

## Anti-scope

- no DDL productivo;
- no cambios a datos clínicos/comerciales;
- no cambios de secretos/DSN;
- no activar tracing, logs, replay ni pay-as-you-go;
- no auto-remediation, auto-merge ni auto-deploy;
- no cerrar deuda de seguridad/performance de otros workstreams dentro de Sentinel;
- no maquillar migration-history global.

## Gates

- G01 CURRENT exacto antes de mutación — PASS al abrir sobre `644cb0d0...`.
- G02 confirmar Sentry preload preservado en Railway — PASS.
- G03 clasificar F4 failure como contract drift, no sensor outage — PASS.
- G04 overlay CURRENT machine-readable y fail-closed.
- G05 F4 sin hardcodes de `41`, `8` ni entrypoint histórico.
- G06 F2 registry baseline preservado como evidencia histórica.
- G07 F4 FAST + production canary según configuración.
- G08 F9 regression por vecindad notifications/auth.
- G09 F13 regression/topology privacy/no-false-green.
- G10 Ascenda CI.
- G11 exact-head / merge-ref / expected-head.
- G12 post-merge read-back Railway/Supabase.
- G13 Notion last + read-back.

## Rollback

Esta fase no requiere DDL. El rollback es revertir los archivos de contrato/documentación V1.1; la cadena productiva S15.2 no se modifica. Si cualquier gate técnico demuestra que Sentry dejó de instrumentar el runtime actual, V1.1 queda abierta y la alineación CURRENT se marca `DRIFTED`, nunca `GREEN` por documentación.