/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_20_AdminSales.gs v2.0                   ║
 * ║  Módulo: Panel de Ventas Administrativo                     ║
 * ║  Bloque 5 — Fase 3                                         ║
 * ║                                                             ║
 * ║  FUNCIONES:                                                 ║
 * ║    api_getAdminSalesDashboardT  → dashboard (hoy/mes/rango) ║
 * ║    api_getAdminSalesDetailT     → tabla paginada            ║
 * ║    api_getClienteHistorialT     → historial pagos cliente   ║
 * ║    api_getSalesConfigT          → config: metas + métodos   ║
 * ║    api_saveSalesConfigT         → guardar meta mensual      ║
 * ║    api_saveMetodoPagoT          → CRUD métodos de pago      ║
 * ║    api_deleteMetodoPagoT        → eliminar método de pago   ║
 * ║    setupSalesSheets             → crear hojas nuevas (1vez) ║
 * ╚══════════════════════════════════════════════════════════════╝
 */

// ══════════════════════════════════════════════════════════════
// SETUP — crear hojas nuevas si no existen
// Ejecutar una sola vez: setupSalesSheets()
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: setupSalesSheets =====
function setupSalesSheets() {
  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);

  // Hoja CAT_METODOS_PAGO
  var shMet = ss.getSheetByName('CAT_METODOS_PAGO');
  if (!shMet) {
    shMet = ss.insertSheet('CAT_METODOS_PAGO');
    shMet.getRange(1, 1, 1, 6).setValues([[
      'METODO', 'SEDE', 'ACTIVO', 'ORDEN', 'MONEDA', 'TS_CREADO'
    ]]);
    // Poblar con los métodos detectados del sheet de ventas
    var sh = _sh(CFG.SHEET_VENTAS);
    var lr = sh.getLastRow();
    var metodosSet = {};
    if (lr >= 2) {
      sh.getRange(2, 1, lr - 1, 14).getValues().forEach(function(r) {
  var met  = _norm(r[VENT_COL.PAGO]  || '');
  var sede = _up(_norm(r[VENT_COL.SEDE] || ''));
  if (!met) return;
  var k = met + '|' + sede;
  if (!metodosSet[k]) metodosSet[k] = { met: met, sede: sede };
});
    }
    var filas = Object.values(metodosSet);
    filas.forEach(function(f, i) {
      shMet.appendRow([f.met, f.sede, 'SI', i + 1, 'PEN', new Date()]);
    });
    Logger.log('CAT_METODOS_PAGO creada con ' + filas.length + ' métodos');
  }

  // Hoja METAS_VENTAS
  var shMeta = ss.getSheetByName('METAS_VENTAS');
  if (!shMeta) {
    shMeta = ss.insertSheet('METAS_VENTAS');
    shMeta.getRange(1, 1, 1, 5).setValues([[
      'PERIODO', 'META', 'MONEDA', 'DESCRIPCION', 'TS_ACTUALIZADO'
    ]]);
    // Agregar meta ejemplo
    shMeta.appendRow(['2026-04', 100000, 'PEN', 'Meta abril 2026', new Date()]);
    Logger.log('METAS_VENTAS creada');
  }

  Logger.log('setupSalesSheets OK');
}

// ══════════════════════════════════════════════════════════════
// FUNCIÓN PRINCIPAL — Dashboard con modo hoy/mes/rango
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_getAdminSalesDashboard =====
/**
 * @param {string} modo   - 'hoy' | 'mes' | 'anio' | 'rango'
 * @param {number} mes    - 1-12 (usado en modo mes/anio)
 * @param {number} anio   - año (usado en modo mes/anio/rango)
 * @param {string} desde  - yyyy-MM-dd (modo rango)
 * @param {string} hasta  - yyyy-MM-dd (modo rango)
 */
