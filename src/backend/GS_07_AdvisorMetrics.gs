/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_07_AdvisorMetrics.gs                    ║
 * ║  Módulo: KPIs, Ranking, Comisiones y Atenciones             ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01–05                                     ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Dashboard del asesor (home panel)
 *   MOD-02 · Comisiones del asesor (mes + histórico)
 *   MOD-03 · Ranking del equipo
 *   MOD-04 · Atenciones y satisfacción
 *   MOD-05 · Top clientes del asesor
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · DASHBOARD DEL ASESOR
// ══════════════════════════════════════════════════════════════
// G01_START

/**
 * api_getAdvisorDashboard — Datos completos para el home del asesor
 * KPIs de hoy + comisión mini + seguimientos + atenciones
 */
function api_getAdvisorDashboard() {
  var s   = cc_requireSession();
  var now = new Date();
  var hoy = _date(now);

  // ── Llamadas de hoy ──
  var shL  = _sh(CFG.SHEET_LLAMADAS);
  var lrL  = shL.getLastRow();
  var llamHoy = 0; var citasHoy = 0;
  var ultLlam = null; var ultNum = "";

  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 20).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      var ia = _norm(r[LLAM_COL.ID_ASESOR]);
      var na = _up(r[LLAM_COL.ASESOR]);
      if (ia !== _norm(s.idAsesor) && na !== _up(s.asesor)) return;
      llamHoy++;
      if (_up(r[LLAM_COL.ESTADO]) === "CITA CONFIRMADA") citasHoy++;
      var ts = r[LLAM_COL.ULT_TS] ? new Date(r[LLAM_COL.ULT_TS]) : null;
      if (ts && (!ultLlam || ts > ultLlam)) {
        ultLlam = ts; ultNum = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      }
    });
  }

  // ── Seguimientos pendientes (quick) ──
  var segPend = 0; var segVencidos = 0;
  try {
    var shS = _shSeguimientos();
    var lrS = shS.getLastRow();
    if (lrS >= 2) {
      shS.getRange(2, 1, lrS - 1, 11).getValues().forEach(function(r) {
        if (_up(r[SEG_COL.ESTADO]) !== "PENDIENTE") return;
        var ia = _norm(r[SEG_COL.ID_ASESOR]);
        var na = _up(r[SEG_COL.ASESOR]);
        if (ia !== _norm(s.idAsesor) && na !== _up(s.asesor)) return;
        segPend++;
        if (_date(r[SEG_COL.FECHA_PROG]) < hoy) segVencidos++;
      });
    }
  } catch(e) {}

  // ── Ranking hoy ──
  var ranking = _calcRankingHoy(s.idAsesor, s.asesor, hoy);

  // ── Comisión mini del mes ──
  var comMes  = _calcComisionesMes(s.idAsesor, s.asesor);
  var metaMes = _getMetaAsesor(s.idAsesor);

  // ── Seguimientos para el panel (los 3 más urgentes) ──
  var segsPanel = [];
  try {
    var shS2 = _shSeguimientos();
    var lrS2 = shS2.getLastRow();
    if (lrS2 >= 2) {
      segsPanel = shS2.getRange(2, 1, lrS2 - 1, 11).getValues()
        .filter(function(r) {
          if (_up(r[SEG_COL.ESTADO]) !== "PENDIENTE") return false;
          var ia = _norm(r[SEG_COL.ID_ASESOR]);
          var na = _up(r[SEG_COL.ASESOR]);
          return ia === _norm(s.idAsesor) || na === _up(s.asesor);
        })
        .map(function(r) {
          var fp  = _date(r[SEG_COL.FECHA_PROG]);
          var tipo = fp < hoy ? "vencido" : fp === hoy ? "hoy" : "proximo";
          return {
            fecha: fp,
            hora:  _norm(r[SEG_COL.HORA_PROG]),
            num:   _normNum(r[SEG_COL.NUMERO]),
            trat:  _up(r[SEG_COL.TRATAMIENTO]),
            tipo:  tipo
          };
        })
        .sort(function(a, b) {
          var ord = { vencido: 0, hoy: 1, proximo: 2 };
          return ord[a.tipo] - ord[b.tipo];
        })
        .slice(0, 3);
    }
  } catch(e) {}

  // ── Atenciones mini ──
  var atenciones = _calcAtencionesMini(s.idAsesor, s.asesor);

  return {
    ok: true,
    kpis: {
      llamHoy:     llamHoy,
      citasHoy:    citasHoy,
      segPend:     segPend,
      segVencidos: segVencidos,
      rankingHoy:  ranking.puesto,
      rankingEmoji:ranking.emoji
    },
    comMes: {
      total:     comMes.total,
      serv:      comMes.serv,
      prod:      comMes.prod,
      factTotal: comMes.factTotal,
      meta:      metaMes,
      pct:       metaMes > 0 ? Math.round(comMes.total / metaMes * 100) : 0,
      deltaVentas: comMes.deltaVentas,
      deltaCom:    comMes.deltaCom
    },
    seguimientos: segsPanel,
    atenciones: atenciones,
    ts: _time(now)
  };
}

