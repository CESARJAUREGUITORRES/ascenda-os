# ASCENDA OS — F4 Revenue Operations Integration V1 — Impact Report

**Estado:** CURRENT / PRE-IMPLEMENTATION  
**Fecha:** 2026-08-14  
**Rama:** `feature/f4-revenue-operations-v1-20260814`  
**Base:** `main@1fbcb4ebc2573c7f6a5e84f9c4d83176d89f20e4`  
**Riesgo:** HIGH con sub-bloque CRITICAL de autorización de writes  
**Predecesor:** F3 Producto Canónico — `PRODUCTION CERTIFIED — 100%`

## 1. Objetivo

Integrar la verdad canónica de producto de F3 en la operación diaria y cerrar la brecha entre **venta registrada**, **producto real**, **pago existente**, **saldo real** e **importación Excel**, sin reescribir evidencia histórica ni crear pagos duplicados.

F4 no importa todavía años históricos. Esa carga queda preservada como F5, una vez estabilizados estos contratos.

## 2. Baseline live verificada

### Producto F3
- 395 hechos actuales en `aos_product_sale_fact_v1`.
- 389 `RESOLVED`.
- 6 `EXCLUDED`.
- 0 `REVIEW_REQUIRED` actualmente.
- 419 unidades físicas resueltas.
- 43 registros promo/pack.
- Venta post-workbook `sale_id=2340` resuelta como `F3:LIFTINGB30GR` con cantidad física 1.

### Ventas / pagos / cartera
- `aos_ventas`: 1,279 filas.
- 394 filas actualmente tipadas `PRODUCTO`.
- 123 filas con `estado_pago=ADELANTO`.
- 0 ventas actuales con `cotizacion_id` poblado.
- `aos_pagos`: 1 fila; 1 ligada a cotización. La evidencia histórica de cobro no vive principalmente en `aos_pagos`.
- `aos_cartera_reconciliacion`: 162 casos activos; 162 pendientes; 0 saldo confirmado; 0 reconciliados; S/0 confirmado para cobranza en este corte.

**Conclusión:** F4 no puede diseñar matching suponiendo que `aos_pagos` sea un ledger histórico completo. Debe considerar `aos_ventas`, cotizaciones y evidencia posterior existente, manteniendo la diferencia entre pago y deuda.

## 3. Hallazgo A — Ventas Admin no consume F3 todavía

`app/public/admin-sales.html` sigue construyendo `Top Productos` en el navegador a partir de `aos_ventas.descripcion` y una función hardcodeada `canonProductName()` con un conjunto parcial de aliases.

La propia UI declara que muestra **ventas, no unidades físicas**.

### Riesgo
- variantes no previstas pueden fragmentar rankings;
- el frontend duplica una lógica que F3 ya resolvió de forma gobernada en DB;
- las unidades reales, packs y estado de resolución no llegan al panel;
- un cambio futuro de aliases exigiría editar frontend en vez de actualizar una dimensión gobernada.

### Decisión F4
Eliminar la función ad-hoc como fuente de verdad. Crear un read-model/RPC token-gated que una:

`aos_ventas → aos_product_sale_fact_v1 → aos_product_identity_v1`.

Debe devolver por producto canónico:
- `product_key`;
- `canonical_name`;
- número de líneas/ventas;
- facturación;
- unidades físicas;
- promo/pack;
- sede;
- asesor;
- estado de pago;
- coverage/resolution status.

El monto continúa procediendo de la venta original; la identidad y cantidad proceden de F3.

## 4. Hallazgo B — Venta manual debe seleccionar catálogo, no depender de spelling

F3 ya resuelve aliases después del INSERT/UPDATE de `aos_ventas`, pero el mejor control es prevenir errores cuando la venta nace manualmente.

### Decisión F4
- Para producto/servicio manual, preferir selector desde catálogo/identidad canónica.
- Mantener texto libre solo donde sea necesario como evidencia/nota.
- Si el catálogo tiene una relación F3 uno-a-uno, guardar el nombre canónico estable.
- Si existen variantes ambiguas, obligar a seleccionar variante; no colapsar automáticamente.
- Las importaciones legacy siguen usando aliases F3.
- Alias desconocido → `REVIEW_REQUIRED`, nunca inferencia silenciosa.

