/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_08_Agenda.gs                            ║
 * ║  Módulo: Agenda, Slots, Horarios y Google Calendar          ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01–07                                     ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Slots disponibles por fecha y tipo
 *   MOD-02 · Vista día/semana/mes de la agenda
 *   MOD-03 · Doctora del día y turno activo
 *   MOD-04 · Crear, editar y eliminar citas
 *   MOD-05 · Integración con Google Calendar
 *   MOD-06 · Admin — agenda global
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · SLOTS DISPONIBLES
// ══════════════════════════════════════════════════════════════
// H01_START

/**
 * api_getSlotsDisponibles — Retorna slots libres para una fecha y sede
 *
 * @param {string} fecha    "yyyy-MM-dd"
 * @param {string} sede     "SAN ISIDRO" | "PUEBLO LIBRE" | ""
 * @param {string} tipoAt  "DOCTORA" | "ENFERMERIA" | ""
 * @returns {Object} {ok, slots:[{hora, libre, ocupados, cap, doctora}]}
 */
function api_getSlotsDisponibles(fecha, sede, tipoAt) {
  cc_requireSession();
  fecha  = _date(fecha || new Date());
  sede   = _up(sede || "");
  tipoAt = _up(tipoAt || "");

  // ── Obtener horario del día ──
  var diaSem = _diaSemana(fecha);
  var horarios = _getHorariosDia(diaSem, sede);

  if (!horarios.length) {
    return { ok: true, slots: [], msg: "Sin horarios configurados para ese día." };
  }

  // ── Contar citas existentes por slot ──
  var citasEnFecha = _getCitasFecha(fecha, sede, tipoAt);

  // ── Construir slots ──
  var slotsFinal = [];
  horarios.forEach(function(hor) {
    var slots = _generarSlots(hor.horaIni, hor.horaFin);
    var cap   = tipoAt === "ENFERMERIA"
      ? hor.capEnf : hor.capDoc;
    var doctora = hor.doctoraLabel;

    slots.forEach(function(hora) {
      var key     = hora + "|" + (doctora || "");
      var ocupados = citasEnFecha[key] || 0;
      slotsFinal.push({
        hora:     hora,
        libre:    ocupados < cap,
        libres:   cap - ocupados,
        ocupados: ocupados,
        cap:      cap,
        doctora:  doctora
      });
    });
  });

  return { ok: true, slots: slotsFinal };
}

/**
 * Lee horarios configurados para un día de semana y sede
 * @returns {Array} [{horaIni, horaFin, capDoc, capEnf, doctoraLabel}]
 */
function _getHorariosDia(diaSem, sede) {
  try {
    var sh = _shHorarios();
    var lr = sh.getLastRow();
    if (lr < 2) return _horariosFallback(diaSem);

    var rows = sh.getRange(2, 1, lr - 1, 11).getValues();
    var result = rows
      .filter(function(r) {
        var ds  = _up(r[HOR_COL.DIA_SEM]);
        var sd  = _up(r[HOR_COL.SEDE]);
        var act = _up(r[HOR_COL.ACTIVO]);
        var diaCoin = ds === diaSem || ds === "";
        var sedeCoin = !sede || !sd || sd.includes(sede) || sede.includes(sd);
        return diaCoin && sedeCoin && act !== "NO" && act !== "FALSE";
      })
      .map(function(r) {
        return {
          doctoraLabel: _norm(r[HOR_COL.DOCTORA_LABEL]),
          horaIni:      _normHora(r[HOR_COL.HORA_INI]),
          horaFin:      _normHora(r[HOR_COL.HORA_FIN]),
          capDoc:       Number(r[HOR_COL.CAP_DOC]) || AGENDA_CONFIG.CAP_DOC_DEFAULT,
          capEnf:       Number(r[HOR_COL.CAP_ENF]) || AGENDA_CONFIG.CAP_ENF_DEFAULT,
          sede:         _norm(r[HOR_COL.SEDE])
        };
      });

    return result.length ? result : _horariosFallback(diaSem);
  } catch(e) {
    return _horariosFallback(diaSem);
  }
}

/**
 * Horario fallback si no hay datos en la hoja HORARIOS_DOCTORAS
 * Usa DRA. CAROLINA como doctora por defecto
 */
