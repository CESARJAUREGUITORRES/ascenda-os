# MEMORY.md — AscendaOS v1
## Contexto activo — Última actualización: 09/04/2026
## Para continuar: pega este archivo + ULTRAPROMPMT_MAESTRO.md al inicio del nuevo chat

---

## PROYECTO

- **Sistema:** AscendaOS v1 — CRM clínica estética Zi Vital (Lima, Perú)
- **Stack:** Google Apps Script + Google Sheets + WebApp HTML/CSS/JS
- **Sheet ID:** `1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM`
- **Repo GitHub:** `https://github.com/CESARJAUREGUITORRES/ascenda-os`
- **Carpeta frontend en repo:** `src/frontend/`
- **Carpeta backend en repo:** `src/backend/`
- **Operador:** César Jáuregui / CREACTIVE OS
- **Deploy URL:** `script.google.com/macros/s/AKfycbyVoliSxxF3gJTX71Yi3tTd7L1sAUSyFj3HPmBYVaFCGKy69uWLzJV6nDcYjVBn-L5/exec`

---

## ARCHIVOS GAS — ESTADO ACTUAL

```
GS_00_Shell.gs              ✅ sirve HTML como WebApp — router dinámico
GS_01_Config.gs v2.0        ✅ constantes CFG, todos los COL, MESES_ES
GS_02_Auth.gs               ✅ sesiones, tokens, turno, permisos
GS_03_CoreHelpers.gs        ✅ _up, _norm, _normNum, _date, _inRango, etc.
GS_04_DataAccess.gs         ✅ da_leadsData, da_llamadasData, da_ventasData, da_inversionData
GS_05_Cache.gs              ✅ caché (pendiente optimizar - bug B-01)
GS_06_AdvisorCalls.gs       ✅ call center asesor v2.6 - MOD-01 a MOD-10
GS_07_AdvisorMetrics.gs     ✅ ranking + api_getMisSemanaT
GS_08_Agenda.gs             ✅ citas GCal
GS_09_Patients.gs           ✅ api_getPatientProfileT
GS_10_Sales.gs              ✅ ventas asesor
GS_11_Commissions.gs        ✅ comisiones (bug B-03 en header TABLA)
GS_12_AdminDashboard.gs     ✅ home admin - KPIs + ticker + semáforo + pagos
GS_13_Marketing.gs v4.2     ✅ marketing dashboard - subsanadas/nuncaContactadas
GS_14_Billing.gs            ⚠️ bug B-07 spinner infinito
GS_15_Notifications.gs      ✅ notificaciones base
GS_16_Integrations.gs       ✅ GCal, WhatBot, webhook
GS_17_Security.gs           ✅ seguridad
GS_18_MigrationCompat.gs    ✅ aliases compatibilidad
GS_19_InversionCampanas.gs  ✅ NUEVO - CRUD inversión campañas marketing
GS_20_AdminSales.gs v2.0    ✅ NUEVO - dashboard ventas admin completo
GS_23_SheetSetup.gs         ✅ setup hojas del sistema

⚠️ GS_LeadsCampana.gs       → ELIMINAR (constantes inventadas causan errores)

PENDIENTES DE CREAR:
GS_21_AdminComisiones.gs    ← Bloque 1
GS_22_AdminCalls.gs         ← Bloque 2
GS_24_Patients360.gs        ← Bloque 3
GS_25_Config.gs             ← Bloque 4
GS_26_Services.gs           ← Bloque 9
GS_27_Products.gs           ← Bloque 10
GS_28_Warehouse.gs          ← Bloque 11
GS_29_Notifications_v2.gs   ← Bloque 8
GS_30_Caja.gs               ← Bloque 12
```

---

## ARCHIVOS HTML — ESTADO ACTUAL

