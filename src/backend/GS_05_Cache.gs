/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_05_Cache.gs                             ║
 * ║  Módulo: Cache Centralizado con CacheService                ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config, GS_03_CoreHelpers             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Operaciones básicas de cache
 *   MOD-02 · Cache por dominio con TTL específico
 *   MOD-03 · Invalidación selectiva
 *   MOD-04 · Wrappers con cache para funciones pesadas
 *
 * ESTRATEGIA:
 *   - Dashboard Admin: 60s (se refresca cada 1 min)
 *   - Marketing: 300s (5 min, datos no cambian constantemente)
 *   - Catálogos: 600s (10 min, muy estables)
 *   - Asesores: 120s (2 min, pueden cambiar su estado)
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · OPERACIONES BÁSICAS DE CACHE
// ══════════════════════════════════════════════════════════════
// E01_START

var CACHE_PREFIX = "AOS_C_";

/**
 * Genera una clave de cache normalizada
 * @param {string} dominio - "dashboard" | "marketing" | "catalogos" | etc.
 * @param {string} sufijo - Parámetros adicionales para diferenciar
 * @returns {string} Clave de cache
 */
function _cacheK(dominio, sufijo) {
  var key = CACHE_PREFIX + dominio;
  if (sufijo) key += "_" + String(sufijo).replace(/[^a-zA-Z0-9_]/g, "_");
  return key.substring(0, 250); // CacheService tiene límite de 250 chars
}

/**
 * Lee un valor del cache
 * @param {string} key
 * @returns {*|null} El valor parseado o null si no existe/expiró
 */
