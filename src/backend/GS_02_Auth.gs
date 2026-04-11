/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_02_Auth.gs                              ║
 * ║  Versión: 1.2.0                                             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CAMBIOS v1.2.0:
 *   FIX-L1 · _asesoresRaw lee 18 cols (era 16) → incluye PERMISOS y FOTO_URL
 *   FIX-L2 · _closeEstadoAbierto lee solo últimas 200 filas (era 5,595+)
 *            → login: 6-9s → <2s
 *   FIX-L3 · api_getEstadoAsesor igual: últimas 200 filas
 *   FIX-L4 · _asesoresActivosCached usa CacheService TTL 2 min
 *            → no releer RRHH en cada request
 *
 * CONTENIDO:
 *   MOD-01 · Token interno
 *   MOD-02 · Gestión de sesiones
 *   MOD-03 · Login y Logout
 *   MOD-04 · Helpers de asesores desde RRHH
 *   MOD-05 · Estado operativo del asesor
 *   MOD-06 · Normalización de roles
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · TOKEN INTERNO DE EJECUCIÓN
// ══════════════════════════════════════════════════════════════
// B01_START
var _CURRENT_TOKEN = null;

function _setToken(t) { _CURRENT_TOKEN = t; }
function _getToken()  { return _CURRENT_TOKEN; }

function _withToken(token, fn, args) {
  _setToken(token);
  return fn.apply(null, args || []);
}
// B01_END


// ══════════════════════════════════════════════════════════════
// MOD-02 · GESTIÓN DE SESIONES CON CACHESERVICE
// ══════════════════════════════════════════════════════════════
// B02_START

function _cacheKey(token) {
  return SESSION_CONFIG.PREFIX +
    String(token || "").replace(/[^a-zA-Z0-9]/g, "").substring(0, 40);
}

function cc_setSession(ctx, token) {
  var key = _cacheKey(token || ctx.token);
  CacheService.getScriptCache().put(key, JSON.stringify(ctx), SESSION_CONFIG.TTL);
}

function cc_getSession(token) {
  if (!token) return null;
  var raw = CacheService.getScriptCache().get(_cacheKey(token));
  if (!raw) return null;
  try { return JSON.parse(raw); } catch(e) { return null; }
}

function cc_clearSession(token) {
  if (token) CacheService.getScriptCache().remove(_cacheKey(token));
}

function cc_requireSession() {
  var token = _getToken();
  var s = cc_getSession(token);
  if (!s || !s.idAsesor) throw new Error("No autorizado. Iniciá sesión.");
  s.role = _normRole(s.role);
  return s;
}

function cc_requireAdmin() {
  var s = cc_requireSession();
  if (s.role !== ROLES.ADMIN) throw new Error("Solo administradores.");
  return s;
}
// B02_END


// ══════════════════════════════════════════════════════════════
// MOD-03 · LOGIN Y LOGOUT
// ══════════════════════════════════════════════════════════════
// B03_START

function api_login(usuario, pass, device) {
  var normU = function(s) { return String(s || "").trim().toLowerCase(); };
  usuario = normU(usuario);
  pass    = normU(pass);

  var asesores = _asesoresRaw();
  var u = asesores.find(function(x) {
    return normU(x.usuario) === usuario
      && normU(x.pass) === pass
      && x.estado === "ACTIVO";
  });

  if (!u) return { ok: false, error: "Usuario o contraseña incorrectos" };

  var token = _genToken();
  var now   = new Date();

  var ctx = {
    idAsesor: u.idAsesor,
    asesor:   u.label || u.nombre || u.idAsesor,
    role:     _normRole(u.role),
    sede:     u.sede,
    permisos: u.permisos || [],
    fotoUrl:  u.fotoUrl  || "",
    device:   _norm(device),
    ts:       now.toISOString(),
    token:    token
  };

  try { cc_setSession(ctx, token); } catch(e) {}

  // FIX-L2: _closeEstadoAbierto ahora lee solo últimas 200 filas
  try {
    _setToken(token);
    _closeEstadoAbierto(_norm(ctx.asesor));
    var shLog = _ensureSheet(CFG.LOG_PERSONAL, [
      "FECHA","ASESOR","EVENTO","ESTADO","DETALLE",
      "INICIO","FIN","DURACION_MIN","SESSION_ID","ORIGEN","TS_LOG"
    ]);
    shLog.appendRow([
      _date(now), ctx.asesor, "LOGIN", "LOGEADO", "",
      now, "", "", token, "", now
    ]);
  } catch(e) {}

  // Notificar login a admins
  try {
    var admins = _asesoresActivosCached().filter(function(a) {
      return _normRole(a.role) === ROLES.ADMIN;
    });
    admins.forEach(function(adm) {
      _notifSheet().appendRow([
        _uid(), _date(now), _time(now), "LOGIN",
        "🟣 " + _norm(ctx.asesor) + " se conectó",
        "", "", "", adm.idAsesor, adm.label || adm.nombre, ""
      ]);
    });
  } catch(e) {}

  // FIX: incluir scriptUrl para que Login.html no necesite un segundo request
  var scriptUrl = "";
  try { scriptUrl = ScriptApp.getService().getUrl(); } catch(e) {}

  return { ok: true, token: token, ctx: ctx, scriptUrl: scriptUrl };
}

