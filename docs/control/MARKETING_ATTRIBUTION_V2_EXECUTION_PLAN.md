# ASCENDA OS — MARKETING ATTRIBUTION V2

**Estado:** Plan oficial de ejecución
**Objetivo:** mejorar trazabilidad, atribución, históricos, cohortes y lectura de Marketing sin romper la operación actual ni duplicar fuentes de verdad.
**Principio central:** `numero_limpio` identifica a la persona; cada fila de `aos_leads` identifica un evento/touchpoint de marketing. La atribución debe enlazar eventos reales, no inferirlos por conveniencia.

---

## REGLAS NO NEGOCIABLES

1. No borrar leads repetidos automáticamente.
2. No duplicar tablas core (`aos_leads`, `aos_llamadas`, `aos_agenda_citas`, `aos_ventas`).
3. No reemplazar el panel Marketing actual de golpe.
4. No atribuir una venta anterior al evento de lead.
5. No adjudicar una venta a un nuevo lead si existe evidencia fuerte de que la gestión usó un registro anterior.
6. No forzar atribución histórica cuando la evidencia sea ambigua.
7. Toda atribución histórica tendrá método y nivel de confianza.
8. Los registros nuevos deben conservar relaciones explícitas por ID siempre que sea posible.
9. Los cambios estructurales serán backward-compatible: nuevas columnas nullable, nuevos RPC/versiones paralelas y rollback conocido.
10. Cada fase se valida antes de habilitar la siguiente.

---

# FASE 0 — BASELINE Y PRUEBAS DE CONTROL

## 0.1 Congelar baseline
- GitHub baseline: commit actual de `main` al inicio de la iniciativa.
- Registrar versión de las RPC afectadas.
- Registrar conteos de leads, llamadas, citas y ventas por mes.
- Registrar KPIs Marketing enero→mes actual.

## 0.2 Casos patrón
Crear una batería de casos verificables:
- persona con un solo lead y una venta;
- persona con varios leads en meses distintos y primera compra posterior;
- cliente existente que reingresa por nueva campaña;
- nuevo lead registrado pero gestión realizada desde un lead anterior;
- mismo teléfono con dos anuncios el mismo mes;
- llamada manual sin lead inequívoco;
- venta anterior al nuevo lead;
- múltiples ventas posteriores;
- cita Call Center con una única llamada `CITA CONFIRMADA` cercana;
- caso ambiguo sin evidencia suficiente.

**Gate 0:** no implementar reglas que no puedan probarse contra estos casos.

---

# FASE 1 — DEJAR DE PERDER TRAZABILIDAD FUTURA (P0)

## 1.1 `aos_siguiente_lead`
Corregir la selección para conservar el registro exacto de `aos_leads` que originó la entrega al asesor.

Debe devolver como mínimo:
- `lead_id`;
- `numero_limpio`;
- `fecha`;
- `hora_ingreso`;
- `tratamiento`;
- `anuncio`;
- tier/cola y contexto existente.

No se permite reconstruir posteriormente la ficha con `WHERE numero_limpio = ... LIMIT 1` sin una regla determinista.

## 1.2 Frontend Call Center
`CC.lead` debe conservar:
- `leadId`;
- `num`;
- `trat`;
- `anuncio`;
- `fecha`;
- `horaIngreso`;
- origen/tier si aplica.

La UI visible no cambia.

## 1.3 Enlace Lead → Llamada
Añadir de forma nullable a `aos_llamadas`:
- `lead_id_origen bigint`.

Para nuevos registros generados desde Call Center, guardar el `lead_id` exacto utilizado.
Las llamadas manuales o históricas pueden permanecer `NULL`.

## 1.4 Enlace Lead/Llamada → Cita
Añadir de forma nullable a `aos_agenda_citas`:
- `lead_id_origen bigint`;
- `llamada_id_origen bigint`.

Primero se implementará `lead_id_origen`. `llamada_id_origen` solo se poblará cuando el flujo de guardado pueda retornar de manera segura el ID real de la llamada sin riesgo de duplicación.

## 1.5 Índices
Crear índices sobre los nuevos IDs. No añadir FKs estrictas hasta validar el histórico y los flujos legacy.

**Gate 1:** generar leads de prueba/control y comprobar que nuevos registros mantienen `lead → llamada → cita` sin alterar la UI ni los flujos existentes.

---

# FASE 2 — CORRECCIÓN INMEDIATA DE MARKETING ACTUAL (P0)

## 2.1 `Ver Leads`
Reglas:
- una compra anterior al evento de lead no convierte ese lead en `VENDIDO`;
- si la venta es del mismo día y no hay secuencia temporal suficiente, no afirmar certeza sin una cadena de gestión consistente;
- mostrar `cliente nuevo` vs `cliente existente`;
- mostrar resultado de ese touchpoint, no todo el historial anterior de la persona;
- conservar acceso al historial completo vía Paciente 360.

