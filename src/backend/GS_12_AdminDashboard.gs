/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_12_AdminDashboard.gs                    ║
 * ║  Módulo: Home Admin — KPIs ejecutivos y monitoreo           ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · KPIs ejecutivos del día y del mes
 *   MOD-02 · Monitoreo del equipo en tiempo real (semáforo)
 *   MOD-03 · Ticker de marketing (leads, llamados, citas, ventas)
 *   MOD-04 · Alertas del sistema
 *   MOD-05 · Ranking de comisiones del equipo
 *   MOD-06 · Ventas del día
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · KPIs EJECUTIVOS
// ══════════════════════════════════════════════════════════════
// L01_START

/**
 * api_getAdminHomeKpis — Datos completos para el home del admin
 * Llamado único que retorna todo lo necesario para el dashboard
 */
function api_getAdminHomeKpis() {
  cc_requireAdmin();
  var now  = new Date();
  var hoy  = _date(now);
  var mes  = now.getMonth() + 1;
  var anio = now.getFullYear();

  // ── Leer todas las hojas en memoria (una sola vez cada una) ──
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lrL = shL.getLastRow();
  var llamData = lrL >= 2 ? shL.getRange(2, 1, lrL - 1, 20).getValues() : [];

  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  var ventData = lrV >= 2 ? shV.getRange(2, 1, lrV - 1, 19).getValues() : [];

  var shA = _shAgenda();
  var lrA = shA.getLastRow();
  var agData = lrA >= 2 ? shA.getRange(2, 1, lrA - 1, 22).getValues() : [];

  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  var leadData = lrLd >= 2 ? shLd.getRange(2, 1, lrLd - 1, 9).getValues() : [];

  // ── KPIs LLAMADAS HOY ──
  var llamHoy = 0; var citasHoy = 0;
  var byAsesorHoy = {};

  llamData.forEach(function(r) {
    var fd = _date(r[LLAM_COL.FECHA]);
    if (fd !== hoy) return;
    llamHoy++;
    if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') citasHoy++;
    var nom = _up(_norm(r[LLAM_COL.ASESOR])) || _norm(r[LLAM_COL.ID_ASESOR]);
    if (!byAsesorHoy[nom]) byAsesorHoy[nom] = { llamadas:0, citas:0 };
    byAsesorHoy[nom].llamadas++;
    if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') byAsesorHoy[nom].citas++;
  });

  // ── KPIs VENTAS HOY y MES ──
  var mesStr   = anio + '-' + String(mes).padStart(2, '0');
  var factHoy  = 0; var countHoy = 0;
  var factMes  = 0; var countMes = 0;
  var ventasHoy = [];

  ventData.forEach(function(r) {
    var fd    = _date(r[VENT_COL.FECHA]);
    var monto = Number(r[VENT_COL.MONTO]) || 0;
    if (fd.slice(0, 7) === mesStr) { factMes += monto; countMes++; }
    if (fd === hoy) {
      factHoy += monto; countHoy++;
      ventasHoy.push({
        fecha:    fd,
        nombres:  _norm(r[VENT_COL.NOMBRES]),
        apellidos:_norm(r[VENT_COL.APELLIDOS]),
        num:      _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]),
        trat:     _norm(r[VENT_COL.TRATAMIENTO]),
        monto:    monto,
        tipo:     _up(_norm(r[VENT_COL.TIPO])),
        asesor:   _up(_norm(r[VENT_COL.ASESOR])),
        sede:     _up(_norm(r[VENT_COL.SEDE]))
      });
    }
  });

  // ── KPIs CITAS HOY ──
  var citasAgHoy = 0; var asistieronHoy = 0;
  agData.forEach(function(r) {
    if (_date(r[AG_COL.FECHA]) !== hoy) return;
    if (_up(r[AG_COL.ESTADO]) === 'CANCELADA') return;
    citasAgHoy++;
    var edo = _up(r[AG_COL.ESTADO]);
    if (edo === 'ASISTIO' || edo === 'EFECTIVA') asistieronHoy++;
  });

  // ── LEADS MES ──
  var leadsMes = 0;
  leadData.forEach(function(r) {
    var fd = _date(r[LEAD_COL.FECHA] || r[0]);
    if (fd.slice(0, 7) === mesStr) leadsMes++;
  });

  // ── ALERTAS ROJAS ──
  var alertas = _calcAlertas(byAsesorHoy, now);

  // ── DELTA VENTAS vs ayer ──
  var ayerStr = _date(new Date(now.getTime() - 86400000));
  var factAyer = ventData
    .filter(function(r) { return _date(r[VENT_COL.FECHA]) === ayerStr; })
    .reduce(function(s, r) { return s + (Number(r[VENT_COL.MONTO])||0); }, 0);
  var deltaVentasHoy = factAyer > 0 ? (factHoy - factAyer) / factAyer : null;

  return {
    ok:   true,
    ts:   _time(now),
    kpis: {
      factHoy:     factHoy,
      countHoy:    countHoy,
      factMes:     factMes,
      countMes:    countMes,
      llamHoy:     llamHoy,
      citasHoy:    citasHoy,
      citasAgHoy:  citasAgHoy,
      asistieronHoy:asistieronHoy,
      leadsMes:    leadsMes,
      alertas:     alertas.length,
      deltaVentasHoy: deltaVentasHoy
    },
    ventasHoy:  ventasHoy,
    alertas:    alertas
  };
}

