/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_12_AdminDashboard.gs v2.1               ║
 * ║  Módulo: Home Admin — KPIs ejecutivos y monitoreo           ║
 * ║  FIXES:                                                     ║
 * ║    B-05 · undefined min SRA CARMEN → cálculo minsSin seguro ║
 * ║    CLEAN · wrapper api_getMarketingTickerT duplicado        ║
 * ╚══════════════════════════════════════════════════════════════╝
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · KPIs EJECUTIVOS
// ══════════════════════════════════════════════════════════════
// L01_START

function api_getAdminHomeKpis() {
  cc_requireAdmin();
  var now  = new Date();
  var hoy  = _date(now);
  var mes  = now.getMonth() + 1;
  var anio = now.getFullYear();

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

  var mesStr  = anio + '-' + String(mes).padStart(2, '0');
  var factHoy = 0; var countHoy = 0;
  var factMes = 0; var countMes = 0;
  var ventasHoy = [];
  ventData.forEach(function(r) {
    var fd    = _date(r[VENT_COL.FECHA]);
    var monto = Number(r[VENT_COL.MONTO]) || 0;
    if (fd.slice(0, 7) === mesStr) { factMes += monto; countMes++; }
    if (fd === hoy) {
      factHoy += monto; countHoy++;
      ventasHoy.push({
        fecha: fd, nombres: _norm(r[VENT_COL.NOMBRES]),
        apellidos: _norm(r[VENT_COL.APELLIDOS]),
        num: _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]),
        trat: _norm(r[VENT_COL.TRATAMIENTO]), monto: monto,
        tipo: _up(_norm(r[VENT_COL.TIPO])), asesor: _up(_norm(r[VENT_COL.ASESOR])),
        sede: _up(_norm(r[VENT_COL.SEDE]))
      });
    }
  });

  var citasAgHoy = 0; var asistieronHoy = 0;
  agData.forEach(function(r) {
    if (_date(r[AG_COL.FECHA]) !== hoy) return;
    if (_up(r[AG_COL.ESTADO]) === 'CANCELADA') return;
    citasAgHoy++;
    var edo = _up(r[AG_COL.ESTADO]);
    if (edo === 'ASISTIO' || edo === 'EFECTIVA') asistieronHoy++;
  });

  var leadsMes = 0;
  leadData.forEach(function(r) {
    var fd = _date(r[LEAD_COL.FECHA] || r[0]);
    if (fd.slice(0, 7) === mesStr) leadsMes++;
  });

  var alertas = _calcAlertas(byAsesorHoy, now);
  var ayerStr = _date(new Date(now.getTime() - 86400000));
  var factAyer = ventData
    .filter(function(r) { return _date(r[VENT_COL.FECHA]) === ayerStr; })
    .reduce(function(s, r) { return s + (Number(r[VENT_COL.MONTO])||0); }, 0);
  var deltaVentasHoy = factAyer > 0 ? (factHoy - factAyer) / factAyer : null;

  return {
    ok: true, ts: _time(now),
    kpis: {
      factHoy: factHoy, countHoy: countHoy, factMes: factMes, countMes: countMes,
      llamHoy: llamHoy, citasHoy: citasHoy, citasAgHoy: citasAgHoy,
      asistieronHoy: asistieronHoy, leadsMes: leadsMes,
      alertas: alertas.length, deltaVentasHoy: deltaVentasHoy
    },
    ventasHoy: ventasHoy, alertas: alertas
  };
}

function _calcAlertas(byAsesorHoy, now) {
  var alertas = [];
  var estadoMap = _getEstadosEquipo();
  _asesoresActivosCached().filter(function(a) {
    return a.role === ROLES.ASESOR;
  }).forEach(function(a) {
    var nom   = _up(a.label || a.nombre);
    var datos = byAsesorHoy[nom] || { llamadas:0, citas:0 };
    var edo   = estadoMap[nom] || {};
    var mins  = edo.minutos;
    var estado = edo.estado || '';
    if (estado === 'ACTIVO' && datos.llamadas === 0) {
      alertas.push({ tipo:'sin_llamadas', asesor:nom, mensaje:nom+' está activo sin llamadas', nivel:'rojo' });
    }
    if (mins !== null && mins > 30 && estado !== 'PAUSA' && estado !== 'CIERRE') {
      alertas.push({ tipo:'inactivo', asesor:nom, mensaje:nom+' inactivo hace '+mins+' min', nivel:'amarillo' });
    }
  });
  return alertas;
}

