# ASCENDA OS — Marketing / Funnel Data Quality Baseline

**Fecha:** 2026-08-12  
**Scope:** Leads → Llamadas → Agenda → Ventas.  
**Regla:** este documento identifica anomalías y pérdidas de contexto. No autoriza correcciones masivas automáticas.

## 1. Calidad estructural observada

### Leads (`aos_leads`)

- 5,369 filas observadas.
- Teléfono/`numero_limpio` faltante: 0.
- Tratamiento faltante: 0.
- Fecha faltante: 0.
- Anuncio faltante: 15.

Conclusión: la fuente de leads tiene buena completitud para identidad, tratamiento y fecha. El anuncio requiere un control de importación para evitar nuevas filas sin creativo/origen.

### Llamadas (`aos_llamadas`)

- 34,047 filas observadas.
- Teléfono faltante: 0.
- Tratamiento faltante: 3,227.
- Anuncio faltante: 29,833.
- `hora_llamada`: presente y con formato válido en el histórico observado.

Conclusión: `aos_llamadas.anuncio` y `tratamiento` no son fuentes históricas suficientes por sí solas. El motor V2 debe usar relaciones por ID y reconstrucción con confidence.

### Agenda (`aos_agenda_citas`)

- 2,912 filas observadas en la baseline.
- Teléfono faltante: 25.
- Tratamiento faltante: 88.
- `origen_cita` faltante: 333.
- `venta_id_match`: históricamente sin poblar.
- 150 citas figuran `PENDIENTE` con fecha anterior al día de la baseline.

Las 150 pendientes vencidas NO se corrigen automáticamente. Pueden representar estados no cerrados, no-show no tipificado, reprogramaciones no reflejadas u otras situaciones operativas.

### Ventas (`aos_ventas`)

- 1,271 filas observadas en la baseline.
- Teléfono faltante: 0.
- Tratamiento faltante: 0.
- Asesor faltante: 0.
- Fecha faltante: 0.

Conclusión: Ventas es relativamente completa como fuente comercial, aunque la importación por Excel históricamente no conserva siempre el vínculo explícito con cita/atención.

## 2. Corrección puntual validada

Se detectó una cita Call Center almacenada accidentalmente en agosto de 2029.

Evidencia disponible:

- fue creada durante una gestión de agosto 2026;
- existía una llamada `CITA CONFIRMADA` de la misma gestión;
- la observación de esa llamada indicaba explícitamente día 05 de agosto y hora 17:00;
- no existía otra cita del mismo paciente que justificara el año 2029.

Se realizó una corrección estricta cambiando únicamente `fecha_cita` de 2029-08-05 a 2026-08-05. Estado, tratamiento, sede y origen se conservaron.

Resultado posterior:

- citas a más de un año futuro: 0.
- no se realizaron otras correcciones de Agenda.

## 3. Contradicciones que NO deben repararse automáticamente

### `NO ASISTIO` + venta el mismo día

Attribution V2 detecta operaciones donde existe una cita Call Center marcada `NO ASISTIO` y, sin embargo, existen ventas del mismo teléfono el mismo día.

Estas filas NO implican necesariamente venta duplicada. Posibles causas:

- estado de cita no actualizado;
- venta realizada fuera del flujo formal de asistencia;
- importación comercial posterior;
- cita distinta/no enlazada;
- inconsistencia operativa.

Tratamiento: marcar anomalía, conservar datos originales y solicitar evidencia antes de modificar estados históricos.

### Reingreso con historia previa

Si una venta ocurre después de un lead del mes pero la persona ya tenía leads anteriores, no se atribuye automáticamente al lead más nuevo. Se requiere cadena de gestión o permanece en revisión.

## 4. Reglas preventivas recomendadas

1. Todo nuevo lead debe conservar `fecha`, hora/timestamp de negocio, tratamiento y anuncio/origen cuando exista.
2. Toda llamada originada desde un lead debe conservar `lead_id_origen`.
3. Toda cita originada por Call Center debe conservar `lead_id_origen` cuando exista.
4. Los nuevos registros deben usar IDs explícitos en lugar de reconstrucciones por teléfono cuando el sistema ya conoce la relación.
5. Una fecha de cita anormalmente futura debe generar advertencia antes de guardar.
6. Una cita `PENDIENTE` vencida debe entrar en una cola operativa de cierre/revisión, no corregirse silenciosamente.
7. Los duplicados técnicos de leads se marcan y excluyen de métricas cuando la firma es inequívoca; no se eliminan físicamente durante esta fase.
8. Los datos clínicos/comerciales contradictorios se preservan y se reportan; la auditoría nunca debe fabricar coherencia.

## 5. Backlog de calidad

- [ ] Diseñar revisión de las 150 citas `PENDIENTE` vencidas por antigüedad/origen/sede.
- [ ] Añadir validación de año/fecha extrema en creación de citas.
- [ ] Reducir nuevos leads sin `anuncio`.
- [ ] Propagar `lead_id_origen` a llamadas/citas/seguimientos nuevos.
- [ ] Medir desde el cutover la cobertura de `lead_id_origen` diaria/semanal.
- [ ] Diseñar relación 1:N cita↔ventas; no depender de `venta_id_match` escalar.
- [ ] Separar anomalías `NO ASISTIO + venta` para revisión humana.
- [ ] Auditar las 25 citas sin teléfono y 88 sin tratamiento antes de cualquier normalización.
