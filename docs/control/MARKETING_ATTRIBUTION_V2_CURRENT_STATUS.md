# ASCENDA OS — Marketing Attribution V2 — Current Status

**Fecha:** 2026-08-12  
**Rama:** `feature/marketing-attribution-v2-foundation`  
**PR:** #5 → `staging` (draft)  
**Producción (`main`):** sin cutover V2

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

Por tanto, hoy existe pipeline de reactivación, pero no revenue histórico de reactivación confirmado.

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

## Frontend implementado en la feature

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
`app/public/admin-marketing.html` solo carga el adaptador modular `admin-marketing-v2.js`.

El adaptador V2:
- mantiene las tarjetas/embudo/gestión existentes;
- sustituye Histórico por V2;
- sustituye LTV por cohortes reales V2, sin proyecciones especulativas legacy;
- sustituye Anuncios/Campañas mensuales por V2;
- sustituye Anuncios/Campañas anuales por V2;
- añade una fila compacta de trazabilidad: personas, touchpoints, duplicados, reingresos y reactivaciones;
- deriva años/meses disponibles de datos reales;
- `Ver Leads` usa SQL server-side para paginación 25/50/100, búsqueda, filtro de estado y KPIs completos del filtro;
- exportación CSV conserva el filtro seleccionado.

## Seguridad de superficie

Las funciones internas de reconstrucción/matching permanecen sin `EXECUTE` para `anon`. Solo las RPC read-only/agregadas necesarias para la UI actual fueron expuestas, coherente con la arquitectura frontend existente.

La Action temporal utilizada para aplicar parches protegidos de frontend fue eliminada antes de integrar a `staging`.

## CI / integración

- Los parches de frontend pasaron `node --check` y `git diff --check` durante la Action de parcheo.
- Los gates SQL críticos fueron ejecutados y validados de forma individual.
- El regression SQL agregado completo excede el statement timeout por costo acumulado; debe dividirse en checks independientes en una fase de CI de base de datos posterior.
- Falta gate final: **Ascenda CI verde sobre el head definitivo de la feature**.
- Solo después de CI verde: merge PR #5 → `staging`.
- `main` y Railway permanecen sin cutover V2 hasta validación posterior.
