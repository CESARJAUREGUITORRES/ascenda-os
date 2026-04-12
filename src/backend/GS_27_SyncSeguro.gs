/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_27_SyncSeguro.gs                        ║
 * ║  Módulo: Sincronización segura Sheets → Supabase            ║
 * ║  Versión: 1.0.0                                             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * PROPÓSITO:
 *   Red de seguridad que garantiza que TODOS los datos del Excel
 *   lleguen a Supabase, sin importar si el asesor usa la app nueva
 *   o tipifica directo en Sheets.
 *
 * FUNCIONES PRINCIPALES:
 *   syncHoy()                   → Sincroniza hoy + ayer (ejecutar manual)
 *   instalarTriggerSyncSeguro() → Instala trigger cada 10 min (ejecutar 1 vez)
 *   desinstalarTrigger()        → Remueve el trigger si es necesario
 *
 * TABLAS QUE SINCRONIZA:
 *   - aos_llamadas   ← CONSOLIDADO DE LLAMADAS
 *   - aos_ventas     ← CONSOLIDADO DE VENTAS
 *   - aos_agenda_citas ← AGENDA_CITAS
 *   - aos_leads      ← LEADS (solo nuevos del día)
 *
 * CÓMO INSTALAR:
 *   1. Crear archivo GS_27_SyncSeguro.gs en Apps Script
 *   2. Pegar este código
 *   3. Ejecutar instalarTriggerSyncSeguro() UNA SOLA VEZ
 *   4. Verificar en Triggers que aparece syncCada10Min
 */

// ===== CTRL+F: SS_CONFIG =====
var SS_SUPABASE_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co';
var SS_SHEET_ID     = '1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM';

function _ssKey() {
  return PropertiesService.getScriptProperties().getProperty('SUPABASE_KEY') || '';
}

function _ssHeaders() {
  var key = _ssKey();
  return {
    'apikey':        key,
    'Authorization': 'Bearer ' + key,
    'Content-Type':  'application/json',
    'Prefer':        'resolution=merge-duplicates,return=minimal'
  };
}

function _ssUpsert(tabla, lote) {
  if (!lote || !lote.length) return { ok: true, insertados: 0 };
  var url = SS_SUPABASE_URL + '/rest/v1/' + tabla;
  try {
    var resp = UrlFetchApp.fetch(url, {
      method: 'POST',
      headers: _ssHeaders(),
      payload: JSON.stringify(lote),
      muteHttpExceptions: true
    });
    var code = resp.getResponseCode();
    if (code >= 200 && code < 300) {
      return { ok: true, insertados: lote.length };
    } else {
      Logger.log('❌ ' + tabla + ' [' + code + ']: ' + resp.getContentText().slice(0, 200));
      return { ok: false, error: resp.getContentText().slice(0, 200) };
    }
  } catch(e) {
    Logger.log('❌ ' + tabla + ' fetch error: ' + e.message);
    return { ok: false, error: e.message };
  }
}
// ===== CTRL+F: SS_CONFIG_END =====


// ══════════════════════════════════════════════════════════════
// MOD-01 · SYNC LLAMADAS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SS_LLAMADAS =====

