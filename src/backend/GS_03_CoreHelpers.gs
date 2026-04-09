/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_03_CoreHelpers.gs                       ║
 * ║  Módulo: Helpers y Utilidades Puras                         ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config                                 ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Normalización de texto
 *   MOD-02 · Formateo de fechas y horas
 *   MOD-03 · Manejo de teléfonos y WhatsApp
 *   MOD-04 · Helpers de hojas (Sheets)
 *   MOD-05 · Helpers de notificaciones y logs
 *   MOD-06 · Helpers de negocio
 *   MOD-07 · Utilidades generales
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · NORMALIZACIÓN DE TEXTO
// ══════════════════════════════════════════════════════════════
// C01_START

/** Normaliza: trim + string seguro */
function _norm(s) {
  return String(s == null ? "" : s).trim();
}

/** Normaliza a MAYÚSCULAS */
function _up(s) {
  return _norm(s).toUpperCase();
}

/** Normaliza a minúsculas */
function _low(s) {
  return _norm(s).toLowerCase();
}

/** Elimina acentos y normaliza para búsqueda */
function _normSearch(s) {
  return _norm(s)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toUpperCase();
}

/** Determina el tipo de atención según el tratamiento */
function _tipoAtencion(tratamiento) {
  var t = _up(tratamiento || "");
  for (var i = 0; i < TRAT_ENFERMERIA.length; i++) {
    if (t.indexOf(TRAT_ENFERMERIA[i]) >= 0) return TIPO_ATENCION.ENFERMERIA;
  }
  return TIPO_ATENCION.DOCTORA;
}
// C01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · FORMATEO DE FECHAS Y HORAS
// ══════════════════════════════════════════════════════════════
// C02_START

/** Fecha actual */
function _now() { return new Date(); }

/**
 * Convierte cualquier valor a string de fecha "yyyy-MM-dd"
 * Acepta: Date, string ISO, string dd/MM/yyyy, número serial
 */
function _date(d) {
  if (!d) return "";
  if (typeof d === "string") {
    var m1 = d.match(/^(\d{4}-\d{2}-\d{2})/);
    if (m1) return m1[1];
    var m2 = d.match(/^(\d{2})\/(\d{2})\/(\d{4})/);
    if (m2) return m2[3] + "-" + m2[2] + "-" + m2[1];
    var p = new Date(d);
    return isNaN(p) ? "" : Utilities.formatDate(p, CFG.TZ, "yyyy-MM-dd");
  }
  if (d instanceof Date && !isNaN(d)) {
    return Utilities.formatDate(d, CFG.TZ, "yyyy-MM-dd");
  }
  try {
    var pd = new Date(d);
    return isNaN(pd) ? "" : Utilities.formatDate(pd, CFG.TZ, "yyyy-MM-dd");
  } catch(e) { return ""; }
}

/**
 * Convierte cualquier valor a string de hora "HH:mm"
 * Acepta: Date, string "HH:mm", string "HH:mm:ss", número decimal
 */
function _time(d) {
  if (!d && d !== 0) return "";
  if (typeof d === "string") {
    var s = d.trim();
    // Formato AM/PM
    var ampm = s.match(/(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)/i);
    if (ampm) {
      var h = parseInt(ampm[1]);
      var m = parseInt(ampm[2]);
      var ap = ampm[3].toUpperCase();
      if (ap === "PM" && h < 12) h += 12;
      if (ap === "AM" && h === 12) h = 0;
      return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0");
    }
    // Formato HH:mm o HH:mm:ss
    var hm = s.match(/^(\d{1,2}):(\d{2})/);
    if (hm) return hm[0].slice(0, 5);
    return s.slice(0, 5);
  }
  if (d instanceof Date && !isNaN(d)) {
    return Utilities.formatDate(d, CFG.TZ, "HH:mm");
  }
  if (typeof d === "number") {
    var totalMins = Math.floor(d * 24 * 60);
    var hh = Math.floor(totalMins / 60) % 24;
    var mm = totalMins % 60;
    return String(hh).padStart(2, "0") + ":" + String(mm).padStart(2, "0");
  }
  try {
    var pd = new Date(d);
    return isNaN(pd) ? "" : Utilities.formatDate(pd, CFG.TZ, "HH:mm");
  } catch(e) { return ""; }
}

