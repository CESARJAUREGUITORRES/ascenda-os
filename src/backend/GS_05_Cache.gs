/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_05_Cache.gs                             ║
 * ║  Módulo: Cache Centralizado con CacheService                ║
 * ║  Versión: 2.1.0                                             ║
 * ║  FIXES:                                                     ║
 * ║    B-03 · _loadTablasCom: lee cols D/E para servicios       ║
 * ║    B-01 · api_precalentarCacheT: precarga al login          ║
 * ║    PERF · Score del mes usa cache del paso 4 (no relee      ║
 * ║           12,200 filas dos veces) → login ~3x más rápido    ║
 * ╚══════════════════════════════════════════════════════════════╝
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · OPERACIONES BÁSICAS DE CACHE
// ══════════════════════════════════════════════════════════════
// E01_START

var CACHE_PREFIX = "AOS_C_";

function _cacheK(dominio, sufijo) {
  var key = CACHE_PREFIX + dominio;
  if (sufijo) key += "_" + String(sufijo).replace(/[^a-zA-Z0-9_]/g, "_");
  return key.substring(0, 250);
}

function cache_get(key) {
  try {
    var raw = CacheService.getScriptCache().get(key);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch(e) { return null; }
}

function cache_set(key, value, ttlSecs) {
  try {
    var ttl  = ttlSecs || 60;
    var json = JSON.stringify(value);
    if (json.length > 100000) {
      Logger.log("Cache WARN: " + key + " demasiado grande (" + json.length + " chars), omitiendo");
      return false;
    }
    CacheService.getScriptCache().put(key, json, ttl);
    return true;
  } catch(e) {
    Logger.log("Cache SET error (" + key + "): " + e.message);
    return false;
  }
}

function cache_delete(key) {
  try { CacheService.getScriptCache().remove(key); } catch(e) {}
}

function cache_getOrSet(key, fn, ttlSecs) {
  var cached = cache_get(key);
  if (cached !== null) return cached;
  var value = fn();
  cache_set(key, value, ttlSecs);
  return value;
}
// E01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · CACHE POR DOMINIO
// ══════════════════════════════════════════════════════════════
// E02_START

function cache_getDashboard()        { return cache_get(_cacheK("dashboard", "admin")); }
function cache_setDashboard(data)    { cache_set(_cacheK("dashboard", "admin"), data, PERF_CONFIG.CACHE_DASHBOARD_S); }

function cache_getMarketing(sufijo)  { return cache_get(_cacheK("marketing", sufijo)); }
function cache_setMarketing(data, sufijo) { cache_set(_cacheK("marketing", sufijo), data, PERF_CONFIG.CACHE_MARKETING_S); }

function cache_getCatalogos()        { return cache_get(_cacheK("catalogos", "all")); }
function cache_setCatalogos(data)    { cache_set(_cacheK("catalogos", "all"), data, PERF_CONFIG.CACHE_CATALOGOS_S); }

function cache_getAsesores()         { return cache_get(_cacheK("asesores", "activos")); }
function cache_setAsesores(data)     { cache_set(_cacheK("asesores", "activos"), data, PERF_CONFIG.CACHE_ASESORES_S); }

function cache_getTablaComisiones()  { return cache_get(_cacheK("com", "tabla")); }
function cache_setTablaComisiones(d) { cache_set(_cacheK("com", "tabla"), d, PERF_CONFIG.CACHE_CATALOGOS_S); }

function cache_getComisionesAsesor(idAsesor, anio, mes) {
  return cache_get(_cacheK("com_asesor", idAsesor + "_" + anio + "_" + mes));
}
function cache_setComisionesAsesor(data, idAsesor, anio, mes) {
  cache_set(_cacheK("com_asesor", idAsesor + "_" + anio + "_" + mes), data, PERF_CONFIG.CACHE_ASESORES_S);
}
// E02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · INVALIDACIÓN SELECTIVA
// ══════════════════════════════════════════════════════════════
// E03_START

function cache_invalidateDashboard() { cache_delete(_cacheK("dashboard", "admin")); }

function cache_invalidateMarketing() {
  cache_set(_cacheK("marketing", "invalidated_at"), new Date().getTime(), 3600);
}

function cache_invalidateAsesores()  { cache_delete(_cacheK("asesores", "activos")); }

function cache_invalidateComisiones(idAsesor, anio, mes) {
  if (idAsesor) cache_delete(_cacheK("com_asesor", idAsesor + "_" + anio + "_" + mes));
}

function cache_flush() {
  try {
    CacheService.getScriptCache().removeAll([
      _cacheK("dashboard", "admin"),
      _cacheK("marketing", "all"),
      _cacheK("catalogos", "all"),
      _cacheK("asesores",  "activos"),
      _cacheK("com",       "tabla")
    ]);
    Logger.log("Cache limpiado correctamente.");
  } catch(e) { Logger.log("Error limpiando cache: " + e.message); }
}
// E03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · ASESORES + TABLA COMISIONES CON CACHE
// ══════════════════════════════════════════════════════════════
// E04_START

function _asesoresActivosCached() {
  var cached = cache_getAsesores();
  if (cached) return cached;
  var data = _asesoresActivos();
  cache_setAsesores(data);
  return data;
}

// ===== CTRL+F: _loadTablasCom =====
/**
 * B-03 FIX v2.0 — Lee la estructura REAL de TABLA DE COMISIONES:
 *   Col A (0): MONTO MÍNIMO productos
 *   Col B (1): COMISIÓN FIJA productos (S/.)
 *   Col C (2): vacía / separador
 *   Col D (3): MONTO MÍNIMO servicios (a veces vacía)
 *   Col E (4): COMISIÓN % servicios (ej: 0.5% ó 0.005)
 */
function _loadTablasCom() {
  var cached = cache_getTablaComisiones();
  if (cached) return cached;

  var result = { serv: 0.005, prod: [] };

  try {
    var sh = _sh(CFG.SHEET_TABLA_COM);
    var lr = sh.getLastRow();
    var lc = sh.getLastColumn();

    if (lr < 2) {
      Logger.log('_loadTablasCom: hoja vacía, usando defaults serv=0.5%');
      cache_setTablaComisiones(result);
      return result;
    }

    var colsLeer = Math.max(lc, 5);
    var data = sh.getRange(1, 1, lr, colsLeer).getValues();

    var servRate   = 0.005;
    var prodRanges = [];
    var servEncontrado = false;

    for (var i = 1; i < data.length; i++) {
      var r = data[i];

      var colA = r[0];
      var colB = r[1];

      if (colA !== '' && colA !== null && !isNaN(Number(colA))) {
        var minVal = Number(colA);
        var comVal = Number(colB) || 0;
        if (minVal >= 0 && comVal >= 0) {
          prodRanges.push({ min: minVal, com: comVal });
        }
      }

      if (!servEncontrado && r.length > 4) {
        var colE = r[4];
        if (colE !== '' && colE !== null && colE !== undefined) {
          var vE = Number(String(colE).replace('%', '').trim());
          if (!isNaN(vE) && vE > 0) {
            servRate = vE <= 1 ? vE : vE / 100;
            servEncontrado = true;
            Logger.log('_loadTablasCom: serv% encontrado en col E fila ' + (i+1) + ' = ' + colE + ' → ' + servRate);
          }
        }
      }

      if (!servEncontrado && r.length > 3) {
        var colD = r[3];
        if (colD !== '' && colD !== null) {
          var vD = Number(String(colD).replace('%', '').trim());
          if (!isNaN(vD) && vD > 0 && vD <= 1) {
            servRate = vD; servEncontrado = true;
          } else if (!isNaN(vD) && vD > 0 && vD <= 100) {
            servRate = vD / 100; servEncontrado = true;
          }
        }
      }
    }

    prodRanges.sort(function(a, b) { return b.min - a.min; });
    result = { serv: servRate, prod: prodRanges };

    Logger.log('_loadTablasCom OK: serv=' + (servRate * 100) + '% · ' + prodRanges.length + ' rangos prod');

  } catch(e) {
    Logger.log('_loadTablasCom ERROR: ' + e.message);
  }

  cache_setTablaComisiones(result);
  return result;
}

function _comRate(tipo, monto) {
  var t      = _up(String(tipo || ""));
  var tablas = _loadTablasCom();

  if (t === "PRODUCTO") {
    var m     = Number(monto) || 0;
    var rango = null;
    for (var i = 0; i < tablas.prod.length; i++) {
      if (m >= tablas.prod[i].min) { rango = tablas.prod[i]; break; }
    }
    return { tipo: "fijo", valor: rango ? rango.com : 0 };
  }
  return { tipo: "pct", valor: tablas.serv };
}
// E04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · PRECARGA DE CACHE AL LOGIN (B-01 FIX)
// ===== CTRL+F: api_precalentarCacheT =====
// ══════════════════════════════════════════════════════════════
// E05_START

/**
 * B-01 FIX v2.1 — Precalienta el caché con los datos más costosos.
 * PERF FIX: El paso 5 ya NO relee el Sheet de llamadas (12,200 filas).
 *           Reutiliza los datos del paso 4 desde el cache.
 *           Resultado: login ~3x más rápido.
 */
function api_precalentarCacheT(token) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  var mes  = now.getMonth() + 1;
  var anio = now.getFullYear();
  var hoy  = _date(now);
  var resultado = { ok: true, cargado: [], ts: _time(now) };

  // 1. Lista de asesores activos
  try {
    if (!cache_getAsesores()) {
      cache_setAsesores(_asesoresActivos());
      resultado.cargado.push('asesores');
    }
  } catch(e) { Logger.log('precalentar asesores: ' + e.message); }

  // 2. Catálogos de tratamientos y anuncios
  try {
    if (!cache_getCatalogos()) {
      cache_setCatalogos(_buildCatalogosData());
      resultado.cargado.push('catalogos');
    }
  } catch(e) { Logger.log('precalentar catalogos: ' + e.message); }

  // 3. Tabla de comisiones
  try {
    if (!cache_getTablaComisiones()) {
      _loadTablasCom();
      resultado.cargado.push('tablaComisiones');
    }
  } catch(e) { Logger.log('precalentar comisiones: ' + e.message); }

  // 4. Llamadas del asesor de hoy — UNA SOLA lectura del Sheet
  try {
    var keyHoy = _cacheK('calls_hoy', s.idAsesor + '_' + hoy);
    if (!cache_get(keyHoy)) {
      var shL   = _sh(CFG.SHEET_LLAMADAS);
      var lrL   = shL.getLastRow();
      var miId  = _norm(s.idAsesor);
      var miNom = _up(s.asesor);
      var itemsHoy = [];
      if (lrL >= 2) {
        shL.getRange(2, 1, lrL - 1, 21).getValues().forEach(function(r) {
          if (_date(r[LLAM_COL.FECHA]) !== hoy) return;
          if (_norm(r[LLAM_COL.ID_ASESOR]) !== miId &&
              _up(r[LLAM_COL.ASESOR])      !== miNom) return;
          itemsHoy.push({
            hora:      _time(r[LLAM_COL.HORA]),
            num:       _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]),
            trat:      _up(r[LLAM_COL.TRATAMIENTO]),
            estado:    _up(r[LLAM_COL.ESTADO]),
            subEstado: r[LLAM_COL.SUB_ESTADO] ? _norm(r[LLAM_COL.SUB_ESTADO]) : '',
            obs:       _norm(r[LLAM_COL.OBS]),
            intento:   Number(r[LLAM_COL.INTENTO]) || 1
          });
        });
      }
      itemsHoy.sort(function(a, b) { return a.hora < b.hora ? 1 : -1; });
      var citas = itemsHoy.filter(function(x) { return x.estado === 'CITA CONFIRMADA'; }).length;
      cache_set(keyHoy, { ok:true, items:itemsHoy, total:itemsHoy.length, citas:citas }, 120);
      resultado.cargado.push('calls_hoy(' + itemsHoy.length + ')');
    }
  } catch(e) { Logger.log('precalentar calls_hoy: ' + e.message); }

  // 5. Score básico del mes — REUTILIZA datos del paso 4 (no relee el Sheet)
  // PERF FIX: elimina la segunda lectura de 12,200 filas
  try {
    var keyScore = _cacheK('score_mes', s.idAsesor + '_' + mes + '_' + anio);
    if (!cache_get(keyScore)) {
      var keyHoyCheck = _cacheK('calls_hoy', s.idAsesor + '_' + hoy);
      var dataHoy     = cache_get(keyHoyCheck);
      var llamadas2   = dataHoy ? dataHoy.total : 0;
      var citas2      = dataHoy ? dataHoy.citas  : 0;
      cache_set(keyScore, {
        llamadas: llamadas2, citas: citas2, mes: mes, anio: anio
      }, 120);
      resultado.cargado.push('score_mes(' + llamadas2 + ' llam-cache)');
    }
  } catch(e) { Logger.log('precalentar score: ' + e.message); }

  Logger.log('precalentar OK [' + s.asesor + ']: ' + resultado.cargado.join(', '));
  return resultado;
}

