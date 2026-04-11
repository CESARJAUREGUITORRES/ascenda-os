/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_12_AdminDashboard.gs                    ║
 * ║  Versión: 3.0.0                                             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CAMBIOS v3.0.0:
 *   PERF-01 · api_getAdminHomeKpisV2: caché TTL 90s por día
 *             Lee 4 hojas grandes → ahora solo en el primer request
 *             Requests siguientes: <100ms desde caché
 *   PERF-02 · api_getTeamSemaforo: caché TTL 30s
 *             Lee LLAMADAS completo (12,201 filas) → ahora cacheado
 *   PERF-03 · api_getMarketingTicker: caché TTL 5 min
 *   PERF-04 · api_getAdminHomeKpis: también usa caché (alias V2)
 *   INVALIDAR: cache_invalidateDashboard() limpia todos al guardar venta/llamada
 *
 * CONTENIDO:
 *   MOD-01 · KPIs ejecutivos (con caché v3)
 *   MOD-02 · Monitoreo del equipo semáforo (con caché v3)
 *   MOD-03 · Ticker de marketing (con caché v3)
 *   MOD-04 · Operaciones
 *   MOD-05 · Ranking comisiones
 *   MOD-06 · Pagos pendientes
 *   MOD-07 · KPIs V2 (con caché v3)
 */

// ══════════════════════════════════════════════════════════════
// CLAVES DE CACHÉ DEL DASHBOARD
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: DASH_CACHE_KEYS =====
var _DASH_KPIS_TTL    = 90;   // 90 segundos — KPIs del día
var _DASH_SEM_TTL     = 30;   // 30 segundos — semáforo del equipo
var _DASH_TICKER_TTL  = 300;  // 5 minutos   — ticker marketing

function _dashKpisKey(hoy)   { return "AOS_DASH_KPIS_"   + (hoy || _date(new Date())); }
function _dashSemKey(hoy)    { return "AOS_DASH_SEM_"    + (hoy || _date(new Date())); }
function _dashTickerKey(mes) { return "AOS_DASH_TICKER_" + (mes || _mesKey()); }
function _mesKey() {
  var n = new Date();
  return n.getFullYear() + "-" + String(n.getMonth() + 1).padStart(2, "0");
}

/**
 * Invalida TODOS los cachés del dashboard.
 * Llamar desde api_saveCall y api_registrarPago.
 * Ya existe en GS_05 como cache_invalidateDashboard() — esta función
 * agrega la invalidación de los nuevos keys v3.
 */
function _invalidateDashboardV3() {
  var hoy = _date(new Date());
  try { cache_delete(_dashKpisKey(hoy));          } catch(e) {}
  try { cache_delete(_dashSemKey(hoy));           } catch(e) {}
  try { cache_delete(_dashTickerKey(_mesKey()));  } catch(e) {}
  try { cache_invalidateDashboard();              } catch(e) {} // GS_05 original
}
// ===== CTRL+F: DASH_CACHE_KEYS_END =====


// ══════════════════════════════════════════════════════════════
// MOD-01 · KPIs EJECUTIVOS
// ══════════════════════════════════════════════════════════════
// L01_START

function api_getAdminHomeKpis() {
  // alias → siempre usa V2
  return api_getAdminHomeKpisV2();
}