/**
 * Calcula alertas: asesores sin llamadas o inactivos por > 30 min
 */
function _calcAlertas(byAsesorHoy, now) {
  var alertas = [];
  var estadoMap = _getEstadosEquipo();

  _asesoresActivosCached().filter(function(a) {
    return a.role === ROLES.ASESOR;
  }).forEach(function(a) {
    var nom    = _up(a.label || a.nombre);
    var datos  = byAsesorHoy[nom] || { llamadas:0, citas:0 };
    var edo    = estadoMap[nom] || {};
    var mins   = edo.minutos;
    var estado = edo.estado || '';

    // Alerta si: activo pero sin llamadas en últimos 30 min
    if (estado === 'ACTIVO' && datos.llamadas === 0) {
      alertas.push({
        tipo:    'sin_llamadas',
        asesor:  nom,
        mensaje: nom + ' está activo sin llamadas',
        nivel:   'rojo'
      });
    }

    // Alerta si: con sesión pero inactivo > 30 min
    if (mins !== null && mins > 30 && estado !== 'PAUSA' && estado !== 'CIERRE') {
      alertas.push({
        tipo:    'inactivo',
        asesor:  nom,
        mensaje: nom + ' inactivo hace ' + mins + ' min',
        nivel:   'amarillo'
      });
    }
  });

  return alertas;
}

/** Wrapper token */
function api_getAdminHomeKpisT(token) {
  _setToken(token); return api_getAdminHomeKpis();
}
// L01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · MONITOREO DEL EQUIPO (SEMÁFORO)
// ══════════════════════════════════════════════════════════════
// L02_START

/**
 * api_getTeamSemaforo — Estado en tiempo real del equipo
 * Para el panel de monitoreo en el home admin
 */
function api_getTeamSemaforo() {
  cc_requireAdmin();
  var now  = new Date();
  var hoy  = _date(now);

  // Llamadas de hoy por asesor
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lr  = shL.getLastRow();
  var byAsesor = {};

  if (lr >= 2) {
    shL.getRange(2, 1, lr - 1, 20).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      var nom = _up(_norm(r[LLAM_COL.ASESOR]));
      if (!nom) return;
      if (!byAsesor[nom]) {
        byAsesor[nom] = {
          llamadas:0, citas:0,
          ultTs: null, ultNum: ''
        };
      }
      byAsesor[nom].llamadas++;
      if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') byAsesor[nom].citas++;
      var ts = r[LLAM_COL.ULT_TS] ? new Date(r[LLAM_COL.ULT_TS]) : null;
      if (ts && (!byAsesor[nom].ultTs || ts > byAsesor[nom].ultTs)) {
        byAsesor[nom].ultTs  = ts;
        byAsesor[nom].ultNum = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      }
    });
  }

  // Estados operativos
  var estadoMap = _getEstadosEquipo();

  // Construir filas del semáforo
  var asesores = _asesoresActivosCached().filter(function(a) {
    return a.role === ROLES.ASESOR;
  });

  var filas = asesores.map(function(a) {
    var nom    = _up(a.label || a.nombre);
    var datos  = byAsesor[nom] || { llamadas:0, citas:0, ultTs:null, ultNum:'' };
    var edo    = estadoMap[nom] || { estado:'', minutos:null };
    var mins   = datos.ultTs ? Math.floor((now - datos.ultTs) / 60000) : null;
    var sem    = _calcSemaforo(mins, edo.estado);

    return {
      idAsesor:  _norm(a.idAsesor),
      nombre:    nom,
      llamadas:  datos.llamadas,
      citas:     datos.citas,
      ultTs:     datos.ultTs ? _time(datos.ultTs) : '—',
      ultNum:    datos.ultNum,
      minsSin:   mins,
      estado:    edo.estado || (datos.llamadas > 0 ? 'ACTIVO' : '—'),
      semaforo:  sem,
      sede:      a.sede || ''
    };
  });

  var totLlam  = filas.reduce(function(s, f) { return s + f.llamadas; }, 0);
  var totCitas = filas.reduce(function(s, f) { return s + f.citas;    }, 0);
  var alertas  = filas.filter(function(f) { return f.semaforo === 'rojo'; }).length;

  return {
    ok:        true,
    filas:     filas,
    totLlam:   totLlam,
    totCitas:  totCitas,
    alertas:   alertas,
    ts:        _time(now)
  };
}