function api_getAdminSalesDashboard(modo, mes, anio, desde, hasta) {
  cc_requireAdmin();
  var now = new Date();
  modo  = modo  || 'hoy';
  anio  = Number(anio) || now.getFullYear();
  mes   = Number(mes)  || (now.getMonth() + 1);

  var dDesde, dHasta, periodoLabel;

  if (modo === 'hoy') {
    var hoy = _date(now);
    dDesde = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    dHasta = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
    periodoLabel = 'Hoy, ' + hoy;
  } else if (modo === 'mes') {
    dDesde = new Date(anio, mes - 1, 1, 0, 0, 0);
    dHasta = new Date(anio, mes, 0, 23, 59, 59);
    periodoLabel = MESES_ES[mes] + ' ' + anio;
  } else if (modo === 'anio') {
    dDesde = new Date(anio, 0, 1, 0, 0, 0);
    dHasta = new Date(anio, 11, 31, 23, 59, 59);
    periodoLabel = 'Año ' + anio;
    mes = null; // no aplica en modo año
  } else if (modo === 'rango' && desde && hasta) {
    var pd = desde.split('-');
    var ph = hasta.split('-');
    dDesde = new Date(Number(pd[0]), Number(pd[1])-1, Number(pd[2]), 0, 0, 0);
    dHasta = new Date(Number(ph[0]), Number(ph[1])-1, Number(ph[2]), 23, 59, 59);
    periodoLabel = desde + ' → ' + hasta;
  } else {
    // fallback hoy
    dDesde = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    dHasta = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
    periodoLabel = 'Hoy';
    modo = 'hoy';
  }

  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return _emptyResult(modo, mes, anio, periodoLabel);

  var rows = sh.getRange(2, 1, lr - 1, 19).getValues();

  // ── Filtrar ventas del período ─────────────────────────────
  var ventasPer = [];
  rows.forEach(function(r, i) {
    var fd = r[VENT_COL.FECHA];
    if (!fd || !_inRango(fd, dDesde, dHasta)) return;
    var montoRaw = Number(r[VENT_COL.MONTO]) || 0;
    var pagoStr  = _norm(r[VENT_COL.PAGO] || '');
    // Detectar dólares: si el campo DESCRIPCION o PAGO contiene USD/$
    var esUSD = pagoStr.indexOf('$') >= 0 || pagoStr.toUpperCase().indexOf('USD') >= 0 ||
                pagoStr.toUpperCase().indexOf('DOLAR') >= 0;
    ventasPer.push({
      rowNum:     i + 2,
      fecha:      _date(fd),
      nombres:    _norm(r[VENT_COL.NOMBRES]),
      apellidos:  _norm(r[VENT_COL.APELLIDOS]),
      celular:    _norm(r[VENT_COL.CELULAR]),
      trat:       _up(_norm(r[VENT_COL.TRATAMIENTO])),
      desc:       _norm(r[VENT_COL.DESCRIPCION]),
      pago:       pagoStr,
      monto:      montoRaw,
      moneda:     esUSD ? 'USD' : 'PEN',
      estadoPago: _up(_norm(r[VENT_COL.ESTADO_PAGO])),
      asesor:     _up(_norm(r[VENT_COL.ASESOR])),
      sede:       _up(_norm(r[VENT_COL.SEDE])),
      tipo:       _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO',
      num:        _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]),
      ventaId:    _norm(r[VENT_COL.VENTA_ID])
    });
  });

  var totalVentas = ventasPer.length;
  // Separar por moneda para facturación
  var ventasPEN   = ventasPer.filter(function(v){ return v.moneda !== 'USD'; });
  var ventasUSD   = ventasPer.filter(function(v){ return v.moneda === 'USD'; });
  var factPEN     = ventasPEN.reduce(function(s,v){ return s+v.monto; }, 0);
  var factUSD     = ventasUSD.reduce(function(s,v){ return s+v.monto; }, 0);
  var factTotal   = factPEN; // facturación principal en soles

  // ── Por sede ──────────────────────────────────────────────
  var porSede = {};
  ventasPer.forEach(function(v) {
    var s = v.sede || 'SIN SEDE';
    if (!porSede[s]) porSede[s] = {
      sede:s, ventas:0, factPEN:0, factUSD:0,
      nServicios:0, nProductos:0, nPEN:0, nUSD:0
    };
    porSede[s].ventas++;
    if (v.moneda === 'USD') { porSede[s].factUSD += v.monto; porSede[s].nUSD++; }
    else                    { porSede[s].factPEN += v.monto; porSede[s].nPEN++; }
    if (v.tipo === 'PRODUCTO') porSede[s].nProductos++;
    else                       porSede[s].nServicios++;
  });
  var sedesList = Object.values(porSede).sort(function(a,b){ return b.factPEN - a.factPEN; });

  // ── Por método de pago ────────────────────────────────────
  var porPago = {};
  ventasPer.forEach(function(v) {
    var p = v.pago || 'SIN MÉTODO';
    var s = v.sede || 'SIN SEDE';
    var k = p;
    if (!porPago[k]) porPago[k] = { metodo:p, ventas:0, factPEN:0, factUSD:0, porSede:{} };
    porPago[k].ventas++;
    if (v.moneda === 'USD') porPago[k].factUSD += v.monto;
    else                    porPago[k].factPEN += v.monto;
    if (!porPago[k].porSede[s]) porPago[k].porSede[s] = { ventas:0, factPEN:0, factUSD:0 };
    porPago[k].porSede[s].ventas++;
    if (v.moneda === 'USD') porPago[k].porSede[s].factUSD += v.monto;
    else                    porPago[k].porSede[s].factPEN += v.monto;
  });
  var pagosList = Object.values(porPago).sort(function(a,b){ return b.factPEN - a.factPEN; });

  // ── Tipos y estados ───────────────────────────────────────
  var nServicios  = ventasPer.filter(function(v){ return v.tipo !== 'PRODUCTO'; }).length;
  var nProductos  = ventasPer.filter(function(v){ return v.tipo === 'PRODUCTO'; }).length;
  var factServ    = ventasPer.filter(function(v){ return v.tipo !== 'PRODUCTO' && v.moneda !== 'USD'; }).reduce(function(s,v){ return s+v.monto; }, 0);
  var factProd    = ventasPer.filter(function(v){ return v.tipo === 'PRODUCTO' && v.moneda !== 'USD'; }).reduce(function(s,v){ return s+v.monto; }, 0);
  var nCompletos  = ventasPer.filter(function(v){ return v.estadoPago === 'PAGO COMPLETO'; }).length;
  var pendientes  = ventasPer.filter(function(v){ return v.estadoPago === 'ADELANTO'; });
  var sinEstado   = ventasPer.filter(function(v){ return v.estadoPago === 'PENDIENTE' || !v.estadoPago; }).length;
  var ticketProm  = totalVentas > 0 ? factTotal / totalVentas : 0;

  // ── Por asesor ────────────────────────────────────────────
  var porAsesor = {};
  ventasPer.forEach(function(v) {
    var a = v.asesor || 'SIN ASESOR';
    if (!porAsesor[a]) porAsesor[a] = { asesor:a, ventas:0, fact:0 };
    porAsesor[a].ventas++;
    if (v.moneda !== 'USD') porAsesor[a].fact += v.monto;
  });
  var asesorList = Object.values(porAsesor).sort(function(a,b){ return b.fact - a.fact; });

  // ── Por tratamiento ───────────────────────────────────────
  var porTrat = {};
  ventasPer.forEach(function(v) {
    var t = v.trat || 'SIN TRATAMIENTO';
    if (!porTrat[t]) porTrat[t] = { trat:t, ventas:0, fact:0 };
    porTrat[t].ventas++;
    if (v.moneda !== 'USD') porTrat[t].fact += v.monto;
  });
  var tratList = Object.values(porTrat)
    .sort(function(a,b){ return b.fact - a.fact; })
    .slice(0, 12);

  // ── Proyección del mes (solo en modo mes) ─────────────────
  var proyeccion  = null;
  var metaMes     = null;
  var historialMetas = [];

  if (modo === 'mes') {
    var diaActual    = now.getMonth()+1 === mes && now.getFullYear() === anio ? now.getDate() : new Date(anio, mes, 0).getDate();
    var diasMes      = new Date(anio, mes, 0).getDate();
    var ritmoActual  = diaActual > 0 ? factTotal / diaActual : 0;
    var proyMes      = ritmoActual * diasMes;
    var pctAvance    = Math.round(diaActual / diasMes * 100);

    // Leer meta del mes desde METAS_VENTAS
    try {
      var shMeta = SpreadsheetApp.openById(CFG.SHEET_ID).getSheetByName('METAS_VENTAS');
      if (shMeta) {
        var lrM = shMeta.getLastRow();
        var periodo = anio + '-' + String(mes).padStart(2,'0');
        if (lrM >= 2) {
          var metaRows = shMeta.getRange(2, 1, lrM-1, 3).getValues();
          metaRows.forEach(function(r) {
            if (_norm(r[0]) === periodo) metaMes = Number(r[1]) || null;
          });
          // Historial últimos 6 meses
          var mesesHist = [];
          for (var hi = 0; hi < 6; hi++) {
            var hm = mes - hi; var ha = anio;
            if (hm <= 0) { hm += 12; ha--; }
            mesesHist.push(ha + '-' + String(hm).padStart(2,'0'));
          }
          metaRows.forEach(function(r) {
            if (mesesHist.indexOf(_norm(r[0])) >= 0) {
              historialMetas.push({ periodo: _norm(r[0]), meta: Number(r[1])||0, moneda: _norm(r[2])||'PEN' });
            }
          });
        }
      }
    } catch(eM) {}

    var pctMeta = metaMes && metaMes > 0 ? Math.round(factTotal / metaMes * 100) : null;

    proyeccion = {
      diasTranscurridos: diaActual,
      diasMes:           diasMes,
      pctAvance:         pctAvance,
      ritmoActual:       +ritmoActual.toFixed(2),
      proyeccionMes:     +proyMes.toFixed(2),
      meta:              metaMes,
      pctMeta:           pctMeta
    };
  }

  // ── Período anterior (para delta) ─────────────────────────
  var factAnt = 0; var ventasAnt = 0;
  if (modo === 'mes') {
    var mesAnt  = mes === 1 ? 12 : mes - 1;
    var anioAnt = mes === 1 ? anio - 1 : anio;
    var mesAntStr = anioAnt + '-' + String(mesAnt).padStart(2,'0');
    rows.forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]).slice(0,7) !== mesAntStr) return;
      factAnt += Number(r[VENT_COL.MONTO]) || 0;
      ventasAnt++;
    });
  } else if (modo === 'hoy') {
    var ayer = _date(new Date(now.getTime() - 86400000));
    rows.forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]) !== ayer) return;
      factAnt += Number(r[VENT_COL.MONTO]) || 0;
      ventasAnt++;
    });
  }
  var deltaFact   = factAnt   > 0 ? (factTotal   - factAnt)   / factAnt   : null;
  var deltaVentas = ventasAnt > 0 ? (totalVentas - ventasAnt) / ventasAnt : null;

  // ── KPIs por sede para resumen ────────────────────────────
  var sedeSI = porSede['SAN ISIDRO']   || { ventas:0, factPEN:0, factUSD:0, nUSD:0, nProductos:0, nServicios:0 };
  var sedePL = porSede['PUEBLO LIBRE'] || { ventas:0, factPEN:0, factUSD:0, nUSD:0, nProductos:0, nServicios:0 };

  return {
    ok:    true,
    modo:  modo,
    mes:   mes,
    anio:  anio,
    periodoLabel: periodoLabel,
    mesNom: mes ? (MESES_ES[mes] || '') : '',
    kpis: {
      factTotal:       factTotal,
      factUSD:         factUSD,
      nVentasUSD:      ventasUSD.length,
      totalVentas:     totalVentas,
      ticketProm:      +ticketProm.toFixed(2),
      nServicios:      nServicios,
      nProductos:      nProductos,
      factServ:        factServ,
      factProd:        factProd,
      nAdelantos:      pendientes.length,
      factAdelantos:   pendientes.filter(function(v){return v.moneda!=='USD';}).reduce(function(s,v){return s+v.monto;},0),
      nCompletos:      nCompletos,
      nPendientes:     sinEstado,
      deltaFact:       deltaFact,
      deltaVentas:     deltaVentas,
      factSI:          sedeSI.factPEN,
      factPL:          sedePL.factPEN,
      ventasSI:        sedeSI.ventas,
      ventasPL:        sedePL.ventas,
      factUSD_SI:      sedeSI.factUSD,
      factUSD_PL:      sedePL.factUSD,
      nUSD_SI:         sedeSI.nUSD,
      nUSD_PL:         sedePL.nUSD,
      nProd_SI:        sedeSI.nProductos,
      nProd_PL:        sedePL.nProductos,
      nServ_SI:        sedeSI.nServicios,
      nServ_PL:        sedePL.nServicios
    },
    proyeccion:       proyeccion,
    historialMetas:   historialMetas,
    sedesList:        sedesList,
    pagosList:        pagosList,
    asesorList:       asesorList,
    tratList:         tratList,
    adelantos:        pendientes.map(function(v) {
      return {
        rowNum:    v.rowNum,   ventaId:   v.ventaId,
        fecha:     v.fecha,    nombres:   v.nombres,
        apellidos: v.apellidos, trat:     v.trat,
        monto:     v.monto,    moneda:    v.moneda,
        pago:      v.pago,     asesor:    v.asesor,
        sede:      v.sede,     num:       v.num,
        whatsapp:  _wa(v.num)
      };
    })
  };
}

