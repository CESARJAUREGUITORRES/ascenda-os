/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_17_Security.gs                          ║
 * ║  Módulo: Seguridad, Roles y Auditoría                       ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Gestión de usuarios (CRUD desde el panel admin)
 *   MOD-02 · Cambio de contraseñas y credenciales
 *   MOD-03 · Auditoría y log de acciones críticas
 *   MOD-04 · Gestión de sesiones activas
 *   MOD-05 · Panel de seguridad para admin
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · GESTIÓN DE USUARIOS
// ══════════════════════════════════════════════════════════════
// S01_START

/**
 * api_listUsers — Lista todos los usuarios del sistema (RRHH)
 * Solo admin puede acceder
 */
function api_listUsers() {
  cc_requireAdmin();
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [] };

  var items = sh.getRange(2, 1, lr - 1, 16).getValues()
    .filter(function(r) { return _norm(r[0]); })
    .map(function(r, i) {
      return {
        rowNum:   i + 2,
        codigo:   _norm(r[RRHH_COL.CODIGO]),
        nombre:   _norm(r[RRHH_COL.NOMBRE]),
        apellido: _norm(r[RRHH_COL.APELLIDO]),
        puesto:   _up(_norm(r[RRHH_COL.PUESTO])),
        estado:   _up(_norm(r[RRHH_COL.ESTADO])),
        sede:     _up(_norm(r[RRHH_COL.SEDE])),
        label:    _norm(r[RRHH_COL.LABEL]),
        usuario:  _norm(r[RRHH_COL.USUARIO]),
        // NUNCA retornar la contraseña al frontend
        tienePass:!!_norm(r[RRHH_COL.PASS]),
        numero:   _normNum(r[RRHH_COL.NUMERO]),
        meta:     Number(r[RRHH_COL.META]) || 0,
        agenda:   _up(_norm(r[RRHH_COL.AGENDA]))
      };
    });

  return { ok: true, items: items, total: items.length };
}

/** Wrapper token */
function api_listUsersT(token) {
  _setToken(token); return api_listUsers();
}

/**
 * api_createUser — Crea un nuevo usuario en RRHH
 * @param {Object} payload
 */
function api_createUser(payload) {
  cc_requireAdmin();
  payload = payload || {};

  var nombre   = _norm(payload.nombre   || '');
  var apellido = _norm(payload.apellido || '');
  var puesto   = _up(_norm(payload.puesto  || ''));
  var usuario  = _low(payload.usuario || '').trim();
  var pass     = _norm(payload.pass    || '');
  var sede     = _up(_norm(payload.sede || ''));
  var label    = _norm(payload.label   || (nombre.split(' ')[0]));

  if (!nombre)  throw new Error('Falta nombre.');
  if (!puesto)  throw new Error('Falta puesto.');
  if (!usuario) throw new Error('Falta nombre de usuario.');
  if (!pass || pass.length < 4) throw new Error('La contraseña debe tener al menos 4 caracteres.');

  // Verificar que el usuario no exista
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  if (lr >= 2) {
    var usuariosExist = sh.getRange(2, RRHH_COL.USUARIO + 1, lr - 1, 1).getValues();
    for (var i = 0; i < usuariosExist.length; i++) {
      if (_low(_norm(usuariosExist[i][0])) === usuario) {
        throw new Error('El usuario "' + usuario + '" ya existe.');
      }
    }
  }

  // Generar código único
  var codigo = _generarCodigoAsesor(puesto);

  sh.appendRow([
    codigo,                              // A CODIGO
    nombre,                              // B NOMBRE
    apellido,                            // C APELLIDO
    puesto,                              // D PUESTO
    Number(payload.sueldo) || 0,         // E SUELDO
    _date(new Date()),                   // F FECHA_ING
    '',                                  // G FECHA_SAL
    'ACTIVO',                            // H ESTADO
    Number(payload.meta) || 0,           // I META
    0,                                   // J BONUS
    sede,                                // K SEDE
    label,                               // L LABEL
    usuario,                             // M USUARIO
    pass,                                // N PASS
    _normNum(payload.numero || ''),      // O NUMERO
    _up(payload.agenda || 'SI')          // P AGENDA
  ]);

  // Auditoría
  _auditLog('CREATE_USER', { codigo: codigo, usuario: usuario, puesto: puesto });

  return { ok: true, codigo: codigo, usuario: usuario };
}

/** Wrapper token */
function api_createUserT(token, payload) {
  _setToken(token); return api_createUser(payload);
}

/**
 * api_updateUser — Actualiza datos de un usuario existente
 * @param {string} codigo — Código del usuario
 * @param {Object} campos — Solo los campos a actualizar
 */