function api_getContext(token) {
  _setToken(token);
  var s = cc_getSession(token);
  if (!s) return { ctx: null };
  s.role = _normRole(s.role);
  return { ctx: s };
}

function api_logout(token) {
  _setToken(token);
  try {
    var s = cc_getSession(token);
    if (s) {
      _closeEstadoAbierto(_norm(s.asesor));
      var shLog = _ensureSheet(CFG.LOG_PERSONAL, [
        "FECHA","ASESOR","EVENTO","ESTADO","DETALLE",
        "INICIO","FIN","DURACION_MIN","SESSION_ID","ORIGEN","TS_LOG"
      ]);
      var now = new Date();
      shLog.appendRow([
        _date(now), s.asesor, "LOGOUT", "DESCONECTADO", "",
        now, "", "", token, "", now
      ]);
    }
  } catch(e) {}
  cc_clearSession(token);
  return { ok: true };
}

function _genToken() {
  return Utilities.base64Encode(
    Utilities.computeDigest(
      Utilities.DigestAlgorithm.SHA_256,
      Math.random().toString() + new Date().getTime().toString()
    )
  ).replace(/[^a-zA-Z0-9]/g, "").substring(0, SESSION_CONFIG.TOKEN_LEN);
}
// B03_END


// ══════════════════════════════════════════════════════════════
// MOD-04 · HELPERS DE ASESORES DESDE RRHH
// ══════════════════════════════════════════════════════════════
// B04_START

/**
 * FIX-L1: Lee 18 cols (era 16) → incluye PERMISOS (col Q=16) y FOTO_URL (col R=17)
 */
function _asesoresRaw() {
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  if (lr < 2) return [];

  return sh.getRange(2, 1, lr - 1, 18).getValues().map(function(r) {
    var permisosRaw = r[RRHH_COL.PERMISOS];
    var permisos = [];
    try {
      if (permisosRaw) {
        permisos = typeof permisosRaw === "string"
          ? JSON.parse(permisosRaw)
          : permisosRaw;
      }
    } catch(e) { permisos = []; }

    return {
      idAsesor:    _norm(r[RRHH_COL.CODIGO]),
      nombre:      _norm(r[RRHH_COL.NOMBRE]),
      apellido:    _norm(r[RRHH_COL.APELLIDO]),
      puesto:      _up(r[RRHH_COL.PUESTO]),
      estado:      _up(r[RRHH_COL.ESTADO]),
      meta:        Number(r[RRHH_COL.META]) || 0,
      sede:        _norm(r[RRHH_COL.SEDE]),
      label:       _norm(r[RRHH_COL.LABEL]),
      usuario:     _low(r[RRHH_COL.USUARIO]),
      pass:        _norm(String(r[RRHH_COL.PASS] || "")),
      numero:      _norm(String(r[RRHH_COL.NUMERO] || "")),
      tieneAgenda: _up(String(r[RRHH_COL.AGENDA] || "")) === "SI",
      role:        _normRole(r[RRHH_COL.PUESTO]),
      permisos:    permisos,
      fotoUrl:     _norm(r[RRHH_COL.FOTO_URL] || "")
    };
  }).filter(function(x) { return x.idAsesor; });
}

/**
 * FIX-L4: _asesoresActivosCached — CacheService TTL 2 min
 * No releer RRHH en cada request (era llamado múltiples veces por request)
 */
function _asesoresActivosCached() {
  var CACHE_KEY = "AOS_ASESORES_ACTIVOS_v2";
  var TTL       = 120; // 2 minutos
  try {
    var cached = cache_get(CACHE_KEY);
    if (cached && Array.isArray(cached)) return cached;
  } catch(e) {}

  var activos = _asesoresActivos();
  try { cache_set(CACHE_KEY, activos, TTL); } catch(e) {}
  return activos;
}

function _asesoresActivos() {
  var map = new Map();
  _asesoresRaw()
    .filter(function(a) { return a.estado === "ACTIVO"; })
    .forEach(function(a) {
      if (!map.has(a.idAsesor)) map.set(a.idAsesor, a);
    });
  return Array.from(map.values());
}

function _doctorasConAgenda() {
  return _asesoresRaw().filter(function(a) {
    return a.puesto === "DOCTORA" && a.tieneAgenda;
  });
}

