/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_01_Config.gs                            ║
 * ║  Módulo: Configuración Global y Constantes                  ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 2.0.0  (Fase 12 — Estructura de datos v2)        ║
 * ║  Dependencias: Ninguna (es la base de todo)                 ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · ID del Spreadsheet
 *   MOD-02 · Nombres oficiales de hojas (CFG)
 *   MOD-03 · Índices de columnas por hoja
 *   MOD-04 · Estados y roles válidos
 *   MOD-05 · Configuración de sistema
 *   MOD-06 · Constantes de negocio
 *
 * CHANGELOG v2.0.0:
 *   - FIX: SHEET_INVERSION corregido (nombre truncado en GSheets)
 *   - NEW: SHEET_TURNOS → hoja LOG_TURNOS para control de turno
 *   - NEW: SHEET_CONFIG_SYS → hoja CONFIGURACION del sistema
 *   - NEW: RRHH_COL.PERMISOS (col Q) y RRHH_COL.FOTO_URL (col R)
 *   - NEW: LLAM_COL.SUB_ESTADO (col U) para sub-tipificación
 *   - NEW: PAC_COL.FOTO_URL (col U) en CONSOLIDADO_DE_PACIENTES
 *   - NEW: TURN_COL → índices de columnas de LOG_TURNOS
 *   - NEW: CONF_COL → índices de columnas de CONFIGURACION
 *   - NEW: ESTADOS_LLAMADA actualizado con "SIN CONTACTO"
 *   - NEW: SUB_ESTADOS_SIN_CONTACTO para sub-tipificación
 *   - NEW: HORARIOS_CONFIG con turnos de trabajo
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · SPREADSHEET ID
// ══════════════════════════════════════════════════════════════
// A01_START
var SHEET_ID = "1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM";
// A01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · NOMBRES OFICIALES DE HOJAS (CFG)
// Usar SIEMPRE estas constantes — nunca strings literales
// ══════════════════════════════════════════════════════════════
// A02_START
var CFG = {
  // Hoja principal del proyecto
  SHEET_ID:      "1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM",

  // ── Hojas operativas núcleo ──────────────────────────────────
  SHEET_RRHH:         "RRHH",
  SHEET_LLAMADAS:     "CONSOLIDADO DE LLAMADAS",
  SHEET_LEADS:        "CONSOLIDADO DE LEADS",
  SHEET_VENTAS:       "CONSOLIDADO DE VENTAS",
  SHEET_AGENDA:       "AGENDA_CITAS",
  SHEET_SEGUIMIENTOS: "SEGUIMIENTOS",
  SHEET_PACIENTES:    "CONSOLIDADO_DE_PACIENTES",

  // ── Hojas de catálogos ───────────────────────────────────────
  SHEET_CAT_TRAT:     "CAT_TRATAMIENTOS",
  SHEET_CAT_ANUNCIOS: "CAT_ANUNCIOS",
  SHEET_TABLA_COM:    "TABLA DE COMISIONES",

  // FIX v2.0: Nombre real en GSheets (estaba truncado con Ñ)
  SHEET_INVERSION: "CONSOLIDADO DE INVERSION DE CAMPAÑAS",

  // ── Hojas de logs y soporte ──────────────────────────────────
  LOG_NOTIF:          "LOG_NOTIFICACIONES",
  LOG_MSG:            "LOG_MENSAJES",
  LOG_PERSONAL:       "LOG_PERSONAL",
  LOG_AUDITORIA:      "LOG_AUDITORIA",
  LOG_COMPROBANTES:   "LOG_COMPROBANTES",

  // ── Hojas de facturación ─────────────────────────────────────
  SHEET_COMPROBANTES: "CONSOLIDADO DE COMPROBANTES",
  SHEET_EMISORES:     "EMISORES",
  SHEET_HORARIOS:     "HORARIOS_DOCTORAS",
  SHEET_SATISFACCION: "SATISFACCION",

  // ── Configuración ────────────────────────────────────────────
  SHEET_CONFIG:       "CONFIGURACION",  // ya existía en el código
  SHEET_CONFIG_SYS:   "CONFIGURACION",  // alias explícito v2.0

  // NEW v2.0: Control de turnos de asesores
  SHEET_TURNOS:       "LOG_TURNOS",

  // Zona horaria (Lima/Perú)
  TZ: "America/Lima"
};
// A02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · ÍNDICES DE COLUMNAS POR HOJA (base 0)
// Usar estos índices en getValues() — nunca números literales
// ══════════════════════════════════════════════════════════════
// A03_START

