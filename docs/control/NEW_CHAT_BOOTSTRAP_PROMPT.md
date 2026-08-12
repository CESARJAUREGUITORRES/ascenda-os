# Prompt de arranque — Continuidad ASCENDA OS

Copia y pega este contenido al iniciar una nueva conversación:

---

Quiero continuar un trabajo productivo y delicado sobre **ASCENDA OS**. Esta conversación es una continuación directa de otra sesión extensa. No empieces desde cero ni inventes contexto.

## PASO 1 — RECUPERA EL CONTEXTO CANÓNICO

Usa el conector de GitHub y trabaja sobre:

`CESARJAUREGUITORRES/ascenda-os`

Primero lee completamente, en este orden:

1. `AGENTS.md`
2. `SECURITY.md`
3. todos los documentos vigentes dentro de `docs/control/`
4. especialmente `docs/control/ASCENDA_CONTINUITY_CURRENT.md`
5. `docs/control/NEW_CHAT_BOOTSTRAP_PROMPT.md`

Trata `ASCENDA_CONTINUITY_CURRENT.md` como el handoff principal de la sesión anterior, pero verifica el estado vivo antes de cualquier escritura.

## PASO 2 — RECUPERA LOS ARCHIVOS FUENTE

En Files/Library busca la carpeta privada:

`/ASCENDA/AuditoriaVentas2026/`

Debe contener:

- `VENTAS_2026_01_ENERO.csv`
- `VENTAS_2026_02_FEBRERO.csv`
- `VENTAS_2026_03_MARZO.csv`
- `VENTAS_2026_04_ABRIL.csv`
- `VENTAS_2026_05_MAYO.csv`
- `VENTAS_2026_06_JUNIO.csv`
- `VENTAS_2026_07_JULIO.csv`

Estos archivos contienen PII y NO deben subirse a GitHub. Úsalos únicamente como fuente privada de conciliación.

Si Library no devuelve los archivos, no reconstruyas datos desde memoria ni desde el documento de handoff: pídeme que vuelva a subir únicamente el CSV del mes en curso.

## PASO 3 — CONECTA AL SISTEMA REAL

Supabase producción de ASCENDA:

`ituyqwstonmhnfshnaqz`

Antes de modificar cualquier dato consulta el estado actual, porque ASCENDA sigue operando en producción y pueden haberse registrado ventas nuevas después del último handoff.

No despliegues, borres ni corrijas datos por intuición.

## REGLA OFICIAL DE FUENTES DE VERDAD

Para la conciliación histórica de ventas 2026:

### Transacción
El CSV maestro del usuario es la fuente de verdad para:
- fecha;
- existencia de la venta;
- tratamiento;
- descripción;
- método de pago;
- monto;
- estado de pago;
- asesor;
- ATENDIO;
- sede.

### Identidad
ASCENDA ya corregido es prioritario para:
- DNI;
- celular;
- numero_limpio;
- identidad del paciente.

Esto es intencional: los CSV consolidados tienen algunos errores de autofill de Google Sheets en DNI/celular. No sobrescribas una identidad consolidada de ASCENDA con un valor sospechoso del CSV.

Si ASCENDA tampoco permite resolver la identidad de forma inequívoca, marca el caso `IDENTITY_REVIEW` y no inventes ni propagues el dato.

## PRODUCTOS

Cuando `TRATAMIENTO = COMPRA DE PRODUCTO`, la columna `DESCRIPCIÓN` contiene el nombre real o la descripción comercial del producto.

No elimines ni reemplaces `descripcion` original. Más adelante construiremos una capa de producto canónico tomando el catálogo/inventario de ASCENDA como fuente de nombres reales y un mapa de aliases.

El usuario posteriormente validará unidades, adelantos/saldos y casos donde dos líneas puedan representar un solo producto físico.

## ESTADO DE LA AUDITORÍA ENERO-JULIO

Los 7 CSV fuente suman:

**1,192 operaciones / S/498,424.47**

Baseline histórico observado en Supabase durante la auditoría:

**1,203 operaciones / S/503,994.07**

Diferencia observada:

**+11 operaciones / +S/5,569.60 en Supabase**

Objetivos por mes:

- Enero: **191 / S/91,029.60**
- Febrero: **166 / S/78,734.62**
- Marzo: **156 / S/63,681.65**
- Abril: **152 / S/59,496.95**
- Mayo: **179 / S/79,225.85**
- Junio: **159 / S/61,140.75**
- Julio: **189 / S/65,115.05**

Lee `ASCENDA_CONTINUITY_CURRENT.md` para los hallazgos específicos de cada mes.

## MISIÓN ACTUAL

Estamos trabajando **mes por mes** y el siguiente objetivo es **ENERO 2026**.

No empieces febrero hasta que enero quede completamente conciliado, validado y documentado.

### Objetivo de enero

Dejar enero exactamente en:

**191 operaciones / S/91,029.60**

sin contaminar DNI/celular ni romper Ventas, Comisiones, Caja, Pacientes, Marketing u otros consumidores.

### Hallazgos de enero ya conocidos

