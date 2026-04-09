/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_06_AdvisorCalls.gs                      ║
 * ║  Módulo: Panel de Llamadas, Leads y Seguimientos            ║
 * ║  Versión: 2.0.0 — Consolidado con GS_24_CallCenterPatch    ║
 * ║  Dependencias: GS_01–05                                     ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Obtener lead activo (con tiers)
 *   MOD-02 · Guardar resultado de llamada
 *   MOD-03 · Gestión de seguimientos
 *   MOD-04 · Llamadas del asesor hoy
 *   MOD-05 · Monitoreo de equipo (admin)
 *   MOD-06 · Citas confirmadas del asesor
 *   MOD-07 · Score y métricas por mes (nuevo)
 *   MOD-08 · Top clientes del asesor (nuevo)
 *   MOD-09 · Búsqueda live de pacientes (nuevo)
 *   MOD-10 · Calendario desde Google Calendar real (nuevo)
 *
 * CALENDARIOS CONFIGURADOS:
 *   HORARIO_DOCTOR_CAL_ID  → turnos de doctoras
 *   HORARIO_PERSONAL_CAL_ID → turnos de enfermería/personal
 */

// ══════════════════════════════════════════════════════════════
// IDs DE GOOGLE CALENDAR (configuración centralizada)
// ══════════════════════════════════════════════════════════════
var HORARIO_DOCTOR_CAL_ID =
  "3784316650e1124f3eb82be4f123001347a18fb1808e4292e0d0503925d4f967@group.calendar.google.com";

var HORARIO_PERSONAL_CAL_ID =
  "2db1abef4cf3589e8646a162324c5818ef5732918ae8a113c1792e759a43e0c2@group.calendar.google.com";

// ══════════════════════════════════════════════════════════════
// MOD-01 · OBTENER LEAD ACTIVO PARA LLAMAR
// ══════════════════════════════════════════════════════════════
// F01_START

function api_getNextLead() {
  var s   = cc_requireSession();
  var now = new Date();
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lr  = shL.getLastRow();

  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  if (lrLd < 2) return { ok: false, sin_leads: true, msg: "Sin leads en la base." };

  var leadsRaw = shLd.getRange(2, 1, lrLd - 1, 9).getValues();

  var llamMap = {};
  if (lr >= 2) {
    shL.getRange(2, 1, lr - 1, 20).getValues().forEach(function(r, i) {
      var num = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      if (!num) return;
      var ts  = r[LLAM_COL.ULT_TS] ? new Date(r[LLAM_COL.ULT_TS]) : null;
      var prx = r[LLAM_COL.PROX_REIN] ? new Date(r[LLAM_COL.PROX_REIN]) : null;
      var edo = _up(r[LLAM_COL.ESTADO]);
      var res = _up(r[LLAM_COL.RESULTADO]);
      var int = Number(r[LLAM_COL.INTENTO]) || 1;
      if (!llamMap[num] || (ts && llamMap[num].ts && ts > llamMap[num].ts)) {
        llamMap[num] = {
          estado: edo, intento: int, ultTs: ts, proxRein: prx,
          resultado: res, rowNum: i + 2,
          asesor: _up(r[LLAM_COL.ASESOR]),
          idAsesor: _norm(r[LLAM_COL.ID_ASESOR])
        };
      }
    });
  }

  var tier1 = [], tier2 = [], tier3 = [];
  var hoy   = _date(now);

  leadsRaw.forEach(function(r) {
    var num = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR] || "");
    if (!num) return;
    var trat    = _up(r[LEAD_COL.TRAT] || "");
    var anuncio = _norm(r[LEAD_COL.ANUNCIO] || "");
    var fecha   = r[LEAD_COL.FECHA];
    var llam    = llamMap[num];
    if (llam && ESTADOS_DESCARTADOS.has(llam.estado)) return;
    var lead = {
      num: num, trat: trat || "SIN TRATAMIENTO",
      anuncio: anuncio, fecha: _date(fecha),
      intento: llam ? llam.intento + 1 : 1,
      rowNum:  llam ? llam.rowNum : 0,
      wa: _wa(num)
    };
    if (!llam) {
      tier1.push(lead);
    } else if (llam.resultado === "REINTENTAR") {
      if (llam.proxRein && llam.proxRein <= now) tier2.push(lead);
    }
  });

  try {
    var shSeg = _sh(CFG.SHEET_SEGUIMIENTOS);
    var lrSeg = shSeg.getLastRow();
    if (lrSeg >= 2) {
      shSeg.getRange(2, 1, lrSeg - 1, 11).getValues().forEach(function(r, i) {
        var fechaProg = _date(r[SEG_COL.FECHA_PROG]);
        var idAsSeq   = _norm(r[SEG_COL.ID_ASESOR]);
        var estado    = _up(r[SEG_COL.ESTADO]);
        var num       = _normNum(r[SEG_COL.NUMERO]);
        if (estado === "PENDIENTE" && fechaProg <= hoy &&
            (idAsSeq === _norm(s.idAsesor) || !idAsSeq)) {
          tier3.push({
            num: num, trat: _up(r[SEG_COL.TRATAMIENTO] || ""),
            anuncio: "SEGUIMIENTO", fecha: fechaProg,
            intento: 1, rowNum: 0, segRowNum: i + 2,
            obs: _norm(r[SEG_COL.OBS]), wa: _wa(num)
          });
        }
      });
    }
  } catch(e) {}

  var lead = null, tier = "";
  if      (tier3.length > 0) { lead = tier3[0]; tier = "TIER 3 · SEGUIMIENTO"; }
  else if (tier1.length > 0) { lead = tier1[0]; tier = "TIER 1 · HOY"; }
  else if (tier2.length > 0) { lead = tier2[0]; tier = "TIER 2 · REINTENTO"; }

  if (!lead) return { ok: false, sin_leads: true,
    msg: "¡Base trabajada al 100%! Sin leads pendientes.",
    stats: { tier1: tier1.length, tier2: tier2.length, tier3: tier3.length }
  };

  var anuncioInfo = _getAnuncioInfo(lead.anuncio, lead.trat);
  return {
    ok: true, lead: lead, tier: tier, anuncio: anuncioInfo,
    stats: { tier1: tier1.length, tier2: tier2.length,
             tier3: tier3.length, total: tier1.length + tier2.length + tier3.length }
  };
}

function _getAnuncioInfo(anuncioNom, trat) {
  var nom = _norm(anuncioNom || trat || "");
  var pregunta = "", texto = nom;
  try {
    var sh = _sh(CFG.SHEET_CAT_ANUNCIOS);
    var lr = sh.getLastRow();
    if (lr >= 2) {
      var rows = sh.getRange(2, 1, lr - 1, 4).getValues();
      for (var i = 0; i < rows.length; i++) {
        if (_normSearch(_norm(rows[i][0])).includes(_normSearch(nom))) {
          texto    = _norm(rows[i][0]);
          pregunta = _norm(rows[i][2] || rows[i][3] || "");
          break;
        }
      }
    }
  } catch(e) {}
  if (!pregunta) pregunta = "¿Te gustaría conocer más sobre " + (trat || "nuestros tratamientos") + "?";
  return { nombre: texto, pregunta: pregunta };
}
// F01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · GUARDAR RESULTADO DE LLAMADA
// ══════════════════════════════════════════════════════════════
// F02_START

