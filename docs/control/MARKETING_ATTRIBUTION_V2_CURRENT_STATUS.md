# ASCENDA OS — Marketing Attribution V2 — Current Status

**Fecha:** 2026-08-12  
**Producción (`main`):** cutover V2 promovido  
**Commit productivo:** `6b817a84a9355d95e66aaad90e1ffef73830787c`  
**Issue operativo:** #4

## Estado ejecutivo

Marketing Attribution V2 fue promovido desde feature → `staging` → `main` después de gates SQL, CI de PR y CI de `staging` en verde.

La promoción productiva incluye:
- captura futura de `lead_id_origen` en Call Center;
- `Ver Leads` V2;
- KPIs y embudo V2;
- Histórico anual V2;
- LTV por cohortes V2;
- Anuncios/Campañas V2 mensual y anual;
- períodos automáticos;
- fila de trazabilidad de personas/touchpoints/duplicados/reingresos/reactivación.

No se ejecutó backfill destructivo ni se forzaron atribuciones ambiguas.

## Gates de datos cerrados

### Duplicados técnicos
La firma de duplicado técnico exige coincidencia del mismo `numero_limpio`, misma fecha comercial, mismo `hora_ingreso`, mismo anuncio, mismo tratamiento y mismo `created_at` dentro del grupo. Reingresos del mismo teléfono/campaña/tratamiento en fechas o meses diferentes permanecen como touchpoints legítimos.

Enero–agosto 2026:
- touchpoints raw: **5,369**
- duplicados técnicos probables: **40**
- touchpoints efectivos: **5,329**

### Cobertura de adquisición
El denominador correcto son compradores cuya primera compra tiene al menos un touchpoint efectivo de Marketing en fecha igual o anterior a dicha compra.

- clientes elegibles: **52**
- clientes atribuidos: **51**
- cobertura: **98.08%**
- matches históricos únicos recuperados: **17**, método `HISTORICAL_UNIQUE_MATCH`, confidence **60**
- casos ambiguos sin atribuir: **1**

No se atribuye una primera compra a un lead que llegó después de la compra.

### Reactivación
Definición: cliente ya comprador + nuevo touchpoint posterior a una compra previa + venta nueva posterior/al mismo día del nuevo touchpoint.

Estado histórico observado:
- touchpoints de reingreso de cliente existente: **5**
- clientes existentes que reingresaron: **4**
- conversiones de reactivación confirmadas: **0**

Por tanto, existe pipeline de reactivación, pero no revenue histórico de reactivación confirmado.

## Casos patrón conservados

- Marzo 2026: **3 clientes / 6 operaciones / S/ 965 M0**. Caso multi-touch ambiguo permanece excluido.
- Julio 2026: **3 clientes / 13 operaciones / S/ 4,258.80 M0**. Venta S/55 anterior al lead permanece excluida.
- Agosto 2026: **2 clientes / 6 operaciones / S/ 1,045 M0**.
- Atribuciones duplicadas de una misma venta: **0**.
- Ventas atribuidas antes del lead: **0**.

## Histórico / LTV 2026

| Mes | M0 | Posterior | Acumulado |
|---|---:|---:|---:|
| Ene | S/ 4,881.50 | S/ 32,676.20 | S/ 37,557.70 |
| Feb | S/ 2,741.40 | S/ 10,245.60 | S/ 12,987.00 |
| Mar | S/ 965.00 | S/ 17,877.00 | S/ 18,842.00 |
| Abr | S/ 99.00 | S/ 448.00 | S/ 547.00 |
| May | S/ 5,201.00 | S/ 2,870.00 | S/ 8,071.00 |
| Jun | S/ 6,521.00 | S/ 3,878.95 | S/ 10,399.95 |
| Jul | S/ 4,258.80 | S/ 5,733.00 | S/ 9,991.80 |
| Ago | S/ 1,045.00 | S/ 0 | S/ 1,045.00 |

Total 2026 observado hasta agosto:
- M0: **S/ 25,712.70**
- posterior: **S/ 73,728.75**
- atribuido acumulado: **S/ 99,441.45**

Anuncios V2 anual, Campañas V2 anual e Histórico V2 anual reconcilian exactamente esos totales.

## Frontend productivo