/**
 * Convierte cualquier valor a datetime "dd/MM/yyyy HH:mm:ss"
 */
function _datetime(d) {
  if (!d) return "";
  var dt = (d instanceof Date && !isNaN(d)) ? d : new Date(d);
  if (isNaN(dt)) return "";
  return Utilities.formatDate(dt, CFG.TZ, "dd/MM/yyyy HH:mm:ss");
}

/**
 * Normaliza hora para agenda — retorna "HH:mm"
 * Acepta: Date, number (decimal), string variado
 */
function _normHora(hv) {
  if (!hv && hv !== 0) return "";
  if (hv instanceof Date && !isNaN(hv)) {
    return String(hv.getHours()).padStart(2, "0") + ":" +
           String(hv.getMinutes()).padStart(2, "0");
  }
  if (typeof hv === "string") {
    var ampm = hv.trim().match(/(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)/i);
    if (ampm) {
      var h = parseInt(ampm[1]);
      var m = parseInt(ampm[2]);
      if (ampm[3].toUpperCase() === "PM" && h < 12) h += 12;
      if (ampm[3].toUpperCase() === "AM" && h === 12) h = 0;
      return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0");
    }
    var hm24 = hv.trim().match(/^(\d{1,2}):(\d{2})/);
    if (hm24) return hm24[0].slice(0, 5);
    return hv.trim().slice(0, 5);
  }
  if (typeof hv === "number") {
    var totalMins = Math.floor(hv * 24 * 60);
    var hh = Math.floor(totalMins / 60) % 24;
    var mm = totalMins % 60;
    return String(hh).padStart(2, "0") + ":" + String(mm).padStart(2, "0");
  }
  return "";
}

/**
 * Redondea una hora al slot más cercano (cada 30 min)
 * Ej: "14:17" → "14:00", "14:33" → "14:30"
 */
function _snapSlot(horaHHmm) {
  if (!horaHHmm || horaHHmm.length < 5) return horaHHmm;
  var h = parseInt(horaHHmm.slice(0, 2));
  var m = parseInt(horaHHmm.slice(3, 5));
  var snapped = m < 30 ? 0 : 30;
  return String(h).padStart(2, "0") + ":" + String(snapped).padStart(2, "0");
}

/**
 * Genera array de slots de horaIni a horaFin (cada SLOT_DURACION_MIN)
 * @param {string} horaIni "HH:mm"
 * @param {string} horaFin "HH:mm"
 * @returns {Array} ["09:00","09:30","10:00",...]
 */
function _generarSlots(horaIni, horaFin) {
  var slots = [];
  if (!horaIni || !horaFin) return slots;
  var hI = parseInt(horaIni.slice(0, 2)) * 60 + parseInt(horaIni.slice(3, 5));
  var hF = parseInt(horaFin.slice(0, 2)) * 60 + parseInt(horaFin.slice(3, 5));
  for (var m = hI; m < hF; m += AGENDA_CONFIG.SLOT_DURACION_MIN) {
    var h = Math.floor(m / 60);
    var min = m % 60;
    slots.push(String(h).padStart(2, "0") + ":" + String(min).padStart(2, "0"));
  }
  return slots;
}

/**
 * Retorna el día de la semana en español para una fecha
 * @param {string} fechaStr "yyyy-MM-dd"
 * @returns {string} "LUNES" | "MARTES" | ...
 */
function _diaSemana(fechaStr) {
  if (!fechaStr) return "";
  var d = new Date(fechaStr + "T12:00:00");
  return DIAS_SEMANA[d.getDay()];
}
// C02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · TELÉFONOS Y WHATSAPP
// ══════════════════════════════════════════════════════════════
// C03_START

/**
 * Normaliza un número de teléfono peruano a 9 dígitos
 * Elimina el código de país +51 si existe
 * @param {*} raw
 * @returns {string} 9 dígitos o string vacío
 */
