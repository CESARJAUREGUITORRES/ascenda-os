# MEMORY.md — AscendaOS v1
## Contexto activo — Última actualización: 2026-04-08
## Para continuar: pega este archivo al inicio del nuevo chat

---

## PROYECTO

- **Sistema:** AscendaOS v1 — CRM clínica estética Zi Vital (Lima, Perú)
- **Stack:** Google Apps Script + Google Sheets + WebApp HTML/CSS/JS
- **Sheet ID:** `1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM`
- **Repo GitHub:** `https://github.com/CESARJAUREGUITORRES/ascenda-os`
- **Carpeta frontend en repo:** `src/frontend/` (NO src/Interfaz)
- **Operador:** César Jáuregui

---

## ARCHIVOS DEL PROYECTO (en GAS)

```
GS_00_Shell.gs              ← sirve el HTML como WebApp
GS_01_Config.gs             ← constantes CFG, LLAM_COL, LEAD_COL, VENT_COL, AG_COL
GS_02_Auth.gs               ← sesiones, tokens, funciones de turno
GS_03_CoreHelpers.gs        ← _up, _norm, _normNum, _date, _inRango, etc.
GS_04_DataAccess.gs         ← _sh, _shAgenda, _shLlamadas, etc.
GS_05_Cache.gs              ← caché
GS_06_AdvisorCalls.gs       ← MOD-01 a MOD-10 + api_getLeadsCampanaMesT
GS_07_AdvisorMetrics.gs     ← ranking equipo
GS_08_Agenda.gs             ← citas
GS_09_Patients.gs           ← api_getPatientProfileT
GS_10_Sales.gs              ← ventas
GS_12_AdminDashboard.gs     ← home admin
GS_13_Marketing.gs          ← marketing dashboard
GS_14_Billing.gs            ← facturación
GS_15_Notifications.gs      ← notificaciones
GS_16_Integrations.gs       ← integraciones (GCal, WhatBot, webhook)
GS_17_Security.gs           ← seguridad
GS_18_MigrationCompat.gs    ← aliases de compatibilidad
GS_23_SheetSetup.gs         ← setup de hojas (script de inicialización)
GS_LeadsCampana.gs          ← ⚠️ ELIMINAR (constantes inventadas, causa errores)
```

---

## ARCHIVOS FRONTEND (en repo src/frontend/)

```
AppShell.html               ← 942 líneas, 53.6 KB — shell global ✅ HECHO
Login.html                  ← pantalla de login
ViewAdminBilling.html       ← facturación admin
ViewAdminHome.html          ← home admin ✅ HECHO
ViewAdminMarketing.html     ← marketing
ViewAdminOperations.html    ← operaciones
ViewAdminTeam.html          ← equipo
ViewAdvisorAgenda.html      ← agenda del asesor
ViewAdvisorAttendance.html  ← asistencia asesor
ViewAdvisorCalls.html       ← call center asesor ✅ HECHO v2.6

PENDIENTES DE CREAR:
  ViewAdminSales.html       ← Fase 3 (nuevo)
  ViewAdminCalls.html       ← Fase 5 (nuevo)
  ViewAdminPatients.html    ← Fase 6 (nuevo — mejora del existente)
  ViewAdminConfig.html      ← Fase 7 (nuevo)
  ViewAdminComisiones.html  ← Fase 11 (nuevo)
```

---

## COLUMNAS REALES DEL GOOGLE SHEET (verificadas en GS_01_Config.gs v2.0)

```javascript
LLAM_COL = {
  FECHA: 0, NUMERO: 1, TRATAMIENTO: 2, ESTADO: 3, OBS: 4,
  HORA: 5, ASESOR: 6, _F7: 7, NUM_LIMPIO: 8, ID_ASESOR: 9,
  ANUNCIO: 10, ORIGEN: 11, INTENTO: 12, ULT_TS: 13,
  PROX_REIN: 14, RESULTADO: 15, SESSION_ID: 16, DEVICE: 17,
  WHATSAPP: 18, TS_LOG: 19, SUB_ESTADO: 20  ← NEW v2.0 col U
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

RRHH_COL = {
  ... (16 cols originales A-P) ...
  PERMISOS: 16,  ← NEW v2.0 col Q
  FOTO_URL: 17   ← NEW v2.0 col R
}

PAC_COL = {
  ... (20 cols originales A-T) ...
  FOTO_URL: 20   ← NEW v2.0 col U
}
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
CFG.SHEET_INVERSION    = "CONSOLIDADO DE INVERSION DE CAM"  ← FIX v2.0
CFG.SHEET_TURNOS       = "LOG_TURNOS"                       ← NEW v2.0
CFG.SHEET_CONFIG_SYS   = "CONFIGURACION"                    ← NEW v2.0
```