```
AppShell.html               ✅ 942 líneas - overlay, turno, sidebar, SVG icons
Login.html                  ✅ pantalla login
ViewAdminHome.html v2.1     ✅ 3 cols: ventas+alertas / ticker+monitoreo / ranking+pagos
ViewAdminMarketing.html v5.1 ✅ 4 filas: KPIs / embudo+hist / 3cols / gestión operacional
ViewAdminSales.html v2.0    ✅ NUEVO - hoy/mes/año/rango - USD - historial cliente - config
ViewAdminBilling.html       ⚠️ bug B-07
ViewAdminOperations.html    ✅
ViewAdminTeam.html          ✅ (pendiente bloque 5: foto/permisos/turnos)
ViewAdvisorHome.html v1.2   ✅ embudo mes + 3 cards + mini calendario turnos
ViewAdvisorCalls.html v2.6  ✅ call center con ficha 360° lateral
ViewAdvisorAgenda.html      ✅ (pendiente bloque 6: KPIs/slots/panel lateral)
ViewAdvisorAttendance.html  ✅
ViewAdvisorCitas.html       ✅ (pendiente bloque 6: modal editar)
ViewAdvisorFollowups.html   ✅
ViewAdvisorPatients.html    ✅
ViewAdvisorSales.html       ✅
ViewAdvisorCommissions.html ✅

PENDIENTES DE CREAR:
ViewAdminComisiones.html    ← Bloque 1
ViewAdminCalls.html         ← Bloque 2
ViewAdminPatients.html      ← Bloque 3 (mejora del existente)
ViewAdminConfig.html        ← Bloque 4
ViewAdminServices.html      ← Bloque 9
ViewAdvisorServices.html    ← Bloque 9
ViewAdminProducts.html      ← Bloque 10
ViewAdminWarehouse.html     ← Bloque 11
ViewAdminCaja.html          ← Bloque 12
```

---

## COLUMNAS REALES DEL GOOGLE SHEET (GS_01_Config.gs v2.0)

```javascript
LLAM_COL = {
  FECHA: 0, NUMERO: 1, TRATAMIENTO: 2, ESTADO: 3, OBS: 4,
  HORA: 5, ASESOR: 6, _F7: 7, NUM_LIMPIO: 8, ID_ASESOR: 9,
  ANUNCIO: 10, ORIGEN: 11, INTENTO: 12, ULT_TS: 13,
  PROX_REIN: 14, RESULTADO: 15, SESSION_ID: 16, DEVICE: 17,
  WHATSAPP: 18, TS_LOG: 19, SUB_ESTADO: 20  // col U - NEW v2.0
}

LEAD_COL = {
  FECHA: 0, CELULAR: 1, TRAT: 2, ANUNCIO: 3, PREGUNTAS: 4,
  HORA: 5, _F6: 6, NUM_LIMPIO: 7
}

VENT_COL = {
  FECHA: 0, NOMBRES: 1, APELLIDOS: 2, DNI: 3, CELULAR: 4,
  TRATAMIENTO: 5, DESCRIPCION: 6, PAGO: 7, MONTO: 8,
  ESTADO_PAGO: 9, ASESOR: 10, ATENDIO: 11, SEDE: 12,
  TIPO: 13, _VACIO: 14, NUM_LIMPIO: 15, VENTA_ID: 16,
  NRO_DOC: 17, ESTADO_DOC: 18
}

AG_COL = {
  ID: 0, FECHA: 1, TRATAMIENTO: 2, TIPO_CITA: 3, SEDE: 4,
  NUMERO: 5, NOMBRE: 6, APELLIDO: 7, DNI: 8, CORREO: 9,
  ASESOR: 10, ID_ASESOR: 11, ESTADO: 12, VENTA_ID: 13,
  OBS: 14, TS_CREADO: 15, TS_ACTUALIZADO: 16, HORA_CITA: 17,
  ETIQUETA_CAMP: 18, DOCTORA: 19, TIPO_ATENCION: 20, GCAL_ID: 21
}

RRHH_COL = {
  CODIGO: 0, NOMBRE: 1, APELLIDO: 2, PUESTO: 3, SUELDO: 4,
  FECHA_ING: 5, FECHA_SAL: 6, ESTADO: 7, META: 8, BONUS: 9,
  SEDE: 10, LABEL: 11, USUARIO: 12, PASS: 13, NUMERO: 14,
  AGENDA: 15, PERMISOS: 16, FOTO_URL: 17  // NEW v2.0
}

PAC_COL = {
  ID: 0, NOMBRES: 1, APELLIDOS: 2, TELEFONO: 3, EMAIL: 4,
  DOCUMENTO: 5, SEXO: 6, FECHA_NAC: 7, DIRECCION: 8, OCUPACION: 9,
  SEDE: 10, FUENTE: 11, FECHA_REG: 12, TOTAL_COMPRAS: 13,
  TOTAL_FACTURADO: 14, ULTIMA_VISITA: 15, TOTAL_LLAMADAS: 16,
  TOTAL_CITAS: 17, ESTADO: 18, NOTAS: 19, FOTO_URL: 20  // NEW v2.0
}

CONF_COL = { CLAVE: 0, VALOR: 1, DESCRIPCION: 2, UPDATED_AT: 3, UPDATED_BY: 4 }
TURN_COL = { FECHA: 0, ID_ASESOR: 1, ASESOR: 2, HORA_ENTRADA: 3, HORA_SALIDA: 4,
  MIN_BREAK: 5, MIN_BANIO: 6, MIN_ATENCION: 7, MIN_LIMPIEZA: 8,
  MIN_CAPACITACION: 9, MIN_OTROS: 10, MIN_TRABAJO: 11,
  TARDANZA_MIN: 12, HORAS_EXTRA_MIN: 13, ESTADO_TURNO: 14,
  TS_CREADO: 15, TS_ACTUALIZADO: 16 }
```

