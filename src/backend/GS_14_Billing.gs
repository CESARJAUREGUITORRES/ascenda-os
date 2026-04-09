/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_14_Billing.gs                           ║
 * ║  Módulo: Facturación — Comprobantes y Emisores              ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config, GS_03_CoreHelpers,            ║
 * ║                GS_04_DataAccess, GS_05_Auth                ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · KPIs de facturación del período
 *   MOD-02 · Listado de comprobantes con filtros
 *   MOD-03 · Asignación de comprobante a una venta
 *   MOD-04 · Gestión de emisores (series y contadores)
 *   MOD-05 · Registro y consulta de comprobantes individuales
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · KPIs DE FACTURACIÓN
// ══════════════════════════════════════════════════════════════
// B01_START

/**
 * api_getBillingKpis — Resumen de facturación para el panel admin
 * @param {number} mes
 * @param {number} anio
 */
function api_getBillingKpis(mes, anio) {
  cc_requireAdmin();
  var now  = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);
  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes,     0, 23, 59, 59);

  // Ventas del período
  var ventas  = da_ventasData(desde, hasta);
  var factBruta = ventas.reduce(function(s, v) { return s + v.monto; }, 0);
  var nVentas   = ventas.length;
  var nServ     = ventas.filter(function(v) { return v.tipo === 'SERVICIO'; }).length;
  var nProd     = ventas.filter(function(v) { return v.tipo === 'PRODUCTO'; }).length;

  // Comprobantes del período
  var comp = _getComprobantesRango(desde, hasta);
  var nEmitidos  = comp.filter(function(c) { return c.estado !== 'PENDIENTE' && c.estado !== ''; }).length;
  var nPendientes= comp.filter(function(c) { return c.estado === 'PENDIENTE' || c.estado === ''; }).length;
  var factDocumentada = comp
    .filter(function(c) { return c.estado !== 'PENDIENTE' && c.estado !== ''; })
    .reduce(function(s, c) { return s + c.monto; }, 0);

  // Por tipo de comprobante
  var tipoCount = {};
  comp.forEach(function(c) {
    var t = c.tipo || 'PENDIENTE';
    tipoCount[t] = (tipoCount[t] || 0) + 1;
  });

  // Por sede
  var porSede = {};
  ventas.forEach(function(v) {
    var sd = v.sede || 'SIN SEDE';
    if (!porSede[sd]) porSede[sd] = { fact: 0, ventas: 0 };
    porSede[sd].fact   += v.monto;
    porSede[sd].ventas += 1;
  });

  // Mes anterior para delta
  var desdeAnt = new Date(anio, mes - 2, 1, 0, 0, 0);
  var hastaAnt = new Date(anio, mes - 1, 0, 23, 59, 59);
  if (mes === 1) { desdeAnt = new Date(anio - 1, 11, 1, 0, 0, 0); hastaAnt = new Date(anio - 1, 11, 31, 23, 59, 59); }
  var ventAnt = da_ventasData(desdeAnt, hastaAnt);
  var factAnt = ventAnt.reduce(function(s, v) { return s + v.monto; }, 0);

  return {
    ok: true, mes: mes, anio: anio,
    kpis: {
      factBruta:       factBruta,
      factDocumentada: factDocumentada,
      nVentas:         nVentas,
      nServ:           nServ,
      nProd:           nProd,
      nEmitidos:       nEmitidos,
      nPendientes:     nPendientes,
      ticketProm:      nVentas > 0 ? +(factBruta / nVentas).toFixed(2) : 0,
      pctDocumentado:  factBruta > 0 ? Math.round(factDocumentada / factBruta * 100) : 0,
      deltaFact:       factAnt > 0 ? +((factBruta - factAnt) / factAnt).toFixed(4) : null
    },
    porTipo: tipoCount,
    porSede: porSede
  };
}

/** Wrapper token */
function api_getBillingKpisT(token, mes, anio) {
  _setToken(token); return api_getBillingKpis(mes, anio);
}
// B01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · LISTADO DE COMPROBANTES
// ══════════════════════════════════════════════════════════════
// B02_START

/**
 * api_listComprobantes — Lista comprobantes con filtros
 * @param {number} mes
 * @param {number} anio
 * @param {string} estado  "" | "PENDIENTE" | "BOLETA_E" | etc.
 * @param {string} sede    "" | "SAN ISIDRO" | "PUEBLO LIBRE"
 */
