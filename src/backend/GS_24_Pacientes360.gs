/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_24_Pacientes360.gs                      ║
 * ║  Módulo: Pacientes 360° — Historia Clínica, Notas,          ║
 * ║          Seguimientos Programados, Timeline, Fusión         ║
 * ║  Autor: César Jáuregui / CREACTIVE OS                      ║
 * ║  Versión: 2.1.0                                             ║
 * ║  Dependencias: GS_01, GS_02, GS_03, GS_04, GS_09          ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CAMBIOS v2.1.0 vs v2.0.0:
 *   FIX-05 · Eliminada api_getPatient360() y su wrapper api_getPatient360T()
 *            de este archivo. La versión definitiva con CacheService vive
 *            en GS_09_Pacientes.gs (PERF-03). Tener dos definiciones del
 *            mismo nombre causaba conflicto de función y login colgado.
 *   MERGE  · api_updateNotaPaciente360 y api_deleteNotaPaciente360 integradas
 *            directamente en MOD-02 (antes estaban como patch al final).
 *
 * CONTENIDO:
 *   MOD-01 · Historia Clínica (MINSA estética)
 *   MOD-02 · Notas multi-rol del equipo (+ editar y eliminar)
 *   MOD-03 · Seguimientos programados por tratamiento
 *   MOD-04 · Timeline unificado del paciente
 *   MOD-05 · Crear cita desde panel 360
 *   MOD-06 · Score y alertas del paciente
 *   MOD-07 · Fusión de pacientes
 *   MOD-08 · Helpers internos de GS_24
 *   MOD-09 · Wrappers token
 *   MOD-10 · Tests
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · HISTORIA CLÍNICA
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: HC_START =====

var HC_COL = {
  DNI:0,NOMBRES:1,APELLIDOS:2,TELEFONO:3,EMAIL:4,FECHA_NAC:5,SEXO:6,
  ESTADO_CIVIL:7,GRADO_INSTRUCCION:8,OCUPACION:9,DISTRITO:10,DIRECCION:11,
  CONTACTO_EMERG_NOMBRE:12,CONTACTO_EMERG_TEL:13,ALERGIAS_MEDICAMENTOS:14,
  ALERGIAS_MATERIALES:15,ENFERMEDADES_CRONICAS:16,MEDICAMENTOS_ACTUALES:17,
  SUPLEMENTOS_VITAMINAS:18,VACUNAS_RECIENTES:19,CIRUGIAS_PREVIAS:20,
  TRAT_ESTETICOS_PREVIOS:21,QUELOIDES:22,IMPLANTES:23,MARCAPASOS:24,
  EMBARAZO:25,LACTANCIA:26,ANTICONCEPTIVOS:27,FECHA_ULT_MENSTRUACION:28,
  FECHA_ULT_PAPANICOLAU:29,TABACO:30,ALCOHOL:31,ACTIVIDAD_FISICA:32,
  HORAS_SUENO:33,CONSENTIMIENTO_FIRMADO:34,FECHA_REGISTRO_HC:35,
  MEDICO_RESPONSABLE:36,TS_CREADO:37,TS_ACTUALIZADO:38
};
var HC_TOTAL_COLS = 39;

/**
 * api_saveHistoriaClinica
 * Crea o actualiza la historia clínica. Clave primaria: DNI.
 * Acceso: ADMIN, DOCTOR, ADMINISTRADOR
 */
function api_saveHistoriaClinica(payload) {
  var s = cc_requireSession();
  if (s.rol !== "ADMIN" && s.rol !== "DOCTOR" && s.rol !== "ADMINISTRADOR")
    throw new Error("Acceso denegado. Solo ADMIN o DOCTOR.");

  payload = payload || {};
  var dni = _norm(payload.dni);
  if (!dni) throw new Error("DNI requerido para historia clínica.");

  var sh  = _sh("HISTORIA_CLINICA");
  var lr  = sh.getLastRow();
  var now = new Date();
  var rowExistente = null;

  if (lr >= 2) {
    var dnis = sh.getRange(2, 1, lr - 1, 1).getValues();
    for (var i = 0; i < dnis.length; i++) {
      if (_norm(dnis[i][0]) === dni) { rowExistente = i + 2; break; }
    }
  }

  var fila = [
    dni,
    _norm(payload.nombres   || "").toUpperCase(),
    _norm(payload.apellidos || "").toUpperCase(),
    _normNum(payload.telefono  || ""),
    _norm(payload.email        || ""),
    _norm(payload.fechaNac     || ""),
    _up(payload.sexo           || ""),
    _norm(payload.estadoCivil  || ""),
    _norm(payload.gradoInst    || ""),
    _norm(payload.ocupacion    || ""),
    _norm(payload.distrito     || ""),
    _norm(payload.direccion    || ""),
    _norm(payload.contactoEmergNombre || ""),
    _norm(payload.contactoEmergTel    || ""),
    _norm(payload.alergiasMedicamentos  || ""),
    _norm(payload.alergiasMateria       || ""),
    _norm(payload.enfermedadesCron      || ""),
    _norm(payload.medicamentosActuales  || ""),
    _norm(payload.suplementos           || ""),
    _norm(payload.vacunas               || ""),
    _norm(payload.cirugiasPrevias       || ""),
    _norm(payload.tratEsteticos         || ""),
    _norm(payload.queloides             || ""),
    _norm(payload.implantes             || ""),
    _norm(payload.marcapasos            || ""),
    _norm(payload.embarazo              || ""),
    _norm(payload.lactancia             || ""),
    _norm(payload.anticonceptivos       || ""),
    _norm(payload.fechaUltMenstruacion  || ""),
    _norm(payload.fechaUltPapanicolau   || ""),
    _norm(payload.tabaco                || ""),
    _norm(payload.alcohol               || ""),
    _norm(payload.actividadFisica       || ""),
    _norm(payload.horasSueno            || ""),
    _norm(payload.consentimientoFirmado || "NO"),
    _date(now),
    _norm(payload.medicoResponsable || s.asesor || ""),
    rowExistente ? sh.getRange(rowExistente, HC_COL.TS_CREADO + 1).getValue() : now,
    now
  ];

  if (rowExistente) {
    sh.getRange(rowExistente, 1, 1, fila.length).setValues([fila]);
    return { ok: true, accion: "actualizado", dni: dni };
  }

  sh.appendRow(fila);
  return { ok: true, accion: "creado", dni: dni };
}