function _emptyResult(modo, mes, anio, lbl) {
  return {
    ok:true, modo:modo, mes:mes, anio:anio, periodoLabel:lbl||'',
    kpis:{factTotal:0,factUSD:0,nVentasUSD:0,totalVentas:0,ticketProm:0,
          nServicios:0,nProductos:0,factServ:0,factProd:0,nAdelantos:0,
          factAdelantos:0,nCompletos:0,nPendientes:0,deltaFact:null,deltaVentas:null,
          factSI:0,factPL:0,ventasSI:0,ventasPL:0,factUSD_SI:0,factUSD_PL:0,
          nUSD_SI:0,nUSD_PL:0,nProd_SI:0,nProd_PL:0,nServ_SI:0,nServ_PL:0},
    proyeccion:null, historialMetas:[], sedesList:[], pagosList:[],
    asesorList:[], tratList:[], adelantos:[]
  };
}

// ══════════════════════════════════════════════════════════════
// TABLA PAGINADA
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_getAdminSalesDetail =====
function api_getAdminSalesDetail(modo, mes, anio, desde, hasta, page, perPage, sede, asesor, tipo) {
  cc_requireAdmin();
  var now = new Date();
  modo    = modo    || 'hoy';
  anio    = Number(anio)    || now.getFullYear();
  mes     = Number(mes)     || (now.getMonth() + 1);
  page    = Number(page)    || 1;
  perPage = Number(perPage) || 25;

  var dDesde, dHasta;
  if (modo === 'hoy') {
    dDesde = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    dHasta = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
  } else if (modo === 'mes') {
    dDesde = new Date(anio, mes - 1, 1, 0, 0, 0);
    dHasta = new Date(anio, mes, 0, 23, 59, 59);
  } else if (modo === 'anio') {
    dDesde = new Date(anio, 0, 1, 0, 0, 0);
    dHasta = new Date(anio, 11, 31, 23, 59, 59);
  } else if (modo === 'rango' && desde && hasta) {
    var pd = desde.split('-'); var ph = hasta.split('-');
    dDesde = new Date(Number(pd[0]),Number(pd[1])-1,Number(pd[2]),0,0,0);
    dHasta = new Date(Number(ph[0]),Number(ph[1])-1,Number(ph[2]),23,59,59);
  } else {
    dDesde = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    dHasta = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
  }

  var sedeUp   = _up(_norm(sede   || ''));
  var asesorUp = _up(_norm(asesor || ''));
  var tipoUp   = _up(_norm(tipo   || ''));

  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok:true, items:[], total:0, page:page, pages:0 };

  var rows  = sh.getRange(2, 1, lr - 1, 19).getValues();
  var items = [];
  rows.forEach(function(r, i) {
    if (!_inRango(r[VENT_COL.FECHA], dDesde, dHasta)) return;
    var vSede   = _up(_norm(r[VENT_COL.SEDE]));
    var vAsesor = _up(_norm(r[VENT_COL.ASESOR]));
    var vTipo   = _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO';
    var pagoStr = _norm(r[VENT_COL.PAGO] || '');
    var esUSD   = pagoStr.indexOf('$') >= 0 || pagoStr.toUpperCase().indexOf('USD') >= 0;
    if (sedeUp   && vSede   !== sedeUp)   return;
    if (asesorUp && vAsesor !== asesorUp) return;
    if (tipoUp   && vTipo   !== tipoUp)   return;
    items.push({
      rowNum:     i + 2,
      fecha:      _date(r[VENT_COL.FECHA]),
      nombres:    _norm(r[VENT_COL.NOMBRES]),
      apellidos:  _norm(r[VENT_COL.APELLIDOS]),
      celular:    _norm(r[VENT_COL.CELULAR]),
      trat:       _up(_norm(r[VENT_COL.TRATAMIENTO])),
      pago:       pagoStr,
      monto:      Number(r[VENT_COL.MONTO]) || 0,
      moneda:     esUSD ? 'USD' : 'PEN',
      estadoPago: _up(_norm(r[VENT_COL.ESTADO_PAGO])),
      asesor:     vAsesor,
      sede:       vSede,
      tipo:       vTipo,
      num:        _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]),
      ventaId:    _norm(r[VENT_COL.VENTA_ID])
    });
  });

  items.sort(function(a,b){ return a.fecha < b.fecha ? 1 : -1; });
  var total  = items.length;
  var pages  = Math.ceil(total / perPage) || 1;
  var start  = (page - 1) * perPage;
  return { ok:true, items:items.slice(start, start+perPage), total:total, page:page, pages:pages, perPage:perPage };
}