---

## HOJAS GOOGLE SHEET

```
EXISTENTES Y EN USO:
  CONSOLIDADO DE LLAMADAS       ~11,830 filas (Abril 2026)
  CONSOLIDADO DE LEADS
  CONSOLIDADO DE VENTAS         74 ventas Abril / S/33,328
  AGENDA_CITAS
  SEGUIMIENTOS
  CONSOLIDADO_DE_PACIENTES      ~6,994 filas
  RRHH
  TABLA DE COMISIONES           cols A-B (productos) y D-E (servicios)
  COMISIONES                    comisión servicios: 0.50% del monto
  CONSOLIDADO DE INVERSION DE CAMPAÑAS  ← nombre real con Ñ
  LOG_TURNOS                    ← NEW v2.0
  CONFIGURACION                 ← NEW v2.0

NUEVAS CREADAS EN SESIÓN 09/04/2026:
  CAT_METODOS_PAGO              ← creada por setupSalesSheets()
  METAS_VENTAS                  ← creada por setupSalesSheets()
  ⚠️ BUG: CAT_METODOS_PAGO quedó vacía - fix pendiente en GS_20

ESTRUCTURA CONSOLIDADO DE INVERSION DE CAMPAÑAS:
  Col A: TRATAMIENTO
  Col B: MES (ENERO..DICIEMBRE)
  Col C: INVERSION (número)
  Col D: RED_SOCIAL (META ADS / TIKTOK ADS / GOOGLE ADS / ORGÁNICO) ← creada
  Col E: ANIO (número) ← creada
  Headers cols D y E dicen "Columna 1" y "Columna 2" (cosmético, no afecta)
  Fix: ejecutar setupInversionSheet() de nuevo → rescribe headers correctos
```

---

## NOMBRES DE HOJAS (CFG en GS_01_Config.gs)

```javascript
CFG.SHEET_LLAMADAS     = "CONSOLIDADO DE LLAMADAS"
CFG.SHEET_LEADS        = "CONSOLIDADO DE LEADS"
CFG.SHEET_VENTAS       = "CONSOLIDADO DE VENTAS"
CFG.SHEET_AGENDA       = "AGENDA_CITAS"
CFG.SHEET_SEGUIMIENTOS = "SEGUIMIENTOS"
CFG.SHEET_PACIENTES    = "CONSOLIDADO_DE_PACIENTES"
CFG.SHEET_INVERSION    = "CONSOLIDADO DE INVERSION DE CAMPAÑAS"  // con Ñ real
CFG.SHEET_TURNOS       = "LOG_TURNOS"
CFG.SHEET_CONFIG_SYS   = "CONFIGURACION"
// NUEVAS - agregar a GS_01_Config.gs cuando se creen:
// CFG.SHEET_CAT_METODOS  = "CAT_METODOS_PAGO"
// CFG.SHEET_METAS        = "METAS_VENTAS"
```

---

## CALENDARIOS GOOGLE CALENDAR