/** Wrapper token */
function api_getTeamSemaforoT(token) {
  _setToken(token); return api_getTeamSemaforo();
}
// L02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · TICKER DE MARKETING
// ══════════════════════════════════════════════════════════════
// L03_START

/**
 * api_getMarketingTicker — Datos del ticker del topbar admin
 * Leads/Llamados/Citas/Ventas del mes con ROAS y CAC estimados
 */
function api_getMarketingTicker() {
  cc_requireAdmin();
  var now  = new Date();
  var mes  = now.getMonth() + 1;
  var anio = now.getFullYear();
  var mesStr = anio + '-' + String(mes).padStart(2,'0');

  // Leads del mes
  var shLd  = _sh(CFG.SHEET_LEADS);
  var lrLd  = shLd.getLastRow();
  var leads = 0;
  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 3).getValues().forEach(function(r) {
      if (_date(r[LEAD_COL.FECHA] || r[0]).slice(0,7) === mesStr) leads++;
    });
  }

  // Llamados del mes
  var shL  = _sh(CFG.SHEET_LLAMADAS);
  var lrL  = shL.getLastRow();
  var llamados = 0; var citasLlam = 0;
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 12).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]).slice(0,7) !== mesStr) return;
      llamados++;
      if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') citasLlam++;
    });
  }

  // Citas del mes en agenda
  var shAg  = _shAgenda();
  var lrAg  = shAg.getLastRow();
  var citas = 0; var asistieron = 0;
  if (lrAg >= 2) {
    shAg.getRange(2, 1, lrAg - 1, 15).getValues().forEach(function(r) {
      if (_date(r[AG_COL.FECHA]).slice(0,7) !== mesStr) return;
      if (_up(r[AG_COL.ESTADO]) === 'CANCELADA') return;
      citas++;
      var edo = _up(r[AG_COL.ESTADO]);
      if (edo === 'ASISTIO' || edo === 'EFECTIVA') asistieron++;
    });
  }

  // Ventas del mes
  var shV  = _sh(CFG.SHEET_VENTAS);
  var lrV  = shV.getLastRow();
  var ventas = 0; var factMes = 0;
  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 12).getValues().forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]).slice(0,7) !== mesStr) return;
      ventas++; factMes += Number(r[VENT_COL.MONTO]) || 0;
    });
  }

  // ROAS y CAC estimados (inversión desde GS_01_Config o placeholder)
  var inversion = MKTG_CONFIG ? (MKTG_CONFIG.INV_MES || 0) : 0;
  var roas = inversion > 0 ? factMes / inversion : null;
  var cac  = ventas > 0 && inversion > 0 ? inversion / ventas : null;

  // Tasas
  var tLlamados   = leads    > 0 ? Math.round(llamados   / leads    * 100) : 0;
  var tCitas      = llamados > 0 ? Math.round(citasLlam  / llamados * 100) : 0;
  var tAsistencia = citas    > 0 ? Math.round(asistieron / citas    * 100) : 0;
  var tConversion = asistieron > 0 ? Math.round(ventas / asistieron * 100) : 0;

  return {
    ok:          true,
    leads:       leads,
    llamados:    llamados,
    citas:       citasLlam,
    asistieron:  asistieron,
    ventas:      ventas,
    factMes:     factMes,
    roas:        roas,
    cac:         cac,
    tasas: {
      llamados:   tLlamados,
      citas:      tCitas,
      asistencia: tAsistencia,
      conversion: tConversion
    }
  };
}