// ══════════════════════════════════════════════════════════════
// HISTORIAL DE PAGOS DE UN CLIENTE
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_getClienteHistorialT =====
/**
 * Retorna todo el historial de ventas de un cliente por su número
 * Incluye el estado de cada pago para calcular si hay deuda pendiente
 */
function api_getClienteHistorial(num) {
  cc_requireAdmin();
  if (!num) return { ok: false, error: 'Falta número' };
  var numN = _normNum(num);

  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, items: [], totalPagado: 0, totalPendiente: 0 };

  var rows = sh.getRange(2, 1, lr - 1, 19).getValues();
  var items = [];
  rows.forEach(function(r, i) {
    var nR = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
    var match = nR === numN || nR === '51'+numN || nR === numN.replace(/^51/,'') ||
                numN === '51'+nR || numN === nR.replace(/^51/,'');
    if (!match) return;
    var pagoStr = _norm(r[VENT_COL.PAGO] || '');
    var esUSD   = pagoStr.indexOf('$') >= 0 || pagoStr.toUpperCase().indexOf('USD') >= 0;
    items.push({
      rowNum:     i + 2,
      fecha:      _date(r[VENT_COL.FECHA]),
      trat:       _up(_norm(r[VENT_COL.TRATAMIENTO])),
      desc:       _norm(r[VENT_COL.DESCRIPCION]),
      pago:       pagoStr,
      monto:      Number(r[VENT_COL.MONTO]) || 0,
      moneda:     esUSD ? 'USD' : 'PEN',
      estadoPago: _up(_norm(r[VENT_COL.ESTADO_PAGO])),
      asesor:     _up(_norm(r[VENT_COL.ASESOR])),
      sede:       _up(_norm(r[VENT_COL.SEDE])),
      ventaId:    _norm(r[VENT_COL.VENTA_ID])
    });
  });

  items.sort(function(a,b){ return a.fecha < b.fecha ? 1 : -1; });

  var totalPagado    = items.filter(function(v){ return v.estadoPago === 'PAGO COMPLETO' && v.moneda !== 'USD'; })
                            .reduce(function(s,v){ return s+v.monto; }, 0);
  var totalAdelanto  = items.filter(function(v){ return v.estadoPago === 'ADELANTO' && v.moneda !== 'USD'; })
                            .reduce(function(s,v){ return s+v.monto; }, 0);
  var totalPendiente = items.filter(function(v){ return v.estadoPago === 'PENDIENTE' && v.moneda !== 'USD'; })
                            .reduce(function(s,v){ return s+v.monto; }, 0);

  var nombre = '';
  if (items.length > 0) {
    var r0 = rows.find(function(r) {
      var nR = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
      return nR === numN || nR === '51'+numN || nR === numN.replace(/^51/,'');
    });
    if (r0) nombre = (_norm(r0[VENT_COL.NOMBRES])+' '+_norm(r0[VENT_COL.APELLIDOS])).trim();
  }

  return {
    ok:             true,
    num:            numN,
    nombre:         nombre,
    items:          items,
    totalPagado:    totalPagado,
    totalAdelanto:  totalAdelanto,
    totalPendiente: totalPendiente,
    nVisitas:       items.length
  };
}