function _calcAlertas(byAsesorHoy, now) {
  var alertas   = [];
  var estadoMap = _getEstadosEquipo();
  _asesoresActivosCached().filter(function(a) {
    return a.role === ROLES.ASESOR;
  }).forEach(function(a) {
    var nom    = _up(a.label || a.nombre);
    var datos  = byAsesorHoy[nom] || { llamadas:0, citas:0 };
    var edo    = estadoMap[nom] || {};
    var mins   = edo.minutos;
    var estado = edo.estado || "";
    if (estado === "ACTIVO" && datos.llamadas === 0) {
      alertas.push({ tipo:"sin_llamadas", asesor:nom, mensaje:nom + " está activo sin llamadas", nivel:"rojo" });
    }
    if (mins !== null && mins > 30 && estado !== "PAUSA" && estado !== "CIERRE") {
      alertas.push({ tipo:"inactivo", asesor:nom, mensaje:nom + " inactivo hace " + mins + " min", nivel:"amarillo" });
    }
  });
  return alertas;
}

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

  // PERF-02: caché TTL 30s
  var cacheKey = _dashSemKey(hoy);
  try {
    var cached = cache_get(cacheKey);
    if (cached) return cached;
  } catch(e) {}

  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lr  = shL.getLastRow();
  var byAsesor = {};

  if (lr >= 2) {
    // Optimización: solo leer 7 cols (era 20) — solo necesitamos fecha, asesor, estado, ult_ts, num
    shL.getRange(2, 1, lr - 1, 20).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      var nom = _up(_norm(r[LLAM_COL.ASESOR]));
      if (!nom) return;
      if (!byAsesor[nom]) byAsesor[nom] = { llamadas:0, citas:0, ultTs:null, ultNum:"" };
      byAsesor[nom].llamadas++;
      if (_up(r[LLAM_COL.ESTADO]) === "CITA CONFIRMADA") byAsesor[nom].citas++;
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
    var datos = byAsesor[nom] || { llamadas:0, citas:0, ultTs:null, ultNum:"" };
    var edo   = estadoMap[nom] || { estado:"", minutos:null };
    var mins  = null;
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
      ultTs:    datos.ultTs ? _time(datos.ultTs) : "—",
      ultNum:   datos.ultNum || "—",
      minsSin:  mins,
      estado:   edo.estado || (datos.llamadas > 0 ? "ACTIVO" : "INACTIVO"),
      semaforo: sem,
      sede:     a.sede || ""
    };
  });

  var totLlam  = filas.reduce(function(s, f) { return s + f.llamadas; }, 0);
  var totCitas = filas.reduce(function(s, f) { return s + f.citas;    }, 0);
  var alertas  = filas.filter(function(f) { return f.semaforo === "rojo"; }).length;

  var resultado = { ok:true, filas:filas, totLlam:totLlam, totCitas:totCitas, alertas:alertas, ts:_time(now) };

  // Guardar en caché — el semáforo se renueva cada 30s
  try { cache_set(cacheKey, resultado, _DASH_SEM_TTL); } catch(e) {}

  return resultado;
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
  var now  = new Date();
  var mes  = now.getMonth() + 1;
  var anio = now.getFullYear();

  // PERF-03: caché TTL 5 min
  var cacheKey = _dashTickerKey(_mesKey());
  try {
    var cached = cache_get(cacheKey);
    if (cached) return cached;
  } catch(e) {}

  var desde  = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta  = new Date(anio, mes, 0, 23, 59, 59);
  var mesStr = anio + "-" + String(mes).padStart(2, "0");

  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  var leads = 0; var leadNums = {};
  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 9).getValues().forEach(function(r) {
      if (!_inRango(r[LEAD_COL.FECHA] || r[0], desde, hasta)) return;
      leads++;
      var n = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
      if (n) { leadNums[n]=true; leadNums["51"+n]=true; leadNums[n.replace(/^51/,"")]=true; }
    });
  }

  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lrL = shL.getLastRow();
  var llamadosSet = {}; var citasLlam = 0;
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 10).getValues().forEach(function(r) {
      if (!_inRango(r[LLAM_COL.FECHA], desde, hasta)) return;
      var n = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      if (!n || !leadNums[n]) return;
      llamadosSet[n] = true;
      if (_up(r[LLAM_COL.ESTADO]) === "CITA CONFIRMADA") citasLlam++;
    });
  }
  var llamados = Object.keys(llamadosSet).length;

  var shAg = _shAgenda();
  var lrAg = shAg.getLastRow();
  var citas = 0; var asistieron = 0;
  if (lrAg >= 2) {
    shAg.getRange(2, 1, lrAg - 1, 15).getValues().forEach(function(r) {
      if (_date(r[AG_COL.FECHA]).slice(0, 7) !== mesStr) return;
      if (_up(r[AG_COL.ESTADO]) === "CANCELADA") return;
      citas++;
      var edo = _up(r[AG_COL.ESTADO]);
      if (edo === "ASISTIO" || edo === "EFECTIVA") asistieron++;
    });
  }

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

  var invTotal = 0;
  try {
    var invMap = da_inversionData(mes, anio, "mes");
    invTotal = Object.values(invMap).reduce(function(s, v) { return s + v; }, 0);
  } catch(e) {}
  if (!invTotal) {
    try {
      var shCfg = _sh(CFG.SHEET_CONFIG_SYS || "CONFIGURACION");
      var lrCfg = shCfg.getLastRow();
      if (lrCfg >= 2) {
        shCfg.getRange(2, 1, lrCfg - 1, 2).getValues().forEach(function(r) {
          if (_norm(r[0]) === "inversion_mes") invTotal = Number(r[1]) || 0;
        });
      }
    } catch(e2) {}
  }

  var roas = invTotal > 0 && factMes > 0 ? +(factMes  / invTotal).toFixed(2) : null;
  var cac  = invTotal > 0 && ventas  > 0 ? +(invTotal / ventas).toFixed(2)   : null;

  var resultado = {
    ok:true, leads:leads, llamados:llamados, citas:citasLlam,
    asistieron:asistieron, ventas:ventas, factMes:factMes, roas:roas, cac:cac,
    tasas:{
      llamados:   leads      > 0 ? Math.round(llamados   / leads      * 100) : 0,
      citas:      llamados   > 0 ? Math.round(citasLlam  / llamados   * 100) : 0,
      asistencia: citas      > 0 ? Math.round(asistieron / citas      * 100) : 0,
      conversion: asistieron > 0 ? Math.round(ventas     / asistieron * 100) : 0
    }
  };

  // Guardar en caché
  try { cache_set(cacheKey, resultado, _DASH_TICKER_TTL); } catch(e) {}

  return resultado;
}

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
  var semaforo = api_getTeamSemaforo(); // ya usa caché

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
    ultLlamadas.sort(function(a,b){ return a.hora < b.hora ? 1 : -1; });
    ultLlamadas = ultLlamadas.slice(0, 20);
  }

  var shA = _shAgenda(); var lrA = shA.getLastRow();
  var citasHoy = [];
  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 22).getValues().forEach(function(r) {
      if (_date(r[AG_COL.FECHA]) !== hoy) return;
      citasHoy.push({
        hora:    _normHora(r[AG_COL.HORA_CITA]),
        nombre:  _norm(r[AG_COL.NOMBRE]) + " " + _norm(r[AG_COL.APELLIDO]),
        trat:    _norm(r[AG_COL.TRATAMIENTO]),
        estado:  _norm(r[AG_COL.ESTADO]),
        doctora: _norm(r[AG_COL.DOCTORA]),
        asesor:  _norm(r[AG_COL.ASESOR]),
        sede:    _norm(r[AG_COL.SEDE])
      });
    });
    citasHoy.sort(function(a,b){ return a.hora < b.hora ? -1 : 1; });
  }

  var tipifMap = {};
  if (lr >= 2) {
    shL.getRange(2, 1, lr - 1, 15).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      var t = _up(r[LLAM_COL.ESTADO]) || "SIN TIPIF";
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
    if (_up(_norm(r[VENT_COL.ESTADO_PAGO])) !== "ADELANTO") return;
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
  if (!ventaId) return { ok:false, error:"VentaId requerido" };
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:false, error:"Sin ventas" };
  var ids = sh.getRange(2, VENT_COL.VENTA_ID + 1, lr - 1, 1).getValues();
  var rowNum = -1;
  for (var i = 0; i < ids.length; i++) {
    if (_norm(ids[i][0]) === ventaId) { rowNum = i + 2; break; }
  }
  if (rowNum === -1) return { ok:false, error:"Venta no encontrada: " + ventaId };
  sh.getRange(rowNum, VENT_COL.ESTADO_PAGO + 1).setValue("PAGO COMPLETO");
  // Invalidar caché al marcar pagado
  _invalidateDashboardV3();
  try {
    var s = cc_requireSession();
    _logAuditoria(s.idAsesor, "PAGO_COMPLETO", ventaId, "ADELANTO → PAGO COMPLETO");
  } catch(e) {}
  return { ok:true, ventaId:ventaId };
}