function api_saveCall(payload) {
  var s   = cc_requireSession();
  payload = payload || {};
  var ESTADO = _up(payload.estado || "");
  var num    = _phone(payload.numero || "");
  if (!num) throw new Error("Falta número de teléfono.");

  var now = new Date();
  var result = da_saveCallOutcome(payload, s);

  if (ESTADO === "CITA CONFIRMADA") {
    try { _guardarCitaDesdeCall(payload, s, now); } catch(eC) {
      Logger.log("Error guardando cita: " + eC.message);
    }
    // Guardar en Google Contacts si se solicitó
    if (payload.guardarGoogleContacts && payload.nombre) {
      try { _guardarEnGoogleContacts(payload); } catch(eG) {
        Logger.log("Error Google Contacts: " + eG.message);
      }
    }
  }

  if (ESTADO === "SEGUIMIENTO") {
    try { _guardarSeguimiento(payload, s, now); } catch(eS) {
      Logger.log("Error guardando seguimiento: " + eS.message);
    }
  }

  if (ESTADO === "CITA CONFIRMADA") {
    try {
      var admins = _asesoresActivos().filter(function(a) {
        return _normRole(a.role) === ROLES.ADMIN;
      });
      admins.forEach(function(adm) {
        _notifSheet().appendRow([
          _uid(), _date(now), _time(now), "CITA",
          "📅 Nueva cita: " + num,
          s.asesor + " confirmó cita — " + _norm(payload.tratamiento || ""),
          s.idAsesor, s.asesor, adm.idAsesor, adm.label || adm.nombre, ""
        ]);
      });
    } catch(e) {}
  }

  if (payload.segRowNum) {
    try {
      var shSeg = _sh(CFG.SHEET_SEGUIMIENTOS);
      shSeg.getRange(payload.segRowNum, SEG_COL.ESTADO + 1).setValue("CERRADO");
      shSeg.getRange(payload.segRowNum, SEG_COL.TS_ACTUALIZADO + 1).setValue(now);
    } catch(e) {}
  }

  try { api_setEstadoAsesor("EN LLAMADA"); } catch(e) {}
  cache_invalidateDashboard();
  return { ok: true, result: result };
}

function _guardarCitaDesdeCall(payload, s, now) {
  var sh  = _shAgenda();
  var cid = "C-" + _uid().slice(0, 8).toUpperCase();
  var num = _phone(payload.numero || "");
  var tipoAt = _up(payload.tipoAtencion || "");
  if (!tipoAt) tipoAt = _tipoAtencion(payload.tratamiento || "");
  var doctora = "";
  if (tipoAt === TIPO_ATENCION.DOCTORA) {
    var doctoras = _doctorasConAgenda();
    var sede     = _up(payload.sede || s.sede || "");
    var dSede    = doctoras.filter(function(d) {
      return !sede || _up(d.sede).includes(sede);
    });
    if (dSede.length) doctora = dSede[0].label || dSede[0].nombre;
  }
  sh.appendRow([
    cid, _date(payload.fechaCita || now), _norm(payload.tratamiento || ""),
    _norm(payload.tipoCita || "CONSULTA NUEVA"), _up(payload.sede || s.sede || ""),
    "'" + num, _norm(payload.nombre || ""), _norm(payload.apellido || ""),
    _norm(payload.dni || ""), _norm(payload.correo || ""),
    _norm(s.asesor), _norm(s.idAsesor), "CITA CONFIRMADA", "",
    _norm(payload.obs || ""), now, now, _norm(payload.horaCita || ""),
    _norm(payload.anuncio || ""), doctora, tipoAt, ""
  ]);
}

function _guardarSeguimiento(payload, s, now) {
  var sh  = _shSeguimientos();
  var sid = "SEG-" + _uid().slice(0, 8).toUpperCase();
  var num = _phone(payload.numero || "");
  var fechaProg = "", horaProg = "";
  if (payload.proxReintentoTs) {
    var dt = new Date(payload.proxReintentoTs);
    if (!isNaN(dt)) { fechaProg = _date(dt); horaProg = _time(dt); }
  }
  sh.appendRow([
    sid, fechaProg, horaProg, "'" + num,
    _norm(payload.tratamiento || ""), _norm(s.asesor), _norm(s.idAsesor),
    _norm(payload.obs || ""), "PENDIENTE", now, now
  ]);
}

/**
 * Guarda el paciente en Google Contacts con formato:
 * NOMBRE + MES AÑO + TRATAMIENTO
 */
function _guardarEnGoogleContacts(payload) {
  var nombre   = _norm(payload.nombre   || '');
  var apellido = _norm(payload.apellido || '');
  var trat     = _norm(payload.tratamiento || '').toUpperCase();
  var correo   = _norm(payload.correo || '');
  var num      = _phone(payload.numero || '');

  // Construir nombre en formato: NOMBRE APELLIDO · ABR AÑO · TRAT
  var meses = ['ENE','FEB','MAR','ABR','MAY','JUN',
               'JUL','AGO','SEP','OCT','NOV','DIC'];
  var now = new Date();
  var mesAbr = meses[now.getMonth()];
  var anio   = now.getFullYear();

  var nombreCompleto = nombre + ' ' + apellido;
  var lastName = apellido + ' - ' + mesAbr + ' ' + anio + ' - ' + trat;

  try {
    var body = {
      names: [{ givenName: nombre, familyName: lastName }],
      phoneNumbers: [{ value: num, type: 'mobile' }]
    };
    if (correo) body.emailAddresses = [{ value: correo, type: 'home' }];
    People.people.createContact(body);
    Logger.log("✅ Google Contacts guardado: " + nombreCompleto);
  } catch(e) {
    Logger.log("⚠️ Google Contacts error: " + e.message);
  }
}
// F02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · GESTIÓN DE SEGUIMIENTOS
// ══════════════════════════════════════════════════════════════
// F03_START

function api_listFollowups(filtro) {
  var s  = cc_requireSession();
  filtro = _low(filtro || "todos");
  var sh = _shSeguimientos();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [] };
  var hoy   = _date(new Date());
  var items = sh.getRange(2, 1, lr - 1, 11).getValues()
    .filter(function(r) {
      if (_up(r[SEG_COL.ESTADO]) !== "PENDIENTE") return false;
      if (_norm(r[SEG_COL.ID_ASESOR]) !== _norm(s.idAsesor) &&
          _norm(r[SEG_COL.ASESOR]).toUpperCase() !== _up(s.asesor)) return false;
      return true;
    })
    .map(function(r, i) {
      var fp   = _date(r[SEG_COL.FECHA_PROG]);
      var hp   = _norm(r[SEG_COL.HORA_PROG]);
      var tipo = fp < hoy ? "vencido" : fp === hoy ? "hoy" : "proximo";
      return {
        id: _norm(r[SEG_COL.ID]), rowNum: i + 2,
        fecha: fp, hora: hp,
        num:  _normNum(r[SEG_COL.NUMERO]),
        trat: _up(r[SEG_COL.TRATAMIENTO]),
        obs:  _norm(r[SEG_COL.OBS]),
        tipo: tipo, wa: _wa(_normNum(r[SEG_COL.NUMERO]))
      };
    })
    .filter(function(x) { return filtro === "todos" || x.tipo === filtro; })
    .sort(function(a, b) { return (a.fecha + a.hora) < (b.fecha + b.hora) ? -1 : 1; });

  return {
    ok: true, items: items,
    totales: {
      vencido: items.filter(function(x) { return x.tipo === "vencido"; }).length,
      hoy:     items.filter(function(x) { return x.tipo === "hoy";     }).length,
      proximo: items.filter(function(x) { return x.tipo === "proximo"; }).length,
      total:   items.length
    }
  };
}

function api_closeFollowup(rowNum) {
  cc_requireSession();
  var sh  = _shSeguimientos();
  var now = new Date();
  sh.getRange(rowNum, SEG_COL.ESTADO + 1).setValue("CERRADO");
  sh.getRange(rowNum, SEG_COL.TS_ACTUALIZADO + 1).setValue(now);
  return { ok: true };
}

// ── Aliases del ViewAdvisorCalls v2.1 ──
function api_getMySeguimientosT(token) {
  _setToken(token);
  var res = api_listFollowups("todos");
  if (!res || !res.ok) return { ok: true, items: [], totales: {} };
  var items = res.items.map(function(s) {
    return {
      segId:    s.rowNum ? String(s.rowNum) : (s.id || ''),
      rowNum:   s.rowNum || 0,
      num:      s.num || '',
      trat:     s.trat || '',
      obs:      s.obs  || '',
      fechaHora:(s.fecha || '') + (s.hora ? ' ' + s.hora : ''),
      vencido:  s.tipo === 'vencido',
      esHoy:    s.tipo === 'hoy',
      whatsapp: s.wa || ('https://wa.me/51' + (s.num||'').replace(/\D/g,''))
    };
  });
  return { ok: true, items: items, totales: res.totales || {} };
}