function cache_get(key) {
  try {
    var raw = CacheService.getScriptCache().get(key);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch(e) {
    return null;
  }
}

/**
 * Escribe un valor en el cache
 * @param {string} key
 * @param {*} value - Será serializado a JSON
 * @param {number} ttlSecs - Segundos de vida (default: 60)
 * @returns {boolean} true si se guardó correctamente
 */
function cache_set(key, value, ttlSecs) {
  try {
    var ttl = ttlSecs || 60;
    var json = JSON.stringify(value);
    // CacheService tiene límite de 100KB por entrada
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

/**
 * Elimina una entrada del cache
 * @param {string} key
 */
function cache_delete(key) {
  try {
    CacheService.getScriptCache().remove(key);
  } catch(e) {}
}

/**
 * Lee del cache; si no existe, ejecuta la función y guarda el resultado
 * Patrón: cache-aside (read-through)
 *
 * @param {string} key - Clave del cache
 * @param {Function} fn - Función que genera el valor si no hay cache
 * @param {number} ttlSecs - TTL en segundos
 * @returns {*} El valor (del cache o recién generado)
 */
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
// Funciones con TTL específico por módulo
// ══════════════════════════════════════════════════════════════
// E02_START

/**
 * Cache para el dashboard del Admin
 * TTL: 60 segundos
 */
function cache_getDashboard() {
  return cache_get(_cacheK("dashboard", "admin"));
}
function cache_setDashboard(data) {
  cache_set(_cacheK("dashboard", "admin"), data, PERF_CONFIG.CACHE_DASHBOARD_S);
}

/**
 * Cache para datos de Marketing
 * TTL: 300 segundos (5 minutos)
 * @param {string} sufijo - Ej: "mes_4_2026" para diferenciar períodos
 */
function cache_getMarketing(sufijo) {
  return cache_get(_cacheK("marketing", sufijo));
}
function cache_setMarketing(data, sufijo) {
  cache_set(_cacheK("marketing", sufijo), data, PERF_CONFIG.CACHE_MARKETING_S);
}

/**
 * Cache para catálogos (tratamientos, anuncios)
 * TTL: 600 segundos (10 minutos)
 */
function cache_getCatalogos() {
  return cache_get(_cacheK("catalogos", "all"));
}
function cache_setCatalogos(data) {
  cache_set(_cacheK("catalogos", "all"), data, PERF_CONFIG.CACHE_CATALOGOS_S);
}

/**
 * Cache para lista de asesores activos
 * TTL: 120 segundos (2 minutos)
 */
function cache_getAsesores() {
  return cache_get(_cacheK("asesores", "activos"));
}
function cache_setAsesores(data) {
  cache_set(_cacheK("asesores", "activos"), data, PERF_CONFIG.CACHE_ASESORES_S);
}

/**
 * Cache para tabla de comisiones (reglas)
 * TTL: 600 segundos (muy estable)
 */
function cache_getTablaComisiones() {
  return cache_get(_cacheK("com", "tabla"));
}
function cache_setTablaComisiones(data) {
  cache_set(_cacheK("com", "tabla"), data, PERF_CONFIG.CACHE_CATALOGOS_S);
}

/**
 * Cache para comisiones del mes de un asesor
 * TTL: 120 segundos
 * @param {string} idAsesor
 * @param {number} año
 * @param {number} mes
 */
function cache_getComisionesAsesor(idAsesor, anio, mes) {
  return cache_get(_cacheK("com_asesor", idAsesor + "_" + anio + "_" + mes));
}
function cache_setComisionesAsesor(data, idAsesor, anio, mes) {
  cache_set(
    _cacheK("com_asesor", idAsesor + "_" + anio + "_" + mes),
    data,
    PERF_CONFIG.CACHE_ASESORES_S
  );
}
// E02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · INVALIDACIÓN SELECTIVA
// ══════════════════════════════════════════════════════════════
// E03_START

/**
 * Invalida el cache del dashboard cuando hay cambios operativos
 * Llamar después de: guardar llamada, guardar venta, cambiar estado
 */
function cache_invalidateDashboard() {
  cache_delete(_cacheK("dashboard", "admin"));
}

/**
 * Invalida el cache de marketing
 * Llamar después de: nuevos leads, nuevas ventas
 */
function cache_invalidateMarketing() {
  // Invalida todas las claves de marketing conocidas
  // No podemos listar claves en CacheService, así que
  // usamos un timestamp de invalidación
  cache_set(_cacheK("marketing", "invalidated_at"),
    new Date().getTime(), 3600);
}

/**
 * Invalida el cache de asesores
 * Llamar después de: cambios en RRHH
 */
function cache_invalidateAsesores() {
  cache_delete(_cacheK("asesores", "activos"));
}

/**
 * Invalida el cache de comisiones de un asesor
 * @param {string} idAsesor
 * @param {number} anio
 * @param {number} mes
 */
function cache_invalidateComisiones(idAsesor, anio, mes) {
  if (idAsesor) {
    cache_delete(_cacheK("com_asesor", idAsesor + "_" + anio + "_" + mes));
  }
}

/**
 * Limpia TODO el cache del sistema (usar con cuidado)
 */
function cache_flush() {
  try {
    CacheService.getScriptCache().removeAll([
      _cacheK("dashboard", "admin"),
      _cacheK("marketing", "all"),
      _cacheK("catalogos", "all"),
      _cacheK("asesores", "activos"),
      _cacheK("com", "tabla")
    ]);
    Logger.log("Cache limpiado correctamente.");
  } catch(e) {
    Logger.log("Error limpiando cache: " + e.message);
  }
}
// E03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · ASESORES CON CACHE
// Versión cacheada de _asesoresActivos()
// ══════════════════════════════════════════════════════════════
// E04_START

/**
 * _asesoresActivosCached — Versión con cache de _asesoresActivos()
 * Usa cache de 120s para evitar lecturas repetidas del Sheet RRHH
 * @returns {Array} Lista de asesores activos
 */
function _asesoresActivosCached() {
  var cached = cache_getAsesores();
  if (cached) return cached;

  var data = _asesoresActivos();
  cache_setAsesores(data);
  return data;
}

/**
 * _loadTablasCom — Carga y cachea la tabla de comisiones
 * @returns {Object} {serv: rate, prod: [{min, com}, ...]}
 */
function _loadTablasCom() {
  var cached = cache_getTablaComisiones();
  if (cached) return cached;

  var result = { serv: 0.005, prod: [] };
  try {
    var sh = _sh(CFG.SHEET_TABLA_COM);
    var lr = sh.getLastRow();
    if (lr >= 2) {
      var data = sh.getRange(1, 1, lr, 5).getValues();
      var servRate  = 0.005;
      var prodRanges = [];

      for (var i = 1; i < data.length; i++) {
        var r = data[i];
        if (r[0] !== "" && r[0] !== null && r[1] !== "" && r[1] !== null) {
          var minVal = Number(r[0]);
          var comVal = Number(r[1]);
          if (!isNaN(minVal) && !isNaN(comVal)) {
            prodRanges.push({ min: minVal, com: comVal });
          }
        }
        if (i === 1 && r[4] !== null && r[4] !== "") {
          var v = Number(r[4]) || 0;
          if (v > 0) servRate = v * 10;
        }
      }

      prodRanges.sort(function(a, b) { return b.min - a.min; });
      result = { serv: servRate, prod: prodRanges };
    }
  } catch(e) {
    Logger.log("_loadTablasCom error: " + e.message);
  }

  cache_setTablaComisiones(result);
  return result;
}

/**
 * _comRate — Calcula la tasa de comisión para un tipo y monto
 * @param {string} tipo - "SERVICIO" | "PRODUCTO"
 * @param {number} monto
 * @returns {Object} {tipo: "fijo"|"pct", valor: number}
 */
function _comRate(tipo, monto) {
  var t      = _up(String(tipo || ""));
  var tablas = _loadTablasCom();

  if (t === "PRODUCTO") {
    var m     = Number(monto) || 0;
    var rango = tablas.prod.find(function(r) { return m >= r.min; });
    return { tipo: "fijo", valor: rango ? rango.com : 0 };
  }
  return { tipo: "pct", valor: tablas.serv };
}
// E04_END

/**
 * TEST: Verificar funcionamiento del cache
 */
function test_Cache() {
  Logger.log("=== AscendaOS GS_05_Cache TEST ===");

  // Test set/get
  var key = _cacheK("test", "1");
  cache_set(key, { valor: 42, texto: "AscendaOS" }, 60);
  var result = cache_get(key);
  Logger.log("SET/GET: " + JSON.stringify(result));

  // Test cache_getOrSet
  var key2 = _cacheK("test", "2");
  var computed = cache_getOrSet(key2, function() {
    return { generado: true, ts: new Date().toISOString() };
  }, 60);
  Logger.log("getOrSet (1ra vez): " + JSON.stringify(computed));
  var computed2 = cache_getOrSet(key2, function() {
    return { generado: true, ts: "NO DEBERIA EJECUTARSE" };
  }, 60);
  Logger.log("getOrSet (2da vez, desde cache): " + JSON.stringify(computed2));

  // Test tabla comisiones
  var tablas = _loadTablasCom();
  Logger.log("Tabla comisiones: " + JSON.stringify(tablas));

  // Limpieza
  cache_delete(key);
  cache_delete(key2);
  Logger.log("=== OK ===");
}