### Call Center
`app/public/calls.js`:
- usa `aos_siguiente_lead_v2`;
- conserva `leadId`, anuncio, `horaIngreso` y `attributionSource`;
- nuevas llamadas guardan `lead_id_origen` cuando existe;
- nuevas citas guardan `lead_id_origen` cuando existe;
- nuevos seguimientos guardan `lead_id_origen` cuando existe;
- `UNRESOLVED` permanece `NULL`;
- no se cambió la secuencia visual ni el `Promise.all` del flujo de cita.

Limitación legacy conocida: `aos_get_seguimientos` aún no devuelve `lead_id_origen` para seguimientos históricos/reabiertos. No bloquea la captura correcta de nuevos seguimientos.

### Marketing
`app/public/admin-marketing.html` carga el adaptador modular `admin-marketing-v2.js`.

El adaptador V2:
- alinea tarjetas KPI y embudo con el mismo Histórico V2;
- sustituye Histórico por V2;
- sustituye LTV por cohortes reales V2, sin proyecciones especulativas legacy;
- sustituye Anuncios/Campañas mensuales por V2;
- sustituye Anuncios/Campañas anuales por V2;
- añade una fila compacta de trazabilidad: personas, touchpoints, duplicados, reingresos y reactivaciones;
- deriva años/meses disponibles de datos reales;
- `Ver Leads` usa SQL server-side para paginación 25/50/100, búsqueda, filtro de estado y KPIs completos del filtro;
- exportación CSV conserva el filtro seleccionado.

En modo año, el embudo usa la suma de oportunidades/cohortes mensuales. La fila de trazabilidad muestra aparte las personas únicas reales del año para no confundir personas con oportunidades recurrentes.

## Seguridad de superficie

Las funciones internas de reconstrucción/matching permanecen sin `EXECUTE` para `anon`. Solo las RPC read-only/agregadas necesarias para la UI actual fueron expuestas, coherente con la arquitectura frontend existente.

Las Actions temporales utilizadas para aplicar parches protegidos fueron eliminadas antes de la promoción.

## Integración y CI

- PR #5 → `staging`: merged, CI verde.
- `staging` `3c461f4e...`: CI verde.
- PR #6 KPI/embudo → `staging`: CI verde.
- `staging` final `0cb7a885...`: CI verde.
- PR #7 `staging → main`: CI específico contra `main` verde y mergeable.
- `main`: `6b817a84a9355d95e66aaad90e1ffef73830787c`.
- Se añade `main` al trigger `push` de Ascenda CI como hardening post-deploy, para que futuros merges productivos tengan verificación posterior además del CI del PR.

El regression SQL combinado completo puede exceder el statement timeout por costo acumulado; los gates críticos se validan individualmente y el suite debe dividirse en checks independientes en una fase posterior.

## Post-deploy / observabilidad

- El asset `app/public/admin-marketing-v2.js` está presente en `main`.
- El entorno actual de ChatGPT no logra resolver por DNS el hostname Railway conocido y GitHub App no tiene permiso para listar deployments. Por ello la entrega en Railway no se declara verificada por HTTP desde este entorno.
- `aos_marketing_traceability_health_v2` muestra 0 `lead_id_origen` en el histórico previo al cutover; esto es esperado porque no se hizo backfill.
- La primera validación operativa pendiente es comprobar nuevas llamadas/citas creadas después del deploy y confirmar cobertura de `lead_id_origen` cuando haya tráfico real.

## Follow-ups abiertos

1. Confirmar Railway/asset desde un entorno con acceso al hostname o mediante evidencia del navegador.
2. Verificar primeras llamadas/citas nuevas con `lead_id_origen` cuando exista tráfico real.
3. Propagar `lead_id_origen` al reabrir seguimientos legacy si se confirma necesario (`aos_get_seguimientos`).
4. Dividir regression SQL pesado en checks independientes.
5. Importar/integrar catálogo real de Meta antes de afirmar anuncios activos con 0 leads.

## Rollback operativo

Ante regresión de UI/código:
- revertir el merge productivo `6b817a84...` o retirar el bootstrap V2;
- Call Center puede volver a `aos_siguiente_lead` sin borrar columnas ni datos nuevos.

Ante incidente de base de datos:
- no borrar columnas ni funciones como primera respuesta;
- dejar de consumir V2. Las columnas añadidas son nullable y backward-compatible.