/**
 * api_getHistoriaClinica
 * Obtiene la historia clínica por DNI o teléfono.
 */
function api_getHistoriaClinica(dniOrTel) {
  cc_requireSession();
  var busq = _norm(dniOrTel);
  if (!busq) return { ok: true, hc: null };

  var sh = _sh("HISTORIA_CLINICA");
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, hc: null };

  var data = sh.getRange(2, 1, lr - 1, HC_TOTAL_COLS).getValues();
  var fila = null;

  for (var i = 0; i < data.length; i++) {
    var r = data[i];
    if (_norm(r[HC_COL.DNI]) === busq ||
        _normNum(r[HC_COL.TELEFONO]) === _normNum(busq)) {
      fila = r; break;
    }
  }

  if (!fila) return { ok: true, hc: null };

  return {
    ok: true,
    hc: {
      dni:                   _norm(fila[HC_COL.DNI]),
      nombres:               _norm(fila[HC_COL.NOMBRES]),
      apellidos:             _norm(fila[HC_COL.APELLIDOS]),
      telefono:              _norm(fila[HC_COL.TELEFONO]),
      email:                 _norm(fila[HC_COL.EMAIL]),
      fechaNac:              _date(fila[HC_COL.FECHA_NAC]),
      sexo:                  _norm(fila[HC_COL.SEXO]),
      estadoCivil:           _norm(fila[HC_COL.ESTADO_CIVIL]),
      gradoInst:             _norm(fila[HC_COL.GRADO_INSTRUCCION]),
      ocupacion:             _norm(fila[HC_COL.OCUPACION]),
      distrito:              _norm(fila[HC_COL.DISTRITO]),
      direccion:             _norm(fila[HC_COL.DIRECCION]),
      contactoEmergNombre:   _norm(fila[HC_COL.CONTACTO_EMERG_NOMBRE]),
      contactoEmergTel:      _norm(fila[HC_COL.CONTACTO_EMERG_TEL]),
      alergiasMedicamentos:  _norm(fila[HC_COL.ALERGIAS_MEDICAMENTOS]),
      alergiasMateria:       _norm(fila[HC_COL.ALERGIAS_MATERIALES]),
      enfermedadesCron:      _norm(fila[HC_COL.ENFERMEDADES_CRONICAS]),
      medicamentosActuales:  _norm(fila[HC_COL.MEDICAMENTOS_ACTUALES]),
      suplementos:           _norm(fila[HC_COL.SUPLEMENTOS_VITAMINAS]),
      cirugiasPrevias:       _norm(fila[HC_COL.CIRUGIAS_PREVIAS]),
      tratEsteticos:         _norm(fila[HC_COL.TRAT_ESTETICOS_PREVIOS]),
      queloides:             _norm(fila[HC_COL.QUELOIDES]),
      implantes:             _norm(fila[HC_COL.IMPLANTES]),
      marcapasos:            _norm(fila[HC_COL.MARCAPASOS]),
      embarazo:              _norm(fila[HC_COL.EMBARAZO]),
      lactancia:             _norm(fila[HC_COL.LACTANCIA]),
      anticonceptivos:       _norm(fila[HC_COL.ANTICONCEPTIVOS]),
      fechaUltMenstruacion:  _norm(fila[HC_COL.FECHA_ULT_MENSTRUACION]),
      fechaUltPapanicolau:   _norm(fila[HC_COL.FECHA_ULT_PAPANICOLAU]),
      tabaco:                _norm(fila[HC_COL.TABACO]),
      alcohol:               _norm(fila[HC_COL.ALCOHOL]),
      actividadFisica:       _norm(fila[HC_COL.ACTIVIDAD_FISICA]),
      horasSueno:            _norm(fila[HC_COL.HORAS_SUENO]),
      consentimientoFirmado: _norm(fila[HC_COL.CONSENTIMIENTO_FIRMADO]),
      fechaRegistroHc:       _date(fila[HC_COL.FECHA_REGISTRO_HC]),
      medicoResponsable:     _norm(fila[HC_COL.MEDICO_RESPONSABLE]),
      tsActualizado:         _datetime(fila[HC_COL.TS_ACTUALIZADO])
    }
  };
}

