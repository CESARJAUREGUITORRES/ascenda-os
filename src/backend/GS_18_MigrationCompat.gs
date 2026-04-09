/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_18_MigrationCompat.gs                   ║
 * ║  Módulo: Compatibilidad y Migración desde CRM antiguo       ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * PROPÓSITO:
 *   Este módulo actúa como puente entre el sistema CRM antiguo
 *   (Zi Vital CRM) y AscendaOS v1. Mantiene compatibilidad con
 *   funciones del sistema anterior para no romper flujos activos
 *   durante la transición.
 *
 * CONTENIDO:
 *   MOD-01 · Aliases de funciones antiguas → nuevas
 *   MOD-02 · Normalización de datos heredados
 *   MOD-03 · Diagnóstico y salud del sistema
 *   MOD-04 · Herramientas de migración de datos
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · ALIASES DE COMPATIBILIDAD
// Mapea funciones del sistema viejo a las nuevas del AscendaOS
// ══════════════════════════════════════════════════════════════
// M01_START

/**
 * Compatibilidad: el CRM viejo podría llamar estas funciones
 * Las redirigimos a las equivalentes nuevas
 */

// -- LLAMADAS --
function getCallList(token)             { return typeof api_getCallQueueT === 'function' ? api_getCallQueueT(token) : {ok:false,error:'No disponible'}; }
function saveCall(token, payload)       { return typeof api_saveCallT === 'function' ? api_saveCallT(token, payload) : {ok:false}; }
function getLeadInfo(token, num)        { return typeof api_getLeadInfoT === 'function' ? api_getLeadInfoT(token, num) : {ok:false}; }

// -- AGENDA --
function getAgenda(token, fecha, sede)  { return typeof api_getAgendaDiaT === 'function' ? api_getAgendaDiaT(token, fecha, sede) : {ok:false}; }
function createCita(token, payload)     { return typeof api_crearCitaT === 'function' ? api_crearCitaT(token, payload) : {ok:false}; }

// -- VENTAS --
function getVentas(token, mes, anio)    { return typeof api_getMyVentasT === 'function' ? api_getMyVentasT(token, mes, anio) : {ok:false}; }
function saveVenta(token, payload)      { return typeof api_saveVentaT === 'function' ? api_saveVentaT(token, payload) : {ok:false}; }

// -- USUARIOS --
function loginUser(user, pass)          { return typeof api_login === 'function' ? api_login(user, pass) : {ok:false}; }
function getEstado(token)               { return typeof api_getEstadoSesionT === 'function' ? api_getEstadoSesionT(token) : {ok:false}; }

// -- NOTIFICACIONES --
function getNotifs(token)               { return typeof api_getNotifCenterT === 'function' ? api_getNotifCenterT(token) : {ok:false}; }
function markRead(token, id)            { return typeof api_markNotifReadT === 'function' ? api_markNotifReadT(token, id) : {ok:false}; }
// M01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · NORMALIZACIÓN DE DATOS HEREDADOS
// ══════════════════════════════════════════════════════════════
// M02_START

/**
 * normalizeLeadsNumeros — Rellena la columna NUM_LIMPIO en LEADS
 * para filas que no la tienen. Ejecutar una sola vez.
 */
function normalizeLeadsNumeros() {
  var sh = _sh(CFG.SHEET_LEADS);
  var lr = sh.getLastRow();
  if (lr < 2) { Logger.log('Sin leads'); return; }

  var cols = Math.min(sh.getLastColumn(), 9);
  var rows = sh.getRange(2, 1, lr - 1, cols).getValues();
  var updates = 0;

  rows.forEach(function(r, i) {
    var numLimpio = _normNum(r[LEAD_COL.NUM_LIMPIO] || '');
    if (!numLimpio) {
      var cel = _normNum(r[LEAD_COL.CELULAR] || '');
      if (cel) {
        sh.getRange(i + 2, LEAD_COL.NUM_LIMPIO + 1).setValue(cel);
        updates++;
      }
    }
  });

  Logger.log('normalizeLeadsNumeros: ' + updates + ' filas actualizadas de ' + (lr-1));
}

