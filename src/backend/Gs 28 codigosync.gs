// ══════════════════════════════════════════════════════════════════
// Gs 28 codigosync.gs — AscendaOS v1
// Sistema maestro de sincronización: Apps Script → GitHub + Supabase
//
// SETUP (una sola vez):
//   Apps Script → Proyecto → Configuración → Script properties → Agregar:
//   GITHUB_TOKEN = [tu token de GitHub]
//   SUPABASE_KEY = [ya está configurado]
//
// FUNCIONES:
//   sincronizarTodo()         ← USA ESTO SIEMPRE
//   verActualizaciones()      ← ver versiones en Supabase
//   descargarCodigo('X.html') ← bajar archivo de Supabase
// ══════════════════════════════════════════════════════════════════

var SUPA_URL  = 'https://ituyqwstonmhnfshnaqz.supabase.co';
var GH_REPO   = 'CESARJAUREGUITORRES/ascenda-os';
var GH_BRANCH = 'main';

function _supaKey() { return PropertiesService.getScriptProperties().getProperty('SUPABASE_KEY'); }
function _ghToken() { return PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN'); }

// ══════════════════════════════════════════════════════════════════
// SINCRONIZAR TODO — función principal
// ══════════════════════════════════════════════════════════════════
function sincronizarTodo() {
  var projectId = ScriptApp.getScriptId();
  var token     = ScriptApp.getOAuthToken();
  var ts        = Utilities.formatDate(new Date(), 'America/Lima', 'yyyy-MM-dd HH:mm');

  Logger.log('╔═════════════════════════════════════════╗');
  Logger.log('║  SINCRONIZANDO PROYECTO → GH + SB       ║');
  Logger.log('╚═════════════════════════════════════════╝');

  var resp = UrlFetchApp.fetch(
    'https://script.googleapis.com/v1/projects/' + projectId + '/content',
    { headers: { 'Authorization': 'Bearer ' + token }, muteHttpExceptions: true }
  );

  if (resp.getResponseCode() !== 200) {
    Logger.log('ERROR HTTP ' + resp.getResponseCode());
    Logger.log('Solución: habilita Apps Script API en script.google.com/home/usersettings');
    return;
  }

  var files = JSON.parse(resp.getContentText()).files || [];
  Logger.log('Archivos en el proyecto: ' + files.length);
  Logger.log('─────────────────────────────────────────────');

  var ok = 0, skip = 0, err = 0;
  files.forEach(function(f) {
    if (!f.source || f.source.length < 10) { skip++; return; }
    var esGS = f.type === 'SERVER_JS', esHTML = f.type === 'HTML';
    if (!esGS && !esHTML) { skip++; return; }
    var ext    = esGS ? '.gs' : '.html';
    var nombre = f.name + ext;
    var ghPath = (esGS ? 'src/backend/' : 'src/frontend/') + nombre;
    var msg    = '[' + ts + '] ' + nombre + ' ' + f.source.length + 'c';
    var ghOk = _pushGitHub(ghPath, f.source, msg);
    var sbOk = _upsertSupabase(nombre, f.source, esGS ? 'gs' : 'html', ts);
    Logger.log((ghOk && sbOk ? '✅' : '⚠️') + ' ' + nombre +
               ' (' + f.source.length + 'c)  GH:' + (ghOk?'✓':'✗') + '  SB:' + (sbOk?'✓':'✗'));
    if (ghOk || sbOk) ok++; else err++;
    Utilities.sleep(250);
  });

  Logger.log('─────────────────────────────────────────────');
  Logger.log('RESULTADO: ' + ok + ' sync | ' + skip + ' skip | ' + err + ' err');
  Logger.log('GitHub: https://github.com/' + GH_REPO);
  Logger.log('═════════════════════════════════════════════');
}

// ══════════════════════════════════════════════════════════════════
// VER ACTUALIZACIONES
// ══════════════════════════════════════════════════════════════════
function verActualizaciones() {
  var key  = _supaKey();
  var resp = UrlFetchApp.fetch(
    SUPA_URL + '/rest/v1/aos_codigo_fuente?select=nombre,tipo,descripcion,version_num,updated_at&order=updated_at.desc',
    { headers: { 'apikey': key, 'Authorization': 'Bearer ' + key } }
  );
  var archivos = JSON.parse(resp.getContentText());
  Logger.log('=== CÓDIGO EN SUPABASE (' + archivos.length + ' archivos) ===');
  archivos.forEach(function(a) {
    Logger.log('[' + a.tipo.toUpperCase() + '] ' + a.nombre +
               ' | v' + (a.version_num||1) + ' | ' + (a.updated_at||'').slice(0,16) +
               ' | ' + (a.descripcion||'').slice(0,50));
  });
}

// ══════════════════════════════════════════════════════════════════
// DESCARGAR CÓDIGO desde Supabase al log
// ══════════════════════════════════════════════════════════════════
function descargarCodigo(nombreArchivo) {
  if (!nombreArchivo) { Logger.log('Uso: descargarCodigo("ViewAdvisorCalls.html")'); return null; }
  var key  = _supaKey();
  var resp = UrlFetchApp.fetch(
    SUPA_URL + '/rest/v1/aos_codigo_fuente?nombre=eq.' + encodeURIComponent(nombreArchivo) +
    '&select=nombre,contenido,descripcion,version_num',
    { headers: { 'apikey': key, 'Authorization': 'Bearer ' + key } }
  );
  var data = JSON.parse(resp.getContentText());
  if (!data || !data.length) { Logger.log('No encontrado: ' + nombreArchivo); return null; }
  var archivo = data[0], contenido = archivo.contenido || '';
  Logger.log('=== ' + archivo.nombre + ' v' + (archivo.version_num||1) + ' — ' + contenido.length + ' chars ===');
  Logger.log(archivo.descripcion || '');
  var chunk = 7000;
  if (contenido.length <= chunk) {
    Logger.log(contenido);
  } else {
    var partes = Math.ceil(contenido.length / chunk);
    for (var i = 0; i < partes; i++) {
      Logger.log('─── PARTE ' + (i+1) + '/' + partes + ' ───');
      Logger.log(contenido.slice(i * chunk, (i+1) * chunk));
    }
  }
  return contenido;
}

// ── HELPERS ───────────────────────────────────────────────────────
function _pushGitHub(path, contenido, msg) {
  var ghToken = _ghToken();
  if (!ghToken) { return false; }
  var sha = null;
  try {
    var r = UrlFetchApp.fetch('https://api.github.com/repos/' + GH_REPO + '/contents/' + path,
      { headers: { 'Authorization': 'token ' + ghToken }, muteHttpExceptions: true });
    if (r.getResponseCode() === 200) sha = JSON.parse(r.getContentText()).sha;
  } catch(e) {}
  var body = { message: msg, content: Utilities.base64Encode(contenido, Utilities.Charset.UTF_8), branch: GH_BRANCH };
  if (sha) body.sha = sha;
  var r = UrlFetchApp.fetch('https://api.github.com/repos/' + GH_REPO + '/contents/' + path, {
    method: 'PUT',
    headers: { 'Authorization': 'token ' + ghToken, 'Content-Type': 'application/json' },
    payload: JSON.stringify(body), muteHttpExceptions: true
  });
  return r.getResponseCode() === 200 || r.getResponseCode() === 201;
}

function _upsertSupabase(nombre, contenido, tipo, ts) {
  var key = _supaKey();
  var r = UrlFetchApp.fetch(SUPA_URL + '/rest/v1/aos_codigo_fuente?on_conflict=nombre', {
    method: 'POST',
    headers: { 'apikey': key, 'Authorization': 'Bearer ' + key,
               'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=minimal' },
    payload: JSON.stringify({ nombre: nombre, tipo: tipo, contenido: contenido,
      version_num: 10, descripcion: 'GAS sync ' + (ts||''), updated_at: new Date().toISOString() }),
    muteHttpExceptions: true
  });
  return r.getResponseCode() === 200 || r.getResponseCode() === 201;
}