function _enfermeriaActiva() {
  return _asesoresRaw().filter(function(a) {
    return a.puesto === "ENFERMERIA" && a.estado === "ACTIVO";
  });
}

function api_listAsesores() {
  cc_requireAdmin();
  return {
    ok: true,
    items: _asesoresActivosCached().map(function(a) {
      return {
        idAsesor: a.idAsesor,
        nombre:   a.label || a.nombre || a.idAsesor,
        role:     a.role,
        sede:     a.sede,
        fotoUrl:  a.fotoUrl || ""
      };
    })
  };
}

function api_listAsesoresT(token) {
  _setToken(token); return api_listAsesores();
}
// B04_END


// ══════════════════════════════════════════════════════════════
// MOD-05 · ESTADO OPERATIVO DEL ASESOR
// ══════════════════════════════════════════════════════════════
// B05_START

function _estadoSheet() {
  return _ensureSheet(CFG.LOG_PERSONAL, [
    "FECHA", "ASESOR", "EVENTO", "ESTADO", "DETALLE",
    "INICIO", "FIN", "DURACION_MIN", "SESSION_ID", "ORIGEN", "TS_LOG"
  ]);
}

/**
 * FIX-L2: Lee solo últimas 200 filas (era lr-1 = 5,595 filas completas)
 * El estado abierto siempre está en las últimas filas del día
 * Login: 6-9s → <2s
 */
function _closeEstadoAbierto(nombre) {
  if (!nombre) return;
  var sh = _estadoSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return;

  // FIX: solo últimas 200 filas — el estado abierto siempre es reciente
  var inicio = Math.max(2, lr - 199);
  var cant   = lr - inicio + 1;
  var data   = sh.getRange(inicio, 1, cant, 11).getValues();

  for (var i = data.length - 1; i >= 0; i--) {
    if (_norm(data[i][1]) === nombre && !data[i][6]) {
      var row = inicio + i; // fila real en el Sheet
      var now = new Date();
      var ini = data[i][5] ? new Date(data[i][5]) : null;
      sh.getRange(row, 7).setValue(now);
      if (ini && !isNaN(ini)) {
        sh.getRange(row, 8).setValue(
          Math.max(0, Math.round((now - ini) / 60000))
        );
      }
      sh.getRange(row, 11).setValue(now);
      return;
    }
  }
}

/**
 * FIX-L3: api_getEstadoAsesor también limita a últimas 200 filas
 */
function api_getEstadoAsesor() {
  var s  = cc_requireSession();
  var sh = _estadoSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, estado: "" };

  var nombre = _norm(s.asesor);
  var inicio = Math.max(2, lr - 199);
  var cant   = lr - inicio + 1;
  var data   = sh.getRange(inicio, 1, cant, 11).getValues();

  for (var i = data.length - 1; i >= 0; i--) {
    if (_norm(data[i][1]) === nombre && !data[i][6]) {
      return { ok: true, estado: _norm(data[i][3]) };
    }
  }
  return { ok: true, estado: "" };
}

function api_setEstadoAsesor(estado) {
  var s  = cc_requireSession();
  estado = _up(estado);

  if (ESTADOS_OPERATIVO.indexOf(estado) === -1) {
    throw new Error("Estado inválido: \"" + estado + "\"");
  }

  var now    = new Date();
  var nombre = _norm(s.asesor);
  _closeEstadoAbierto(nombre);
  _estadoSheet().appendRow([
    _date(now), nombre, "ESTADO", estado, "",
    now, "", "", "", "", now
  ]);

  // Notificar a admins
  try {
    var admins = _asesoresActivosCached().filter(function(a) {
      return _normRole(a.role) === ROLES.ADMIN;
    });
    admins.forEach(function(adm) {
      _notifSheet().appendRow([
        _uid(), _date(now), _time(now), "ESTADO",
        "👤 " + nombre + ": " + estado,
        "El asesor " + nombre + " cambió su estado a " + estado,
        _norm(s.idAsesor), nombre,
        adm.idAsesor, adm.label || adm.nombre, ""
      ]);
    });
  } catch(e) {}

  return { ok: true, estado: estado };
}

function api_getEstadoAsesorT(token) {
  _setToken(token); return api_getEstadoAsesor();
}
function api_setEstadoAsesorT(token, estado) {
  _setToken(token); return api_setEstadoAsesor(estado);
}
// B05_END


// ══════════════════════════════════════════════════════════════
// MOD-06 · NORMALIZACIÓN DE ROLES
// ══════════════════════════════════════════════════════════════
// B06_START

