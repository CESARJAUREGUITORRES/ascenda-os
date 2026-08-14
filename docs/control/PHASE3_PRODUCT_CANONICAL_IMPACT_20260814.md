# ASCENDA OS — FASE 3 · PRODUCTO CANÓNICO

**Estado:** BUILD / PREPRODUCTION ONLY  
**Fecha:** 2026-08-14  
**Rama:** `feature/phase3-product-canonical-20260814`  
**Base CI:** `infra/zero-cost-ci-v2` hasta que PR #97 cierre y se sincronice con `main`  
**Riesgo:** HIGH — identidad comercial de producto, importaciones de ventas, analítica e inventario.  
**Autorización owner:** 2026-08-14 — “procede para llegar al 100%”, válida para completar el loop gobernado F3 una vez que los gates exigidos estén verdes; no habilita bypass de CI, seguridad o rollback.  

## Objetivo

Construir una capa canónica y reproducible de producto sin destruir evidencia histórica. La columna `aos_ventas.descripcion` permanece intacta. Fase 3 debe resolver qué producto fue vendido, cuántas unidades físicas representa la venta y si fue promo/pack, y debe aplicar esa lógica a futuras importaciones.

## Fuente de verdad aprobada

El archivo privado `Clientes_Productos 2026.xlsx` fue cotejado con producción sin publicar PII en GitHub.

Auditoría al corte del archivo:

- 394/394 `N° REGISTRO` existen en `aos_ventas`;
- 388 filas contienen producto canónico confirmado;
- 6 filas quedan expresamente `EXCLUIDO / SIN PRODUCTO` y no se inferirá identidad automáticamente;
- 418 unidades físicas después de corregir pagos fraccionados;
- 43 filas marcadas promo/pack;
- 51 nombres canónicos distintos;
- 167 aliases históricos de producto sin conflicto después de correcciones;
- producción ya contiene una venta posterior al corte del Excel (13/08/2026, `sale_id=2340`, `LIFTIN B`), que debe resolverse por la lógica futura y no por el seed histórico.

## Correcciones de integración detectadas

El Excel conserva la evidencia original, pero cuatro celdas necesitan corrección lógica antes de convertirse en contrato de datos:

1. venta `909`: `PERFECT- B 90GR` debe mapear a `PERFECT FORM B 90GR`, no a F;
2. venta `1644`: `LYMDHARIAL GOTAS` debe mapear a `LYNDHARIAL GOTAS`, no a Hydrashield;
3. venta `1632`: cantidad física = `0`; es segundo pago del mismo producto de la venta `1631`;
4. venta `1638`: cantidad física = `0`; es segundo pago del mismo producto de la venta `1637`.

Estas correcciones producen el total físico coherente de **418 unidades**.

## Estado productivo verificado

Producción tiene actualmente:

- `aos_catalogo_servicios`: 54 productos ACTIVOS y 167 servicios ACTIVOS;
- `aos_product_alias_overrides`: 42 aliases explícitos;
- `aos_cia_product_catalog_alias_v1`: view de aliases catálogo/overrides;
- `aos_cia_product_sale_reconciliation_v1`: conciliación derivada de producto;
- estado de conciliación actual: 130 `CATALOG_EXACT`, 140 `EXPLICIT_ALIAS`, 123 `UNKNOWN`;
- `aos_importar_ventas(jsonb)` clasifica la fila como PRODUCTO/SERVICIO, pero no persiste identidad canónica, unidades físicas ni promo/pack.

## Arquitectura F3

### 1. Identidad de producto

Nueva capa `aos_product_identity_v1`:

- identidad canónica estable;
- vínculo opcional al catálogo activo;
- estado de ciclo de vida: `CATALOG`, `CURRENT_UNCATALOGED`, `LEGACY`, `REVIEW`;
- no obliga a introducir productos históricos en el catálogo operativo actual.

### 2. Alias

Nueva capa `aos_product_alias_v2`:

- alias normalizado/raw → identidad canónica;
- fuente y confianza;
- cantidad por defecto solo cuando sea inequívoca;
- un alias ambiguo nunca fabrica cantidad ni producto.

### 3. Hecho de producto por venta