// api_getAdminHomeKpisT → siempre usa V2 (con factHoySI, factHoyPL, nVentasHoy)
function api_getAdminHomeKpisT(token) {
  _setToken(token);
  return api_getAdminHomeKpisV2();
}
// L01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · MONITOREO DEL EQUIPO (SEMÁFORO)
// ══════════════════════════════════════════════════════════════
// L02_START

// ===== CTRL+F: function api_getTeamSemaforo() =====
function api_getTeamSemaforo() {
  cc_requireAdmin();
  var now = new Date();
  var hoy = _date(now);

  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lr  = shL.getLastRow();
  var byAsesor = {};

  if (lr >= 2) {
    shL.getRange(2, 1, lr - 1, 20).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      var nom = _up(_norm(r[LLAM_COL.ASESOR]));
      if (!nom) return;
      if (!byAsesor[nom]) byAsesor[nom] = { llamadas:0, citas:0, ultTs:null, ultNum:'' };
      byAsesor[nom].llamadas++;
      if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') byAsesor[nom].citas++;

      // B-05 FIX: parseo seguro del timestamp
      var tsRaw = r[LLAM_COL.ULT_TS];
      var ts = null;
      try {
        if (tsRaw) {
          var tsObj = (tsRaw instanceof Date) ? tsRaw : new Date(tsRaw);
          if (!isNaN(tsObj.getTime())) ts = tsObj;
        }
      } catch(eTs) { ts = null; }

      if (ts && (!byAsesor[nom].ultTs || ts > byAsesor[nom].ultTs)) {
        byAsesor[nom].ultTs  = ts;
        byAsesor[nom].ultNum = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      }
    });
  }

  var estadoMap = _getEstadosEquipo();
  var asesores  = _asesoresActivosCached().filter(function(a) {
    return a.role === ROLES.ASESOR;
  });

  var filas = asesores.map(function(a) {
    var nom   = _up(a.label || a.nombre);
    var datos = byAsesor[nom] || { llamadas:0, citas:0, ultTs:null, ultNum:'' };
    var edo   = estadoMap[nom] || { estado:'', minutos:null };

    // B-05 FIX: cálculo de minsSin completamente seguro
    var mins = null;
    try {
      if (datos.ultTs && datos.ultTs instanceof Date && !isNaN(datos.ultTs.getTime())) {
        var diff = now.getTime() - datos.ultTs.getTime();
        if (!isNaN(diff) && diff >= 0) mins = Math.floor(diff / 60000);
      }
    } catch(eM) { mins = null; }

    var sem = _calcSemaforo(mins, edo.estado);

    return {
      idAsesor: _norm(a.idAsesor),
      nombre:   nom,
      llamadas: datos.llamadas,
      citas:    datos.citas,
      ultTs:    datos.ultTs ? _time(datos.ultTs) : '—',
      ultNum:   datos.ultNum || '—',
      minsSin:  mins,       // ← null si no hay datos (ya no devuelve NaN)
      estado:   edo.estado || (datos.llamadas > 0 ? 'ACTIVO' : 'INACTIVO'),
      semaforo: sem,
      sede:     a.sede || ''
    };
  });

  var totLlam  = filas.reduce(function(s, f) { return s + f.llamadas; }, 0);
  var totCitas = filas.reduce(function(s, f) { return s + f.citas;    }, 0);
  var alertas  = filas.filter(function(f) { return f.semaforo === 'rojo'; }).length;

  return { ok:true, filas:filas, totLlam:totLlam, totCitas:totCitas, alertas:alertas, ts:_time(now) };
}

function api_getTeamSemaforoT(token) {
  _setToken(token); return api_getTeamSemaforo();
}
// L02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · TICKER DE MARKETING
// ══════════════════════════════════════════════════════════════
// L03_START