function api_cerrarSeguimientoT(token, segId) {
  _setToken(token);
  var rowNum = parseInt(segId, 10);
  if (!rowNum || isNaN(rowNum)) return { ok: false, error: 'rowNum invalido: ' + segId };
  return api_closeFollowup(rowNum);
}

function api_listFollowupsT(token, filtro) {
  _setToken(token); return api_listFollowups(filtro);
}
function api_closeFollowupT(token, rowNum) {
  _setToken(token); return api_closeFollowup(rowNum);
}
// F03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · LLAMADAS DEL ASESOR HOY
// ══════════════════════════════════════════════════════════════
// F04_START

function api_getMyCallsToday() {
  var s   = cc_requireSession();
  var hoy = _date(new Date());
  var sh  = _sh(CFG.SHEET_LLAMADAS);
  var lr  = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [], total: 0, citas: 0 };

  var items = sh.getRange(2, 1, lr - 1, 21).getValues()
    .filter(function(r) {
      var fd = _date(r[LLAM_COL.FECHA]);
      var ia = _norm(r[LLAM_COL.ID_ASESOR]);
      var na = _up(r[LLAM_COL.ASESOR]);
      return fd === hoy && (ia === _norm(s.idAsesor) || na === _up(s.asesor));
    })
    .map(function(r) {
      return {
        hora:      _time(r[LLAM_COL.HORA]),
        num:       _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]),
        trat:      _up(r[LLAM_COL.TRATAMIENTO]),
        estado:    _up(r[LLAM_COL.ESTADO]),
        subEstado: LLAM_COL.SUB_ESTADO !== undefined ? _norm(r[LLAM_COL.SUB_ESTADO]) : '',
        obs:       _norm(r[LLAM_COL.OBS]),
        intento:   Number(r[LLAM_COL.INTENTO]) || 1
      };
    })
    .sort(function(a, b) { return a.hora < b.hora ? 1 : -1; });

  var citas = items.filter(function(x) { return x.estado === "CITA CONFIRMADA"; }).length;
  return { ok: true, items: items, total: items.length, citas: citas };
}

function api_getMyCallsTodayT(token) { _setToken(token); return api_getMyCallsToday(); }
function api_getNextLeadT(token)     { _setToken(token); return api_getNextLead(); }
function api_saveCallT(token, payload){ _setToken(token); return api_saveCall(payload); }
// F04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · MONITOREO DEL EQUIPO (ADMIN)
// ══════════════════════════════════════════════════════════════
// F05_START

function api_getTeamMonitor() {
  cc_requireAdmin();
  var now = new Date(), hoy = _date(now);
  var sh  = _sh(CFG.SHEET_LLAMADAS);
  var lr  = sh.getLastRow();
  var byAsesor = {};
  if (lr >= 2) {
    sh.getRange(2, 1, lr - 1, 20).getValues().forEach(function(r) {
      if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
      var ia = _norm(r[LLAM_COL.ID_ASESOR]) || _up(r[LLAM_COL.ASESOR]);
      if (!ia) return;
      if (!byAsesor[ia]) byAsesor[ia] = {
        idAsesor: ia, nombre: _up(r[LLAM_COL.ASESOR]),
        llamadas: 0, citas: 0, ultTs: null, ultNum: ""
      };
      byAsesor[ia].llamadas++;
      if (_up(r[LLAM_COL.ESTADO]) === "CITA CONFIRMADA") byAsesor[ia].citas++;
      var ts = r[LLAM_COL.ULT_TS] ? new Date(r[LLAM_COL.ULT_TS]) : null;
      if (ts && (!byAsesor[ia].ultTs || ts > byAsesor[ia].ultTs)) {
        byAsesor[ia].ultTs  = ts;
        byAsesor[ia].ultNum = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      }
    });
  }
  var estadoMap = _getEstadosEquipo();
  var asesores  = _asesoresActivosCached().filter(function(a) { return a.role !== ROLES.DOCTORA; });
  var filas = asesores.map(function(a) {
    var id    = _norm(a.idAsesor);
    var nom   = _up(a.label || a.nombre || a.idAsesor);
    var datos = byAsesor[id] || byAsesor[nom] || { llamadas: 0, citas: 0, ultTs: null, ultNum: "" };
    var edoInfo = estadoMap[nom] || estadoMap[id] || { estado: "", minutos: null };
    var minsSin = datos.ultTs ? Math.floor((now - datos.ultTs) / 60000) : null;
    return {
      idAsesor: id, nombre: nom, llamadas: datos.llamadas, citas: datos.citas,
      ultTs: datos.ultTs ? _time(datos.ultTs) : "—", ultNum: datos.ultNum,
      minsSin: minsSin, estado: edoInfo.estado || (datos.llamadas > 0 ? "ACTIVO" : "INACTIVO"),
      semaforo: _calcSemaforo(minsSin, edoInfo.estado), sede: a.sede
    };
  });
  var totalLlam  = filas.reduce(function(s, f) { return s + f.llamadas; }, 0);
  var totalCitas = filas.reduce(function(s, f) { return s + f.citas;    }, 0);
  var alertas    = filas.filter(function(f) { return f.semaforo === "rojo"; }).length;
  return { ok: true, filas: filas, totalLlam: totalLlam, totalCitas: totalCitas, alertas: alertas, ts: _time(now) };
}

function _getEstadosEquipo() {
  var map = {};
  try {
    var sh  = _estadoSheet();
    var lr  = sh.getLastRow();
    if (lr < 2) return map;
    var now  = new Date();
    var data = sh.getRange(2, 1, lr - 1, 11).getValues();
    var visto = new Set();
    for (var i = data.length - 1; i >= 0; i--) {
      var r   = data[i];
      var nom = _up(_norm(r[1]));
      if (visto.has(nom)) continue;
      if (!r[6]) {
        var ini  = r[5] ? new Date(r[5]) : null;
        var mins = ini && !isNaN(ini) ? Math.floor((now - ini) / 60000) : null;
        map[nom] = { estado: _up(_norm(r[3])), minutos: mins };
        visto.add(nom);
      }
    }
  } catch(e) {}
  return map;
}

function api_getTeamMonitorT(token) { _setToken(token); return api_getTeamMonitor(); }
// F05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · CITAS CONFIRMADAS DEL ASESOR
// ══════════════════════════════════════════════════════════════
// F06_START

