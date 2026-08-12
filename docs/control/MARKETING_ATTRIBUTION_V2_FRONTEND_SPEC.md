# ASCENDA OS — Marketing Attribution V2 — Frontend Cutover Spec

**Scope:** mínimo, backward-compatible, sin rediseñar UI.

## 1. Call Center — `app/public/calls.js`

### 1.1 Carga de lead

Cambiar únicamente la RPC de `loadLead()`:

- de `aos_siguiente_lead`
- a `aos_siguiente_lead_v2`

Conservar toda la lógica de errores/retry actual.

### 1.2 Contexto que debe conservar `CC.lead`

Además de los campos existentes, conservar:

- `leadId`: `res.lead.id || null`
- `anuncio`: `res.lead.anuncio || ''`
- `horaIngreso`: `res.lead.horaIngreso || ''`
- `source`: `res.lead.source || 'UNRESOLVED'`

No inventar `leadId` si V2 devuelve `null`.

### 1.3 Display de anuncio

Usar `CC.lead.anuncio` / `res.lead.anuncio` como fuente. No depender de `res.anuncio.nombre`, porque el anuncio pertenece al objeto `lead` de la RPC V2.

No cambiar layout.

### 1.4 Registro de llamada normal

En el objeto `row` que se inserta en `aos_llamadas`, añadir:

- `lead_id_origen: CC.lead && CC.lead.leadId ? CC.lead.leadId : null`
- conservar `anuncio: CC.lead.anuncio || ''`

Si `leadId` es NULL, la llamada debe seguir guardándose exactamente como hoy.

### 1.5 CITA CONFIRMADA

En `rowL` (`aos_llamadas`) añadir:

- `lead_id_origen`
- `anuncio`

En `rowC` (`aos_agenda_citas`) añadir:

- `lead_id_origen`

NO cambiar todavía `Promise.all` ni intentar rellenar `llamada_id_origen`; se hará en una fase posterior. El `lead_id_origen` compartido ya permite enlazar inequívocamente llamada y cita nuevas cuando existe evidencia.

### 1.6 Seguimiento

En la llamada de seguimiento (`rowL`) añadir `lead_id_origen`.

Al crear un nuevo `aos_seguimientos`, añadir `lead_id_origen` si existe.

Al reprogramar un seguimiento existente, preservar su `lead_id_origen`; no reemplazarlo por NULL.

### 1.7 Flujos sin lead

Seguimiento/paciente activo/no-asistió/rebarrido pueden devolver `leadId=null`.

Esto es válido. No buscar el lead más reciente como fallback en frontend.

## 2. Marketing — `app/public/admin-marketing.html`

### 2.1 Ver Leads

Cambiar la RPC del modal de `aos_marketing_leads_detalle` a `aos_marketing_leads_detalle_v2`.

La UI debe distinguir:

- lead/touchpoint vendido;
- cantidad de operaciones (`ventas_total`);
- facturación (`monto_facturado`).

No usar historia anterior al touchpoint.

### 2.2 Paginación

La primera iteración puede seguir cargando el resultado completo de V2 y paginar en cliente si el volumen mensual sigue siendo manejable.

Objetivo de UI:

- total real de filas;
- selector 25 / 50 / 100;
- Anterior / Siguiente;
- buscador por teléfono, tratamiento, anuncio o estado;
- KPIs del modal calculados sobre el dataset completo, no solo la página visible.

### 2.3 Histórico

NO conectar `aos_marketing_historico_v2_preview` hasta que se publique un wrapper/permiso explícito de lectura.

Cuando se habilite:

- siempre mostrar enero → mes actual del año seleccionado;
- el filtro de mes solo resalta la fila seleccionada;
- `leads` = personas únicas;
- mostrar touchpoints/reingresos en información adicional, no sustituyendo personas únicas;
- `ventas` = operaciones M0 de la cohorte, NO ventas globales de la clínica;
- `fact` = revenue M0;
- `fact_acumulado` = M0 + revenue futuro atribuido/LTV según definición aprobada.

## 3. No hacer en este cutover

- no cambiar `main` directamente;
- no cambiar layout general de Marketing;
- no activar bloques nuevos de LTV/Attribution todavía;
- no hacer backfill histórico desde frontend;
- no asignar lead al flujo cuando RPC devuelve `UNRESOLVED`;
- no rellenar `venta_id_match`;
- no cambiar Auth/RLS;
- no cambiar creación de cita a una nueva transacción/RPC todavía.

## 4. Tests mínimos antes de PR

1. `calls.js` pasa `node --check`.
2. `aos_siguiente_lead_v2` conserva número/tier respecto a V1 en pruebas con ROLLBACK.
3. Caso con lead directo guarda `lead_id_origen` en payload.
4. Caso `UNRESOLVED` sigue guardando llamada/cita con NULL sin error.
5. `Ver Leads` agosto: 2 leads vendidos, 6 operaciones, S/1,045.
6. CI verde.
7. Ningún archivo fuera de scope funcional cambia.

## 5. Rollback

Frontend:

- volver llamadas RPC a V1;
- quitar campos `lead_id_origen` de payload (las columnas nullable pueden permanecer sin impacto);
- volver `Ver Leads` a RPC V1.

DB:

- no eliminar columnas durante rollback funcional;
- mantener datos de trazabilidad ya capturados porque son aditivos.
