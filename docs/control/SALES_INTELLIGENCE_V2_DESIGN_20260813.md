# ASCENDA OS — Sales Intelligence V2

Fecha de auditoría: 2026-08-13
Estado: DISEÑO + AUDITORÍA READ-ONLY COMPLETADOS
Rama: `feat/sales-intelligence-v2`
Producción: SIN CAMBIOS

## 1. Objetivo

Evolucionar el panel de Ventas desde un dashboard descriptivo a una herramienta de inteligencia comercial y cartera, sin romper la lógica certificada enero–12 agosto 2026 ni aumentar innecesariamente la carga sobre Supabase.

Prioridades V2:
1. Comparativa anual + metas.
2. Cartera de adelantos/saldos y reconciliación de pagos.
3. Canal de venta / web.
4. Inteligencia de clientes y calidad demográfica.
5. Insights IA sobre datos validados.
6. Top Productos por unidades reales cuando termine la reconciliación manual de productos.

## 2. Reglas de negocio fijadas

- `OTROS` se trata siempre como `SERVICIO`, aunque un registro legacy tenga `tipo='PRODUCTO'`.
- Una fila de `COMPRA DE PRODUCTO` no equivale necesariamente a una unidad física.
- Precio no determina por sí solo cantidad de producto.
- `PARTE 1`, `PARTE 2`, `ADELANTO`, `SALDO`, `2DO PAGO` o dos métodos de pago pueden pertenecer a una única operación comercial.
- Los 1,275 registros / S/555,373.27 certificados al 12/08/2026 no deben cambiar por la implementación visual de V2.

## 3. Estado técnico actual del panel

Frontend productivo: `app/public/admin-sales.html`.

RPC principales:
- `aos_ventas_admin(p_mes,p_anio,p_sede,p_asesor)`
- `aos_ventas_admin_anio(p_anio,p_sede,p_asesor)`

El panel ya recibe en el RPC mensual:
- facturación, ventas y ticket promedio;
- servicios/productos;
- estados de pago;
- meta mensual;
- detalle;
- asesor, sede y método de pago;
- serie anual;
- métodos configurados y metas.

Problema de escalabilidad: el RPC anual devuelve también todo el detalle. Con los datos actuales el payload anual es aprox. 462 KB para solo 1,275 filas. Además, ambos RPC ejecutan múltiples scans repetidos sobre `aos_ventas` y recalculan comisiones mediante subconsultas. La tabla todavía es pequeña (~888 KB), pero el patrón no escala bien.

No existe polling periódico dentro de `admin-sales.html`; el principal costo del panel proviene de la forma del RPC y del tamaño de la respuesta, no de un `setInterval` local.

## 4. Baseline anual certificado

Meta mensual actual: S/100,000 para enero–agosto.

| Mes | Ventas | Facturado | % Meta | Variación vs mes anterior |
|---|---:|---:|---:|---:|
| Ene | 191 | S/91,029.60 | 91.03% | — |
| Feb | 166 | S/78,734.62 | 78.73% | -13.51% |
| Mar | 156 | S/63,681.65 | 63.68% | -19.12% |
| Abr | 152 | S/59,496.95 | 59.50% | -6.57% |
| May | 179 | S/79,225.85 | 79.23% | +33.16% |
| Jun | 159 | S/61,140.75 | 61.14% | -22.83% |
| Jul | 189 | S/65,115.05 | 65.12% | +6.50% |
| Ago 1–12 | 83 | S/56,948.80 | 56.95% | mes parcial |

YTD al corte: S/555,373.27 sobre una meta acumulada de S/800,000 = 69.42%.

Para meses parciales no debe compararse el mes incompleto contra el mes completo. Ejemplo: 1–12 agosto = S/56,948.80 vs 1–12 julio = S/32,839.05, una mejora comparable de +73.42%.

## 5. Diseño funcional — Comparativa anual + metas

### KPI superiores
- Facturado YTD.
- Meta YTD.
- % cumplimiento YTD.
- Gap a meta acumulada.
- Ticket promedio YTD.
- Promedio mensual de meses cerrados.
- Mejor mes.
- Último mes cerrado vs anterior.

### Gráfico principal
Serie enero–diciembre:
- barra `Facturado real`;
- barra/línea `Meta`;
- indicador `% cumplimiento`;
- mes actual marcado como PARCIAL.