/**
 * normalizeVentasNumeros — Rellena NUM_LIMPIO en VENTAS
 */
function normalizeVentasNumeros() {
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) { Logger.log('Sin ventas'); return; }

  var rows = sh.getRange(2, 1, lr - 1, 17).getValues();
  var updates = 0;

  rows.forEach(function(r, i) {
    var numLimpio = _normNum(r[VENT_COL.NUM_LIMPIO] || '');
    if (!numLimpio) {
      var cel = _normNum(r[VENT_COL.CELULAR] || '');
      if (cel) {
        sh.getRange(i + 2, VENT_COL.NUM_LIMPIO + 1).setValue(cel);
        updates++;
      }
    }
  });

  Logger.log('normalizeVentasNumeros: ' + updates + ' filas actualizadas');
}

/**
 * normalizeLlamadasNumeros — Rellena NUM_LIMPIO en LLAMADAS
 */
function normalizeLlamadasNumeros() {
  var sh = _sh(CFG.SHEET_LLAMADAS);
  var lr = sh.getLastRow();
  if (lr < 2) { Logger.log('Sin llamadas'); return; }

  var rows = sh.getRange(2, 1, lr - 1, 10).getValues();
  var updates = 0;

  rows.forEach(function(r, i) {
    var numLimpio = _normNum(r[LLAM_COL.NUM_LIMPIO] || '');
    if (!numLimpio) {
      var num = _normNum(r[LLAM_COL.NUMERO] || '');
      if (num) {
        sh.getRange(i + 2, LLAM_COL.NUM_LIMPIO + 1).setValue(num);
        updates++;
      }
    }
  });

  Logger.log('normalizeLlamadasNumeros: ' + updates + ' filas actualizadas');
}

/**
 * runFullNormalization — Ejecuta toda la normalización de datos
 * Llamar una sola vez durante la migración inicial
 */
function runFullNormalization() {
  Logger.log('=== INICIANDO NORMALIZACIÓN COMPLETA ===');
  normalizeLeadsNumeros();
  normalizeVentasNumeros();
  normalizeLlamadasNumeros();
  if (typeof backfillTipo === 'function') backfillTipo(); // de GS_04
  Logger.log('=== NORMALIZACIÓN COMPLETA FINALIZADA ===');
}
// M02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · DIAGNÓSTICO Y SALUD DEL SISTEMA
// ══════════════════════════════════════════════════════════════
// M03_START

/**
 * api_healthCheck — Verifica que todo el sistema funciona
 * Llamado desde el panel de admin para diagnóstico
 */
