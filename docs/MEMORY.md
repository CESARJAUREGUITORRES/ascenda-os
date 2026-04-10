# MEMORY.md — AscendaOS v1 · CreActive OS
## Estado del proyecto · Última actualización: Abril 2026

---

## CONTEXTO ACTIVO — Para iniciar sesión nueva pega esto como primer mensaje

```
Proyecto: AscendaOS v1 — CRM Clínica Zi Vital
Stack: Google Apps Script + Google Sheets + WebApp HTML/CSS/JS
Sheet ID: 1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM
Deploy: script.google.com/macros/s/AKfycbyVoliSxxF3gJTX71Yi3tTd7L1sAUSyFj3HPmBYVaFCGKy69uWLzJV6nDcYjVBn-L5/exec
Repo: github.com/CESARJAUREGUITORRES/ascenda-os
```

---

## 1. PROYECTO Y EQUIPO

**Producto activo:** AscendaOS v1 — CRM para Clínica Zi Vital
**Empresa:** CreActive OS
**Stack:** Google Apps Script + Google Sheets + WebApp HTML/CSS/JS
**Fase actual:** Bloque 2.5 completado → iniciando Bloque 3 (Capa 0 primero)

**Equipo operativo:**
- Asesores: WILMER, RUVILA, MIREYA, SRA CARMEN
- Admin: CESAR
- Sedes: SAN ISIDRO · PUEBLO LIBRE

**Semántica crítica del proyecto:**
- `CAMPAÑA` = `LEAD_COL.TRAT` = `LLAM_COL.TRATAMIENTO` (HIFU, ENZIMAS FACIALES, CAPILAR, HIDROFACIAL, etc.)
- `VENT.TRATAMIENTO` = servicio clínico vendido (diferente semántica a campaña)
- `ANUNCIO` = texto del anuncio específico dentro de la campaña

---

## 2. ROADMAP — ESTADO ACTUAL

```
✅ BLOQUE 0   Bugs críticos resueltos
✅ BLOQUE 1   Comisiones Admin → GS_21_AdminComisiones.gs + ViewAdminComisiones.html
✅ BLOQUE 2   Llamadas Admin → GS_22_AdminCalls.gs (v3.3) + ViewAdminCalls.html (v3.3)
✅ BLOQUE 2.5 Ficha contextual asesor → GS_06_AdvisorCalls.gs (v2.1.0) + ViewAdvisorCalls.html (v2.7)

🔴 BLOQUE 3   Pacientes 360° — EN PREPARACIÓN
              CAPA 0: GS_00_Repairs.gs — reparaciones previas al Sheet
              CAPA 1: recalcularTodosPacientes() — recálculo masivo de 6,994 pacientes
              CAPA 2: GS_23 + GS_24 + ViewAdminPatients — panel completo

⏳ BLOQUE 4   Configuración del sistema
⏳ BLOQUE 5   Equipo + fotos + permisos
⏳ BLOQUE 6   Agenda + Mis Citas
⏳ BLOQUE 7   Call Center — cerrar pendientes
⏳ BLOQUE 8   Notificaciones de ventas
⏳ BLOQUE 9   Catálogo de Servicios KB
⏳ BLOQUE 10  Catálogo de Productos
⏳ BLOQUE 11  Almacén central
⏳ BLOQUE 12  Sistema de Caja

── CAPA FUTURA (post índice maestro) ──────────────────────────
⏳ BLOQUE 13  Meta + TikTok Leads webhook automático
⏳ BLOQUE 14  Chatbot WhatsApp con IA (Claude como cerebro)
⏳ BLOQUE 15  Panel de métricas Meta + TikTok en admin
⏳ BLOQUE 16  Validación DNI RENIEC (API tercero o PIDE)
⏳ BLOQUE 17  Datos externos: tipo de cambio + feriados + clima
⏳ BLOQUE 18  Prospectos B2B (Google Maps / Outscraper)
```

---

## 3. DIAGNÓSTICO COMPLETO DEL SHEET — Abril 2026

### Estado de hojas (31 hojas en total)