function _hc_getAlertas(hc) {
  if (!hc) return [];
  var alertas = [];
  if (_norm(hc.embarazo)            ) alertas.push({ tipo:"CRITICO", msg:"⚠️ EMBARAZO registrado" });
  if (_norm(hc.lactancia)           ) alertas.push({ tipo:"CRITICO", msg:"⚠️ LACTANCIA activa" });
  if (_norm(hc.marcapasos)          ) alertas.push({ tipo:"CRITICO", msg:"⚠️ MARCAPASOS — contraindicación HIFU/RF" });
  if (_norm(hc.alergiasMedicamentos)) alertas.push({ tipo:"ALERTA",  msg:"Alergias: " + hc.alergiasMedicamentos.slice(0,60) });
  if (_norm(hc.implantes)           ) alertas.push({ tipo:"ALERTA",  msg:"Implantes: " + hc.implantes.slice(0,40) });
  if (_norm(hc.queloides)           ) alertas.push({ tipo:"INFO",    msg:"Queloides registrados" });
  return alertas;
}
// ===== CTRL+F: HC_END =====


// ══════════════════════════════════════════════════════════════
// MOD-02 · NOTAS MULTI-ROL (+ editar y eliminar)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: NOTAS_START =====

function api_saveNotaPaciente360(num, texto, tipoNota) {
  var s    = cc_requireSession();
  num      = _normNum(num);
  texto    = _norm(texto);
  tipoNota = _up(_norm(tipoNota || "GENERAL"));

  if (!num || !texto) throw new Error("Número y texto son requeridos.");
  if (texto.length > 2000) throw new Error("Nota máximo 2000 caracteres.");

  var sh  = _sh("NOTAS_PACIENTES");
  var now = new Date();
  sh.appendRow([ _uid(), _date(now), _time(now), num, texto, s.rol || "ASESOR", s.asesor || "", tipoNota, now ]);
  return { ok: true };
}

function api_getNotasPaciente360(num, tipoNota) {
  cc_requireSession();
  num = _normNum(num);
  if (!num) return { ok: true, notas: [] };

  var sh = _sh("NOTAS_PACIENTES");
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, notas: [] };

  var data  = sh.getRange(2, 1, lr - 1, 9).getValues();
  var notas = data
    .filter(function(r) {
      var ok = _normNum(r[3]) === num;
      if (tipoNota) ok = ok && _up(_norm(r[7])) === _up(tipoNota);
      return ok;
    })
    .map(function(r) {
      return { id:_norm(r[0]), fecha:_date(r[1]), hora:_norm(r[2]),
               texto:_norm(r[4]), rol:_norm(r[5]), usuario:_norm(r[6]), tipo:_norm(r[7]) };
    })
    .sort(function(a, b) { return a.fecha < b.fecha ? 1 : -1; });

  return { ok: true, notas: notas };
}

// ===== CTRL+F: api_updateNotaPaciente360 =====
/**
 * api_updateNotaPaciente360
 * Edita el texto de una nota. Acceso: propietario o ADMIN.
 */
function api_updateNotaPaciente360(notaId, nuevoTexto) {
  var s      = cc_requireSession();
  notaId     = _norm(notaId);
  nuevoTexto = _norm(nuevoTexto);
  if (!notaId)                      throw new Error("ID de nota requerido.");
  if (!nuevoTexto)                  throw new Error("Texto no puede estar vacío.");
  if (nuevoTexto.length > 2000)     throw new Error("Nota máximo 2000 caracteres.");

  var sh   = _sh("NOTAS_PACIENTES");
  var lr   = sh.getLastRow();
  if (lr < 2) throw new Error("Sin notas registradas.");

  var data = sh.getRange(2, 1, lr - 1, 9).getValues();
  for (var i = 0; i < data.length; i++) {
    if (_norm(data[i][0]) !== notaId) continue;
    var usuarioNota   = _norm(data[i][6]);
    var esAdmin       = s.rol === "ADMIN" || s.rol === "ADMINISTRADOR";
    var esPropietario = _norm(s.asesor) === usuarioNota || _norm(s.usuario) === usuarioNota;
    if (!esAdmin && !esPropietario) throw new Error("Solo puedes editar tus propias notas.");
    sh.getRange(i + 2, 5).setValue(nuevoTexto);
    var tipoActual = _norm(data[i][7]);
    if (tipoActual && tipoActual.indexOf("(editado)") < 0)
      sh.getRange(i + 2, 8).setValue(tipoActual + " (editado)");
    return { ok: true, msg: "Nota actualizada." };
  }
  throw new Error("Nota no encontrada: " + notaId);
}
// ===== CTRL+F: api_updateNotaPaciente360_END =====

// ===== CTRL+F: api_deleteNotaPaciente360 =====
/**
 * api_deleteNotaPaciente360
 * Elimina físicamente una nota. Acceso: propietario o ADMIN.
 */
function api_deleteNotaPaciente360(notaId) {
  var s  = cc_requireSession();
  notaId = _norm(notaId);
  if (!notaId) throw new Error("ID de nota requerido.");

  var sh = _sh("NOTAS_PACIENTES");
  var lr = sh.getLastRow();
  if (lr < 2) throw new Error("Sin notas registradas.");

  var data = sh.getRange(2, 1, lr - 1, 9).getValues();
  for (var i = 0; i < data.length; i++) {
    if (_norm(data[i][0]) !== notaId) continue;
    var usuarioNota   = _norm(data[i][6]);
    var esAdmin       = s.rol === "ADMIN" || s.rol === "ADMINISTRADOR";
    var esPropietario = _norm(s.asesor) === usuarioNota || _norm(s.usuario) === usuarioNota;
    if (!esAdmin && !esPropietario) throw new Error("Solo puedes eliminar tus propias notas.");
    sh.deleteRow(i + 2);
    return { ok: true, msg: "Nota eliminada." };
  }
  throw new Error("Nota no encontrada: " + notaId);
}
// ===== CTRL+F: api_deleteNotaPaciente360_END =====

