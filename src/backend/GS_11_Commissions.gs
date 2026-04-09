 /**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_11_Commissions.gs                       ║
 * ║  Módulo: Comisiones, Metas y Ranking                        ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01–10                                     ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Panel completo de comisiones del asesor
 *   MOD-02 · Ranking del equipo (mes/año)
 *   MOD-03 · Tabla de comisiones (reglas)
 *   MOD-04 · Comisiones globales admin
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · PANEL COMPLETO DE COMISIONES DEL ASESOR
// ══════════════════════════════════════════════════════════════
// K01_START

/**
 * api_getFullCommissionsPanel — Datos completos para el panel Comisiones
 * @param {number} mes
 * @param {number} anio
 */
function api_getFullCommissionsPanel(mes, anio) {
  var s   = cc_requireSession();
  var now = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);

  // Comisiones del mes actual
  var comMes = _calcComisionesMes(s.idAsesor, s.asesor, anio, mes);

  // Meta y progreso
  var meta = _getMetaAsesor(s.idAsesor);
  var pct  = meta > 0 ? Math.round(comMes.total / meta * 100) : 0;

  // Historial anual
  var historial = [];
  for (var m = 1; m <= mes; m++) {
    var cm = _calcComisionesMes(s.idAsesor, s.asesor, anio, m);
    historial.push({
      mes:      m,
      mesNom:   MESES_ES[m].slice(0,3),
      mesNomFull: MESES_ES[m],
      fact:     cm.factTotal,
      comServ:  cm.serv,
      comProd:  cm.prod,
      comTotal: cm.total,
      ventas:   cm.ventas || 0
    });
  }

  // Ranking del equipo en el mes
  var ranking = api_getTeamRanking(anio, mes);
  var miPuesto = 1;
  if (ranking.ok) {
    var idx = ranking.ranking.findIndex(function(r) {
      return r.idAsesor === s.idAsesor;
    });
    if (idx >= 0) miPuesto = idx + 1;
  }

  // Top clientes del mes
  var desde = new Date(anio, mes - 1, 1);
  var hasta = new Date(anio, mes, 0, 23, 59, 59);
  var ventas = da_ventasData(desde, hasta);
  var miNom  = _up(s.asesor);
  var misVentas = ventas.filter(function(v) {
    return _up(v.asesor) === miNom || _norm(v.idAsesor) === _norm(s.idAsesor);
  });

  var clienteMap = {};
  misVentas.forEach(function(v) {
    var nom = (_norm(v.nombres) + " " + _norm(v.apellidos)).trim().toUpperCase() || v.num;
    var key = _normNum(v.num) || nom;
    if (!clienteMap[key]) {
      clienteMap[key] = {
        nombre:   nom,
        num:      _normNum(v.num),
        fact:     0,
        compras:  0,
        ultFecha: "",
        wa:       _wa(_normNum(v.num))
      };
    }
    clienteMap[key].fact    += v.monto;
    clienteMap[key].compras += 1;
    if (!clienteMap[key].ultFecha || _date(v.fecha) > clienteMap[key].ultFecha) {
      clienteMap[key].ultFecha = _date(v.fecha);
    }
  });
  var topClientes = Object.values(clienteMap)
    .sort(function(a,b) { return b.fact - a.fact; })
    .slice(0, 5);

  // Detalle de ventas con comisión
  var detalle = misVentas.map(function(v) {
    var rate = _comRate(v.tipo, v.monto);
    var com  = rate.tipo === "pct" ? v.monto * rate.valor : rate.valor;
    return {
      fecha:   _date(v.fecha),
      cliente: (_norm(v.nombres) + " " + _norm(v.apellidos)).trim() || v.num,
      num:     _normNum(v.num),
      trat:    _norm(v.trat),
      monto:   v.monto,
      tipo:    v.tipo,
      com:     com,
      sede:    v.sede,
      wa:      _wa(_normNum(v.num))
    };
  }).sort(function(a,b) { return a.fecha < b.fecha ? 1 : -1; });

  return {
    ok:         true,
    mes:        mes,
    anio:       anio,
    comMes:     comMes,
    meta:       meta,
    pct:        pct,
    puesto:     miPuesto,
    rankingEmoji: { 1:"🥇", 2:"🥈", 3:"🥉" }[miPuesto] || "#"+miPuesto,
    historial:  historial,
    topClientes:topClientes,
    detalle:    detalle,
    tablaReglas:_getReglasComision()
  };
}