/**
 * Calcula ranking del asesor entre el equipo (hoy)
 */
function _calcRankingHoy(idAsesor, asesorNom, hoy) {
  var sh = _sh(CFG.SHEET_LLAMADAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { puesto: 1, emoji: "🥇" };

  var citasPorAsesor = {};
  sh.getRange(2, 1, lr - 1, 20).getValues().forEach(function(r) {
    if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
    if (_up(r[LLAM_COL.ESTADO]) !== "CITA CONFIRMADA") return;
    var ia = _norm(r[LLAM_COL.ID_ASESOR]) || _up(r[LLAM_COL.ASESOR]);
    citasPorAsesor[ia] = (citasPorAsesor[ia] || 0) + 1;
  });

  var miId   = _norm(idAsesor) || _up(asesorNom);
  var misCit = citasPorAsesor[miId] || 0;

  var puestos = Object.values(citasPorAsesor).sort(function(a, b) { return b - a; });
  var puesto  = puestos.indexOf(misCit) + 1;
  if (puesto < 1) puesto = Object.keys(citasPorAsesor).length + 1;

  var emojis = { 1: "🥇", 2: "🥈", 3: "🥉" };
  return { puesto: puesto, emoji: emojis[puesto] || "#" + puesto };
}
// G01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · COMISIONES DEL ASESOR
// ══════════════════════════════════════════════════════════════
// G02_START

/**
 * _calcComisionesMes — Calcula comisiones del asesor para un mes
 */
function _calcComisionesMes(idAsesor, asesorNom, anio, mes) {
  var now = new Date();
  anio = anio || now.getFullYear();
  mes  = mes  || (now.getMonth() + 1);

  // Usar cache si está disponible
  var cached = cache_getComisionesAsesor(idAsesor, anio, mes);
  if (cached) return cached;

  var desde = new Date(anio, mes - 1, 1);
  var hasta = new Date(anio, mes, 0, 23, 59, 59);
  var ventas = da_ventasData(desde, hasta);

  // Filtrar por asesor
  var miId  = _norm(idAsesor);
  var miNom = _up(asesorNom);
  var misVentas = ventas.filter(function(v) {
    return _up(v.asesor) === miNom || _norm(v.idAsesor) === miId;
  });

  var comServ = 0; var comProd = 0; var factTotal = 0;
  var tablas  = _loadTablasCom();

  misVentas.forEach(function(v) {
    factTotal += v.monto;
    var rate   = _comRate(v.tipo, v.monto);
    if (rate.tipo === "pct")   comServ += v.monto * rate.valor;
    else                       comProd += rate.valor;
  });

  // Delta vs mes anterior
  var anioAnt = mes === 1 ? anio - 1 : anio;
  var mesAnt  = mes === 1 ? 12 : mes - 1;
  var desdeA  = new Date(anioAnt, mesAnt - 1, 1);
  var hastaA  = new Date(anioAnt, mesAnt, 0, 23, 59, 59);
  var ventasAnt = da_ventasData(desdeA, hastaA).filter(function(v) {
    return _up(v.asesor) === miNom || _norm(v.idAsesor) === miId;
  });
  var factAnt  = ventasAnt.reduce(function(s, v) { return s + v.monto; }, 0);
  var comServAnt = 0; var comProdAnt = 0;
  ventasAnt.forEach(function(v) {
    var rate = _comRate(v.tipo, v.monto);
    if (rate.tipo === "pct") comServAnt += v.monto * rate.valor;
    else                     comProdAnt += rate.valor;
  });

  var deltaVentas = _delta(factAnt, factTotal);
  var deltaCom    = _delta(comServAnt + comProdAnt, comServ + comProd);

  var result = {
    total:       comServ + comProd,
    serv:        comServ,
    prod:        comProd,
    factTotal:   factTotal,
    ventas:      misVentas.length,
    deltaVentas: deltaVentas,
    deltaCom:    deltaCom,
    misVentas:   misVentas
  };

  cache_setComisionesAsesor(result, idAsesor, anio, mes);
  return result;
}

/**
 * Obtiene la meta de comisión mensual del asesor desde RRHH
 */
function _getMetaAsesor(idAsesor) {
  var asesores = _asesoresRaw();
  var a = asesores.find(function(x) { return _norm(x.idAsesor) === _norm(idAsesor); });
  return a ? (Number(a.meta) || 100) : 100;
}

/**
 * api_getAdvisorCommissions — Comisiones completas del asesor
 * Incluye histórico del año y top clientes
 */
function api_getAdvisorCommissions(anio) {
  var s   = cc_requireSession();
  anio    = Number(anio) || new Date().getFullYear();
  var mes = new Date().getMonth() + 1;

  // Mes actual
  var comMes = _calcComisionesMes(s.idAsesor, s.asesor, anio, mes);

  // Historial del año
  var historial = [];
  for (var m = 1; m <= mes; m++) {
    var cm = _calcComisionesMes(s.idAsesor, s.asesor, anio, m);
    historial.push({
      mes:     m,
      mesNom:  MESES_ES[m].slice(0, 3),
      fact:    cm.factTotal,
      comServ: cm.serv,
      comProd: cm.prod,
      comTotal:cm.total
    });
  }

  // Top 5 clientes del asesor
  var topClientes = _calcTopClientes(s.idAsesor, s.asesor, anio);

  return {
    ok:         true,
    mes:        mes,
    anio:       anio,
    comMes:     comMes,
    meta:       _getMetaAsesor(s.idAsesor),
    historial:  historial,
    topClientes:topClientes
  };
}

/**
 * Top 5 clientes del asesor por facturación en el año
 */
function _calcTopClientes(idAsesor, asesorNom, anio) {
  var desde  = new Date(anio, 0, 1);
  var hasta  = new Date(anio, 11, 31, 23, 59, 59);
  var ventas = da_ventasData(desde, hasta);
  var miId   = _norm(idAsesor);
  var miNom  = _up(asesorNom);

  var clienteMap = {};
  ventas.filter(function(v) {
    return _up(v.asesor) === miNom || _norm(v.idAsesor) === miId;
  }).forEach(function(v) {
    var nom = (_norm(v.nombres) + " " + _norm(v.apellidos)).trim().toUpperCase();
    var key = _normNum(v.num) || nom;
    if (!clienteMap[key]) {
      clienteMap[key] = {
        nombre:  nom,
        num:     _normNum(v.num),
        fact:    0,
        ultFecha:"",
        wa:      _wa(_normNum(v.num))
      };
    }
    clienteMap[key].fact += v.monto;
    if (!clienteMap[key].ultFecha || _date(v.fecha) > clienteMap[key].ultFecha) {
      clienteMap[key].ultFecha = _date(v.fecha);
    }
  });

  return Object.values(clienteMap)
    .sort(function(a, b) { return b.fact - a.fact; })
    .slice(0, 5);
}

/** Wrappers token comisiones */
function api_getAdvisorDashboardT(token) {
  _setToken(token); return api_getAdvisorDashboard();
}
function api_getAdvisorCommissionsT(token, anio) {
  _setToken(token); return api_getAdvisorCommissions(anio);
}
// G02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · RANKING DEL EQUIPO
// ══════════════════════════════════════════════════════════════
// G03_START

/**
 * api_getTeamRanking — Ranking de comisiones del equipo
 * @param {number} anio
 * @param {number} mes
 */
function api_getTeamRanking(anio, mes) {
  cc_requireSession();
  var now = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);

  var asesores = _asesoresActivosCached().filter(function(a) {
    return a.role === ROLES.ASESOR;
  });

  var ranking = asesores.map(function(a) {
    var com = _calcComisionesMes(a.idAsesor, a.label || a.nombre, anio, mes);
    return {
      idAsesor:  a.idAsesor,
      nombre:    _up(a.label || a.nombre),
      comServ:   com.serv,
      comProd:   com.prod,
      comTotal:  com.total,
      fact:      com.factTotal,
      ventas:    com.ventas,
      delta:     com.deltaCom,
      meta:      _getMetaAsesor(a.idAsesor)
    };
  }).sort(function(a, b) { return b.comTotal - a.comTotal; });

  var totalCom  = ranking.reduce(function(s, x) { return s + x.comTotal; }, 0);
  var totalFact = ranking.reduce(function(s, x) { return s + x.fact; }, 0);

  return {
    ok:        true,
    ranking:   ranking,
    totalCom:  totalCom,
    totalFact: totalFact,
    mes:       mes,
    anio:      anio
  };
}

