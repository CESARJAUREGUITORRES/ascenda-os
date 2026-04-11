# MEMORY.md — CREACTIVE OS · AscendaOS v1
## Memoria Maestra Consolidada | Última actualización: 11 Abril 2026

---

## CÓMO USAR ESTE ARCHIVO

Al iniciar sesión nueva → pegar el ULTRA PROMPT + la sección **CONTEXTO ACTIVO** como primer mensaje.
Claude leerá el resto desde Supabase (`aos_memory` + `aos_codigo_fuente`).

---

# ══════════════════════════════════════════
# SECCIÓN 1 — CONTEXTO ACTIVO
# (Copiar al inicio de cada sesión nueva)
# ══════════════════════════════════════════

```
PROYECTO: AscendaOS v1 — CRM Clínica Zi Vital
EMPRESA:  CREACTIVE OS (Holding de productos digitales)
STACK:    Google Apps Script + Google Sheets + WebApp HTML/CSS/JS + Supabase PostgreSQL
FASE:     Construcción activa — Bloques 0-2.5 completados

SHEET ID:   1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM
DEPLOY URL: script.google.com/macros/s/AKfycbyVoliSxxF3gJTX71Yi3tTd7L1sAUSyFj3HPmBYVaFCGKy69uWLzJV6nDcYjVBn-L5/exec
REPO:       github.com/CESARJAUREGUITORRES/ascenda-os
SUPABASE:   ituyqwstonmhnfshnaqz (clave en PropertiesService: SUPABASE_KEY)

ESTADO ACTUAL (11/04/2026):
- 52 archivos en Supabase: 29 GS + 20 HTML + 3 MD
- GitHub Action activo (sync cada hora)
- Supabase como fuente de verdad del código
- Call center operativo para asesores

PRÓXIMO OBJETIVO: Sesión B — fix ViewAdminCalls KPIs + ViewAdminMarketing Supabase directo

PENDIENTES INMEDIATOS:
1. ViewAdminCalls — parámetros filtro KPIs incorrectos
2. ViewAdminMarketing — migrar a Supabase directo
3. GS_27 SyncSeguro — instalar trigger 10min
4. Probar sistema con asesores (Wilmer, Ruvila, Mireya, Carmen)
```

---

# ══════════════════════════════════════════
# SECCIÓN 2 — ECOSISTEMA CREACTIVE OS
# ══════════════════════════════════════════

## Empresa y visión
- **CREACTIVE OS** = Holding de productos digitales
- **Filosofía:** Síntesis entre inteligencia humana y AI para resolver problemas operativos reales
- **Visión:** Cada sistema construido se convierte en un producto vertical reutilizable

## Agentes a crear al terminar el CRM
| Agente | Función |
|--------|---------|
| T-Arquitecto | Define estructura modular de cualquier sistema nuevo |
| T-Developer | Patrones GAS + HTML, nomenclatura, helpers comunes |
| C-Producto | Adapta paneles base a sector específico |
| C-Blueprint | Analiza necesidades de cliente nuevo y mapea qué construir |

## Verticales identificadas
| Producto | Sector | Estado |
|----------|--------|--------|
| AscendaClinic | Clínicas estéticas | En construcción ✅ |
| AscendaLegal | Abogados + equipo comercial | Definido |
| AscendaPsych | Psicólogos + citas + notas sesión | Definido |
| AscendaFinance | Gestión financiera + mercados | Proyecto paralelo |

## Los 12 paneles reutilizables del core
1. Monitoreo equipo tiempo real · 2. KPIs con filtro · 3. Embudo conversión
4. Histórico anual · 5. Gestión bases con tabs · 6. Distribución colas
7. Pacientes/Clientes 360 · 8. Comisiones por asesor · 9. Agenda + calendario
10. Call center con ficha contextual · 11. Facturación + PDFs · 12. Configuración

---

# ══════════════════════════════════════════
# SECCIÓN 3 — PROYECTO ASCENDAOS v1
# ══════════════════════════════════════════

## Equipo operativo
- **Admin:** CESAR (ZIV-001, cesar123)
- **Asesores:** WILMER (ZIV-004), RUVILA (ZIV-002), MIREYA (ZIV-003), SRA CARMEN (ZIV-005)
- **Sedes:** SAN ISIDRO · PUEBLO LIBRE