function _horariosFallback(diaSem) {
  // Solo días de semana
  var diasHabiles = ["LUNES","MARTES","MIERCOLES","JUEVES","VIERNES","SABADO"];
  if (diasHabiles.indexOf(diaSem) === -1) return [];

  return [{
    doctoraLabel: "DRA. CAROLINA",
    horaIni:      "14:30",
    horaFin:      "20:00",
    capDoc:       5,
    capEnf:       5,
    sede:         "SAN ISIDRO"
  }];
}

/**
 * Cuenta citas existentes por slot (hora|doctora)
 * @returns {Object} {"HH:mm|DOCTORA": count}
 */
function _getCitasFecha(fecha, sede, tipoAt) {
  var conteo = {};
  try {
    var sh = _shAgenda();
    var lr = sh.getLastRow();
    if (lr < 2) return conteo;

    sh.getRange(2, 1, lr - 1, 22).getValues().forEach(function(r) {
      var fd = _date(r[AG_COL.FECHA]);
      if (fd !== fecha) return;

      var estadoCita = _up(r[AG_COL.ESTADO]);
      if (estadoCita === "CANCELADA") return;

      var sedeCita   = _up(r[AG_COL.SEDE]);
      var tipoAtCita = _up(r[AG_COL.TIPO_ATENCION]);

      if (sede && sedeCita && !sedeCita.includes(sede) && !sede.includes(sedeCita)) return;
      if (tipoAt && tipoAtCita && tipoAtCita !== tipoAt) return;

      var hora    = _normHora(r[AG_COL.HORA_CITA]);
      var doctora = _norm(r[AG_COL.DOCTORA]);
      var key     = hora + "|" + doctora;
      conteo[key] = (conteo[key] || 0) + 1;
    });
  } catch(e) {}
  return conteo;
}

/** Wrappers token slots */
function api_getSlotsDisponiblesT(token, fecha, sede, tipoAt) {
  _setToken(token);
  return api_getSlotsDisponibles(fecha, sede, tipoAt);
}
// H01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · VISTA AGENDA (DÍA / SEMANA / MES)
// ══════════════════════════════════════════════════════════════
// H02_START

/**
 * api_getAgendaDia — Citas del día para vista calendario
 * @param {string} fecha   "yyyy-MM-dd"
 * @param {string} sede    "" = todas
 * @param {string} filtroAsesor "" = todos (admin) | id (asesor)
 */
function api_getAgendaDia(fecha, sede, filtroAsesor) {
  var s  = cc_requireSession();
  fecha  = _date(fecha || new Date());
  sede   = _up(sede || "");

  // Asesor solo ve sus citas (admin ve todas)
  var esAdmin = s.role === ROLES.ADMIN;
  if (!esAdmin && !filtroAsesor) {
    filtroAsesor = s.idAsesor;
  }

  var sh = _shAgenda();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, citas: [], resumen: {}, doctoraDia: null };

  var citas = sh.getRange(2, 1, lr - 1, 22).getValues()
    .filter(function(r) {
      if (_date(r[AG_COL.FECHA]) !== fecha) return false;
      if (sede && !_up(r[AG_COL.SEDE]).includes(sede)) return false;
      if (filtroAsesor) {
        var ia = _norm(r[AG_COL.ID_ASESOR]);
        var na = _up(r[AG_COL.ASESOR]);
        var fId = _norm(filtroAsesor);
        var fNom = _up(filtroAsesor);
        if (ia !== fId && na !== fNom) return false;
      }
      return true;
    })
    .map(function(r) {
      return {
        id:          _norm(r[AG_COL.ID]),
        hora:        _normHora(r[AG_COL.HORA_CITA]),
        trat:        _norm(r[AG_COL.TRATAMIENTO]),
        tipoCita:    _norm(r[AG_COL.TIPO_CITA]),
        sede:        _norm(r[AG_COL.SEDE]),
        num:         _normNum(r[AG_COL.NUMERO]),
        nombre:      _norm(r[AG_COL.NOMBRE]),
        apellido:    _norm(r[AG_COL.APELLIDO]),
        asesor:      _norm(r[AG_COL.ASESOR]),
        estadoCita:  _norm(r[AG_COL.ESTADO]),
        tipoAtencion:_norm(r[AG_COL.TIPO_ATENCION]),
        doctora:     _norm(r[AG_COL.DOCTORA]),
        obs:         _norm(r[AG_COL.OBS]),
        wa:          _wa(_normNum(r[AG_COL.NUMERO]))
      };
    })
    .sort(function(a, b) { return a.hora < b.hora ? -1 : 1; });

  // Doctora del día
  var doctoraDia = _getDoctoraDia(fecha, sede);

  // Resumen
  var resumen = {
    total:       citas.length,
    confirmadas: citas.filter(function(c) { return c.estadoCita === "CITA CONFIRMADA"; }).length,
    asistieron:  citas.filter(function(c) { return c.estadoCita === "ASISTIO"; }).length,
    efectivas:   citas.filter(function(c) { return c.estadoCita === "EFECTIVA"; }).length,
    canceladas:  citas.filter(function(c) { return c.estadoCita === "CANCELADA"; }).length
  };

  return { ok: true, citas: citas, resumen: resumen, doctoraDia: doctoraDia };
}