function _syncLlamadas(desde, hasta) {
  var ss  = SpreadsheetApp.openById(SS_SHEET_ID);
  var sh  = ss.getSheetByName('CONSOLIDADO DE LLAMADAS');
  if (!sh) { Logger.log('⚠️ Hoja CONSOLIDADO DE LLAMADAS no encontrada'); return 0; }

  var lr  = sh.getLastRow();
  if (lr < 2) return 0;

  // Leer en bloques de 1000 para no exceder memoria
  var BATCH = 500;
  var total = 0;

  for (var i = 2; i <= lr; i += BATCH) {
    var cant = Math.min(BATCH, lr - i + 1);
    var data = sh.getRange(i, 1, cant, 20).getValues();

    var lote = [];
    data.forEach(function(r) {
      var fecha = r[0];
      if (!fecha) return;

      var fechaStr = '';
      try {
        var d = fecha instanceof Date ? fecha : new Date(fecha);
        if (isNaN(d)) return;
        fechaStr = Utilities.formatDate(d, 'America/Lima', 'yyyy-MM-dd');
      } catch(e) { return; }

      // Filtrar por rango de fechas
      if (fechaStr < desde || fechaStr > hasta) return;

      var num = String(r[1] || '').replace(/\D/g, '');
      if (!num) return;

      // Hora llamada
      var horaStr = '';
      try {
        var h = r[5];
        if (h instanceof Date) horaStr = Utilities.formatDate(h, 'America/Lima', 'HH:mm:ss');
        else if (h) horaStr = String(h);
      } catch(e) {}

      // ULT_TS
      var ultTs = null;
      try {
        var ut = r[13];
        if (ut instanceof Date && !isNaN(ut)) ultTs = ut.toISOString();
        else if (ut) ultTs = new Date(ut).toISOString();
      } catch(e) {}

      // PROX_REIN
      var proxRein = null;
      try {
        var pr = r[14];
        if (pr instanceof Date && !isNaN(pr)) proxRein = pr.toISOString();
        else if (pr) proxRein = new Date(pr).toISOString();
      } catch(e) {}

      lote.push({
        fecha:         fechaStr,
        numero:        String(r[1] || ''),
        tratamiento:   String(r[2] || '').toUpperCase(),
        estado:        String(r[3] || '').toUpperCase(),
        observacion:   String(r[4] || '').slice(0, 500),
        hora_llamada:  horaStr,
        asesor:        String(r[6] || ''),
        numero_limpio: num,
        id_asesor:     String(r[9] || ''),
        anuncio:       String(r[10] || ''),
        intento:       Number(r[12]) || 1,
        ult_ts:        ultTs,
        prox_rein:     proxRein,
        resultado:     String(r[15] || '').toUpperCase(),
        sub_estado:    String(r[16] || '')
      });
    });

    if (lote.length > 0) {
      var res = _ssUpsert('aos_llamadas', lote);
      if (res.ok) total += res.insertados;
    }
  }

  Logger.log('✅ Llamadas sincronizadas: ' + total);
  return total;
}
// ===== CTRL+F: SS_LLAMADAS_END =====


// ══════════════════════════════════════════════════════════════
// MOD-02 · SYNC VENTAS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SS_VENTAS =====

function _syncVentas(desde, hasta) {
  var ss = SpreadsheetApp.openById(SS_SHEET_ID);
  var sh = ss.getSheetByName('CONSOLIDADO DE VENTAS');
  if (!sh) { Logger.log('⚠️ Hoja CONSOLIDADO DE VENTAS no encontrada'); return 0; }

  var lr = sh.getLastRow();
  if (lr < 2) return 0;

  var BATCH = 500;
  var total = 0;

  for (var i = 2; i <= lr; i += BATCH) {
    var cant = Math.min(BATCH, lr - i + 1);
    var data = sh.getRange(i, 1, cant, 16).getValues();

    var lote = [];
    data.forEach(function(r) {
      var fecha = r[0];
      if (!fecha) return;

      var fechaStr = '';
      try {
        var d = fecha instanceof Date ? fecha : new Date(fecha);
        if (isNaN(d)) return;
        fechaStr = Utilities.formatDate(d, 'America/Lima', 'yyyy-MM-dd');
      } catch(e) { return; }

      if (fechaStr < desde || fechaStr > hasta) return;

      var ventaId = String(r[1] || '').trim();
      if (!ventaId) return;

      var num = String(r[12] || r[2] || '').replace(/\D/g, '');

      lote.push({
        venta_id:      ventaId,
        fecha:         fechaStr,
        nombres:       String(r[3] || ''),
        apellidos:     String(r[4] || ''),
        tratamiento:   String(r[5] || ''),
        descripcion:   String(r[6] || '').slice(0, 300),
        pago:          String(r[7] || ''),
        monto:         Number(r[8]) || 0,
        estado_pago:   String(r[9] || '').toUpperCase(),
        asesor:        String(r[10] || ''),
        sede:          String(r[11] || '').toUpperCase(),
        numero_limpio: num,
        tipo:          'SERVICIO'
      });
    });

    if (lote.length > 0) {
      var res = _ssUpsert('aos_ventas', lote);
      if (res.ok) total += res.insertados;
    }
  }

  Logger.log('✅ Ventas sincronizadas: ' + total);
  return total;
}
// ===== CTRL+F: SS_VENTAS_END =====


// ══════════════════════════════════════════════════════════════
// MOD-03 · SYNC AGENDA CITAS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SS_AGENDA =====

