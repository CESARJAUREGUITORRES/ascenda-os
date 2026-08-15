# ASCENDA OS — F4 Revenue Operations Integration V1 — CURRENT Checkpoint

**Estado:** `IN_PROGRESS / BUILD COMPLETE / ZERO-COST CI GATE`  
**Actualizado:** 2026-08-14  
**Branch:** `feature/f4-revenue-operations-v1-20260814`  
**PR:** `#110`  
**Head al entrar al gate:** consultar PR/checks exact-SHA; no usar este valor como sustituto de GitHub live.

## Input contract

- F3 Producto Canónico certificado en producción.
- `aos_product_identity_v1`, `aos_product_alias_v2`, `aos_product_sale_fact_v1` disponibles live.
- F4 roadmap canónico: `docs/control/REVENUE_DATA_INTELLIGENCE_ROADMAP_CURRENT.md`.
- Impact Report: `docs/control/F4_REVENUE_OPERATIONS_IMPACT_20260814.md`.

## Baseline live previa al cutover

- Producto facts: 395 total / 389 resolved / 6 excluded / 0 review / 419 unidades.
- Ventas: 1,279 total en el corte de diseño; producción puede crecer normalmente durante el gate.
- Cartera: 162 activos / sin auto-conversión de ADELANTO a deuda en el corte.
- `aos_pagos`: no se considera ledger histórico completo; F4 jamás crea un pago al reconciliar evidencia.

## Hallazgos resueltos por el build

1. **Top Productos:** deja de depender de `descripcion` + aliases hardcodeados como autoridad y recibe identidad F3, ventas, facturación, unidades físicas, packs y cobertura.
2. **Detalle Ventas:** conserva descripción raw y añade producto canónico/resolution metadata.
3. **Edición Ventas:** nuevo `aos_editar_venta_v4` exige sesión Auth V3 + 2FA + `admin-sales`, actor server-side, sede válida, whitelist y optimistic lock.
4. **Importar:** preview read-only + batch/idempotency visibility + resolución de productos + adelantos + posible coincidencia previa; commit por `aos_importar_ventas_v4` tokenizado.
5. **Caja venta:** `aos_grabar_venta_caja_v4` exige 2FA + `admin-caja`, actor server-side, sede/sesión y montos válidos.
6. **Cartera:** `aos_cartera_candidates_v2` propone evidencia sin mutar; `aos_cartera_reconcile_v2` exige evidencia para `PAGO_RECONCILIADO`, conserva optimistic lock y verifica que no se cree ningún `aos_pagos`.
7. **KronIA financiero:** front proxy F4 exige `X-AOS-App-Token` fuerte para confirmar edición de venta; una sesión legacy sin prueba fuerte falla cerrado.
8. **Runtime UI:** Service Worker inyecta el bridge F4 en `/app` sin reescribir la estructura operativa de Ventas/Cartera.
9. **Cutover:** migración separada preparada para revocar execute público de `aos_editar_venta`, `aos_importar_ventas`, `aos_grabar_venta_caja` y `aos_cartera_reconcile` solo después de deploy/canary.
10. **Recovery:** fail-closed; nunca restaura writes legacy débiles.

## Artefactos del release

- `supabase/migrations/20260814223000_f4_revenue_operations_core_v1.sql`
- `supabase/migrations/20260814223100_f4_cartera_candidates_v2.sql`
- `supabase/migrations/20260814223900_f4_revenue_operations_cutover.sql`
- `supabase/rollbacks/20260814223900_f4_revenue_operations_recovery.sql`
- `app/public/f4-revenue-ops.js`
- `app/public/f4-kronia-revenue-bridge.js`
- `app/server-f4.js`
- `app/public/phase2-service-worker.js`
- `ci/phase4-revenue/schema_contract.sql`
- `ci/phase4-revenue/tests/001_revenue_operations.sql`
- `ci/phase4-revenue/ui_contract.py`
- `.github/workflows/phase4-revenue-operations.yml`

## CI / Definition of Done pendiente

El build no autoriza producción por sí mismo. Para cerrar F4 deben pasar, sobre el SHA exacto:

1. Runtime syntax + UI contract.
2. Supabase efímero Zero-Cost.
3. Exact additive migrations replayables.
4. DB lint.
5. 38 pgTAP F4.
6. Cutover ACL contract.
7. Recovery fail-closed.
8. Ascenda CI + Zero-Cost baseline sin regresión.
9. Preflight read-only de producción.
10. Merge/deploy Railway exact-SHA.
11. Aplicación additive core.
12. Owner canary Ventas + Importar preview + Cartera candidates + Caja no-mutating navigation.
13. Aplicación de cutover ACL.
14. Post-deploy smoke: no ventas/pagos ficticios, F3 intacta, Cartera sin deuda automática, legacy writes cerrados.
15. Validation Report + Notion CURRENT.

## Seguridad / deuda explícita no bloqueante

Los legacy **read-only** `aos_ventas_admin*` continúan disponibles temporalmente porque el contexto KronIA legacy todavía los consume. F4 elimina su uso como autoridad en Ventas Admin y cierra los mutation paths de revenue. La migración del contexto read-only de KronIA queda para el workstream Intelligence/KronIA; no se falseará como deuda resuelta en F4.

## Anti-scope

F5 históricos/pacientes no empieza hasta F4 certificado. F6 BI avanzado y F7 automatización permanecen fuera de F4.

## Next exact action

**Esperar/inspeccionar Zero-Cost CI exact-SHA de PR #110; corregir cualquier fallo; después ejecutar production read-only preflight.**