/**
 * api_getAgendaSemana — Citas de una semana
 * @param {string} fechaBase Cualquier día de la semana
 */
function api_getAgendaSemana(fechaBase, sede, filtroAsesor) {
  var s = cc_requireSession();
  var base = fechaBase ? new Date(fechaBase + "T12:00:00") : new Date();
  var diaSem = base.getDay(); // 0=Dom
  // Calcular inicio de semana (Lunes)
  var iniSem = new Date(base);
  iniSem.setDate(base.getDate() - (diaSem === 0 ? 6 : diaSem - 1));

  var dias = [];
  for (var i = 0; i < 7; i++) {
    var d = new Date(iniSem);
    d.setDate(iniSem.getDate() + i);
    var fd = _date(d);
    var res = api_getAgendaDia(fd, sede, filtroAsesor);
    dias.push({
      fecha:  fd,
      diaNom: DIAS_SEMANA[d.getDay()],
      citas:  res.citas || [],
      total:  (res.citas || []).length
    });
  }

  return { ok: true, dias: dias };
}

/**
 * Obtiene la doctora asignada para un día y sede
 */
function _getDoctoraDia(fecha, sede) {
  var diaSem   = _diaSemana(fecha);
  var horarios = _getHorariosDia(diaSem, sede || "");
  if (!horarios.length) return null;

  var h = horarios[0];
  return {
    nombre:  h.doctoraLabel,
    horaIni: h.horaIni,
    horaFin: h.horaFin,
    sede:    h.sede || sede
  };
}

/** Wrappers token agenda */
function api_getAgendaDiaT(token, fecha, sede, filtroAsesor) {
  _setToken(token); return api_getAgendaDia(fecha, sede, filtroAsesor);
}
function api_getAgendaSemanaT(token, fechaBase, sede, filtroAsesor) {
  _setToken(token); return api_getAgendaSemana(fechaBase, sede, filtroAsesor);
}
// H02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · DOCTORA DEL DÍA Y RESUMEN RÁPIDO
// ══════════════════════════════════════════════════════════════
// H03_START

/**
 * api_getDoctoraDia — Info de la doctora del día + turnos del equipo
 */
function api_getDoctoraDia(fecha, sede) {
  cc_requireSession();
  fecha = _date(fecha || new Date());
  sede  = _up(sede || "");

  var doctora = _getDoctoraDia(fecha, sede);

  // Enfermería de apoyo del día
  var enfermeriaApoya = _enfermeriaActiva()
    .map(function(e) { return e.label || e.nombre; })
    .join(", ");

  // Turnos de asesores (del LOG_PERSONAL)
  var turnosAsesores = _getTurnosHoy(fecha);

  return {
    ok:          true,
    doctora:     doctora,
    enfermeria:  enfermeriaApoya,
    turnos:      turnosAsesores
  };
}

/**
 * Obtiene los turnos activos del día desde LOG_PERSONAL
 */
function _getTurnosHoy(fecha) {
  var turnos = [];
  try {
    var sh  = _estadoSheet();
    var lr  = sh.getLastRow();
    if (lr < 2) return turnos;

    var hoy = _date(fecha || new Date());
    sh.getRange(2, 1, lr - 1, 11).getValues().forEach(function(r) {
      var fd  = _date(r[0]);
      var evt = _up(r[2]);
      if (fd !== hoy) return;
      if (evt !== "ESTADO") return;
      var edo = _up(r[3]);
      if (["APERTURA DE TURNO","CIERRE DE TURNO"].indexOf(edo) === -1) return;
      turnos.push({
        asesor: _norm(r[1]),
        evento: edo,
        hora:   _time(r[5])
      });
    });
  } catch(e) {}
  return turnos;
}

