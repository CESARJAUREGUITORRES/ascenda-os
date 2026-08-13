# ASCENDA OS — Continuidad canónica de trabajo

**Fecha de corte:** 2026-08-12  
**Repositorio:** `CESARJAUREGUITORRES/ascenda-os`  
**Supabase producción:** `ituyqwstonmhnfshnaqz`  
**Rama de trabajo preferida:** `staging`  
**Producción:** `main`

> Este documento existe para permitir continuidad entre conversaciones de ChatGPT/Codex sin depender de memoria de chat. Debe leerse junto con `AGENTS.md`, `SECURITY.md` y todos los documentos vigentes de `docs/control/`.

---

## 1. Regla de seguridad y de trabajo

ASCENDA OS es un sistema productivo real. No modificar `main`, datos financieros, identidad, Auth/RLS, RPC privilegiadas, caja, comisiones, pacientes o marketing sin análisis de impacto y rollback.

Flujo para cambios de riesgo:

`captura/idea -> archivo productivo -> JS/backend -> RPC -> tablas -> triggers -> consumidores -> Impact Report -> cambio mínimo -> validación -> CI -> producción -> verificación`

Para datos financieros históricos, trabajar **mes por mes**, nunca hacer una corrección masiva enero-julio en una sola transacción.

---

## 2. Arquitectura productiva resumida

- Frontend productivo: `app/public/*.html` + JavaScript público.
- Backend Node/Railway: `app/server.js`.
- Base principal: Supabase/Postgres, con gran parte de lógica de negocio en RPC/triggers.
- `src/` y varias carpetas históricas son legacy y no deben asumirse como producción.
- Marketing, Call Center, Agenda, Pacientes, Ventas, Comisiones, Caja, Inventario y KronIA comparten datos y dependencias.
- El teléfono normalizado (`numero_limpio`) es una clave semántica importante, pero para conciliación de identidad histórica no debe sobrescribirse ciegamente.

---

## 3. Estado reciente de Marketing / Ventas / Importar

### Marketing
Se estabilizó el panel de Marketing con un controlador frontend V4/V4.2 reinicializable, eliminando wrappers/parches V3 acumulados que provocaban bloques vacíos al remontar el SPA.

Problemas encontrados y tratados:
- Histórico y LTV podían fallar con `57014 statement timeout` por concurrencia de RPC pesadas.
- Se escalonaron cargas pesadas y se optimizaron consultas/índices.
- Histórico anual debe ser independiente del mes seleccionado: al escoger marzo, debe seguir mostrando ENE-AGO del año disponible; el mes solo cambia la cohorte seleccionada.
- Se redondearon KPIs/porcentajes/ROAS para evitar decimales largos.
- Trazabilidad V4, Atribución/reingresos e Intención→Compra forman parte del panel actual.

**Regla importante:** `Facturación Marketing M0` NO equivale a `Facturación total de Ventas`. Marketing M0 solo incluye ventas atribuibles a la cohorte de leads correspondiente.

### Ventas agosto — incidente reconciliado
Se detectó una diferencia exacta de S/300 entre el Excel maestro y ASCENDA. Se identificaron dos ventas adicionales en Supabase que no estaban en la fuente contable y se corrigieron. También se corrigió un lote con fechas 08/08 almacenadas como 09/08.

Después de esa conciliación, agosto quedó en **71 ventas / S/53,274.80** antes de que el usuario continuara ingresando nuevas ventas posteriores. Siempre consultar el valor actual antes de comparar nuevamente.

### Importar ventas
Se añadió protección de idempotencia por lote exacto en backend y una confirmación previa del lote. El frontend todavía necesita, como mejora visual pendiente, reemplazar el `window.confirm()`/confirmación nativa por un modal profesional ASCENDA (azul/blanco) que muestre fecha, sede, filas, total y validaciones antes de insertar.

---

## 4. Fuente de verdad — reglas oficiales de conciliación 2026

### 4.1 Transacción/venta
Para reconciliar ventas históricas enero-julio 2026:

**CSV maestro del usuario = fuente de verdad transaccional**, especialmente para:
- fecha;
- tratamiento;
- descripción;
- método de pago;
- monto;
- estado de pago;
- asesor;
- `ATENDIO`;
- sede;
- existencia o ausencia de la operación.

### 4.2 Identidad
**ASCENDA ya corregido = fuente prioritaria de identidad** para:
- DNI;
- celular;
- `numero_limpio`;
- identidad consolidada en Pacientes/Filiación.

Razón: al consolidar los CSV aparecieron patrones de autofill/series en Google Sheets en celulares/DNI. No sobrescribir una identidad ya consolidada en ASCENDA usando una variante sospechosa del CSV.

Si ASCENDA tampoco resuelve la identidad con certeza, marcar `IDENTITY_REVIEW`; no inventar ni propagar el dato.