// ===== CTRL+F: NOTAS_END =====


// ══════════════════════════════════════════════════════════════
// MOD-03 · SEGUIMIENTOS PROGRAMADOS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SEG_PROG_START =====

var CICLOS_TRATAMIENTO = {
  "TOXINA BOTULINICA":150,"TOXINA":150,"ACIDO HIALURONICO":450,"HIALURONICO":450,
  "HIFU":365,"BIO ESTIMULADOR":180,"BIOESTIMULADOR":180,"CRIOLIPOLISIS":180,
  "ENZIMAS FACIALES":90,"ENZIMAS":90,"HIDROFACIAL":30,"CAPILAR":30,
  "VITAMINAS":30,"DETOX":30,"PQ AGE":120,"DERMAPEN":30
};

function _seg_calcCiclo(tratamiento) {
  var t = _up(_norm(tratamiento || ""));
  for (var key in CICLOS_TRATAMIENTO) { if (t.indexOf(key) >= 0) return CICLOS_TRATAMIENTO[key]; }
  return 90;
}

function api_saveSeguimientoProgramado(payload) {
  cc_requireSession();
  payload = payload || {};
  var num  = _normNum(payload.num || "");
  var trat = _norm(payload.tratamiento || "");
  if (!num || !trat) throw new Error("Número y tratamiento requeridos.");

  var sh  = _sh("SEGUIMIENTOS_PROGRAMADOS");
  var lr  = sh.getLastRow();
  var now = new Date();
  var diasCiclo       = Number(payload.diasCiclo) || _seg_calcCiclo(trat);
  var fechaUltApp     = payload.fechaUltAplicacion ? new Date(payload.fechaUltAplicacion) : now;
  var fechaRecontacto = new Date(fechaUltApp.getTime() + diasCiclo * 24 * 60 * 60 * 1000);
  var rowExistente    = null;

  if (lr >= 2) {
    var data = sh.getRange(2, 1, lr - 1, 7).getValues();
    for (var i = 0; i < data.length; i++) {
      if (_normNum(data[i][1]) === num && _up(_norm(data[i][2])) === _up(trat) &&
          _up(_norm(data[i][6])) === "PENDIENTE") { rowExistente = i + 2; break; }
    }
  }

  var fila = [
    rowExistente ? sh.getRange(rowExistente, 1).getValue() : _uid(),
    num, _up(trat), _date(fechaUltApp), diasCiclo, _date(fechaRecontacto), "PENDIENTE",
    _norm(payload.asesorAsignado || ""), _norm(payload.obs || ""),
    rowExistente ? sh.getRange(rowExistente, 10).getValue() : now, now
  ];

  if (rowExistente) {
    sh.getRange(rowExistente, 1, 1, fila.length).setValues([fila]);
    return { ok: true, accion: "actualizado", fechaRecontacto: _date(fechaRecontacto) };
  }
  sh.appendRow(fila);
  return { ok: true, accion: "creado", fechaRecontacto: _date(fechaRecontacto) };
}

function api_getSeguimientosProgramados(num, filtro) {
  cc_requireSession();
  filtro = _norm(filtro || "todos").toLowerCase();
  var sh   = _sh("SEGUIMIENTOS_PROGRAMADOS");
  var lr   = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [] };
  var data = sh.getRange(2, 1, lr - 1, 11).getValues();
  var hoy  = new Date(); hoy.setHours(0,0,0,0);
  var en7d = new Date(hoy.getTime() + 7 * 24 * 60 * 60 * 1000);

  var items = data
    .filter(function(r) {
      if (_up(_norm(r[6])) !== "PENDIENTE") return false;
      if (num && _normNum(r[1]) !== _normNum(num)) return false;
      return true;
    })
    .map(function(r) {
      var fRec    = r[5] ? (r[5] instanceof Date ? r[5] : new Date(r[5])) : null;
      var vencido = fRec && fRec < hoy;
      return {
        id:_norm(r[0]), num:_normNum(r[1]), tratamiento:_norm(r[2]),
        fechaUltApp:_date(r[3]), diasCiclo:Number(r[4])||0, fechaRecontacto:_date(r[5]),
        estado:_norm(r[6]), asesor:_norm(r[7]), obs:_norm(r[8]),
        vencido:vencido, esHoy:fRec&&fRec.toDateString()===hoy.toDateString(),
        enProximos7d:fRec&&!vencido&&fRec<=en7d,
        diasRestantes:fRec?Math.floor((fRec-hoy)/(1000*60*60*24)):null
      };
    })
    .filter(function(item) {
      if (filtro === "vencidos")    return item.vencido;
      if (filtro === "proximos_7d") return item.enProximos7d || item.esHoy;
      if (filtro === "pendientes")  return !item.vencido;
      return true;
    })
    .sort(function(a, b) {
      if (a.vencido && !b.vencido) return -1;
      if (!a.vencido && b.vencido) return 1;
      return a.fechaRecontacto < b.fechaRecontacto ? -1 : 1;
    });

  return { ok: true, total: items.length, items: items };
}