/** Wrapper token ranking */
function api_getTeamRankingT(token, anio, mes) {
  _setToken(token); return api_getTeamRanking(anio, mes);
}
// G03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · ATENCIONES Y SATISFACCIÓN
// ══════════════════════════════════════════════════════════════
// G04_START

/**
 * Calcula métricas mini de atenciones del asesor
 * @returns {Object} {atendidos, notaProm, pctRecom}
 */
function _calcAtencionesMini(idAsesor, asesorNom) {
  var result = { atendidos: 0, notaProm: null, pctRecom: 0 };
  try {
    var sh = _shSatisfaccion();
    var lr = sh.getLastRow();
    if (lr < 2) return result;

    var miId  = _norm(idAsesor);
    var miNom = _up(asesorNom);
    var mes   = new Date().getMonth() + 1;
    var anio  = new Date().getFullYear();
    var desde = _date(new Date(anio, mes - 1, 1));
    var hasta = _date(new Date(anio, mes, 0));

    var mias = sh.getRange(2, 1, lr - 1, 16).getValues()
      .filter(function(r) {
        var ia = _norm(r[4]);  // col E = ASESOR col index 4
        var na = _up(r[4]);
        var fd = _date(r[1]);
        return (ia === miId || na === miNom) &&
               fd >= desde && fd <= hasta;
      });

    result.atendidos = mias.length;
    if (mias.length > 0) {
      var notas = mias.map(function(r) { return Number(r[12]) || 0; });
      var sum   = notas.reduce(function(s, n) { return s + n; }, 0);
      result.notaProm = Math.round(sum / notas.length * 10) / 10;
      var recomendaron = mias.filter(function(r) {
        return Number(r[11]) >= 8; // P6_RECOMENDACION >= 8/10
      }).length;
      result.pctRecom = Math.round(recomendaron / mias.length * 100);
    }
  } catch(e) {}
  return result;
}