| Hoja | Registros | Estado |
|------|-----------|--------|
| CONSOLIDADO_DE_PACIENTES | 6,994 | ⚠️ 405 duplicados, campos vacíos |
| CONSOLIDADO DE VENTAS | 600 | 🔴 0/600 con VENTA_ID |
| AGENDA_CITAS | 468 | ⚠️ Sin col GCAL_ID, 465 en PENDIENTE |
| CONSOLIDADO DE LLAMADAS | 12,186 | ⚠️ Cols sin header, 8,855 NO CONTESTA legacy |
| SEGUIMIENTOS | 237 | 🔴 BUG: col D sobreescrita por teléfono |
| RRHH | 8 | ✅ OK |
| HORARIOS_DOCTORAS | activo | ✅ OK |
| CAT_TRATAMIENTOS | 0 | ❌ Vacía — necesita poblarse |
| CAT_ANUNCIOS | 0 | ❌ Vacía — necesita poblarse |

### Bugs críticos detectados

**BUG-01 — SEGUIMIENTOS: col D sobreescrita**
Header de columna D (`NUMERO`) fue reemplazado por el valor `986293339` (un número de teléfono entró en fila 1). Todo GS que lee esa col por nombre falla silenciosamente.

**BUG-02 — VENTAS: 600/600 sin VENTA_ID**
Columna Q (`VENTA_ID`) existe pero está vacía en todos los registros históricos. Sin VENTA_ID no se puede vincular venta ↔ cita ↔ paciente. El GS_04 genera IDs solo para ventas nuevas, las históricas nunca se backfillearon.

**BUG-03 — LLAMADAS: columnas sin header**
Columnas H, J, K, L, M, N, O, P, Q, R, S, T existen con datos pero sin encabezado visible. GS_01 las referencia por índice (correcto técnicamente) pero el Sheet es ilegible para humanos. Adicionalmente `NO CONTESTA` legacy (8,855 filas) nunca fue migrado a `SIN CONTACTO`.

**BUG-04 — PACIENTES: 405 duplicados por teléfono**
De 6,994 pacientes, 405 teléfonos aparecen 2+ veces. Historial fragmentado, KPIs incorrectos.

### Completitud de CONSOLIDADO_DE_PACIENTES

| Columna | Completitud | Acción |
|---------|-------------|--------|
| ID, Nombres, Apellidos, Teléfono, Sexo, Estado | ✅ 100% | — |
| N° documento (DNI) | ⚠️ 43% | Completar con RENIEC API |
| Email | ❌ 18% | Completar progresivamente |
| Fecha nacimiento | ❌ 18% | — |
| SEDE_PRINCIPAL | ❌ 2% | Recalcular desde VENTAS/AGENDA |
| FUENTE | ❌ 4% | Recalcular desde LEADS |
| TOTAL_COMPRAS / TOTAL_FACTURADO | ❌ 2% | recalcularTodosPacientes() |
| ULTIMA_VISITA | ❌ 5% | recalcularTodosPacientes() |
| TOTAL_LLAMADAS / TOTAL_CITAS | ❌ ~0% | recalcularTodosPacientes() |

### Cruces detectados

| Situación | Cantidad |
|-----------|----------|
| Pacientes con ventas vinculadas | 127 |
| Ventas con número NO en PACIENTES | **32** (fantasmas) |
| Pacientes con citas en agenda | 253 |
| Citas con número NO en PACIENTES | **102** (fantasmas) |
| Total facturado registrado | S/ 272,525 |

### Columnas que faltan en hojas existentes

**CONSOLIDADO DE VENTAS** (actualmente 17 cols, GS_01 espera 19+):
- Falta col O: `_VACIO` (reservado)
- Falta col R: `NRO_DOC`
- Falta col S: `ESTADO_DOC`
- Nuevas Bloque 3: `AGRUPADOR_DIA` · `COMPROBANTE_ID` · `TIPO_COMPROBANTE`

**AGENDA_CITAS** (actualmente 21 cols):
- Falta col V: `GCAL_EVENT_ID`
- Nueva Bloque 3: `ORIGEN_CITA`

**CONSOLIDADO_DE_PACIENTES** (actualmente 21 cols):
- Nuevas Bloque 3: `ETIQUETA_BASE` · `SCORE_ESTADO` · `DIAS_ULTIMA_VISITA`

---

## 4. BLOQUE 3 — PLAN DE ACCIÓN (3 CAPAS)

### CAPA 0 — GS_00_Repairs.gs (ejecutar primero, una sola vez)

