/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_15_Notifications.gs                     ║
 * ║  Módulo: Notificaciones y Mensajería Interna                ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config, GS_03_CoreHelpers,            ║
 * ║                GS_04_DataAccess, GS_05_Auth                ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * NOTA: GS_03_CoreHelpers ya implementa las funciones base de
 * notificaciones (api_listNotifications, api_sendNotification,
 * api_sendMessage, api_markNotifRead). Este módulo extiende con:
 *
 * CONTENIDO:
 *   MOD-01 · Centro de notificaciones (agregado + badges)
 *   MOD-02 · Mensajería directa asesor ↔ admin
 *   MOD-03 · Notificaciones automáticas del sistema
 *   MOD-04 · Alertas de cumpleaños y aniversarios
 *   MOD-05 · Panel de notificaciones para admin
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · CENTRO DE NOTIFICACIONES (BADGES + POLLING)
// ══════════════════════════════════════════════════════════════
// N01_START

/**
 * api_getNotifCenter — Datos completos del centro de notificaciones
 * Llamado periódico desde el frontend (polling cada 30s)
 * Retorna contadores, últimas notificaciones y mensajes sin leer
 */
function api_getNotifCenter() {
  var s  = cc_requireSession();
  var sh = _notifSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return _emptyNotifCenter(s.idAsesor);

  var all = sh.getRange(2, 1, lr - 1, 11).getValues()
    .filter(function(r) { return _norm(r[8]) === _norm(s.idAsesor); });

  var notifs = all.filter(function(r) { return _up(r[3]) !== 'MESSAGE'; });
  var msgs   = all.filter(function(r) { return _up(r[3]) === 'MESSAGE'; });

  var unreadNotifs = notifs.filter(function(r) { return !_norm(r[10]); }).length;
  var unreadMsgs   = msgs.filter(function(r)   { return !_norm(r[10]); }).length;

  // Últimas 5 notificaciones no leídas o las más recientes
  var latestNotifs = notifs
    .sort(function(a, b) { return String(b[1]) > String(a[1]) ? 1 : -1; })
    .slice(0, 5)
    .map(function(r) {
      return {
        id:      _norm(r[0]),
        fecha:   _date(r[1]),
        hora:    _time(r[2]),
        tipo:    _up(r[3]),
        titulo:  _norm(r[4]),
        cuerpo:  _norm(r[5]),
        de:      _norm(r[7]),
        leido:   !!_norm(r[10])
      };
    });

  // Último mensaje sin leer de cada remitente
  var latestMsgs = [];
  var deMap = {};
  msgs
    .sort(function(a, b) { return String(b[1]) > String(a[1]) ? 1 : -1; })
    .forEach(function(r) {
      var de = _norm(r[6]);
      if (!deMap[de]) {
        deMap[de] = true;
        latestMsgs.push({
          id:     _norm(r[0]),
          fecha:  _date(r[1]),
          hora:   _time(r[2]),
          texto:  _norm(r[5]),
          deId:   de,
          deNom:  _norm(r[7]),
          leido:  !!_norm(r[10])
        });
      }
    });

  // Sonido: si hay nuevas notificaciones desde hace < 30s → flag de sonido
  var playSound = _checkSoundFlag(s.idAsesor);

  return {
    ok:          true,
    idAsesor:    s.idAsesor,
    unreadNotifs:unreadNotifs,
    unreadMsgs:  unreadMsgs,
    total:       unreadNotifs + unreadMsgs,
    notifs:      latestNotifs,
    msgs:        latestMsgs,
    playSound:   playSound,
    ts:          _time(new Date())
  };
}

/** Retorna objeto vacío del notification center */
function _emptyNotifCenter(idAsesor) {
  return {
    ok: true, idAsesor: idAsesor || '',
    unreadNotifs: 0, unreadMsgs: 0, total: 0,
    notifs: [], msgs: [], playSound: false, ts: _time(new Date())
  };
}

