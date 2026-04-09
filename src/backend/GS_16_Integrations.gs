/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_16_Integrations.gs                      ║
 * ║  Módulo: Integraciones Externas                             ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Google Calendar — sincronización de citas
 *   MOD-02 · Bridge Chatbot / WhatBot (WhatBot by CREACTIVE OS)
 *   MOD-03 · Webhook entrante (leads desde formularios externos)
 *   MOD-04 · Utilidades de integración y logs
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · GOOGLE CALENDAR
// ══════════════════════════════════════════════════════════════
// I01_START

/**
 * api_syncCitaCalendar — Crea o actualiza un evento en GCal para una cita
 * @param {string} agendaId — ID de la fila en AGENDA_CITAS
 */
function api_syncCitaCalendar(agendaId) {
  cc_requireSession();
  agendaId = _norm(agendaId);
  if (!agendaId || !GCAL_CONFIG.ACTIVO) return { ok: false, msg: 'GCal desactivado o sin ID' };

  var shAg = _shAgenda();
  var lr   = shAg.getLastRow();
  if (lr < 2) return { ok: false, msg: 'Sin citas' };

  // Buscar la fila por ID (col A)
  var ids = shAg.getRange(2, AG_COL.ID + 1, lr - 1, 1).getValues();
  var rowIdx = -1;
  for (var i = 0; i < ids.length; i++) {
    if (_norm(ids[i][0]) === agendaId) { rowIdx = i + 2; break; }
  }
  if (rowIdx === -1) return { ok: false, msg: 'Cita no encontrada: ' + agendaId };

  var row      = shAg.getRange(rowIdx, 1, 1, 22).getValues()[0];
  var fechaStr = _date(row[AG_COL.FECHA]);
  var horaStr  = _normHora(row[AG_COL.HORA_CITA]) || '10:00';
  var trat     = _norm(row[AG_COL.TRATAMIENTO]);
  var nombre   = _norm(row[AG_COL.NOMBRE]) + ' ' + _norm(row[AG_COL.APELLIDO]);
  var sede     = _norm(row[AG_COL.SEDE]);
  var asesor   = _norm(row[AG_COL.ASESOR]);
  var doctora  = _norm(row[AG_COL.DOCTORA]);
  var obs      = _norm(row[AG_COL.OBS]);
  var gcalId   = _norm(row[AG_COL.GCAL_ID]);

  // Construir fechas de inicio y fin (30 min por defecto)
  var startDt = new Date(fechaStr + 'T' + horaStr + ':00');
  var endDt   = new Date(startDt.getTime() + AGENDA_CONFIG.SLOT_DURACION_MIN * 60000);

  var titulo  = '🏥 ' + nombre.trim() + ' · ' + trat;
  var desc    = [
    'Paciente: ' + nombre.trim(),
    'Tratamiento: ' + trat,
    'Sede: ' + sede,
    'Asesor: ' + asesor,
    'Doctora: ' + doctora,
    obs ? 'Obs: ' + obs : ''
  ].filter(Boolean).join('\n');

  try {
    var cal = CalendarApp.getCalendarById(GCAL_CONFIG.TURNOS_ID);
    if (!cal) return { ok: false, msg: 'Calendario no encontrado. Verificar GCAL_CONFIG.TURNOS_ID.' };

    var event;
    if (gcalId) {
      // Actualizar evento existente
      try {
        event = cal.getEventById(gcalId);
        if (event) {
          event.setTitle(titulo);
          event.setDescription(desc);
          event.setTime(startDt, endDt);
        } else {
          gcalId = ''; // Recrear si no existe
        }
      } catch(e) { gcalId = ''; }
    }

    if (!gcalId) {
      // Crear nuevo evento
      event  = cal.createEvent(titulo, startDt, endDt, { description: desc });
      gcalId = event.getId();
      // Guardar GCAL_ID en la hoja
      shAg.getRange(rowIdx, AG_COL.GCAL_ID + 1).setValue(gcalId);
    }

    return { ok: true, gcalId: gcalId, titulo: titulo };
  } catch(e) {
    Logger.log('api_syncCitaCalendar error: ' + e.message);
    return { ok: false, msg: e.message };
  }
}