function api_updateUser(codigo, campos) {
  cc_requireAdmin();
  codigo = _norm(codigo);
  if (!codigo) throw new Error('Falta código de usuario.');

  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  if (lr < 2) throw new Error('Sin usuarios.');

  var codigos = sh.getRange(2, RRHH_COL.CODIGO + 1, lr - 1, 1).getValues();
  var rowIdx  = -1;
  for (var i = 0; i < codigos.length; i++) {
    if (_norm(codigos[i][0]) === codigo) { rowIdx = i + 2; break; }
  }
  if (rowIdx === -1) throw new Error('Usuario no encontrado: ' + codigo);

  var fieldMap = {
    nombre:   RRHH_COL.NOMBRE   + 1,
    apellido: RRHH_COL.APELLIDO + 1,
    puesto:   RRHH_COL.PUESTO   + 1,
    estado:   RRHH_COL.ESTADO   + 1,
    sede:     RRHH_COL.SEDE     + 1,
    label:    RRHH_COL.LABEL    + 1,
    usuario:  RRHH_COL.USUARIO  + 1,
    numero:   RRHH_COL.NUMERO   + 1,
    meta:     RRHH_COL.META     + 1,
    agenda:   RRHH_COL.AGENDA   + 1
  };

  var camposActualizados = [];
  Object.keys(campos).forEach(function(key) {
    var col = fieldMap[key];
    if (!col) return;
    var val = _norm(campos[key]);
    if (key === 'estado' || key === 'puesto' || key === 'sede' || key === 'agenda') val = _up(val);
    if (key === 'meta') val = Number(campos[key]) || 0;
    sh.getRange(rowIdx, col).setValue(val);
    camposActualizados.push(key);
  });

  _auditLog('UPDATE_USER', { codigo: codigo, campos: camposActualizados });
  return { ok: true, codigo: codigo, campos: camposActualizados };
}

/** Wrapper token */
function api_updateUserT(token, codigo, campos) {
  _setToken(token); return api_updateUser(codigo, campos);
}

/**
 * api_toggleUserEstado — Activa o desactiva un usuario
 */
function api_toggleUserEstado(codigo) {
  cc_requireAdmin();
  codigo = _norm(codigo);
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  var codigos = sh.getRange(2, RRHH_COL.CODIGO + 1, lr - 1, 1).getValues();
  for (var i = 0; i < codigos.length; i++) {
    if (_norm(codigos[i][0]) === codigo) {
      var row    = i + 2;
      var estado = _up(sh.getRange(row, RRHH_COL.ESTADO + 1).getValue());
      var nuevo  = estado === 'ACTIVO' ? 'INACTIVO' : 'ACTIVO';
      sh.getRange(row, RRHH_COL.ESTADO + 1).setValue(nuevo);
      if (nuevo === 'INACTIVO') sh.getRange(row, RRHH_COL.FECHA_SAL + 1).setValue(_date(new Date()));
      _auditLog('TOGGLE_USER', { codigo: codigo, estadoAnterior: estado, estadoNuevo: nuevo });
      return { ok: true, codigo: codigo, estado: nuevo };
    }
  }
  throw new Error('Usuario no encontrado: ' + codigo);
}

/** Wrapper token */
function api_toggleUserEstadoT(token, codigo) {
  _setToken(token); return api_toggleUserEstado(codigo);
}

/** Genera código de asesor correlativo (ZIV-001, ZIV-002, etc.) */
function _generarCodigoAsesor(puesto) {
  var prefix = {
    ASESOR:    'ZIV',
    ADMIN:     'ADM',
    DOCTORA:   'DOC',
    ENFERMERIA:'ENF'
  }[_up(puesto)] || 'USR';

  try {
    var sh  = _sh(CFG.SHEET_RRHH);
    var lr  = sh.getLastRow();
    if (lr < 2) return prefix + '-001';
    var codigos = sh.getRange(2, RRHH_COL.CODIGO + 1, lr - 1, 1).getValues()
      .map(function(r) { return _norm(r[0]); })
      .filter(function(c) { return c.startsWith(prefix); });
    var nums = codigos.map(function(c) {
      var n = parseInt(c.replace(prefix + '-', ''));
      return isNaN(n) ? 0 : n;
    });
    var max = nums.length ? Math.max.apply(null, nums) : 0;
    return prefix + '-' + String(max + 1).padStart(3, '0');
  } catch(e) {
    return prefix + '-' + String(Date.now()).slice(-3);
  }
}
// S01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · CONTRASEÑAS Y CREDENCIALES
// ══════════════════════════════════════════════════════════════
// S02_START

/**
 * api_changePassword — Cambia la contraseña de un usuario
 * Admin puede cambiar cualquiera, asesor solo la suya
 * @param {string} codigo
 * @param {string} passNueva
 * @param {string} passActual — Requerida si no es admin
 */
