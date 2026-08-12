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

Esto es evidencia fuerte de duplicación técnica/importación, pero **no se borran filas** durante Attribution V2. Se marcan como `duplicado_tecnico_probable` y solo se excluirán de métricas de captación tras validar la regla.

Los otros **2** reingresos no se clasifican como duplicados técnicos en esta baseline.

## 2. Agosto 2026 — ventas de cohorte

Resultado validado después de corregir la regla temporal del dashboard:

- Leads/personas convertidas observadas por la lógica V2 de detalle: **2**
- Operaciones de venta dentro de las ventanas válidas: **6**
- Facturación M0 observada: **S/ 1,045**
- Ventas posteriores al cierre de agosto en la fecha de la baseline: **0**

Importante: `clientes convertidos` y `operaciones de venta` son métricas distintas. No usar la etiqueta genérica `ventas` para ambas.

## 3. Ver Leads V1 vs V2 — agosto

La lógica V1 consulta historial global del teléfono y puede marcar un lead actual como vendido por compras antiguas.

Comparación factual observada:

- V1: **5** leads mostrados como vendidos, **16** operaciones históricas, **S/ 2,485.50** asociados.
- V2: **2** leads/touchpoints convertidos, **6** operaciones dentro de la ventana válida, **S/ 1,045**.

V2 permanece paralela hasta completar la validación del recorrido `lead → llamada → cita → venta`.

## 4. Call Center — trazabilidad histórica reproducible

Matcher canónico `aos_marketing_call_cita_match_v2`:

- Citas con `origen_cita = CALL_CENTER`: **831**
- Match único llamada `CITA CONFIRMADA` + mismo teléfono + mismo asesor dentro de ±10 minutos: **791**
- Casos ambiguos dentro de ±10 minutos: **24**
- Sin match en ±10 minutos: **16**
- Cobertura de match único: **≈95.2%**

La exploración preliminar anterior había estimado 796. La cifra oficial se corrige a **791** porque esta versión proviene de una función reproducible y versionada.

Los 24 ambiguos poseen timestamps de llamadas diferentes; no son simples filas duplicadas con el mismo timestamp y no deben resolverse automáticamente.

## 5. Call Center — llamada ↔ lead de Marketing

Sobre las 791 cadenas llamada→cita inequívocas:

- **504** tienen exactamente un único lead de Marketing previo.
- **3** tienen múltiples leads previos.
- De esos 3, **1** se resuelve de manera única usando tratamiento.
- **2** permanecen ambiguos.
- **284** no tienen ningún lead de Marketing previo y, por tanto, no deben forzarse dentro de Marketing.

Esto confirma que `NO ATRIBUIBLE A MARKETING` es un resultado válido del motor.

## 6. Cita / asistencia ↔ venta

- Citas Call Center con estado `ASISTIO` o `EFECTIVA`: **133**.
- Citas con al menos una venta del mismo teléfono el mismo día: **78**.
- En **75** casos la cita/asistencia del teléfono en ese día es inequívoca respecto al histórico de agenda.
- Existen casos con múltiples citas/asistencias el mismo día que deben permanecer ambiguos.

### Atenciones

`aos_atenciones` ya contiene `cita_id` y `venta_id`, y `aos_ventas` contiene `atencion_id`, pero el histórico no forma una cadena completa universal:

- Atenciones totales observadas: **493**.
- Atenciones con `cita_id`: **344**.
- Atenciones con `venta_id`: **0**.
- Ventas que apuntan a alguna atención vía `aos_ventas.atencion_id`: **233**.
- Las ventas enlazadas a atención no coinciden actualmente con atenciones que tengan `cita_id` poblado.

Por tanto no se utilizará `atencion_id` como puente universal de atribución hasta corregir el flujo de captura futuro.

## 7. Anomalías verificadas de trazabilidad

En agosto existe al menos un lead con cadena fuerte `lead → llamada → cita`, pero la cita del día de las ventas figura como `NO ASISTIO` mientras existen cuatro operaciones de venta reales ese mismo día por **S/ 667**.

Las cuatro operaciones son productos/servicio diferentes, por lo que no constituyen una duplicación evidente de ventas. La contradicción es el estado de asistencia frente al registro comercial.

**Regla:** estas contradicciones se marcan como anomalía y no se corrigen automáticamente durante el backfill.

## 8. Pérdida histórica de contexto

### `aos_llamadas`

- Total observado: **34,047**
- Con `anuncio` poblado: **4,214**
- Sin `anuncio`: **29,833**

Por tanto, `aos_llamadas.anuncio` no puede utilizarse como única evidencia histórica.

### `aos_agenda_citas`

- Total observado: **2,912**
- `venta_id_match` poblado: **0**

La columna existe, pero el enlace cita→venta no se ha implementado históricamente.

## 9. Bug de origen identificado en Call Center

La función madre `aos_siguiente_lead` selecciona primero un `numero_limpio`, pero posteriormente reconstruye la ficha con un patrón equivalente a:

`WHERE ld.numero_limpio = v_num LIMIT 1`

sin conservar el `lead_id` seleccionado ni aplicar un orden determinista en esa reconstrucción.

Cuando un teléfono posee múltiples touchpoints, esto puede devolver un registro distinto al que originó la selección.

### Solución paralela

`aos_siguiente_lead_v2` mantiene la lógica de selección actual y añade resolución de `lead_id` cuando existe evidencia suficiente. Para tiers/colas que no se originan inequívocamente en un lead nuevo, puede devolver `UNRESOLVED` en lugar de inventar un origen.

## 10. Columnas de trazabilidad ya creadas — backward-compatible

Todas son nullable y no modifican la UI ni registros históricos:

- `aos_llamadas.lead_id_origen`
- `aos_agenda_citas.lead_id_origen`
- `aos_agenda_citas.llamada_id_origen`
- `aos_seguimientos.lead_id_origen`
- `aos_leads_en_curso.lead_id_origen`

No se han añadido Foreign Keys estrictas todavía.

## 11. Herramientas internas read-only

Creadas y sin conexión a la UI:

- `aos_marketing_touchpoints_v2`
- `aos_marketing_call_cita_match_v2`
- `aos_marketing_call_lead_match_v2`

Estas funciones tienen `EXECUTE` revocado a `PUBLIC` durante la fase de reconstrucción.

## 12. Reglas de certeza

1. Un teléfono identifica a una persona, no a un único touchpoint.
2. Una fila de `aos_leads` es un evento/touchpoint.
3. Una venta anterior al touchpoint nunca puede convertirlo.
4. Un lead posterior no recibe crédito si existe evidencia de que la gestión utilizó un touchpoint anterior.
5. Una atribución histórica ambigua permanece sin atribuir o marcada para revisión.
6. Ningún backfill se ejecuta únicamente para hacer coincidir totales.
7. Toda nueva relación explícita por ID tiene precedencia sobre inferencias históricas.
8. `NO ATRIBUIBLE A MARKETING` es un resultado correcto cuando no existe lead previo.
9. Las contradicciones de estados operativos se reportan; no se corrigen por inferencia.

## 13. Gates antes de reemplazar V1

- Captura futura de `lead_id` validada.
- Llamadas nuevas guardan origen cuando existe.
- Citas nuevas preservan origen cuando existe.
- V1 vs V2 explicado enero→mes actual.
- Casos de reingreso/remarketing validados.
- Duplicados técnicos clasificados sin borrar datos.
- Histórico anual utiliza solo universo Marketing.
- M0 y LTV/acumulado permanecen métricas separadas.
- `Ver Leads` muestra resultado del touchpoint y no historia previa.
- CI verde.
- Rollback documentado.