Agregar:
- total real independiente de paginación;
- páginas;
- selector 25/50/100;
- búsqueda.

## 2.2 Histórico anual
Separar:
- `mes analizado`;
- `horizonte histórico`.

Para año actual: enero→mes actual siempre visible.
Para año pasado: enero→diciembre.
El mes seleccionado solo se resalta y controla los demás bloques del panel.

## 2.3 Universo del histórico
Cada fila mensual debe usar exclusivamente la cohorte de Marketing de ese mes:
- personas únicas;
- touchpoints;
- llamadas atribuibles;
- citas atribuibles;
- asistencias atribuibles;
- conversiones atribuibles;
- revenue atribuible.

No mezclar citas/ventas globales de la clínica.

## 2.4 Campañas / tratamiento
Corregir cualquier subconsulta que compare `anuncio = tratamiento` cuando corresponde `tratamiento = tratamiento`.

**Gate 2:** comparar V1/V2 de enero→mes actual; toda diferencia debe estar explicada por casos concretos.

---

# FASE 3 — MOTOR DE ATRIBUCIÓN PARALELO (P0)

Crear primero una capa read-only (`VIEW`/RPC) llamada provisionalmente `aos_marketing_atribucion_v2`.
No reemplaza las tablas actuales.

Cada resultado debe incluir, cuando exista:
- `numero_limpio`;
- `lead_id`;
- `llamada_id`;
- `cita_id`;
- `venta_id`;
- campaña/anuncio;
- tratamiento de interés;
- tratamiento comprado;
- tipo de cliente;
- tipo de atribución;
- método de match;
- confidence score;
- cohorte;
- offset M0/M+1/M+2...

Tipos de atribución:
- `ADQUISICION`;
- `REACTIVACION`;
- `SEGUIMIENTO_HISTORICO`;
- `ORGANICO_NO_ATRIBUIDO`;
- `SIN_ATRIBUIR`.

Métodos posibles:
- `DIRECT_LEAD_ID`;
- `CALL_CHAIN`;
- `HISTORICAL_UNIQUE_MATCH`;
- `MANUAL_FOLLOWUP`;
- `INFERRED_LOW_CONFIDENCE`.

No sumar dos veces la misma venta en revenue total.

**Gate 3:** el motor nuevo funciona en paralelo y no modifica cifras visibles aún.

---

# FASE 4 — RECONSTRUCCIÓN HISTÓRICA (P0)

## 4.1 Cita ↔ llamada
Para citas `CALL_CENTER`, usar primero evidencia fuerte:
- mismo `numero_limpio`;
- mismo asesor;
- llamada `CITA CONFIRMADA`;
- ventana temporal cercana a `ts_creado`.

Hallazgo inicial: ~95.8% de citas Call Center presentan un match único de llamada dentro de 10 minutos. Esto se volverá a medir en la baseline final.

## 4.2 Llamada ↔ lead
Prioridad:
1. ID explícito, si existe;
2. anuncio/tratamiento/fecha/hora compatibles y un único lead candidato;
3. único lead previo compatible con la gestión;
4. varios candidatos → no forzar; enviar a revisión/confianza baja.

## 4.3 Cita ↔ venta
Utilizar `venta_id_match` solo cuando exista una regla verificable. No autocompletar coincidencias ambiguas.

## 4.4 Confidence
Propuesta inicial:
- 100 = ID explícito;
- 95 = cadena llamada→cita inequívoca + lead inequívoco;
- 80 = evidencia temporal/anuncio/tratamiento fuerte;
- 60 = único candidato razonable pero sin cadena completa;
- <60 = no usar para KPIs oficiales sin revisión.

**Gate 4:** reporte de cobertura, precisión y casos ambiguos antes de persistir backfill alguno.

---

# FASE 5 — REINGRESOS Y DUPLICADOS (P1)

No eliminar 358 registros porque existan 350 personas únicas.

Clasificar touchpoints adicionales como:
- nuevo anuncio;
- nueva campaña/tratamiento;
- reactivación;
- seguimiento;
- duplicado técnico probable.

KPIs separados:
- personas únicas;
- ingresos/touchpoints;
- reingresos;
- duplicados técnicos probables.

Un duplicado técnico solo se excluye de métricas de captación cuando su regla esté demostrada.

---

# FASE 6 — ADQUISICIÓN, REACTIVACIÓN Y SEGUIMIENTO (P1)

## Adquisición
Primera conversión del cliente atribuible a un evento de marketing.

## Reactivación
Cliente ya existente que reingresa por un nuevo touchpoint y cuya nueva gestión puede vincularse a dicho touchpoint.

## Seguimiento histórico
Nueva venta generada a partir de una gestión que utilizó un evento de lead anterior, aunque exista un nuevo lead posterior que no fue el usado.

## Orgánico/no atribuible
Venta sin evidencia suficiente para asignarla a una campaña.