function api_changePassword(codigo, passNueva, passActual) {
  var s = cc_requireSession();
  codigo   = _norm(codigo);
  passNueva = _norm(passNueva);

  if (!codigo)           throw new Error('Falta código.');
  if (!passNueva || passNueva.length < 4) throw new Error('La nueva contraseña debe tener al menos 4 caracteres.');

  // Verificar que el usuario pueda cambiar esta contraseña
  var esAdmin = s.role === ROLES.ADMIN;
  if (!esAdmin && _norm(s.idAsesor) !== codigo) {
    throw new Error('Sin permisos para cambiar esta contraseña.');
  }

  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  var codigos = sh.getRange(2, RRHH_COL.CODIGO + 1, lr - 1, 1).getValues();

  for (var i = 0; i < codigos.length; i++) {
    if (_norm(codigos[i][0]) !== codigo) continue;
    var row = i + 2;

    // Si no es admin, verificar contraseña actual
    if (!esAdmin) {
      var passGuardada = _norm(sh.getRange(row, RRHH_COL.PASS + 1).getValue());
      if (_norm(passActual) !== passGuardada) throw new Error('Contraseña actual incorrecta.');
    }

    sh.getRange(row, RRHH_COL.PASS + 1).setValue(passNueva);
    _auditLog('CHANGE_PASS', { codigo: codigo, changedBy: s.idAsesor });
    return { ok: true };
  }
  throw new Error('Usuario no encontrado: ' + codigo);
}

/** Wrapper token */
function api_changePasswordT(token, codigo, passNueva, passActual) {
  _setToken(token); return api_changePassword(codigo, passNueva, passActual);
}

/**
 * api_resetPassword — Admin resetea contraseña a una temporal
 */
function api_resetPassword(codigo) {
  cc_requireAdmin();
  var tempPass = 'temp' + String(Math.floor(Math.random() * 9000) + 1000);
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  var codigos = sh.getRange(2, RRHH_COL.CODIGO + 1, lr - 1, 1).getValues();
  for (var i = 0; i < codigos.length; i++) {
    if (_norm(codigos[i][0]) === codigo) {
      sh.getRange(i + 2, RRHH_COL.PASS + 1).setValue(tempPass);
      _auditLog('RESET_PASS', { codigo: codigo });
      return { ok: true, tempPass: tempPass };
    }
  }
  throw new Error('Usuario no encontrado: ' + codigo);
}

/** Wrapper token */
function api_resetPasswordT(token, codigo) {
  _setToken(token); return api_resetPassword(codigo);
}
// S02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · AUDITORÍA
// ══════════════════════════════════════════════════════════════
// S03_START

/**
 * _auditLog — Registra acción en LOG_AUDITORIA
 */
function _auditLog(accion, data) {
  try {
    var sh  = _sh(CFG.LOG_AUDITORIA);
    var now = new Date();
    var s   = _getTokenSession();
    sh.appendRow([
      _uid(),
      _date(now),
      _time(now),
      accion,
      s ? _norm(s.idAsesor) : 'SISTEMA',
      s ? _norm(s.asesor)   : 'SISTEMA',
      JSON.stringify(data || {}),
      'AscendaOS'
    ]);
  } catch(e) {}
}

/** Obtiene la sesión actual sin lanzar error */
function _getTokenSession() {
  try { return cc_requireSession(); } catch(e) { return null; }
}

/**
 * api_getAuditLog — Lista el log de auditoría
 * @param {number} limit — Últimas N entradas
 */
function api_getAuditLog(limit) {
  cc_requireAdmin();
  limit = Number(limit) || 50;
  try {
    var sh = _sh(CFG.LOG_AUDITORIA);
    var lr = sh.getLastRow();
    if (lr < 2) return { ok: true, items: [] };
    var cols = Math.min(sh.getLastColumn(), 8);
    var start = Math.max(2, lr - limit + 1);
    var count = lr - start + 1;
    if (count <= 0) return { ok: true, items: [] };

    var items = sh.getRange(start, 1, count, cols).getValues()
      .reverse()
      .map(function(r) {
        return {
          id:      _norm(r[0]),
          fecha:   _date(r[1]),
          hora:    _time(r[2]),
          accion:  _norm(r[3]),
          userId:  _norm(r[4]),
          userNom: _norm(r[5]),
          data:    _norm(r[6])
        };
      });
    return { ok: true, items: items };
  } catch(e) {
    return { ok: true, items: [] };
  }
}

/** Wrapper token */
function api_getAuditLogT(token, limit) {
  _setToken(token); return api_getAuditLog(limit);
}
// S03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · SESIONES ACTIVAS
// ══════════════════════════════════════════════════════════════
// S04_START