/** Wrappers token */
function api_getDoctoraDiaT(token, fecha, sede) {
  _setToken(token); return api_getDoctoraDia(fecha, sede);
}
// H03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · CREAR, EDITAR Y ELIMINAR CITAS
// ══════════════════════════════════════════════════════════════
// H04_START

/**
 * api_createCita — Crea una nueva cita directamente desde la agenda
 * (diferente de crear desde el call center)
 */
function api_createCita(payload) {
  var s   = cc_requireSession();
  payload = payload || {};
  var now = new Date();

  var num = _phone(payload.numero || "");
  if (!num)                    throw new Error("Falta número.");
  if (!payload.fechaCita)      throw new Error("Falta fecha de cita.");
  if (!payload.tratamiento)    throw new Error("Falta tratamiento.");

  var cid    = "C-" + _uid().slice(0, 8).toUpperCase();
  var tipoAt = _up(payload.tipoAtencion || "");
  if (!tipoAt) tipoAt = _tipoAtencion(payload.tratamiento);

  var doctora = _norm(payload.doctora || "");
  if (!doctora && tipoAt === TIPO_ATENCION.DOCTORA) {
    var docs = _doctorasConAgenda();
    var sede = _up(payload.sede || s.sede || "");
    var docSede = docs.filter(function(d) {
      return !sede || _up(d.sede || "").includes(sede) || sede.includes(_up(d.sede || ""));
    });
    if (docSede.length) doctora = docSede[0].label || docSede[0].nombre;
  }

  _shAgenda().appendRow([
    cid,
    _date(payload.fechaCita),
    _norm(payload.tratamiento),
    _norm(payload.tipoCita || "CONSULTA NUEVA"),
    _up(payload.sede || s.sede || ""),
    "'" + num,
    _norm(payload.nombre || ""),
    _norm(payload.apellido || ""),
    _norm(payload.dni || ""),
    _norm(payload.correo || ""),
    _norm(payload.asesor || s.asesor),
    _norm(payload.idAsesor || s.idAsesor),
    "CITA CONFIRMADA",
    "",
    _norm(payload.obs || ""),
    now,
    now,
    _norm(payload.horaCita || ""),
    _norm(payload.anuncio || ""),
    doctora,
    tipoAt,
    ""
  ]);

  // Sincronizar con Google Calendar si está activo
  if (GCAL_CONFIG.ACTIVO) {
    try {
      _syncCitaCalendar(cid, payload, doctora);
    } catch(eGcal) {
      Logger.log("GCal sync error: " + eGcal.message);
    }
  }

  // Notificar admin
  try {
    var admins = _asesoresActivos().filter(function(a) {
      return _normRole(a.role) === ROLES.ADMIN;
    });
    admins.forEach(function(adm) {
      _notifSheet().appendRow([
        _uid(), _date(now), _time(now), "CITA",
        "📅 Nueva cita: " + num,
        (payload.asesor || s.asesor) + " — " + _norm(payload.tratamiento) + " — " + _date(payload.fechaCita),
        s.idAsesor, s.asesor,
        adm.idAsesor, adm.label || adm.nombre, ""
      ]);
    });
  } catch(e) {}

  cache_invalidateDashboard();
  return { ok: true, citaId: cid };
}

/**
 * api_updateCita — Actualiza una cita existente
 */
