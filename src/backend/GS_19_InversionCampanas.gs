/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_14_InversionCampanas.gs                 ║
 * ║  Módulo: CRUD de Inversión de Campañas                      ║
 * ║  Archivo NUEVO — no reemplaza ninguno existente             ║
 * ║                                                             ║
 * ║  Sheet: CONSOLIDADO DE INVERSION DE CAM                     ║
 * ║  Estructura:                                                ║
 * ║    Col A: TRATAMIENTO                                       ║
 * ║    Col B: MES (ENERO..DICIEMBRE)                            ║
 * ║    Col C: INVERSION (número)                                ║
 * ║    Col D: RED_SOCIAL (META ADS / TIKTOK ADS /               ║
 * ║                       GOOGLE ADS / ORGÁNICO)               ║
 * ║    Col E: ANIO (número)                                     ║
 * ╚══════════════════════════════════════════════════════════════╝
 */

// ══════════════════════════════════════════════════════════════
// SETUP — asegura que el sheet tenga las columnas correctas
// Ejecutar una sola vez con: setupInversionSheet()
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: setupInversionSheet =====
function setupInversionSheet() {
  var sh = _sh(CFG.SHEET_INVERSION);
  var lr = sh.getLastRow();

  // Verificar/agregar headers
  var headers = sh.getRange(1, 1, 1, 5).getValues()[0];
  if (!headers[3] || _norm(headers[3]) === '') {
    sh.getRange(1, 4).setValue('RED_SOCIAL');
    Logger.log('Col D RED_SOCIAL agregada');
  }
  if (!headers[4] || _norm(headers[4]) === '') {
    sh.getRange(1, 5).setValue('ANIO');
    Logger.log('Col E ANIO agregada');
  }

  // Rellenar ANIO en filas existentes que no lo tengan
  if (lr >= 2) {
    var datos = sh.getRange(2, 1, lr - 1, 5).getValues();
    var updates = [];
    datos.forEach(function(r, i) {
      var anio = Number(r[4]) || 0;
      if (!anio) {
        updates.push({ row: i + 2, anio: 2026 });
      }
    });
    updates.forEach(function(u) {
      sh.getRange(u.row, 5).setValue(u.anio);
    });
    Logger.log('Filas actualizadas con ANIO: ' + updates.length);
  }

  Logger.log('setupInversionSheet OK');
}

// ══════════════════════════════════════════════════════════════
// LEER — obtener inversiones de un mes/año con su fila
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_getInversionPanelT =====
/**
 * Retorna todas las inversiones de un mes/año con rowNum para edición
 * @param {string} token
 * @param {number} mes  1-12
 * @param {number} anio
 */
function api_getInversionPanelT(token, mes, anio) {
  _setToken(token);
  cc_requireAdmin();

  var now  = new Date();
  mes  = Number(mes)  || (now.getMonth() + 1);
  anio = Number(anio) || now.getFullYear();

  var mesTexto = MESES_ES[mes] || '';
  var sh = _sh(CFG.SHEET_INVERSION);
  var lr = sh.getLastRow();

  var items = [];
  var totalInv = 0;

  if (lr >= 2) {
    sh.getRange(2, 1, lr - 1, 5).getValues().forEach(function(r, i) {
      var trat    = _up(_norm(r[0] || ''));
      var mesR    = _up(_norm(r[1] || ''));
      var monto   = Number(r[2]) || 0;
      var red     = _norm(r[3] || '');
      var anioR   = Number(r[4]) || 2026; // compatibilidad: si no tiene año, asumir 2026

      if (!trat) return;
      if (mesR !== mesTexto) return;
      if (anioR !== anio) return;

      items.push({
        rowNum:     i + 2,
        tratamiento: trat,
        mes:         mesR,
        anio:        anioR,
        monto:       monto,
        redSocial:   red || 'META ADS'
      });
      totalInv += monto;
    });
  }

  // Calcular totales por red social
  var porRed = {};
  items.forEach(function(it) {
    porRed[it.redSocial] = (porRed[it.redSocial] || 0) + it.monto;
  });

  return {
    ok:       true,
    mes:      mes,
    anio:     anio,
    mesNom:   MESES_ES[mes] || '',
    items:    items,
    total:    totalInv,
    porRed:   porRed
  };
}

// ══════════════════════════════════════════════════════════════
// GUARDAR FILA (nueva o actualizar existente)
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_saveInversionRowT =====
/**
 * Guarda una fila de inversión (crea nueva o actualiza por rowNum)
 * @param {string} token
 * @param {Object} payload
 *   { rowNum, tratamiento, mes, anio, monto, redSocial }
 *   rowNum = 0 → crear nueva fila
 *   rowNum > 0 → actualizar fila existente
 */
