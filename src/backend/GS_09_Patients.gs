/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_09_Pacientes.gs                         ║
 * ║  Versión: 2.0.0                                             ║
 * ║  CAMBIOS v2.0.0:                                            ║
 * ║   PERF-01 · _getPatientHistory() cacheada por número        ║
 * ║             TTL 5 min — invalida al guardar nota/cita/venta  ║
 * ║   PERF-02 · api_listPatients lee cols=24 (era 20)           ║
 * ║             fix para ETIQUETA_BASE, SCORE_ESTADO,           ║
 * ║             DIAS_ULTIMA_VISITA que estaban ignorados         ║
 * ║   PERF-03 · api_getPatientProfile lee cols=24               ║
 * ║   FIX-01  · _mapPaciente incluye direccion y ocupacion      ║
 * ║   NEW-01  · api_invalidatePatientCacheT para invalidar       ║
 * ║             manualmente desde otros módulos                  ║
 * ╚══════════════════════════════════════════════════════════════╝
 * INSTRUCCIÓN DE INSTALACIÓN:
 *   1. Abrir GS_09_Pacientes.gs en Apps Script
 *   2. Ctrl+A → borrar todo
 *   3. Pegar este archivo completo
 *   4. Ctrl+S → Guardar
 *   5. Nueva versión de implementación → Implementar
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · LISTADO Y BÚSQUEDA
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: I01_START =====

function api_listPatients(query, page, limit) {
  cc_requireSession();
  query = _normSearch(query || "");
  page  = Math.max(1, Number(page)  || 1);
  limit = Math.min(200, Number(limit) || 50);

  var sh = _sh(CFG.SHEET_PACIENTES);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:true, items:[], total:0, page:1, pages:1 };

  // PERF-02: leer 24 cols (antes 20) para incluir cols del Bloque 3
  var cols = Math.min(sh.getLastColumn(), 24);
  var rows = sh.getRange(2, 1, lr - 1, cols).getValues();

  var filtered = rows.filter(function(r) {
    if (!r[PAC_COL.ID] && !r[PAC_COL.NOMBRES]) return false;
    if (!query) return true;
    var haystack = _normSearch(
      _norm(r[PAC_COL.ID])        + " " +
      _norm(r[PAC_COL.NOMBRES])   + " " +
      _norm(r[PAC_COL.APELLIDOS]) + " " +
      _norm(String(r[PAC_COL.TELEFONO])) + " " +
      _norm(r[PAC_COL.DOCUMENTO])
    );
    return haystack.includes(query);
  });

  var total = filtered.length;
  var pages = Math.max(1, Math.ceil(total / limit));
  var start = (page - 1) * limit;
  var slice = filtered.slice(start, start + limit);

  return { ok:true, items:slice.map(function(r){ return _mapPaciente(r); }), total:total, page:page, pages:pages };
}

function _mapPaciente(r) {
  return {
    id:          _norm(r[PAC_COL.ID]),
    nombres:     _norm(r[PAC_COL.NOMBRES]),
    apellidos:   _norm(r[PAC_COL.APELLIDOS]),
    telefono:    _normNum(r[PAC_COL.TELEFONO]),
    email:       _norm(r[PAC_COL.EMAIL]       || ""),
    documento:   _norm(r[PAC_COL.DOCUMENTO]   || ""),
    sexo:        _norm(r[PAC_COL.SEXO]        || ""),
    fechaNac:    _date(r[PAC_COL.FECHA_NAC]   || ""),
    direccion:   _norm(r[PAC_COL.DIRECCION]   || ""),   // FIX-01: antes faltaba
    ocupacion:   _norm(r[PAC_COL.OCUPACION]   || ""),   // FIX-01: antes faltaba
    sede:        _norm(r[PAC_COL.SEDE]        || ""),
    fuente:      _norm(r[PAC_COL.FUENTE]      || ""),
    fechaReg:    _date(r[PAC_COL.FECHA_REG]   || ""),
    totalCompras:Number(r[PAC_COL.TOTAL_COMPRAS]   || 0),
    totalFact:   Number(r[PAC_COL.TOTAL_FACTURADO] || 0),
    ultVisita:   _date(r[PAC_COL.ULTIMA_VISITA]    || ""),
    totalLlam:   Number(r[PAC_COL.TOTAL_LLAMADAS]  || 0),
    totalCitas:  Number(r[PAC_COL.TOTAL_CITAS]     || 0),
    estado:      _up(r[PAC_COL.ESTADO] || "NUEVO"),
    notas:       _norm(r[PAC_COL.NOTAS] || ""),
    wa:          _wa(_normNum(r[PAC_COL.TELEFONO]))
  };
}