```
1. Corregir BUG-01: restaurar header "NUMERO" en col D de SEGUIMIENTOS
2. Corregir BUG-03: agregar headers faltantes en LLAMADAS (cols H,J..T)
3. Migrar BUG-03: NO CONTESTA → SIN CONTACTO en 8,855 filas de LLAMADAS
4. Backfill BUG-02: generar VENTA_ID para 600 ventas históricas (formato V-XXXXXXXX)
5. Agregar columnas nuevas en VENTAS: _VACIO(O), NRO_DOC(R), ESTADO_DOC(S),
   AGRUPADOR_DIA(T), COMPROBANTE_ID(U), TIPO_COMPROBANTE(V)
6. Agregar columnas nuevas en AGENDA: GCAL_EVENT_ID(V), ORIGEN_CITA(W)
7. Agregar columnas nuevas en PACIENTES: ETIQUETA_BASE(V), SCORE_ESTADO(W), DIAS_ULTIMA_VISITA(X)
8. Actualizar GS_01_Config con los nuevos índices
```

### CAPA 1 — recalcularTodosPacientes() dentro de GS_23

```
Función que recorre los 6,994 pacientes y para cada uno:
- Cruza por teléfono con VENTAS → TOTAL_COMPRAS, TOTAL_FACTURADO, ULTIMA_VISITA, SEDE_PRINCIPAL
- Cruza por teléfono con AGENDA → TOTAL_CITAS
- Cruza por teléfono con LLAMADAS → TOTAL_LLAMADAS
- Cruza por teléfono con LEADS → FUENTE (primera campaña)
- Calcula SCORE_ESTADO: activo/riesgo/inactivo por días desde última visita
- Calcula DIAS_ULTIMA_VISITA
- Escribe batch en el Sheet (no fila por fila)
Tiempo estimado: 3-5 minutos para 6,994 pacientes
```

### CAPA 2 — Bloque 3 real

**Archivos a crear:**
```
GS_23_EtiquetasBase.gs    → genera y mantiene BASE_ETIQUETAS
GS_24_Pacientes360.gs     → backend completo Pacientes 360
ViewAdminPatients.html    → panel búsqueda + perfil 360
```

**Hojas nuevas a crear:**
```
BASE_ETIQUETAS           → num | etiqueta | campaña | ultActividad | asesor
NOTAS_PACIENTES          → ID | fecha | num | texto | rol | usuario | tipoNota
DOCUMENTOS_PACIENTES     → ID | fecha | tipo | urlDrive | usuario | num
SEGUIMIENTOS_PROGRAMADOS → ID | num | tratamiento | fechaUltApp | diasCiclo | fechaRecontacto | estado
HISTORIA_CLINICA         → DNI (PK) + todos los campos MINSA estética
```

---

## 5. BLOQUE 3 — ARQUITECTURA PACIENTES 360°

### 8 Zonas del panel
1. **Ficha identidad** — editable global, cambios se reflejan en todo el sistema
2. **Historia clínica** — formulario MINSA estética completo
3. **Compras agrupadas por día** — cards con PDF comprobante descargable/envío email
4. **Citas** — historial + crear desde aquí + actualiza agenda global
5. **Historial de contactos** — todas las llamadas, tipificaciones, observaciones
6. **Notas del equipo** — multi-rol (asesor/médico/enfermero/recepción)
7. **Documentos y fotos** — consentimientos, antes/después, contratos
8. **Seguimiento programado** — por tratamiento o producto

### Features adicionales aprobados
- **Score del paciente:** activo / en riesgo / inactivo (días desde última visita)
- **Timeline unificado:** cronológico mezclado (llamadas + citas + compras + notas)
- **Alertas contraindicaciones:** banner rojo si alergias o embarazo registrado
- **Buscador:** autocompletado por nombre, apellido, DNI, teléfono
- **Detección de duplicados:** mismos datos + distinto DNI → alerta + fusión (solo admin)

### Roles y permisos en 360
| Rol | Puede hacer |
|-----|-------------|
| Admin | Todo + eliminar + fusionar historias |
| Asesor | Leer + notas ventas + crear citas |
| Recepción | Crear citas + notas recepción |
| Doctor | Historia clínica + notas médicas + recetas + descuentos + insumos |
| Enfermero | Notas enfermería + receta + plan de trabajo |

### Seguimiento programado por tratamiento
| Tratamiento | Ciclo |
|-------------|-------|
| Toxina botulínica | 4–6 meses |
| Ácido hialurónico | 12–18 meses |
| HIFU | 12 meses |
| Productos dosis diaria | unidades ÷ dosis_diaria |

