# ASCENDA OS — FASE 3 · PRODUCTO CANÓNICO — CERTIFICACIÓN PRODUCTIVA

**Estado:** `PRODUCTION CERTIFIED — 100%`  
**Fecha:** 2026-08-14  
**Alcance certificado:** Fase 3 — identidad canónica de producto, aliases, hechos físicos por venta, backfill y resolución automática fail-closed.  
**No implica:** certificación global de todos los módulos de ASCENDA OS.  

Este documento es la evidencia de cierre de Fase 3 y **supera el estado PREPRODUCTION** indicado en `PHASE3_PRODUCT_CANONICAL_IMPACT_20260814.md`. El Impact Report sigue siendo válido para diseño/riesgos; este archivo es la fuente posterior para el estado de release.

## 1. Código y gate exacto

- PR de implementación: `#106 — Phase 3: canonical product identity + owner reconciliation`.
- Candidate SHA certificado por CI: `a3d4ff008da35bf5eba316f00aae903239fe2b3a`.
- Base CURRENT certificada: `c8b71d2d10aa913b81044ba58e8d09674cbe7ab3` (Zero-Cost CI V2).
- Merge productivo F3: `9c62d2a15d752e18d05c886c855fd51ca26b6a92`.
- GitHub Actions run F3: `31839315450`.
- Job: `94892540889 — product-canonical-contract`.
- Resultado: `SUCCESS`.
- Runner: `ASCENDA-ZERO-COST-V2` (`self-hosted`, `Linux`, `X64`, `ascenda-zero-cost-v2`).
- Contrato F3: **34/34 pgTAP assertions**, DB lint, exact migration chain y recovery contract verdes.
- Paid hosted runner fallback: ninguno.

## 2. Fuente privada auditada

La fuente propietaria `Clientes_Productos 2026.xlsx` fue auditada sin publicar PII en GitHub.

Baseline certificada:

- 394/394 IDs del workbook existentes en producción;
- 388 hechos de producto resueltos;
- 6 exclusiones owner-confirmed;
- 418 unidades físicas;
- 43 filas promo/pack;
- 51 identidades de producto F3 representadas;
- las 394 decisiones owner-confirmed quedan `locked=true`;
- evidencia histórica `aos_ventas.descripcion` preservada.

Correcciones owner-confirmed protegidas:

- venta 909 → `PERFECT FORM B 90GR`;
- venta 1644 → `LYNDHARIAL GOTAS`;
- venta 1632 → cantidad física `0` por pago fraccionado;
- venta 1638 → cantidad física `0` por pago fraccionado.

## 3. Migraciones productivas aplicadas

Supabase producción `ituyqwstonmhnfshnaqz` registró:

1. `20260814211841` — `phase3_product_canonical_schema_v1`;
2. `20260814211944` — `phase3_product_owner_seed_v1`;
3. `20260814212007` — `phase3_product_catalog_identity_unify_v1`;
4. `20260814212023` — `phase3_product_existing_backfill_v1`.

La cadena fue aplicada en ese orden después de CI verde y preflight productivo read-only.

## 4. Smoke productivo post-cutover

Resultado observado inmediatamente después del cutover:

### Hechos owner-confirmed

- owner facts: `394`;
- `RESOLVED`: `388`;
- `EXCLUDED`: `6`;
- physical units: `418`;
- promo/pack rows: `43`;
- locked owner facts: `394`;
- owner canonical products represented: `51`.

### Cobertura viva

- ventas dentro del resolver productivo: `395`;
- hechos F3 totales: `395`;
- filas desbloqueadas: `1`;
- `REVIEW_REQUIRED`: `0` al cierre;
- review queue: `0` al cierre.

La única venta posterior al workbook en ese corte es `sale_id=2340`, descripción histórica `LIFTIN B`. F3 la resolvió automáticamente a:

- `product_key = F3:LIFTINGB30GR`;
- canonical name = `LIFTING B 30GR`;
- physical_qty = `1`;
- resolution source = `AUTO_ALIAS_V2`;
- resolution status = `RESOLVED`;
- `aos_ventas.descripcion` permanece `LIFTIN B`.

No quedó identidad genérica CAT duplicada para el vínculo one-to-one de Lifting B.

## 5. Identidades y catálogo

- identidades owner F3: `51`;
- `LEGACY`: `8`;
- `CURRENT_UNCATALOGED`: `3`;
- identidades totales incluyendo catálogo operativo: `91`;
- productos activos existentes en catálogo: `54`;
- aliases F3 owner materializados desde descripciones vivas: `171`;
- aliases activos totales F3/CIA incorporados: `241`.

Los tres `CURRENT_UNCATALOGED` permanecen deliberadamente fuera de una alta comercial automática porque F3 certifica identidad, no inventa precio/categoría:

- `FOTOPROTECTOR OIL CONTROL FUSION WATER 50 ML-ISDIN`;
- `POWER 10 HONEYDEW FAIRY 30 ML`;
- `SENSITONIC`.

Su identidad ya es estable. Una alta comercial futura debe conservar la misma identidad y utilizar precio/categoría aprobados por negocio.

## 6. Seguridad certificada

Post-cutover:

- RLS activo en `aos_product_identity_v1`, `aos_product_alias_v2`, `aos_product_sale_fact_v1`;
- `anon` no puede leer identity/facts/review queue;
- `authenticated` no puede actualizar facts;
- `anon` no puede ejecutar `aos_product_resolve_sale_v1(bigint)`;
- `authenticated` no puede ejecutar `aos_product_backfill_unlocked_v1()`;
- trigger `trg_aos_product_sync_sale_v1` activo;
- desconocidos fallan cerrado a `REVIEW_REQUIRED` en vez de inventar producto;
- no se incorporó PII del workbook a GitHub ni a las tablas F3.

## 7. Integridad de evidencia

El smoke confirmó sin cambios las descripciones históricas críticas:

- 909: `PERFECT- B 90GR`;
- 1632: `GOTAS LYNDHARIAL`;
- 1638: `2DO PARTE SERUM LIFTING B`;
- 1644: `LYMDHARIAL GOTAS`;
- 2340: `LIFTIN B`.

La arquitectura F3 agrega interpretación canónica; no reescribe la evidencia transaccional original.

## 8. Recovery

Recovery certificado:

`supabase/rollbacks/20260814200600_phase3_product_recovery.sql`

Su efecto es fail-closed:

- elimina el trigger automático;
- revoca resolver/backfill operativo;
- mantiene las ventas históricas intactas;
- conserva las tablas/vistas F3 como evidencia read-only para `service_role`;
- no restaura permisos débiles ni modifica Auth, Caja, Cartera o pacientes.

## 9. Cierre

Todos los gates definidos para el alcance F3 quedaron satisfechos:

`SOURCE AUDIT → IMPACT → ISOLATED BUILD → ZERO-COST CI → READ-ONLY PREFLIGHT → OWNER AUTHORIZATION → MERGE → ADDITIVE CUTOVER → BACKFILL → SECURITY SMOKE → EVIDENCE PRESERVATION → RECOVERY`.

**Resultado formal:** `FASE 3 — PRODUCTO CANÓNICO — PRODUCTION CERTIFIED — 100%`.
