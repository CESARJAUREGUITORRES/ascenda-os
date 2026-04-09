# ROADMAP MAESTRO — AscendaOS v1
## Índice completo actualizado al 09/04/2026
## Operador: César Jáuregui / CREACTIVE OS

---

## ESTADO ACTUAL — COMPLETADO ✅

| Módulo | Archivo | Estado |
|---|---|---|
| AppShell | AppShell.html | ✅ 100% |
| Home Admin | ViewAdminHome.html v2.1 | ✅ 100% |
| Home Asesor | ViewAdvisorHome.html v1.2 | ✅ 100% |
| Call Center Asesor | ViewAdvisorCalls.html v2.6 | ✅ ~90% |
| Marketing Admin | ViewAdminMarketing.html v5.1 | ✅ 95% |
| Ventas Admin | ViewAdminSales.html v2.0 | ✅ 100% |
| GS_13 Marketing | GS_13_Marketing.gs v4.2 | ✅ 100% |
| GS_19 Inversión | GS_19_InversionCampanas.gs | ✅ 100% |
| GS_20 Ventas | GS_20_AdminSales.gs v2.0 | ✅ 100% |

---

## NUMERACIÓN DE ARCHIVOS GAS

```
GS_00  Shell
GS_01  Config
GS_02  Auth
GS_03  CoreHelpers
GS_04  DataAccess
GS_05  Cache
GS_06  AdvisorCalls
GS_07  AdvisorMetrics
GS_08  Agenda
GS_09  Patients
GS_10  Sales
GS_11  Commissions
GS_12  AdminDashboard
GS_13  Marketing
GS_14  Billing
GS_15  Notifications
GS_16  Integrations
GS_17  Security
GS_18  MigrationCompat
GS_19  InversionCampanas    ← NUEVO (creado)
GS_20  AdminSales           ← NUEVO (creado)
GS_21  AdminComisiones      ← PENDIENTE
GS_22  AdminCalls           ← PENDIENTE
GS_23  SheetSetup           ← EXISTENTE
GS_24  Patients360          ← PENDIENTE
GS_25  Config               ← PENDIENTE
GS_26  Services             ← PENDIENTE (NUEVO - Bloque 14)
GS_27  Products             ← PENDIENTE (NUEVO - Bloque 15)
GS_28  Warehouse            ← PENDIENTE (NUEVO - Bloque 16)
GS_29  Notifications_v2     ← PENDIENTE (NUEVO - Bloque 17)
GS_30  Caja                 ← PENDIENTE (NUEVO - Bloque 18, al final)
```

---

## HOJAS GOOGLE SHEET — EXISTENTES Y NUEVAS

### EXISTENTES (ya en uso)
```
CONSOLIDADO DE LLAMADAS
CONSOLIDADO DE LEADS
CONSOLIDADO DE VENTAS
AGENDA_CITAS
SEGUIMIENTOS
CONSOLIDADO_DE_PACIENTES
RRHH
TABLA DE COMISIONES
COMISIONES
CONSOLIDADO DE INVERSION DE CAMPAÑAS
LOG_TURNOS
CONFIGURACION
```

### NUEVAS — CREADAS EN ESTA SESIÓN
```
CAT_METODOS_PAGO     ← creada por setupSalesSheets()
METAS_VENTAS         ← creada por setupSalesSheets()
```

### NUEVAS — PENDIENTES DE CREAR
```
CAT_SERVICIOS        ← Bloque 14 (Servicios)
CAT_PRODUCTOS        ← Bloque 15 (Productos)
INVENTARIO_PROD_SI   ← Bloque 16 (Almacén Sede A)
INVENTARIO_PROD_PL   ← Bloque 16 (Almacén Sede B)
INVENTARIO_PROD_CTR  ← Bloque 16 (Almacén Central)
INVENTARIO_INS_SI    ← Bloque 16 (Insumos Sede A)
INVENTARIO_INS_PL    ← Bloque 16 (Insumos Sede B)
INVENTARIO_INS_CTR   ← Bloque 16 (Insumos Central)
MOV_ALMACEN          ← Bloque 16 (Movimientos trazables)
CONFIG_GCAL          ← Bloque 13 (IDs de calendarios)
NOTIF_VENTAS         ← Bloque 17 (Cola de notificaciones)
CAJA_TURNOS          ← Bloque 18 (Cierres de caja)
```