## Arquitectura de datos
```
LECTURA:  Browser → sb_rpc() → Supabase directo (~300ms)
ESCRITURA: Browser → GAS → Google Sheets + Supabase via trigger
JOIN KEY: NUMERO_LIMPIO es el join universal entre todas las hojas
```

## Semántica crítica
- `CAMPAÑA` = `LEAD_COL.TRAT` = `LLAM_COL.TRATAMIENTO` (HIFU, ENZIMAS FACIALES, etc.)
- `VENT.TRATAMIENTO` = servicio clínico vendido — **diferente semántica**
- `ANUNCIO` = texto del anuncio específico dentro de la campaña

## Reglas innegociables
- NUNCA sync automático con DELETE — solo INSERT seguro
- GAS solo para escrituras y lógica compleja
- Todo parche nuevo se registra en `aos_codigo_fuente`
- Usar siempre funciones `da_*` de GS_04 — nunca leer sheets con índices hardcodeados
- Constantes de columnas siempre desde GS_01_Config.gs

---

# ══════════════════════════════════════════
# SECCIÓN 4 — ROADMAP COMPLETO
# ══════════════════════════════════════════

```
✅ BLOQUE 0    Bugs críticos resueltos
✅ BLOQUE 1    Comisiones Admin → GS_21 + ViewAdminComisiones
✅ BLOQUE 2    Llamadas Admin → GS_22 v3.3 + ViewAdminCalls v3.3
✅ BLOQUE 2.5  Ficha contextual asesor → GS_06 v2.1.0 + ViewAdvisorCalls v2.7

🔴 SESIÓN B    ViewAdminCalls KPIs fix + ViewAdminMarketing Supabase directo ← PRÓXIMO

🔴 BLOQUE 3    Pacientes 360° (arquitectura aprobada, 8 zonas)
               CAPA 0: GS_00_Repairs.gs — reparaciones previas (✅ ejecutado)
               CAPA 1: recalcularTodosPacientes() — 6,994 pacientes
               CAPA 2: GS_23 + GS_24 + ViewAdminPatients — panel completo

⏳ BLOQUE 4    Configuración del sistema
⏳ BLOQUE 5    Equipo + fotos + permisos
⏳ BLOQUE 6    Agenda + Mis Citas
⏳ BLOQUE 7    Call Center — cerrar pendientes
⏳ BLOQUE 8    Notificaciones de ventas
⏳ BLOQUE 9    Catálogo de Servicios
⏳ BLOQUE 10   Catálogo de Productos
⏳ BLOQUE 11   Almacén central
⏳ BLOQUE 12   Sistema de Caja

── CAPAS FUTURAS ───────────────────────────────────────────────
⏳ BLOQUE 13   Meta + TikTok Leads webhook automático
⏳ BLOQUE 14   Chatbot WhatsApp con IA (Claude como cerebro)
⏳ BLOQUE 15   Panel métricas Meta + TikTok en admin
⏳ BLOQUE 16   Validación DNI RENIEC
⏳ BLOQUE 17   Datos externos: tipo cambio + feriados + clima
⏳ BLOQUE 18   Prospectos B2B (Google Maps / Outscraper)
```

---

# ══════════════════════════════════════════
# SECCIÓN 5 — DIAGNÓSTICO DEL SHEET (Abril 2026)
# ══════════════════════════════════════════

## Estado de hojas (31 hojas)
| Hoja | Registros | Estado |
|------|-----------|--------|
| CONSOLIDADO_DE_PACIENTES | 6,994 | ⚠️ 405 duplicados, campos vacíos |
| CONSOLIDADO DE VENTAS | 600 | 🔴 0/600 con VENTA_ID |
| AGENDA_CITAS | 468 | ⚠️ Sin col GCAL_ID, 465 en PENDIENTE |
| CONSOLIDADO DE LLAMADAS | 12,186 | ⚠️ Cols sin header, 8,855 NO CONTESTA legacy |
| SEGUIMIENTOS | 237 | 🔴 BUG: col D sobreescrita por teléfono |
| RRHH | 8 | ✅ OK |
| CAT_TRATAMIENTOS | 0 | ❌ Vacía |
| CAT_ANUNCIOS | 0 | ❌ Vacía |