/** Wrapper token */
function api_getMarketingTickerT(token) {
  _setToken(token); return api_getMarketingTicker();
}
// L03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · OPERACIONES (PANEL ADMIN DETALLE)
// ══════════════════════════════════════════════════════════════
// L04_START

/**
 * api_getOperationsPanel — Panel completo de operaciones para el admin
 * Métricas detalladas + actividad por asesor del día
 */
function api_getOperationsPanel() {
  cc_requireAdmin();
  var now  = new Date();
  var hoy  = _date(now);

  // Semáforo del equipo
  var semaforo = api_getTeamSemaforo();

  // Últimas 20 llamadas del día
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lr  = shL.getLastRow();
  var ultLlamadas = [];
  if (lr >= 2) {
    var rows = shL.getRange(2, 1, lr - 1, 20).getValues();
    rows.forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      ultLlamadas.push({
        hora:   _time(r[LLAM_COL.HORA] || new Date()),
        asesor: _up(_norm(r[LLAM_COL.ASESOR])),
        num:    _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]),
        trat:   _up(_norm(r[LLAM_COL.TRATAMIENTO])),
        estado: _up(r[LLAM_COL.ESTADO])
      });
    });
    ultLlamadas.sort(function(a,b) { return a.hora < b.hora ? 1 : -1; });
    ultLlamadas = ultLlamadas.slice(0, 20);
  }

  // Citas de hoy en agenda
  var shA  = _shAgenda();
  var lrA  = shA.getLastRow();
  var citasHoy = [];
  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 22).getValues().forEach(function(r) {
      if (_date(r[AG_COL.FECHA]) !== hoy) return;
      citasHoy.push({
        hora:    _normHora(r[AG_COL.HORA_CITA]),
        nombre:  _norm(r[AG_COL.NOMBRE]) + ' ' + _norm(r[AG_COL.APELLIDO]),
        trat:    _norm(r[AG_COL.TRATAMIENTO]),
        estado:  _norm(r[AG_COL.ESTADO]),
        doctora: _norm(r[AG_COL.DOCTORA]),
        asesor:  _norm(r[AG_COL.ASESOR]),
        sede:    _norm(r[AG_COL.SEDE])
      });
    });
    citasHoy.sort(function(a,b) { return a.hora < b.hora ? -1 : 1; });
  }

  // Resumen tipificaciones del día
  var tipifMap = {};
  if (lr >= 2) {
    shL.getRange(2, 1, lr - 1, 15).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      var t = _up(r[LLAM_COL.ESTADO]) || 'SIN TIPIF';
      tipifMap[t] = (tipifMap[t] || 0) + 1;
    });
  }

  return {
    ok:          true,
    semaforo:    semaforo,
    ultLlamadas: ultLlamadas,
    citasHoy:    citasHoy,
    tipifMap:    tipifMap,
    ts:          _time(now)
  };
}

/** Wrapper token */
function api_getOperationsPanelT(token) {
  _setToken(token); return api_getOperationsPanel();
}
// L04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · RANKING DE COMISIONES (PANEL ADMIN)
// ══════════════════════════════════════════════════════════════
// L05_START

/**
 * api_getAdminRankingComisiones — Ranking del equipo para el home admin
 */
function api_getAdminRankingComisiones() {
  cc_requireAdmin();
  var now  = new Date();
  var mes  = now.getMonth() + 1;
  var anio = now.getFullYear();
  return api_getTeamRanking(anio, mes);
}

/** Wrapper token */
function api_getAdminRankingComisionesT(token) {
  _setToken(token); return api_getAdminRankingComisiones();
}
// L05_END

/**
 * TEST
 */
