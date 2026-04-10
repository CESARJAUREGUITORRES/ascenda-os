/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_09_Pacientes.gs                         ║
 * ║  VERSIÓN RESTAURADA DESDE GITHUB — ESTADO ESTABLE          ║
 * ║  Versión: 1.0.0 (base) + api_getPatient360T para Bloque 3  ║
 * ╚══════════════════════════════════════════════════════════════╝
 * INSTRUCCIÓN:
 *   Reemplaza TODO el contenido de GS_09_Pacientes.gs con esto.
 *   Ctrl+A → Borrar → Pegar → Ctrl+S → Desplegar nueva versión.
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · LISTADO Y BÚSQUEDA
// ══════════════════════════════════════════════════════════════
// I01_START

function api_listPatients(query, page, limit) {
  cc_requireSession();
  query = _normSearch(query || "");
  page  = Math.max(1, Number(page)  || 1);
  limit = Math.min(200, Number(limit) || 50);

  var sh = _sh(CFG.SHEET_PACIENTES);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:true, items:[], total:0, page:1, pages:1 };

  var cols = Math.min(sh.getLastColumn(), 20);
  var rows = sh.getRange(2, 1, lr - 1, cols).getValues();

  var filtered = rows.filter(function(r) {
    if (!r[PAC_COL.ID] && !r[PAC_COL.NOMBRES]) return false;
    if (!query) return true;
    var haystack = _normSearch(
      _norm(r[PAC_COL.ID]) + " " +
      _norm(r[PAC_COL.NOMBRES]) + " " +
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
    email:       _norm(r[PAC_COL.EMAIL] || ""),
    documento:   _norm(r[PAC_COL.DOCUMENTO] || ""),
    sexo:        _norm(r[PAC_COL.SEXO] || ""),
    fechaNac:    _date(r[PAC_COL.FECHA_NAC] || ""),
    sede:        _norm(r[PAC_COL.SEDE] || ""),
    fuente:      _norm(r[PAC_COL.FUENTE] || ""),
    fechaReg:    _date(r[PAC_COL.FECHA_REG] || ""),
    totalCompras:Number(r[PAC_COL.TOTAL_COMPRAS] || 0),
    totalFact:   Number(r[PAC_COL.TOTAL_FACTURADO] || 0),
    ultVisita:   _date(r[PAC_COL.ULTIMA_VISITA] || ""),
    totalLlam:   Number(r[PAC_COL.TOTAL_LLAMADAS] || 0),
    totalCitas:  Number(r[PAC_COL.TOTAL_CITAS] || 0),
    estado:      _up(r[PAC_COL.ESTADO] || "NUEVO"),
    notas:       _norm(r[PAC_COL.NOTAS] || ""),
    wa:          _wa(_normNum(r[PAC_COL.TELEFONO]))
  };
}

function api_listPatientsT(token, query, page, limit) {
  _setToken(token); return api_listPatients(query, page, limit);
}
// I01_END


// ══════════════════════════════════════════════════════════════
// MOD-02 · PERFIL COMPLETO DEL PACIENTE
// ══════════════════════════════════════════════════════════════
// I02_START

function api_getPatientProfile(idOrNum) {
  cc_requireSession();
  idOrNum = _norm(idOrNum);
  if (!idOrNum) throw new Error("ID o número requerido.");

  var sh  = _sh(CFG.SHEET_PACIENTES);
  var lr  = sh.getLastRow();
  var pac = null;
  var pacRow = null;

  if (lr >= 2) {
    var rows = sh.getRange(2, 1, lr - 1, 20).getValues();
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

  pac.rowNum = pacRow;
  var historial = _getPatientHistory(pac.telefono || idOrNum);
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
          email:"", sexo:"", fechaNac:"", sede:"", fuente:"", fechaReg:"",
          totalCompras:0, totalFact:0, ultVisita:"", totalLlam:0, totalCitas:0,
          estado:"ACTIVO", notas:"", wa:_wa(limpio)
        };
      }
    }
  }
  return null;
}