/**
 * api_getMyAttendance — Atenciones completas del asesor
 * Datos para el panel Mis Atenciones
 */
function api_getMyAttendance(mes, anio) {
  var s   = cc_requireSession();
  var now = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);

  var desde = _date(new Date(anio, mes - 1, 1));
  var hasta  = _date(new Date(anio, mes, 0));

  var result = { atendidos: 0, notaProm: null, pctRecom: 0, items: [] };
  try {
    var sh = _shSatisfaccion();
    var lr = sh.getLastRow();
    if (lr < 2) return { ok: true, ...result };

    var miId  = _norm(s.idAsesor);
    var miNom = _up(s.asesor);

    var items = sh.getRange(2, 1, lr - 1, 16).getValues()
      .filter(function(r) {
        var ia = _norm(r[4]);
        var na = _up(r[4]);
        var fd = _date(r[1]);
        return (ia === miId || na === miNom) &&
               fd >= desde && fd <= hasta;
      })
      .map(function(r) {
        return {
          id:          _norm(r[0]),
          fecha:       _date(r[1]),
          num:         _normNum(r[2]),
          paciente:    _norm(r[3]),
          p1:          Number(r[5])  || 0,
          p2:          Number(r[6])  || 0,
          p3:          Number(r[7])  || 0,
          p4:          Number(r[8])  || 0,
          p5:          Number(r[9])  || 0,
          p6:          Number(r[10]) || 0,
          feedback:    _norm(r[11]),
          nota:        Number(r[12]) || 0,
          estado:      _norm(r[14])
        };
      });

    result.atendidos = items.length;
    result.items     = items;

    if (items.length > 0) {
      var sumN = items.reduce(function(s, x) { return s + x.nota; }, 0);
      result.notaProm = Math.round(sumN / items.length * 10) / 10;
      var recom = items.filter(function(x) { return x.p6 >= 8; }).length;
      result.pctRecom = Math.round(recom / items.length * 100);
    }
  } catch(e) {}

  return Object.assign({ ok: true, mes: mes, anio: anio }, result);
}