---

## CALENDARIOS GOOGLE CALENDAR

```
DOCTORAS:
  ID: 3784316650e1124f3eb82be4f123001347a18fb1808e4292e0d0503925d4f967@group.calendar.google.com
  Formato SUMMARY: "(PROCED)DRA YESSICA PEREZ 5PM - 7.30PM"
  Sede en LOCATION: "Av. Javier Prado Este 996" → SAN ISIDRO
                    "Av. Brasil 1170"            → PUEBLO LIBRE

ENFERMERÍA:
  ID: 2db1abef4cf3589e8646a162324c5818ef5732918ae8a113c1792e759a43e0c2@group.calendar.google.com
  Formato SUMMARY: "🟢 MIREYA - Turno Enfermería | SAN ISIDRO"
```

---

## ESTADO ACTUAL — FASES COMPLETADAS

```
FASE 12 — Estructura de datos         ✅ 100% COMPLETA
  GS_01_Config.gs: todas las constantes nuevas ✅
  GS_02_Auth.gs: api_abrirTurnoT, api_cerrarTurnoT, api_registrarMinutosEstadoT ✅
  ⚠️ Hojas físicas LOG_TURNOS y CONFIGURACION en Sheet: SIN CONFIRMAR

FASE 1 — AppShell                     ✅ COMPLETA (declarada por César)
  942 líneas, 53.6 KB
  Overlay bloqueante, turno, sidebar toggle, menú admin ✅

FASE 2 — Home Admin                   ✅ COMPLETA (declarada por César)
  Monitoreo equipo visible en imagen live ✅
  KPIs reales funcionando ✅

FASE 9 — Call Center Asesor           ✅ ~90% COMPLETA
  v2.6 instalada y funcionando en producción ✅
  Sub-tipificación SIN CONTACTO ✅
  Hora AM/PM en seguimiento ✅
  Ficha 360° lateral ✅
  Datos en métricas visibles ✅
  ⚠️ Pendiente: calendario GCal no conecta (columnas vacías)
  ⚠️ Pendiente: Ficha 360° tab Compras no muestra datos
```

---

## BUGS ACTIVOS — PRIORIDAD

```
🔴 B-01 · Velocidad ~3min en todos los paneles
   Causa: Sin caché precargado, GAS lee sheets enteras en cada request
   Hojas afectadas: LLAMADAS (11,830 filas), PACIENTES (6,994 filas)
   Fix: Precarga de caché al login + reducir cols leídas
   Archivo: GS_05_Cache.gs + AppShell.html

🔴 B-02 · Fechas "DEC 30 1899" en seguimientos
   Causa: HORA_PROG guardada como string con TZ Colombia
   Síntoma: 9 seguimientos "vencidos" con fecha 1899
   Fix: Sanitizar parseo en api_getMySeguimientosT
   Archivo: GS_06_AdvisorCalls.gs MOD-03

🔴 B-03 · "Error" en Mis Comisiones del asesor
   Causa: TABLA DE COMISIONES con estructura de header mal leída
   Fix: Revisar GS de comisiones + estructura de la hoja
   Archivo: GS de comisiones (por identificar)

🟡 B-04 · Calendario GCal vacío en Call Center
   Causa: api_getSemanaCalT no retorna datos
   Fix: Debug de la función, verificar permisos GCal
   Archivo: GS_06_AdvisorCalls.gs MOD-10

🟡 B-05 · "undefined min" SRA CARMEN en Home Admin
   Causa: LOG_PERSONAL sin registro válido para ese asesor
   Fix: Manejar null en cálculo de tiempo en GS_12

🟡 B-06 · ROAS/CAC vacíos en Marketing
   Causa: Nombre hoja ya corregido en Config pero falta redespliegue
   Fix: Redesplegar + verificar lectura de INVERSION

🟡 B-07 · Facturación KPIs no cargan (spinner infinito)
   Causa: GS_14 timeout o bug en lectura
   Fix: Debug GS_14_Billing.gs

🟡 B-08 · Zona horaria Colombia en lugar de Lima/Perú
   Causa: Cliente JS usa TZ del navegador, no CFG.TZ
   Fix: Forzar TZ Lima en frontend
```

---

## ÍNDICE MAESTRO DE TRABAJO — ORDEN DE EJECUCIÓN

