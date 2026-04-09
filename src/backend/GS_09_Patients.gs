/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_09_Patients.gs                          ║
 * ║  Módulo: Consolidado de Pacientes                           ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01–08                                     ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Listado y búsqueda de pacientes
 *   MOD-02 · Perfil completo del paciente
 *   MOD-03 · Historial de llamadas, ventas y citas del paciente
 *   MOD-04 · Crear y actualizar pacientes
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · LISTADO Y BÚSQUEDA
// ══════════════════════════════════════════════════════════════
// I01_START

/**
 * api_listPatients — Lista paginada de pacientes con búsqueda
 * @param {string} query  Busca en nombre, teléfono, DNI, ID
 * @param {number} page   Página (base 1)
 * @param {number} limit  Items por página (default 50)
 */
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

  // Filtrar
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

  var items = slice.map(function(r) {
    return _mapPaciente(r);
  });

  return { ok:true, items:items, total:total, page:page, pages:pages };
}

/**
 * Mapea una fila cruda a objeto paciente
 */
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

/** Wrappers token */
function api_listPatientsT(token, query, page, limit) {
  _setToken(token); return api_listPatients(query, page, limit);
}
// I01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · PERFIL COMPLETO DEL PACIENTE
// ══════════════════════════════════════════════════════════════
// I02_START

/**
 * api_getPatientProfile — Perfil completo + historial
 * Busca por ID de paciente (P-XXXX) o por número de teléfono
 * @param {string} idOrNum  ID tipo "P-0001" o número "987654321"
 */
function api_getPatientProfile(idOrNum) {
  cc_requireSession();
  idOrNum = _norm(idOrNum);
  if (!idOrNum) throw new Error("ID o número requerido.");

  var sh  = _sh(CFG.SHEET_PACIENTES);
  var lr  = sh.getLastRow();
  var pac = null;

  if (lr >= 2) {
    var rows = sh.getRange(2, 1, lr - 1, 20).getValues();
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      if (_norm(r[PAC_COL.ID]) === idOrNum ||
          _normNum(r[PAC_COL.TELEFONO]) === _normNum(idOrNum)) {
        pac = _mapPaciente(r);
        break;
      }
    }
  }

  if (!pac) {
    // Crear perfil mínimo desde llamadas/ventas si no existe en PACIENTES
    pac = _buildProfileFromHistory(idOrNum);
  }

  if (!pac) throw new Error("Paciente no encontrado: " + idOrNum);

  // Historial
  var historial = _getPatientHistory(pac.telefono || idOrNum);

  return {
    ok:       true,
    paciente: pac,
    historial:historial
  };
}

/**
 * Construye un perfil básico desde el historial de llamadas/ventas
 */
function _buildProfileFromHistory(num) {
  var limpio = _normNum(num);
  if (!limpio) return null;

  // Buscar en ventas
  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  if (lrV >= 2) {
    var rows = shV.getRange(2, 1, lrV - 1, 19).getValues();
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      var n = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR] || "");
      if (n === limpio) {
        return {
          id:       "P-SIN",
          nombres:  _norm(r[VENT_COL.NOMBRES]),
          apellidos:_norm(r[VENT_COL.APELLIDOS]),
          telefono: limpio,
          documento:_norm(r[VENT_COL.DNI]),
          email:"", sexo:"", fechaNac:"", sede:"", fuente:"",
          fechaReg:"", totalCompras:0, totalFact:0, ultVisita:"",
          totalLlam:0, totalCitas:0, estado:"ACTIVO", notas:"",
          wa: _wa(limpio)
        };
      }
    }
  }
  return null;
}

/**
 * Obtiene el historial completo de un paciente
 */