// ══════════════════════════════════════════════════════════════
// CONFIG: METAS + MÉTODOS DE PAGO
// ══════════════════════════════════════════════════════════════

// ===== CTRL+F: api_getSalesConfig =====
function api_getSalesConfig() {
  cc_requireAdmin();
  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);

  // Leer metas
  var metas = [];
  try {
    var shMeta = ss.getSheetByName('METAS_VENTAS');
    if (shMeta && shMeta.getLastRow() >= 2) {
      shMeta.getRange(2, 1, shMeta.getLastRow()-1, 5).getValues().forEach(function(r, i) {
        if (!r[0]) return;
        metas.push({ rowNum:i+2, periodo:_norm(r[0]), meta:Number(r[1])||0, moneda:_norm(r[2])||'PEN', desc:_norm(r[3]) });
      });
    }
  } catch(e) {}

  // Leer métodos de pago
  var metodos = [];
  try {
    var shMet = ss.getSheetByName('CAT_METODOS_PAGO');
    if (shMet && shMet.getLastRow() >= 2) {
      shMet.getRange(2, 1, shMet.getLastRow()-1, 6).getValues().forEach(function(r, i) {
        if (!r[0]) return;
        metodos.push({ rowNum:i+2, metodo:_norm(r[0]), sede:_up(_norm(r[1]||'')), activo:_norm(r[2])==='SI', orden:Number(r[3])||0, moneda:_norm(r[4])||'PEN' });
      });
    }
  } catch(e) {}

  // Leer tratamientos únicos desde ventas
  var tratsSet = {};
  try {
    var shV = _sh(CFG.SHEET_VENTAS);
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      shV.getRange(2, VENT_COL.TRATAMIENTO+1, lrV-1, 1).getValues().forEach(function(r) {
        var t = _up(_norm(r[0]||''));
        if (t) tratsSet[t] = true;
      });
    }
  } catch(e) {}

  return {
    ok:      true,
    metas:   metas.sort(function(a,b){ return b.periodo.localeCompare(a.periodo); }),
    metodos: metodos.sort(function(a,b){ return a.orden - b.orden; }),
    tratamientos: Object.keys(tratsSet).sort()
  };
}