/** Wrapper token atenciones */
function api_getMyAttendanceT(token, mes, anio) {
  _setToken(token); return api_getMyAttendance(mes, anio);
}
// G04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · VENTAS DEL ASESOR
// ══════════════════════════════════════════════════════════════
// G05_START

/**
 * api_getMyLastSales — Últimas ventas del asesor (para panel home)
 * @param {number} limit
 */
function api_getMyLastSales(limit) {
  var s   = cc_requireSession();
  limit   = Number(limit) || 5;
  var now = new Date();
  var desde = new Date(now.getFullYear(), now.getMonth(), 1);
  var hasta = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

  var ventas = da_ventasData(desde, hasta);
  var miId   = _norm(s.idAsesor);
  var miNom  = _up(s.asesor);

  var mis = ventas
    .filter(function(v) {
      return _up(v.asesor) === miNom || _norm(v.idAsesor) === miId;
    })
    .sort(function(a, b) {
      return _date(b.fecha) < _date(a.fecha) ? -1 : 1;
    })
    .slice(0, limit);

  return { ok: true, items: mis };
}

/** Wrapper token last sales */
function api_getMyLastSalesT(token, limit) {
  _setToken(token); return api_getMyLastSales(limit);
}
// G05_END

/**
 * TEST
 */
function test_AdvisorMetrics() {
  Logger.log("=== GS_07_AdvisorMetrics TEST ===");
  Logger.log("Funciones disponibles:");
  Logger.log("  api_getAdvisorDashboardT(token)");
  Logger.log("  api_getAdvisorCommissionsT(token, anio)");
  Logger.log("  api_getTeamRankingT(token, anio, mes)");
  Logger.log("  api_getMyAttendanceT(token, mes, anio)");
  Logger.log("  api_getMyLastSalesT(token, limit)");
  Logger.log("=== OK ===");
}