function api_listComprobantes(mes, anio, estado, sede) {
  cc_requireAdmin();
  var now  = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);
  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes,     0, 23, 59, 59);

  estado = _up(estado || '');
  sede   = _up(sede   || '');

  var ventas = da_ventasData(desde, hasta)
    .filter(function(v) {
      if (sede && _up(v.sede) !== sede) return false;
      if (estado) {
        var edoDoc = _up(v.estadoDoc);
        if (estado === 'PENDIENTE' && edoDoc && edoDoc !== 'PENDIENTE') return false;
        if (estado !== 'PENDIENTE' && edoDoc !== estado) return false;
      }
      return true;
    })
    .map(function(v) {
      return {
        fecha:     _date(v.fecha),
        ventaId:   v.ventaId,
        paciente:  (v.nombres + ' ' + v.apellidos).trim() || '—',
        celular:   v.celular,
        trat:      v.trat,
        monto:     v.monto,
        tipo:      v.tipo,
        pago:      v.pago,
        estadoPago:v.estadoPago,
        asesor:    v.asesor,
        sede:      v.sede,
        nroDoc:    v.nroDoc  || '',
        estadoDoc: v.estadoDoc || 'PENDIENTE',
        num:       v.num
      };
    })
    .sort(function(a, b) { return a.fecha < b.fecha ? 1 : -1; });

  return { ok: true, items: ventas, total: ventas.length };
}

/** Wrapper token */
function api_listComprobantesT(token, mes, anio, estado, sede) {
  _setToken(token); return api_listComprobantes(mes, anio, estado, sede);
}

/**
 * Helper interno — lee comprobantes del Sheet de comprobantes en rango
 */
function _getComprobantesRango(desde, hasta) {
  try {
    var sh = _sh(CFG.SHEET_COMPROBANTES);
    var lr = sh.getLastRow();
    if (lr < 2) return [];
    // Columnas del Sheet CONSOLIDADO DE COMPROBANTES:
    // A=FECHA B=VENTA_ID C=NRO_DOC D=TIPO E=MONTO F=ESTADO G=EMISOR H=SEDE I=TS
    return sh.getRange(2, 1, lr - 1, 9).getValues()
      .filter(function(r) { return _inRango(r[0], desde, hasta); })
      .map(function(r) {
        return {
          fecha:   _date(r[0]),
          ventaId: _norm(r[1]),
          nroDoc:  _norm(r[2]),
          tipo:    _up(_norm(r[3])),
          monto:   Number(r[4]) || 0,
          estado:  _up(_norm(r[5])),
          emisor:  _norm(r[6]),
          sede:    _up(_norm(r[7]))
        };
      });
  } catch(e) {
    // Si no existe la hoja, usar los datos de VENTAS directamente
    var ventas = da_ventasData(desde, hasta);
    return ventas.map(function(v) {
      return {
        fecha:   _date(v.fecha),
        ventaId: v.ventaId,
        nroDoc:  v.nroDoc  || '',
        tipo:    v.estadoDoc || 'PENDIENTE',
        monto:   v.monto,
        estado:  v.estadoDoc || 'PENDIENTE',
        emisor:  '',
        sede:    v.sede
      };
    });
  }
}
// B02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · ASIGNACIÓN DE COMPROBANTE A VENTA
// ══════════════════════════════════════════════════════════════
// B03_START

/**
 * api_asignarComprobante — Asigna número de comprobante a una venta
 * Actualiza CONSOLIDADO DE VENTAS cols R (NRO_DOC) y S (ESTADO_DOC)
 * @param {string} ventaId   — ID de la venta (col Q)
 * @param {string} nroDoc    — Número del comprobante (ej: "B001-00001234")
 * @param {string} tipoDoc   — Tipo: BOLETA_E | FACTURA_E | RH | BOLETA_FISICA | etc.
 * @param {string} emisor    — ID o nombre del emisor
 */
function api_asignarComprobante(ventaId, nroDoc, tipoDoc, emisor) {
  cc_requireAdmin();
  ventaId = _norm(ventaId);
  nroDoc  = _norm(nroDoc);
  tipoDoc = _up(tipoDoc || '');
  emisor  = _norm(emisor || '');

  if (!ventaId) throw new Error('Falta ventaId.');
  if (!nroDoc)  throw new Error('Falta número de comprobante.');

  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) throw new Error('Sin ventas registradas.');

  // Buscar la venta por VENTA_ID (col Q = índice 16)
  var ids   = sh.getRange(2, VENT_COL.VENTA_ID + 1, lr - 1, 1).getValues();
  var rowIdx = -1;
  for (var i = 0; i < ids.length; i++) {
    if (_norm(ids[i][0]) === ventaId) { rowIdx = i + 2; break; }
  }
  if (rowIdx === -1) throw new Error('Venta no encontrada: ' + ventaId);

  // Actualizar cols R y S (base 1: col 18 y 19)
  sh.getRange(rowIdx, VENT_COL.NRO_DOC    + 1).setValue(nroDoc);
  sh.getRange(rowIdx, VENT_COL.ESTADO_DOC + 1).setValue(tipoDoc || 'EMITIDO');

  // Registrar también en el Sheet de comprobantes si existe
  try {
    var shComp = _sh(CFG.SHEET_COMPROBANTES);
    var rowVenta = sh.getRange(rowIdx, 1, 1, 19).getValues()[0];
    shComp.appendRow([
      rowVenta[VENT_COL.FECHA],
      ventaId,
      nroDoc,
      tipoDoc,
      rowVenta[VENT_COL.MONTO],
      tipoDoc || 'EMITIDO',
      emisor,
      rowVenta[VENT_COL.SEDE],
      new Date()
    ]);
  } catch(e) { /* Sheet de comprobantes opcional */ }

  // Incrementar contador del emisor si corresponde
  if (emisor) _incrementarContador(emisor);

  return { ok: true, ventaId: ventaId, nroDoc: nroDoc };
}