/**
 * Columnas de RRHH (base 0)
 * Última col original: P (índice 15) = AGENDA
 * NEW v2.0: Q (16) = PERMISOS · R (17) = FOTO_URL
 */
var RRHH_COL = {
  CODIGO:   0,  // A - ID único del asesor
  NOMBRE:   1,  // B
  APELLIDO: 2,  // C
  PUESTO:   3,  // D - ASESOR / ADMIN / DOCTORA / ENFERMERIA
  SUELDO:   4,  // E
  FECHA_ING:5,  // F
  FECHA_SAL:6,  // G
  ESTADO:   7,  // H - ACTIVO / INACTIVO
  META:     8,  // I - Meta de comisión mensual
  BONUS:    9,  // J
  SEDE:     10, // K
  LABEL:    11, // L - Nombre para mostrar
  USUARIO:  12, // M - Login username
  PASS:     13, // N - Password
  NUMERO:   14, // O - Teléfono del asesor
  AGENDA:   15, // P - SI/NO tiene agenda asignada
  // ── NEW v2.0 ──────────────────────────────────────────
  PERMISOS: 16, // Q - JSON de módulos habilitados
                //     Ej: {"callcenter":true,"ventas":true,"marketing":false}
  FOTO_URL: 17  // R - URL de imagen de perfil del asesor/doctora
};

/**
 * Columnas de CONSOLIDADO DE LLAMADAS (base 0)
 * Última col original: T (índice 19) = TS_LOG
 * NEW v2.0: U (20) = SUB_ESTADO para sub-tipificación de SIN CONTACTO
 */
var LLAM_COL = {
  FECHA:        0,  // A
  NUMERO:       1,  // B
  TRATAMIENTO:  2,  // C
  ESTADO:       3,  // D - SIN CONTACTO, CITA CONFIRMADA, etc.
  OBS:          4,  // E - Observación
  HORA:         5,  // F
  ASESOR:       6,  // G - Nombre del asesor
  _F7:          7,  // H - (reservado)
  NUM_LIMPIO:   8,  // I - Número normalizado 9 dígitos
  ID_ASESOR:    9,  // J
  ANUNCIO:      10, // K
  ORIGEN:       11, // L
  INTENTO:      12, // M
  ULT_TS:       13, // N - Timestamp último intento
  PROX_REIN:    14, // O - Timestamp próximo reintento
  RESULTADO:    15, // P - CERRADO / REINTENTAR
  SESSION_ID:   16, // Q
  DEVICE:       17, // R
  WHATSAPP:     18, // S - URL de WhatsApp
  TS_LOG:       19, // T
  // ── NEW v2.0 ──────────────────────────────────────────
  SUB_ESTADO:   20  // U - Sub-tipificación cuando ESTADO = "SIN CONTACTO"
                    //     Valores: "NO CONTESTA" | "SIN SERVICIO" | "NUMERO NO EXISTE"
};

/**
 * Columnas de CONSOLIDADO DE LEADS (base 0)
 * Sin cambios en v2.0
 */
var LEAD_COL = {
  FECHA:     0, // A
  CELULAR:   1, // B
  TRAT:      2, // C
  ANUNCIO:   3, // D
  PREGUNTAS: 4, // E
  HORA:      5, // F
  _F6:       6, // G (reservado)
  NUM_LIMPIO:7  // H - Número limpio
};

/**
 * Columnas de CONSOLIDADO DE VENTAS (base 0)
 * Sin cambios en v2.0
 */
var VENT_COL = {
  FECHA:       0,  // A
  NOMBRES:     1,  // B
  APELLIDOS:   2,  // C
  DNI:         3,  // D
  CELULAR:     4,  // E
  TRATAMIENTO: 5,  // F
  DESCRIPCION: 6,  // G
  PAGO:        7,  // H
  MONTO:       8,  // I
  ESTADO_PAGO: 9,  // J - ADELANTO / PAGO COMPLETO / PENDIENTE
  ASESOR:      10, // K
  ATENDIO:     11, // L
  SEDE:        12, // M
  TIPO:        13, // N - SERVICIO / PRODUCTO
  _VACIO:      14, // O (reservado)
  NUM_LIMPIO:  15, // P
  VENTA_ID:    16, // Q
  NRO_DOC:     17, // R - Número de comprobante
  ESTADO_DOC:  18  // S - Estado del comprobante
};