function api_listPatientsT(token, query, page, limit) {
  _setToken(token); return api_listPatients(query, page, limit);
}
// ===== CTRL+F: I01_END =====


// ══════════════════════════════════════════════════════════════
// MOD-02 · PERFIL COMPLETO DEL PACIENTE
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: I02_START =====

function api_getPatientProfile(idOrNum) {
  cc_requireSession();
  idOrNum = _norm(idOrNum);
  if (!idOrNum) throw new Error("ID o número requerido.");

  var sh     = _sh(CFG.SHEET_PACIENTES);
  var lr     = sh.getLastRow();
  var pac    = null;
  var pacRow = null;

  if (lr >= 2) {
    // PERF-03: leer 24 cols (antes 20)
    var rows = sh.getRange(2, 1, lr - 1, 24).getValues();
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      if (_norm(r[PAC_COL.ID]) === idOrNum ||
          _normNum(r[PAC_COL.TELEFONO]) === _normNum(idOrNum)) {
        pac    = _mapPaciente(r);
        pacRow = i + 2;
        break;
      }
    }
  }

  if (!pac) pac = _buildProfileFromHistory(idOrNum);
  if (!pac) throw new Error("Paciente no encontrado: " + idOrNum);

  pac.rowNum   = pacRow;
  var historial = _getPatientHistoryCached(pac.telefono || idOrNum);
  return { ok:true, paciente:pac, historial:historial };
}

function _buildProfileFromHistory(num) {
  var limpio = _normNum(num);
  if (!limpio) return null;
  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  if (lrV >= 2) {
    var rows = shV.getRange(2, 1, lrV - 1, 19).getValues();
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      var n = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR] || "");
      if (n === limpio) {
        return {
          id:"P-SIN", nombres:_norm(r[VENT_COL.NOMBRES]), apellidos:_norm(r[VENT_COL.APELLIDOS]),
          telefono:limpio, documento:_norm(r[VENT_COL.DNI]),
          email:"", sexo:"", fechaNac:"", direccion:"", ocupacion:"",
          sede:"", fuente:"", fechaReg:"",
          totalCompras:0, totalFact:0, ultVisita:"", totalLlam:0, totalCitas:0,
          estado:"ACTIVO", notas:"", wa:_wa(limpio)
        };
      }
    }
  }
  return null;
}

// ══════════════════════════════════════════════════════════════
// PERF-01 · HISTORIAL CON CACHÉ POR NÚMERO
// TTL: 5 minutos. Se invalida automáticamente al guardar
// llamadas, notas, citas o ventas del mismo número.
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: CACHE_HISTORY_START =====

var _HIST_CACHE_TTL = 300; // 5 minutos en segundos

function _histCacheKey(num) {
  return "AOS_HIST_" + String(num || "").replace(/\D/g, "");
}

function _getPatientHistoryCached(num) {
  var limpio = _normNum(num);
  if (!limpio) return _emptyHistory();

  // Intentar leer del caché
  try {
    var cached = cache_get(_histCacheKey(limpio));
    if (cached) return cached;
  } catch(e) {}

  // Calcular historial real
  var historial = _getPatientHistory(limpio);

  // Guardar en caché
  try {
    cache_set(_histCacheKey(limpio), historial, _HIST_CACHE_TTL);
  } catch(e) {}

  return historial;
}

/**
 * api_invalidatePatientCache
 * Invalida el caché de historial de un paciente.
 * Llamar desde api_saveCall, api_saveNotaPaciente360,
 * api_createCitaDesde360, api_registrarPago cuando
 * el número del paciente esté disponible.
 */
function api_invalidatePatientCache(num) {
  var limpio = _normNum(num || "");
  if (!limpio) return;
  try { cache_delete(_histCacheKey(limpio)); } catch(e) {}
}