/**
 * api_deleteCitaCalendar — Elimina el evento de GCal cuando se cancela una cita
 */
function api_deleteCitaCalendar(gcalId) {
  cc_requireSession();
  if (!gcalId || !GCAL_CONFIG.ACTIVO) return { ok: true };
  try {
    var cal   = CalendarApp.getCalendarById(GCAL_CONFIG.TURNOS_ID);
    var event = cal.getEventById(gcalId);
    if (event) event.deleteEvent();
    return { ok: true };
  } catch(e) {
    return { ok: false, msg: e.message };
  }
}

/**
 * api_getCalendarSlots — Slots disponibles de doctora en una fecha
 * Consulta Google Calendar para ver ocupados y retorna disponibles
 * @param {string} fecha      "yyyy-MM-dd"
 * @param {string} sede
 * @param {string} doctora
 * @param {string} tipoAtencion "DOCTORA" | "ENFERMERIA"
 */
function api_getCalendarSlots(fecha, sede, doctora, tipoAtencion) {
  cc_requireSession();
  // Usa la lógica de GS_08_Agenda si existe, o fallback
  try {
    if (typeof api_getAgendaSlots === 'function') {
      return api_getAgendaSlots(fecha, sede, doctora, tipoAtencion);
    }
  } catch(e) {}
  return { ok: true, slots: [], msg: 'api_getAgendaSlots no disponible' };
}

/** Wrappers token */
function api_syncCitaCalendarT(token, agendaId)        { _setToken(token); return api_syncCitaCalendar(agendaId); }
function api_deleteCitaCalendarT(token, gcalId)        { _setToken(token); return api_deleteCitaCalendar(gcalId); }
function api_getCalendarSlotsT(token, f, s, d, t)      { _setToken(token); return api_getCalendarSlots(f, s, d, t); }
// I01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · BRIDGE CHATBOT / WHATBOT
// ══════════════════════════════════════════════════════════════
// I02_START

/**
 * api_chatbotInboundLead — Recibe un lead desde WhatBot / chatbot externo
 * Endpoint para ser llamado desde Node.js / Railway con autenticación por API Key
 * @param {Object} payload {numero, trat, anuncio, pregunta, horaIngreso, apiKey}
 */
function api_chatbotInboundLead(payload) {
  payload = payload || {};

  // Verificar API Key
  var apiKey = _norm(payload.apiKey || '');
  if (!_validarApiKey(apiKey)) {
    return { ok: false, error: 'API Key inválida' };
  }

  var num  = _phone(payload.numero || '');
  if (!num) return { ok: false, error: 'Número inválido' };

  var now  = new Date();
  var trat = _up(_norm(payload.trat || ''));
  var anuncio = _norm(payload.anuncio || '');
  var pregunta = _norm(payload.pregunta || '');

  // Verificar si el lead ya existe en el mes actual
  var mesStr = _date(now).slice(0, 7);
  var sh     = _sh(CFG.SHEET_LEADS);
  var lr     = sh.getLastRow();
  if (lr >= 2) {
    var nums = sh.getRange(2, LEAD_COL.NUM_LIMPIO + 1, lr - 1, 1).getValues();
    for (var i = 0; i < nums.length; i++) {
      var existNum = _normNum(nums[i][0]);
      if (existNum === num) {
        // Lead duplicado en este mes
        return { ok: true, duplicate: true, num: num };
      }
    }
  }

  // Registrar nuevo lead
  sh.appendRow([
    _date(now),          // A FECHA
    "'" + num,           // B CELULAR
    trat,                // C TRATAMIENTO
    anuncio,             // D ANUNCIO
    pregunta,            // E PREGUNTAS
    _time(now),          // F HORA
    '',                  // G reservado
    num                  // H NUM_LIMPIO
  ]);

  // Registrar en log de integraciones
  _logIntegracion('WHATBOT_LEAD', { num: num, trat: trat, anuncio: anuncio });

  return { ok: true, duplicate: false, num: num, fecha: _date(now) };
}