function _syncAgenda(desde, hasta) {
  var ss = SpreadsheetApp.openById(SS_SHEET_ID);
  var sh = ss.getSheetByName('AGENDA_CITAS');
  if (!sh) { Logger.log('⚠️ Hoja AGENDA_CITAS no encontrada'); return 0; }

  var lr = sh.getLastRow();
  if (lr < 2) return 0;

  var BATCH = 500;
  var total = 0;

  for (var i = 2; i <= lr; i += BATCH) {
    var cant = Math.min(BATCH, lr - i + 1);
    var data = sh.getRange(i, 1, cant, 22).getValues();

    var lote = [];
    data.forEach(function(r) {
      var id = String(r[0] || '').trim();
      if (!id) return;

      var fechaCita = '';
      try {
        var d = r[1] instanceof Date ? r[1] : new Date(r[1]);
        if (!isNaN(d)) fechaCita = Utilities.formatDate(d, 'America/Lima', 'yyyy-MM-dd');
      } catch(e) {}

      // Filtrar por TS_CREADO (col 15) o FECHA_CITA
      var tsCreado = null;
      try {
        var tc = r[15];
        if (tc instanceof Date && !isNaN(tc)) {
          tsCreado = tc.toISOString();
          var tcStr = Utilities.formatDate(tc, 'America/Lima', 'yyyy-MM-dd');
          if (tcStr < desde || tcStr > hasta) return;
        } else if (fechaCita && (fechaCita < desde || fechaCita > hasta)) {
          return;
        }
      } catch(e) {
        if (fechaCita && (fechaCita < desde || fechaCita > hasta)) return;
      }

      var num = String(r[4] || '').replace(/\D/g, '');

      // Hora cita
      var horaCita = '';
      try {
        var hc = r[17];
        if (hc instanceof Date) horaCita = Utilities.formatDate(hc, 'America/Lima', 'HH:mm');
        else if (hc) horaCita = String(hc);
      } catch(e) {}

      lote.push({
        id:            id,
        fecha_cita:    fechaCita,
        tratamiento:   String(r[2] || ''),
        tipo_cita:     String(r[3] || ''),
        numero:        num,
        nombre:        String(r[5] || ''),
        apellido:      String(r[6] || ''),
        asesor:        String(r[9] || ''),
        id_asesor:     String(r[10] || ''),
        estado_cita:   String(r[11] || 'PENDIENTE').toUpperCase(),
        sede:          String(r[8] || '').toUpperCase(),
        hora_cita:     horaCita,
        doctora:       String(r[18] || ''),
        obs:           String(r[12] || '').slice(0, 300),
        ts_creado:     tsCreado,
        ts_actualizado: new Date().toISOString()
      });
    });

    if (lote.length > 0) {
      var res = _ssUpsert('aos_agenda_citas', lote);
      if (res.ok) total += res.insertados;
    }
  }

  Logger.log('✅ Citas sincronizadas: ' + total);
  return total;
}
// ===== CTRL+F: SS_AGENDA_END =====


// ══════════════════════════════════════════════════════════════
// MOD-04 · SYNC LEADS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SS_LEADS =====

function _syncLeads(desde, hasta) {
  var ss = SpreadsheetApp.openById(SS_SHEET_ID);
  var sh = ss.getSheetByName('LEADS');
  if (!sh) {
    // Intentar nombre alternativo
    sh = ss.getSheetByName('CONSOLIDADO DE LEADS');
    if (!sh) { Logger.log('⚠️ Hoja LEADS no encontrada'); return 0; }
  }

  var lr = sh.getLastRow();
  if (lr < 2) return 0;

  var BATCH = 500;
  var total = 0;

  for (var i = 2; i <= lr; i += BATCH) {
    var cant = Math.min(BATCH, lr - i + 1);
    var data = sh.getRange(i, 1, cant, 9).getValues();

    var lote = [];
    data.forEach(function(r) {
      var fecha = r[0];
      if (!fecha) return;

      var fechaStr = '';
      try {
        var d = fecha instanceof Date ? fecha : new Date(fecha);
        if (isNaN(d)) return;
        fechaStr = Utilities.formatDate(d, 'America/Lima', 'yyyy-MM-dd');
      } catch(e) { return; }

      if (fechaStr < desde || fechaStr > hasta) return;

      var num = String(r[5] || r[1] || '').replace(/\D/g, '');
      if (!num) return;

      lote.push({
        fecha:         fechaStr,
        celular:       String(r[1] || ''),
        tratamiento:   String(r[2] || '').toUpperCase(),
        anuncio:       String(r[3] || ''),
        preguntas:     String(r[4] || '').slice(0, 500),
        numero_limpio: num
      });
    });

    if (lote.length > 0) {
      // Leads usa INSERT (no upsert) porque pueden duplicarse por fecha
      var url = SS_SUPABASE_URL + '/rest/v1/aos_leads';
      var headers = _ssHeaders();
      headers['Prefer'] = 'resolution=ignore-duplicates,return=minimal';
      try {
        var resp = UrlFetchApp.fetch(url, {
          method: 'POST',
          headers: headers,
          payload: JSON.stringify(lote),
          muteHttpExceptions: true
        });
        var code = resp.getResponseCode();
        if (code >= 200 && code < 300) total += lote.length;
        else Logger.log('⚠️ leads batch: ' + resp.getContentText().slice(0, 100));
      } catch(e) {
        Logger.log('⚠️ leads fetch: ' + e.message);
      }
    }
  }

  Logger.log('✅ Leads sincronizados: ' + total);
  return total;
}
// ===== CTRL+F: SS_LEADS_END =====