## 5. Hallazgo C — Importar es un write-path principal y debe ser first-class

`aos_importar_ventas` ya implementa idempotencia por lote exacto y escribe en `aos_ventas`. Con el trigger F3, nuevas filas de producto pueden resolver su identidad automáticamente.

Sin embargo, el sistema sigue usando Importar como canal operativo relevante; no se puede construir lógica que funcione solo desde Caja.

### Contrato F4
Caja e Importar deben converger en:
1. `aos_ventas` como evidencia transaccional;
2. resolver F3 para producto;
3. bridge Cartera cuando `estado_pago=ADELANTO`;
4. mismas reglas de auditoría/calidad.

Debe existir preview previo a importación con:
- total de filas;
- periodo/sede;
- monto total;
- duplicados previstos;
- productos `RESOLVED / REVIEW_REQUIRED` cuando sea determinable;
- advertencias de identidad/reconciliación;
- hash/idempotency key.

## 6. Hallazgo D — Cartera tiene motor de enlace, pero UI incompleta

`aos_cartera_reconcile(...)` ya acepta `p_cotizacion_id` para asociar un caso de venta a una cotización, implementa optimistic locking por `updated_at`, valida sede/identidad y registra before/after en `aos_security_log`.

Pero `app/public/admin-cartera.html` actualmente envía `p_cotizacion_id:null`; por tanto el admin no tiene un buscador/selector real para vincular evidencia.

### Decisión F4 — Reconciliation V2
Construir una capa de **candidatos**, separada de la mutación:

`aos_cartera_candidates_v2(token, case_id)` → read-only.

Señales de candidato:
- teléfono normalizado;
- DNI cuando exista;
- misma sede;
- tratamiento o producto canónico;
- monto registrado / total esperado;
- ventana temporal;
- pago completo posterior;
- cotización parcial compatible.

El resultado debe exponer `score/confidence + reasons`, nunca decidir deuda automáticamente.

### Acción humana
El admin puede:
- vincular evidencia existente;
- `PAGO_RECONCILIADO`;
- `NO_ES_DEUDA`;
- `REVISAR`;
- confirmar `SALDO_CONFIRMADO` solo con total/saldo verificables.

**Vincular no crea una nueva fila de pago.** Es una relación/auditoría sobre evidencia que ya existe.

## 7. Hallazgo E — Seguridad del write-path de Ventas requiere corrección dentro de F4

Preflight live detectó que varias RPC legacy relevantes siguen siendo ejecutables por `anon`/`authenticated`, entre ellas:
- `aos_editar_venta`;
- `aos_importar_ventas`;
- `aos_grabar_venta_caja`;
- RPC de lectura administrativa de ventas.

El frontend de Ventas Admin además envía identidad/rol declarados por el navegador al editor legacy. Ese patrón no puede considerarse autorización suficiente.

### Riesgo
CRITICAL para mutaciones financieras: un rol enviado por navegador no debe otorgar autoridad.

### Remediación F4 obligatoria
Aplicar patrón additive-first:
1. crear wrappers/gateways V3 tokenizados usando sesión fuerte y panel requerido (`admin-sales`, `admin-import-ventas`, `admin-caja` según acción);
2. whitelist explícita de campos mutables;
3. optimistic locking para edición de venta;
4. actor derivado server-side, no `p_rol` confiado desde cliente;
5. audit before/after;
6. migrar consumidores UI;
7. negative tests con token inválido/rol incorrecto/sede incorrecta;
8. recién después revocar execute del legacy cuando todos los consumers estén migrados.

No hacer big-bang revoke antes de probar Caja/Importar/Ventas Admin.

## 8. Arquitectura propuesta

### F4A — Canonical Sales Read Model
`aos_sales_admin_gateway_v3(token, periodo, sede, asesor)`

Debe conservar los KPIs actuales y añadir:
- `canonicalProducts`;
- `productResolutionCoverage`;
- `physicalUnits`;
- `reviewRequired`;
- detalle con `raw_description + canonical_product`.