function test_AdminDashboard() {
  Logger.log('=== GS_12_AdminDashboard TEST ===');
  Logger.log('Funciones disponibles:');
  Logger.log('  api_getAdminHomeKpisT(token)');
  Logger.log('  api_getTeamSemaforoT(token)');
  Logger.log('  api_getMarketingTickerT(token)');
  Logger.log('  api_getOperationsPanelT(token)');
  Logger.log('  api_getAdminRankingComisionesT(token)');
  Logger.log('=== OK ===');
}
/**
 * ════════════════════════════════════════════════════════
 * GS_12_AdminDashboard.gs — PATCH v2.0 (Fase 2)
 * Agregar AL FINAL del archivo GS_12_AdminDashboard.gs existente
 * ════════════════════════════════════════════════════════
 *
 * INSTRUCCIÓN DE PEGADO:
 * BUSCAR con Ctrl+F en GS_12_AdminDashboard.gs:
 *   el último "}" o "// === FIN ===" o la última función
 * PEGAR: después del cierre del último bloque
 *
 * CONTIENE:
 *   api_getPagosAdelantoT  → Lista ventas con ESTADO_PAGO = ADELANTO
 *   api_marcarPagadoT      → Actualiza ESTADO_PAGO a PAGO COMPLETO
 *   api_getAdminHomeKpisT  → Patch para agregar factHoySI, factHoyPL, nVentasHoy
 */

// ════════════════════════════════════════════════════════
// NUEVAS FUNCIONES v2.0 — PAGOS PENDIENTES (HOME ADMIN)
// ════════════════════════════════════════════════════════

// ===== CTRL+F: api_getPagosAdelanto =====

/**
 * api_getPagosAdelanto — Lista todas las ventas con ESTADO_PAGO = ADELANTO
 * Usada en el Home Admin para mostrar pagos pendientes con WA + Marcar pagado
 */
function api_getPagosAdelanto() {
  cc_requireAdmin();

  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [] };

  var rows = sh.getRange(2, 1, lr - 1, 20).getValues();
  var items = [];

  rows.forEach(function(r, i) {
    var estadoPago = _up(_norm(r[VENT_COL.ESTADO_PAGO]));
    if (estadoPago !== 'ADELANTO') return;

    var numLimpio = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);

    items.push({
      rowNum:    i + 2,
      ventaId:   _norm(r[VENT_COL.VENTA_ID]),
      fecha:     _date(r[VENT_COL.FECHA]),
      nombres:   _norm(r[VENT_COL.NOMBRES]),
      apellidos: _norm(r[VENT_COL.APELLIDOS]),
      trat:      _norm(r[VENT_COL.TRATAMIENTO]),
      monto:     Number(r[VENT_COL.MONTO]) || 0,
      pago:      _norm(r[VENT_COL.PAGO]),
      asesor:    _norm(r[VENT_COL.ASESOR]),
      sede:      _up(_norm(r[VENT_COL.SEDE])),
      num:       _normNum(r[VENT_COL.CELULAR]),
      numLimpio: numLimpio,
      whatsapp:  _wa(numLimpio)
    });
  });

  // Ordenar por fecha más reciente primero
  items.sort(function(a, b) { return b.fecha > a.fecha ? 1 : -1; });

  return { ok: true, items: items, total: items.length };
}

/** Wrapper token */
function api_getPagosAdelantoT(token) {
  _setToken(token); return api_getPagosAdelanto();
}

// ===== CTRL+F: api_marcarPagado =====

/**
 * api_marcarPagado — Actualiza el ESTADO_PAGO de una venta a PAGO COMPLETO
 * @param {string} ventaId — ID único de la venta (col Q)
 */
function api_marcarPagado(ventaId) {
  cc_requireAdmin();
  ventaId = _norm(ventaId);
  if (!ventaId) return { ok: false, error: 'VentaId requerido' };

  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: false, error: 'Sin ventas' };

  // Buscar la fila por VENTA_ID (col Q = índice 16 base 0 = col 17 base 1)
  var ids = sh.getRange(2, VENT_COL.VENTA_ID + 1, lr - 1, 1).getValues();
  var rowNum = -1;
  for (var i = 0; i < ids.length; i++) {
    if (_norm(ids[i][0]) === ventaId) { rowNum = i + 2; break; }
  }

  if (rowNum === -1) return { ok: false, error: 'Venta no encontrada: ' + ventaId };

  // Actualizar ESTADO_PAGO a PAGO COMPLETO (col J = índice 9 base 0 = col 10 base 1)
  sh.getRange(rowNum, VENT_COL.ESTADO_PAGO + 1).setValue('PAGO COMPLETO');

  // Log de auditoría
  try {
    var s = cc_requireSession();
    _logAuditoria(s.idAsesor, 'PAGO_COMPLETO', ventaId, 'ADELANTO → PAGO COMPLETO');
  } catch(e) {}

  return { ok: true, ventaId: ventaId };
}