---

## ÍNDICE MAESTRO DE BLOQUES

---

### BLOQUE 0 — BUGS CRÍTICOS (prioridad siempre)
```
B-01 · Fix velocidad ~3min todos los paneles
       GS_05_Cache.gs + AppShell.html
       → Precarga caché al login + lazy loading

B-02 · Fix fechas "1899" en seguimientos
       GS_06_AdvisorCalls.gs MOD-03
       → Sanitizar HORA_PROG al parsear

B-03 · Fix "Error" en Mis Comisiones asesor
       GS_11_Commissions.gs
       → Header mal leído en TABLA DE COMISIONES

B-04 · Fix undefined min semáforo home admin
       GS_12_AdminDashboard.gs
       → Manejar null en LOG_PERSONAL

B-05 · Fix zona horaria Colombia vs Lima
       GS_03_CoreHelpers.gs + frontend
       → Forzar TZ America/Lima
```

---

### BLOQUE 1 — FASE 11: Comisiones Admin
```
Archivos:
  GS_21_AdminComisiones.gs  ← NUEVO
  ViewAdminComisiones.html  ← NUEVO

Items:
  1.1 · api_getTeamCommissionsT   → GS_21
  1.2 · api_updateComisionesT     → GS_21
  1.3 · 3 cards: Com.Total / Fact.Total / Asesor Top
  1.4 · Tabla récord equipo por mes
  1.5 · Top clientes del mes (equipo completo)
  1.6 · Tabla ventas del mes con comisión por fila
  1.7 · Modal "+ Actualizar comisiones" editable
```

---

### BLOQUE 2 — FASE 5: Llamadas Admin
```
Archivos:
  GS_22_AdminCalls.gs   ← NUEVO
  ViewAdminCalls.html   ← NUEVO

Items:
  2.1 · KPIs: Leads vírgenes, Llamados hoy, Citas, Conv%
  2.2 · Tabla "Base Vírgenes" con color por días sin llamar
  2.3 · Score por asesor con sub-estados SIN CONTACTO
  2.4 · Distribución tipificaciones en barras
  2.5 · Histórico mensual gestión
```

---

### BLOQUE 3 — FASE 6: Pacientes 360°
```
Archivos:
  GS_24_Patients360.gs       ← NUEVO
  ViewAdminPatients.html     ← PATCH del existente

Items:
  3.1 · api_getPatient360T mejorado
  3.2 · Panel lateral 360° con badges y datos personales
  3.3 · Tab Compras / Citas / Contactos en panel
  3.4 · Detección de duplicados al crear paciente
  3.5 · Campo Notas + guardar
```

---

### BLOQUE 4 — FASE 7: Configuración del sistema
```
Archivos:
  GS_25_Config.gs         ← NUEVO
  ViewAdminConfig.html    ← NUEVO

Items:
  4.1 · Datos empresa: nombre, RUC, logo URL, slogan
  4.2 · Horarios de trabajo editables por día (Lu-Do)
  4.3 · Tabla de comisiones editable (servicios/productos)
  4.4 · Fix zona horaria Lima/Perú desde config
  4.5 · IDs de Google Calendar editables
        · Cal. Doctoras (ID actual hardcodeado)
        · Cal. Personal/Asesores (ID actual hardcodeado)
  4.6 · Cuenta Gmail para Google Contacts
        · URL / email de contacto del account
  4.7 · Botón "Verificar conexión" GCal
        · Prueba que los IDs de calendarios sean válidos
        · Muestra: conectado ✅ / error ❌ con mensaje
  4.8 · Sedes: nombre, dirección, color
        · San Isidro → Azul
        · Pueblo Libre → Verde
        · Agregar nueva sede
  4.9 · Token / Webhook WhatsApp (si aplica)

NOTAS TÉCNICAS GCAL:
  El problema que describes es que tienes 3 cuentas distintas:
    · Gmail A → Cal. Doctoras
    · Gmail B → Cal. Personal/Asesores
    · Gmail C → Google Contacts
  GAS SOLO PUEDE CONECTAR AL CALENDARIO DEL GMAIL QUE
  AUTORIZÓ EL SCRIPT. No puede cambiar de cuenta en runtime.
  
  SOLUCIÓN REAL:
    · La config guarda los IDs de los calendarios
    · Los IDs ya están hardcodeados en GS_01_Config.gs
    · Lo que SÍ es editable: los IDs (si cambian)
    · Lo que NO es posible: cambiar el gmail de autorización
      desde el panel (hay que reautorizar el script en GAS)
    · Se puede agregar un botón "Reautorizar calendarios"
      que abra el flujo de OAuth de GAS
```