// ===== CTRL+F: api_saveSalesConfig =====
/**
 * Guarda o actualiza la meta de un período
 * @param {Object} payload { periodo, meta, moneda, desc }
 */
function api_saveSalesConfig(payload) {
  cc_requireAdmin();
  payload = payload || {};
  var periodo = _norm(payload.periodo || '');
  var meta    = Number(payload.meta) || 0;
  var moneda  = _norm(payload.moneda || 'PEN');
  var desc    = _norm(payload.desc || '');
  if (!periodo) return { ok:false, error:'Falta período (yyyy-MM)' };

  var ss     = SpreadsheetApp.openById(CFG.SHEET_ID);
  var shMeta = ss.getSheetByName('METAS_VENTAS');
  if (!shMeta) return { ok:false, error:'Hoja METAS_VENTAS no existe. Ejecuta setupSalesSheets()' };

  var lr = shMeta.getLastRow();
  var rowNum = -1;
  if (lr >= 2) {
    var periodos = shMeta.getRange(2, 1, lr-1, 1).getValues();
    for (var i = 0; i < periodos.length; i++) {
      if (_norm(periodos[i][0]) === periodo) { rowNum = i+2; break; }
    }
  }

  if (rowNum >= 2) {
    shMeta.getRange(rowNum, 2, 1, 4).setValues([[meta, moneda, desc, new Date()]]);
    return { ok:true, action:'updated', periodo:periodo };
  } else {
    shMeta.appendRow([periodo, meta, moneda, desc, new Date()]);
    return { ok:true, action:'created', periodo:periodo };
  }
}