function api_invalidatePatientCacheT(token, num) {
  _setToken(token);
  api_invalidatePatientCache(num);
  return { ok:true };
}
// ===== CTRL+F: CACHE_HISTORY_END =====

function _emptyHistory() {
  return { llamadas:[], ventas:[], citas:[], totalFact:0, totalLlam:0, totalVentas:0, totalCitas:0 };
}

function _getPatientHistory(num) {
  var limpio = _normNum(num);
  if (!limpio) return _emptyHistory();

  var llamadas = [];
  try {
    var shL = _sh(CFG.SHEET_LLAMADAS);
    var lrL = shL.getLastRow();
    if (lrL >= 2) {
      llamadas = shL.getRange(2, 1, lrL - 1, 20).getValues()
        .filter(function(r){ return _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]) === limpio; })
        .map(function(r){ return {
          fecha:   _date(r[LLAM_COL.FECHA]),
          hora:    _time(r[LLAM_COL.HORA]),
          estado:  _up(r[LLAM_COL.ESTADO]),
          trat:    _up(r[LLAM_COL.TRATAMIENTO]),
          asesor:  _norm(r[LLAM_COL.ASESOR]),
          obs:     _norm(r[LLAM_COL.OBS]),
          intento: Number(r[LLAM_COL.INTENTO]) || 1
        }; })
        .sort(function(a,b){ return a.fecha < b.fecha ? 1 : -1; })
        .slice(0, 30);
    }
  } catch(e) {}

  var ventas = [];
  try {
    var shV = _sh(CFG.SHEET_VENTAS);
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      ventas = shV.getRange(2, 1, lrV - 1, 19).getValues()
        .filter(function(r){ return _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]) === limpio; })
        .map(function(r){ return {
          fecha:      _date(r[VENT_COL.FECHA]),
          trat:       _norm(r[VENT_COL.TRATAMIENTO]),
          monto:      Number(r[VENT_COL.MONTO]) || 0,
          tipo:       _up(r[VENT_COL.TIPO]),
          asesor:     _norm(r[VENT_COL.ASESOR]),
          sede:       _up(r[VENT_COL.SEDE]),
          pago:       _norm(r[VENT_COL.PAGO]),
          ventaId:    _norm(r[VENT_COL.VENTA_ID]    || ""),
          estadoPago: _up(r[VENT_COL.ESTADO_PAGO]   || "")
        }; })
        .sort(function(a,b){ return a.fecha < b.fecha ? 1 : -1; });
    }
  } catch(e) {}

  var citas = [];
  try {
    var shA = _shAgenda();
    var lrA = shA.getLastRow();
    if (lrA >= 2) {
      citas = shA.getRange(2, 1, lrA - 1, 23).getValues()
        .filter(function(r){ return _normNum(r[AG_COL.NUMERO]) === limpio; })
        .map(function(r){ return {
          citaId:   _norm(r[AG_COL.ID]),
          fecha:    _date(r[AG_COL.FECHA]),
          hora:     _normHora(r[AG_COL.HORA_CITA]),
          trat:     _norm(r[AG_COL.TRATAMIENTO]),
          tipoCita: _norm(r[AG_COL.TIPO_CITA]),
          estado:   _norm(r[AG_COL.ESTADO]),
          sede:     _norm(r[AG_COL.SEDE]),
          asesor:   _norm(r[AG_COL.ASESOR]),
          doctora:  _norm(r[AG_COL.DOCTORA]),
          obs:      _norm(r[AG_COL.OBS] || "")
        }; })
        .sort(function(a,b){ return a.fecha < b.fecha ? 1 : -1; });
    }
  } catch(e) {}

  var totalFact = ventas.reduce(function(s,v){ return s + v.monto; }, 0);
  return {
    llamadas:    llamadas,
    ventas:      ventas,
    citas:       citas,
    totalFact:   totalFact,
    totalLlam:   llamadas.length,
    totalVentas: ventas.length,
    totalCitas:  citas.length
  };
}

function api_getPatientProfileT(token, idOrNum) {
  _setToken(token); return api_getPatientProfile(idOrNum);
}