---

### BLOQUE 5 — FASE 8: Equipo + fotos + permisos
```
Archivos:
  ViewAdminTeam.html    ← PATCH del existente

Items:
  5.1 · Campo FOTO_URL en formulario editar usuario
  5.2 · Checkboxes de permisos por módulo
  5.3 · Tab "Turnos" → ver LOG_TURNOS por asesor
  5.4 · Alertas tardanza / break excedido en tab Turnos
```

---

### BLOQUE 6 — FASE 10: Agenda + Mis Citas (patch)
```
Archivos:
  ViewAdvisorAgenda.html    ← PATCH
  ViewAdvisorCitas.html     ← PATCH

Items:
  6.1 · KPIs superiores (Total/Confirmadas/Efectivas/Tasa%)
  6.2 · Barra "HOY ATIENDEN" con doctoras y horarios
  6.3 · Panel lateral al click en cita (reemplaza modal)
  6.4 · Botones cambio de estado con colores en panel
  6.5 · Filtros Sede + Estado
  6.6 · Slots con capacidad X/5
  6.7 · Modal editar cita completo con ESTADO + REAGENDAR
```

---

### BLOQUE 7 — FASE 9 cerrar pendientes (Call Center Asesor)
```
Archivos:
  GS_06_AdvisorCalls.gs    ← PATCH
  ViewAdvisorCalls.html    ← PATCH si necesario

Items:
  7.1 · Fix calendario GCal vacío (columnas vacías)
  7.2 · Fix Ficha 360° tab Compras sin datos
```

---

### BLOQUE 8 — Notificaciones de ventas en tiempo real
```
Archivos:
  GS_29_Notifications_v2.gs    ← NUEVO (mejora GS_15)
  AppShell.html                ← PATCH (polling + sonido)

Items:
  8.1 · Polling cada 30s: detectar ventas nuevas vs último check
  8.2 · Sonido de caja/timbre al registrar venta
  8.3 · Toast notification en cualquier panel activo
        · Si 1 venta: "Nueva venta: WILMER · Toxina · S/350 · San Isidro"
        · Si N ventas: "3 ventas nuevas · S/1,250 · San Isidro (2) + PL (1)"
  8.4 · Badge contador en sidebar del menú "Ventas"
  8.5 · Historial de notificaciones del día (campana)
  8.6 · No duplicar: registrar último TS visto por sesión
```

---

### BLOQUE 9 — Catálogo de Servicios (Knowledge Base)
```
Archivos:
  GS_26_Services.gs          ← NUEVO
  ViewAdminServices.html     ← NUEVO (admin: CRUD)
  ViewAdvisorServices.html   ← NUEVO (asesor: solo lectura)
  Hoja: CAT_SERVICIOS

Estructura CAT_SERVICIOS:
  ID · NOMBRE · DESCRIPCION · BENEFICIOS · CONTRAINDICACIONES
  DURACION_MIN · PRECIO_BASE · PRECIO_PROMO · PROMO_ACTIVA
  INSUMOS (JSON lista) · DOCTORAS_CERT (JSON lista)
  PROTOCOLO · DATOS_CIENTIFICOS · FOTO_URL · ACTIVO
  CATEGORIA · TS_CREADO · TS_ACTUALIZADO

Items:
  9.1 · api_getServicesT / api_saveServiceT / api_deleteServiceT
  9.2 · Vista admin: tabla CRUD + modal edición completa
  9.3 · Vista asesor: cards visuales con búsqueda
        · Card: foto, nombre, descripción, precio, promoción
        · Popup detalle: toda la ficha completa
        · Útil en llamada para dar info precisa al cliente
  9.4 · Filtro por categoría
  9.5 · Campo "Insumos que usa" → vinculado a almacén (Bloque 10)
  9.6 · Campo "Doctoras certificadas" → vinculado a RRHH
  9.7 · Promociones activas con fechas de vigencia
```