// ===== CTRL+F: api_saveMetodoPago =====
/**
 * Guarda o actualiza un método de pago
 * @param {Object} payload { rowNum, metodo, sede, activo, orden, moneda }
 */
function api_saveMetodoPago(payload) {
  cc_requireAdmin();
  payload = payload || {};
  var metodo = _norm(payload.metodo || '');
  var sede   = _up(_norm(payload.sede || ''));
  var activo = payload.activo !== false ? 'SI' : 'NO';
  var orden  = Number(payload.orden) || 99;
  var moneda = _norm(payload.moneda || 'PEN');
  var rowNum = Number(payload.rowNum) || 0;
  if (!metodo) return { ok:false, error:'Falta nombre del método' };

  var ss    = SpreadsheetApp.openById(CFG.SHEET_ID);
  var shMet = ss.getSheetByName('CAT_METODOS_PAGO');
  if (!shMet) return { ok:false, error:'Hoja CAT_METODOS_PAGO no existe. Ejecuta setupSalesSheets()' };

  if (rowNum >= 2) {
    shMet.getRange(rowNum, 1, 1, 5).setValues([[metodo, sede, activo, orden, moneda]]);
    return { ok:true, action:'updated', rowNum:rowNum };
  } else {
    shMet.appendRow([metodo, sede, activo, orden, moneda, new Date()]);
    return { ok:true, action:'created', rowNum:shMet.getLastRow() };
  }
}