/**
 * api_chatbotGetInfo — WhatBot consulta información de un número
 * Para responder preguntas sobre estados, citas, etc.
 * @param {Object} payload {numero, apiKey, consulta}
 */
function api_chatbotGetInfo(payload) {
  payload = payload || {};
  var apiKey = _norm(payload.apiKey || '');
  if (!_validarApiKey(apiKey)) return { ok: false, error: 'API Key inválida' };

  var num = _phone(payload.numero || '');
  if (!num) return { ok: false, error: 'Número inválido' };

  // Buscar en llamadas: último estado
  var shL  = _sh(CFG.SHEET_LLAMADAS);
  var lrL  = shL.getLastRow();
  var ultEstado = '';
  var ultTrat   = '';
  if (lrL >= 2) {
    var rows = shL.getRange(2, 1, lrL - 1, 20).getValues();
    for (var i = rows.length - 1; i >= 0; i--) {
      var rNum = _normNum(rows[i][LLAM_COL.NUM_LIMPIO] || rows[i][LLAM_COL.NUMERO]);
      if (rNum === num) {
        ultEstado = _up(rows[i][LLAM_COL.ESTADO]);
        ultTrat   = _up(_norm(rows[i][LLAM_COL.TRATAMIENTO]));
        break;
      }
    }
  }

  // Buscar cita próxima en agenda
  var shAg = _shAgenda();
  var lrAg = shAg.getLastRow();
  var citaProxima = null;
  var hoy = _date(new Date());
  if (lrAg >= 2) {
    shAg.getRange(2, 1, lrAg - 1, 22).getValues().forEach(function(r) {
      if (_normNum(r[AG_COL.NUMERO]) !== num) return;
      var fd = _date(r[AG_COL.FECHA]);
      if (fd >= hoy && _up(r[AG_COL.ESTADO]) !== 'CANCELADA') {
        if (!citaProxima || fd < citaProxima.fecha) {
          citaProxima = {
            fecha:    fd,
            trat:     _norm(r[AG_COL.TRATAMIENTO]),
            hora:     _normHora(r[AG_COL.HORA_CITA]),
            sede:     _norm(r[AG_COL.SEDE]),
            estado:   _norm(r[AG_COL.ESTADO])
          };
        }
      }
    });
  }

  return {
    ok:          true,
    num:         num,
    ultEstado:   ultEstado,
    ultTrat:     ultTrat,
    citaProxima: citaProxima,
    tieneVenta:  _tieneVenta(num)
  };
}

/** Verifica si un número tiene venta registrada */
function _tieneVenta(num) {
  try {
    var sh = _sh(CFG.SHEET_VENTAS);
    var lr = sh.getLastRow();
    if (lr < 2) return false;
    var nums = sh.getRange(2, VENT_COL.NUM_LIMPIO + 1, lr - 1, 1).getValues();
    for (var i = 0; i < nums.length; i++) {
      if (_normNum(nums[i][0]) === num) return true;
    }
    return false;
  } catch(e) { return false; }
}

/** Valida API Key contra la configuración */
function _validarApiKey(key) {
  if (!key) return false;
  try {
    var sh = _sh(CFG.SHEET_CONFIG);
    var lr = sh.getLastRow();
    if (lr < 2) return key === 'CREACTIVE_DEV_KEY'; // Fallback para desarrollo
    var rows = sh.getRange(2, 1, lr - 1, 2).getValues();
    for (var i = 0; i < rows.length; i++) {
      if (_norm(rows[i][0]) === 'API_KEY' && _norm(rows[i][1]) === key) return true;
    }
  } catch(e) {}
  return key === 'CREACTIVE_DEV_KEY';
}