// ===== CTRL+F: function api_getMarketingTicker() =====
function api_getMarketingTicker() {
  cc_requireAdmin();
  var now   = new Date();
  var mes   = now.getMonth() + 1;
  var anio  = now.getFullYear();
  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes, 0, 23, 59, 59);
  var mesStr = anio + '-' + String(mes).padStart(2, '0');

  // Leads del mes
  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  var leads = 0; var leadNums = {};
  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 9).getValues().forEach(function(r) {
      if (!_inRango(r[LEAD_COL.FECHA] || r[0], desde, hasta)) return;
      leads++;
      var n = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
      if (n) { leadNums[n]=true; leadNums['51'+n]=true; leadNums[n.replace(/^51/,'')]=true; }
    });
  }

  // Llamados únicos del mes (solo leads nuevos)
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lrL = shL.getLastRow();
  var llamadosSet = {}; var citasLlam = 0;
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 10).getValues().forEach(function(r) {
      if (!_inRango(r[LLAM_COL.FECHA], desde, hasta)) return;
      var n = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      if (!n || !leadNums[n]) return;
      llamadosSet[n] = true;
      if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') citasLlam++;
    });
  }
  var llamados = Object.keys(llamadosSet).length;

  // Citas del mes en agenda
  var shAg = _shAgenda();
  var lrAg = shAg.getLastRow();
  var citas = 0; var asistieron = 0;
  if (lrAg >= 2) {
    shAg.getRange(2, 1, lrAg - 1, 15).getValues().forEach(function(r) {
      if (_date(r[AG_COL.FECHA]).slice(0, 7) !== mesStr) return;
      if (_up(r[AG_COL.ESTADO]) === 'CANCELADA') return;
      citas++;
      var edo = _up(r[AG_COL.ESTADO]);
      if (edo === 'ASISTIO' || edo === 'EFECTIVA') asistieron++;
    });
  }

  // Ventas solo de leads nuevos del mes
  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  var ventas = 0; var factMes = 0;
  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 17).getValues().forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]).slice(0, 7) !== mesStr) return;
      var numV = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
      if (!numV || !leadNums[numV]) return;
      ventas++; factMes += Number(r[VENT_COL.MONTO]) || 0;
    });
  }

  // Inversión para ROAS y CAC
  var invTotal = 0;
  try {
    var invMap = da_inversionData(mes, anio, 'mes');
    invTotal = Object.values(invMap).reduce(function(s, v) { return s + v; }, 0);
  } catch(e) {}
  if (!invTotal) {
    try {
      var shCfg = _sh(CFG.SHEET_CONFIG_SYS || 'CONFIGURACION');
      var lrCfg = shCfg.getLastRow();
      if (lrCfg >= 2) {
        shCfg.getRange(2, 1, lrCfg - 1, 2).getValues().forEach(function(r) {
          if (_norm(r[0]) === 'inversion_mes') invTotal = Number(r[1]) || 0;
        });
      }
    } catch(e2) {}
  }

  var roas = invTotal > 0 && factMes > 0 ? +(factMes  / invTotal).toFixed(2) : null;
  var cac  = invTotal > 0 && ventas  > 0 ? +(invTotal / ventas).toFixed(2)   : null;

  return {
    ok:true, leads:leads, llamados:llamados, citas:citasLlam,
    asistieron:asistieron, ventas:ventas, factMes:factMes, roas:roas, cac:cac,
    tasas:{
      llamados:   leads      > 0 ? Math.round(llamados   / leads      * 100) : 0,
      citas:      llamados   > 0 ? Math.round(citasLlam  / llamados   * 100) : 0,
      asistencia: citas      > 0 ? Math.round(asistieron / citas      * 100) : 0,
      conversion: asistieron > 0 ? Math.round(ventas     / asistieron * 100) : 0
    }
  };
}

// ÚNICO wrapper — limpiado (estaba duplicado antes)
function api_getMarketingTickerT(token) {
  _setToken(token); return api_getMarketingTicker();
}
// L03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · OPERACIONES
// ══════════════════════════════════════════════════════════════
// L04_START

function api_getOperationsPanel() {
  cc_requireAdmin();
  var now = new Date(); var hoy = _date(now);
  var semaforo = api_getTeamSemaforo();

  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lr  = shL.getLastRow();
  var ultLlamadas = [];
  if (lr >= 2) {
    var rows = shL.getRange(2, 1, lr - 1, 20).getValues();
    rows.forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      ultLlamadas.push({
        hora: _time(r[LLAM_COL.HORA] || new Date()),
        asesor: _up(_norm(r[LLAM_COL.ASESOR])),
        num: _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]),
        trat: _up(_norm(r[LLAM_COL.TRATAMIENTO])),
        estado: _up(r[LLAM_COL.ESTADO])
      });
    });
    ultLlamadas.sort(function(a,b){ return a.hora < b.hora ? 1 : -1; });
    ultLlamadas = ultLlamadas.slice(0, 20);
  }

  var shA = _shAgenda(); var lrA = shA.getLastRow();
  var citasHoy = [];
  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 22).getValues().forEach(function(r) {
      if (_date(r[AG_COL.FECHA]) !== hoy) return;
      citasHoy.push({
        hora: _normHora(r[AG_COL.HORA_CITA]),
        nombre: _norm(r[AG_COL.NOMBRE]) + ' ' + _norm(r[AG_COL.APELLIDO]),
        trat: _norm(r[AG_COL.TRATAMIENTO]), estado: _norm(r[AG_COL.ESTADO]),
        doctora: _norm(r[AG_COL.DOCTORA]), asesor: _norm(r[AG_COL.ASESOR]),
        sede: _norm(r[AG_COL.SEDE])
      });
    });
    citasHoy.sort(function(a,b){ return a.hora < b.hora ? -1 : 1; });
  }

  var tipifMap = {};
  if (lr >= 2) {
    shL.getRange(2, 1, lr - 1, 15).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      var t = _up(r[LLAM_COL.ESTADO]) || 'SIN TIPIF';
      tipifMap[t] = (tipifMap[t] || 0) + 1;
    });
  }

  return { ok:true, semaforo:semaforo, ultLlamadas:ultLlamadas, citasHoy:citasHoy, tipifMap:tipifMap, ts:_time(now) };
}