/**
 * Columnas de AGENDA_CITAS (base 0)
 * Sin cambios en v2.0
 */
var AG_COL = {
  ID:             0,  // A
  FECHA:          1,  // B
  TRATAMIENTO:    2,  // C
  TIPO_CITA:      3,  // D
  SEDE:           4,  // E
  NUMERO:         5,  // F
  NOMBRE:         6,  // G
  APELLIDO:       7,  // H
  DNI:            8,  // I
  CORREO:         9,  // J
  ASESOR:         10, // K
  ID_ASESOR:      11, // L
  ESTADO:         12, // M
  VENTA_ID:       13, // N
  OBS:            14, // O
  TS_CREADO:      15, // P
  TS_ACTUALIZADO: 16, // Q
  HORA_CITA:      17, // R
  ETIQUETA_CAMP:  18, // S
  DOCTORA:        19, // T
  TIPO_ATENCION:  20, // U
  GCAL_ID:        21  // V
};

/**
 * Columnas de SEGUIMIENTOS (base 0)
 * Sin cambios en v2.0
 */
var SEG_COL = {
  ID:            0, // A
  FECHA_PROG:    1, // B
  HORA_PROG:     2, // C
  NUMERO:        3, // D
  TRATAMIENTO:   4, // E
  ASESOR:        5, // F
  ID_ASESOR:     6, // G
  OBS:           7, // H
  ESTADO:        8, // I - PENDIENTE / CERRADO
  TS_CREADO:     9, // J
  TS_ACTUALIZADO:10 // K
};

/**
 * Columnas de HORARIOS_DOCTORAS (base 0)
 * Sin cambios en v2.0
 */
var HOR_COL = {
  ID:            0, // A
  DOCTORA_LABEL: 1, // B
  DIA_SEM:       2, // C
  HORA_INI:      3, // D
  HORA_FIN:      4, // E
  SEDE:          5, // F
  CAP_DOC:       6, // G
  CAP_ENF:       7, // H
  ACTIVO:        8, // I
  GCAL_ID:       9, // J
  TS:            10 // K
};

/**
 * Columnas de CONSOLIDADO_DE_PACIENTES (base 0)
 * Última col original: T (índice 19) = NOTAS
 * NEW v2.0: U (20) = FOTO_URL
 */
var PAC_COL = {
  ID:              0,  // A
  NOMBRES:         1,  // B
  APELLIDOS:       2,  // C
  TELEFONO:        3,  // D
  EMAIL:           4,  // E
  DOCUMENTO:       5,  // F
  SEXO:            6,  // G
  FECHA_NAC:       7,  // H
  DIRECCION:       8,  // I
  OCUPACION:       9,  // J
  SEDE:            10, // K
  FUENTE:          11, // L
  FECHA_REG:       12, // M
  TOTAL_COMPRAS:   13, // N
  TOTAL_FACTURADO: 14, // O
  ULTIMA_VISITA:   15, // P
  TOTAL_LLAMADAS:  16, // Q
  TOTAL_CITAS:     17, // R
  ESTADO:          18, // S
  NOTAS:           19, // T
  // ── NEW v2.0 ──────────────────────────────────────────
  FOTO_URL:        20  // U - URL de foto del paciente (opcional)
};

/**
 * NEW v2.0 · Columnas de LOG_TURNOS (base 0)
 * Hoja nueva que registra entrada/salida y estados de cada asesor
 */
var TURN_COL = {
  FECHA:           0, // A - Fecha del turno (yyyy-MM-dd)
  ID_ASESOR:       1, // B - Código del asesor (ZIV-XXX)
  ASESOR:          2, // C - Nombre/label del asesor
  HORA_ENTRADA:    3, // D - Hora de inicio de turno (HH:mm:ss)
  HORA_SALIDA:     4, // E - Hora de cierre de turno (HH:mm:ss)
  MIN_BREAK:       5, // F - Minutos acumulados en BREAK
  MIN_BANIO:       6, // G - Minutos acumulados en BAÑO
  MIN_ATENCION:    7, // H - Minutos acumulados en ATENCIÓN
  MIN_LIMPIEZA:    8, // I - Minutos acumulados en LIMPIEZA
  MIN_CAPACITACION:9, // J - Minutos acumulados en CAPACITACIÓN
  MIN_OTROS:       10,// K - Minutos en otros estados no-activos
  MIN_TRABAJO:     11,// L - Minutos totales de trabajo efectivo
  TARDANZA_MIN:    12,// M - Minutos de tardanza (0 si llegó a tiempo)
  HORAS_EXTRA_MIN: 13,// N - Minutos de horas extra
  ESTADO_TURNO:    14,// O - ABIERTO / CERRADO
  TS_CREADO:       15,// P - Timestamp de apertura de turno
  TS_ACTUALIZADO:  16 // Q - Timestamp de última actualización
};