// ══════════════════════════════════════════════════════════════
// MOD-05 · FUNCIONES PRINCIPALES
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SS_MAIN =====

/**
 * syncHoy — sincroniza hoy + ayer
 * Ejecutar manualmente cuando se necesite
 */
function debugHojas() {
  var ss = SpreadsheetApp.openById(SS_SHEET_ID);
  var hojas = ss.getSheets();
  Logger.log('Hojas disponibles:');
  hojas.forEach(function(h) { Logger.log('  "' + h.getName() + '"'); });

  // Verificar primeras filas de llamadas
  var sh = ss.getSheetByName('CONSOLIDADO DE LLAMADAS');
  if (sh) {
    var lr = sh.getLastRow();
    Logger.log('LLAMADAS: ' + lr + ' filas');
    if (lr >= 2) {
      var sample = sh.getRange(lr, 1, 1, 5).getValues()[0];
      Logger.log('Ultima fila: ' + JSON.stringify(sample));
      Logger.log('Tipo col 0: ' + typeof sample[0] + ' valor: ' + sample[0]);
    }
  }
}

function syncHoy() {
  var key = _ssKey();
  if (!key) {
    Logger.log('❌ SUPABASE_KEY no configurada en Script Properties');
    return;
  }

  var now  = new Date();
  var hoy  = Utilities.formatDate(now, 'America/Lima', 'yyyy-MM-dd');
  var ayer = Utilities.formatDate(new Date(now.getTime() - 86400000), 'America/Lima', 'yyyy-MM-dd');

  Logger.log('🔄 Sync Seguro — desde: ' + ayer + ' hasta: ' + hoy);
  Logger.log('');

  var tLlam  = _syncLlamadas(ayer, hoy);
  var tVent  = _syncVentas(ayer, hoy);
  var tCitas = _syncAgenda(ayer, hoy);
  var tLeads = _syncLeads(ayer, hoy);

  // Refrescar vista materializada de llamadas
  try {
    var url = SS_SUPABASE_URL + '/rest/v1/rpc/aos_refresh_llammap';
    UrlFetchApp.fetch(url, {
      method: 'POST',
      headers: _ssHeaders(),
      payload: '{}',
      muteHttpExceptions: true
    });
    Logger.log('✅ Vista aos_llamadas_ultimo refrescada');
  } catch(e) {
    Logger.log('⚠️ refresh llammap: ' + e.message);
  }

  Logger.log('');
  Logger.log('══════════════════════════════');
  Logger.log('RESUMEN SYNC HOY + AYER:');
  Logger.log('  Llamadas:  ' + tLlam);
  Logger.log('  Ventas:    ' + tVent);
  Logger.log('  Citas:     ' + tCitas);
  Logger.log('  Leads:     ' + tLeads);
  Logger.log('══════════════════════════════');

  // Guardar timestamp del último sync
  PropertiesService.getScriptProperties().setProperty('LAST_SYNC', new Date().toISOString());
}

/**
 * syncCada10Min — ejecutado por el trigger automático
 * Sincroniza solo las últimas 2 horas para ser eficiente
 */
function syncCada10Min() {
  var key = _ssKey();
  if (!key) return;

  var now  = new Date();
  var hoy  = Utilities.formatDate(now, 'America/Lima', 'yyyy-MM-dd');
  var ayer = Utilities.formatDate(new Date(now.getTime() - 86400000), 'America/Lima', 'yyyy-MM-dd');

  // Solo sincronizar hoy y ayer — eficiente y seguro
  _syncLlamadas(ayer, hoy);
  _syncVentas(ayer, hoy);
  _syncAgenda(ayer, hoy);
  _syncLeads(hoy, hoy); // Leads solo hoy

  PropertiesService.getScriptProperties().setProperty('LAST_SYNC', now.toISOString());
}

/**
 * syncRangoFecha — para recuperar datos de fechas específicas
 * @param {string} desde  'yyyy-MM-dd'
 * @param {string} hasta  'yyyy-MM-dd'
 */