function _getPatientHistory(num) {
  var limpio = _normNum(num);
  if (!limpio) return { llamadas:[], ventas:[], citas:[], totalFact:0, totalLlam:0, totalVentas:0, totalCitas:0 };

  var llamadas = [];
  try {
    var shL = _sh(CFG.SHEET_LLAMADAS);
    var lrL = shL.getLastRow();
    if (lrL >= 2) {
      llamadas = shL.getRange(2, 1, lrL - 1, 20).getValues()
        .filter(function(r){ return _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]) === limpio; })
        .map(function(r){ return { fecha:_date(r[LLAM_COL.FECHA]), hora:_time(r[LLAM_COL.HORA]), estado:_up(r[LLAM_COL.ESTADO]), trat:_up(r[LLAM_COL.TRATAMIENTO]), asesor:_norm(r[LLAM_COL.ASESOR]), obs:_norm(r[LLAM_COL.OBS]), intento:Number(r[LLAM_COL.INTENTO])||1 }; })
        .sort(function(a,b){ return a.fecha < b.fecha ? 1 : -1; }).slice(0, 30);
    }
  } catch(e) {}

  var ventas = [];
  try {
    var shV = _sh(CFG.SHEET_VENTAS);
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      ventas = shV.getRange(2, 1, lrV - 1, 19).getValues()
        .filter(function(r){ return _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]) === limpio; })
        .map(function(r){ return { fecha:_date(r[VENT_COL.FECHA]), trat:_norm(r[VENT_COL.TRATAMIENTO]), monto:Number(r[VENT_COL.MONTO])||0, tipo:_up(r[VENT_COL.TIPO]), asesor:_norm(r[VENT_COL.ASESOR]), sede:_up(r[VENT_COL.SEDE]), pago:_norm(r[VENT_COL.PAGO]), ventaId:_norm(r[VENT_COL.VENTA_ID]||""), estadoPago:_up(r[VENT_COL.ESTADO_PAGO]||"") }; })
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
        .map(function(r){ return { citaId:_norm(r[AG_COL.ID]), fecha:_date(r[AG_COL.FECHA]), hora:_normHora(r[AG_COL.HORA_CITA]), trat:_norm(r[AG_COL.TRATAMIENTO]), tipoCita:_norm(r[AG_COL.TIPO_CITA]), estado:_norm(r[AG_COL.ESTADO]), sede:_norm(r[AG_COL.SEDE]), asesor:_norm(r[AG_COL.ASESOR]), doctora:_norm(r[AG_COL.DOCTORA]), obs:_norm(r[AG_COL.OBS]||"") }; })
        .sort(function(a,b){ return a.fecha < b.fecha ? 1 : -1; });
    }
  } catch(e) {}

  var totalFact = ventas.reduce(function(s,v){ return s + v.monto; }, 0);
  return { llamadas:llamadas, ventas:ventas, citas:citas, totalFact:totalFact, totalLlam:llamadas.length, totalVentas:ventas.length, totalCitas:citas.length };
}

function api_getPatientProfileT(token, idOrNum) {
  _setToken(token); return api_getPatientProfile(idOrNum);
}

// ===== api_getPatient360T — UNA SOLA DEFINICIÓN =====
// Usada por ViewAdminPatients para cargar el panel 360
function api_getPatient360T(token, numOrId) {
  _setToken(token);
  cc_requireSession();
  var res = api_getPatientProfile(numOrId);
  if (!res || !res.ok) return { ok:false, msg:"Paciente no encontrado: " + numOrId };
  var p = res.paciente;
  if (p.ultVisita) {
    var hoy = new Date(); hoy.setHours(0,0,0,0);
    var uv  = new Date(p.ultVisita); uv.setHours(0,0,0,0);
    p.diasUltVisita = Math.floor((hoy - uv) / (1000*60*60*24));
  } else {
    p.diasUltVisita = null;
  }
  if (p.estado) {
    p.estado = p.estado.toUpperCase()
      .replace(/Ó/g,"O").replace(/É/g,"E").replace(/Á/g,"A").replace(/Í/g,"I").replace(/Ú/g,"U");
  }
  var h = res.historial || {};
  if (h.citas) h.citas = h.citas.map(function(c){ c.estado = c.estado.toUpperCase().replace(/Ó/g,"O").replace(/É/g,"E").replace(/Á/g,"A").replace(/Í/g,"I").replace(/Ú/g,"U"); return c; });
  return { ok:true, paciente:p, historial:h };
}
// I02_END


// ══════════════════════════════════════════════════════════════
// MOD-03 · ESTADÍSTICAS
// ══════════════════════════════════════════════════════════════
// I03_START

function api_getPatientsStats() {
  cc_requireSession();
  var sh = _sh(CFG.SHEET_PACIENTES);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:true, total:0, activos:0, inactivos:0, nuevos:0 };
  var rows = sh.getRange(2, 1, lr - 1, 19).getValues().filter(function(r){ return r[PAC_COL.ID] || r[PAC_COL.NOMBRES]; });
  return {
    ok:true,
    total:    rows.length,
    activos:  rows.filter(function(r){ return _up(r[PAC_COL.ESTADO]) === "ACTIVO"; }).length,
    inactivos:rows.filter(function(r){ return _up(r[PAC_COL.ESTADO]) === "INACTIVO"; }).length,
    nuevos:   rows.filter(function(r){ return _up(r[PAC_COL.ESTADO]) === "NUEVO" || !_norm(r[PAC_COL.ESTADO]); }).length
  };
}

function api_getPatientsStatsT(token) {
  _setToken(token); return api_getPatientsStats();
}
// I03_END


// ══════════════════════════════════════════════════════════════
// MOD-04 · ACTUALIZAR PACIENTES
// ══════════════════════════════════════════════════════════════
// I04_START