### 4.3 Productos
Cuando `TRATAMIENTO = COMPRA DE PRODUCTO`, el producto real se obtiene principalmente de `DESCRIPCIÓN`.

No destruir ni reemplazar `descripcion` original. En una fase posterior se construirá normalización de producto usando catálogo/inventario ASCENDA como fuente canónica de nombres y un mapa de aliases.

Ejemplos de alias observados: Beauty Maker / Beautymaker / Beauty Maker Promo; Lifting B / Lifting-B / Liftin B; Zinc / Zinc 50MG / Sulfato de Zinc 50 MG; etc.

Pendiente posterior: el usuario proporcionará/validará equivalencias de unidades y casos de adelanto/saldo para saber cuándo varias líneas representan 1 producto físico.

---

## 5. Archivos fuente privados persistentes

**NO están en GitHub por contener PII.** Fueron copiados a la Library privada de ChatGPT en:

`/ASCENDA/AuditoriaVentas2026/`

Archivos:
- `VENTAS_2026_01_ENERO.csv`
- `VENTAS_2026_02_FEBRERO.csv`
- `VENTAS_2026_03_MARZO.csv`
- `VENTAS_2026_04_ABRIL.csv`
- `VENTAS_2026_05_MAYO.csv`
- `VENTAS_2026_06_JUNIO.csv`
- `VENTAS_2026_07_JULIO.csv`

En una conversación nueva, buscar estos archivos con Files/Library. Si por cualquier motivo no son accesibles desde ese entorno, pedir al usuario re-subir solo el mes que se esté conciliando; no reconstruir filas desde este documento.

---

## 6. Auditoría global enero-julio ya realizada (read-only)

Fuente CSV total enero-julio:

**1,192 operaciones / S/498,424.47**

Baseline Supabase observado durante auditoría:

**1,203 operaciones / S/503,994.07**

Diferencia global en ese momento:

**+11 operaciones / +S/5,569.60 en Supabase**

### Mes por mes

| Mes | CSV fuente | Supabase observado | Diferencia inicial |
|---|---:|---:|---:|
| Enero | 191 / S/91,029.60 | 191 / S/90,930.60 | -S/99 |
| Febrero | 166 / S/78,734.62 | 179 / S/84,486.22 | +13 / +S/5,751.60 |
| Marzo | 156 / S/63,681.65 | 155 / S/63,520.65 | -1 / -S/161 |
| Abril | 152 / S/59,496.95 | 152 / S/59,496.95 | total cuadra |
| Mayo | 179 / S/79,225.85 | 181 / S/79,304.85 | +2 / +S/79 |
| Junio | 159 / S/61,140.75 | 156 / S/61,139.75 | -3 / -S/1 |
| Julio | 189 / S/65,115.05 | 189 / S/65,115.05 | total cuadra |

Estos números son un baseline histórico. **Antes de escribir, volver a consultar Supabase**, porque el sistema sigue operativo y puede haber nuevos cambios.

---

## 7. Hallazgos conocidos por mes

### Enero — siguiente mes a ejecutar
Objetivo final exacto de conciliación financiera:

**191 operaciones / S/91,029.60**

Hallazgos ya detectados:
- Lote de Jacquelina correspondiente al 08/01 fue observado almacenado como 09/01; una venta de Lorena presentó el desplazamiento inverso 09/01 -> 08/01. Recalcular y confirmar IDs exactos desde CSV+DB antes de actualizar.
- Una operación de Yuli por S/3,150 aparece fragmentada en Supabase como S/3,000 + S/150. Confirmar matching exacto antes de consolidar.
- Falta una venta de Janet del 30/01 por S/99 en el baseline observado.
- `ATENDIO` estaba vacío en las 191 ventas de enero en Supabase, mientras el CSV contiene ese campo. Debe rellenarse solo después de matching inequívoco venta-a-venta.
- Existen algunos tratamientos/campos que no coinciden entre CSV y DB. Aplicar regla: CSV gana en transacción; ASCENDA gana en identidad.
- No tocar DNI/celular de una venta de enero solo porque difiera del CSV; validar primero Pacientes/Filiación/historial.

**ESTADO:** enero todavía NO debe considerarse conciliado ni cerrado hasta completar la transacción y post-validación.

### Febrero
Hallazgos conocidos:
- 11 ventas extra del 06/02 por S/5,751.60 no existen en CSV maestro (IDs observados 883-893; revalidar antes de borrar).
- S/208.95 dividido como S/199 + S/9.95.
- S/105 dividido como S/99 + S/6.
- dos filas del 26/02 fueron observadas como 25/02.

Objetivo: **166 / S/78,734.62**.

### Marzo
- diferencia de S/40 en Hidrofacial antiacné de Alan;
- diferencia de S/2 en Lifting-B de Miriam;
- falta una compra Lymphdiaral S/119 de Marisa.