function api_saveInversionRowT(token, payload) {
  _setToken(token);
  cc_requireAdmin();

  payload = payload || {};
  var trat  = _up(_norm(payload.tratamiento || ''));
  var mes   = _up(_norm(payload.mes || ''));
  var anio  = Number(payload.anio) || new Date().getFullYear();
  var monto = Number(payload.monto) || 0;
  var red   = _norm(payload.redSocial || 'META ADS');
  var rowNum = Number(payload.rowNum) || 0;

  if (!trat)  return { ok: false, error: 'Falta tratamiento' };
  if (!mes)   return { ok: false, error: 'Falta mes' };
  if (monto <= 0) return { ok: false, error: 'Monto debe ser mayor a 0' };

  // Validar mes
  var mesIdx = MESES_ES.indexOf(mes);
  if (mesIdx < 1) return { ok: false, error: 'Mes inválido: ' + mes };

  // Validar red social
  var redesValidas = ['META ADS', 'TIKTOK ADS', 'GOOGLE ADS', 'ORGANICO'];
  var redNorm = red.toUpperCase().replace(/[ÁÀÄÂ]/g,'A').replace(/[ÉÈËÊ]/g,'E');
  if (redesValidas.indexOf(redNorm) < 0) redNorm = 'META ADS';

  var sh = _sh(CFG.SHEET_INVERSION);

  if (rowNum >= 2) {
    // Actualizar fila existente
    sh.getRange(rowNum, 1).setValue(trat);
    sh.getRange(rowNum, 2).setValue(mes);
    sh.getRange(rowNum, 3).setValue(monto);
    sh.getRange(rowNum, 4).setValue(redNorm);
    sh.getRange(rowNum, 5).setValue(anio);
    return { ok: true, action: 'updated', rowNum: rowNum };
  } else {
    // Nueva fila
    sh.appendRow([trat, mes, monto, redNorm, anio]);
    var newRow = sh.getLastRow();
    return { ok: true, action: 'created', rowNum: newRow };
  }
}

// ══════════════════════════════════════════════════════════════
// ELIMINAR FILA
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_deleteInversionRowT =====
/**
 * Elimina una fila de inversión por rowNum
 * @param {string} token
 * @param {number} rowNum
 */
function api_deleteInversionRowT(token, rowNum) {
  _setToken(token);
  cc_requireAdmin();

  rowNum = Number(rowNum);
  if (!rowNum || rowNum < 2) return { ok: false, error: 'rowNum inválido' };

  var sh = _sh(CFG.SHEET_INVERSION);
  var lr = sh.getLastRow();
  if (rowNum > lr) return { ok: false, error: 'Fila no existe' };

  sh.deleteRow(rowNum);
  return { ok: true, deleted: rowNum };
}

// ══════════════════════════════════════════════════════════════
// OBTENER CATÁLOGO DE TRATAMIENTOS DISPONIBLES
// Para el select del modal
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_getTratamientosListT =====
function api_getTratamientosListT(token) {
  _setToken(token);
  cc_requireAdmin();

  var tratos = new Set();

  // Leer desde la hoja de inversión (tratamientos usados)
  try {
    var sh = _sh(CFG.SHEET_INVERSION);
    var lr = sh.getLastRow();
    if (lr >= 2) {
      sh.getRange(2, 1, lr - 1, 1).getValues().forEach(function(r) {
        var t = _up(_norm(r[0] || ''));
        if (t) tratos.add(t);
      });
    }
  } catch(e) {}

  // Leer desde catálogo de leads (tratamientos con leads)
  try {
    var shL = _sh(CFG.SHEET_LEADS);
    var lrL = shL.getLastRow();
    if (lrL >= 2) {
      shL.getRange(2, 3, Math.min(lrL - 1, 3000), 1).getValues().forEach(function(r) {
        var t = _up(_norm(r[0] || ''));
        if (t && t.length > 2) tratos.add(t);
      });
    }
  } catch(e) {}

  var lista = Array.from(tratos).sort();
  return { ok: true, items: lista };
}

function test_InversionCampanas() {
  Logger.log('=== GS_14_InversionCampanas TEST ===');
  Logger.log('Funciones: setupInversionSheet, api_getInversionPanelT');
  Logger.log('           api_saveInversionRowT, api_deleteInversionRowT');
  Logger.log('           api_getTratamientosListT');
  Logger.log('Ejecutar setupInversionSheet() una vez para preparar el sheet');
  Logger.log('=== OK ===');
}