/** Wrapper token panel comisiones */
function api_getFullCommissionsPanelT(token, mes, anio) {
  _setToken(token); return api_getFullCommissionsPanel(mes, anio);
}
// K01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · RANKING DEL EQUIPO
// (Alias de api_getTeamRanking en GS_07, centralizado aquí)
// ══════════════════════════════════════════════════════════════
// K02_START

/**
 * api_getCommissionsRankingT — Ranking para el panel de comisiones
 */
function api_getCommissionsRankingT(token, anio, mes) {
  _setToken(token);
  return api_getTeamRanking(anio, mes);
}
// K02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · TABLA DE REGLAS DE COMISIONES
// ══════════════════════════════════════════════════════════════
// K03_START

/**
 * _getReglasComision — Retorna las reglas de comisión formateadas
 */
function _getReglasComision() {
  var tablas = _loadTablasCom();
  return {
    servPct:  tablas.serv * 100,
    prodRangos: tablas.prod.map(function(r) {
      return {
        desde:  r.min,
        com:    r.com,
        label: "Desde S/" + r.min + " → S/" + r.com + " por venta"
      };
    })
  };
}

/**
 * api_getComisionSimulada — Simula cuánto ganaría el asesor
 * @param {number} monto
 * @param {string} tipo "SERVICIO" | "PRODUCTO"
 */
function api_getComisionSimulada(monto, tipo) {
  cc_requireSession();
  monto = Number(monto) || 0;
  tipo  = _up(tipo || "SERVICIO");

  var rate = _comRate(tipo, monto);
  var com  = rate.tipo === "pct" ? monto * rate.valor : rate.valor;

  return {
    ok:     true,
    monto:  monto,
    tipo:   tipo,
    com:    com,
    comFmt: _fmtSoles(com),
    rate:   rate
  };
}

/** Wrappers token */
function api_getComisionSimuladaT(token, monto, tipo) {
  _setToken(token); return api_getComisionSimulada(monto, tipo);
}
// K03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · COMISIONES GLOBALES ADMIN
// ══════════════════════════════════════════════════════════════
// K04_START

/**
 * api_getAdminCommissionsPanel — Panel de comisiones para el admin
 * @param {number} mes
 * @param {number} anio
 */
function api_getAdminCommissionsPanel(mes, anio) {
  cc_requireAdmin();
  var now = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);

  var ranking   = api_getTeamRanking(anio, mes);
  var totalCom  = ranking.totalCom  || 0;
  var totalFact = ranking.totalFact || 0;

  // Historial del equipo
  var historialEquipo = [];
  for (var m = 1; m <= mes; m++) {
    var rk = api_getTeamRanking(anio, m);
    historialEquipo.push({
      mes:      m,
      mesNom:   MESES_ES[m].slice(0,3),
      fact:     rk.totalFact,
      comTotal: rk.totalCom
    });
  }

  return {
    ok:             true,
    mes:            mes,
    anio:           anio,
    ranking:        ranking.ranking || [],
    totalCom:       totalCom,
    totalFact:      totalFact,
    historialEquipo:historialEquipo,
    tablaReglas:    _getReglasComision()
  };
}

/** Wrapper token admin comisiones */
function api_getAdminCommissionsPanelT(token, mes, anio) {
  _setToken(token); return api_getAdminCommissionsPanel(mes, anio);
}
// K04_END

/**
 * TEST
 */
function test_Commissions() {
  Logger.log("=== GS_11_Commissions TEST ===");
  Logger.log("Reglas: " + JSON.stringify(_getReglasComision()));
  Logger.log("Funciones: api_getFullCommissionsPanelT, api_getCommissionsRankingT, api_getAdminCommissionsPanelT");
  Logger.log("=== OK ===");
}