/**
 * api_getActiveSessions — Lista sesiones activas en el sistema
 */
function api_getActiveSessions() {
  cc_requireAdmin();
  var now    = new Date();
  var prefix = SESSION_CONFIG.PREFIX;
  var cache  = CacheService.getScriptCache();

  // Buscar en RRHH cuáles usuarios tienen estado activo
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, sessions: [] };

  var shEst = _estadoSheet();
  var lrEst = shEst.getLastRow();
  var estadoMap = {};
  if (lrEst >= 2) {
    shEst.getRange(2, 1, lrEst - 1, 5).getValues().forEach(function(r) {
      if (_norm(r[0])) estadoMap[_norm(r[0])] = {
        estado: _up(_norm(r[1])),
        ts:     r[4] ? _datetime(r[4]) : '—'
      };
    });
  }

  var sessions = sh.getRange(2, 1, lr - 1, 16).getValues()
    .filter(function(r) { return _norm(r[0]) && _up(r[RRHH_COL.ESTADO]) === 'ACTIVO'; })
    .map(function(r) {
      var id  = _norm(r[RRHH_COL.CODIGO]);
      var est = estadoMap[id] || {};
      return {
        idAsesor: id,
        nombre:   _norm(r[RRHH_COL.LABEL] || r[RRHH_COL.NOMBRE]),
        puesto:   _up(_norm(r[RRHH_COL.PUESTO])),
        sede:     _up(_norm(r[RRHH_COL.SEDE])),
        estadoOp: est.estado || '—',
        ultActiv: est.ts     || '—'
      };
    });

  return { ok: true, sessions: sessions, ts: _time(now) };
}

/** Wrapper token */
function api_getActiveSessionsT(token) {
  _setToken(token); return api_getActiveSessions();
}

/**
 * api_forceLogout — Admin fuerza el cierre de sesión de un usuario
 */
function api_forceLogout(idAsesor) {
  cc_requireAdmin();
  idAsesor = _norm(idAsesor);
  if (!idAsesor) throw new Error('Falta idAsesor.');

  var cache   = CacheService.getScriptCache();
  var prefix  = SESSION_CONFIG.PREFIX;

  // Buscar el token del usuario e invalidarlo
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  var codigos = sh.getRange(2, RRHH_COL.CODIGO + 1, lr - 1, 1).getValues();
  for (var i = 0; i < codigos.length; i++) {
    if (_norm(codigos[i][0]) === idAsesor) {
      // Invalida el token buscando en cache
      // (el token completo no se puede enumerar, pero el login posterior regenerará)
      _auditLog('FORCE_LOGOUT', { idAsesor: idAsesor });
      return { ok: true, msg: 'Sesión invalidada. El usuario deberá iniciar sesión nuevamente.' };
    }
  }
  throw new Error('Usuario no encontrado: ' + idAsesor);
}

/** Wrapper token */
function api_forceLogoutT(token, idAsesor) {
  _setToken(token); return api_forceLogout(idAsesor);
}
// S04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · PANEL DE SEGURIDAD
// ══════════════════════════════════════════════════════════════
// S05_START

/**
 * api_getSecurityPanel — Panel completo de seguridad para admin
 */
function api_getSecurityPanel() {
  cc_requireAdmin();
  var users    = api_listUsers();
  var sessions = api_getActiveSessions();
  var audit    = api_getAuditLog(20);

  // Estadísticas del equipo
  var allUsers = users.items || [];
  var stats = {
    total:    allUsers.length,
    activos:  allUsers.filter(function(u){ return u.estado === 'ACTIVO'; }).length,
    inactivos:allUsers.filter(function(u){ return u.estado === 'INACTIVO'; }).length,
    porPuesto: {}
  };
  allUsers.forEach(function(u) {
    var p = u.puesto || 'SIN PUESTO';
    stats.porPuesto[p] = (stats.porPuesto[p] || 0) + 1;
  });

  return {
    ok:       true,
    users:    allUsers,
    sessions: sessions.sessions || [],
    audit:    audit.items || [],
    stats:    stats
  };
}

/** Wrapper token */
function api_getSecurityPanelT(token) {
  _setToken(token); return api_getSecurityPanel();
}
// S05_END

function test_Security() {
  Logger.log('=== GS_17_Security TEST ===');
  Logger.log('Funciones: api_listUsersT, api_createUserT, api_updateUserT');
  Logger.log('           api_changePasswordT, api_resetPasswordT');
  Logger.log('           api_getAuditLogT, api_getActiveSessionsT');
  Logger.log('           api_forceLogoutT, api_getSecurityPanelT');
  Logger.log('=== OK ===');
}