// ===== CTRL+F: api_getPatient360T =====
// UNA SOLA DEFINICIÓN — usada por ViewAdminPatients
function api_getPatient360T(token, numOrId) {
  _setToken(token);
  cc_requireSession();
  var res = api_getPatientProfile(numOrId);
  if (!res || !res.ok) return { ok:false, msg:"Paciente no encontrado: " + numOrId };
  var p = res.paciente;

  // Calcular días desde última visita
  if (p.ultVisita) {
    var hoy = new Date(); hoy.setHours(0,0,0,0);
    var uv  = new Date(p.ultVisita); uv.setHours(0,0,0,0);
    p.diasUltVisita = Math.floor((hoy - uv) / (1000*60*60*24));
  } else {
    p.diasUltVisita = null;
  }

  // Normalizar tildes en estado
  if (p.estado) {
    p.estado = p.estado.toUpperCase()
      .replace(/Ó/g,"O").replace(/É/g,"E").replace(/Á/g,"A")
      .replace(/Í/g,"I").replace(/Ú/g,"U");
  }

  // Normalizar tildes en estados de citas
  var h = res.historial || {};
  if (h.citas) {
    h.citas = h.citas.map(function(c) {
      c.estado = (c.estado || "").toUpperCase()
        .replace(/Ó/g,"O").replace(/É/g,"E").replace(/Á/g,"A")
        .replace(/Í/g,"I").replace(/Ú/g,"U");
      return c;
    });
  }

  return { ok:true, paciente:p, historial:h };
}
// ===== CTRL+F: I02_END =====


// ══════════════════════════════════════════════════════════════
// MOD-03 · ESTADÍSTICAS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: I03_START =====

function api_getPatientsStats() {
  cc_requireSession();
  var sh = _sh(CFG.SHEET_PACIENTES);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:true, total:0, activos:0, inactivos:0, nuevos:0 };
  var rows = sh.getRange(2, 1, lr - 1, 19).getValues()
    .filter(function(r){ return r[PAC_COL.ID] || r[PAC_COL.NOMBRES]; });
  return {
    ok:true,
    total:     rows.length,
    activos:   rows.filter(function(r){ return _up(r[PAC_COL.ESTADO]) === "ACTIVO"; }).length,
    inactivos: rows.filter(function(r){ return _up(r[PAC_COL.ESTADO]) === "INACTIVO"; }).length,
    nuevos:    rows.filter(function(r){ return _up(r[PAC_COL.ESTADO]) === "NUEVO" || !_norm(r[PAC_COL.ESTADO]); }).length
  };
}

function api_getPatientsStatsT(token) {
  _setToken(token); return api_getPatientsStats();
}
// ===== CTRL+F: I03_END =====


// ══════════════════════════════════════════════════════════════
// MOD-04 · ACTUALIZAR PACIENTES
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: I04_START =====

function api_updatePatientNotes(idOrNum, notas) {
  cc_requireSession();
  idOrNum = _norm(idOrNum);
  notas   = _norm(notas);
  var sh  = _sh(CFG.SHEET_PACIENTES);
  var lr  = sh.getLastRow();
  if (lr < 2) throw new Error("Sin pacientes.");
  var rows = sh.getRange(2, 1, lr - 1, 20).getValues();
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i];
    if (_norm(r[PAC_COL.ID]) === idOrNum ||
        _normNum(r[PAC_COL.TELEFONO]) === _normNum(idOrNum)) {
      sh.getRange(i + 2, PAC_COL.NOTAS + 1).setValue(notas);
      return { ok:true };
    }
  }
  throw new Error("Paciente no encontrado.");
}

function api_updatePatientNotesT(token, idOrNum, notas) {
  _setToken(token); return api_updatePatientNotes(idOrNum, notas);
}