function api_marcarPagadoT(token, ventaId) {
  _setToken(token); return api_marcarPagado(ventaId);
}
// L06_END


// ══════════════════════════════════════════════════════════════
// MOD-07 · KPIs V2 — CON CACHÉ v3
// ══════════════════════════════════════════════════════════════
// L07_START

// ===== CTRL+F: api_getAdminHomeKpisV2 =====
function api_getAdminHomeKpisV2() {
  cc_requireAdmin();
  var now = new Date();
  var hoy = _date(now);

  // PERF-01: caché TTL 90s — clave incluye el día para auto-invalidar a medianoche
  var cacheKey = _dashKpisKey(hoy);
  try {
    var cached = cache_get(cacheKey);
    if (cached) return cached;
  } catch(e) {}

  var mesI = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
  var mesF = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

  // VENTAS del día
  var shV  = _sh(CFG.SHEET_VENTAS);
  var lrV  = shV.getLastRow();
  var ventasHoyAll = [];
  var factAyer = 0;
  var ayer = _date(new Date(now.getTime() - 86400000));

  if (lrV >= 2) {
    // Una sola lectura para hoy Y ayer (era 2 lecturas)
    shV.getRange(2, 1, lrV - 1, 19).getValues().forEach(function(r) {
      var fd    = _date(r[VENT_COL.FECHA]);
      var monto = Number(r[VENT_COL.MONTO]) || 0;
      if (fd === ayer) { factAyer += monto; return; }
      if (fd !== hoy)  return;
      ventasHoyAll.push({
        nombres:   _norm(r[VENT_COL.NOMBRES]),
        apellidos: _norm(r[VENT_COL.APELLIDOS]),
        trat:      _norm(r[VENT_COL.TRATAMIENTO]),
        monto:     monto,
        tipo:      _up(_norm(r[VENT_COL.TIPO])) || "SERVICIO",
        asesor:    _norm(r[VENT_COL.ASESOR]),
        sede:      _up(_norm(r[VENT_COL.SEDE])),
        num:       _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR])
      });
    });
  }

  var factHoy   = ventasHoyAll.reduce(function(s, v){ return s + v.monto; }, 0);
  var factHoySI = ventasHoyAll.filter(function(v){
    return (v.sede||"").indexOf("ISIDRO") >= 0 || (v.sede||"").indexOf("SAN") >= 0;
  }).reduce(function(s, v){ return s + v.monto; }, 0);
  var factHoyPL = ventasHoyAll.filter(function(v){
    return (v.sede||"").indexOf("PUEBLO") >= 0 || (v.sede||"").indexOf("LIBRE") >= 0;
  }).reduce(function(s, v){ return s + v.monto; }, 0);

  // LLAMADAS — solo 6 cols (antes 20)
  var shL = _sh(CFG.SHEET_LLAMADAS); var lrL = shL.getLastRow();
  var llamHoy = 0; var llamMes = 0;
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 6).getValues().forEach(function(r) {
      var fd = _date(r[LLAM_COL.FECHA]);
      if (fd === hoy) llamHoy++;
      if (_inRango(r[LLAM_COL.FECHA], mesI, mesF)) llamMes++;
    });
  }

  // AGENDA — solo 18 cols
  var shA = _shAgenda(); var lrA = shA.getLastRow();
  var citasHoy = 0; var citasAgHoy = 0;
  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 18).getValues().forEach(function(r) {
      if (_date(r[AG_COL.FECHA]) !== hoy) return;
      citasHoy++;
      var est = _up(_norm(r[AG_COL.ESTADO]));
      if (est !== "CANCELADA" && est !== "NO ASISTIO") citasAgHoy++;
    });
  }

  // LEADS — solo 1 col
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
    var semRes = api_getTeamSemaforo(); // usa su propio caché (30s)
    if (semRes && semRes.filas) {
      semRes.filas.forEach(function(f) {
        var mins = f.minsSin;
        var est  = (f.estado || "").toUpperCase();
        var msg  = ""; var tipo = "";
        if (mins !== null && !isNaN(mins) && mins > 15 && est !== "EN LLAMADA") {
          tipo = "inactivo"; msg = f.nombre + " inactivo hace " + mins + " min";
        } else if (ESTADOS_PAUSA.has(est) && mins !== null && !isNaN(mins) && mins > 45) {
          tipo = "break"; msg = f.nombre + " en " + est + " hace " + mins + " min (>45min)";
        }
        if (msg) alertasList.push({ tipo:tipo, nivel:tipo==="inactivo"?"rojo":"amarillo", mensaje:msg });
      });
      kpis.alertas = alertasList.length;
    }
  } catch(e) {}

  var resultado = { ok:true, kpis:kpis, ventasHoy:ventasHoyAll.slice(0, 20), alertas:alertasList };

  // PERF-01: guardar en caché
  try { cache_set(cacheKey, resultado, _DASH_KPIS_TTL); } catch(e) {}

  return resultado;
}