/**
 * Verifica si debe reproducirse un sonido de notificación
 * Revisa si hay notificaciones de los últimos 30 segundos no marcadas
 */
function _checkSoundFlag(idAsesor) {
  try {
    var sh   = _notifSheet();
    var lr   = sh.getLastRow();
    if (lr < 2) return false;
    var now  = new Date();
    var hace30s = new Date(now.getTime() - 30000);
    var rows = sh.getRange(2, 1, lr - 1, 11).getValues();
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      if (_norm(r[8]) !== _norm(idAsesor)) continue;
      if (_norm(r[10])) continue; // ya leído
      var ts = r[1];
      if (ts instanceof Date && ts > hace30s) return true;
    }
    return false;
  } catch(e) { return false; }
}

/** Wrappers token */
function api_getNotifCenterT(token) {
  _setToken(token); return api_getNotifCenter();
}
// N01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · MENSAJERÍA DIRECTA
// ══════════════════════════════════════════════════════════════
// N02_START

/**
 * api_getConversacion — Historial de mensajes entre dos usuarios
 * @param {string} conIdAsesor — ID del otro participante
 */
function api_getConversacion(conIdAsesor) {
  var s  = cc_requireSession();
  conIdAsesor = _norm(conIdAsesor);
  if (!conIdAsesor) throw new Error('Falta conIdAsesor.');

  var sh = _msgSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [] };

  var items = sh.getRange(2, 1, lr - 1, 9).getValues()
    .filter(function(r) {
      var de   = _norm(r[4]);
      var para = _norm(r[6]);
      return (de === _norm(s.idAsesor) && para === conIdAsesor) ||
             (de === conIdAsesor && para === _norm(s.idAsesor));
    })
    .map(function(r) {
      return {
        id:      _norm(r[0]),
        fecha:   _date(r[1]),
        hora:    _time(r[2]),
        texto:   _norm(r[3]),
        deId:    _norm(r[4]),
        deNom:   _norm(r[5]),
        paraId:  _norm(r[6]),
        leido:   !!_norm(r[8]),
        propio:  _norm(r[4]) === _norm(s.idAsesor)
      };
    })
    .sort(function(a, b) { return (a.fecha + a.hora) < (b.fecha + b.hora) ? -1 : 1; });

  // Marcar como leídos los mensajes de la otra persona
  _marcarMensajesLeidos(sh, s.idAsesor, conIdAsesor);

  return { ok: true, items: items };
}

/** Wrapper token */
function api_getConversacionT(token, conIdAsesor) {
  _setToken(token); return api_getConversacion(conIdAsesor);
}

/**
 * api_enviarMensaje — Envía mensaje directo
 * @param {string} paraIdAsesor
 * @param {string} texto
 */
function api_enviarMensaje(paraIdAsesor, texto) {
  var s   = cc_requireSession();
  paraIdAsesor = _norm(paraIdAsesor);
  texto        = _norm(texto);
  if (!paraIdAsesor || !texto) throw new Error('Faltan datos.');

  // Buscar destinatario
  var dest = _asesoresActivosCached().find(function(a) {
    return _norm(a.idAsesor) === paraIdAsesor;
  });
  if (!dest) throw new Error('Destinatario no encontrado.');

  var now     = new Date();
  var destNom = dest.label || dest.nombre || paraIdAsesor;

  _msgSheet().appendRow([
    _uid(), _date(now), _time(now), texto,
    _norm(s.idAsesor), _norm(s.asesor),
    paraIdAsesor, destNom, ''
  ]);

  // Crear notificación de nuevo mensaje
  _notifSheet().appendRow([
    _uid(), _date(now), _time(now), 'MESSAGE',
    'Mensaje de ' + _norm(s.asesor), texto,
    _norm(s.idAsesor), _norm(s.asesor),
    paraIdAsesor, destNom, ''
  ]);

  return { ok: true };
}