/** Wrapper token */
function api_marcarPagadoT(token, ventaId) {
  _setToken(token); return api_marcarPagado(ventaId);
}

// ════════════════════════════════════════════════════════
// PATCH api_getAdminHomeKpis — Agregar factHoySI, factHoyPL, nVentasHoy
// ════════════════════════════════════════════════════════
// INSTRUCCIÓN:
// BUSCAR con Ctrl+F: "function api_getAdminHomeKpis("
// Si existe, agregar los campos faltantes al objeto kpis que retorna.
// Si NO existe, usar la función completa de abajo.
// ===== CTRL+F: api_getAdminHomeKpisV2 =====

/**
 * api_getAdminHomeKpisV2 — Versión mejorada de los KPIs del Home Admin
 * Incluye factHoySI, factHoyPL, nVentasHoy para el panel de Ventas del Día
 * REEMPLAZA a api_getAdminHomeKpis si ya existe, o usa directamente si no.
 *
 * NOTA: Si ya tienes api_getAdminHomeKpisT funcionando bien,
 *       solo agrega los campos faltantes al objeto kpis de tu función existente:
 *         kpis.nVentasHoy = ventasHoy.length;
 *         kpis.factHoySI  = sum(ventasHoy donde sede=SAN ISIDRO);
 *         kpis.factHoyPL  = sum(ventasHoy donde sede=PUEBLO LIBRE);
 */