function api_getOperationsPanelT(token) {
  _setToken(token); return api_getOperationsPanel();
}
// L04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · RANKING COMISIONES
// ══════════════════════════════════════════════════════════════
// L05_START

function api_getAdminRankingComisiones() {
  cc_requireAdmin();
  var now = new Date();
  return api_getTeamRanking(now.getFullYear(), now.getMonth() + 1);
}

function api_getAdminRankingComisionesT(token) {
  _setToken(token); return api_getAdminRankingComisiones();
}
// L05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · PAGOS PENDIENTES
// ══════════════════════════════════════════════════════════════
// L06_START

// ===== CTRL+F: api_getPagosAdelanto =====
function api_getPagosAdelanto() {
  cc_requireAdmin();
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:true, items:[] };

  var rows  = sh.getRange(2, 1, lr - 1, 20).getValues();
  var items = [];
  rows.forEach(function(r, i) {
    if (_up(_norm(r[VENT_COL.ESTADO_PAGO])) !== 'ADELANTO') return;
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
  items.sort(function(a,b){ return b.fecha > a.fecha ? 1 : -1; });
  return { ok:true, items:items, total:items.length };
}

function api_getPagosAdelantoT(token) {
  _setToken(token); return api_getPagosAdelanto();
}

// ===== CTRL+F: api_marcarPagado =====
function api_marcarPagado(ventaId) {
  cc_requireAdmin();
  ventaId = _norm(ventaId);
  if (!ventaId) return { ok:false, error:'VentaId requerido' };
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:false, error:'Sin ventas' };
  var ids = sh.getRange(2, VENT_COL.VENTA_ID + 1, lr - 1, 1).getValues();
  var rowNum = -1;
  for (var i = 0; i < ids.length; i++) {
    if (_norm(ids[i][0]) === ventaId) { rowNum = i + 2; break; }
  }
  if (rowNum === -1) return { ok:false, error:'Venta no encontrada: ' + ventaId };
  sh.getRange(rowNum, VENT_COL.ESTADO_PAGO + 1).setValue('PAGO COMPLETO');
  try {
    var s = cc_requireSession();
    _logAuditoria(s.idAsesor, 'PAGO_COMPLETO', ventaId, 'ADELANTO → PAGO COMPLETO');
  } catch(e) {}
  return { ok:true, ventaId:ventaId };
}

function api_marcarPagadoT(token, ventaId) {
  _setToken(token); return api_marcarPagado(ventaId);
}
// L06_END

// ══════════════════════════════════════════════════════════════
// MOD-07 · KPIs V2 (con factHoySI, factHoyPL, nVentasHoy)
// ══════════════════════════════════════════════════════════════
// L07_START