### PDFs — 4 tipos
1. Comprobante de compra (QR + código interno)
2. Cotización editable
3. Receta médica (CMP del doctor)
4. Receta enfermería (rango: técnico/licenciado)

---

## 6. BLOQUE 2 — LLAMADAS ADMIN (COMPLETADO)

### Archivos entregados
- `GS_22_AdminCalls.gs` — v3.3 · 1475 líneas · 10 módulos
- `ViewAdminCalls.html` — v3.3 · 777 líneas

### KPIs v2
| # | KPI | Fuente | Filtra período | Filtra asesor |
|---|-----|--------|---------------|---------------|
| 1 | Llamadas totales | LLAMADAS | ✅ | ✅ |
| 2 | Vírgenes históricos | LEADS vs LLAMADAS | ❌ global | ❌ |
| 3 | Leads contactados / total | LEADS + LLAMADAS | ✅ | ✅ |
| 4 | Citas agendadas | AGENDA.TS_CREADO | ✅ | ✅ |
| 5 | Asistidos | AGENDA.ESTADO | ✅ | ✅ |
| 6 | Facturación call center | VENTAS asesor≠vacío | ✅ | ✅ |

---

## 7. BLOQUE 2.5 — FICHA CONTEXTUAL ASESOR (COMPLETADO)

### Archivos entregados
- `GS_06_AdvisorCalls.gs` — v2.1.0 · 1298 líneas · MOD-11 nuevo
- `ViewAdvisorCalls.html` — v2.7 · 1081 líneas · 4 parches aplicados

### Parches del v2.7
- **P1:** CSS `.ctx-*` para bloque contextual
- **P2:** `<div id="cc-contexto">` antes del `.num-block-hint`
- **P3:** función `renderContexto(ctx)` al final del script
- **P4:** `renderContexto(res.lead.contexto||null)` en `loadLead()`

---

## 8. LÓGICA MADRE — COLA PRIORIZADA (8 PASOS)

```
PASO 1 · Vírgenes del mes actual          → máxima prioridad
PASO 2 · No asistió a cita (últimas 2sem) → seguimiento urgente
PASO 3 · Vírgenes históricos              → mismo nivel que paso 1
PASO 4 · Sin contacto mes actual          → reintentar horario pico
PASO 5 · Canceló / reprogramó cita        → intención activa
PASO 6 · Base antigua sin convertir       → de más reciente a más antiguo
PASO 7 · Pacientes activos recompra 90d   → oferta complementaria
PASO 8 · Sin contacto histórico           → último recurso
```

**Anti-duplicado:** `CacheService` clave `COLA_HOY_[ASESOR]_[FECHA]`
**Distribuciones:** `PropertiesService` clave `DIST_CONFIG_[ASESOR_NORM]`

---

## 9. TAXONOMÍA DE BASES (3 DIMENSIONES)

**DIM 1 — Estado:** Virgen · Sin contacto · Contactado · Con cita · Paciente activo · Inactivo · Provincia · Retirado · Con adelanto

**DIM 2 — Origen:** Campaña · Tratamiento · Orgánico · Mes ingreso · Base antigua · Pacientes históricos

**DIM 3 — Agenda:** Asistió · No asistió · Canceló · Cita pendiente · Con venta · Control recurrente

---

## 10. ECOSISTEMA FUTURO — VISIÓN COMPLETA

### Capas post-índice maestro