function api_getAdminHomeKpisV2() {
  cc_requireAdmin();

  var now   = new Date();
  var hoy   = _date(now);
  var mesI  = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
  var mesF  = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

  // ── Ventas de hoy ────────────────────────────────────
  var shV  = _sh(CFG.SHEET_VENTAS);
  var lrV  = shV.getLastRow();
  var ventasHoy = [];
  var ventasHoyAll = [];

  if (lrV >= 2) {
    var rowsV = shV.getRange(2, 1, lrV - 1, 19).getValues();
    rowsV.forEach(function(r) {
      var fd = _date(r[VENT_COL.FECHA]);
      if (fd !== hoy) return;
      var item = {
        nombres:   _norm(r[VENT_COL.NOMBRES]),
        apellidos: _norm(r[VENT_COL.APELLIDOS]),
        trat:      _norm(r[VENT_COL.TRATAMIENTO]),
        monto:     Number(r[VENT_COL.MONTO]) || 0,
        tipo:      _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO',
        asesor:    _norm(r[VENT_COL.ASESOR]),
        sede:      _up(_norm(r[VENT_COL.SEDE])),
        num:       _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR])
      };
      ventasHoyAll.push(item);
    });
    ventasHoy = ventasHoyAll.slice(0, 20); // Máximo 20 para el panel
  }

  var factHoy   = ventasHoyAll.reduce(function(s, v) { return s + v.monto; }, 0);
  var factHoySI = ventasHoyAll.filter(function(v) { return v.sede.indexOf('SAN ISIDRO') >= 0; })
                              .reduce(function(s, v) { return s + v.monto; }, 0);
  var factHoyPL = ventasHoyAll.filter(function(v) { return v.sede.indexOf('PUEBLO') >= 0; })
                              .reduce(function(s, v) { return s + v.monto; }, 0);

  // ── Ventas de ayer (para delta) ──────────────────────
  var ayer     = _date(new Date(now.getTime() - 86400000));
  var factAyer = 0;
  if (lrV >= 2) {
    var rowsA = shV.getRange(2, 1, lrV - 1, 10).getValues();
    rowsA.forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]) === ayer) factAyer += Number(r[VENT_COL.MONTO]) || 0;
    });
  }

  // ── Llamadas hoy ─────────────────────────────────────
  var shL    = _sh(CFG.SHEET_LLAMADAS);
  var lrL    = shL.getLastRow();
  var llamHoy = 0;
  var llamMes = 0;
  if (lrL >= 2) {
    var rowsL = shL.getRange(2, 1, lrL - 1, 6).getValues();
    rowsL.forEach(function(r) {
      var fd = _date(r[LLAM_COL.FECHA]);
      if (fd === hoy) llamHoy++;
      if (_inRango(r[LLAM_COL.FECHA], mesI, mesF)) llamMes++;
    });
  }

  // ── Citas hoy ────────────────────────────────────────
  var shA    = _shAgenda();
  var lrA    = shA.getLastRow();
  var citasHoy = 0;
  var citasAgHoy = 0;
  if (lrA >= 2) {
    var rowsC = shA.getRange(2, 1, lrA - 1, 18).getValues();
    rowsC.forEach(function(r) {
      if (_date(r[AG_COL.FECHA]) === hoy) {
        citasHoy++;
        var est = _up(_norm(r[AG_COL.ESTADO]));
        if (est !== 'CANCELADA' && est !== 'NO ASISTIO') citasAgHoy++;
      }
    });
  }

  // ── Leads del mes ────────────────────────────────────
  var shLd   = _sh(CFG.SHEET_LEADS);
  var lrLd   = shLd.getLastRow();
  var leadsMes = 0;
  if (lrLd >= 2) {
    var rowsLd = shLd.getRange(2, 1, lrLd - 1, 1).getValues();
    rowsLd.forEach(function(r) {
      if (_inRango(r[0], mesI, mesF)) leadsMes++;
    });
  }

  // ── Delta ────────────────────────────────────────────
  var deltaVentasHoy = factAyer > 0 ? (factHoy - factAyer) / factAyer : null;

  var kpis = {
    factHoy:        factHoy,
    factHoySI:      factHoySI,
    factHoyPL:      factHoyPL,
    nVentasHoy:     ventasHoyAll.length,
    deltaVentasHoy: deltaVentasHoy,
    llamHoy:        llamHoy,
    llamMes:        llamMes,
    citasHoy:       citasHoy,
    citasAgHoy:     citasAgHoy,
    leadsMes:       leadsMes,
    alertas:        0
  };

  // ── Alertas del equipo ───────────────────────────────
  var alertasList = [];
  try {
    var semRes = api_getTeamSemaforo();
    if (semRes && semRes.filas) {
      semRes.filas.forEach(function(f) {
        var mins = f.minsSin;
        var est  = (f.estado || '').toUpperCase();
        var tipo = '';
        var msg  = '';

        if (mins !== null && mins > 15 && est !== 'EN LLAMADA') {
          tipo = 'inactivo';
          msg  = f.nombre + ' inactivo hace ' + mins + ' min';
        } else if (ESTADOS_PAUSA.has(est) && mins !== null && mins > 45) {
          tipo = 'break';
          msg  = f.nombre + ' en ' + est + ' hace ' + mins + ' min (>45min)';
        }

        if (msg) {
          alertasList.push({ tipo: tipo, nivel: tipo === 'inactivo' ? 'rojo' : 'amarillo', mensaje: msg });
        }
      });
      kpis.alertas = alertasList.length;
    }
  } catch(e) {}

  return {
    ok:        true,
    kpis:      kpis,
    ventasHoy: ventasHoy,
    alertas:   alertasList
  };
}

/** Wrapper token — este reemplaza/complementa al existente */
function api_getAdminHomeKpisV2T(token) {
  _setToken(token); return api_getAdminHomeKpisV2();
}

// ════════════════════════════════════════════════════════
// ALIAS — si quieres usar api_getAdminHomeKpisT (el original)
// pero con los campos nuevos, agrega esta función:
// ════════════════════════════════════════════════════════

/**
 * api_getAdminHomeKpisT — Wrapper que llama a la V2
 * Reemplaza la llamada en ViewAdminHome.html:
 *   .api_getAdminHomeKpisT(token)
 * por:
 *   .api_getAdminHomeKpisT(token)  ← funciona si renombras api_getAdminHomeKpisV2T a este nombre
 *
 * INSTRUCCIÓN SIMPLIFICADA:
 * Si prefieres, renombra api_getAdminHomeKpisV2 a api_getAdminHomeKpis
 * y borra la versión anterior. Ambas hacen lo mismo.
 */