function api_getMyCitas(filtro, anio) {
  var s  = cc_requireSession();
  filtro = _low(filtro || 'activas');
  anio   = Number(anio) || new Date().getFullYear();
  var hoy = _date(new Date());
  var sh  = _shAgenda();
  var lr  = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [], totales: { activas:0, vencidas:0, sinFecha:0, total:0 } };

  var idAsesor  = _norm(s.idAsesor);
  var nomAsesor = _up(s.asesor);
  var activas = [], vencidas = [], sinFecha = [];

  sh.getRange(2, 1, lr - 1, 22).getValues().forEach(function(r) {
    var ia = _norm(r[AG_COL.ID_ASESOR]);
    var na = _up(r[AG_COL.ASESOR]);
    if (ia !== idAsesor && na !== nomAsesor) return;
    var fd     = _date(r[AG_COL.FECHA]);
    var estado = fd === '' ? 'SIN FECHA' : fd < hoy ? 'VENCIDA' : 'ACTIVA';
    var obj = {
      id: _norm(r[AG_COL.ID]), fecha: fd, hora: _normHora(r[AG_COL.HORA_CITA]),
      trat: _norm(r[AG_COL.TRATAMIENTO]), tipoCita: _norm(r[AG_COL.TIPO_CITA]),
      sede: _norm(r[AG_COL.SEDE]), num: _normNum(r[AG_COL.NUMERO]),
      nombre: _norm(r[AG_COL.NOMBRE]), apellido: _norm(r[AG_COL.APELLIDO]),
      estadoCita: _norm(r[AG_COL.ESTADO]), tipoAtencion: _norm(r[AG_COL.TIPO_ATENCION]),
      doctora: _norm(r[AG_COL.DOCTORA]), obs: _norm(r[AG_COL.OBS]), estado: estado,
      tsCreado: r[AG_COL.TS_CREADO] ? String(r[AG_COL.TS_CREADO]) : '',
      wa: _wa(_normNum(r[AG_COL.NUMERO]))
    };
    if      (estado === 'ACTIVA')   activas.push(obj);
    else if (estado === 'VENCIDA')  vencidas.push(obj);
    else                             sinFecha.push(obj);
  });

  var sortDesc = function(a, b) { return (a.fecha + a.hora) < (b.fecha + b.hora) ? 1 : -1; };
  activas.sort(sortDesc); vencidas.sort(sortDesc); sinFecha.sort(sortDesc);
  var filtered = filtro === 'activas'  ? activas
               : filtro === 'vencidas' ? vencidas
               : activas.concat(vencidas).concat(sinFecha);
  return {
    ok: true, items: filtered,
    totales: { activas: activas.length, vencidas: vencidas.length,
               sinFecha: sinFecha.length,
               total: activas.length + vencidas.length + sinFecha.length }
  };
}

function api_getMyCitasT(token, filtro, anio) {
  _setToken(token); return api_getMyCitas(filtro, anio);
}
// F06_END

// ══════════════════════════════════════════════════════════════
// MOD-07 · SCORE Y TIPIFICACIONES DEL ASESOR POR MES
// ══════════════════════════════════════════════════════════════
// F07_START

// ===== CTRL+F: api_getMyScoreMesT =====
function api_getMyScoreMesT(token, mes, anio) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  mes  = mes  || (now.getMonth() + 1);
  anio = anio || now.getFullYear();
  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes,     0, 23, 59, 59);
  var miId  = _norm(s.idAsesor);
  var miNom = _up(s.asesor);

  var leads = 0;
  try {
    var shLd = _sh(CFG.SHEET_LEADS);
    var lrLd = shLd.getLastRow();
    if (lrLd >= 2) {
      shLd.getRange(2, 1, lrLd - 1, 6).getValues().forEach(function(r) {
        if (_inRango(r[LEAD_COL.FECHA], desde, hasta)) leads++;
      });
    }
  } catch(e) {}

  var llamadas = 0, citas = 0;
  try {
    var shL = _sh(CFG.SHEET_LLAMADAS);
    var lrL = shL.getLastRow();
    if (lrL >= 2) {
      shL.getRange(2, 1, lrL - 1, 20).getValues().forEach(function(r) {
        if (!_inRango(r[LLAM_COL.FECHA], desde, hasta)) return;
        if (_norm(r[LLAM_COL.ID_ASESOR]) !== miId && _up(r[LLAM_COL.ASESOR]) !== miNom) return;
        llamadas++;
        if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') citas++;
      });
    }
  } catch(e) {}

  var asistieron = 0;
  try {
    var shA = _shAgenda();
    var lrA = shA.getLastRow();
    if (lrA >= 2) {
      shA.getRange(2, 1, lrA - 1, 22).getValues().forEach(function(r) {
        if (!_inRango(r[AG_COL.FECHA], desde, hasta)) return;
        if (_norm(r[AG_COL.ID_ASESOR]) !== miId && _up(r[AG_COL.ASESOR]) !== miNom) return;
        var est = _up(r[AG_COL.ESTADO]);
        if (est === 'ASISTIO' || est === 'EFECTIVA') asistieron++;
      });
    }
  } catch(e) {}

  var ventas = 0, fact = 0;
  try {
    var shV = _sh(CFG.SHEET_VENTAS);
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      shV.getRange(2, 1, lrV - 1, 19).getValues().forEach(function(r) {
        if (!_inRango(r[VENT_COL.FECHA], desde, hasta)) return;
        if (_up(r[VENT_COL.ASESOR]) !== miNom) return;
        ventas++; fact += Number(r[VENT_COL.MONTO]) || 0;
      });
    }
  } catch(e) {}

  return {
    ok: true,
    datos: { leads:leads, llamadas:llamadas, citas:citas,
             asistieron:asistieron, ventas:ventas, fact:fact, mes:mes, anio:anio }
  };
}

// ===== CTRL+F: api_getMyCallsByMesT =====
function api_getMyCallsByMesT(token, mes, anio) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  mes  = mes  || (now.getMonth() + 1);
  anio = anio || now.getFullYear();
  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes,     0, 23, 59, 59);
  var miId  = _norm(s.idAsesor);
  var miNom = _up(s.asesor);
  var items = [];
  try {
    var shL = _sh(CFG.SHEET_LLAMADAS);
    var lrL = shL.getLastRow();
    if (lrL >= 2) {
      shL.getRange(2, 1, lrL - 1, 21).getValues().forEach(function(r) {
        if (!_inRango(r[LLAM_COL.FECHA], desde, hasta)) return;
        if (_norm(r[LLAM_COL.ID_ASESOR]) !== miId && _up(r[LLAM_COL.ASESOR]) !== miNom) return;
        items.push({
          fecha:     _date(r[LLAM_COL.FECHA]),
          estado:    _up(r[LLAM_COL.ESTADO]),
          subEstado: (LLAM_COL.SUB_ESTADO !== undefined) ? _norm(r[LLAM_COL.SUB_ESTADO]) : ''
        });
      });
    }
  } catch(e) {}
  return { ok: true, items: items, total: items.length };
}

function api_saveNotasPacienteT(token, num, notas) {
  _setToken(token);
  return api_updatePatientNotes(num, notas);
}
// F07_END

// ══════════════════════════════════════════════════════════════
// MOD-08 · TOP CLIENTES DEL ASESOR
// ══════════════════════════════════════════════════════════════
// F08_START

// ===== CTRL+F: api_getMyTopClientesT =====
function api_getMyTopClientesT(token, limit) {
  _setToken(token);
  var s = cc_requireSession();
  limit = limit || 20;
  var miId  = _norm(s.idAsesor);
  var miNom = _up(s.asesor);
  var por   = {};

  try {
    var shV = _sh(CFG.SHEET_VENTAS);
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      shV.getRange(2, 1, lrV - 1, 19).getValues().forEach(function(r) {
        if (_up(r[VENT_COL.ASESOR]) !== miNom) return;
        var num = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
        if (!num) return;
        var fch = _date(r[VENT_COL.FECHA]);
        var nom = ((_norm(r[VENT_COL.NOMBRES])||'') + ' ' + (_norm(r[VENT_COL.APELLIDOS])||'')).trim();
        if (!por[num]) por[num] = {
          num:num, nombre:nom, fact:0, nVentas:0,
          ultFechaVenta:'', ultTrat:'',
          ultFechaCita:'', ultEstadoCita:'', ultTratCita:'',
          wa:_wa(num)
        };
        por[num].fact += Number(r[VENT_COL.MONTO]) || 0;
        por[num].nVentas++;
        if (fch > por[num].ultFechaVenta) {
          por[num].ultFechaVenta = fch;
          por[num].ultTrat = _norm(r[VENT_COL.TRATAMIENTO]);
          if (nom) por[num].nombre = nom;
        }
      });
    }
  } catch(e) {}

  try {
    var shA = _shAgenda();
    var lrA = shA.getLastRow();
    if (lrA >= 2) {
      shA.getRange(2, 1, lrA - 1, 22).getValues().forEach(function(r) {
        var ia = _norm(r[AG_COL.ID_ASESOR]), na = _up(r[AG_COL.ASESOR]);
        if (ia !== miId && na !== miNom) return;
        var num = _normNum(r[AG_COL.NUMERO]);
        if (!por[num]) return;
        var fch = _date(r[AG_COL.FECHA]);
        if (!por[num].ultFechaCita || fch > por[num].ultFechaCita) {
          por[num].ultFechaCita  = fch;
          por[num].ultEstadoCita = _norm(r[AG_COL.ESTADO]);
          por[num].ultTipoCita   = _norm(r[AG_COL.TIPO_CITA]);
          por[num].ultTratCita   = _norm(r[AG_COL.TRATAMIENTO]);
        }
      });
    }
  } catch(e) {}

  var lista = Object.values(por).sort(function(a,b){return b.fact-a.fact;}).slice(0,limit).map(function(c,i) {
    var ultVisita='', ultAccion='';
    if (c.ultFechaVenta && c.ultFechaCita) {
      if (c.ultFechaVenta >= c.ultFechaCita) { ultVisita=c.ultFechaVenta; ultAccion='Compra: '+c.ultTrat; }
      else { ultVisita=c.ultFechaCita; ultAccion=(c.ultTipoCita||'Cita')+': '+c.ultTratCita+(c.ultEstadoCita?' ('+c.ultEstadoCita+')':''); }
    } else if (c.ultFechaVenta) { ultVisita=c.ultFechaVenta; ultAccion='Compra: '+c.ultTrat; }
    else if (c.ultFechaCita)    { ultVisita=c.ultFechaCita; ultAccion=c.ultEstadoCita+': '+c.ultTratCita; }
    return { pos:i+1, num:c.num, nombre:c.nombre||c.num, fact:c.fact,
             nVentas:c.nVentas, ultVisita:ultVisita, ultAccion:ultAccion, wa:c.wa };
  });
  return { ok: true, items: lista, total: lista.length };
}
// F08_END