function api_updatePatientNotes(idOrNum, notas) {
  cc_requireSession();
  idOrNum = _norm(idOrNum); notas = _norm(notas);
  var sh = _sh(CFG.SHEET_PACIENTES); var lr = sh.getLastRow();
  if (lr < 2) throw new Error("Sin pacientes.");
  var rows = sh.getRange(2, 1, lr - 1, 20).getValues();
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i];
    if (_norm(r[PAC_COL.ID]) === idOrNum || _normNum(r[PAC_COL.TELEFONO]) === _normNum(idOrNum)) {
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
  idOrNum = _norm(idOrNum); payload = payload || {};
  if (!idOrNum) throw new Error("ID o número requerido.");
  var sh = _sh(CFG.SHEET_PACIENTES); var lr = sh.getLastRow(); var rowF = null;
  if (lr < 2) throw new Error("Sin pacientes.");
  var rows = sh.getRange(2, 1, lr - 1, 24).getValues();
  for (var i = 0; i < rows.length; i++) {
    if (_norm(rows[i][PAC_COL.ID]) === idOrNum || _normNum(rows[i][PAC_COL.TELEFONO]) === _normNum(idOrNum)) { rowF = i+2; break; }
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
  if (!cambios.length) return { ok:true, msg:"Sin cambios." };
  cambios.forEach(function(c){ sh.getRange(rowF, c.col).setValue(c.val); });
  return { ok:true, msg:"Paciente actualizado.", fila:rowF, cambios:cambios.length };
}
// I04_END


// ══════════════════════════════════════════════════════════════
// MOD-05 · COMPROBANTES (para tab Comprobantes del panel 360)
// ══════════════════════════════════════════════════════════════

function api_getVentasComprobantes(num) {
  cc_requireSession();
  num = _normNum(num);
  if (!num) return { ok:true, comprobantes:[], totalGeneral:0 };
  var shV = _sh(CFG.SHEET_VENTAS); var lrV = shV.getLastRow();
  if (lrV < 2) return { ok:true, comprobantes:[], totalGeneral:0 };
  var ventas = shV.getRange(2, 1, lrV - 1, 19).getValues()
    .filter(function(r){ return _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]) === num; })
    .map(function(r){ return { fecha:_date(r[VENT_COL.FECHA]), trat:_norm(r[VENT_COL.TRATAMIENTO]), monto:Number(r[VENT_COL.MONTO])||0, pago:_norm(r[VENT_COL.PAGO]), asesor:_norm(r[VENT_COL.ASESOR]), sede:_up(r[VENT_COL.SEDE]), ventaId:_norm(r[VENT_COL.VENTA_ID]||""), estadoPago:_up(_norm(r[VENT_COL.ESTADO_PAGO]||"COBRADO")) }; })
    .sort(function(a,b){ return a.fecha < b.fecha ? 1:-1; });
  if (!ventas.length) return { ok:true, comprobantes:[], totalGeneral:0 };
  var porDia = {}, MESES = ["ENE","FEB","MAR","ABR","MAY","JUN","JUL","AGO","SEP","OCT","NOV","DIC"];
  ventas.forEach(function(v){ var k=v.fecha||"SIN-FECHA"; if(!porDia[k])porDia[k]=[]; porDia[k].push(v); });
  var comprobantes = Object.keys(porDia).map(function(fecha){
    var items=porDia[fecha], total=items.reduce(function(s,v){return s+v.monto;},0), sede=items[0].sede||"";
    var fl=fecha; try{var p=fecha.split("-");if(p.length===3)fl=parseInt(p[2],10)+" "+MESES[parseInt(p[1],10)-1]+" "+p[0];}catch(e){}
    return { fecha:fecha, fechaLabel:fl, compId:"COMP-"+fecha.replace(/-/g,"")+"-"+num, items:items, totalItems:items.length, totalMonto:total, totalPagado:total, porPagar:0, tieneDeuda:false, sede:sede };
  });
  return { ok:true, comprobantes:comprobantes, totalGeneral:ventas.reduce(function(s,v){return s+v.monto;},0) };
}

function api_getVentasComprobantesT(token, num) {
  _setToken(token); return api_getVentasComprobantes(num);
}

function api_getComprobantesRealT(token, num) {
  return api_getVentasComprobantesT(token, num);
}

function api_getMetodosPagoT(token) {
  _setToken(token); cc_requireSession();
  return { ok:true, metodos:["EFECTIVO","MERCADOPAGO","IZIPAY YA","POS NIUBIZ S.I.","POS NIUBIZ P.L.","QR CARMEN","QR DOCTORA","BCP DRA","BCP CARMEN","INTERBANK DRA","INTERBANK CARMEN","TRANSFERENCIA BCP","TRANSFERECIA IBK","DOLARES EFECTIVO"] };
}

// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════
function test_Patients() {
  Logger.log("=== GS_09 TEST ===");
  var stats = api_getPatientsStats();
  Logger.log("Total pacientes: " + stats.total);
  Logger.log("=== OK ===");
}