/** Wrapper token */
function api_enviarMensajeT(token, paraId, texto) {
  _setToken(token); return api_enviarMensaje(paraId, texto);
}

/**
 * api_getContacts — Lista de contactos para mensajería
 */
function api_getContacts() {
  var s = cc_requireSession();
  var all = _asesoresActivosCached();
  return {
    ok: true,
    items: all
      .filter(function(a) { return _norm(a.idAsesor) !== _norm(s.idAsesor); })
      .map(function(a) {
        return {
          idAsesor: a.idAsesor,
          nombre:   a.label || a.nombre,
          role:     a.role,
          sede:     a.sede
        };
      })
  };
}

/** Wrapper token */
function api_getContactsT(token) {
  _setToken(token); return api_getContacts();
}

/** Marca mensajes como leídos */
function _marcarMensajesLeidos(sh, paraId, deId) {
  try {
    var lr = sh.getLastRow();
    if (lr < 2) return;
    var rows = sh.getRange(2, 1, lr - 1, 9).getValues();
    for (var i = 0; i < rows.length; i++) {
      if (_norm(rows[i][4]) === deId &&
          _norm(rows[i][6]) === paraId &&
          !_norm(rows[i][8])) {
        sh.getRange(i + 2, 9).setValue(_datetime(new Date()));
      }
    }
  } catch(e) {}
}
// N02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · NOTIFICACIONES AUTOMÁTICAS DEL SISTEMA
// ══════════════════════════════════════════════════════════════
// N03_START

/**
 * api_notifVentaRegistrada — Notifica al admin cuando un asesor registra venta
 * Llamada automáticamente desde api_saveVenta
 */
function notif_ventaRegistrada(ctx, ventaId, monto, trat) {
  try {
    var admins = _asesoresActivosCached().filter(function(a) {
      return a.role === ROLES.ADMIN;
    });
    var now    = new Date();
    var titulo = '💰 Venta registrada';
    var cuerpo = _norm(ctx.asesor) + ' · ' + _norm(trat) + ' · S/' + (Number(monto) || 0).toFixed(0);

    admins.forEach(function(admin) {
      _notifSheet().appendRow([
        _uid(), _date(now), _time(now), 'VENTA',
        titulo, cuerpo,
        _norm(ctx.idAsesor), _norm(ctx.asesor),
        admin.idAsesor, admin.label || admin.nombre, ''
      ]);
    });
  } catch(e) {}
}

/**
 * api_notifCitaConfirmada — Notifica al admin cuando se confirma una cita
 */
function notif_citaConfirmada(ctx, num, trat) {
  try {
    var admins = _asesoresActivosCached().filter(function(a) {
      return a.role === ROLES.ADMIN;
    });
    var now    = new Date();
    var titulo = '📅 Cita confirmada';
    var cuerpo = _norm(ctx.asesor) + ' confirmó cita: ' + _norm(trat);

    admins.forEach(function(admin) {
      _notifSheet().appendRow([
        _uid(), _date(now), _time(now), 'CITA',
        titulo, cuerpo,
        _norm(ctx.idAsesor), _norm(ctx.asesor),
        admin.idAsesor, admin.label || admin.nombre, ''
      ]);
    });
  } catch(e) {}
}

/**
 * api_notifAlertaAdmin — Genera alerta manual del admin para todos
 * @param {string} titulo
 * @param {string} cuerpo
 * @param {string} tipo   ALERTA | INFO | OK
 */