Objetivo: **156 / S/63,681.65**.

### Abril
Cuadra en filas y monto, pero no marcar validado hasta comparar campos operativos/identidad. No eliminar operaciones idénticas si también existen en CSV; pueden ser ventas legítimas repetidas.

Objetivo: **152 / S/59,496.95**.

### Mayo
- duplicado S/99 de Nancy observado;
- venta S/733.95 fragmentada como S/699 + S/34.95;
- Amber Succínico de Jacquelina observado en S/500 vs S/520 fuente.

Objetivo: **179 / S/79,225.85**.

### Junio
- duplicación/sustitución de productos el 03/06;
- venta combinada que debe ser dos operaciones el 13/06;
- falta producto S/189 el 15/06;
- cinco ventas observadas desplazadas 18/06 -> 20/06;
- venta S/269 observada fusionando S/199 + S/70.

Objetivo: **159 / S/61,140.75**.

### Julio
Cuadra en filas y monto. Pendiente validación completa de campos/identidad antes de cerrarlo.

Objetivo: **189 / S/65,115.05**.

---

## 8. Patrón de errores históricos descubierto

Los errores no parecen aleatorios. Patrones detectados:
- importaciones duplicadas;
- fecha única aplicada a todo un lote;
- ventas fragmentadas artificialmente en dos líneas;
- ventas fusionadas que deberían ser dos líneas;
- operaciones faltantes/extra;
- autofill de celulares/DNI en CSV consolidado;
- pérdida de `ATENDIO` en importaciones históricas;
- ausencia de normalización canónica de productos.

Corregir causas y prevenir recurrencia, no solo cuadrar totales.

---

## 9. Procedimiento obligatorio para ENERO

1. Leer `AGENTS.md`, `SECURITY.md`, `docs/control/` y este documento.
2. Recuperar `VENTAS_2026_01_ENERO.csv` desde Library.
3. Hacer nueva lectura read-only de todas las ventas enero en `aos_ventas` y snapshot previo.
4. Construir matching venta-a-venta. No usar simple orden de filas como identidad del registro.
5. Para identidad, conservar ASCENDA salvo evidencia de que ASCENDA también está errado.
6. Para transacción, aplicar CSV maestro.
7. Preparar tabla de acciones exactas por `aos_ventas.id`: KEEP / UPDATE / INSERT / DELETE / MERGE / SPLIT / IDENTITY_REVIEW.
8. Verificar dependencias de cada registro a modificar/eliminar en Agenda, Atenciones, Caja, Comisiones, Inventario, Pacientes, sesiones, planes, alertas y Marketing.
9. Crear rollback exacto de cada cambio antes de escribir.
10. Ejecutar una transacción protegida para enero únicamente.
11. Abortarla si el resultado no termina exactamente en **191 ventas / S/91,029.60**.
12. Validar además por día, sede, método de pago, servicio/producto, asesor, estado y `ATENDIO`.
13. Verificar panel Ventas y consumidores (Comisiones/Marketing) después del cambio.
14. Documentar enero como `VALIDADO` solo si todos los checks pasan.
15. No iniciar febrero hasta cerrar enero.

---

## 10. Próximas mejoras después de enero-julio

- Modal profesional ASCENDA para confirmación de importación de ventas (reemplazar confirm nativo).
- Capa de control de calidad del panel Ventas: meses conciliados, inconsistencias, posibles duplicados, identidad pendiente.
- Normalización de productos: conservar `descripcion_raw`, mapear a producto canónico del inventario/catálogo y luego modelar cantidad/unidades/adelanto-saldo con validación del usuario.
- Identity Resolution para Pacientes/Filiación usando DNI + teléfono + historial + leads + llamadas + citas + ventas, sin fusionar automáticamente casos ambiguos.
- Optimización adicional de Marketing para evitar recomputar historia completa en cada apertura; preferir métricas incrementales/materializadas cuando la reconciliación financiera esté cerrada.

---

## 11. Criterio de cierre por mes

Un mes solo queda **VALIDADO** cuando se cumple:

- filas CSV = filas Supabase;
- monto CSV = monto Supabase;
- diferencias diarias = 0;
- faltantes = 0;
- extras = 0;
- fragmentaciones/fusiones conocidas resueltas;
- campos transaccionales reconciliados;
- identidad no contaminada;
- dependencias críticas verificadas;
- paneles consumidores coherentes;
- rollback y auditoría documentados.

---

## 12. Nota para el siguiente agente/chat

No confíes únicamente en números escritos en este documento: son el último estado conocido. **Verifica el estado vivo en GitHub, Supabase y Library antes de cada escritura.** Este archivo sirve para recuperar intención, reglas, hallazgos y secuencia de trabajo, no para sustituir la comprobación del sistema productivo.