// ══════════════════════════════════════════════════════════════
// MOD-09 · BÚSQUEDA LIVE DE PACIENTES
// ══════════════════════════════════════════════════════════════
// F09_START

// ===== CTRL+F: api_searchPatientsLiveT =====
function api_searchPatientsLiveT(token, query) {
  _setToken(token);
  cc_requireSession();
  query = _norm(query || '');
  if (query.length < 2) return { ok: true, items: [] };
  var qUp = query.toUpperCase(), qNum = query.replace(/\D/g,'');
  var results = [], seen = {};
  try {
    var shP = _sh(CFG.SHEET_PACIENTES);
    var lrP = shP.getLastRow();
    if (lrP >= 2) {
      shP.getRange(2, 1, Math.min(lrP-1, 8000), 20).getValues().forEach(function(r) {
        if (results.length >= 8) return;
        var nom = ((_norm(r[PAC_COL.NOMBRES])||'') + ' ' + (_norm(r[PAC_COL.APELLIDOS])||'')).toUpperCase();
        var tel = _normNum(r[PAC_COL.TELEFONO]);
        if (nom.indexOf(qUp) < 0 && (!qNum || tel.indexOf(qNum) < 0)) return;
        if (seen[tel]) return;
        seen[tel] = true;
        results.push({
          nombres:   _norm(r[PAC_COL.NOMBRES]),
          apellidos: _norm(r[PAC_COL.APELLIDOS]),
          telefono:  tel,
          sede:      _norm(r[PAC_COL.SEDE]),
          trat:      '',
          estado:    _norm(r[PAC_COL.ESTADO]) || 'ACTIVO'
        });
      });
    }
  } catch(e) {}
  if (results.length < 4 && qNum && qNum.length >= 6) {
    try {
      var shV2 = _sh(CFG.SHEET_VENTAS);
      var lrV2 = shV2.getLastRow();
      if (lrV2 >= 2) {
        shV2.getRange(2, 1, Math.min(lrV2-1, 5000), 16).getValues().forEach(function(r) {
          if (results.length >= 8) return;
          var tel = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
          if (!tel || tel.indexOf(qNum) < 0 || seen[tel]) return;
          seen[tel] = true;
          results.push({
            nombres:   _norm(r[VENT_COL.NOMBRES]),
            apellidos: _norm(r[VENT_COL.APELLIDOS]),
            telefono:  tel,
            sede:      _norm(r[VENT_COL.SEDE]),
            trat:      _norm(r[VENT_COL.TRATAMIENTO]),
            estado:    'ACTIVO'
          });
        });
      }
    } catch(e) {}
  }
  return { ok: true, items: results.slice(0, 8) };
}
// F09_END

// ══════════════════════════════════════════════════════════════
// MOD-10 v2 · CALENDARIO DESDE GOOGLE CALENDAR REAL (SEMANAL)
// ══════════════════════════════════════════════════════════════
// F10_START

// ===== CTRL+F: api_getSemanaCalT =====
/**
 * Retorna los 7 días de una semana con turnos reales de GCal.
 * @param {string} token
 * @param {number} semanaOffset  0=actual, -1=anterior, 1=próxima
 * @param {string} sede          "SAN ISIDRO" | "PUEBLO LIBRE" | "" (ambas)
 */
function api_getSemanaCalT(token, semanaOffset, sede) {
  _setToken(token);
  cc_requireSession();
  semanaOffset = semanaOffset || 0;
  sede = _up(sede || '');

  // Calcular lunes de la semana
  var now    = new Date();
  var dow    = now.getDay();
  var diffL  = dow === 0 ? -6 : 1 - dow;
  var lunes  = new Date(now);
  lunes.setDate(now.getDate() + diffL + semanaOffset * 7);
  lunes.setHours(0, 0, 0, 0);

  // Generar los 7 días
  var dias = [];
  for (var i = 0; i < 7; i++) {
    var d = new Date(lunes);
    d.setDate(lunes.getDate() + i);
    dias.push(d);
  }

  var desde = new Date(lunes);
  var hasta = new Date(lunes);
  hasta.setDate(lunes.getDate() + 6);
  hasta.setHours(23, 59, 59);

  // Leer ambos calendarios
  var evDocRes = _leerEventosCalendarRango(HORARIO_DOCTOR_CAL_ID,   desde, hasta);
  var evEnfRes = _leerEventosCalendarRango(HORARIO_PERSONAL_CAL_ID, desde, hasta);

  var DIAS_ES = {0:'DOMINGO',1:'LUNES',2:'MARTES',3:'MIERCOLES',
                 4:'JUEVES',5:'VIERNES',6:'SABADO'};
  var hoy = _date(now);

  var resultado = dias.map(function(d) {
    var fd      = _date(d);
    var diaSem  = DIAS_ES[d.getDay()];
    var esDom   = d.getDay() === 0;
    var esHoy   = fd === hoy;
    var esPasado= d < new Date(now.getFullYear(), now.getMonth(), now.getDate());

    var doctoras  = [];
    var enfermeria = [];

    // ── Doctoras de GCal ──────────────────────────────────
    var evsDia = evDocRes[fd] || [];
    evsDia.forEach(function(ev) {
      var parsed = _parsearEventoDoctor(ev.titulo);
      var sedeDia = _sedeDesdeLocation(ev.location || '');
      if (sede && sedeDia && sedeDia !== sede) return;
      doctoras.push({
        label:    parsed.nombre,
        tipo:     parsed.tipo,
        horaIni:  ev.horaIni,
        horaFin:  ev.horaFin,
        sede:     sedeDia,
        fuente:   'gcal'
      });
    });

    // ── Enfermería de GCal ───────────────────────────────
    var evsEnf = evEnfRes[fd] || [];
    var porSede = {};
    evsEnf.forEach(function(ev) {
      var nombre  = _parsearNombreEnfermero(ev.titulo);
      var sedeDia = _sedeDesdeLocation(ev.location || '');
      if (!nombre) return;
      if (sede && sedeDia && sedeDia !== sede) return;
      if (!porSede[sedeDia]) porSede[sedeDia] = [];
      porSede[sedeDia].push(nombre);
    });
    Object.keys(porSede).forEach(function(s) {
      enfermeria.push({ sede: s, nombres: porSede[s] });
    });

    // Determinar estado visual del día
    var estado;
    if (esDom && !doctoras.length && !enfermeria.length) {
      estado = 'sin_horario';
    } else if (!doctoras.length && !enfermeria.length) {
      estado = 'sin_horario';
    } else {
      estado = 'disponible';
    }

    return {
      fecha:      fd,
      dia:        d.getDate(),
      mes:        d.getMonth() + 1,
      anio:       d.getFullYear(),
      diaSem:     diaSem,
      estado:     estado,
      doctoras:   doctoras,
      enfermeria: enfermeria,
      esHoy:      esHoy,
      esPasado:   esPasado
    };
  });

  return {
    ok:          true,
    semanaOffset: semanaOffset,
    dias:        resultado,
    desde:       _date(lunes),
    hasta:       _date(hasta)
  };
}

