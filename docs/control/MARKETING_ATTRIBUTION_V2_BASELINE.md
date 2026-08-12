# ASCENDA OS — MARKETING ATTRIBUTION V2 — BASELINE FACTUAL

**Fecha de baseline:** 2026-08-12  
**Proyecto Supabase:** `ituyqwstonmhnfshnaqz`  
**Git baseline de producción:** `bb01659f1fca1546dbcf0d56ec9c31b93aacc36c`  
**Objetivo:** conservar cifras y hallazgos verificables antes de sustituir lógica de atribución.

## 1. Agosto 2026 — leads

- Registros/touchpoints: **358**
- Personas únicas (`numero_limpio`): **350**
- Touchpoints adicionales: **8**
- Personas con más de un registro en agosto: **8**
- Reingresos con más de un anuncio: **1**
- Reingresos con más de un tratamiento: **1**
- Personas repetidas el mismo día: **6**

### Duplicado técnico probable

De los 8 touchpoints adicionales, **6** forman grupos con:

- mismo `numero_limpio`;
- mismo día;
- mismo anuncio;
- mismo tratamiento;
- misma `hora_ingreso`;
- mismo `created_at`.

Esto es evidencia fuerte de duplicación técnica/importación, pero **no se borran filas** durante Attribution V2. Se marcarán como `duplicado_tecnico_probable` y solo se excluirán de métricas de captación tras validar la regla.

Los otros **2** reingresos no se clasifican como duplicados técnicos en esta baseline.

## 2. Agosto 2026 — ventas de cohorte

Resultado validado después de corregir la regla temporal del dashboard:

- Leads/personas convertidas reales observadas por la lógica V2 de detalle: **2**
- Operaciones de venta atribuibles a la ventana de los touchpoints: **6**
- Facturación atribuible M0 observada: **S/ 1,045**
- Ventas posteriores al cierre de agosto en la fecha de la baseline: **0**

Importante: `clientes convertidos` y `operaciones de venta` son métricas distintas. No usar la etiqueta genérica `ventas` para ambas.

## 3. Ver Leads V1 vs V2 — agosto

La lógica V1 consulta historial global del teléfono y puede marcar un lead actual como vendido por compras antiguas.

Comparación factual observada:

- V1: **5** leads mostrados como vendidos, **16** operaciones históricas, **S/ 2,485.50** asociados.
- V2: **2** leads/touchpoints convertidos, **6** operaciones dentro de la ventana válida, **S/ 1,045**.

V2 todavía permanece paralela hasta completar la validación del recorrido `lead → llamada → cita → venta`.

## 4. Call Center — trazabilidad histórica

- Citas con `origen_cita = CALL_CENTER`: **831**
- Citas con una única llamada `CITA CONFIRMADA` del mismo teléfono y asesor dentro de ±10 minutos de `ts_creado`: **796**
- Cobertura de match fuerte aproximada: **95.8%**
- Casos ambiguos o sin match inmediato: **35**

Esta señal permite reconstruir históricamente `llamada → cita` con alta confianza para una gran parte del histórico, pero no autoriza un backfill automático sin revisar también el origen del lead.

## 5. Pérdida histórica de contexto

### `aos_llamadas`

- Total observado: **34,047**
- Con `anuncio` poblado: **4,214**
- Sin `anuncio`: **29,833**

Por tanto, `aos_llamadas.anuncio` no puede utilizarse como única evidencia histórica.

### `aos_agenda_citas`

- Total observado: **2,912**
- `venta_id_match` poblado: **0**

La columna existe, pero el enlace cita→venta no se ha implementado históricamente.

## 6. Bug de origen identificado en Call Center

La función madre `aos_siguiente_lead` selecciona primero un `numero_limpio`, pero posteriormente reconstruye la ficha con un patrón equivalente a:

`WHERE ld.numero_limpio = v_num LIMIT 1`

sin conservar el `lead_id` seleccionado ni aplicar un orden determinista en esa reconstrucción.

Cuando un teléfono posee múltiples touchpoints, esto puede devolver un registro distinto al que originó la selección.

### Solución paralela

`aos_siguiente_lead_v2` mantiene la lógica de selección actual y añade resolución de `lead_id` cuando existe evidencia suficiente. Para tiers/colas que no se originan inequívocamente en un lead nuevo, puede devolver `UNRESOLVED` en lugar de inventar un origen.

## 7. Columnas de trazabilidad ya creadas — backward-compatible

Todas son nullable y no modifican la UI ni registros históricos:

- `aos_llamadas.lead_id_origen`
- `aos_agenda_citas.lead_id_origen`
- `aos_agenda_citas.llamada_id_origen`
- `aos_seguimientos.lead_id_origen`
- `aos_leads_en_curso.lead_id_origen`

No se han añadido Foreign Keys estrictas todavía.

## 8. Reglas de certeza

1. Un teléfono identifica a una persona, no a un único touchpoint.
2. Una fila de `aos_leads` es un evento/touchpoint.
3. Una venta anterior al touchpoint nunca puede convertirlo.
4. Un lead posterior no recibe crédito si existe evidencia de que la gestión utilizó un touchpoint anterior.
5. Una atribución histórica ambigua permanece sin atribuir o marcada para revisión.
6. Ningún backfill se ejecuta únicamente para hacer coincidir totales.
7. Toda nueva relación explícita por ID tiene precedencia sobre inferencias históricas.

## 9. Gates antes de reemplazar V1

- Captura futura de `lead_id` validada.
- Llamadas nuevas guardan origen cuando existe.
- Citas nuevas preservan origen cuando existe.
- V1 vs V2 explicado enero→mes actual.
- Casos de reingreso/remarketing validados.
- Duplicados técnicos clasificados sin borrar datos.
- Histórico anual utiliza solo universo Marketing.
- `Ver Leads` muestra resultado del touchpoint y no historia previa.
- CI verde.
- Rollback documentado.