### BLOQUE 0 — BUGS CRÍTICOS (primero, bloquean uso diario)
```
B-01 · Fix velocidad precarga caché          → GS_05 + AppShell
B-02 · Fix fechas 1899 seguimientos          → GS_06 MOD-03
B-03 · Fix Error comisiones asesor           → GS comisiones
B-04 · Fix undefined min SRA CARMEN          → GS_12
B-05 · Fix zona horaria Colombia             → GS_06 + frontend
```

### BLOQUE 1 — FASE 1+2 verificación (confirmar items pendientes)
```
1.1 · Verificar todos los items F1 AppShell  → leer código
1.2 · Verificar todos los items F2 HomeAdmin → leer código
```

### BLOQUE 2 — FASE 9 cerrar pendientes
```
9.1 · Fix calendario GCal                    → GS_06 MOD-10
9.2 · Fix Ficha 360° tab Compras             → GS_09_Patients.gs
```

### BLOQUE 3 — FASE 4: Marketing Fix
```
4.1 · Fix ROAS/CAC vacíos                    → GS_13
4.2 · Fix embudo responde al filtro de mes   → GS_13
4.3 · Fix citas en embudo = solo AGENDA      → GS_13
4.4 · Botón + Presupuesto campaña            → ViewAdminMarketing + GS_13
4.5 · Filtrar filas vacías en tablas         → ViewAdminMarketing
4.6 · Fix embudo 0 ventas vs histórico 62    → GS_13
```

### BLOQUE 4 — FASE 3: Ventas Admin (módulo nuevo)
```
5.1 · Crear GS_19_AdminSales.gs              → NUEVO
5.2 · Crear ViewAdminSales.html              → NUEVO
5.3 · Cards facturado, ventas, por sede      → En 5.2
5.4 · Métodos de pago por sede expandible    → En 5.2
5.5 · Popup Adelantos + marcar pagado        → En 5.2 + 5.1
5.6 · Tabla detalle paginada por sede        → En 5.2
5.7 · Proyección del mes                     → En 5.1
```

### BLOQUE 5 — FASE 11: Comisiones Admin (módulo nuevo)
```
6.1 · api_getTeamCommissionsT                → GS_12 patch
6.2 · api_updateComisionesT                  → GS_12 patch
6.3 · Crear ViewAdminComisiones.html         → NUEVO
6.4 · Cards superiores (3)                   → En 6.3
6.5 · Tabla récord equipo por mes            → En 6.3
6.6 · Top clientes del mes                   → En 6.3
6.7 · Tabla ventas con comisión por fila     → En 6.3
6.8 · Modal actualizar comisiones editable   → En 6.3
```

### BLOQUE 6 — FASE 5: Llamadas Admin (módulo nuevo)
```
7.1 · Crear GS_20_CallsAdmin.gs              → NUEVO
7.2 · Crear ViewAdminCalls.html              → NUEVO
7.3 · KPIs leads vírgenes, llamados, conv%   → En 7.2
7.4 · Tabla base vírgenes color por días     → En 7.2
7.5 · Score por asesor con sub-estados       → En 7.2
7.6 · Distribución tipificaciones barras     → En 7.2
7.7 · Histórico mensual gestión              → En 7.2
```

### BLOQUE 7 — FASE 6: Pacientes 360° (módulo nuevo)
```
8.1 · Crear GS_21_Patients360.gs             → NUEVO
8.2 · Mejorar ViewAdminPatients.html         → PATCH
8.3 · Panel lateral: badges + datos          → En 8.2
8.4 · Tabs Compras / Citas / Contactos       → En 8.2
8.5 · Detección de duplicados                → En 8.1 + 8.2
8.6 · Campo Notas + guardar                  → En 8.2
```

### BLOQUE 8 — FASE 7: Configuración (módulo nuevo)
```
9.1 · Crear GS_22_Config.gs                  → NUEVO
9.2 · Crear ViewAdminConfig.html             → NUEVO
9.3 · Datos empresa (nombre, RUC, logo)      → En 9.2
9.4 · Horarios de trabajo editables          → En 9.2
9.5 · Tabla comisiones editable              → En 9.2
9.6 · Fix TZ Lima desde config               → En 9.1
```

### BLOQUE 9 — FASE 8: Equipo + fotos + permisos
```
10.1 · Campo FOTO_URL en editar usuario      → ViewAdminTeam patch
10.2 · Checkboxes permisos por módulo        → ViewAdminTeam patch
10.3 · Tab Turnos → ver LOG_TURNOS           → ViewAdminTeam patch
10.4 · Alertas tardanza / break excedido     → ViewAdminTeam patch
```