```
DOCTORAS:
  ID: 3784316650e1124f3eb82be4f123001347a18fb1808e4292e0d0503925d4f967@group.calendar.google.com
  Formato evento: "(PROCED)DRA YESSICA PEREZ 5PM - 7.30PM"
  Sede en LOCATION: "Av. Javier Prado Este 996" → SAN ISIDRO
                    "Av. Brasil 1170"            → PUEBLO LIBRE

PERSONAL/ASESORES (HORARIO_PERSONAL_CAL_ID):
  ID: 2db1abef4cf3589e8646a162324c5818ef5732918ae8a113c1792e759a43e0c2@group.calendar.google.com
  Formato evento: "🟢 MIREYA - Turno Enfermería | SAN ISIDRO"
  Verde (🟢) = SAN ISIDRO | Amarillo (🟡) = PUEBLO LIBRE

LIMITACIÓN TÉCNICA:
  GAS solo accede al calendario del Gmail que autorizó el script.
  Los IDs son de cuentas distintas → editables desde Config (Bloque 4)
  pero cambiar Gmail de autorización requiere reautorizar el script manualmente.
```

---

## DATOS DEL NEGOCIO

```
Empresa: Zi Vital (clínica estética)
Sedes: San Isidro · Pueblo Libre (Lima, Perú)
Moneda principal: Soles (PEN) - también hay ventas en USD

Equipo activo:
  Asesoras: RUVILA, MIREYA, SRA CARMEN
  Asesor: WILMER
  Admin: CESAR
  Doctoras (en sistema): DRA CAROLINA, DRA PAMELA, DRA YESSICA

Datos reales al 09/04/2026:
  Ventas Mes Abril: 74 ventas · S/33,328.45
    San Isidro: S/22,632 · 41 ventas
    Pueblo Libre: S/10,696 · 33 ventas
  Ticket promedio: S/450
  Servicios del mes: 53 · Productos: 21
  Adelantos pendientes: 2 (S/1,300 + S/300)
  Proyección mes: S/111,094 (ritmo S/3,703/día · día 9/30)

  Histórico mensual:
    ENE 2026: 1018 leads · S/90,931 · 191 ventas · 18.8% conv
    FEB 2026: 904 leads  · S/84,486 · 179 ventas · 19.8% conv
    MAR 2026: 676 leads  · S/63,521 · 155 ventas · 22.9% conv
    ABR 2026: 51 leads   · S/33,328 · 74 ventas  · 145% conv (mes en curso)

Top tratamientos Abril:
  1. TOXINA S/9,910
  2. ACIDO HIALURONICO S/8,645
  3. COMPRA DE PRODUCTO S/2,948
  4. HIFU S/1,998
  5. BIOESTIMULADOR S/1,799
```

---

## LÓGICA DE NEGOCIO — REGLAS IMPORTANTES

```
COMISIONES:
  Servicios: 0.50% del monto de venta
  Productos: según tabla (col A=monto mínimo, col B=comisión)
  TABLA DE COMISIONES en GS: cols A-B (productos) y D-E (servicios)

LEADS Y MARKETING:
  - Leads del mes = números nuevos del período
  - Llamados = leads únicos contactados (NO total llamadas)
  - Ticker Home Admin muestra solo leads del mes
  - Historial: LLAM. = leads únicos contactados (fix aplicado 09/04)
  - Sin llamar del mes: foto fija al cierre del mes
  - Subsanadas: leads sin llamar del mes contactados después
  - Nunca contactadas: los que siguen sin llamada en toda la historia
  
INVERSIÓN DE CAMPAÑAS:
  - Se registra por tratamiento + mes + red social + año
  - Se accede con: da_inversionData(mes, anio, 'mes')
  - Funciones CRUD en GS_19_InversionCampanas.gs
  - setupInversionSheet() ejecutar UNA VEZ para agregar cols D y E

VENTAS Y CAJA:
  - ESTADO_PAGO: ADELANTO / PAGO COMPLETO / PENDIENTE
  - USD detectado: si campo PAGO contiene "$" o "USD" o "DOLAR"
  - Histórico de cliente: api_getClienteHistorialT(token, num)
  - Metas en hoja METAS_VENTAS con clave yyyy-MM

ALMACÉN (futuro Bloque 11):
  - Auto-descuento al cerrar venta en GS_10
  - 3 almacenes: SI / PL / CTR (central)
  - Insumos: descuento manual con responsable
  - Productos: descuento automático vinculado a venta
```