### F4B — Secure sales writes
- `aos_sales_edit_v3(...)` — `admin-sales` + 2FA.
- `aos_importar_ventas_v3(...)` — `admin-import-ventas` + idempotencia.
- wrapper seguro para grabación desde Caja — `admin-caja` + sesión de caja válida.

Los nombres definitivos se cerrarán tras inventariar todos los consumers y evitar colisión con wrappers existentes.

### F4C — Cartera Candidate Engine
Read-only candidates + mutación de reconciliación separada. No introducir scoring opaco: cada score debe incluir razones determinísticas.

### F4D — UI
**Ventas Admin**
- Top Productos canónico;
- ventas + unidades;
- badge de calidad/resolución;
- editor sin authority declarada por browser.

**Cartera**
- `Buscar coincidencias`;
- candidatos y razones;
- `Vincular existente`;
- `Ya pagado / No es deuda / Confirmar saldo / Revisar`;
- timeline/audit del caso.

**Importar**
- preview profesional;
- resultado del lote;
- productos no reconocidos;
- casos que entraron a Cartera;
- no usar `window.confirm()` como gate final.

## 9. Non-goals de F4

No construir todavía:
- merges masivos de pacientes históricos;
- cargas multi-año;
- geografía/demografía definitiva;
- LTV/cohortes multi-año;
- agentes de cobranza;
- campañas automáticas.

Esos outputs pertenecen a F5–F7.

## 10. Tests Zero-Cost obligatorios

### Producto
- 4 spellings → 1 producto canónico;
- facturación mantiene suma de `aos_ventas.monto`;
- `physical_qty` suma unidades reales;
- packs no multiplican venta monetaria;
- unknown → `REVIEW_REQUIRED`.

### Ventas / Import
- token inválido no lee data admin ni muta;
- asesor/admin sin panel correcto no muta;
- lote repetido es idempotente;
- import PRODUCTO dispara F3;
- import ADELANTO dispara Cartera;
- raw description permanece intacta.

### Cartera
- candidate read no muta;
- stale case se rechaza;
- sede incompatible se rechaza;
- identidad incompatible se rechaza;
- link válido no incrementa conteo de pagos/ventas;
- `NO_ES_DEUDA` deja saldo 0;
- `SALDO_CONFIRMADO` exige evidencia y total coherente;
- auditoría before/after presente.

### No regresión
- Caja abre/cierra/ventas sigue operativa;
- Ventas Admin mantiene totales del periodo;
- Sales Intelligence V2 no cambia sus totales por activar F4;
- F3 facts permanecen 1:1 por venta productiva.

## 11. Rollout

1. branch aislada + contratos sintéticos;
2. Zero-Cost CI V2;
3. preflight producción read-only;
4. funciones/read-model aditivos;
5. canary solo admin owner;
6. validar Ventas Admin, Importar y Cartera sin transacciones ficticias;
7. mover frontend a gateways nuevos;
8. revocar legacy writes únicamente con evidence de paridad;
9. post-deploy smoke;
10. recovery que desactive gateways F4 sin reabrir paths anónimos inseguros.

## 12. Gate de salida F4

F4 = `PRODUCTION CERTIFIED — 100%` solo cuando:
- Top Productos usa F3 y reporta venta + unidades correctamente;
- selección manual reduce spelling libre;
- Importar y Caja convergen en F3 + Cartera;
- admin puede vincular evidencia existente sin crear pagos duplicados;
- casos ambiguos fallan cerrado;
- mutaciones financieras ya no confían en rol/actor enviado por navegador;
- ACL/RLS/gateways negativos pasan;
- Zero-Cost CI V2 verde sobre SHA exacto;
- canary y smoke productivo pasan;
- rollback/recovery probado;
- checkpoint GitHub + Supabase + Notion actualizado.

## 13. Siguiente fase preservada

F5 — Historical Client & Sales Consolidation + Patient Identity permanece explícitamente en cola. No se elimina ni se sustituye. Su input contract será F4 certificado, para que años pasados entren por contratos operativos ya confiables.