---

### BLOQUE 10 — Catálogo de Productos + E-commerce interno
```
Archivos:
  GS_27_Products.gs          ← NUEVO
  ViewAdminProducts.html     ← NUEVO (admin: CRUD + gestión)
  Hoja: CAT_PRODUCTOS

Estructura CAT_PRODUCTOS:
  ID · NOMBRE · DESCRIPCION · CATEGORIA · MARCA
  PRECIO_COSTO · PRECIO_VENTA · PRECIO_PROMO · PROMO_ACTIVA
  FOTO_URL · ACTIVO · TS_CREADO · TS_ACTUALIZADO
  (Stock se lee desde ALMACEN → no se guarda aquí)

Items:
  10.1 · api_getProductsT / api_saveProductT / api_deleteProductT
  10.2 · Vista admin: cards visuales estilo e-commerce
         · Grid de cards con foto, nombre, precio, stock total
         · Click card → popup detalle expandido
         · Popup: imagen grande, descripción, precio costo/venta
           stock por sede, historial de ventas del mes
         · Badge "PROMO" si hay oferta activa
  10.3 · Vista asesor: solo lectura, útil para consultar en llamada
  10.4 · Filtro por categoría / stock disponible
  10.5 · Indicador stock bajo (alerta visual)
  10.6 · Vinculado a almacén para leer stock en tiempo real
```

---

### BLOQUE 11 — Almacén (módulo central)
```
Archivos:
  GS_28_Warehouse.gs         ← NUEVO
  ViewAdminWarehouse.html    ← NUEVO
  Hojas múltiples por sede

Estructura hojas:
  INVENTARIO_PROD_{SEDE}:
    ID_PRODUCTO · NOMBRE · STOCK_ACTUAL · STOCK_MINIMO
    PRECIO_COSTO · TS_ACTUALIZADO

  INVENTARIO_INS_{SEDE}:
    ID_INSUMO · NOMBRE · UNIDAD · STOCK_ACTUAL · STOCK_MINIMO
    COSTO_UNIDAD · SERVICIO_ASOCIADO · TS_ACTUALIZADO

  MOV_ALMACEN:
    ID_MOV · FECHA · HORA · TIPO (VENTA/USO/INGRESO/TRASLADO)
    ITEM_ID · ITEM_NOMBRE · CATEGORIA (PRODUCTO/INSUMO)
    SEDE_ORIGEN · SEDE_DESTINO · CANTIDAD · RESPONSABLE
    CLIENTE · VENTA_ID · OBS · TS_LOG

Sedes de almacén:
  SI  → San Isidro
  PL  → Pueblo Libre
  CTR → Central (bodega, sin atención al público)

Items:
  11.1 · api_getWarehouseDashboardT → stock actual por sede
  11.2 · api_registerMovimientoT → ingresar movimiento manual
  11.3 · api_getMovimientosT → historial con filtros
  11.4 · Auto-descuento al registrar venta en GS_10
         → trigger onVenta → descuenta del almacén de esa sede
  11.5 · Alertas stock mínimo → notificación en panel
  11.6 · Transferencia entre sedes con trazabilidad
  11.7 · Vista admin:
         · Tab Productos: stock visual por sede con barras
         · Tab Insumos: tabla con unidades y responsable
         · Tab Movimientos: historial filtrable
         · Tab Alertas: stock bajo con botón "Registrar ingreso"
  11.8 · Cada movimiento registra:
         Quién (responsable) · Dónde (sede) · Qué (item)
         Cuánto (cantidad) · Para quién (cliente si aplica)
         Cuándo (fecha/hora)
```

