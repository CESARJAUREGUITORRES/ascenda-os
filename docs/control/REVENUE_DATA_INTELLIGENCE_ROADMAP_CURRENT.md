# ASCENDA OS — Revenue Data & Intelligence Roadmap CURRENT

**Estado:** CURRENT  
**Actualizado:** 2026-08-14  
**Fuente de verdad:** GitHub + Supabase live; Notion es capa visual derivada.  
**Workstream:** ventas, productos, cartera, importación, pacientes/filiación e inteligencia comercial.

## 1. Estado ejecutivo

FASE 3 — Producto Canónico está **PRODUCTION CERTIFIED — 100%**.

Evidencia CURRENT:
- `main`: `af8da4c051827f0e11010a7c60d692367104c094` (incluye certificación F3 vía PR #108).
- Producción contiene `aos_product_identity_v1`, `aos_product_alias_v2` y `aos_product_sale_fact_v1`.
- 395 hechos de producto actuales: 394 owner-locked del workbook + 1 venta posterior al corte.
- 389 resueltos, 6 excluidos, 0 `REVIEW_REQUIRED` actualmente.
- 419 unidades físicas resueltas actuales: 418 del workbook + 1 canary posterior.
- 43 filas promo/pack.
- Canary real `sale_id=2340` (`LIFTIN B`) resuelto como `F3:LIFTINGB30GR` sin reescribir la descripción histórica.

La fase 3 ya no debe ampliarse con dashboards, conciliación o demografía. Esas capacidades son consumidores downstream de la verdad canónica F3.

## 2. Decisión de secuencia

La cola anterior para subir clientes/ventas históricas **no se elimina**. Se reordena.

Orden canónico desde este checkpoint:

1. **F4 — Revenue Operations Integration V1** — siguiente.
2. **F5 — Historical Client & Sales Consolidation + Patient Identity** — cola preservada; ejecutar después de F4.
3. **F6 — Sales Intelligence 3.0** — explotar datos multi-año y paciente unificado.
4. **F7 — Governed Commercial Automation** — automatización solo sobre saldos, identidad y segmentos validados.

Motivo: antes de importar más historia, los write/read paths actuales deben consumir correctamente producto canónico y Cartera debe permitir reconciliación humana sin duplicar pagos. Luego la carga histórica entra a contratos ya estables y puede alimentar BI sin multiplicar inconsistencias.

## 3. F4 — Revenue Operations Integration V1

**Objetivo:** convertir la verdad canónica ya disponible en comportamiento operativo visible y seguro.

### F4A — Ventas Admin + Producto Canónico

- `Top Productos` debe agrupar por identidad canónica, no por spelling crudo.
- Mostrar por producto: facturación, ventas, unidades físicas, promo/pack, sede, asesor y estado de pago.
- Venta manual: preferir selector de catálogo/producto canónico; reducir texto libre.
- Conservar siempre `aos_ventas.descripcion` como evidencia histórica.
- Importaciones y texto legacy siguen pasando por alias resolver.
- Alias desconocido → `REVIEW_REQUIRED`; nunca inventar producto.
- Flujo admin para mapear un alias una sola vez y reutilizarlo después, con auditoría.
- No desacoplar Caja e Importar: ambos deben terminar en la misma capa de hechos de producto.

### F4B — Cartera / Reconciliation V2

Principio no negociable: **ADELANTO es evidencia de pago, no deuda**.

El panel debe permitir al admin:
- revisar candidatos de coincidencia por paciente/contacto/DNI, servicio o producto, monto, sede y ventana temporal;
- vincular un pago ya existente con la venta/cotización correcta **sin crear un segundo pago**;
- marcar `PAGO_RECONCILIADO`, `NO_ES_DEUDA`, `REVISAR` o confirmar un saldo real;
- ver pagos posteriores que probablemente liquidan el caso;
- corregir manualmente enlaces cuando el match automático no sea suficiente;
- conservar quién vinculó, cuándo, evidencia usada y valores antes/después;
- recibir casos originados tanto por Caja como por `Importar Ventas`.

El sistema puede sugerir coincidencias; la confirmación financiera ambigua sigue siendo human-in-the-loop.

### F4C — Intelligence Foundation sobre datos actuales

Sin esperar F6, las superficies actuales pueden empezar a consumir dimensiones confiables:
- ranking canónico de productos y servicios;
- mix servicio/producto;
- unidades físicas y facturación;
- desempeño por sede/asesor/mes;
- heatmap calendario del año cargado (día de semana / día del mes) con etiqueta explícita de cobertura temporal;
- indicadores de calidad: porcentaje resuelto, review queue, cobertura de identidad paciente.

No presentar aún geografía/edad como conclusión ejecutiva si la cobertura de filiación es insuficiente.

### Gate F4

F4 solo cierra si:
- UI y RPC usan dimensión canónica sin alterar `aos_ventas` histórica;
- venta manual e importación convergen en el mismo contrato;
- Cartera permite vincular evidencia existente sin duplicar pagos;
- matches ambiguos fallan cerrado y quedan revisables;
- auditoría, ACL/RLS, rollback y Zero-Cost CI V2 pasan;
- smoke real de Ventas Admin + Cartera + Importar pasa en producción.

## 4. F5 — Historical Client & Sales Consolidation + Patient Identity

**Esta es la fase anteriormente en cola para subir datos de clientes/ventas de años pasados. Se conserva y se ejecuta después de F4.**

### Propósito

Crear una identidad de paciente estable y una historia comercial multi-año antes de explotar demografía, geografía, cohortes y estacionalidad.

### Ingreso de archivos históricos

Cada lote debe pasar por:
1. inventario de columnas y años;
2. profiling de calidad;
3. normalización no destructiva;
4. detección de duplicados/conflictos;
5. resolución de identidad con evidencia;
6. preview de merges y excepciones;
7. aprobación humana para conflictos;
8. import idempotente y auditable;
9. reconciliación post-import con ventas/productos/cartera;
10. reporte de cobertura final.

Nunca fusionar pacientes en masa solo por nombre. `numero_limpio`, documento, email y otros atributos son evidencia, no autoridad absoluta aislada.

### Dimensiones a normalizar

- identidad paciente;
- teléfonos/documentos/emails;
- sexo;
- fecha de nacimiento / edad derivada;
- país/departamento/ciudad/distrito;
- sede principal;
- fuente/canal;
- primera y última compra;
- tratamiento/producto;
- año/fecha de venta;
- provenance: archivo, lote, fila, regla y confianza.

### Output F5

- paciente canónico y tabla de aliases/bridges;
- ventas históricas ligadas a identidad con provenance;
- cobertura de campos de filiación medible;
- conflictos no resueltos en queue explícita;
- dataset multi-año listo para BI;
- ninguna pérdida de evidencia original.

## 5. F6 — Sales Intelligence 3.0

**Objetivo:** pasar de KPIs financieros a inteligencia comercial explicable y accionable.

### Resumen / performance
- YTD, MTD, meta, ticket, proyección;
- servicio vs producto;
- facturación vs cobro reconciliado;
- saldo real confirmado, separado de adelantos.

### Tiempo y estacionalidad
- heatmap día de semana × semana/mes;
- días del mes con mayor conversión/facturación;
- mes vs mes;
- año vs año;
- mismo día/ventana en años anteriores;
- estacionalidad y ventanas recomendadas para campañas, siempre con tamaño de muestra visible.

### Cliente / demografía
- sexo por servicio/producto;
- bandas de edad solo con cobertura suficiente;
- frecuencia y recencia;
- LTV / valor acumulado;
- recompra;
- pacientes dormidos;
- cohortes por mes/año de adquisición.

### Geografía
- distrito/provincia/departamento solo después de normalización F5;
- facturación, ticket, frecuencia y mix por zona;
- sede preferida por zona;
- nunca inferir distrito a partir de campos incompletos sin provenance/confianza.

### Afinidad / cross-sell
- tratamiento inicial → siguiente compra;
- servicio → producto asociado;
- producto → recompra;
- attach rate;
- secuencias de compra;
- next-best-offer como recomendación, no ejecución automática.

### Marketing / atribución
Cuando las fuentes de leads/campañas estén reconciliadas:
- lead → cita → venta;
- conversión por tratamiento/anuncio/fuente;
- CPL/CAC/ROAS cuando existan costos confiables;
- time-to-purchase;
- cohortes por origen.

### Regla de cobertura
Toda métrica demográfica/geográfica debe mostrar cobertura y tamaño de muestra. Si cobertura/freshness no pasa el contrato de la fase, se etiqueta como parcial/no confiable y no se usa como conclusión ejecutiva.

## 6. F7 — Governed Commercial Automation

Solo después de F4–F6:
- recordatorios de saldos **confirmados**;
- reactivación de pacientes dormidos;
- next-best-offer;
- campañas por cohortes/afinidad;
- alertas de caída o oportunidad;
- recomendaciones KronIA.

Ningún agente debe convertir un adelanto en deuda, fusionar identidad ambigua o contactar automáticamente basándose en datos de baja confianza.

## 7. Cobertura observada que condiciona el roadmap

Baseline 2026-08-14:
- `aos_ventas`: 1,279 registros; rango cargado 2026-01-05..2026-08-13.
- 1,247/1,279 ventas enlazables hoy a `aos_pacientes` por teléfono normalizado (~97.5%).
- `aos_pacientes`: 7,662 registros.
- sexo poblado: 7,026 (~91.7%).
- fecha de nacimiento poblada: 1,244 (~16.2%).
- distrito poblado: 2 registros.

Conclusión: sexo tiene mejor base de análisis; edad requiere enriquecimiento; distrito no es todavía production-trustworthy. F5 debe mejorar filiación antes de F6 geográfico/demográfico.

## 8. Contratos entre fases

`F3 Producto Canónico` → **qué producto se vendió realmente**.  
`F4 Revenue Operations` → **cómo lo usa operación y cómo se reconcilia el dinero real**.  
`F5 Historical + Patient Identity` → **quién compró realmente y cómo unimos años/fuentes**.  
`F6 Sales Intelligence 3.0` → **qué patrones explicables sirven para decidir**.  
`F7 Automation` → **qué acción gobernada puede ejecutarse sin riesgo**.

## 9. Reglas de continuidad para otros chats/agentes

Antes de trabajar en Ventas, Producto, Cartera, Importar, Pacientes/Filiación o Sales Intelligence:
1. leer `AGENTS.md`;
2. leer este documento CURRENT;
3. verificar `main`, branch/PR/checks y Supabase live;
4. no reabrir F3 salvo bug/regresión demostrada;
5. respetar secuencia F4 → F5 → F6 → F7;
6. mantener `aos_ventas` y datos fuente como evidencia inmutable salvo corrección auditada;
7. usar `ASCENDA-ZERO-COST-V2`; no fallback pagado;
8. registrar nuevos hallazgos en el checkpoint/PR de su fase y no perderlos en chat informal.

## 10. Próximo checkpoint

**NEXT: F4 — Revenue Operations Integration V1.**

Primer loop recomendado:
1. Impact Report read-only de `admin-sales`, `admin-cartera`, `Importar`, RPCs y consumers;
2. contrato `canonical product read model` para Ventas Admin;
3. diseño de selector canónico para altas manuales;
4. candidate-matching + manual link contract para Cartera;
5. paridad Caja/Importar;
6. Zero-Cost tests y branch aislada;
7. canary admin antes de activación general.