Nueva capa `aos_product_sale_fact_v1` + vistas sanitizadas:

- `sale_id` único;
- identidad canónica opcional;
- cantidad física;
- promo/pack;
- estado de resolución;
- fuente de evidencia;
- `aos_product_review_queue_v1` para descripciones desconocidas sin PII de identidad.

Los 394 registros del Excel se sembrarán solo mediante IDs y metadatos de producto. **No se copiarán nombres, teléfonos, DNI ni otra PII al repositorio.**

### 4. Futuras importaciones y ventas ya posteriores al Excel

El resolver F3 se ejecutará después de INSERT/UPDATE de una venta PRODUCTO:

- conserva siempre `aos_ventas.descripcion`;
- primero respeta revisión explícita por venta;
- luego alias confirmado;
- si no hay certeza, genera `REVIEW_REQUIRED` en vez de inventar;
- no modifica monto, pago, paciente, asesor, sede ni identidad del cliente.

Después del seed propietario se ejecuta un backfill controlado únicamente sobre filas no bloqueadas. Esto permite que ventas que llegaron después del Excel —incluida `2340 / LIFTIN B`— se resuelvan con la misma lógica canónica sin editar la evidencia histórica.

## Catálogo: criterio de incorporación

No todo nombre histórico debe convertirse en producto activo. Se distinguen:

- `CATALOG`: ya existe un producto activo equivalente;
- `CURRENT_UNCATALOGED`: existe evidencia de producto de venta actual pero falta alta canónica de catálogo;
- `LEGACY`: producto histórico sin evidencia suficiente de vigencia actual;
- `REVIEW`: identidad no suficientemente determinada.

Los productos `CURRENT_UNCATALOGED` quedan plenamente identificados por F3 sin forzar precio/categoría operativa no confirmados. Su eventual alta comercial en catálogo debe conservar la misma `product_key` y realizarse mediante migración aditiva gobernada, no inventando precios desde ventas promocionales.

## Seguridad / ACL

- RLS ON en nuevas tablas;
- cero escritura directa `anon` / `authenticated`;
- resolver interno `SECURITY DEFINER` con `search_path=''`;
- ninguna PII nueva en tablas F3;
- no reabrir escrituras directas cerradas en Fase 2;
- rollback debe desactivar resolución automática sin tocar ventas históricas.

## Zero-Cost CI V2

Todo workflow F3 debe ejecutar exclusivamente:

`runs-on: [self-hosted, Linux, X64, ascenda-zero-cost-v2]`

No existe fallback a `ubuntu-latest`, `windows-latest` o `macos-*`.

Gates mínimos:

- schema/ACL/RLS;
- resolver determinista;
- seed 394 IDs sin PII;
- 388 PRODUCT / 6 EXCLUDED / 418 unidades / 43 promo-pack / 51 canónicos;
- 0 conflictos alias→canónico;
- split-payments no duplican unidades;
- venta real post-corte `2340 / LIFTIN B` se resuelve por backfill a `LIFTING B 30GR`;
- nuevas ventas `LIFTIN B` se resuelven por trigger;
- desconocidos quedan `REVIEW_REQUIRED` y aparecen en review queue;
- `aos_ventas.descripcion` no cambia;
- recovery preserva seguridad y ventas;
- contrato dedicado actual: 33 assertions pgTAP.

## Rollback / recovery

El rollback F3:

1. revoca ejecución del resolver F3 y elimina su trigger;
2. mantiene intactos `aos_ventas`, catálogo, caja y pacientes;
3. conserva la capa de hechos F3 como evidencia, sin usarla operativamente;
4. nunca restaura rutas débiles de escritura o Auth.

## Gate de producción

No aplicar F3 a producción hasta que:

1. PR #97 Zero-Cost CI V2 esté cerrado/sincronizado;
2. el branch F3 esté sincronizado con `main` CURRENT;
3. CI F3 completo esté verde en un SHA exacto;
4. preflight productivo read-only confirme ausencia de drift crítico;
5. se prepare migración/recovery exactos;
6. canary y post-deploy smoke prueben resolución sin modificar evidencia histórica.

Hasta entonces F3 es **PREPRODUCTION BUILD**, no `100%` ni `PRODUCTION CERTIFIED`.