function api_cerrarSeguimientoProgramado(segId) {
  cc_requireSession();
  segId = _norm(segId);
  if (!segId) throw new Error("ID de seguimiento requerido.");
  var sh = _sh("SEGUIMIENTOS_PROGRAMADOS");
  var lr = sh.getLastRow();
  if (lr < 2) throw new Error("Sin seguimientos.");
  var ids = sh.getRange(2, 1, lr - 1, 1).getValues();
  for (var i = 0; i < ids.length; i++) {
    if (_norm(ids[i][0]) === segId) {
      sh.getRange(i + 2, 7).setValue("CERRADO");
      sh.getRange(i + 2, 11).setValue(new Date());
      return { ok: true };
    }
  }
  throw new Error("Seguimiento no encontrado: " + segId);
}
// ===== CTRL+F: SEG_PROG_END =====


// ══════════════════════════════════════════════════════════════
// MOD-04 · TIMELINE UNIFICADO
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: TIMELINE_START =====

function api_getPatientTimeline(num) {
  cc_requireSession();
  num = _normNum(num);
  if (!num) return { ok: true, eventos: [] };

  var perfil = api_getPatientProfile(num);
  if (!perfil || !perfil.ok) return { ok: true, eventos: [] };

  var h       = perfil.historial || {};
  var eventos = [];

  (h.llamadas || []).forEach(function(l) {
    var en = _g24_normEstado(l.estado);
    eventos.push({ fecha:l.fecha, hora:l.hora, tipo:"LLAMADA", icono:"📞", titulo:en,
      sub:l.trat, detalle:l.obs, actor:l.asesor,
      color: en==="CITA CONFIRMADA"?"#16A34A":en==="SIN CONTACTO"?"#DC2626":"#6B7BA8" });
  });

  (h.ventas || []).forEach(function(v) {
    eventos.push({ fecha:v.fecha, tipo:"COMPRA", icono:"💰", titulo:v.trat,
      sub:"S/ "+(v.monto||0).toFixed(0), detalle:(v.pago||"")+(v.sede?" · "+v.sede:""),
      actor:v.asesor, color:"#0A4FBF" });
  });

  (h.citas || []).forEach(function(c) {
    var en    = _g24_normEstado(c.estado);
    var color = (en==="ASISTIO"||en==="EFECTIVA")?"#16A34A":en==="NO ASISTIO"?"#DC2626":en==="CANCELADA"?"#9AAAC8":"#D97706";
    eventos.push({ fecha:c.fecha, hora:c.hora, tipo:"CITA", icono:"📅", titulo:c.trat,
      sub:en, detalle:(c.sede||"")+(c.doctora?" · "+c.doctora:""), actor:c.asesor, color:color });
  });

  var notasRes = api_getNotasPaciente360(num);
  (notasRes.notas || []).forEach(function(n) {
    eventos.push({ fecha:n.fecha, hora:n.hora, tipo:"NOTA", icono:"📝", titulo:n.tipo,
      sub:n.texto.slice(0,80), detalle:"", actor:n.usuario, color:"#7C3AED" });
  });

  eventos.sort(function(a, b) {
    return ((a.fecha||"")+(a.hora||"")) < ((b.fecha||"")+(b.hora||"")) ? 1 : -1;
  });
  return { ok: true, total: eventos.length, eventos: eventos.slice(0, 100) };
}
// ===== CTRL+F: TIMELINE_END =====


// ══════════════════════════════════════════════════════════════
// MOD-05 · CREAR CITA DESDE PANEL 360
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: CITA360_START =====

function api_createCitaDesde360(payload) {
  var s    = cc_requireSession();
  payload  = payload || {};
  var num  = _normNum(payload.num || "");
  if (!num)                 throw new Error("Número de paciente requerido.");
  if (!payload.fechaCita)   throw new Error("Fecha de cita requerida.");
  if (!payload.tratamiento) throw new Error("Tratamiento requerido.");

  var perfil = null;
  try { var r = api_getPatientProfile(num); if (r&&r.ok&&r.paciente) perfil=r.paciente; } catch(e) {}

  var sh  = _shAgenda();
  var now = new Date();
  var cid = _uid();

  sh.appendRow([
    cid,
    _norm(payload.fechaCita),
    _up(_norm(payload.tratamiento)),
    _norm(payload.tipoCita || "CONSULTA NUEVA"),
    _up(_norm(payload.sede || (perfil ? perfil.sede : ""))),
    num,
    _norm(payload.nombre   || (perfil ? perfil.nombres   : "")),
    _norm(payload.apellido || (perfil ? perfil.apellidos  : "")),
    _norm(payload.dni      || (perfil ? perfil.documento  : "")),
    _norm(payload.correo   || (perfil ? perfil.email      : "")),
    _norm(payload.asesorNombre || s.asesor    || ""),
    _norm(payload.asesorId     || s.idAsesor  || ""),
    "PENDIENTE", "",
    _norm(payload.obs || ""),
    now, now,
    _norm(payload.horaCita || ""), "",
    _norm(payload.doctora || ""),
    _tipoAtencion(_norm(payload.tratamiento)),
    "", "360"
  ]);

  return { ok: true, citaId: cid, msg: "Cita creada desde panel 360." };
}

function api_getEquipoActivo() {
  cc_requireSession();
  var sh = _sh("RRHH");
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [] };
  var data  = sh.getRange(2, 1, lr - 1, 10).getValues();
  var items = data
    .filter(function(r) { var a=_up(_norm(r[7]||"")); return a!=="INACTIVO"&&a!=="RETIRADO"&&_norm(r[1]); })
    .map(function(r)    { return { id:_norm(r[0]), nombre:_norm(r[1]), rol:_up(_norm(r[3]||"ASESOR")), sede:_up(_norm(r[5]||"")) }; });
  return { ok: true, items: items };
}
// ===== CTRL+F: CITA360_END =====