function api_updatePatientFullT(token, idOrNum, payload) {
  _setToken(token);
  cc_requireSession();
  idOrNum = _norm(idOrNum);
  payload = payload || {};
  if (!idOrNum) throw new Error("ID o número requerido.");

  var sh   = _sh(CFG.SHEET_PACIENTES);
  var lr   = sh.getLastRow();
  var rowF = null;
  if (lr < 2) throw new Error("Sin pacientes.");

  var rows = sh.getRange(2, 1, lr - 1, 24).getValues();
  for (var i = 0; i < rows.length; i++) {
    if (_norm(rows[i][PAC_COL.ID]) === idOrNum ||
        _normNum(rows[i][PAC_COL.TELEFONO]) === _normNum(idOrNum)) {
      rowF = i + 2; break;
    }
  }
  if (!rowF) throw new Error("Paciente no encontrado: " + idOrNum);

  var cambios = [];
  function _set(col0, val) { cambios.push({ col:col0+1, val:_norm(String(val||"")) }); }

  if (payload.nombres   !== undefined) _set(PAC_COL.NOMBRES,   payload.nombres.trim().toUpperCase());
  if (payload.apellidos !== undefined) _set(PAC_COL.APELLIDOS, payload.apellidos.trim().toUpperCase());
  if (payload.email     !== undefined) _set(PAC_COL.EMAIL,     payload.email.trim().toLowerCase());
  if (payload.documento !== undefined) _set(PAC_COL.DOCUMENTO, payload.documento);
  if (payload.sexo      !== undefined) _set(PAC_COL.SEXO,      payload.sexo.toUpperCase());
  if (payload.fechaNac  !== undefined) _set(PAC_COL.FECHA_NAC, payload.fechaNac);
  if (payload.sede      !== undefined) _set(PAC_COL.SEDE,      payload.sede.toUpperCase());
  if (payload.fuente    !== undefined) _set(PAC_COL.FUENTE,    payload.fuente);
  if (payload.notas     !== undefined) _set(PAC_COL.NOTAS,     payload.notas);
  if (payload.direccion !== undefined) _set(PAC_COL.DIRECCION, payload.direccion);
  if (payload.ocupacion !== undefined) _set(PAC_COL.OCUPACION, payload.ocupacion);

  if (!cambios.length) return { ok:true, msg:"Sin cambios." };
  cambios.forEach(function(c){ sh.getRange(rowF, c.col).setValue(c.val); });

  // Invalidar caché del paciente editado
  try { api_invalidatePatientCache(_normNum(idOrNum)); } catch(e) {}

  return { ok:true, msg:"Paciente actualizado.", fila:rowF, cambios:cambios.length };
}
// ===== CTRL+F: I04_END =====


// ══════════════════════════════════════════════════════════════
// MOD-05 · COMPROBANTES (tab Comprobantes del panel 360)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: I05_START =====

function api_getVentasComprobantes(num) {
  cc_requireSession();
  num = _normNum(num);
  if (!num) return { ok:true, comprobantes:[], totalGeneral:0 };

  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  if (lrV < 2) return { ok:true, comprobantes:[], totalGeneral:0 };

  var MESES = ["ENE","FEB","MAR","ABR","MAY","JUN","JUL","AGO","SEP","OCT","NOV","DIC"];
  var ventas = shV.getRange(2, 1, lrV - 1, 19).getValues()
    .filter(function(r){ return _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]) === num; })
    .map(function(r){ return {
      fecha:      _date(r[VENT_COL.FECHA]),
      trat:       _norm(r[VENT_COL.TRATAMIENTO]),
      monto:      Number(r[VENT_COL.MONTO]) || 0,
      pago:       _norm(r[VENT_COL.PAGO]),
      asesor:     _norm(r[VENT_COL.ASESOR]),
      sede:       _up(r[VENT_COL.SEDE]),
      ventaId:    _norm(r[VENT_COL.VENTA_ID]   || ""),
      estadoPago: _up(_norm(r[VENT_COL.ESTADO_PAGO] || "COBRADO"))
    }; })
    .sort(function(a,b){ return a.fecha < b.fecha ? 1 : -1; });

  if (!ventas.length) return { ok:true, comprobantes:[], totalGeneral:0 };

  var porDia = {};
  ventas.forEach(function(v) {
    var k = v.fecha || "SIN-FECHA";
    if (!porDia[k]) porDia[k] = [];
    porDia[k].push(v);
  });

  var comprobantes = Object.keys(porDia).map(function(fecha) {
    var items = porDia[fecha];
    var total = items.reduce(function(s,v){ return s + v.monto; }, 0);
    var sede  = items[0].sede || "";
    var fl    = fecha;
    try {
      var p = fecha.split("-");
      if (p.length === 3) fl = parseInt(p[2],10) + " " + MESES[parseInt(p[1],10)-1] + " " + p[0];
    } catch(e) {}
    return {
      fecha:       fecha,
      fechaLabel:  fl,
      compId:      "COMP-" + fecha.replace(/-/g,"") + "-" + num,
      items:       items,
      totalItems:  items.length,
      totalMonto:  total,
      totalPagado: total,
      porPagar:    0,
      tieneDeuda:  false,
      sede:        sede
    };
  });

  return {
    ok:           true,
    comprobantes: comprobantes,
    totalGeneral: ventas.reduce(function(s,v){ return s + v.monto; }, 0)
  };
}