Una venta puede contribuir al LTV de la cohorte original y, si corresponde, ser clasificada como revenue de reactivación en un análisis separado; nunca se duplica en facturación total.

---

# FASE 7 — CAMPAÑAS Y ANUNCIOS (P1)

Mantener panel existente.
Agregar sin reestructurar:
- `Ver todos`;
- buscador;
- orden por leads/citas/conversión/facturación/ROAS;
- paginación;
- anuncios con 0 resultados si existen en fuente/configuración;
- detalle completo por fila.

Separar conceptualmente:
- campaña = origen/intención;
- anuncio = creativo/touchpoint;
- tratamiento de interés = intención;
- tratamiento vendido = compra real.

Esto habilita análisis `intención → compra` sin exigir que campaña y venta tengan el mismo tratamiento.

---

# FASE 8 — COHORTES Y LTV (P1)

Recalcular con atribución validada:
- M0;
- M+1;
- M+2;
- M+3;
- M+4+;
- LTV acumulado;
- ROAS acumulado.

Diferenciar:
- `0` = período ocurrió y no hubo revenue;
- `—` = período todavía no ocurrió.

Mantener:
- LTV de adquisición original;
- revenue de reactivación separado.

---

# FASE 9 — `venta_id_match` Y CADENA COMPLETA (P2)

Activar progresivamente:
`lead_id → llamada_id → cita_id → venta_id`.

No poblar automáticamente si existen múltiples ventas candidatas sin regla suficiente.

Crear auditoría del match:
- método;
- fecha;
- confianza;
- manual/automático;
- versión de algoritmo.

---

# FASE 10 — NUEVOS BLOQUES SIN MOVER EL PANEL EXISTENTE (P2)

Debajo de los bloques actuales, agregar de forma progresiva:

## Touchpoints
- personas únicas;
- ingresos;
- reingresos;
- duplicados probables.

## Atribución
- clientes nuevos;
- reactivados;
- seguimiento histórico;
- sin atribuir.

## Intención → compra
- tratamiento/campaña de interés;
- tratamiento realmente comprado;
- revenue cruzado.

## Revenue de cohorte
- M0/M+1/M+2/M+3;
- acumulado.

---

# FASE 11 — MARKETING INTELLIGENCE (P3)

Solo cuando la atribución esté validada:
- calidad de campaña;
- anomalías;
- campañas con alto CPL pero alto LTV;
- anuncios con buen lead volume y baja asistencia;
- revenue de cross-sell;
- clientes de alta calidad adquiridos;
- tiempo de conversión;
- oportunidades de reactivación;
- ROAS de adquisición;
- ROAS acumulado;
- recomendaciones IA explicables.

No mezclar ventas globales de la clínica con Marketing Intelligence.

---

# LOOP OFICIAL DE IMPLEMENTACIÓN

Para cada fase/subfase:

1. **READ** — leer código/RPC/schema implicado.
2. **BASELINE** — guardar métricas antes del cambio.
3. **HYPOTHESIS** — definir exactamente qué error corrige.
4. **IMPACT** — listar tablas, RPC, UI, triggers y consumidores.
5. **DESIGN** — preferir cambios backward-compatible.
6. **DRY RUN** — ejecutar SQL de comparación sin escribir.
7. **IMPLEMENT** — rama feature + migration versionada + código.
8. **STATIC TESTS** — sintaxis/CI.
9. **DATA TESTS** — casos patrón + enero→mes actual.
10. **REGRESSION** — verificar ventas, comisiones, agenda, Call Center y pacientes si comparten objetos.
11. **REVIEW** — analizar diferencias V1 vs V2.
12. **DEPLOY** — solo tras gates verdes.
13. **VERIFY PROD** — reconsultar DB y UI.
14. **OBSERVE** — revisar nuevos registros generados.
15. **DOCUMENT** — actualizar este documento y baseline.
16. **ROLLBACK** — si cualquier gate falla, revertir código/lógica; las columnas nullable pueden permanecer sin afectar operación.

No se avanza al siguiente gate con discrepancias sin explicar.

---

# CRITERIOS DE CIERRE

Marketing Attribution V2 se considera terminado cuando:
- nuevos leads conservan ID a través de Call Center;
- `Ver Leads` no atribuye compras antiguas;
- histórico anual no depende del mes seleccionado;
- histórico usa únicamente cohortes Marketing;
- personas únicas y touchpoints están separados;
- reingresos están clasificados;
- adquisición/reactivación/seguimiento están diferenciados;
- campañas y anuncios muestran todos los registros relevantes;
- cohortes/LTV usan atribución validada;
- `venta_id_match` funciona cuando existe certeza;
- ninguna venta se duplica en revenue total;
- casos ambiguos quedan explícitamente sin atribuir o en revisión;
- todas las nuevas reglas están versionadas y documentadas.
