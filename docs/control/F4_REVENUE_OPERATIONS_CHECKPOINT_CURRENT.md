# ASCENDA OS — F4 Revenue Operations Integration V1 — CURRENT Checkpoint

**Estado:** `IN_PROGRESS / IMPACT COMPLETE / IMPLEMENTATION NOT STARTED`  
**Actualizado:** 2026-08-14  
**Branch:** `feature/f4-revenue-operations-v1-20260814`  
**Base:** `main@1fbcb4ebc2573c7f6a5e84f9c4d83176d89f20e4`

## Input contract

- F3 Producto Canónico certificado en producción.
- `aos_product_identity_v1`, `aos_product_alias_v2`, `aos_product_sale_fact_v1` disponibles live.
- F4 roadmap canónico: `docs/control/REVENUE_DATA_INTELLIGENCE_ROADMAP_CURRENT.md`.
- Impact Report: `docs/control/F4_REVENUE_OPERATIONS_IMPACT_20260814.md`.

## Baseline live

- Producto facts: 395 total / 389 resolved / 6 excluded / 0 review / 419 unidades.
- Ventas: 1,279 total / 394 tipo PRODUCTO / 123 ADELANTO.
- Cartera: 162 activos / 162 pendientes / 0 saldo confirmado / 0 reconciliado en el corte.
- `aos_pagos`: 1 fila; no representa ledger histórico completo.

## Hallazgos bloqueantes incorporados

1. Ventas Admin todavía construye Top Productos desde `descripcion` + aliases hardcodeados en frontend; no usa F3.
2. Cartera backend acepta enlace a cotización, pero UI actual envía `p_cotizacion_id=null`; falta candidate/link workflow.
3. Importar sigue siendo canal principal y debe tener paridad con Caja.
4. Write-path legacy de Ventas/Importar/Caja contiene RPC ejecutables por roles públicos; F4 debe migrarlos progresivamente a gateways tokenizados antes de revocar legacy.

## Orden de implementación

### Block 1 — Contracts & Security Boundary
- inventariar todos los callers de Ventas Admin / Importar / Caja;
- diseñar gateway read-only `admin-sales`;
- diseñar wrappers de write tokenizados;
- negative authorization contract;
- no revocar legacy todavía.

### Block 2 — Canonical Product Read Model
- agregación canónica por product_key/name;
- facturación + ventas + physical_qty + packs;
- detalle raw + canonical;
- coverage/review metric.

### Block 3 — Ventas Admin UI
- reemplazar `canonProductName()` como autoridad;
- Top Productos canónico;
- unidades reales;
- error/loading/coverage;
- preparar selector canónico para alta/edición compatible.

### Block 4 — Importar parity
- preview determinístico;
- idempotency visible;
- producto resolution output;
- Cartera cases output;
- gateway seguro.

### Block 5 — Cartera Reconciliation V2
- read-only candidate engine;
- human link de evidencia existente;
- no duplicate payment;
- audit + optimistic lock;
- UI de candidatos/timeline.

### Block 6 — Cutover
- Zero-Cost CI V2;
- production preflight;
- additive deploy;
- owner canary;
- consumer parity;
- revoke legacy writes solo al final;
- post-deploy smoke + recovery + certification.

## Anti-scope

F5 históricos/pacientes no empieza hasta F4 certificado. F6 BI avanzado y F7 automatización permanecen fuera de F4.

## Next exact action

**Crear contratos sintéticos F4 + inventario de consumers y empezar Block 1 en esta misma branch.**