function _phone(raw) {
  var s = _norm(raw)
    .replace(/[^\d+]/g, "")
    .replace(/^\+/, "");
  if (s.startsWith("51") && s.length > 9) s = s.slice(2);
  if (s.length > 9) s = s.slice(-9);
  return s;
}

/**
 * Genera URL de WhatsApp para un número
 * @param {string} num - Número normalizado
 * @returns {string} URL de WhatsApp o string vacío
 */
function _wa(num) {
  var n = _phone(num);
  return n ? "https://wa.me/51" + n : "";
}

/**
 * Normaliza número quitando espacios y caracteres extra
 * Versión más permisiva para números que vienen del Sheet
 */
function _normNum(raw) {
  if (!raw) return "";
  var s = String(raw).replace(/\s/g, "").replace(/\D/g, "");
  return s.slice(-9);
}
// C03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · HELPERS DE HOJAS (SHEETS)
// ══════════════════════════════════════════════════════════════
// C04_START

/** Abre el Spreadsheet por ID */
function _ss() {
  return SpreadsheetApp.openById(CFG.SHEET_ID);
}

/**
 * Obtiene una hoja por nombre — lanza error si no existe
 * @param {string} nm - Nombre de la hoja
 * @returns {Sheet}
 */
function _sh(nm) {
  var s = _ss().getSheetByName(nm);
  if (!s) throw new Error("Hoja no encontrada: \"" + nm + "\"");
  return s;
}

/**
 * Obtiene o crea una hoja con headers
 * Si la hoja existe pero está vacía, agrega los headers
 * @param {string} nm - Nombre de la hoja
 * @param {Array} headers - Array de strings con los encabezados
 * @returns {Sheet}
 */
function _ensureSheet(nm, headers) {
  var ss = _ss();
  var sh = ss.getSheetByName(nm);
  if (!sh) {
    sh = ss.insertSheet(nm);
    sh.getRange(1, 1, 1, headers.length).setValues([headers]);
  } else if (sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, headers.length).setValues([headers]);
  }
  return sh;
}

/**
 * Genera un UUID único
 * @returns {string}
 */
function _uid() {
  return Utilities.getUuid();
}

/**
 * Verifica si un valor de fecha está dentro de un rango
 * @param {Date|string} fecha
 * @param {Date} desde
 * @param {Date} hasta
 * @returns {boolean}
 */
function _inRango(fecha, desde, hasta) {
  if (!fecha) return false;
  var d = fecha instanceof Date ? fecha : new Date(fecha);
  return d >= desde && d <= hasta;
}
// C04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · HELPERS DE NOTIFICACIONES Y LOGS
// ══════════════════════════════════════════════════════════════
// C05_START

/**
 * Hoja de notificaciones — creada si no existe
 */
function _notifSheet() {
  return _ensureSheet(CFG.LOG_NOTIF, [
    "ID", "FECHA", "HORA", "TIPO", "TITULO", "CUERPO",
    "DE_ID", "DE_NOMBRE", "PARA_ID", "PARA_NOMBRE", "LEIDO_TS"
  ]);
}

/**
 * Hoja de mensajes directos — creada si no existe
 */
function _msgSheet() {
  return _ensureSheet(CFG.LOG_MSG, [
    "ID", "FECHA", "HORA", "MENSAJE",
    "DE_ID", "DE_NOMBRE", "PARA_ID", "PARA_NOMBRE", "LEIDO_TS"
  ]);
}

/**
 * api_listNotifications — Notificaciones del usuario actual
 */
function api_listNotifications() {
  var s  = cc_requireSession();
  var sh = _notifSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [], unreadNotifs: 0, unreadMsgs: 0 };

  var mine = sh.getRange(2, 1, lr - 1, 11).getValues()
    .filter(function(r) { return _norm(r[8]) === _norm(s.idAsesor); })
    .map(function(r) {
      return {
        id:      r[0],
        fecha:   r[1],
        hora:    r[2],
        tipo:    r[3],
        titulo:  r[4],
        cuerpo:  r[5],
        deId:    r[6],
        asesor:  r[7],
        tsLeido: r[10] || ""
      };
    })
    .sort(function(a, b) {
      return String(b.fecha) + String(b.hora) >
             String(a.fecha) + String(a.hora) ? 1 : -1;
    })
    .slice(0, 100);

  return {
    ok: true,
    items:        mine,
    unreadNotifs: mine.filter(function(x) {
      return !x.tsLeido && x.tipo !== "MESSAGE";
    }).length,
    unreadMsgs: mine.filter(function(x) {
      return !x.tsLeido && x.tipo === "MESSAGE";
    }).length
  };
}