/** Wrapper token */
function api_asignarComprobanteT(token, ventaId, nroDoc, tipoDoc, emisor) {
  _setToken(token); return api_asignarComprobante(ventaId, nroDoc, tipoDoc, emisor);
}

/**
 * api_limpiarComprobante — Quita el comprobante asignado a una venta
 */
function api_limpiarComprobante(ventaId) {
  cc_requireAdmin();
  ventaId = _norm(ventaId);
  if (!ventaId) throw new Error('Falta ventaId.');

  var sh  = _sh(CFG.SHEET_VENTAS);
  var lr  = sh.getLastRow();
  if (lr < 2) return { ok: true };

  var ids = sh.getRange(2, VENT_COL.VENTA_ID + 1, lr - 1, 1).getValues();
  for (var i = 0; i < ids.length; i++) {
    if (_norm(ids[i][0]) === ventaId) {
      var row = i + 2;
      sh.getRange(row, VENT_COL.NRO_DOC    + 1).setValue('');
      sh.getRange(row, VENT_COL.ESTADO_DOC + 1).setValue('PENDIENTE');
      return { ok: true };
    }
  }
  throw new Error('Venta no encontrada: ' + ventaId);
}

/** Wrapper token */
function api_limpiarComprobanteT(token, ventaId) {
  _setToken(token); return api_limpiarComprobante(ventaId);
}
// B03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · GESTIÓN DE EMISORES Y CONTADORES
// ══════════════════════════════════════════════════════════════
// B04_START

/**
 * api_listEmisores — Lista emisores activos con su serie y contador
 */
function api_listEmisores() {
  cc_requireAdmin();
  try {
    var sh = _sh(CFG.SHEET_EMISORES);
    var lr = sh.getLastRow();
    if (lr < 2) return { ok: true, items: [] };

    // Columnas EMISORES: A=ID B=NOMBRE C=RUC D=TIPO_DOC E=SERIE F=CORRELATIVO
    //                    G=SEDE H=ESTADO I=REGIMEN J=DIRECCION K=EMAIL L=TS
    var items = sh.getRange(2, 1, lr - 1, 12).getValues()
      .filter(function(r) { return _up(r[7]) !== 'INACTIVO' && _norm(r[0]); })
      .map(function(r) {
        return {
          id:          _norm(r[0]),
          nombre:      _norm(r[1]),
          ruc:         _norm(r[2]),
          tipoDoc:     _up(_norm(r[3])),
          serie:       _norm(r[4]),
          correlativo: Number(r[5]) || 0,
          sede:        _up(_norm(r[6])),
          estado:      _up(_norm(r[7])),
          regimen:     _norm(r[8])
        };
      });
    return { ok: true, items: items };
  } catch(e) {
    return { ok: true, items: [] };
  }
}

/** Wrapper token */
function api_listEmisoresT(token) {
  _setToken(token); return api_listEmisores();
}

/**
 * api_getNextNroDoc — Genera el siguiente número de comprobante
 * @param {string} emisorId
 * @returns {Object} {ok, nroDoc, serie, correlativo}
 */
function api_getNextNroDoc(emisorId) {
  cc_requireAdmin();
  emisorId = _norm(emisorId);
  if (!emisorId) throw new Error('Falta emisorId.');

  try {
    var sh = _sh(CFG.SHEET_EMISORES);
    var lr = sh.getLastRow();
    if (lr < 2) throw new Error('Sin emisores configurados.');

    var ids = sh.getRange(2, 1, lr - 1, 1).getValues();
    for (var i = 0; i < ids.length; i++) {
      if (_norm(ids[i][0]) === emisorId) {
        var row    = i + 2;
        var data   = sh.getRange(row, 1, 1, 6).getValues()[0];
        var serie  = _norm(data[4]);
        var corr   = Number(data[5]) || 0;
        var nroDoc = serie + '-' + String(corr + 1).padStart(8, '0');
        return { ok: true, nroDoc: nroDoc, serie: serie, correlativo: corr + 1 };
      }
    }
    throw new Error('Emisor no encontrado: ' + emisorId);
  } catch(e) {
    return { ok: false, error: e.message };
  }
}