function api_healthCheck() {
  cc_requireAdmin();
  var now     = new Date();
  var results = {};
  var errores = [];

  // Verificar hojas críticas
  var hojasReq = [
    CFG.SHEET_RRHH, CFG.SHEET_LLAMADAS, CFG.SHEET_LEADS,
    CFG.SHEET_VENTAS, CFG.SHEET_AGENDA
  ];
  hojasReq.forEach(function(nm) {
    try {
      var sh = _sh(nm);
      results[nm] = { ok: true, filas: sh.getLastRow() - 1 };
    } catch(e) {
      results[nm] = { ok: false, error: e.message };
      errores.push(nm);
    }
  });

  // Hojas opcionales
  var hojasOpc = [
    CFG.SHEET_COMPROBANTES, CFG.SHEET_EMISORES,
    CFG.SHEET_INVERSION, CFG.LOG_AUDITORIA
  ];
  hojasOpc.forEach(function(nm) {
    try {
      var sh = _sh(nm);
      results[nm] = { ok: true, filas: sh.getLastRow() - 1, opcional: true };
    } catch(e) {
      results[nm] = { ok: false, opcional: true, error: e.message };
    }
  });

  // Verificar GCal
  var gcalOk = false;
  try {
    var cal = CalendarApp.getCalendarById(GCAL_CONFIG.TURNOS_ID);
    gcalOk  = !!cal;
  } catch(e) {}
  results['GCAL'] = { ok: gcalOk };

  // Verificar cache
  var cacheOk = false;
  try {
    var c = CacheService.getScriptCache();
    c.put('AOS_HEALTH', '1', 5);
    cacheOk = c.get('AOS_HEALTH') === '1';
    c.remove('AOS_HEALTH');
  } catch(e) {}
  results['CACHE'] = { ok: cacheOk };

  // Contar sesiones activas
  var nSesiones = 0;
  try {
    var shRrhh = _sh(CFG.SHEET_RRHH);
    var lr = shRrhh.getLastRow();
    if (lr >= 2) {
      nSesiones = shRrhh.getRange(2, RRHH_COL.ESTADO + 1, lr - 1, 1).getValues()
        .filter(function(r) { return _up(_norm(r[0])) === 'ACTIVO'; }).length;
    }
  } catch(e) {}

  return {
    ok:             errores.length === 0,
    ts:             _datetime(now),
    errores:        errores,
    nHojasCriticas: hojasReq.length - errores.length + '/' + hojasReq.length,
    gcalActivo:     gcalOk,
    cacheActivo:    cacheOk,
    usuariosActivos:nSesiones,
    detalle:        results
  };
}

/** Wrapper token */
function api_healthCheckT(token) {
  _setToken(token); return api_healthCheck();
}

/**
 * api_getSystemStats — Estadísticas generales del sistema
 */
function api_getSystemStats() {
  cc_requireAdmin();
  var now  = new Date();
  var mes  = now.getMonth() + 1;
  var anio = now.getFullYear();
  var desde = new Date(anio, mes - 1, 1);
  var hasta = new Date(anio, mes, 0, 23, 59, 59);

  var stats = { ok: true };

  try {
    var shLd = _sh(CFG.SHEET_LEADS);
    stats.totalLeads = Math.max(0, shLd.getLastRow() - 1);
  } catch(e) { stats.totalLeads = 0; }

  try {
    var shL = _sh(CFG.SHEET_LLAMADAS);
    stats.totalLlamadas = Math.max(0, shL.getLastRow() - 1);
  } catch(e) { stats.totalLlamadas = 0; }

  try {
    var shV = _sh(CFG.SHEET_VENTAS);
    stats.totalVentas = Math.max(0, shV.getLastRow() - 1);
  } catch(e) { stats.totalVentas = 0; }

  try {
    var shAg = _shAgenda();
    stats.totalCitas = Math.max(0, shAg.getLastRow() - 1);
  } catch(e) { stats.totalCitas = 0; }

  try {
    var shRr = _sh(CFG.SHEET_RRHH);
    stats.totalUsuarios = Math.max(0, shRr.getLastRow() - 1);
    stats.usuariosActivos = shRr.getLastRow() >= 2
      ? shRr.getRange(2, RRHH_COL.ESTADO + 1, shRr.getLastRow()-1, 1)
             .getValues().filter(function(r){ return _up(r[0])==='ACTIVO'; }).length
      : 0;
  } catch(e) { stats.totalUsuarios = 0; stats.usuariosActivos = 0; }

  // Datos del mes
  try {
    var leadsM = da_leadsData(desde, hasta);
    var ventasM = da_ventasData(desde, hasta);
    stats.leadesMes  = leadsM.length;
    stats.ventasMes  = ventasM.length;
    stats.factMes    = ventasM.reduce(function(s,v){ return s+v.monto; }, 0);
  } catch(e) { stats.leadesMes=0; stats.ventasMes=0; stats.factMes=0; }

  stats.ts = _datetime(now);
  return stats;
}