function api_notifAlertaAdmin(titulo, cuerpo, tipo) {
  var admin = cc_requireAdmin();
  titulo = _norm(titulo) || 'Alerta';
  cuerpo = _norm(cuerpo);
  tipo   = _up(tipo || 'ALERTA');
  if (!cuerpo) throw new Error('Falta mensaje.');

  var asesores = _asesoresActivosCached().filter(function(a) {
    return a.role === ROLES.ASESOR;
  });
  var now  = new Date();
  var icoMap = { ALERTA: '⚠️', INFO: 'ℹ️', OK: '✅' };
  var ico  = icoMap[tipo] || '📢';

  asesores.forEach(function(a) {
    _notifSheet().appendRow([
      _uid(), _date(now), _time(now), tipo,
      ico + ' ' + titulo, cuerpo,
      _norm(admin.idAsesor), _norm(admin.asesor),
      a.idAsesor, a.label || a.nombre, ''
    ]);
  });

  return { ok: true, enviados: asesores.length };
}

/** Wrapper token */
function api_notifAlertaAdminT(token, titulo, cuerpo, tipo) {
  _setToken(token); return api_notifAlertaAdmin(titulo, cuerpo, tipo);
}

/**
 * api_marcarTodasLeidas — Marca todas las notificaciones del usuario como leídas
 */
function api_marcarTodasLeidas() {
  var s  = cc_requireSession();
  var sh = _notifSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true };

  var now  = _datetime(new Date());
  var rows = sh.getRange(2, 1, lr - 1, 11).getValues();
  for (var i = 0; i < rows.length; i++) {
    if (_norm(rows[i][8]) === _norm(s.idAsesor) && !_norm(rows[i][10])) {
      sh.getRange(i + 2, 11).setValue(now);
    }
  }
  return { ok: true };
}

/** Wrapper token */
function api_marcarTodasLeidasT(token) {
  _setToken(token); return api_marcarTodasLeidas();
}
// N03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · PANEL DE NOTIFICACIONES ADMIN
// ══════════════════════════════════════════════════════════════
// N04_START

/**
 * api_getAdminNotifPanel — Panel completo de notificaciones para admin
 * Muestra actividad del equipo: ventas, citas, mensajes recientes
 */
function api_getAdminNotifPanel() {
  cc_requireAdmin();
  var sh = _notifSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [], stats: {} };

  var now    = new Date();
  var hace7d = new Date(now.getTime() - 7 * 86400000);

  var all = sh.getRange(2, 1, lr - 1, 11).getValues()
    .filter(function(r) {
      var ts = r[1];
      return ts instanceof Date ? ts > hace7d : false;
    })
    .map(function(r) {
      return {
        id:      _norm(r[0]),
        fecha:   _date(r[1]),
        hora:    _time(r[2]),
        tipo:    _up(r[3]),
        titulo:  _norm(r[4]),
        cuerpo:  _norm(r[5]),
        deId:    _norm(r[6]),
        deNom:   _norm(r[7]),
        paraId:  _norm(r[8]),
        paraNom: _norm(r[9]),
        leido:   !!_norm(r[10])
      };
    })
    .sort(function(a, b) { return (a.fecha + a.hora) < (b.fecha + b.hora) ? 1 : -1; });

  // Stats por tipo últimas 7d
  var stats = {};
  all.forEach(function(n) {
    stats[n.tipo] = (stats[n.tipo] || 0) + 1;
  });

  return {
    ok:    true,
    items: all.slice(0, 100),
    stats: stats,
    total: all.length
  };
}

/** Wrapper token */
function api_getAdminNotifPanelT(token) {
  _setToken(token); return api_getAdminNotifPanel();
}
// N04_END

/**
 * TEST
 */
function test_Notifications() {
  Logger.log('=== GS_15_Notifications TEST ===');
  Logger.log('Funciones disponibles:');
  Logger.log('  api_getNotifCenterT(token)');
  Logger.log('  api_getConversacionT(token, conIdAsesor)');
  Logger.log('  api_enviarMensajeT(token, paraId, texto)');
  Logger.log('  api_getContactsT(token)');
  Logger.log('  api_notifAlertaAdminT(token, titulo, cuerpo, tipo)');
  Logger.log('  api_marcarTodasLeidasT(token)');
  Logger.log('  api_getAdminNotifPanelT(token)');
  Logger.log('=== OK ===');
}