---

## BUGS ACTIVOS — ESTADO AL 09/04/2026

```
🔴 B-01 · Velocidad ~3min en todos los paneles
   Causa: GAS lee sheets enteras sin caché eficiente
   Hojas: LLAMADAS (11,830 filas), PACIENTES (6,994 filas)
   Fix: Precarga caché al login + reducir cols leídas
   Archivo: GS_05_Cache.gs + AppShell.html
   Estado: PENDIENTE

🔴 B-02 · Fechas "DEC 30 1899" en seguimientos
   Causa: HORA_PROG guardada con TZ Colombia
   Fix: Sanitizar parseo en api_getMySeguimientosT
   Archivo: GS_06_AdvisorCalls.gs MOD-03
   Estado: PENDIENTE

🔴 B-03 · "Error" en Mis Comisiones del asesor
   Causa: TABLA DE COMISIONES header mal leído
   Fix: Revisar GS_11 + estructura hoja
   Estado: PENDIENTE

🟡 B-04 · Calendario GCal vacío en Call Center
   Causa: api_getSemanaCalT no retorna datos
   Archivo: GS_06_AdvisorCalls.gs MOD-10
   Estado: PENDIENTE

🟡 B-05 · undefined min SRA CARMEN semáforo
   Causa: LOG_PERSONAL sin registro válido
   Archivo: GS_12_AdminDashboard.gs
   Estado: PENDIENTE

🟡 B-06 · Facturación KPIs spinner infinito
   Causa: GS_14 timeout o bug lectura
   Archivo: GS_14_Billing.gs
   Estado: PENDIENTE

🟡 B-07 · Zona horaria Colombia vs Lima/Perú
   Causa: JS usa TZ del navegador
   Fix: Forzar TZ Lima en frontend
   Estado: PENDIENTE

🟡 B-08 · CAT_METODOS_PAGO creada vacía
   Causa: setupSalesSheets() leía índice PAGO+1 en vez de SEDE
   Fix en GS_20: cambiar a getRange con col 14 cols completas
   Estado: PENDIENTE - fix documentado en log sesión
```

---

## PATCHES APLICADOS EN SESIÓN 09/04/2026

```
✅ GS_12_AdminDashboard.gs — api_getMarketingTicker()
   Fix: llamados = leads únicos contactados (no total llamadas)
   Ahora: Leads 51 · Llamados 50 · Ventas 0 (consistente con Marketing)

✅ GS_13_Marketing.gs v4.2
   Fix: _buildHistorialMeses → llamados = leads únicos del mes
   Nuevo: subsanadas / nuncaContactadas / pctSubsanadas / pctNunca
   El histórico ya no muestra 1387 llamadas sino 50

✅ GS_19_InversionCampanas.gs — setupInversionSheet()
   Cols D (RED_SOCIAL) y E (ANIO) creadas en sheet
   Datos de Marzo guardados correctamente

✅ ViewAdminMarketing.html v5.1
   Nuevo layout 4 filas aprobado y funcionando
   Modal inversión con filtro por mes/año funcionando
   Chips por red social: META ADS S/1,500 visible

✅ GS_20_AdminSales.gs v2.0
   Dashboard con modos Hoy/Mes/Año/Rango
   Detección USD automática
   Historial cliente + WA plantillas
   Config metas y métodos de pago
   Hojas METAS_VENTAS y CAT_METODOS_PAGO creadas

✅ ViewAdminSales.html v2.0
   Filtros Hoy/Mes/Año/Rango funcionando
   Formatos S/33,328.45 y $1,250.00
   Cards sede con desglose serv/prod/USD
   Chips métodos de pago por sede
   Modal adelantos con historial de cliente
   Botones WA: "Seguimiento cita" y "Pago pendiente"
   Modal Config: metas + métodos
```

---

## FUNCIONES API — ÍNDICE COMPLETO