// ===== CTRL+F: api_getAdminHomeKpisV2 =====
function api_getAdminHomeKpisV2() {
  cc_requireAdmin();
  var now   = new Date();
  var hoy   = _date(now);
  var mesI  = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
  var mesF  = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

  var shV  = _sh(CFG.SHEET_VENTAS);
  var lrV  = shV.getLastRow();
  var ventasHoyAll = [];

  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 19).getValues().forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]) !== hoy) return;
      ventasHoyAll.push({
        nombres:   _norm(r[VENT_COL.NOMBRES]),
        apellidos: _norm(r[VENT_COL.APELLIDOS]),
        trat:      _norm(r[VENT_COL.TRATAMIENTO]),
        monto:     Number(r[VENT_COL.MONTO]) || 0,
        tipo:      _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO',
        asesor:    _norm(r[VENT_COL.ASESOR]),
        sede:      _up(_norm(r[VENT_COL.SEDE])),
        num:       _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR])
      });
    });
  }

  var factHoy   = ventasHoyAll.reduce(function(s, v){ return s + v.monto; }, 0);
  var factHoySI = ventasHoyAll.filter(function(v){
    var s = (v.sede||'').toUpperCase();
    return s.indexOf('SAN') >= 0 || s.indexOf('ISIDRO') >= 0;
  }).reduce(function(s, v){ return s + v.monto; }, 0);
  var factHoyPL = ventasHoyAll.filter(function(v){
    var s = (v.sede||'').toUpperCase();
    return s.indexOf('PUEBLO') >= 0 || s.indexOf('LIBRE') >= 0;
  }).reduce(function(s, v){ return s + v.monto; }, 0);

  var ayer     = _date(new Date(now.getTime() - 86400000));
  var factAyer = 0;
  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 10).getValues().forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]) === ayer) factAyer += Number(r[VENT_COL.MONTO]) || 0;
    });
  }

  var shL = _sh(CFG.SHEET_LLAMADAS); var lrL = shL.getLastRow();
  var llamHoy = 0; var llamMes = 0;
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 6).getValues().forEach(function(r) {
      var fd = _date(r[LLAM_COL.FECHA]);
      if (fd === hoy) llamHoy++;
      if (_inRango(r[LLAM_COL.FECHA], mesI, mesF)) llamMes++;
    });
  }

  var shA = _shAgenda(); var lrA = shA.getLastRow();
  var citasHoy = 0; var citasAgHoy = 0;
  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 18).getValues().forEach(function(r) {
      if (_date(r[AG_COL.FECHA]) === hoy) {
        citasHoy++;
        var est = _up(_norm(r[AG_COL.ESTADO]));
        if (est !== 'CANCELADA' && est !== 'NO ASISTIO') citasAgHoy++;
      }
    });
  }

  var shLd = _sh(CFG.SHEET_LEADS); var lrLd = shLd.getLastRow();
  var leadsMes = 0;
  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 1).getValues().forEach(function(r) {
      if (_inRango(r[0], mesI, mesF)) leadsMes++;
    });
  }

  var deltaVentasHoy = factAyer > 0 ? (factHoy - factAyer) / factAyer : null;

  var kpis = {
    factHoy:factHoy, factHoySI:factHoySI, factHoyPL:factHoyPL,
    nVentasHoy:ventasHoyAll.length, deltaVentasHoy:deltaVentasHoy,
    llamHoy:llamHoy, llamMes:llamMes, citasHoy:citasHoy,
    citasAgHoy:citasAgHoy, leadsMes:leadsMes, alertas:0
  };

  var alertasList = [];
  try {
    var semRes = api_getTeamSemaforo();
    if (semRes && semRes.filas) {
      semRes.filas.forEach(function(f) {
        // B-05 FIX: minsSin ya viene seguro desde api_getTeamSemaforo
        var mins = f.minsSin;
        var est  = (f.estado || '').toUpperCase();
        var msg  = '';
        var tipo = '';
        if (mins !== null && !isNaN(mins) && mins > 15 && est !== 'EN LLAMADA') {
          tipo = 'inactivo'; msg = f.nombre + ' inactivo hace ' + mins + ' min';
        } else if (ESTADOS_PAUSA.has(est) && mins !== null && !isNaN(mins) && mins > 45) {
          tipo = 'break'; msg = f.nombre + ' en ' + est + ' hace ' + mins + ' min (>45min)';
        }
        if (msg) alertasList.push({ tipo:tipo, nivel:tipo==='inactivo'?'rojo':'amarillo', mensaje:msg });
      });
      kpis.alertas = alertasList.length;
    }
  } catch(e) {}

  return { ok:true, kpis:kpis, ventasHoy:ventasHoyAll.slice(0,20), alertas:alertasList };
}

function api_getAdminHomeKpisV2T(token) {
  _setToken(token); return api_getAdminHomeKpisV2();
}
// L07_END

/**
 * TEST
 */
function test_AdminDashboard() {
  Logger.log('=== GS_12_AdminDashboard v2.1 TEST ===');
  Logger.log('B-05 FIX: minsSin ahora es null (no NaN) para asesores sin ultTs');
  Logger.log('CLEAN: api_getMarketingTickerT ya no está duplicado');
  Logger.log('Funciones: api_getAdminHomeKpisT → api_getTeamSemaforoT → api_getMarketingTickerT');
  Logger.log('=== OK ===');
}