/**
 * Parsea el SUMMARY de un evento de doctora.
 * "(PROCED)DRA YESSICA PEREZ 5PM - 7.30PM" → { nombre, tipo }
 */
function _parsearEventoDoctor(summary) {
  summary = _norm(summary || '');
  // Extraer tipo entre paréntesis
  var tipoMatch = summary.match(/\(([^)]+)\)/);
  var tipo = tipoMatch ? tipoMatch[1].toUpperCase() : 'CONSULTA';
  // Nombre: quitar paréntesis y lo que viene después de un patrón de hora
  var sin_paren = summary.replace(/\([^)]*\)/g, '').trim();
  // Quitar el horario al final (números seguidos de am/pm o :)
  var nombre = sin_paren.replace(/\s+\d{1,2}[:.:]?\d{0,2}\s*[aApP][mM].*$/, '')
                         .replace(/\s+\d{1,2}[:.:]\d{2}.*$/, '')
                         .trim().toUpperCase();
  if (!nombre) nombre = sin_paren.trim().toUpperCase();
  return { nombre: nombre, tipo: tipo };
}

/**
 * Extrae el nombre del enfermero del SUMMARY.
 * "🟢 MIREYA - Turno Enfermería | SAN ISIDRO" → "MIREYA"
 */
function _parsearNombreEnfermero(summary) {
  var m = summary.match(/([A-ZÁÉÍÓÚÑ]{3,})/);
  if (!m) return '';
  var name = m[1].toUpperCase();
  // Excluir palabras comunes
  if (['TURNO', 'ENFERMERIA', 'VITAL', 'SAN', 'ISIDRO', 'PUEBLO', 'LIBRE'].indexOf(name) >= 0) return '';
  return name;
}

/**
 * Extrae la sede desde el LOCATION del evento.
 */
function _sedeDesdeLocation(location) {
  var loc = location.toLowerCase();
  if (loc.indexOf('brasil') >= 0 || loc.indexOf('pueblo libre') >= 0) return 'PUEBLO LIBRE';
  if (loc.indexOf('javier prado') >= 0 || loc.indexOf('san isidro') >= 0) return 'SAN ISIDRO';
  return '';
}

/**
 * Lee eventos de un Google Calendar entre dos fechas.
 * Retorna: { "YYYY-MM-DD": [{titulo, horaIni, horaFin, location, allDay}] }
 */
function _leerEventosCalendarRango(calId, desde, hasta) {
  var result = {};
  try {
    var cal = CalendarApp.getCalendarById(calId);
    if (!cal) return result;
    var eventos = cal.getEvents(desde, hasta);
    var TZ = CFG.TZ || 'America/Lima';
    eventos.forEach(function(ev) {
      var start  = ev.getStartTime();
      var end    = ev.getEndTime();
      var titulo = _norm(ev.getTitle());
      var allDay = ev.isAllDayEvent();
      var loc    = _norm(ev.getLocation() || '');
      // Recorrer días del evento (por si es multi-día)
      var dia = new Date(start.getFullYear(), start.getMonth(), start.getDate());
      var diaFin = new Date(end.getFullYear(), end.getMonth(), end.getDate());
      // Para eventos de todo el día, la fecha fin es exclusiva
      if (allDay) diaFin.setDate(diaFin.getDate() - 1);
      while (dia <= diaFin) {
        var fd = _date(dia);
        if (!result[fd]) result[fd] = [];
        result[fd].push({
          titulo:  titulo,
          horaIni: allDay ? '' : Utilities.formatDate(start, TZ, 'HH:mm'),
          horaFin: allDay ? '' : Utilities.formatDate(end,   TZ, 'HH:mm'),
          location: loc,
          allDay:  allDay
        });
        dia.setDate(dia.getDate() + 1);
      }
    });
  } catch(e) {
    Logger.log('_leerEventosCalendarRango [' + calId.slice(0,20) + ']: ' + e.message);
  }
  return result;
}

// Wrapper del calendario mensual (para compatibilidad)
// Actualizado para NO usar fallback del sheet cuando GCal retorna datos
function api_getCalendarioMesT(token, mes, anio, sede) {
  _setToken(token);
  cc_requireSession();
  var now  = new Date();
  mes  = mes  || (now.getMonth() + 1);
  anio = anio || now.getFullYear();
  sede = _up(sede || '');

  var diasEnMes   = new Date(anio, mes, 0).getDate();
  var primerDia   = new Date(anio, mes - 1, 1).getDay();
  var offsetLunes = primerDia === 0 ? 6 : primerDia - 1;

  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes, 0, 23, 59, 59);

  var evDoc = _leerEventosCalendarRango(HORARIO_DOCTOR_CAL_ID,   desde, hasta);
  var evEnf = _leerEventosCalendarRango(HORARIO_PERSONAL_CAL_ID, desde, hasta);

  var citasPorFecha = {};
  try {
    var shA = _shAgenda();
    var lrA = shA.getLastRow();
    if (lrA >= 2) {
      shA.getRange(2, 1, lrA - 1, 22).getValues().forEach(function(r) {
        if (_up(r[AG_COL.ESTADO]) === 'CANCELADA') return;
        if (!_inRango(r[AG_COL.FECHA], desde, hasta)) return;
        var sd = _up(r[AG_COL.SEDE]);
        if (sede && sd && !sd.includes(sede) && !sede.includes(sd)) return;
        var fd = _date(r[AG_COL.FECHA]);
        citasPorFecha[fd] = (citasPorFecha[fd] || 0) + 1;
      });
    }
  } catch(e) {}

  var DIAS_ES = {0:'DOMINGO',1:'LUNES',2:'MARTES',3:'MIERCOLES',4:'JUEVES',5:'VIERNES',6:'SABADO'};
  var hoy = _date(now);
  var dias = {};

  for (var d = 1; d <= diasEnMes; d++) {
    var fechaObj = new Date(anio, mes - 1, d);
    var fd       = _date(fechaObj);
    var diaSem   = DIAS_ES[fechaObj.getDay()];
    var esDom    = fechaObj.getDay() === 0;
    var esPasado = fechaObj < new Date(now.getFullYear(), now.getMonth(), now.getDate());

    var doctoras   = (evDoc[fd] || []).map(function(ev) {
      var p = _parsearEventoDoctor(ev.titulo);
      var s = _sedeDesdeLocation(ev.location || '');
      if (sede && s && s !== sede) return null;
      return { label: p.nombre, tipo: p.tipo, horaIni: ev.horaIni, horaFin: ev.horaFin, sede: s };
    }).filter(Boolean);

    var enfermeria = [];
    var porSede = {};
    (evEnf[fd] || []).forEach(function(ev) {
      var nombre  = _parsearNombreEnfermero(ev.titulo);
      var sedeDia = _sedeDesdeLocation(ev.location || '');
      if (!nombre || (sede && sedeDia && sedeDia !== sede)) return;
      if (!porSede[sedeDia]) porSede[sedeDia] = [];
      porSede[sedeDia].push(nombre);
    });
    Object.keys(porSede).forEach(function(s) {
      enfermeria.push({ sede: s, nombres: porSede[s] });
    });

    var citas  = citasPorFecha[fd] || 0;
    var estado = (!doctoras.length && !enfermeria.length) ? 'sin_horario' :
                 (citas === 0) ? 'libre' :
                 (citas >= 8)  ? 'lleno' :
                 (citas >= 5)  ? 'parcial' : 'disponible';

    dias[d] = {
      fecha:      fd,
      dia:        d,
      diaSem:     diaSem,
      estado:     estado,
      citas:      citas,
      doctoras:   doctoras,
      enfermeria: enfermeria,
      esHoy:      fd === hoy,
      esPasado:   esPasado
    };
  }

  return { ok: true, mes: mes, anio: anio, diasEnMes: diasEnMes, offsetLunes: offsetLunes, dias: dias };
}