// ══════════════════════════════════════════════════════════════
// MOD-06 · SCORE Y ALERTAS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SCORE360_START =====

function api_getPatientScore360(num) {
  cc_requireSession();
  num = _normNum(num);
  if (!num) throw new Error("Número requerido.");

  var perfilRes = api_getPatientProfile(num);
  if (!perfilRes || !perfilRes.ok) return { ok: false };
  var p = perfilRes.paciente || {};

  var hcRes        = api_getHistoriaClinica(_norm(p.documento || num));
  var alertas      = hcRes.hc ? _hc_getAlertas(hcRes.hc) : [];
  var segRes       = api_getSeguimientosProgramados(num, "vencidos");
  var segsVencidos = segRes.total || 0;

  var score = _norm(p.estado) || "NUEVO";
  var dias  = null;
  if (p.ultVisita) {
    var hoy = new Date(); hoy.setHours(0,0,0,0);
    var uv  = new Date(p.ultVisita); uv.setHours(0,0,0,0);
    dias = Math.floor((hoy - uv) / (1000*60*60*24));
    score = dias <= 90 ? "ACTIVO" : dias <= 180 ? "EN_RIESGO" : "INACTIVO";
  }

  var colorScore = { "ACTIVO":"#16A34A","EN_RIESGO":"#D97706","INACTIVO":"#DC2626","NUEVO":"#6B7BA8" };
  return {
    ok:true, num:num, score:score, colorScore:colorScore[score]||"#6B7BA8",
    diasUltVisita:dias, ultVisita:_date(p.ultVisita),
    totalFact:p.totalFact||0, totalCompras:p.totalCompras||0,
    alertas:alertas, segsVencidos:segsVencidos, tieneHC:!!hcRes.hc
  };
}
// ===== CTRL+F: SCORE360_END =====


// ══════════════════════════════════════════════════════════════
// MOD-07 · FUSIÓN DE PACIENTES
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: FUSION_START =====

function api_detectarDuplicados() {
  cc_requireSession();
  var sh = _sh("CONSOLIDADO_DE_PACIENTES");
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, grupos: [], total: 0 };

  var data = sh.getRange(2, 1, lr - 1, 21).getValues();
  var mapaT = {}, grupos = [];

  data.forEach(function(r, i) {
    var tel = _normNum(r[3]);
    var est = _up(_norm(r[18] || ""));
    if (!tel || est === "RETIRADO") return;
    if (!mapaT[tel]) mapaT[tel] = [];
    mapaT[tel].push({ row:i+2, id:_norm(r[0]), nombres:_norm(r[1]), apellidos:_norm(r[2]),
      tel:tel, dni:_norm(r[5]), totalFact:Number(r[14])||0, ultVisita:_date(r[15]),
      totalComp:Number(r[13])||0, estado:_up(_norm(r[18]||"NUEVO")) });
  });

  Object.keys(mapaT).forEach(function(tel) {
    if (mapaT[tel].length >= 2) grupos.push({ tipo:"TELEFONO_DUPLICADO", clave:tel, registros:mapaT[tel] });
  });

  var telsDup = {};
  grupos.forEach(function(g) { g.registros.forEach(function(r) { telsDup[r.tel]=true; }); });

  var mapaN = {};
  data.forEach(function(r, i) {
    var tel = _normNum(r[3]);
    if (telsDup[tel] || _up(_norm(r[18]||""))==="RETIRADO") return;
    var clave = (_norm(r[1]).split(" ")[0]||"") + "_" + (_norm(r[2]).split(" ")[0]||"");
    if (!clave || clave === "_") return;
    if (!mapaN[clave]) mapaN[clave] = [];
    mapaN[clave].push({ row:i+2, id:_norm(r[0]), nombres:_norm(r[1]), apellidos:_norm(r[2]),
      tel:tel, dni:_norm(r[5]), totalFact:Number(r[14])||0, ultVisita:_date(r[15]),
      totalComp:Number(r[13])||0, estado:_up(_norm(r[18]||"NUEVO")) });
  });

  Object.keys(mapaN).forEach(function(clave) {
    if (mapaN[clave].length >= 2)
      grupos.push({ tipo:"NOMBRE_SIMILAR", clave:clave.replace("_"," "), registros:mapaN[clave] });
  });

  grupos = grupos.slice(0, 50);
  return { ok: true, grupos: grupos, total: grupos.length };
}