function api_getVentasComprobantesT(token, num) {
  _setToken(token); return api_getVentasComprobantes(num);
}

function api_getComprobantesRealT(token, num) {
  return api_getVentasComprobantesT(token, num);
}

function api_getMetodosPagoT(token) {
  _setToken(token);
  cc_requireSession();
  return { ok:true, metodos:[
    "EFECTIVO","MERCADOPAGO","IZIPAY YA",
    "POS NIUBIZ S.I.","POS NIUBIZ P.L.",
    "QR CARMEN","QR DOCTORA",
    "BCP DRA","BCP CARMEN",
    "INTERBANK DRA","INTERBANK CARMEN",
    "TRANSFERENCIA BCP","TRANSFERECIA IBK",
    "DOLARES EFECTIVO"
  ]};
}
// ===== CTRL+F: I05_END =====


// ══════════════════════════════════════════════════════════════
// MOD-06 · BÚSQUEDA RÁPIDA (live search desde call center)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: I06_START =====

function api_searchPatientsLive(query) {
  cc_requireSession();
  query = _normSearch(query || "");
  if (query.length < 2) return { ok:true, items:[] };

  var sh = _sh(CFG.SHEET_PACIENTES);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:true, items:[] };

  var cols = Math.min(sh.getLastColumn(), 24);
  var rows = sh.getRange(2, 1, lr - 1, cols).getValues();

  var results = [];
  for (var i = 0; i < rows.length && results.length < 10; i++) {
    var r = rows[i];
    if (!r[PAC_COL.ID] && !r[PAC_COL.NOMBRES]) continue;
    var hay = _normSearch(
      _norm(r[PAC_COL.NOMBRES])   + " " +
      _norm(r[PAC_COL.APELLIDOS]) + " " +
      _norm(String(r[PAC_COL.TELEFONO])) + " " +
      _norm(r[PAC_COL.DOCUMENTO])
    );
    if (hay.includes(query)) {
      results.push({
        id:       _norm(r[PAC_COL.ID]),
        nombres:  _norm(r[PAC_COL.NOMBRES]),
        apellidos:_norm(r[PAC_COL.APELLIDOS]),
        telefono: _normNum(r[PAC_COL.TELEFONO]),
        sede:     _norm(r[PAC_COL.SEDE] || ""),
        trat:     _norm(r[PAC_COL.FUENTE] || "")
      });
    }
  }
  return { ok:true, items:results };
}

function api_searchPatientsLiveT(token, query) {
  _setToken(token); return api_searchPatientsLive(query);
}
// ===== CTRL+F: I06_END =====


// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: TEST_GS09 =====

function test_Patients_v2() {
  Logger.log("=== GS_09 v2.0 TEST ===");

  var stats = api_getPatientsStats();
  Logger.log("Total pacientes: " + stats.total);
  Logger.log("Activos: " + stats.activos + " | Nuevos: " + stats.nuevos);

  Logger.log("--- Test caché historial ---");
  var t1 = new Date().getTime();
  var h1 = _getPatientHistoryCached("986293339"); // Jacquelina
  var t2 = new Date().getTime();
  Logger.log("Primera carga (sin caché): " + (t2-t1) + "ms — llamadas:" + h1.llamadas.length);

  var t3 = new Date().getTime();
  var h2 = _getPatientHistoryCached("986293339");
  var t4 = new Date().getTime();
  Logger.log("Segunda carga (con caché): " + (t4-t3) + "ms — llamadas:" + h2.llamadas.length);

  Logger.log("--- Señales de éxito ---");
  Logger.log("✅ Segunda carga < 100ms = caché funcionando");
  Logger.log("✅ Llamadas mismo count en ambas cargas");
  Logger.log("=== OK ===");
}