// ── UTILIDADES HEREDADAS (compatibilidad) ────────────────────
function _leerEventosCalendar(calId, anio, mes) {
  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes, 0, 23, 59, 59);
  return _leerEventosCalendarRango(calId, desde, hasta);
}
function _minutosEntre(horaIni, horaFin) {
  try {
    var a=(horaIni||'09:00').split(':'), b=(horaFin||'21:00').split(':');
    return (parseInt(b[0])*60+parseInt(b[1]))-(parseInt(a[0])*60+parseInt(a[1]));
  } catch(e) { return 120; }
}
// F10_END

// ════════════════════════════════════════════════════════════════════
// GS_06 PARCHE v2 — Agregar al FINAL de GS_06_AdvisorCalls.gs
// Busca con Ctrl+F: PARCHE_SEMANA_LEADS_START
// ════════════════════════════════════════════════════════════════════
// PARCHE_SEMANA_LEADS_START

// ── IDs de Google Calendar (ya declarados arriba, no redeclarar) ──
// var HORARIO_DOCTOR_CAL_ID  = "3784316650e1124f3eb82be4f123001347a18fb1808e4292e0d0503925d4f967@group.calendar.google.com";
// var HORARIO_PERSONAL_CAL_ID = "2db1abef4cf3589e8646a162324c5818ef5732918ae8a113c1792e759a43e0c2@group.calendar.google.com";

// ════════════════════════════════════════════════════════════════════
// api_getSemanaCalT
// Retorna los 7 días de la semana con datos REALES del Google Calendar
// SIN fallback al Sheet. Solo muestra días que tienen eventos reales.
// ════════════════════════════════════════════════════════════════════
function api_getSemanaCalT(token, semanaOffset, sede) {
  _setToken(token);
  cc_requireSession();
  semanaOffset = semanaOffset || 0;
  sede = _up(sede || '');

  // Calcular lunes de la semana
  var now   = new Date();
  var dow   = now.getDay();
  var diffL = (dow === 0) ? -6 : (1 - dow);
  var lunes = new Date(now);
  lunes.setDate(now.getDate() + diffL + semanaOffset * 7);
  lunes.setHours(0, 0, 0, 0);

  // 7 días de la semana
  var diasSemana = [];
  for (var i = 0; i < 7; i++) {
    var d = new Date(lunes);
    d.setDate(lunes.getDate() + i);
    diasSemana.push(d);
  }

  // Rango para leer GCal
  var desde = new Date(lunes);
  var hasta = new Date(lunes);
  hasta.setDate(lunes.getDate() + 6);
  hasta.setHours(23, 59, 59);

  // Leer ambos calendarios para el rango completo de la semana
  var evDocMap = {};
  var evEnfMap = {};
  var TZ = (typeof CFG !== 'undefined' && CFG.TZ) ? CFG.TZ : 'America/Lima';

  function leerCalRango(calId) {
    var map = {};
    try {
      var cal = CalendarApp.getCalendarById(calId);
      if (!cal) return map;
      var evs = cal.getEvents(desde, hasta);
      evs.forEach(function(ev) {
        var start  = ev.getStartTime();
        var end    = ev.getEndTime();
        var allDay = ev.isAllDayEvent();
        var titulo = ev.getTitle();
        var loc    = ev.getLocation() || '';
        // Formatear fecha como YYYY-MM-DD
        var fd = Utilities.formatDate(start, TZ, 'yyyy-MM-dd');
        if (!map[fd]) map[fd] = [];
        map[fd].push({
          titulo:  titulo,
          horaIni: allDay ? '' : Utilities.formatDate(start, TZ, 'HH:mm'),
          horaFin: allDay ? '' : Utilities.formatDate(end,   TZ, 'HH:mm'),
          location: loc,
          allDay:  allDay
        });
      });
    } catch(e) {
      Logger.log('leerCalRango [' + calId.slice(0,20) + ']: ' + e.message);
    }
    return map;
  }

  evDocMap = leerCalRango(HORARIO_DOCTOR_CAL_ID);
  evEnfMap = leerCalRango(HORARIO_PERSONAL_CAL_ID);

  var hoyStr = Utilities.formatDate(now, TZ, 'yyyy-MM-dd');
  var DIAS_ES = ['DOMINGO','LUNES','MARTES','MIERCOLES','JUEVES','VIERNES','SABADO'];

  var resultado = diasSemana.map(function(d) {
    var fd     = Utilities.formatDate(d, TZ, 'yyyy-MM-dd');
    var diaSem = DIAS_ES[d.getDay()];
    var esHoy  = (fd === hoyStr);
    var hoyDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    var esPasado = (d < hoyDate);

    // ── Doctoras ──
    var doctoras = [];
    (evDocMap[fd] || []).forEach(function(ev) {
      var sedeDia = parsearSede(ev.location);
      if (sede && sedeDia && sedeDia !== sede) return;
      var parsed  = parsearEventoDoctor(ev.titulo);
      doctoras.push({
        label:   parsed.nombre,
        tipo:    parsed.tipo,
        horaIni: ev.horaIni,
        horaFin: ev.horaFin,
        sede:    sedeDia,
        fuente:  'gcal'
      });
    });

    // ── Enfermería agrupada por sede ──
    var enfPorSede = {};
    (evEnfMap[fd] || []).forEach(function(ev) {
      var sedeDia = parsearSede(ev.location);
      if (sede && sedeDia && sedeDia !== sede) return;
      var nombre  = parsearNombreEnfermero(ev.titulo);
      if (!nombre) return;
      if (!enfPorSede[sedeDia]) enfPorSede[sedeDia] = [];
      if (enfPorSede[sedeDia].indexOf(nombre) < 0) enfPorSede[sedeDia].push(nombre);
    });
    var enfermeria = Object.keys(enfPorSede).map(function(s) {
      return { sede: s, nombres: enfPorSede[s] };
    });

    var sinTurno = (doctoras.length === 0 && enfermeria.length === 0);
    var estado   = sinTurno ? 'sin_horario' : 'disponible';

    return {
      fecha:      fd,
      dia:        d.getDate(),
      mes:        d.getMonth() + 1,
      anio:       d.getFullYear(),
      diaSem:     diaSem,
      estado:     estado,
      doctoras:   doctoras,
      enfermeria: enfermeria,
      esHoy:      esHoy,
      esPasado:   esPasado
    };
  });

  return {
    ok:           true,
    semanaOffset: semanaOffset,
    dias:         resultado,
    desde:        Utilities.formatDate(desde, TZ, 'yyyy-MM-dd'),
    hasta:        Utilities.formatDate(hasta, TZ, 'yyyy-MM-dd')
  };
}

// Helper: extraer sede del LOCATION
function parsearSede(location) {
  if (!location) return '';
  var loc = location.toLowerCase();
  if (loc.indexOf('brasil') >= 0 || loc.indexOf('pueblo libre') >= 0) return 'PUEBLO LIBRE';
  if (loc.indexOf('javier prado') >= 0 || loc.indexOf('san isidro') >= 0) return 'SAN ISIDRO';
  return '';
}

// Helper: parsear "(PROCED)DRA YESSICA PEREZ 5PM - 7.30PM" → {nombre, tipo}
function parsearEventoDoctor(summary) {
  summary = (summary || '').toUpperCase();
  var tipoMatch = summary.match(/\(([^)]+)\)/);
  var tipo = tipoMatch ? tipoMatch[1] : 'CONSULTA';
  var sinParen = summary.replace(/\([^)]*\)/g, '').trim();
  // Quitar horarios del nombre: cualquier número seguido de am/pm o ":"
  var nombre = sinParen.replace(/\s+\d{1,2}[:.]\d{0,2}\s*[AP]?M.*$/i, '')
                        .replace(/\s+\d{1,2}[AP]M.*$/i, '')
                        .trim();
  return { nombre: nombre || sinParen, tipo: tipo };
}