/** Wrappers para endpoint externo (no requieren token interno) */
function api_chatbotInboundLeadExt(payload)  { return api_chatbotInboundLead(payload); }
function api_chatbotGetInfoExt(payload)       { return api_chatbotGetInfo(payload); }
// I02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · WEBHOOK ENTRANTE
// ══════════════════════════════════════════════════════════════
// I03_START

/**
 * doPost — Endpoint HTTP POST para webhooks externos
 * Recibe leads desde Facebook Ads, Landing Pages, WhatBot, etc.
 * URL: /exec (POST)
 */
function doPost(e) {
  try {
    var body    = JSON.parse(e.postData.contents || '{}');
    var source  = _up(_norm(body.source || ''));
    var apiKey  = _norm(body.apiKey || '');

    if (!_validarApiKey(apiKey)) {
      return ContentService
        .createTextOutput(JSON.stringify({ ok: false, error: 'Unauthorized' }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    var result;
    switch(source) {
      case 'WHATBOT':
      case 'CHATBOT':
        result = api_chatbotInboundLead(body);
        break;
      case 'FACEBOOK':
      case 'LANDING':
      case 'FORM':
        result = _inboundLeadForm(body);
        break;
      default:
        result = { ok: false, error: 'Source desconocido: ' + source };
    }

    return ContentService
      .createTextOutput(JSON.stringify(result))
      .setMimeType(ContentService.MimeType.JSON);
  } catch(err) {
    return ContentService
      .createTextOutput(JSON.stringify({ ok: false, error: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * _inboundLeadForm — Registra lead desde formulario externo
 */
function _inboundLeadForm(body) {
  var num = _phone(body.numero || body.celular || body.phone || '');
  if (!num) return { ok: false, error: 'Sin número de teléfono' };

  var sh  = _sh(CFG.SHEET_LEADS);
  var now = new Date();

  sh.appendRow([
    _date(now),
    "'" + num,
    _up(_norm(body.trat || body.tratamiento || '')),
    _norm(body.anuncio  || body.utm_source  || ''),
    _norm(body.pregunta || body.mensaje     || ''),
    _time(now),
    '',
    num
  ]);

  _logIntegracion('FORM_LEAD', { num: num, source: body.source });
  return { ok: true, num: num };
}
// I03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · LOGS DE INTEGRACIÓN
// ══════════════════════════════════════════════════════════════
// I04_START

/**
 * Registra una integración en LOG_AUDITORIA
 */
function _logIntegracion(tipo, data) {
  try {
    var sh  = _sh(CFG.LOG_AUDITORIA);
    var now = new Date();
    sh.appendRow([
      _uid(),
      _date(now),
      _time(now),
      tipo,
      JSON.stringify(data || {}),
      'INTEGRACION'
    ]);
  } catch(e) {}
}

/**
 * api_getIntegracionStatus — Estado de todas las integraciones
 */
function api_getIntegracionStatus() {
  cc_requireAdmin();
  var gcalActivo = false;
  try {
    var cal = CalendarApp.getCalendarById(GCAL_CONFIG.TURNOS_ID);
    gcalActivo = !!cal;
  } catch(e) {}

  return {
    ok: true,
    integraciones: {
      gcal:    { activo: gcalActivo && GCAL_CONFIG.ACTIVO, id: GCAL_CONFIG.TURNOS_ID },
      whatbot: { activo: true, desc: 'WhatBot by CREACTIVE OS — Node.js + Railway' },
      webhook: { activo: true, desc: 'doPost endpoint activo' }
    }
  };
}

/** Wrapper token */
function api_getIntegracionStatusT(token) {
  _setToken(token); return api_getIntegracionStatus();
}
// I04_END

function test_Integrations() {
  Logger.log('=== GS_16_Integrations TEST ===');
  Logger.log('GCal ID: ' + GCAL_CONFIG.TURNOS_ID);
  Logger.log('API Key válida (dev): ' + _validarApiKey('CREACTIVE_DEV_KEY'));
  Logger.log('=== OK ===');
}