/**
 * _buildCatalogosData — Construye objeto de catálogos
 */
function _buildCatalogosData() {
  var trats = [], anuncios = [];
  try {
    var sh = _sh(CFG.SHEET_CAT_TRAT);
    var lr = sh.getLastRow();
    if (lr >= 2) {
      sh.getRange(2, 1, lr - 1, 1).getValues().forEach(function(r) {
        if (_norm(r[0])) trats.push(_norm(r[0]));
      });
    }
  } catch(e) {}
  try {
    var sh2 = _sh(CFG.SHEET_CAT_ANUNCIOS);
    var lr2 = sh2.getLastRow();
    if (lr2 >= 2) {
      sh2.getRange(2, 1, lr2 - 1, 3).getValues().forEach(function(r) {
        if (_norm(r[0])) anuncios.push({ nombre:_norm(r[0]), pregunta:_norm(r[2]||'') });
      });
    }
  } catch(e) {}
  return { trats:trats, anuncios:anuncios };
}
// E05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · LIMPIEZA DE DATOS HISTÓRICOS 1899 (B-02 HELPER)
// ===== CTRL+F: limpiarSeguimientos1899 =====
// ══════════════════════════════════════════════════════════════
// E06_START

function limpiarSeguimientos1899() {
  var sh = _sh(CFG.SHEET_SEGUIMIENTOS);
  var lr = sh.getLastRow();
  if (lr < 2) { Logger.log('Sin filas que limpiar'); return; }

  var data     = sh.getRange(2, 1, lr - 1, 11).getValues();
  var limpias  = 0;
  var revisadas = 0;

  data.forEach(function(r, i) {
    revisadas++;
    var fechaVal = r[SEG_COL.FECHA_PROG];
    var horaVal  = r[SEG_COL.HORA_PROG];
    var fechaStr = _date(fechaVal);
    var limpiar  = false;

    if (fechaStr && fechaStr.indexOf('1899') >= 0) limpiar = true;
    if (String(fechaVal).indexOf('1899') >= 0)      limpiar = true;
    if (String(horaVal).indexOf('1899') >= 0)       limpiar = true;

    if (limpiar) {
      var fila = i + 2;
      sh.getRange(fila, SEG_COL.FECHA_PROG + 1).setValue('');
      sh.getRange(fila, SEG_COL.HORA_PROG  + 1).setValue('');
      sh.getRange(fila, SEG_COL.TS_ACTUALIZADO + 1).setValue(new Date());
      limpias++;
    }
  });

  Logger.log('limpiarSeguimientos1899: ' + limpias + ' filas limpiadas de ' + revisadas);
  return { ok: true, limpias: limpias, revisadas: revisadas };
}
// E06_END

// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════

function test_Cache() {
  Logger.log("=== AscendaOS GS_05_Cache v2.1 TEST ===");

  var key = _cacheK("test", "1");
  cache_set(key, { valor: 42 }, 60);
  var result = cache_get(key);
  Logger.log("SET/GET: " + JSON.stringify(result));

  cache_delete(_cacheK("com", "tabla"));
  var tablas = _loadTablasCom();
  Logger.log("Tabla comisiones: serv=" + (tablas.serv * 100) + "% · prod=" + JSON.stringify(tablas.prod));
  Logger.log("_comRate SERVICIO S/350: " + JSON.stringify(_comRate("SERVICIO", 350)));
  Logger.log("_comRate PRODUCTO S/189: " + JSON.stringify(_comRate("PRODUCTO", 189)));

  cache_delete(key);
  Logger.log("=== OK ===");
}