function _getPatientHistory(num) {
  var limpio = _normNum(num);
  if (!limpio) return { llamadas:[], ventas:[], citas:[] };

  // Llamadas
  var llamadas = [];
  try {
    var shL = _sh(CFG.SHEET_LLAMADAS);
    var lrL = shL.getLastRow();
    if (lrL >= 2) {
      llamadas = shL.getRange(2, 1, lrL - 1, 20).getValues()
        .filter(function(r) {
          return _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]) === limpio;
        })
        .map(function(r) {
          return {
            fecha:    _date(r[LLAM_COL.FECHA]),
            hora:     _time(r[LLAM_COL.HORA]),
            estado:   _up(r[LLAM_COL.ESTADO]),
            trat:     _up(r[LLAM_COL.TRATAMIENTO]),
            asesor:   _norm(r[LLAM_COL.ASESOR]),
            obs:      _norm(r[LLAM_COL.OBS]),
            intento:  Number(r[LLAM_COL.INTENTO]) || 1
          };
        })
        .sort(function(a,b) { return a.fecha < b.fecha ? 1 : -1; })
        .slice(0, 30);
    }
  } catch(e) {}

  // Ventas
  var ventas = [];
  try {
    var shV = _sh(CFG.SHEET_VENTAS);
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      ventas = shV.getRange(2, 1, lrV - 1, 19).getValues()
        .filter(function(r) {
          return _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]) === limpio;
        })
        .map(function(r) {
          return {
            fecha:  _date(r[VENT_COL.FECHA]),
            trat:   _norm(r[VENT_COL.TRATAMIENTO]),
            monto:  Number(r[VENT_COL.MONTO]) || 0,
            tipo:   _up(r[VENT_COL.TIPO]),
            asesor: _norm(r[VENT_COL.ASESOR]),
            sede:   _up(r[VENT_COL.SEDE]),
            pago:   _norm(r[VENT_COL.PAGO])
          };
        })
        .sort(function(a,b) { return a.fecha < b.fecha ? 1 : -1; });
    }
  } catch(e) {}

  // Citas
  var citas = [];
  try {
    var shA = _shAgenda();
    var lrA = shA.getLastRow();
    if (lrA >= 2) {
      citas = shA.getRange(2, 1, lrA - 1, 22).getValues()
        .filter(function(r) {
          return _normNum(r[AG_COL.NUMERO]) === limpio;
        })
        .map(function(r) {
          return {
            fecha:     _date(r[AG_COL.FECHA]),
            hora:      _normHora(r[AG_COL.HORA_CITA]),
            trat:      _norm(r[AG_COL.TRATAMIENTO]),
            tipoCita:  _norm(r[AG_COL.TIPO_CITA]),
            estado:    _norm(r[AG_COL.ESTADO]),
            sede:      _norm(r[AG_COL.SEDE]),
            asesor:    _norm(r[AG_COL.ASESOR]),
            doctora:   _norm(r[AG_COL.DOCTORA])
          };
        })
        .sort(function(a,b) { return a.fecha < b.fecha ? 1 : -1; });
    }
  } catch(e) {}

  var totalFact = ventas.reduce(function(s,v) { return s + v.monto; }, 0);

  return {
    llamadas:   llamadas,
    ventas:     ventas,
    citas:      citas,
    totalFact:  totalFact,
    totalLlam:  llamadas.length,
    totalVentas:ventas.length,
    totalCitas: citas.length
  };
}

/** Wrappers token perfil */
function api_getPatientProfileT(token, idOrNum) {
  _setToken(token); return api_getPatientProfile(idOrNum);
}
// I02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · ESTADÍSTICAS DE PACIENTES
// ══════════════════════════════════════════════════════════════
// I03_START

/**
 * api_getPatientsStats — KPIs del panel de pacientes
 */
function api_getPatientsStats() {
  cc_requireSession();

  var sh = _sh(CFG.SHEET_PACIENTES);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:true, total:0, activos:0, inactivos:0, nuevos:0 };

  var rows = sh.getRange(2, 1, lr - 1, 19).getValues()
    .filter(function(r) { return r[PAC_COL.ID] || r[PAC_COL.NOMBRES]; });

  var total    = rows.length;
  var activos  = rows.filter(function(r) { return _up(r[PAC_COL.ESTADO]) === "ACTIVO"; }).length;
  var inactivos= rows.filter(function(r) { return _up(r[PAC_COL.ESTADO]) === "INACTIVO"; }).length;
  var nuevos   = rows.filter(function(r) { return _up(r[PAC_COL.ESTADO]) === "NUEVO" || !_norm(r[PAC_COL.ESTADO]); }).length;

  return { ok:true, total:total, activos:activos, inactivos:inactivos, nuevos:nuevos };
}

/** Wrapper token stats */
function api_getPatientsStatsT(token) {
  _setToken(token); return api_getPatientsStats();
}
// I03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · CREAR Y ACTUALIZAR PACIENTES
// ══════════════════════════════════════════════════════════════
// I04_START

/**
 * api_updatePatientNotes — Actualiza las notas de un paciente
 */
function api_updatePatientNotes(idOrNum, notas) {
  cc_requireSession();
  idOrNum = _norm(idOrNum);
  notas   = _norm(notas);

  var sh = _sh(CFG.SHEET_PACIENTES);
  var lr = sh.getLastRow();
  if (lr < 2) throw new Error("Sin pacientes registrados.");

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

/** Wrapper token notas */
function api_updatePatientNotesT(token, idOrNum, notas) {
  _setToken(token); return api_updatePatientNotes(idOrNum, notas);
}
// I04_END

/**
 * TEST
 */
function test_Patients() {
  Logger.log("=== GS_09_Patients TEST ===");
  var stats = api_getPatientsStats();
  Logger.log("Stats: " + JSON.stringify(stats));
  Logger.log("=== OK ===");
}
function api_getPatient360T(token, num) {
  _setToken(token);
  cc_requireSession();
  num = _normNum(num);
  // Buscar en PACIENTES
  // Cruzar con VENTAS, AGENDA_CITAS, LLAMADAS por NUM_LIMPIO
  // Retornar { ok, paciente, compras[], citas[], llamadas[], 
  //            totalFact, totalCompras, totalCitas, totalContactos }
}