function api_updateCita(citaId, payload) {
  var s  = cc_requireSession();
  payload = payload || {};

  var sh = _shAgenda();
  var lr = sh.getLastRow();
  if (lr < 2) throw new Error("Agenda vacía.");

  var ids    = sh.getRange(2, 1, lr - 1, 1).getValues().flat().map(_norm);
  var rowIdx = ids.indexOf(_norm(citaId));
  if (rowIdx === -1) throw new Error("Cita no encontrada: " + citaId);

  var row = rowIdx + 2;
  var now = new Date();

  // Actualizar campos provistos
  var updates = {};
  if (payload.fechaCita)    updates[AG_COL.FECHA + 1]        = _date(payload.fechaCita);
  if (payload.tratamiento)  updates[AG_COL.TRATAMIENTO + 1]  = _norm(payload.tratamiento);
  if (payload.tipoCita)     updates[AG_COL.TIPO_CITA + 1]    = _norm(payload.tipoCita);
  if (payload.sede)         updates[AG_COL.SEDE + 1]         = _up(payload.sede);
  if (payload.nombre)       updates[AG_COL.NOMBRE + 1]       = _norm(payload.nombre);
  if (payload.apellido)     updates[AG_COL.APELLIDO + 1]     = _norm(payload.apellido);
  if (payload.dni)          updates[AG_COL.DNI + 1]          = _norm(payload.dni);
  if (payload.horaCita)     updates[AG_COL.HORA_CITA + 1]    = _norm(payload.horaCita);
  if (payload.estadoCita)   updates[AG_COL.ESTADO + 1]       = _norm(payload.estadoCita);
  if (payload.doctora)      updates[AG_COL.DOCTORA + 1]      = _norm(payload.doctora);
  if (payload.tipoAtencion) updates[AG_COL.TIPO_ATENCION + 1]= _up(payload.tipoAtencion);
  if (payload.obs !== undefined) updates[AG_COL.OBS + 1]     = _norm(payload.obs);
  updates[AG_COL.TS_ACTUALIZADO + 1] = now;

  da_setRowCells(CFG.SHEET_AGENDA, row, updates);
  cache_invalidateDashboard();
  return { ok: true };
}

/**
 * api_deleteCita — Cancela una cita (no la elimina físicamente)
 */
function api_deleteCita(citaId) {
  return api_updateCita(citaId, { estadoCita: "CANCELADA" });
}

/** Wrappers token CRUD citas */
function api_createCitaT(token, payload)         { _setToken(token); return api_createCita(payload); }
function api_updateCitaT(token, citaId, payload) { _setToken(token); return api_updateCita(citaId, payload); }
function api_deleteCitaT(token, citaId)          { _setToken(token); return api_deleteCita(citaId); }
// H04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · INTEGRACIÓN GOOGLE CALENDAR
// ══════════════════════════════════════════════════════════════
// H05_START

/**
 * Sincroniza una cita nueva con Google Calendar
 * @param {string} citaId
 * @param {Object} payload
 * @param {string} doctora
 */
function _syncCitaCalendar(citaId, payload, doctora) {
  if (!GCAL_CONFIG.ACTIVO) return;

  var cal = CalendarApp.getCalendarById(GCAL_CONFIG.TURNOS_ID);
  if (!cal) {
    Logger.log("GCal: Calendario no encontrado → " + GCAL_CONFIG.TURNOS_ID);
    return;
  }

  var fecha = new Date(payload.fechaCita + "T12:00:00");
  if (!payload.horaCita) return;

  var partes = String(payload.horaCita).split(":");
  if (partes.length < 2) return;

  var inicio = new Date(payload.fechaCita + "T" + payload.horaCita + ":00");
  var fin    = new Date(inicio.getTime() + 30 * 60000); // 30 min por cita

  var titulo = "[CITA] " + _norm(payload.tratamiento) +
    " — " + _norm(payload.nombre || "") + " " + _norm(payload.apellido || "") +
    " (" + _normNum(payload.numero || "") + ")";

  var desc = [
    "Asesor: " + _norm(payload.asesor || ""),
    "Sede: "   + _up(payload.sede || ""),
    "Doctora: "+ (doctora || "—"),
    "Tipo: "   + _norm(payload.tipoCita || ""),
    "ID: "     + citaId
  ].join("\n");

  try {
    var evt = cal.createEvent(titulo, inicio, fin, {
      description: desc,
      location: _up(payload.sede || "")
    });

    // Guardar el ID del evento en la cita
    var sh   = _shAgenda();
    var lr   = sh.getLastRow();
    var ids  = sh.getRange(2, 1, lr - 1, 1).getValues().flat().map(_norm);
    var ridx = ids.indexOf(_norm(citaId));
    if (ridx >= 0) {
      sh.getRange(ridx + 2, AG_COL.GCAL_ID + 1).setValue(evt.getId());
    }
    Logger.log("GCal: Evento creado → " + evt.getId());
  } catch(e) {
    Logger.log("GCal createEvent error: " + e.message);
  }
}

/**
 * api_syncAgendaCalendar — Sincroniza todas las citas activas con GCal
 * Solo admin, ejecutar manualmente cuando sea necesario
 */