### BLOQUE 10 — FASE 10: Agenda + Mis Citas (patch)
```
11.1 · KPIs superiores en agenda             → ViewAdvisorAgenda patch
11.2 · Barra HOY ATIENDEN con doctoras       → ViewAdvisorAgenda patch
11.3 · Panel lateral al click en cita        → ViewAdvisorAgenda patch
11.4 · Botones cambio estado con colores     → ViewAdvisorAgenda patch
11.5 · Filtros Sede + Estado                 → ViewAdvisorAgenda patch
11.6 · Slots con capacidad X/5              → ViewAdvisorAgenda patch
11.7 · Modal editar cita completo + REAGENDAR → ViewAdvisorCitas patch
```

---

## RESUMEN EJECUTIVO

```
TOTAL ÍTEMS PENDIENTES:    ~65
BUGS CRÍTICOS:              5  (Bloque 0)
ARCHIVOS NUEVOS:            7  (GS_19, GS_20, GS_21, GS_22 + 4 HTML)
ARCHIVOS A PARCHEAR:       ~8
ARCHIVOS A VERIFICAR:       2  (AppShell, ViewAdminHome)
ARCHIVO A ELIMINAR:         1  (GS_LeadsCampana.gs)
```

---

## DECISIÓN TÉCNICA IMPORTANTE — RAILWAY

```
PREGUNTA: ¿Migrar a Railway mejoraría la velocidad?
RESPUESTA: SÍ, pero NO ahora. Explicación:

PROBLEMA ACTUAL (velocidad ~3min):
  El cuello de botella NO es el servidor — es Google Apps Script
  leyendo Google Sheets con 6,994 + 11,830 filas sin caché eficiente.
  Railway no resuelve eso porque el backend sigue siendo GAS.

LO QUE RAILWAY RESOLVERÍA (en Fase 2):
  - Backend Node.js con Supabase (PostgreSQL) → consultas en <100ms
  - Sin límites de tiempo de ejecución (GAS tiene 30s límite)
  - Sin límites de quota de Google (6min/día en GAS)
  - Multi-tenancy real para vender AscendaOS a otras clínicas
  - API REST documentada

CUÁNDO MIGRAR A RAILWAY:
  → Cuando el sistema esté 100% completo y validado en producción
  → Cuando tengas 2-3 clientes pagando (validación comercial)
  → Estimado: 3-6 meses desde ahora
  → Costo Railway: ~$5-20/mes (vs $0 actual en GAS)

FIX DE VELOCIDAD AHORA (sin migrar):
  → Precarga de caché al momento del login
  → Reducir columnas leídas (solo las necesarias)
  → Lazy loading: no cargar todo a la vez
  → Esto baja de 3min a ~8-15 segundos realistas
```

---

## DATOS DEL EQUIPO (activos en producción)

```
Asesores activos: RUVILA, MIREYA, WILMER, SRA CARMEN
Admin: CESAR
Doctoras (inactivas en sistema): DRA CAROLINA, DRA PAMELA, DRA YESSICA
Datos reales al 08/04/2026:
  Pacientes: 6,994 total (134 activos, 6,860 nuevos sin actualizar)
  Llamadas Abril: 563 (WILMER: 563 acum., Citas: 37, Fact: S/9,049)
  Ventas Año: ENE S/90,931 · FEB S/84,486 · MAR S/63,521 · ABR ~S/30,987
```

---

## NOTAS TÉCNICAS IMPORTANTES

```
- Repo GitHub es PÚBLICO → Claude puede leer raw URLs directamente
  Formato: https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/[ruta]
  IMPORTANTE: Claude solo lee URLs que el usuario escribe explícitamente en el chat
  
- Carpeta frontend en repo: src/frontend/ (NO src/Interfaz)
  
- Al pegar archivos en GAS: Ctrl+A → Delete → Ctrl+V → Ctrl+S → Redesplegar
  
- Redespliegue: Deploy → Manage deployments → lápiz → New version → Deploy

- GS_LeadsCampana.gs debe ELIMINARSE del proyecto GAS
  (tiene constantes HOJA_LEADS, LEADS_COL inventadas que no existen)
```

---

## INSTRUCCIÓN PARA EL PRÓXIMO CHAT

```
Soy César, continúo el desarrollo de AscendaOS v1.
Sistema activo en producción — clínica Zi Vital, Lima Perú.

Lee el contexto completo en:
https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/docs/MEMORY.md

Archivos clave para leer antes de arrancar:
- GS_06: https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/src/backend/GS_06_AdvisorCalls.gs
- Config: https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/src/backend/GS_01_Config.gs

[DESCRIBE QUÉ HACER EN ESTA SESIÓN — ejemplo: "Atacar Bloque 0 bugs críticos"]
```