function _normRole(r) {
  var v = _up(r).replace(/\s+/g, " ").trim();
  if (["ADMINISTRADOR", "ADMIN", "ADMINISTRADORA"].indexOf(v) >= 0) return ROLES.ADMIN;
  if (["DOCTORA", "DOCTOR"].indexOf(v) >= 0) return ROLES.DOCTORA;
  if (v === "MARKETING") return ROLES.MARKETING;
  return ROLES.ASESOR;
}
// B06_END


// ══════════════════════════════════════════════════════════════
// FUNCIONES DE TURNO (sin cambios)
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_verificarTurnoHoyT =====
function api_verificarTurnoHoyT(token) {
  _setToken(token);
  var s = cc_requireSession();
  var hoy = _date(new Date());
  var sh  = _sh(CFG.SHEET_TURNOS);
  var lr  = sh.getLastRow();
  if (lr < 2) return { ok: false };
  var rows = sh.getRange(2, 1, lr-1, 3).getValues();
  for (var i = 0; i < rows.length; i++) {
    if (_date(rows[i][0]) === hoy && _norm(rows[i][1]) === s.idAsesor) {
      return { ok: true, turnoId: i + 2 };
    }
  }
  return { ok: false };
}
function api_verificarTurnoHoyTW(token) {
  _setToken(token); return api_verificarTurnoHoyT(token);
}

// ===== CTRL+F: api_iniciarTurnoT =====
function api_iniciarTurnoT(token) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  var sh  = _sh(CFG.SHEET_TURNOS);
  sh.appendRow([
    _date(now), s.idAsesor, s.asesor,
    Utilities.formatDate(now, CFG.TZ, "HH:mm:ss"),
    "", 0, 0, 0, 0, 0, 0, 0, 0, 0, "ABIERTO",
    now.toISOString(), now.toISOString()
  ]);
  var rowNum = sh.getLastRow();
  return { ok: true, turnoId: rowNum };
}

// ===== CTRL+F: api_cerrarTurnoT =====
function api_cerrarTurnoT(token) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  var sh  = _sh(CFG.SHEET_TURNOS);
  var lr  = sh.getLastRow();
  var hoy = _date(now);
  if (lr < 2) return { ok: false };
  var rows = sh.getRange(2, 1, lr-1, 15).getValues();
  for (var i = rows.length - 1; i >= 0; i--) {
    if (_date(rows[i][0]) === hoy && _norm(rows[i][1]) === s.idAsesor && _norm(rows[i][14]) === "ABIERTO") {
      var rowNum = i + 2;
      sh.getRange(rowNum, 5).setValue(Utilities.formatDate(now, CFG.TZ, "HH:mm:ss"));
      sh.getRange(rowNum, 15).setValue("CERRADO");
      sh.getRange(rowNum, 17).setValue(now.toISOString());
      api_logout(token);
      return { ok: true };
    }
  }
  return { ok: false };
}

// ===== CTRL+F: api_registrarMinutosEstadoT =====
function api_registrarMinutosEstadoT(token, estado, minutos) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  var sh  = _sh(CFG.SHEET_TURNOS);
  var lr  = sh.getLastRow();
  var hoy = _date(now);
  if (lr < 2) return { ok: false };
  var mCol = {"BREAK":6,"BAÑO":7,"ATENCIÓN":8,"LIMPIEZA":9,"CAPACITACIÓN":10};
  var col  = mCol[_up(estado)] || 11;
  var rows = sh.getRange(2, 1, lr-1, 2).getValues();
  for (var i = rows.length - 1; i >= 0; i--) {
    if (_date(rows[i][0]) === hoy && _norm(rows[i][1]) === s.idAsesor) {
      var rowNum = i + 2;
      var actual = Number(sh.getRange(rowNum, col).getValue()) || 0;
      sh.getRange(rowNum, col).setValue(actual + minutos);
      return { ok: true };
    }
  }
  return { ok: false };
}

// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════

function test_Auth() {
  Logger.log("=== GS_02_Auth v1.2 TEST ===");
  Logger.log("FIX-L1: _asesoresRaw lee 18 cols (PERMISOS + FOTO_URL)");
  Logger.log("FIX-L2: _closeEstadoAbierto lee últimas 200 filas");
  Logger.log("FIX-L3: api_getEstadoAsesor lee últimas 200 filas");
  Logger.log("FIX-L4: _asesoresActivosCached con TTL 2 min");

  var t1 = new Date().getTime();
  var asesores = _asesoresRaw();
  var t2 = new Date().getTime();
  Logger.log("_asesoresRaw: " + asesores.length + " asesores en " + (t2-t1) + "ms");

  var t3 = new Date().getTime();
  var r = api_login("cesar", "1234", "TEST");
  var t4 = new Date().getTime();
  Logger.log("Login completo: " + (t4-t3) + "ms → " + (r.ok ? "✅ OK" : "❌ " + r.error));
  Logger.log("=== FIN TEST ===");
}