```
CAPA A — Integraciones de captación
  → Meta Leads API webhook → CONSOLIDADO DE LEADS automático
  → TikTok Leads API webhook → mismo destino
  → Panel de métricas Meta + TikTok en admin (inversión, CPL, CTR)
  → Cruce automático: costo por lead vs conversión real interna

CAPA B — Chatbot WhatsApp con IA
  → WhatsApp Business API (Meta Cloud, gratuita hasta volumen)
  → Claude como cerebro del bot
  → Capacidades:
    • Recibe texto, audio e imágenes
    • Responde sobre tratamientos, precios, disponibilidad
    • Agenda citas directamente en AGENDA_CITAS
    • Registra leads nuevos en CONSOLIDADO DE LEADS
    • Detecta intención de compra → alerta asesor con contexto completo
    • Recibe comprobantes Yape/Plin/transferencia → notifica asesor
    • Consulta historia clínica con código único de verificación
    • Acceso de escritura al CRM (trazado con origen = BOT)
  → Métricas propias: ventas bot vs asesor, conversión, tiempo respuesta

CAPA C — Chatbot TikTok / Meta Messenger
  → Mismo motor que WhatsApp, diferente canal
  → Leads desde mensajes directos de TikTok o Instagram/Facebook

CAPA D — Validación DNI RENIEC
  → Opción 1: PIDE (Plataforma Interoperabilidad del Estado) — gratis, burocrático
  → Opción 2: apiperu.dev o consultasruc.com — ~$0.03/consulta (~$5/mes en volumen clínica)
  → Al registrar cita confirmada: ingresar DNI → autocompletar nombre + apellido + fecha nac
  → Elimina errores de tipeo en nombres de pacientes

CAPA E — Datos externos útiles
  → Tipo de cambio: BCRP/SBS (gratis, oficial) o cuantoestaeldolar.pe API (paralelo)
  → Feriados Peru: API pública gratis → bloqueo automático slots agenda
  → Clima Lima: OpenWeatherMap gratis → alerta no-show días lluvia
  → Distritos/ubigeos: INEI → autocompletar dirección correctamente
  → Reseñas Google My Business: Places API → panel reputación en admin

CAPA F — Prospectos B2B
  → Outscraper o Google Places API → extraer negocios por zona
  → Hoja BASE_PROSPECTOS_B2B en Sheet
  → Panel: score de potencial, estado de contacto, envío propuesta por email
  → Caso de uso: empresas para convenios corporativos de bienestar
```

### Ecosistema cerrado completo

```
ENTRADA          PROCESAMIENTO           SALIDA
─────────────────────────────────────────────────
Meta/TikTok ads → leads automáticos → call center
WhatsApp bot    → citas + cobros   → agenda + caja
Google Maps B2B → prospectos       → propuestas email
                        ↓
               AscendaOS CRM
         (base de datos unificada)
                        ↓
  KPIs · Comisiones · Pacientes 360 · Historia clínica
  Facturación · PDFs · Seguimientos · Notificaciones
```

---

## 11. DATOS EXTERNOS — MAPA DE FUENTES

| Dato | Fuente | Costo | Dificultad |
|------|--------|-------|-----------|
| Dólar oficial (compra/venta) | BCRP / SBS API | Gratis | ✅ Fácil |
| Dólar paralelo (Ocoña) | cuantoestaeldolar.pe API | ~$10/mes | ✅ Fácil |
| Acciones globales (NYSE, NASDAQ) | Finnhub.io | Gratis | ✅ Fácil |
| Acciones BVL | bvl.com.pe/api-bvl-data | Solicitar acceso | ⚠️ Medio |
| Crypto | CoinGecko API | Gratis | ✅ Fácil |
| Noticias financieras | Finnhub + BVL RSS | Gratis | ✅ Fácil |
| Feriados Perú | API pública / BCRP | Gratis | ✅ Fácil |
| Clima Lima | OpenWeatherMap | Gratis | ✅ Fácil |
| Validación DNI | apiperu.dev o PIDE | $0.03/consulta o gratis | ✅/⚠️ |
| Distritos/ubigeos | INEI | Gratis | ✅ Fácil |
| Reseñas Google | Places API | ~$17/1000 consultas | ✅ Fácil |
| Negocios B2B | Outscraper | ~$10/1000 registros | ✅ Fácil |

*Nota: Datos financieros (dólar, acciones, crypto) son para AscendaFinance, no para AscendaOS CRM. Para el CRM la integración más valiosa es feriados + clima + DNI.*

---

## 12. VISIÓN CREACTIVE OS — AGENTES Y VERTICALES

### Agentes a crear al terminar el CRM
| Agente | Función |
|--------|---------|
| T-Arquitecto | Define estructura modular de cualquier sistema nuevo |
| T-Developer | Patrones GAS + HTML, nomenclatura, helpers comunes |
| C-Producto | Adapta paneles base a sector específico |
| C-Blueprint | Analiza necesidades de cliente nuevo y mapea qué construir |

### Verticales identificadas
| Producto | Sector | Estado |
|----------|--------|--------|
| AscendaClinic | Clínicas estéticas | En construcción ✅ |
| AscendaLegal | Abogados + equipo comercial | Definido |
| AscendaPsych | Psicólogos + citas + notas sesión | Definido |
| AscendaFinance | Gestión financiera + mercados | Proyecto paralelo — refactorizar |

