// ═══════════════════════════════════════════════════════════════════
// SYNC_LLAMADAS_HOY.gs — v2 — Solo campos que existen en aos_llamadas
// Ejecutar UNA VEZ desde el editor de Apps Script
// ═══════════════════════════════════════════════════════════════════

function syncLlamadasFaltantesHoy() {
  var ss      = SpreadsheetApp.openById('1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM');
  var sh      = ss.getSheetByName('CONSOLIDADO DE LLAMADAS');
  var supaUrl = 'https://ituyqwstonmhnfshnaqz.supabase.co';
  var supaKey = PropertiesService.getScriptProperties().getProperty('SUPABASE_KEY');
  var hoy     = Utilities.formatDate(new Date(), 'America/Lima', 'yyyy-MM-dd');

  if (!supaKey) { Logger.log('❌ SUPABASE_KEY no encontrada'); return; }

  var lr   = sh.getLastRow();
  var data = sh.getRange(2, 1, lr - 1, 20).getValues();

  // Columnas del sheet (0-indexed):
  // 0=FECHA, 1=NUMERO, 2=TRATAMIENTO, 3=ESTADO, 4=OBSERVACION,
  // 5=HORA_LLAMADA, 6=ASESOR, 7=RESERV_ADD_H, 8=NUMERO_LIMPIO,
  // 9=ID_ASESOR, 10=ANUNCIO, 11=ORIGEN, 12=INTENTO, 13=ULT_TS,
  // 14=PROX_REIN, 15=RESULTADO, 16=SESSION_ID, 17=DEVICE, 18=WHATSAPP, 19=TS_LOG

  var filasHoy = data.filter(function(r) {
    if (!r[0]) return false;
    var f = r[0] instanceof Date
      ? Utilities.formatDate(r[0], 'America/Lima', 'yyyy-MM-dd')
      : String(r[0]).slice(0, 10);
    return f === hoy;
  });

  Logger.log('Filas de hoy en Sheets: ' + filasHoy.length);

  var registros = filasHoy.map(function(r) {
    var fechaStr = r[0] instanceof Date
      ? Utilities.formatDate(r[0], 'America/Lima', 'yyyy-MM-dd')
      : String(r[0]).slice(0, 10);

    var ultTs = null;
    if (r[13] instanceof Date) ultTs = r[13].toISOString();
    else if (r[19] instanceof Date) ultTs = r[19].toISOString();

    var horaStr = '';
    if (r[5] instanceof Date) horaStr = Utilities.formatDate(r[5], 'America/Lima', 'HH:mm:ss');
    else if (r[5]) horaStr = String(r[5]).trim();

    // Solo los campos que existen en aos_llamadas
    return {
      fecha:         fechaStr,
      numero:        String(r[1]  || '').trim(),
      tratamiento:   String(r[2]  || '').trim().toUpperCase(),
      estado:        String(r[3]  || '').trim().toUpperCase(),
      observacion:   String(r[4]  || '').trim(),
      hora_llamada:  horaStr,
      asesor:        String(r[6]  || '').trim().toUpperCase(),
      numero_limpio: String(r[8]  || r[1] || '').replace(/\D/g, ''),
      id_asesor:     String(r[9]  || '').trim(),
      anuncio:       String(r[10] || '').trim(),
      origen:        String(r[11] || '').trim(),
      intento:       parseInt(r[12]) || 1,
      ult_ts:        ultTs,
      session_id:    String(r[16] || '').trim(),
      device:        String(r[17] || '').trim()
    };
  }).filter(function(r) {
    return r.numero_limpio && r.asesor;
  });

  Logger.log('Registros a sincronizar: ' + registros.length);

  // Insertar en lotes de 50, ignorando duplicados
  var loteSize = 50, insertados = 0, errores = 0;
  for (var i = 0; i < registros.length; i += loteSize) {
    var lote = registros.slice(i, i + loteSize);
    var resp = UrlFetchApp.fetch(supaUrl + '/rest/v1/aos_llamadas', {
      method: 'POST',
      headers: {
        'apikey':        supaKey,
        'Authorization': 'Bearer ' + supaKey,
        'Content-Type':  'application/json',
        'Prefer':        'resolution=ignore-duplicates,return=minimal'
      },
      payload: JSON.stringify(lote),
      muteHttpExceptions: true
    });
    var code = resp.getResponseCode();
    if (code === 201 || code === 200) {
      insertados += lote.length;
      Logger.log('Lote ' + (Math.floor(i/loteSize)+1) + ': ✅ ' + lote.length + ' insertados');
    } else {
      errores += lote.length;
      Logger.log('Lote ' + (Math.floor(i/loteSize)+1) + ': ❌ ' + code + ' — ' + resp.getContentText().slice(0,200));
    }
    Utilities.sleep(300);
  }

  Logger.log('══════════════════');
  Logger.log('COMPLETADO: ' + insertados + ' insertados, ' + errores + ' errores');
}