## Bugs críticos
| ID | Bug | Impacto |
|----|-----|---------|
| BUG-01 | SEGUIMIENTOS col D header sobreescrito por teléfono | GS que lee por nombre falla silencioso |
| BUG-02 | VENTAS: 600/600 sin VENTA_ID | No se puede vincular venta↔cita↔paciente |
| BUG-03 | LLAMADAS: cols H,J..T sin header | Sheet ilegible + 8,855 "NO CONTESTA" sin migrar |
| BUG-04 | PACIENTES: 405 duplicados por teléfono | KPIs incorrectos, historial fragmentado |

## Cruces detectados
| Situación | Cantidad |
|-----------|----------|
| Pacientes con ventas vinculadas | 127 |
| Ventas con número NO en PACIENTES | 32 (fantasmas) |
| Pacientes con citas en agenda | 253 |
| Citas con número NO en PACIENTES | 102 (fantasmas) |
| Total facturado registrado | S/ 272,525 |

---

# ══════════════════════════════════════════
# SECCIÓN 6 — ARQUITECTURA TÉCNICA
# ══════════════════════════════════════════

## Columnas clave por hoja (índices base 0)
```javascript
// Confirmados contra el Sheet real — Abril 2026

PAC_COL:  ID:0, NOMBRES:1, APELLIDOS:2, TELEFONO:3, EMAIL:4,
          DOCUMENTO:5, SEXO:6, FECHA_NAC:7, DIRECCION:8,
          OCUPACION:9, SEDE:10, FUENTE:11, FECHA_REG:12,
          TOTAL_COMPRAS:13, TOTAL_FACTURADO:14, ULTIMA_VISITA:15,
          TOTAL_LLAMADAS:16, TOTAL_CITAS:17, ESTADO:18, NOTAS:19, FOTO_URL:20
          // Bloque 3: ETIQUETA_BASE:21, SCORE_ESTADO:22, DIAS_ULTIMA_VISITA:23

VENT_COL: FECHA:0, NOMBRES:1, APELLIDOS:2, DNI:3, CELULAR:4,
          TRATAMIENTO:5, DESCRIPCION:6, PAGO:7, MONTO:8,
          ESTADO_PAGO:9, ASESOR:10, ATENDIO:11, SEDE:12,
          TIPO:13, _VACIO:14, NUM_LIMPIO:15, VENTA_ID:16
          // Faltan en Sheet: NRO_DOC:17, ESTADO_DOC:18
          // Bloque 3: AGRUPADOR_DIA:19, COMPROBANTE_ID:20, TIPO_COMPROBANTE:21

AG_COL:   ID:0, FECHA:1, TRATAMIENTO:2, TIPO_CITA:3, SEDE:4,
          NUMERO:5, NOMBRE:6, APELLIDO:7, DNI:8, CORREO:9,
          ASESOR:10, ID_ASESOR:11, ESTADO:12, VENTA_ID:13,
          OBS:14, TS_CREADO:15, TS_ACTUALIZADO:16, HORA_CITA:17,
          ETIQUETA_CAMP:18, DOCTORA:19, TIPO_ATENCION:20
          // Falta: GCAL_ID:21 / Bloque 3: ORIGEN_CITA:22

LLAM_COL: FECHA:0, NUMERO:1, TRATAMIENTO:2, ESTADO:3, OBS:4,
          HORA:5, ASESOR:6, _F7:7, NUM_LIMPIO:8, ID_ASESOR:9,
          ANUNCIO:10, ORIGEN:11, INTENTO:12, ULT_TS:13,
          PROX_REIN:14, RESULTADO:15, SESSION_ID:16, DEVICE:17,
          WHATSAPP:18, TS_LOG:19, SUB_ESTADO:20
          // NOTA: cols J..T tienen datos pero SIN header en Sheet

LEAD_COL: FECHA:0, CELULAR:1, TRAT:2, ANUNCIO:3, HORA:5, NUM_LIMPIO:7

SEG_COL:  ID:0, FECHA_PROG:1, HORA_PROG:2, NUMERO:3 (BUG-01 sobreescrito),
          TRATAMIENTO:4, ASESOR:5, ID_ASESOR:6, OBS:7, ESTADO:8,
          TS_CREADO:9, TS_ACTUALIZADO:10
```