```
── GS_00_Shell ──
getViewHtml(fileName, token)
getScriptUrl()
api_pingT(token)

── GS_02_Auth ──
api_loginT(usuario, pass)
cc_getSession(token)
cc_requireSession()
cc_requireAdmin()
api_abrirTurnoT(token)
api_cerrarTurnoT(token)
api_registrarMinutosEstadoT(token, estado, minutos)

── GS_06_AdvisorCalls ──
api_getNextLeadT(token)
api_saveCallOutcomeT(token, payload)
api_getMySeguimientosT(token)
api_getLeadsCampanaMesT(token)
api_getMyScoreMesT(token)
api_getSemanaCalT(token)

── GS_07_AdvisorMetrics ──
api_getAdvisorDashboardT(token)
api_getTeamRanking(anio, mes)
api_getMisSemanaT(token)

── GS_08_Agenda ──
api_getAgendaT(token, fecha, sede)
api_saveCitaT(token, payload)
api_updateCitaEstadoT(token, citaId, estado)

── GS_09_Patients ──
api_getPatientProfileT(token, num)
api_savePatientT(token, payload)

── GS_10_Sales ──
api_saveSaleT(token, payload)
api_getMySalesT(token)

── GS_11_Commissions ──
api_getMyCommissionsT(token)
api_getTeamRanking(anio, mes)

── GS_12_AdminDashboard ──
api_getAdminHomeKpisT(token)          → llama a V2
api_getAdminHomeKpisV2()              → con factHoySI, factHoyPL, nVentasHoy
api_getTeamSemaforoT(token)
api_getMarketingTickerT(token)        → PATCH 09/04: solo leads del mes
api_getOperationsPanelT(token)
api_getAdminRankingComisionesT(token)
api_getPagosAdelantoT(token)
api_marcarPagadoT(token, ventaId)

── GS_13_Marketing ──
api_getMarketingDashboardT(token, mes, anio)
api_getAdminCallsPanelT(token, mes, anio, asesor)

── GS_19_InversionCampanas ──
setupInversionSheet()                 → ejecutar UNA VEZ
api_getInversionPanelT(token, mes, anio)
api_saveInversionRowT(token, payload)
api_deleteInversionRowT(token, rowNum)
api_getTratamientosListT(token)

── GS_20_AdminSales ──
setupSalesSheets()                    → ejecutar UNA VEZ
api_getAdminSalesDashboardT(token, modo, mes, anio, desde, hasta)
api_getAdminSalesDetailT(token, modo, mes, anio, desde, hasta, page, perPage, sede, asesor, tipo)
api_getClienteHistorialT(token, num)
api_getSalesConfigT(token)
api_saveSalesConfigT(token, payload)  → { periodo, meta, moneda, desc }
api_saveMetodoPagoT(token, payload)   → { rowNum, metodo, sede, activo, orden, moneda }
api_deleteMetodoPagoT(token, rowNum)
```

---

## ROADMAP — BLOQUES PENDIENTES