/**
 * api_markNotifRead — Marca una notificación como leída
 */
function api_markNotifRead(id) {
  var s  = cc_requireSession();
  var sh = _notifSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true };
  var ids = sh.getRange(2, 1, lr - 1, 1).getValues()
    .flat().map(_norm);
  var idx = ids.indexOf(_norm(id));
  if (idx === -1) return { ok: true };
  sh.getRange(idx + 2, 11).setValue(new Date());
  return { ok: true };
}

/**
 * api_sendNotification — Admin envía notificación a asesor(es)
 */
function api_sendNotification(destino, txt, titulo) {
  var admin = cc_requireAdmin();
  txt    = _norm(txt);
  titulo = _norm(titulo) || "Notificación";
  if (!txt) throw new Error("Mensaje vacío.");

  var sh    = _notifSheet();
  var now   = new Date();
  var todos = _asesoresActivos();
  var isAll = _up(destino).includes("ALL");
  var tgts  = isAll
    ? todos
    : todos.filter(function(a) {
        return _norm(a.idAsesor) === _norm(destino) ||
               _low(a.label) === _low(destino);
      });
  if (!tgts.length) throw new Error("Destino inválido.");

  tgts.forEach(function(t) {
    sh.appendRow([
      _uid(), _date(now), _time(now), "NOTIF",
      titulo, txt,
      admin.idAsesor, admin.asesor,
      t.idAsesor, t.label || t.nombre, ""
    ]);
  });

  return { ok: true, sent: tgts.length };
}

/**
 * api_sendMessage — Admin envía mensaje directo a asesor
 */
function api_sendMessage(idAsesor, txt) {
  var admin = cc_requireAdmin();
  idAsesor  = _norm(idAsesor);
  txt       = _norm(txt);
  if (!idAsesor || !txt) throw new Error("Faltan datos.");

  var t = _asesoresActivos().find(function(a) {
    return _norm(a.idAsesor) === idAsesor;
  });
  if (!t) throw new Error("Asesor no encontrado.");

  var now  = new Date();
  var tNom = t.label || t.nombre || t.idAsesor;

  _msgSheet().appendRow([
    _uid(), _date(now), _time(now), txt,
    admin.idAsesor, admin.asesor, t.idAsesor, tNom, ""
  ]);
  _notifSheet().appendRow([
    _uid(), _date(now), _time(now), "MESSAGE",
    "Nuevo mensaje", txt,
    admin.idAsesor, admin.asesor, t.idAsesor, tNom, ""
  ]);

  return { ok: true };
}

/** Wrappers token notificaciones */
function api_listNotificationsT(token)       { _setToken(token); return api_listNotifications(); }
function api_markNotifReadT(token, id)        { _setToken(token); return api_markNotifRead(id); }
function api_sendNotificationT(token, d, t, ti){ _setToken(token); return api_sendNotification(d,t,ti); }
function api_sendMessageT(token, id, txt)     { _setToken(token); return api_sendMessage(id, txt); }
// C05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · HELPERS DE NEGOCIO
// ══════════════════════════════════════════════════════════════
// C06_START

/**
 * Determina el semáforo de actividad de un asesor
 * @param {number|null} minsSinLlamar
 * @param {string} estadoActual
 * @returns {string} "verde" | "amarillo" | "rojo" | "pausa" | "gris"
 */
function _calcSemaforo(minsSinLlamar, estadoActual) {
  if (ESTADOS_PAUSA.has(_up(estadoActual))) return SEMAFORO.PAUSA;
  if (minsSinLlamar === null) return SEMAFORO.GRIS;
  if (minsSinLlamar <= SEMAFORO_UMBRALES.VERDE)   return SEMAFORO.VERDE;
  if (minsSinLlamar <= SEMAFORO_UMBRALES.AMARILLO) return SEMAFORO.AMARILLO;
  return SEMAFORO.ROJO;
}