## Triggers activos en Supabase
- `trg_refresh_llammap` — activo
- `trg_sync_paciente_venta` — activo
- `trg_sync_paciente_contacto` — ELIMINADO (causaba error)

## Funciones SQL en Supabase
- `aos_semaforo_equipo(p_hoy)`
- `aos_seguimientos_asesor(p_asesor, p_id, p_hoy)`
- `aos_comisiones_asesor(p_asesor, p_id, p_mes, p_anio)`
- `aos_historial_pago_paciente(p_num)`
- `aos_cerrar_seguimiento(p_id)`
- `aos_kpis_dashboard`
- `aos_panel_asesor`
- `aos_cerrar_estado_abierto`

---

# ══════════════════════════════════════════
# SECCIÓN 7 — BLOQUE 3 — PACIENTES 360°
# ══════════════════════════════════════════

## 8 Zonas del panel
1. Ficha identidad — editable global
2. Historia clínica — formulario MINSA estética completo
3. Compras agrupadas por día — cards + PDF comprobante
4. Citas — historial + crear desde aquí + actualiza agenda
5. Historial de contactos — todas las llamadas y tipificaciones
6. Notas del equipo — multi-rol
7. Documentos y fotos — consentimientos, antes/después
8. Seguimiento programado — por tratamiento o producto

## Hojas nuevas a crear
```
BASE_ETIQUETAS           → num | etiqueta | campaña | ultActividad | asesor
NOTAS_PACIENTES          → ID | fecha | num | texto | rol | usuario | tipoNota
DOCUMENTOS_PACIENTES     → ID | fecha | tipo | urlDrive | usuario | num
SEGUIMIENTOS_PROGRAMADOS → ID | num | tratamiento | fechaUltApp | diasCiclo | fechaRecontacto | estado
HISTORIA_CLINICA         → DNI (PK) + todos los campos MINSA estética
```

## Seguimiento programado por tratamiento
| Tratamiento | Ciclo |
|-------------|-------|
| Toxina botulínica | 4–6 meses |
| Ácido hialurónico | 12–18 meses |
| HIFU | 12 meses |
| Productos dosis diaria | unidades ÷ dosis_diaria |

## PDFs — 4 tipos
1. Comprobante de compra (QR + código interno)
2. Cotización editable
3. Receta médica (CMP del doctor)
4. Receta enfermería

## Roles y permisos en 360
| Rol | Puede hacer |
|-----|-------------|
| Admin | Todo + eliminar + fusionar historias |
| Asesor | Leer + notas ventas + crear citas |
| Recepción | Crear citas + notas recepción |
| Doctor | Historia clínica + notas médicas + recetas + descuentos |
| Enfermero | Notas enfermería + receta + plan de trabajo |

---

# ══════════════════════════════════════════
# SECCIÓN 8 — LÓGICA MADRE (COLA PRIORIZADA)
# ══════════════════════════════════════════

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

# ══════════════════════════════════════════
# SECCIÓN 9 — TAXONOMÍA DE BASES
# ══════════════════════════════════════════

**DIM 1 — Estado:** Virgen · Sin contacto · Contactado · Con cita · Paciente activo · Inactivo · Provincia · Retirado · Con adelanto

**DIM 2 — Origen:** Campaña · Tratamiento · Orgánico · Mes ingreso · Base antigua · Pacientes históricos

**DIM 3 — Agenda:** Asistió · No asistió · Canceló · Cita pendiente · Con venta · Control recurrente

---

# ══════════════════════════════════════════
# SECCIÓN 10 — FLUJO DE TRABAJO (AHORRA TOKENS)
# ══════════════════════════════════════════

```
AL INICIAR SESIÓN:
  Claude lee aos_memory + aos_codigo_fuente → contexto completo en 2 mensajes

AL CREAR PARCHE:
  Claude edita en aos_codigo_fuente → notifica a César
  César copia contenido completo de Supabase → pega en Apps Script → despliega
  SIN copiar parches parciales en el chat

REGLAS:
  ✅ No pedir código al inicio de sesión
  ✅ No generar archivos completos en el chat
  ✅ Solo parches mínimos cuando sea necesario
  ✅ Código completo siempre vive en Supabase
  ✅ GS_28_CodigoSync.gs: subirTodosLosHTML() / descargarCodigo(nombre) / verActualizaciones()
```