function api_fusionarPacientes(rowPrincipal, rowSecundario) {
  var s = cc_requireSession();
  if (s.rol !== "ADMIN" && s.rol !== "ADMINISTRADOR") throw new Error("Solo ADMIN puede fusionar pacientes.");
  rowPrincipal  = Number(rowPrincipal);
  rowSecundario = Number(rowSecundario);
  if (!rowPrincipal || !rowSecundario) throw new Error("Filas de principal y secundario requeridas.");
  if (rowPrincipal === rowSecundario)  throw new Error("No puedes fusionar un registro consigo mismo.");

  var sh = _sh("CONSOLIDADO_DE_PACIENTES");
  var fP = sh.getRange(rowPrincipal,  1, 1, 24).getValues()[0];
  var fS = sh.getRange(rowSecundario, 1, 1, 24).getValues()[0];
  var tP = _normNum(fP[3]), tS = _normNum(fS[3]);
  if (!tP) throw new Error("El registro principal no tiene teléfono válido.");
  if (!tS) throw new Error("El registro secundario no tiene teléfono válido.");

  var fA = fP.slice();
  [4,5,7,8,9,10,11].forEach(function(c) {
    if (!_norm(String(fA[c])) && _norm(String(fS[c]))) fA[c] = fS[c];
  });
  [13,14,16,17].forEach(function(c) { fA[c] = (Number(fA[c])||0) + (Number(fS[c])||0); });
  var uvP = fP[15]?new Date(fP[15]):null, uvS = fS[15]?new Date(fS[15]):null;
  if (uvP&&uvS) { fA[15]=uvP>uvS?uvP:uvS; } else if (!uvP&&uvS) { fA[15]=uvS; }

  sh.getRange(rowPrincipal,  1, 1, fA.length).setValues([fA]);
  sh.getRange(rowSecundario, 19).setValue("RETIRADO");

  _fusion_reasignarLlamadas(tS, tP);
  _fusion_reasignarCitas(tS, tP);
  _fusion_reasignarVentas(tS, tP);
  _fusion_reasignarNotas(tS, tP);

  Logger.log("FUSION OK — principal: "+tP+" (row "+rowPrincipal+") | secundario: "+tS+" → RETIRADO");
  return { ok: true, msg: "Fusión completada. "+tS+" consolidado en "+tP+"." };
}

function _fusion_reasignarLlamadas(tS, tP) {
  try { var sh=_sh("CONSOLIDADO DE LLAMADAS"),lr=sh.getLastRow();if(lr<2)return;
    var n=sh.getRange(2,9,lr-1,1).getValues(),u=[];
    for(var i=0;i<n.length;i++){if(_normNum(n[i][0])===tS)u.push(i+2);}
    u.forEach(function(r){sh.getRange(r,9).setValue(tP);});
    Logger.log("  Llamadas reasignadas: "+u.length);
  } catch(e){Logger.log("  WARN llamadas: "+e.message);}
}
function _fusion_reasignarCitas(tS, tP) {
  try { var sh=_shAgenda(),lr=sh.getLastRow();if(lr<2)return;
    var n=sh.getRange(2,6,lr-1,1).getValues(),u=[];
    for(var i=0;i<n.length;i++){if(_normNum(n[i][0])===tS)u.push(i+2);}
    u.forEach(function(r){sh.getRange(r,6).setValue(tP);});
    Logger.log("  Citas reasignadas: "+u.length);
  } catch(e){Logger.log("  WARN citas: "+e.message);}
}
function _fusion_reasignarVentas(tS, tP) {
  try { var sh=_sh("CONSOLIDADO DE VENTAS"),lr=sh.getLastRow();if(lr<2)return;
    var n=sh.getRange(2,16,lr-1,1).getValues(),u=[];
    for(var i=0;i<n.length;i++){if(_normNum(n[i][0])===tS)u.push(i+2);}
    u.forEach(function(r){sh.getRange(r,16).setValue(tP);});
    Logger.log("  Ventas reasignadas: "+u.length);
  } catch(e){Logger.log("  WARN ventas: "+e.message);}
}
function _fusion_reasignarNotas(tS, tP) {
  try { var sh=_sh("NOTAS_PACIENTES"),lr=sh.getLastRow();if(lr<2)return;
    var n=sh.getRange(2,4,lr-1,1).getValues(),u=[];
    for(var i=0;i<n.length;i++){if(_normNum(n[i][0])===tS)u.push(i+2);}
    u.forEach(function(r){sh.getRange(r,4).setValue(tP);});
    Logger.log("  Notas reasignadas: "+u.length);
  } catch(e){Logger.log("  WARN notas: "+e.message);}
}
// ===== CTRL+F: FUSION_END =====


// ══════════════════════════════════════════════════════════════
// MOD-08 · HELPERS INTERNOS DE GS_24
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: HELPERS24_START =====

/**
 * _g24_normEstado
 * Normaliza estados de citas y llamadas con/sin tilde.
 *
 * NOTA FIX-05: api_getPatient360() fue eliminada de este módulo.
 * La versión definitiva con CacheService está en GS_09 PERF-03.
 * Tener la función duplicada en ambos archivos causaba conflicto
 * en GAS y era la causa raíz del login colgado.
 */
function _g24_normEstado(estado) {
  if (!estado) return "";
  var e = estado.toUpperCase().trim()
    .replace(/Ó/g,"O").replace(/É/g,"E").replace(/Á/g,"A").replace(/Í/g,"I").replace(/Ú/g,"U");
  var map = {
    "NO CONTESTA":"SIN CONTACTO","NO CONTEST":"SIN CONTACTO",
    "ASISTIO":"ASISTIO","NO ASISTIO":"NO ASISTIO","EFECTIVA":"ASISTIO",
    "CITA CONFIRMADA":"CITA CONFIRMADA","CANCELADA":"CANCELADA","CANCELO":"CANCELADA",
    "REAGENDADA":"REAGENDADA","PENDIENTE":"PENDIENTE"
  };
  return map[e] || e;
}

function _g24_calcDiasUltVisita(ultVisita) {
  if (!ultVisita) return null;
  try {
    var uv=new Date(ultVisita); uv.setHours(0,0,0,0);
    var hoy=new Date(); hoy.setHours(0,0,0,0);
    var d=Math.floor((hoy-uv)/(1000*60*60*24));
    return d>=0?d:null;
  } catch(e) { return null; }
}
// ===== CTRL+F: HELPERS24_END =====