- Hay desplazamientos de fecha alrededor del 08/01 y 09/01 que afectan a Jacquelina y Lorena; vuelve a identificar IDs exactos con CSV + DB antes de actualizar.
- Una venta de Yuli por S/3,150 fue observada fragmentada como S/3,000 + S/150.
- Falta una venta de Janet del 30/01 por S/99 en el baseline observado.
- El campo `ATENDIO` estaba vacío en las 191 ventas de enero de Supabase, aunque el CSV contiene ese dato.
- Hay diferencias de tratamiento/campos en algunas ventas.
- Hay errores potenciales de autofill en identidad; para DNI/celular gana ASCENDA salvo evidencia de que ASCENDA también esté errado.

No asumas que estos IDs o valores siguen iguales: confirma el estado actual antes de escribir.

## PROCEDIMIENTO OBLIGATORIO PARA ENERO

1. Recupera `VENTAS_2026_01_ENERO.csv` desde Library.
2. Consulta todas las ventas actuales de enero en `aos_ventas`.
3. Genera un snapshot/read-only de enero antes de cambios.
4. Haz matching venta-a-venta. No uses simplemente el orden de filas.
5. Construye una tabla de decisiones por `aos_ventas.id`:
   - KEEP
   - UPDATE
   - INSERT
   - DELETE
   - MERGE
   - SPLIT
   - IDENTITY_REVIEW
6. Para cada UPDATE/DELETE/MERGE/SPLIT comprueba dependencias en Agenda, Atenciones, Caja, Comisiones, Inventario, Pacientes, sesiones, planes, alertas, Marketing y cualquier FK/relación semántica relevante.
7. Conserva identidad ASCENDA cuando exista conflicto de DNI/celular.
8. Aplica CSV como verdad transaccional.
9. Prepara rollback exacto antes de escribir.
10. Muéstrame un Impact Report con:
   - conteo antes/después;
   - facturación antes/después;
   - IDs afectados;
   - campos modificados;
   - inserts/deletes;
   - dependencias;
   - riesgos;
   - rollback.
11. Si el análisis es inequívoco, procede con una transacción protegida SOLO PARA ENERO.
12. La transacción debe abortar si no termina exactamente en:

   **191 ventas / S/91,029.60**

13. Después valida:
   - total mensual;
   - total diario;
   - sede;
   - métodos de pago;
   - servicios/productos;
   - asesor;
   - estado de pago;
   - ATENDIO;
   - faltantes;
   - extras;
   - fragmentaciones/fusiones;
   - efectos en Ventas/Comisiones/Marketing/Pacientes.
14. Marca enero como `VALIDADO` solamente si todas las comprobaciones pasan.
15. Actualiza `docs/control/ASCENDA_CONTINUITY_CURRENT.md` con el resultado final de enero para que la siguiente conversación continúe desde un estado canónico actualizado.

## RESTRICCIONES

- No tocar `main` directamente para código salvo instrucción expresa y riesgo entendido.
- No hacer una corrección masiva enero-julio.
- No borrar posibles duplicados solo porque se parezcan; si también existen en CSV pueden ser compras legítimas repetidas.
- No normalizar productos todavía destruyendo `descripcion` original.
- No corregir DNI/celular desde CSV si ASCENDA ya tiene una identidad más fiable.
- No exponer PII, secretos ni tokens en respuestas o GitHub.
- No declarar éxito por cuadrar solo el total; un mes debe cuadrar también por día y campos operativos.

## CONTEXTO DEL SISTEMA QUE DEBES TENER PRESENTE

ASCENDA OS es un sistema productivo real con frontend estático en `app/public`, backend Node/Railway en `app/server.js`, Supabase/Postgres con lógica fuerte en RPC/triggers y módulos interdependientes de Marketing, Call Center, Agenda, Pacientes, Ventas, Comisiones, Caja, Inventario y KronIA.

Marketing fue estabilizado recientemente con controlador V4/V4.2. Histórico anual debe ser independiente del filtro mensual. LTV/Histórico tuvieron timeouts por concurrencia. Importar ventas tiene protección de idempotencia por lote y confirmación previa, pero está pendiente reemplazar la confirmación nativa por un modal profesional azul/blanco ASCENDA.

No confundas facturación total de Ventas con facturación M0 de Marketing: Marketing solo atribuye ventas a cohortes de leads.

## RESULTADO QUE QUIERO DE TU PRIMERA RESPUESTA

Antes de modificar nada, respóndeme con:

1. confirmación de que leíste `AGENTS.md`, `SECURITY.md` y `ASCENDA_CONTINUITY_CURRENT.md`;
2. confirmación de que encontraste el CSV de enero en Library;
3. baseline vivo actual de enero en Supabase;
4. diferencias exactas entre CSV enero y Supabase;
5. mapa de acciones KEEP/UPDATE/INSERT/DELETE/MERGE/SPLIT/IDENTITY_REVIEW;
6. Impact Report y rollback;
7. solo entonces procede con la reconciliación de enero si el análisis es inequívoco.

Esta es una continuación de producción. Prioriza exactitud, trazabilidad y reversibilidad sobre velocidad.

---