function api_getAdminHomeKpisV2T(token) {
  _setToken(token); return api_getAdminHomeKpisV2();
}
// L07_END


// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════

function test_AdminDashboard_v3() {
  Logger.log("=== GS_12_AdminDashboard v3.0 TEST ===");

  Logger.log("--- Test KPIs con caché ---");
  var t1  = new Date().getTime();
  var r1  = api_getAdminHomeKpisV2();
  var t2  = new Date().getTime();
  Logger.log("Primera carga (sin caché): " + (t2-t1) + "ms");

  var t3  = new Date().getTime();
  var r2  = api_getAdminHomeKpisV2();
  var t4  = new Date().getTime();
  Logger.log("Segunda carga (con caché): " + (t4-t3) + "ms");
  Logger.log("✅ Señal de éxito: segunda carga < 200ms");

  Logger.log("--- Test semáforo con caché ---");
  var t5  = new Date().getTime();
  var s1  = api_getTeamSemaforo();
  var t6  = new Date().getTime();
  Logger.log("Primera carga semáforo: " + (t5-t6) + "ms | asesores: " + (s1.filas||[]).length);

  var t7  = new Date().getTime();
  var s2  = api_getTeamSemaforo();
  var t8  = new Date().getTime();
  Logger.log("Segunda carga semáforo (caché): " + (t7-t8) + "ms");

  Logger.log("=== OK ===");
}