---

### BLOQUE 12 — Sistema de Caja (al final — conecta todo)
```
Archivos:
  GS_30_Caja.gs              ← NUEVO
  ViewAdminCaja.html         ← NUEVO
  Hoja: CAJA_TURNOS

Conecta con:
  · CONSOLIDADO DE VENTAS (ingresos)
  · CONSOLIDADO_DE_PACIENTES (cliente)
  · CAT_METODOS_PAGO (formas de cobro)
  · MOV_ALMACEN (salida de productos)
  · COMISIONES (cálculo al cierre)
  · CONSOLIDADO DE LEADS (para cruzar conversión)
  · GS_13 Marketing (ROAS por cierre de caja)

Items:
  12.1 · Apertura y cierre de caja por sede y turno
  12.2 · Registro de transacciones en tiempo real
  12.3 · Cuadre de caja: efectivo + digital por método
  12.4 · Diferencia cuadre (sobrante/faltante)
  12.5 · Reporte de cierre: PDF descargable
  12.6 · Historial de cierres por sede y fecha
  12.7 · Cruce automático con ventas del día
  12.8 · Dashboard financiero del día: ingresos, métodos, asesores
```

---

## ORDEN ESTRATÉGICO DE EJECUCIÓN

```
PRIORIDAD 1 — Lo que está en producción y tiene bugs
  → Bloque 0: Bugs críticos (cuando aparezcan)

PRIORIDAD 2 — Módulos de gestión comercial (impacto diario)
  → Bloque 1: Comisiones Admin
  → Bloque 2: Llamadas Admin

PRIORIDAD 3 — Módulos de operación clínica
  → Bloque 3: Pacientes 360°
  → Bloque 4: Configuración del sistema
  → Bloque 6: Agenda + Mis Citas

PRIORIDAD 4 — Módulos de soporte/equipo
  → Bloque 5: Equipo + fotos + permisos
  → Bloque 7: Call Center (cerrar pendientes)

PRIORIDAD 5 — Módulos de ecosistema de producto
  → Bloque 8: Notificaciones de ventas
  → Bloque 9: Catálogo de Servicios
  → Bloque 10: Catálogo de Productos
  → Bloque 11: Almacén

PRIORIDAD 6 — Sistema de Caja (al final)
  → Bloque 12: Caja

TOTAL BLOQUES:         12
TOTAL ITEMS:          ~85
ARCHIVOS GAS NUEVOS:  10 (GS_21 a GS_30)
ARCHIVOS HTML NUEVOS: 9
ARCHIVOS PATCH:       ~6
HOJAS SHEET NUEVAS:   ~12
```

---

## NOTA SOBRE CALENDARIOS GOOGLE

```
LIMITACIÓN TÉCNICA IMPORTANTE:
  GAS solo puede acceder a calendarios del Google Account
  que autorizó el script. No se puede cambiar de cuenta
  en runtime desde el panel.

LO QUE SÍ SE PUEDE HACER DESDE CONFIGURACIÓN (Bloque 4):
  · Editar los IDs de los calendarios (si cambian)
  · Botón "Verificar conexión" → valida que el ID responde
  · Botón "Ver instrucciones" → guía para reautorizar si cambió
  
LO QUE REQUIERE INTERVENCIÓN MANUAL EN GAS:
  · Cambiar el Gmail que autoriza el script
  · Agregar un nuevo calendario de una cuenta diferente
  · Esto se hace en: GAS → Servicios → Google Calendar → reautorizar

PARA EL FUTURO (migración a Railway/Node.js):
  · Con OAuth2 propio se puede conectar cualquier Gmail
  · El usuario conecta desde el panel con un botón
  · Sin limitaciones de cuenta
```

---
*Generado por CREACTIVE OS — AscendaOS v1 Roadmap*
*Última actualización: 09/04/2026*