/**
 * NEW v2.0 · Columnas de CONFIGURACION (base 0)
 * Hoja de configuración del sistema editable desde el panel
 */
var CONF_COL = {
  CLAVE:       0, // A - Identificador único de la configuración
  VALOR:       1, // B - Valor de la configuración
  DESCRIPCION: 2, // C - Descripción legible
  UPDATED_AT:  3, // D - Timestamp de última actualización
  UPDATED_BY:  4  // E - ID del asesor que actualizó
};
// A03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · ESTADOS Y ROLES VÁLIDOS
// ══════════════════════════════════════════════════════════════
// A04_START

/** Roles del sistema */
var ROLES = {
  ADMIN:     "ADMIN",
  ASESOR:    "ASESOR",
  DOCTORA:   "DOCTORA",
  MARKETING: "MARKETING"
};

/**
 * Estados válidos de una llamada
 * v2.0: "NO CONTESTA" → "SIN CONTACTO" (renombrado)
 * El valor anterior se mantiene en ESTADOS_LLAMADA_LEGACY para
 * compatibilidad con datos históricos en el Sheet
 */
var ESTADOS_LLAMADA = [
  "CITA CONFIRMADA",
  "SIN CONTACTO",       // v2.0: era "NO CONTESTA"
  "SEGUIMIENTO",
  "NO LE INTERESA",
  "PROVINCIA",
  "SACAR DE LA BASE"
];

/** v2.0: Sub-estados de SIN CONTACTO para segunda tipificación */
var SUB_ESTADOS_SIN_CONTACTO = [
  "NO CONTESTA",        // Llamó y no contestó
  "SIN SERVICIO",       // Número fuera de servicio / apagado
  "NUMERO NO EXISTE"    // Número inválido / no existe
];

/**
 * Compatibilidad: estados del Sheet histórico que mapean a SIN CONTACTO
 * Usado en GS_18_MigrationCompat para normalizar datos viejos
 */
var ESTADOS_SIN_CONTACTO_LEGACY = new Set([
  "NO CONTESTA",
  "SIN CONTACTO"
]);

/** Estados que descartan un lead definitivamente */
var ESTADOS_DESCARTADOS = new Set([
  "SACAR DE LA BASE",
  "CITA CONFIRMADA",
  "NO LE INTERESA",
  "PROVINCIA",
  "PROVINCIAS",
  "NO INTERESA"
]);

/** Estados válidos de una cita */
var ESTADOS_CITA = [
  "PENDIENTE",
  "CITA CONFIRMADA",
  "ASISTIO",
  "EFECTIVA",
  "NO ASISTIO",
  "CANCELADA",
  "REAGENDADA",
  "SEGUIMIENTO"
];

/** Estados operativos del asesor */
var ESTADOS_OPERATIVO = [
  "ACTIVO",
  "EN LLAMADA",
  "BREAK",
  "BAÑO",
  "ATENCIÓN",
  "LIMPIEZA",
  "CAPACITACIÓN",
  "APERTURA DE TURNO",
  "CIERRE DE TURNO",
  "LOGEADO"
];

/** Estados que activan el overlay bloqueante en el asesor */
var ESTADOS_BLOQUEANTES = new Set([
  "BREAK",
  "BAÑO",
  "ATENCIÓN",
  "LIMPIEZA",
  "CAPACITACIÓN"
]);

/** Estados que se consideran "en pausa" para el semáforo */
var ESTADOS_PAUSA = new Set([
  "BREAK",
  "BAÑO",
  "ATENCIÓN",
  "LIMPIEZA",
  "CAPACITACIÓN"
]);

/** Meses en español para marketing */
var MESES_ES = [
  "", "ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO",
  "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"
];

/** Días de la semana */
var DIAS_SEMANA = [
  "DOMINGO", "LUNES", "MARTES", "MIERCOLES",
  "JUEVES", "VIERNES", "SABADO"
];
// A04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · CONFIGURACIÓN DEL SISTEMA
// ══════════════════════════════════════════════════════════════
// A05_START