// ===== CTRL+F: api_deleteMetodoPago =====
function api_deleteMetodoPago(rowNum) {
  cc_requireAdmin();
  rowNum = Number(rowNum);
  if (!rowNum || rowNum < 2) return { ok:false, error:'rowNum inválido' };
  var ss    = SpreadsheetApp.openById(CFG.SHEET_ID);
  var shMet = ss.getSheetByName('CAT_METODOS_PAGO');
  if (!shMet) return { ok:false, error:'Hoja no existe' };
  if (rowNum > shMet.getLastRow()) return { ok:false, error:'Fila no existe' };
  shMet.deleteRow(rowNum);
  return { ok:true, deleted:rowNum };
}

// ══════════════════════════════════════════════════════════════
// WRAPPERS TOKEN
// ══════════════════════════════════════════════════════════════

function api_getAdminSalesDashboardT(token, modo, mes, anio, desde, hasta) {
  _setToken(token); return api_getAdminSalesDashboard(modo, mes, anio, desde, hasta);
}
function api_getAdminSalesDetailT(token, modo, mes, anio, desde, hasta, page, perPage, sede, asesor, tipo) {
  _setToken(token); return api_getAdminSalesDetail(modo, mes, anio, desde, hasta, page, perPage, sede, asesor, tipo);
}
function api_getClienteHistorialT(token, num) {
  _setToken(token); return api_getClienteHistorial(num);
}
function api_getSalesConfigT(token) {
  _setToken(token); return api_getSalesConfig();
}
function api_saveSalesConfigT(token, payload) {
  _setToken(token); return api_saveSalesConfig(payload);
}
function api_saveMetodoPagoT(token, payload) {
  _setToken(token); return api_saveMetodoPago(payload);
}
function api_deleteMetodoPagoT(token, rowNum) {
  _setToken(token); return api_deleteMetodoPago(rowNum);
}

function test_AdminSales() {
  Logger.log('=== GS_20_AdminSales v2.0 TEST ===');
  Logger.log('1. Ejecutar setupSalesSheets() una vez para crear hojas');
  Logger.log('2. api_getAdminSalesDashboardT(token, "hoy"|"mes"|"rango", mes, anio, desde, hasta)');
  Logger.log('3. api_getClienteHistorialT(token, num)');
  Logger.log('4. api_getSalesConfigT(token) / api_saveSalesConfigT / api_saveMetodoPagoT');
  Logger.log('=== OK ===');
}