```
BLOQUE 0 — Bugs críticos (prioridad siempre)
  B-01 velocidad · B-02 fechas 1899 · B-03 comisiones
  B-04 GCal call center · B-05 undefined min · B-06 billing
  B-07 zona horaria · B-08 CAT_METODOS_PAGO vacía

BLOQUE 1 — Comisiones Admin
  GS_21_AdminComisiones.gs + ViewAdminComisiones.html
  Team commissions dashboard · tabla récord · top clientes

BLOQUE 2 — Llamadas Admin
  GS_22_AdminCalls.gs + ViewAdminCalls.html
  KPIs leads vírgenes · base vírgenes · score asesor · historial

BLOQUE 3 — Pacientes 360°
  GS_24_Patients360.gs + ViewAdminPatients.html (patch)
  Panel lateral 360° · tabs compras/citas · duplicados · notas

BLOQUE 4 — Configuración del sistema
  GS_25_Config.gs + ViewAdminConfig.html
  Datos empresa · horarios · comisiones editables · IDs GCal
  Botón verificar conexión calendarios · sedes editables

BLOQUE 5 — Equipo + fotos + permisos
  ViewAdminTeam.html (patch)
  FOTO_URL · checkboxes permisos · tab turnos · alertas tardanza

BLOQUE 6 — Agenda + Mis Citas (patch)
  ViewAdvisorAgenda.html + ViewAdvisorCitas.html
  KPIs · HOY ATIENDEN · panel lateral · slots · modal editar

BLOQUE 7 — Call Center cerrar pendientes
  GS_06 + ViewAdvisorCalls (patch)
  Fix GCal · fix ficha 360° compras

BLOQUE 8 — Notificaciones de ventas en tiempo real
  GS_29_Notifications_v2.gs + AppShell.html (patch)
  Sonido timbre · toast agrupado · badge sidebar

BLOQUE 9 — Catálogo de Servicios (Knowledge Base)
  GS_26_Services.gs + ViewAdminServices.html + ViewAdvisorServices.html
  Hoja: CAT_SERVICIOS
  Ficha completa: beneficios, contraindicaciones, insumos, doctoras
  Vista asesor: cards con popup detalle

BLOQUE 10 — Catálogo de Productos (E-commerce interno)
  GS_27_Products.gs + ViewAdminProducts.html
  Hoja: CAT_PRODUCTOS
  Cards visuales · foto · precio costo/venta · stock por sede

BLOQUE 11 — Almacén (módulo central)
  GS_28_Warehouse.gs + ViewAdminWarehouse.html
  Hojas: INVENTARIO_PROD_SI/PL/CTR · INVENTARIO_INS_SI/PL/CTR · MOV_ALMACEN
  Auto-descuento al vender · trazabilidad completa · alertas stock

BLOQUE 12 — Sistema de Caja (al final)
  GS_30_Caja.gs + ViewAdminCaja.html
  Hoja: CAJA_TURNOS
  Conecta TODO: ventas + pacientes + almacén + comisiones + marketing
```

---

## NOTAS TÉCNICAS CRÍTICAS

```
ROUTER GS_00_Shell:
  Completamente dinámico — no necesita modificarse para nuevas vistas.
  getViewHtml('ViewAdminSales', token) → carga ViewAdminSales.html automático.
  Solo agregar al sidebar en AppShell.html.

AL PEGAR EN GAS:
  Ctrl+A → Delete → Ctrl+V → Ctrl+S → Redesplegar
  Deploy → Manage deployments → lápiz → New version → Deploy

SETUP SHEETS (ejecutar una vez cada uno):
  setupInversionSheet()   → GS_19 (ya ejecutado)
  setupSalesSheets()      → GS_20 (ya ejecutado, BUG: métodos vacíos)

REPO GITHUB (público):
  Raw URL formato: https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/[ruta]
  Claude solo lee URLs escritas explícitamente en el chat.

MIGRACIÓN FUTURA A RAILWAY/NODE.JS:
  Cuando sistema esté 100% completo y validado en producción.
  Fix de velocidad ahora (sin migrar): caché al login + lazy loading.
  Estimado migración: 3-6 meses desde ahora.

CALENDARIOS GOOGLE:
  3 cuentas distintas: Cal.Doctoras / Cal.Personal / Google Contacts
  GAS solo accede al Gmail que autorizó el script.
  Solución en Bloque 4: editar IDs desde config + botón verificar.
  Cambiar Gmail autorización: reautorizar manualmente en GAS.
```

---

## INSTRUCCIÓN PARA EL PRÓXIMO CHAT

```
Soy César, continúo el desarrollo de AscendaOS v1.
Sistema en producción — clínica Zi Vital, Lima Perú.
Stack: Google Apps Script + Google Sheets + WebApp HTML/CSS/JS

Lee el ULTRAPROMPMT_MAESTRO.md primero (ya adjunto en el proyecto).
Luego lee este MEMORY.md para el contexto completo.

Contexto en GitHub:
  MEMORY: https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/docs/MEMORY.md
  Config: https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/src/backend/GS_01_Config.gs

[INDICA EL BLOQUE A TRABAJAR — ejemplo: "/bloque 1" para Comisiones Admin]

Estado al 09/04/2026:
  ✅ Completados: AppShell, Home Admin, Home Asesor, Call Center, Marketing, Ventas Admin
  🔵 Siguiente: Bloque 1 (Comisiones Admin) o Bloque 2 (Llamadas Admin)
```