/** Configuración de sesión */
var SESSION_CONFIG = {
  TTL:       28800,  // 8 horas en segundos
  PREFIX:    "AOS_S_",
  TOKEN_LEN: 32
};

/** Configuración de agenda */
var AGENDA_CONFIG = {
  SLOT_DURACION_MIN:  30,
  CAP_DOC_DEFAULT:    5,
  CAP_ENF_DEFAULT:    5,
  HORA_INI_DEFAULT:   "09:00",
  HORA_FIN_DEFAULT:   "21:00"
};

/** Configuración del call panel */
var CALL_CONFIG = {
  LOCK_ENTRE_ASESORES_MS: 30 * 60 * 1000,  // 30 min anti-duplicación
  MIN_ESPERA_NC_MS:        3 * 60 * 60 * 1000,  // 3h entre reintentos NC
  MAX_INTENTOS:            50,
  DIAS_TIER2:              7  // leads vírgenes hasta 7 días = Tier 2
};

/** Configuración de polling y cache */
var PERF_CONFIG = {
  POLL_NOTIF_MS:     30000,  // 30 segundos
  POLL_ADMIN_MS:     60000,  // 60 segundos
  CACHE_DASHBOARD_S: 60,     // 1 minuto
  CACHE_MARKETING_S: 300,    // 5 minutos
  CACHE_CATALOGOS_S: 600,    // 10 minutos
  CACHE_ASESORES_S:  120     // 2 minutos
};

/** Google Calendar */
var GCAL_CONFIG = {
  ACTIVO:    true,
  TURNOS_ID: "3784316650e1124f3eb82be4f123001347a18fb1808e4292e0d0503925d4f967@group.calendar.google.com"
};

/** Sedes válidas */
var SEDES = ["SAN ISIDRO", "PUEBLO LIBRE"];

/** Tratamientos que van a ENFERMERÍA (no a DOCTORA) */
var TRAT_ENFERMERIA = [
  "ENZIMAS", "ENZIMAS FACIALES", "VITAMINAS", "DETOX",
  "MESOTERAPIA CAPILAR", "MESOTERAPIA FACIAL",
  "RADIOFRECUENCIA CAPILAR", "RADIOFRECUENCIA FACIAL",
  "EXOSOMAS CAPILARES", "EXOSOMAS FACIAL",
  "HIDROFACIAL", "CAPILAR", "PEPTONAS", "PQ AGE",
  "FULL VITS", "NUCLEOKIN", "LIFTING B", "LIFTING"
];

/**
 * NEW v2.0 · Horarios de trabajo oficiales
 * Usados para calcular tardanzas y horas extra en LOG_TURNOS
 * Puede ser sobreescrito por la hoja CONFIGURACION si existe
 */
var HORARIOS_CONFIG = {
  // Formato: [hora_inicio_min_desde_medianoche, hora_fin_min_desde_medianoche]
  // 10:30 = 630 min | 20:30 = 1230 min | 09:30 = 570 min | 18:00 = 1080 min
  LUNES:     { inicio: "10:30", fin: "20:30", descanso: false },
  MARTES:    { inicio: "10:30", fin: "20:30", descanso: false },
  MIERCOLES: { inicio: "10:30", fin: "20:30", descanso: false },
  JUEVES:    { inicio: "10:30", fin: "20:30", descanso: false },
  VIERNES:   { inicio: "10:30", fin: "20:30", descanso: false },
  SABADO:    { inicio: "09:30", fin: "18:00", descanso: false },
  DOMINGO:   { inicio: null,    fin: null,    descanso: true  },
  // Tolerancia de tardanza en minutos antes de marcar como tarde
  TOLERANCIA_MIN: 5,
  // Máximo de break acumulado permitido por turno (en minutos)
  MAX_BREAK_MIN: 45
};

/**
 * NEW v2.0 · Permisos por defecto según rol
 * Usado al crear un usuario nuevo si no se especifican permisos
 */
var PERMISOS_DEFAULT = {
  ADMIN: JSON.stringify({
    home_admin:       true,
    operaciones:      true,
    agenda_global:    true,
    pacientes:        true,
    ventas_admin:     true,
    comisiones_admin: true,
    marketing:        true,
    llamadas_admin:   true,
    facturacion:      true,
    equipo:           true,
    configuracion:    true,
    chats:            true
  }),
  ASESOR: JSON.stringify({
    panel_principal:  true,
    call_center:      true,
    seguimientos:     true,
    agenda:           true,
    mis_citas:        true,
    pacientes:        true,
    mis_ventas:       true,
    comisiones:       true,
    mis_atenciones:   true,
    mi_perfil:        true
  }),
  DOCTORA: JSON.stringify({
    agenda:           true,
    mis_citas:        true,
    pacientes:        true,
    mi_perfil:        true
  }),
  MARKETING: JSON.stringify({
    marketing:        true,
    pacientes:        true,
    mi_perfil:        true
  })
};
// A05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · CONSTANTES DE NEGOCIO
// ══════════════════════════════════════════════════════════════
// A06_START