### Tabla mensual
Columnas:
- Mes.
- Facturado.
- Meta.
- % cumplimiento.
- Ventas.
- Ticket.
- Variación vs mes anterior cerrado.
- Comparación MTD same-days para el mes actual.

### Proyección mensual
Solo en mes activo:
- días con información;
- ritmo promedio diario;
- facturación proyectada a fin de mes;
- monto faltante para meta;
- promedio diario necesario para llegar a meta.

## 6. Cartera / saldos — hallazgos críticos

Infraestructura existente:
- `aos_cotizaciones`
- `aos_cotizacion_items`
- `aos_pagos`
- `aos_abonar_cotizacion()`

Datos actuales:
- 284 cotizaciones.
- 229 `PAGADO_COMPLETO`.
- 39 `PAGADO_PARCIAL` con S/74,715.77 de saldo registrado.
- 12 `ANULADO` con S/11,991 de saldo residual: NO debe contarse como cartera cobrable automáticamente.
- 3 `CREADO` por S/1,305 y 1 `POR_PAGAR` por S/1,499: son pipeline/cotización, no deuda confirmada por defecto.
- 7 cotizaciones anuladas tienen inconsistencia aritmética en saldo por S/1,424 acumulados.

Conclusión: S/89,510.77 es el saldo bruto almacenado en todas las cotizaciones, pero NO es equivalente a deuda exigible. El primer universo operativo serio es `PAGADO_PARCIAL`: 39 casos / S/74,715.77, sujeto a reconciliación histórica.

Distribución de saldo parcial por mes de origen:
- Ene: 15 / S/15,494.50
- Feb: 15 / S/49,702.47
- Mar: 7 / S/7,918.80
- Abr: 2 / S/1,600.00

Las cotizaciones existentes terminan el 25/04/2026. No hay cotizaciones creadas desde mayo, por lo que la infraestructura dejó de representar todo el flujo comercial posterior.

## 7. Problema de ledger de pagos

`aos_pagos` contiene actualmente solo 1 pago por S/169, mientras `aos_cotizaciones.total_pagado` acumula S/285,206.32. Por tanto, `aos_pagos` NO es todavía un ledger histórico completo y no puede usarse solo para automatizar cobranzas.

Además existen 122 filas históricas de `aos_ventas` con `estado_pago='ADELANTO'` por S/75,222.90 entre enero y 12 agosto. Ninguna tiene `cotizacion_id` asociado.

Es obligatorio reconciliar estos dos mundos antes de enviar recordatorios automáticos.

## 8. Riesgo en `aos_abonar_cotizacion()`

El RPC actual:
1. actualiza `total_pagado` y `saldo_pendiente` de la cotización;
2. crea fila en `aos_pagos`;
3. crea también una fila en `aos_ventas`;
4. esa fila de venta usa siempre `estado_pago='PAGO COMPLETO'`;
5. esa fila usa siempre `tipo='SERVICIO'`;
6. no guarda `cotizacion_id` en la nueva fila de `aos_ventas`.

Esto confunde el concepto de cobro parcial con pago completo y puede perder la naturaleza PRODUCTO/SERVICIO del ítem. La corrección V2 debe preservar compatibilidad con Caja y Comisiones y hacerse con migración/rollback, no parche directo.

## 9. Diseño funcional — Cartera de valor

### KPI
- Saldo confirmado.
- Clientes con saldo confirmado.
- Adelantos históricos sin reconciliar.
- Cobros recuperados del mes.
- Saldo vencido por antigüedad (solo cuando exista fecha de vencimiento/último pago confiable).
- Cotizaciones abiertas sin pago separadas de deuda real.

### Tabla operativa
- Cliente.
- Teléfono.
- Sede.
- Operación/cotización.
- Servicio/producto.
- Total pactado.
- Pagado.
- Saldo.
- Fecha origen.
- Último pago confiable.
- Responsable.
- Estado reconciliación.
- Próxima acción.

Estados propuestos:
- `PENDIENTE_RECONCILIAR`
- `SALDO_CONFIRMADO`
- `PAGO_RECONCILIADO`
- `CERRADO`
- `NO_ES_DEUDA`
- `REVISAR`

## 10. Bridge para histórico

No crear un segundo sistema de pagos. Se propone una tabla puente mínima para vincular filas legacy de ventas con el sistema existente, sin duplicar montos:

`aos_venta_pago_vinculos`
- `id`
- `venta_row_id` -> `aos_ventas.id`
- `cotizacion_id` nullable
- `grupo_pago_id`
- `rol_pago` (`UNICO`,`ADELANTO`,`PARTE_1`,`PARTE_2`,`SALDO`,`COMPLEMENTO`)
- `estado_reconciliacion`
- `confianza`
- `confirmado_por`
- `confirmed_at`

La tabla es vínculo/auditoría, no fuente financiera paralela.

## 11. Diseño técnico de RPC V2

Evitar ampliar indefinidamente los RPC actuales.

Propuesta:

### `aos_sales_intelligence_summary`
Devuelve únicamente:
- KPIs del período;
- serie mensual;
- metas;
- comparativa MTD same-days;
- sede/métodos/agregados;
- no devuelve detalle de 1,000+ filas.

Implementación con un CTE `base` filtrado una sola vez y agregaciones condicionales.

Clasificación obligatoria:
`CASE WHEN upper(trim(tratamiento))='OTROS' THEN 'SERVICIO' ELSE tipo END`.

### `aos_sales_detail_page`
Detalle paginado `limit/offset` o cursor. El frontend ya muestra 100 filas; el backend debe dejar de transferir las 1,275 de una vez.

### `aos_sales_receivables_summary`
Solo agregados de cartera reconciliada y pipeline, separando deuda confirmada de cotización abierta.

### `aos_sales_receivables_page`
Tabla paginada de casos operativos.

## 12. Índices / salud

Existentes útiles:
- `aos_ventas(fecha)`
- `aos_ventas(asesor,fecha)`
- `aos_ventas(numero_limpio,fecha)`
- `aos_cotizaciones(numero_limpio)`
- `aos_pagos(cotizacion_id)`

Antes de añadir índices, validar planes de consulta. Candidatos futuros, solo si EXPLAIN lo justifica:
- `aos_cotizaciones(estado, fecha_creacion)`
- `aos_ventas(fecha,sede)`

No crear índices por intuición en producción.

## 13. Canal web — baseline provisional

Mientras no exista `canal_venta`, la regla histórica segura para inferir web sigue siendo `COMPRA DE PRODUCTO + MERCADOPAGO`.

Ventas web inferidas:
- Ene: 1 / S/159
- Mar: 4 / S/646
- May: 2 / S/429
- Jul: 1 / S/240
- Ago 1–12: 7 / S/1,265

V2 debe introducir un `canal_venta` explícito para nuevas operaciones y conservar `canal_inferido` para históricos.

## 14. Calidad demográfica

Pacientes: 7,660.
- Sexo informado: 7,026.
- Fecha de nacimiento: 1,244.
- Distrito: solo 2.
- País/departamento/ciudad aparecen informados en 7,660, pero todos son `Perú / Lima / Lima`, por lo que actualmente funcionan como valores por defecto y no como evidencia geográfica útil.

No mostrar todavía un mapa de distritos como si la información fuera confiable. Primero debe existir KPI de calidad de filiación y enriquecimiento del dato.

## 15. Orden de implementación

### Fase A — sin tocar datos financieros
1. Comparativa anual + metas + MTD comparable.
2. RPC summary optimizado y detalle paginado.
3. Frontend Sales Intelligence V2.
4. Tests de regresión contra los 8 cortes certificados.

### Fase B — cartera
5. Matriz de reconciliación de los 122 adelantos legacy.
6. Validación de los 39 saldos parciales.
7. Tabla puente de vínculos legacy.
8. Corrección segura de `aos_abonar_cotizacion()`.
9. Panel de cartera.

### Fase C — crecimiento
10. Canal web explícito.
11. Calidad/demografía.
12. RFM/LTV/reactivación.
13. Insights IA.
14. Recordatorios automáticos solo sobre `SALDO_CONFIRMADO`.

### Fase D — productos
15. Ingestar Excel corregido de productos.
16. Normalizar nombres y unidades.
17. Top Productos definitivo por compras, unidades y facturación.

## 16. Gates de seguridad

- No modificar `main` directamente.
- Rama -> CI -> PR -> staging -> validación -> main.
- Cualquier DDL/RPC productivo requiere migration, impact report, rollback y aprobación humana.
- Antes/después de cada cambio: checksum financiero certificado 1,275 / S/555,373.27 al corte 12/08/2026.
- Ningún cambio de inteligencia debe alterar ventas históricas certificadas.