/** Wrapper token */
function api_getNextNroDocT(token, emisorId) {
  _setToken(token); return api_getNextNroDoc(emisorId);
}

/**
 * Incrementa el correlativo del emisor (llamado internamente al asignar)
 */
function _incrementarContador(emisorId) {
  try {
    var sh = _sh(CFG.SHEET_EMISORES);
    var lr = sh.getLastRow();
    if (lr < 2) return;
    var ids = sh.getRange(2, 1, lr - 1, 1).getValues();
    for (var i = 0; i < ids.length; i++) {
      if (_norm(ids[i][0]) === emisorId) {
        var row  = i + 2;
        var corr = Number(sh.getRange(row, 6).getValue()) || 0;
        sh.getRange(row, 6).setValue(corr + 1);
        sh.getRange(row, 12).setValue(new Date()); // TS actualizado
        return;
      }
    }
  } catch(e) {}
}
// B04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · RESUMEN DIARIO DE FACTURACIÓN
// ══════════════════════════════════════════════════════════════
// B05_START

/**
 * api_getBillingToday — Resumen de ventas del día para el admin
 */
function api_getBillingToday() {
  cc_requireAdmin();
  var now   = new Date();
  var hoy   = _date(now);
  var desde = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  var hasta = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

  var ventas = da_ventasData(desde, hasta);

  var factHoy    = ventas.reduce(function(s, v) { return s + v.monto; }, 0);
  var nVentas    = ventas.length;
  var nPendDoc   = ventas.filter(function(v) { return !v.nroDoc || v.estadoDoc === 'PENDIENTE'; }).length;
  var nEmitidos  = nVentas - nPendDoc;

  // Agrupado por asesor
  var porAsesor  = {};
  ventas.forEach(function(v) {
    var a = v.asesor || 'SIN ASESOR';
    if (!porAsesor[a]) porAsesor[a] = { fact: 0, ventas: 0, pendientes: 0 };
    porAsesor[a].fact    += v.monto;
    porAsesor[a].ventas  += 1;
    if (!v.nroDoc || v.estadoDoc === 'PENDIENTE') porAsesor[a].pendientes++;
  });

  // Agrupado por sede
  var porSede = {};
  ventas.forEach(function(v) {
    var sd = v.sede || 'SIN SEDE';
    if (!porSede[sd]) porSede[sd] = { fact: 0, ventas: 0 };
    porSede[sd].fact   += v.monto;
    porSede[sd].ventas += 1;
  });

  return {
    ok: true, fecha: hoy,
    kpis: { factHoy: factHoy, nVentas: nVentas, nEmitidos: nEmitidos, nPendDoc: nPendDoc },
    porAsesor: porAsesor,
    porSede:   porSede,
    detalle:   ventas.map(function(v) {
      return {
        fecha:     _date(v.fecha),
        ventaId:   v.ventaId,
        paciente:  (v.nombres + ' ' + v.apellidos).trim(),
        trat:      v.trat,
        monto:     v.monto,
        tipo:      v.tipo,
        estadoPago:v.estadoPago,
        asesor:    v.asesor,
        sede:      v.sede,
        nroDoc:    v.nroDoc    || '',
        estadoDoc: v.estadoDoc || 'PENDIENTE',
        num:       v.num
      };
    })
  };
}

/** Wrapper token */
function api_getBillingTodayT(token) {
  _setToken(token); return api_getBillingToday();
}
// B05_END

/**
 * TEST
 */
function test_Billing() {
  Logger.log('=== GS_14_Billing TEST ===');
  Logger.log('Funciones disponibles:');
  Logger.log('  api_getBillingKpisT(token, mes, anio)');
  Logger.log('  api_listComprobantesT(token, mes, anio, estado, sede)');
  Logger.log('  api_asignarComprobanteT(token, ventaId, nroDoc, tipoDoc, emisor)');
  Logger.log('  api_limpiarComprobanteT(token, ventaId)');
  Logger.log('  api_listEmisoresT(token)');
  Logger.log('  api_getNextNroDocT(token, emisorId)');
  Logger.log('  api_getBillingTodayT(token)');
  Logger.log('=== OK ===');
}