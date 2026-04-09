/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_00_Shell.gs                             ║
 * ║  Módulo: Funciones puente para el AppShell                  ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config, GS_02_Auth                     ║
 * ║                                                             ║
 * ║  IMPORTANTE: Crear este archivo ANTES de GS_01_Config       ║
 * ║  en el orden del sidebar de Apps Script.                    ║
 * ║  Nombre sugerido: GS_00_Shell.gs                            ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · doGet (punto de entrada único)
 *   MOD-02 · getViewHtml (router de vistas)
 *   MOD-03 · getScriptUrl (helper de URL)
 *   MOD-04 · api_ping (health check)
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · PUNTO DE ENTRADA ÚNICO
// ══════════════════════════════════════════════════════════════
// S01_START

/**
 * doGet — Punto de entrada de la aplicación web
 * ?page=login → Login.html
 * ?page=app   → AppShell.html (con token)
 * default     → Login.html
 */
function doGet(e) {
  var page = (e && e.parameter && e.parameter.page)
    ? e.parameter.page : "login";

  var fileMap = {
    "login":  "Login",
    "app":    "AppShell",
    "admin":  "AppShell",
    "asesor": "AppShell"
  };

  var fileName = fileMap[page] || "Login";

  return HtmlService
    .createHtmlOutputFromFile(fileName)
    .setTitle("AscendaOS v1")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag("viewport", "width=device-width, initial-scale=1.0");
}
// S01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · ROUTER DE VISTAS
// El AppShell llama a esta función para obtener el HTML
// de cada módulo/vista del sistema
// ══════════════════════════════════════════════════════════════
// S02_START

/**
 * getViewHtml — Retorna el contenido HTML de una vista
 * Verifica sesión válida antes de servir el contenido
 *
 * @param {string} fileName - Nombre del archivo HTML (sin extensión .html)
 * @param {string} token    - Token de sesión del usuario
 * @returns {string|null}   - HTML de la vista o null si no autorizado
 */
function getViewHtml(fileName, token) {
  // Verificar sesión
  try {
    _setToken(token);
    var s = cc_getSession(token);
    if (!s || !s.idAsesor) return null;
  } catch(e) {
    return null;
  }

  // Validar que el fileName sea seguro (solo letras, números, guiones)
  if (!fileName || !/^[a-zA-Z0-9_-]+$/.test(fileName)) {
    return "<div style='padding:24px;color:#DC2626;font-family:sans-serif;'>Vista inválida.</div>";
  }

  // Cargar el archivo HTML
  try {
    var html = HtmlService
      .createHtmlOutputFromFile(fileName)
      .getContent();
    return html;
  } catch(e) {
    // Vista todavía no construida
    return "<div style='display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;gap:12px;font-family:sans-serif;'>" +
      "<div style='font-size:32px;'>🔧</div>" +
      "<div style='font-size:14px;font-weight:700;color:#6B7BA8;'>Módulo en construcción</div>" +
      "<div style='font-size:12px;color:#9AAAC8;'>" + fileName + " — Bloque pendiente de instalación</div>" +
      "</div>";
  }
}
// S02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · HELPERS DE URL
// ══════════════════════════════════════════════════════════════
// S03_START

/**
 * getScriptUrl — Retorna la URL de despliegue del script
 * Usada por Login.html y AppShell.html para redirecciones
 * @returns {string} URL de la aplicación web
 */
function getScriptUrl() {
  try {
    return ScriptApp.getService().getUrl();
  } catch(e) {
    return "";
  }
}

/**
 * getAppInfo — Retorna información básica de la app
 * Usada para verificar que el deploy está activo
 * @returns {Object}
 */
function getAppInfo() {
  return {
    nombre:  "AscendaOS",
    version: "1.0.0",
    autor:   "CREACTIVE · César Jáuregui",
    ok:      true
  };
}
// S03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · HEALTH CHECK
// ══════════════════════════════════════════════════════════════
// S04_START

/**
 * api_ping — Verifica que el backend está respondiendo
 * @returns {Object} {ok, ts, version}
 */
function api_ping() {
  return {
    ok:      true,
    ts:      new Date().toISOString(),
    version: "1.0.0",
    sheet:   CFG.SHEET_ID
  };
}

/**
 * api_pingT — Con token (requiere sesión válida)
 */
function api_pingT(token) {
  _setToken(token);
  var s = cc_getSession(token);
  if (!s) return { ok: false, error: "Sin sesión" };
  return {
    ok:      true,
    ts:      new Date().toISOString(),
    asesor:  s.asesor,
    role:    s.role,
    version: "1.0.0"
  };
}
// S04_END

/**
 * TEST: Verificar que el shell responde
 */
function test_Shell() {
  Logger.log("=== AscendaOS GS_00_Shell TEST ===");
  Logger.log("getAppInfo: " + JSON.stringify(getAppInfo()));
  Logger.log("api_ping: "   + JSON.stringify(api_ping()));
  try {
    var url = getScriptUrl();
    Logger.log("Script URL: " + (url || "(no hay deploy activo)"));
  } catch(e) {
    Logger.log("Script URL error: " + e.message);
  }
  Logger.log("=== OK ===");
}