/** Tipos de atención */
var TIPO_ATENCION = {
  DOCTORA:    "DOCTORA",
  ENFERMERIA: "ENFERMERIA"
};

/** Tipos de venta */
var TIPO_VENTA = {
  SERVICIO: "SERVICIO",
  PRODUCTO: "PRODUCTO"
};

/** Estados de pago */
var ESTADO_PAGO = {
  PENDIENTE:     "PENDIENTE",
  ADELANTO:      "ADELANTO",
  PAGO_COMPLETO: "PAGO COMPLETO"
};

/** Tipos de comprobante */
var TIPO_COMPROBANTE = {
  BOLETA_E:     "BOLETA_E",
  FACTURA_E:    "FACTURA_E",
  RH:           "RH",
  BOLETA_F:     "BOLETA_FISICA",
  COORDINACION: "COORDINACION",
  LIBRE:        "LIBRE",
  PENDIENTE:    "PENDIENTE"
};

/** Semáforo de actividad del asesor */
var SEMAFORO = {
  VERDE:    "verde",    // llamó hace ≤ 3 min
  AMARILLO: "amarillo", // llamó hace 3-5 min
  ROJO:     "rojo",     // llamó hace > 5 min
  PAUSA:    "pausa",    // en estado de pausa/break
  GRIS:     "gris"      // sin llamadas hoy
};

/** Umbrales del semáforo en minutos */
var SEMAFORO_UMBRALES = {
  VERDE:    3,
  AMARILLO: 5
};

/** Tiers del call panel */
var CALL_TIERS = {
  TIER1: "TIER 1 · HOY",
  TIER2: "TIER 2 · SEMANA",
  TIER3: "TIER 3 · ROTACIÓN"
};
// A06_END

// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════

/**
 * TEST: Ejecutar desde el editor para verificar que
 * la configuración cargó correctamente
 */
function test_Config() {
  Logger.log("=== AscendaOS GS_01_Config v2.0 TEST ===");
  Logger.log("SHEET_ID: " + CFG.SHEET_ID);
  Logger.log("SHEET_INVERSION (FIX): " + CFG.SHEET_INVERSION);
  Logger.log("SHEET_TURNOS (NEW): " + CFG.SHEET_TURNOS);
  Logger.log("RRHH cols totales: " + Object.keys(RRHH_COL).length + " (era 16, ahora 18)");
  Logger.log("  Nueva col PERMISOS (Q=" + RRHH_COL.PERMISOS + ")");
  Logger.log("  Nueva col FOTO_URL  (R=" + RRHH_COL.FOTO_URL + ")");
  Logger.log("LLAM cols totales: " + Object.keys(LLAM_COL).length + " (era 20, ahora 21)");
  Logger.log("  Nueva col SUB_ESTADO (U=" + LLAM_COL.SUB_ESTADO + ")");
  Logger.log("PAC cols totales: " + Object.keys(PAC_COL).length + " (era 20, ahora 21)");
  Logger.log("  Nueva col FOTO_URL (U=" + PAC_COL.FOTO_URL + ")");
  Logger.log("TURN_COL: " + Object.keys(TURN_COL).length + " columnas");
  Logger.log("CONF_COL: " + Object.keys(CONF_COL).length + " columnas");
  Logger.log("SUB_ESTADOS_SIN_CONTACTO: " + JSON.stringify(SUB_ESTADOS_SIN_CONTACTO));
  Logger.log("ESTADOS_BLOQUEANTES: " + JSON.stringify(Array.from(ESTADOS_BLOQUEANTES)));
  Logger.log("HORARIOS_CONFIG L-V: " + HORARIOS_CONFIG.LUNES.inicio + " → " + HORARIOS_CONFIG.LUNES.fin);
  Logger.log("HORARIOS_CONFIG Sáb: " + HORARIOS_CONFIG.SABADO.inicio + " → " + HORARIOS_CONFIG.SABADO.fin);
  Logger.log("=== OK ===");
}