/**
 * Calcula delta porcentual entre dos valores
 * @param {number} prev
 * @param {number} cur
 * @returns {number|null}
 */
function _delta(prev, cur) {
  if (prev === 0) return null;
  return (cur - prev) / Math.abs(prev);
}

/**
 * Formatea monto en soles
 * @param {number} n
 * @returns {string} "S/. 1,234.56"
 */
function _fmtSoles(n) {
  return "S/. " + (Number(n) || 0).toFixed(2)
    .replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/**
 * Retorna el ID único del paciente/número
 * Usa NUMERO_LIMPIO como ID universal
 */
function _numKey(raw) {
  return _phone(raw);
}
// C06_END

// ══════════════════════════════════════════════════════════════
// MOD-07 · CATÁLOGOS
// ══════════════════════════════════════════════════════════════
// C07_START

/**
 * api_listTratamientos — Lista tratamientos activos
 */
function api_listTratamientos() {
  cc_requireSession();
  try {
    var sh = _sh(CFG.SHEET_CAT_TRAT);
    var lr = sh.getLastRow();
    if (lr >= 2) {
      var items = sh.getRange(2, 1, lr - 1, 2).getValues()
        .filter(function(r) {
          return _up(r[1]) === "ACTIVO" || _norm(r[1]) === "";
        })
        .map(function(r) { return _norm(r[0]); })
        .filter(Boolean);
      if (items.length) return { ok: true, items: Array.from(new Set(items)) };
    }
  } catch(e) {}
  // Fallback hardcodeado
  return { ok: true, items: [
    "ENZIMAS FACIALES", "HIFU", "CRIOLIPOLISIS",
    "BIO ESTIMULADOR", "CAPILAR", "VITAMINAS",
    "DETOX", "FACIAL", "CORPORAL", "COMPRA DE PRODUCTO",
    "HIDROFACIAL", "EXOSOMAS FACIAL", "EXOSOMAS CAPILARES",
    "MESOTERAPIA FACIAL", "TOXINA", "PEPTONAS"
  ]};
}

/**
 * api_listAnuncios — Lista anuncios activos
 */
function api_listAnuncios() {
  cc_requireSession();
  try {
    var sh = _sh(CFG.SHEET_CAT_ANUNCIOS);
    var lr = sh.getLastRow();
    if (lr >= 2) {
      var items = sh.getRange(2, 1, lr - 1, 2).getValues()
        .filter(function(r) {
          return _up(r[1]) === "ACTIVO" || _norm(r[1]) === "";
        })
        .map(function(r) { return _norm(r[0]); })
        .filter(Boolean);
      if (items.length) return { ok: true, items: Array.from(new Set(items)) };
    }
  } catch(e) {}
  return { ok: true, items: ["SIN ANUNCIO"] };
}

/** Wrappers token catálogos */
function api_listTratamientosT(token) { _setToken(token); return api_listTratamientos(); }
function api_listAnunciosT(token)     { _setToken(token); return api_listAnuncios(); }
function api_listAsesoresDestinosT(token) { _setToken(token); return api_listAsesores(); }
// C07_END

/**
 * TEST: Verificar helpers básicos
 */
function test_CoreHelpers() {
  Logger.log("=== AscendaOS GS_03_CoreHelpers TEST ===");
  Logger.log("_date(new Date()): "   + _date(new Date()));
  Logger.log("_time(new Date()): "   + _time(new Date()));
  Logger.log("_phone('(+51) 987-654-321'): " + _phone("(+51) 987-654-321"));
  Logger.log("_phone('51987654321'): "        + _phone("51987654321"));
  Logger.log("_normRole('Administrador'): "   + _normRole("Administrador"));
  Logger.log("_snapSlot('14:22'): "           + _snapSlot("14:22"));
  Logger.log("_generarSlots('09:00','10:00'): " +
    JSON.stringify(_generarSlots("09:00", "10:00")));
  Logger.log("=== OK ===");
}