// Helper: extraer nombre enfermero de "🟢 MIREYA - Turno Enfermería | SAN ISIDRO"
function parsearNombreEnfermero(summary) {
  var match = (summary || '').match(/([A-ZÁÉÍÓÚÑ]{3,})/);
  if (!match) return '';
  var nombre = match[1].toUpperCase();
  var excluir = ['TURNO','ENFERMERIA','VITAL','SAN','ISIDRO','PUEBLO','LIBRE','ENFERM'];
  if (excluir.indexOf(nombre) >= 0) return '';
  return nombre;
}

// ════════════════════════════════════════════════════════════════════
// api_getLeadsCampanaMesT
// Cruza LEADS + LLAMADAS + VENTAS con columnas reales del Sheet
//
// CONSOLIDADO DE LLAMADAS:
//   Col A(0)=FECHA, Col B(1)=NUMERO, Col D(3)=ESTADO,
//   Col G(6)=ASESOR, Col I(8)=NUMERO_LIMPIO
//
// CONSOLIDADO DE LEADS:
//   Col A(0)=FECHA, Col B(1)=CELULAR,
//   Col F(5)=HORA_INGRESO, Col G(6)=NUMERO_LIMPIO
// ════════════════════════════════════════════════════════════════════
function api_getLeadsCampanaMesT(token, mes, anio) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  mes  = mes  || (now.getMonth() + 1);
  anio = anio || now.getFullYear();

  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes,     0, 23, 59, 59);

  var miNom = _up(s.asesor || '');
  var miId  = _norm(s.idAsesor || '');

  // ── 1. Leer LEADS del mes (por HORA INGRESO DE LEAD) ──────────────
  var leadsDelMes = {};   // numLimpio → fechaIngreso
  try {
    var shLd = _sh(CFG.SHEET_LEADS);
    var lrLd = shLd.getLastRow();
    if (lrLd >= 2) {
      shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
        // Col G (índice 6) = NUMERO_LIMPIO
        // Col F (índice 5) = HORA INGRESO DE LEAD
        var numL = limpia(r[6] || r[1]);  // NUMERO_LIMPIO o CELULAR
        if (!numL) return;
        var fechaIn = r[5] || r[0];       // HORA INGRESO o FECHA
        if (_inRango(fechaIn, desde, hasta)) {
          leadsDelMes[numL] = fechaIn;
        }
      });
    }
  } catch(e) {
    Logger.log('api_getLeadsCampanaMesT LEADS: ' + e.message);
  }

  var totalLeads = Object.keys(leadsDelMes).length;

  // ── 2. Cruzar con LLAMADAS del asesor en el período ───────────────
  var llamadasPorNum = {};    // numLimpio → {count, estados}
  var todosNums      = {};    // todos los nums llamados (para clientes únicos)
  try {
    var shL = _sh(CFG.SHEET_LLAMADAS);
    var lrL = shL.getLastRow();
    if (lrL >= 2) {
      shL.getRange(2, 1, lrL - 1, 10).getValues().forEach(function(r) {
        var fecha  = r[0];
        var num    = limpia(r[8] || r[1]);  // NUMERO_LIMPIO (col I=8) o NUMERO (col B=1)
        var estado = _up(r[3] || '');       // ESTADO col D=3
        var asesor = _up(r[6] || '');       // ASESOR col G=6

        if (!num) return;
        if (!_inRango(fecha, desde, hasta)) return;
        // Filtrar por asesor logueado
        if (miNom && asesor && asesor !== miNom) {
          // Intentar con ID (col J=9)
          var idCol = _norm(r[9] || '');
          if (miId && idCol && idCol !== miId) return;
          if (!idCol) return; // no coincide nombre ni hay ID → skip
        }

        // Todos los clientes únicos
        todosNums[num] = true;

        // Solo contar si era lead del mes
        if (leadsDelMes[num]) {
          if (!llamadasPorNum[num]) llamadasPorNum[num] = { count: 0, estados: [] };
          llamadasPorNum[num].count++;
          llamadasPorNum[num].estados.push(estado);
        }
      });
    }
  } catch(e) {
    Logger.log('api_getLeadsCampanaMesT LLAMADAS: ' + e.message);
  }

  var leadsLlamados    = Object.keys(llamadasPorNum).length;
  var clientesUnicos   = Object.keys(todosNums).length;

  // Leads con CITA CONFIRMADA
  var leadsCitas = 0;
  Object.keys(llamadasPorNum).forEach(function(num) {
    var tieneClta = llamadasPorNum[num].estados.some(function(e) {
      return e === 'CITA CONFIRMADA' || e === 'CITA';
    });
    if (tieneClta) leadsCitas++;
  });

  // ── 3. Cruzar con VENTAS del período ─────────────────────────────
  var leadsVentas = 0, leadsFact = 0;
  try {
    var shV = _sh(CFG.SHEET_VENTAS);
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      shV.getRange(2, 1, lrV - 1, 20).getValues().forEach(function(r) {
        var fecha = r[VENT_COL.FECHA] || r[0];
        if (!_inRango(fecha, desde, hasta)) return;
        var numV  = limpia(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR] || r[3]);
        var asesorV = _up(r[VENT_COL.ASESOR] || r[4] || '');
        if (miNom && asesorV && asesorV !== miNom) return;
        if (!numV || !leadsDelMes[numV]) return;
        var monto = parseFloat(r[VENT_COL.MONTO] || r[7]) || 0;
        leadsVentas++;
        leadsFact += monto;
      });
    }
  } catch(e) {
    Logger.log('api_getLeadsCampanaMesT VENTAS: ' + e.message);
  }

  return {
    ok:                 true,
    mes:                mes,
    anio:               anio,
    leadsNuevos:        totalLeads,
    leadsLlamados:      leadsLlamados,
    pctLlamados:        totalLeads > 0 ? Math.round(leadsLlamados / totalLeads * 100) : 0,
    leadsCitas:         leadsCitas,
    leadsVentas:        leadsVentas,
    leadsFact:          leadsFact,
    clientesUnicos:     clientesUnicos,
    clientesUnicosCamp: leadsLlamados
  };
}

// Helper local: limpiar número a solo dígitos
function limpia(v) {
  return String(v || '').replace(/[^0-9]/g, '');
}

// PARCHE_SEMANA_LEADS_END
// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════

function test_AdvisorCalls() {
  Logger.log("=== GS_06_AdvisorCalls v2.0 TEST ===");
  Logger.log("Funciones disponibles:");
  Logger.log("  api_getNextLeadT(token)");
  Logger.log("  api_saveCallT(token, payload)");
  Logger.log("  api_getMyCallsTodayT(token)");
  Logger.log("  api_listFollowupsT(token, filtro)");
  Logger.log("  api_getMyCitasT(token, filtro, anio)");
  Logger.log("  api_getTeamMonitorT(token) [solo admin]");
  Logger.log("  api_getMySeguimientosT(token) [nuevo]");
  Logger.log("  api_cerrarSeguimientoT(token, segId) [nuevo]");
  Logger.log("  api_getMyScoreMesT(token, mes, anio) [nuevo]");
  Logger.log("  api_getMyCallsByMesT(token, mes, anio) [nuevo]");
  Logger.log("  api_getMyTopClientesT(token, limit) [nuevo]");
  Logger.log("  api_searchPatientsLiveT(token, query) [nuevo]");
  Logger.log("  api_getCalendarioMesT(token, mes, anio, sede) [nuevo - Google Calendar]");
  Logger.log("  api_getDoctorInfoT(token, docLabel, fecha, sede) [nuevo]");
  Logger.log("=== OK ===");
}