function api_syncAgendaCalendar() {
  cc_requireAdmin();
  var sh   = _shAgenda();
  var lr   = sh.getLastRow();
  if (lr < 2) return { ok: true, synced: 0 };

  var filas   = sh.getRange(2, 1, lr - 1, 22).getValues();
  var synced  = 0;
  var hoy     = new Date();

  filas.forEach(function(r, i) {
    var estado  = _up(r[AG_COL.ESTADO]);
    var gcalId  = _norm(r[AG_COL.GCAL_ID]);
    var fd      = r[AG_COL.FECHA];
    if (!fd || estado === "CANCELADA") return;

    var fechaDate = fd instanceof Date ? fd : new Date(fd);
    if (isNaN(fechaDate) || fechaDate < new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())) return;
    if (gcalId) return; // ya sincronizada

    var payload = {
      fechaCita:   _date(r[AG_COL.FECHA]),
      horaCita:    _normHora(r[AG_COL.HORA_CITA]),
      tratamiento: _norm(r[AG_COL.TRATAMIENTO]),
      tipoCita:    _norm(r[AG_COL.TIPO_CITA]),
      sede:        _norm(r[AG_COL.SEDE]),
      numero:      _normNum(r[AG_COL.NUMERO]),
      nombre:      _norm(r[AG_COL.NOMBRE]),
      apellido:    _norm(r[AG_COL.APELLIDO]),
      asesor:      _norm(r[AG_COL.ASESOR])
    };

    try {
      _syncCitaCalendar(_norm(r[AG_COL.ID]), payload, _norm(r[AG_COL.DOCTORA]));
      synced++;
    } catch(e) {}
  });

  return { ok: true, synced: synced };
}

/** Wrapper token sync */
function api_syncAgendaCalendarT(token) {
  _setToken(token); return api_syncAgendaCalendar();
}
// H05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · AGENDA GLOBAL (ADMIN)
// ══════════════════════════════════════════════════════════════
// H06_START

/**
 * api_getAgendaGlobal — Vista completa de la agenda para el admin
 * Todas las citas de todos los asesores y sedes
 */
function api_getAgendaGlobal(fecha, sede) {
  cc_requireAdmin();
  return api_getAgendaDia(fecha, sede, null);
}

/**
 * api_getResumenAgenda — Resumen rápido de la agenda
 * Para el ticker del topbar admin
 */
function api_getResumenAgenda(fecha) {
  cc_requireSession();
  fecha = _date(fecha || new Date());

  var sh = _shAgenda();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, total: 0, confirmadas: 0, asistieron: 0 };

  var total = 0; var conf = 0; var asist = 0;
  sh.getRange(2, 1, lr - 1, 22).getValues().forEach(function(r) {
    if (_date(r[AG_COL.FECHA]) !== fecha) return;
    if (_up(r[AG_COL.ESTADO]) === "CANCELADA") return;
    total++;
    var edo = _up(r[AG_COL.ESTADO]);
    if (edo === "CITA CONFIRMADA") conf++;
    if (edo === "ASISTIO" || edo === "EFECTIVA") asist++;
  });

  return { ok: true, total: total, confirmadas: conf, asistieron: asist };
}

/** Wrappers token agenda global */
function api_getAgendaGlobalT(token, fecha, sede) {
  _setToken(token); return api_getAgendaGlobal(fecha, sede);
}
function api_getResumenAgendaT(token, fecha) {
  _setToken(token); return api_getResumenAgenda(fecha);
}
// H06_END

/**
 * TEST
 */
function test_Agenda() {
  Logger.log("=== GS_08_Agenda TEST ===");
  var hoy = _date(new Date());
  Logger.log("Día semana: " + _diaSemana(hoy));
  Logger.log("Horarios hoy: " + JSON.stringify(_getHorariosDia(_diaSemana(hoy), "")));
  Logger.log("Slots hoy (fallback): esperados desde 14:30 cada 30min");
  Logger.log("Funciones disponibles:");
  Logger.log("  api_getSlotsDisponiblesT(token, fecha, sede, tipoAt)");
  Logger.log("  api_getAgendaDiaT(token, fecha, sede, filtroAsesor)");
  Logger.log("  api_getAgendaSemanaT(token, fechaBase, sede, filtroAsesor)");
  Logger.log("  api_createCitaT(token, payload)");
  Logger.log("  api_updateCitaT(token, citaId, payload)");
  Logger.log("  api_deleteCitaT(token, citaId)");
  Logger.log("  api_getAgendaGlobalT(token, fecha, sede)  [admin]");
  Logger.log("=== OK ===");
}