// ══════════════════════════════════════════════════════════════
// MOD-09 · WRAPPERS TOKEN
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: WRAP360_START =====
//
// ⚠️ IMPORTANTE — api_getPatient360T NO está en este archivo.
// Está en GS_09_Pacientes.gs (función api_getPatient360T en PERF-03)
// con CacheService para mejor rendimiento.
// Poner la misma función en dos archivos .gs del mismo proyecto
// causaba conflicto de nombre y login colgado. FIX-05.

function api_saveHistoriaClinicaT(token, payload)            { _setToken(token); return api_saveHistoriaClinica(payload); }
function api_getHistoriaClinicaT(token, dniOrTel)            { _setToken(token); return api_getHistoriaClinica(dniOrTel); }
function api_saveNotaPaciente360T(token, num, texto, tipo)   { _setToken(token); return api_saveNotaPaciente360(num, texto, tipo); }
function api_getNotasPaciente360T(token, num, tipo)          { _setToken(token); return api_getNotasPaciente360(num, tipo); }
function api_updateNotaPaciente360T(token, notaId, texto)    { _setToken(token); return api_updateNotaPaciente360(notaId, texto); }
function api_deleteNotaPaciente360T(token, notaId)           { _setToken(token); return api_deleteNotaPaciente360(notaId); }
function api_saveSeguimientoProgramadoT(token, payload)      { _setToken(token); return api_saveSeguimientoProgramado(payload); }
function api_getSeguimientosProgramadosT(token, num, filtro) { _setToken(token); return api_getSeguimientosProgramados(num, filtro); }
function api_cerrarSeguimientoProgramadoT(token, segId)      { _setToken(token); return api_cerrarSeguimientoProgramado(segId); }
function api_getPatientTimelineT(token, num)                 { _setToken(token); return api_getPatientTimeline(num); }
function api_createCitaDesde360T(token, payload)             { _setToken(token); return api_createCitaDesde360(payload); }
function api_getPatientScore360T(token, num)                 { _setToken(token); return api_getPatientScore360(num); }
function api_getEquipoActivoT(token)                         { _setToken(token); return api_getEquipoActivo(); }
function api_detectarDuplicadosT(token)                      { _setToken(token); return api_detectarDuplicados(); }
function api_fusionarPacientesT(token, rowP, rowS)           { _setToken(token); return api_fusionarPacientes(rowP, rowS); }
// ===== CTRL+F: WRAP360_END =====


// ══════════════════════════════════════════════════════════════
// MOD-10 · TESTS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: TEST360_START =====

function test_GS24_v21_verificar() {
  Logger.log("=== TEST GS_24_Pacientes360 v2.1 ===");

  try { var hc = api_getHistoriaClinica("99999999");
    Logger.log("✅ api_getHistoriaClinica OK — hc: " + (hc.hc ? "encontrada" : "no existe")); }
  catch(e) { Logger.log("❌ api_getHistoriaClinica: " + e.message); }

  try { var segs = api_getSeguimientosProgramados(null, "vencidos");
    Logger.log("✅ api_getSeguimientosProgramados OK — vencidos: " + segs.total); }
  catch(e) { Logger.log("❌ api_getSeguimientosProgramados: " + e.message); }

  try { var notas = api_getNotasPaciente360("987654321");
    Logger.log("✅ api_getNotasPaciente360 OK — notas: " + notas.notas.length); }
  catch(e) { Logger.log("❌ api_getNotasPaciente360: " + e.message); }

  Logger.log("--- Test _g24_normEstado ---");
  Logger.log("'ASISTIÓ'   → " + _g24_normEstado("ASISTIÓ"));     // ASISTIO
  Logger.log("'NO ASISTIÓ'→ " + _g24_normEstado("NO ASISTIÓ")); // NO ASISTIO
  Logger.log("'CANCELÓ'   → " + _g24_normEstado("CANCELÓ"));     // CANCELADA
  Logger.log("'NO CONTESTA'→ " + _g24_normEstado("NO CONTESTA")); // SIN CONTACTO

  try { var eq = api_getEquipoActivo();
    Logger.log("✅ api_getEquipoActivo OK — asesores: " + eq.items.length); }
  catch(e) { Logger.log("❌ api_getEquipoActivo: " + e.message); }

  try { var d = api_detectarDuplicados();
    Logger.log("✅ api_detectarDuplicados OK — grupos: " + d.total); }
  catch(e) { Logger.log("❌ api_detectarDuplicados: " + e.message); }

  Logger.log("=== FIN TEST GS_24 v2.1 ===");
}

/**
 * CHECKLIST DE PRUEBA — GS_24 v2.1
 *
 * PRUEBA 1: test_GS24_v21_verificar() → todos ✅ en Logger
 * PRUEBA 2: Login normal → no debe colgar (FIX-05 aplicado)
 * PRUEBA 3: Panel Pacientes → click en paciente → carga perfil + timeline
 * PRUEBA 4: Tab Citas → citas ASISTIDAS muestran punto VERDE
 * PRUEBA 5: Panel notas → crear, editar y eliminar nota
 *
 * SEÑALES DE ÉXITO:
 *   ✅ Login entra en menos de 15 segundos
 *   ✅ diasUltVisita muestra número (no guión)
 *   ✅ Notas: editar y eliminar funcionan correctamente
 *   ✅ Modal duplicados muestra totalFact y ultVisita
 */
// ===== CTRL+F: TEST360_END =====