---

# ══════════════════════════════════════════
# SECCIÓN 11 — HISTORIAL DE SESIONES
# ══════════════════════════════════════════

## SESIÓN 001 — 2026-04-08
- Ultra Prompt Maestro v2.0 creado
- SOUL.md, AGENTS.md, SKILLS.md, MEMORY.md creados
- Arquitectura dual técnica+comercial definida

## SESIONES Bloque 0-2 — Abril 2026
- GS_21 + ViewAdminComisiones → Comisiones completado
- GS_22 v3.3 + ViewAdminCalls v3.3 → Llamadas Admin completado
- GS_06 v2.1.0 + ViewAdvisorCalls v2.7 → Ficha contextual completado

## SESIÓN A — 10-11 Abril 2026
- ViewAdvisorFollowups v2.0 migrado a Supabase directo
- ViewAdminHome v2.2 migrado a Supabase directo
- ViewAdvisorCommissions v2.0 migrado a Supabase directo
- ViewAdvisorCalls v3.3 migrado a Supabase directo
- GitHub Action instalado y verde
- GS_27_SyncSeguro.gs listo (pendiente instalar trigger)

## SESIÓN B INICIO — 11 Abril 2026
- 20 HTML actualizados desde RAR local (conflictos Git resueltos en 7 archivos)
- 52 archivos en Supabase sincronizados
- MEMORY.md consolidado (3 fuentes unificadas)

---

# ══════════════════════════════════════════
# SECCIÓN 12 — ECOSISTEMA FUTURO
# ══════════════════════════════════════════

```
CAPA A — Integraciones captación
  Meta Leads API + TikTok Leads → webhook → CONSOLIDADO DE LEADS automático
  Panel métricas Meta+TikTok en admin (inversión, CPL, CTR)

CAPA B — Chatbot WhatsApp IA
  WhatsApp Business API + Claude como cerebro
  Agenda citas + registra leads + detecta intención + recibe Yape/Plin

CAPA C — Chatbot TikTok/Meta Messenger
  Mismo motor que WhatsApp, diferente canal

CAPA D — Validación DNI RENIEC
  apiperu.dev (~$0.03/consulta) o PIDE (gratis, burocrático)
  Al registrar cita: DNI → autocompletar nombre + apellido + fecha nac

CAPA E — Datos externos
  Feriados Perú + clima Lima + distritos INEI

CAPA F — Prospectos B2B
  Google Maps/Outscraper → BASE_PROSPECTOS_B2B → panel score + propuestas email
```

---

# ══════════════════════════════════════════
# SECCIÓN 13 — DECISIONES ARQUITECTÓNICAS
# ══════════════════════════════════════════

| ID | Decisión | Alternativa | Razón | Fecha |
|----|----------|-------------|-------|-------|
| DA-01 | Arquitectura dual técnica+comercial | Solo técnica | Visión de negocio | 2026-04-08 |
| DA-02 | Modular: SOUL/AGENTS/SKILLS/MEMORY | Prompt monolítico | Escalabilidad | 2026-04-08 |
| DA-03 | Supabase como fuente de verdad del código | Solo GAS | Persistencia entre sesiones | 2026-04-10 |
| DA-04 | Lectura directa Supabase en browser | GAS intermediario | 3-10x más rápido | 2026-04-10 |
| DA-05 | GitHub Action para sync automático | Manual | Trazabilidad + historial | 2026-04-11 |
| DA-06 | NUNCA sync con DELETE | Bidireccional | Riesgo de pérdida de datos | 2026-04-10 |
| DA-07 | Railway para backend futuro | GAS permanente | Escalabilidad SaaS | Pendiente |

---

# ══════════════════════════════════════════
# SECCIÓN 14 — METODOLOGÍA CREACTIVE OS
# ══════════════════════════════════════════

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

*CREACTIVE OS · AscendaOS v1 · Consolidado 11 Abril 2026*
*Próxima acción: Sesión B — ViewAdminCalls KPIs + ViewAdminMarketing Supabase*