### Los 12 paneles reutilizables del core
1. Monitoreo equipo en tiempo real · 2. KPIs con filtro · 3. Embudo de conversión
4. Histórico anual · 5. Gestión de bases con tabs · 6. Distribución de colas
7. Pacientes/Clientes 360 · 8. Comisiones por asesor · 9. Agenda + calendario
10. Call center con ficha contextual · 11. Facturación + PDFs · 12. Configuración

---

## 13. METODOLOGÍA DE TRABAJO

```
1.  Auditar antes de intervenir
2.  Arquitectura + diagrama antes de código
3.  Documento completo, no parches
4.  Nomenclatura: GS_XX_NombreModulo.gs + ViewNombre.html
5.  Anclas CTRL+F en todo código
6.  Checklist de prueba en cada entrega
7.  SESSION_LOG al cerrar cada sesión
8.  Helpers compartidos no se duplican (GS_03/GS_04)
9.  PropertiesService para configs persistentes
10. CacheService para anti-duplicado diario
11. Mobile-first en HTML siempre
12. Respuesta para ejecución real, no teoría
```

---

## 14. COLUMNAS CLAVE POR HOJA (ÍNDICES BASE 0)

```javascript
// Confirmados contra el Sheet real (Abril 2026)

PAC_COL:  ID:0, NOMBRES:1, APELLIDOS:2, TELEFONO:3, EMAIL:4,
          DOCUMENTO:5, SEXO:6, FECHA_NAC:7, DIRECCION:8,
          OCUPACION:9, SEDE:10, FUENTE:11, FECHA_REG:12,
          TOTAL_COMPRAS:13, TOTAL_FACTURADO:14, ULTIMA_VISITA:15,
          TOTAL_LLAMADAS:16, TOTAL_CITAS:17, ESTADO:18,
          NOTAS:19, FOTO_URL:20
          // Bloque 3 agrega: ETIQUETA_BASE:21, SCORE_ESTADO:22, DIAS_ULTIMA_VISITA:23

VENT_COL: FECHA:0, NOMBRES:1, APELLIDOS:2, DNI:3, CELULAR:4,
          TRATAMIENTO:5, DESCRIPCION:6, PAGO:7, MONTO:8,
          ESTADO_PAGO:9, ASESOR:10, ATENDIO:11, SEDE:12,
          TIPO:13, _VACIO:14, NUM_LIMPIO:15, VENTA_ID:16
          // Faltan en Sheet actual: NRO_DOC:17, ESTADO_DOC:18
          // Bloque 3 agrega: AGRUPADOR_DIA:19, COMPROBANTE_ID:20, TIPO_COMPROBANTE:21

AG_COL:   ID:0, FECHA:1, TRATAMIENTO:2, TIPO_CITA:3, SEDE:4,
          NUMERO:5, NOMBRE:6, APELLIDO:7, DNI:8, CORREO:9,
          ASESOR:10, ID_ASESOR:11, ESTADO:12, VENTA_ID:13,
          OBS:14, TS_CREADO:15, TS_ACTUALIZADO:16, HORA_CITA:17,
          ETIQUETA_CAMP:18, DOCTORA:19, TIPO_ATENCION:20
          // Falta en Sheet: GCAL_ID:21
          // Bloque 3 agrega: ORIGEN_CITA:22

LLAM_COL: FECHA:0, NUMERO:1, TRATAMIENTO:2, ESTADO:3, OBS:4,
          HORA:5, ASESOR:6, _F7:7, NUM_LIMPIO:8, ID_ASESOR:9,
          ANUNCIO:10, ORIGEN:11, INTENTO:12, ULT_TS:13,
          PROX_REIN:14, RESULTADO:15, SESSION_ID:16, DEVICE:17,
          WHATSAPP:18, TS_LOG:19, SUB_ESTADO:20
          // NOTA: cols J..T existen con datos pero SIN header en Sheet

LEAD_COL: FECHA:0, CELULAR:1, TRAT:2, ANUNCIO:3, HORA:5, NUM_LIMPIO:7

SEG_COL:  ID:0, FECHA_PROG:1, HORA_PROG:2, NUMERO:3 (BUG: sobreescrito),
          TRATAMIENTO:4, ASESOR:5, ID_ASESOR:6, OBS:7, ESTADO:8,
          TS_CREADO:9, TS_ACTUALIZADO:10
```

---

*Generado por CreActive OS · AscendaOS v1 · Abril 2026*
*Próxima sesión: arrancar con GS_00_Repairs.gs — CAPA 0 del Bloque 3*