function syncRangoFecha(desde, hasta) {
  var key = _ssKey();
  if (!key) {
    Logger.log('❌ SUPABASE_KEY no configurada');
    return;
  }

  Logger.log('🔄 Sync rango: ' + desde + ' → ' + hasta);

  var tLlam  = _syncLlamadas(desde, hasta);
  var tVent  = _syncVentas(desde, hasta);
  var tCitas = _syncAgenda(desde, hasta);
  var tLeads = _syncLeads(desde, hasta);

  try {
    var url = SS_SUPABASE_URL + '/rest/v1/rpc/aos_refresh_llammap';
    UrlFetchApp.fetch(url, {
      method: 'POST', headers: _ssHeaders(), payload: '{}', muteHttpExceptions: true
    });
  } catch(e) {}

  Logger.log('RESUMEN: Llamadas=' + tLlam + ' Ventas=' + tVent + ' Citas=' + tCitas + ' Leads=' + tLeads);
}
// ===== CTRL+F: SS_MAIN_END =====


// ══════════════════════════════════════════════════════════════
// MOD-06 · GESTIÓN DE TRIGGERS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SS_TRIGGERS =====

/**
 * instalarTriggerSyncSeguro
 * Ejecutar UNA SOLA VEZ desde el editor de Apps Script.
 * Instala trigger que corre syncCada10Min cada 10 minutos.
 */
function instalarTriggerSyncSeguro() {
  // Verificar si ya existe
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === 'syncCada10Min') {
      Logger.log('⚠️ Trigger syncCada10Min ya existe — no se duplica');
      return;
    }
  }

  // Crear trigger cada 10 minutos
  ScriptApp.newTrigger('syncCada10Min')
    .timeBased()
    .everyMinutes(10)
    .create();

  Logger.log('✅ Trigger instalado: syncCada10Min cada 10 minutos');
  Logger.log('   Verificar en: Apps Script → Triggers (reloj izquierdo)');

  // Ejecutar sync inicial
  Logger.log('🔄 Ejecutando sync inicial...');
  syncHoy();
}

/**
 * desinstalarTrigger — remover trigger si es necesario
 */
function desinstalarTrigger() {
  var triggers = ScriptApp.getProjectTriggers();
  var removidos = 0;
  triggers.forEach(function(t) {
    if (t.getHandlerFunction() === 'syncCada10Min') {
      ScriptApp.deleteTrigger(t);
      removidos++;
    }
  });
  Logger.log(removidos > 0 ? '✅ Trigger removido' : '⚠️ No se encontró trigger para remover');
}

/**
 * verEstadoSync — muestra estado actual del sync
 */
function verEstadoSync() {
  var props = PropertiesService.getScriptProperties();
  var lastSync = props.getProperty('LAST_SYNC');
  var key = _ssKey();

  Logger.log('══════════════════════════════');
  Logger.log('ESTADO SYNC SEGURO:');
  Logger.log('  SUPABASE_KEY: ' + (key ? '✅ configurada (' + key.slice(0,20) + '...)' : '❌ no configurada'));
  Logger.log('  Último sync: ' + (lastSync || 'nunca'));

  var triggers = ScriptApp.getProjectTriggers();
  var triggerActivo = triggers.some(function(t) {
    return t.getHandlerFunction() === 'syncCada10Min';
  });
  Logger.log('  Trigger activo: ' + (triggerActivo ? '✅ sí' : '❌ no — ejecutar instalarTriggerSyncSeguro()'));
  Logger.log('══════════════════════════════');
}
// ===== CTRL+F: SS_TRIGGERS_END =====


// ══════════════════════════════════════════════════════════════
// CHECKLIST DE INSTALACIÓN
// ══════════════════════════════════════════════════════════════
/*
  PASOS:
  1. ✅ Crear GS_27_SyncSeguro.gs con este código
  2. ✅ Verificar SUPABASE_KEY en Script Properties = service_role key
  3. ▶️ Ejecutar: instalarTriggerSyncSeguro()
     → Instala el trigger + hace sync inicial de hoy y ayer
  4. Verificar en Supabase que llegaron los datos:
     SELECT COUNT(*) FROM aos_llamadas WHERE fecha >= CURRENT_DATE - 1
  5. Listo — de aquí en adelante sincroniza automático cada 10 min

  PARA RECUPERAR DATOS HISTÓRICOS (opcional):
  → syncRangoFecha('2026-04-01', '2026-04-10')
  → Cambiar las fechas según lo que necesites recuperar
*/