/** Wrapper token */
function api_getSystemStatsT(token) {
  _setToken(token); return api_getSystemStats();
}
// M03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · HERRAMIENTAS DE MIGRACIÓN
// ══════════════════════════════════════════════════════════════
// M04_START

/**
 * migrarPacientesDesdeVentas — Crea entradas en CONSOLIDADO_DE_PACIENTES
 * para todos los clientes que aparecen en VENTAS y no están en Pacientes
 * Ejecutar una sola vez en la migración inicial
 */
function migrarPacientesDesdeVentas() {
  Logger.log('=== MIGRANDO PACIENTES DESDE VENTAS ===');
  var shV = _sh(CFG.SHEET_VENTAS);
  var shP = _shPacientes();
  var lrV = shV.getLastRow();
  if (lrV < 2) { Logger.log('Sin ventas'); return; }

  // Leer pacientes existentes
  var lrP  = shP.getLastRow();
  var existMap = {};
  if (lrP >= 2) {
    shP.getRange(2, PAC_COL.TELEFONO + 1, lrP - 1, 1).getValues().forEach(function(r) {
      var n = _normNum(r[0]);
      if (n) existMap[n] = true;
    });
  }

  var ventas = shV.getRange(2, 1, lrV - 1, 17).getValues();
  var creados = 0;
  var now     = new Date();

  ventas.forEach(function(r) {
    var num = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
    if (!num || existMap[num]) return;

    var idPac = 'P-' + String(Date.now()).slice(-6) + '-' + creados;
    shP.appendRow([
      idPac,
      _norm(r[VENT_COL.NOMBRES]),
      _norm(r[VENT_COL.APELLIDOS]),
      "'" + num,
      '',  // email
      _norm(r[VENT_COL.DNI]),
      '', '', '', '', // sexo, fnac, dir, ocup
      _up(_norm(r[VENT_COL.SEDE])),
      'VENTAS',       // fuente
      _date(now),     // fecha_reg
      1, 0, '', 0, 0, // stats
      'ACTIVO', ''    // estado, notas
    ]);

    existMap[num] = true;
    creados++;
  });

  Logger.log('migrarPacientesDesdeVentas: ' + creados + ' pacientes creados');
}

/**
 * verificarIntegridadNumerosLimpios — Diagnóstico de datos
 * Cuenta cuántas filas tienen NUM_LIMPIO vacío en cada hoja
 */
function verificarIntegridadNumerosLimpios() {
  Logger.log('=== VERIFICACIÓN INTEGRIDAD NUM_LIMPIO ===');

  var check = function(shName, colIdx, label) {
    try {
      var sh = _sh(shName);
      var lr = sh.getLastRow();
      if (lr < 2) { Logger.log(label + ': 0 filas'); return; }
      var vals  = sh.getRange(2, colIdx + 1, lr - 1, 1).getValues();
      var vacios = vals.filter(function(r) { return !_normNum(r[0]); }).length;
      Logger.log(label + ': ' + (lr-1) + ' filas, ' + vacios + ' sin NUM_LIMPIO (' + Math.round(vacios/(lr-1)*100) + '%)');
    } catch(e) { Logger.log(label + ': ERROR - ' + e.message); }
  };

  check(CFG.SHEET_LEADS,    LEAD_COL.NUM_LIMPIO, 'LEADS');
  check(CFG.SHEET_LLAMADAS, LLAM_COL.NUM_LIMPIO, 'LLAMADAS');
  check(CFG.SHEET_VENTAS,   VENT_COL.NUM_LIMPIO, 'VENTAS');
  Logger.log('=== FIN VERIFICACIÓN ===');
}
// M04_END

function test_MigrationCompat() {
  Logger.log('=== GS_18_MigrationCompat TEST ===');
  Logger.log('Aliases de compatibilidad: OK');
  Logger.log('Para diagnóstico ejecutar: api_healthCheck() o verificarIntegridadNumerosLimpios()');
  Logger.log('Para normalizar datos: runFullNormalization()');
  Logger.log('=== OK ===');
}