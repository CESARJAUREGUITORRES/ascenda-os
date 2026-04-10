/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_21_AdminComisiones.gs v2.0              ║
 * ║  Módulo: Panel de Comisiones Admin                          ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · api_getAdminComisionesPanel  — panel con filtros flexibles
 *   MOD-02 · api_getDetalleAsesorCom      — historial + rentabilidad asesor
 *   MOD-03 · api_editarVentaComision       — editar asesor / NO APLICA / monto
 *   MOD-04 · api_getReglasCom             — leer tabla de reglas vigente
 *   MOD-05 · api_saveReglasCom            — guardar reglas (CRUD completo)
 *   MOD-06 · api_updateComisionManual     — ajuste manual con auditoría
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · PANEL COMPLETO CON FILTROS FLEXIBLES
// ══════════════════════════════════════════════════════════════
// C01_START

/**
 * api_getAdminComisionesPanel
 *
 * filtro.tipo      = 'dia' | 'mes' | 'anio' | 'rango'
 * filtro.fecha     = 'YYYY-MM-DD'  (para dia)
 * filtro.mes       = 1-12          (para mes)
 * filtro.anio      = 4 dígitos     (para mes / anio)
 * filtro.fechaIni  = 'YYYY-MM-DD'  (para rango)
 * filtro.fechaFin  = 'YYYY-MM-DD'  (para rango)
 * filtro.asesor    = nombre o null (sub-filtro opcional)
 */
function api_getAdminComisionesPanel(filtro) {
  cc_requireAdmin();
  filtro = filtro || {};
  var now   = new Date();
  var rango = _resolverRango(filtro, now);

  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  if (lrV < 2) return _emptyPanel(filtro);

  var rows = shV.getRange(2, 1, lrV - 1, 20).getValues();

  var ventasMes = [];
  var factServ = 0; var factProd = 0;
  var comServ  = 0; var comProd  = 0;
  var cntServ  = 0; var cntProd  = 0;
  var byAsesor = {};

  rows.forEach(function(r, idx) {
    var fd = _date(r[VENT_COL.FECHA]);
    if (!_enRango(fd, rango)) return;

    var asesorRaw = _up(_norm(r[VENT_COL.ASESOR]));
    var noAplica  = !asesorRaw || asesorRaw === 'NO APLICA';

    if (filtro.asesor && _up(_norm(filtro.asesor)) !== asesorRaw) return;

    var monto   = Number(r[VENT_COL.MONTO]) || 0;
    var tipo    = _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO';
    var esProd  = tipo === 'PRODUCTO';
    var trat    = _norm(r[VENT_COL.TRATAMIENTO])  || '—';
    var nom     = (_norm(r[VENT_COL.NOMBRES]) + ' ' + _norm(r[VENT_COL.APELLIDOS])).trim() || '—';
    var num     = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
    var sede    = _up(_norm(r[VENT_COL.SEDE]))     || '—';
    var pago    = _norm(r[VENT_COL.PAGO])          || '—';
    var estPago = _up(_norm(r[VENT_COL.ESTADO_PAGO])) || '—';
    var vid     = _norm(r[VENT_COL.VENTA_ID])      || '';

    var com = 0;
    if (!noAplica) {
      var cr = _comRate(esProd ? 'PRODUCTO' : 'SERVICIO', monto);
      if (cr) com = cr.tipo === 'pct' ? monto * cr.valor : cr.valor;
    }

    ventasMes.push({
      rowNum:     idx + 2,
      ventaId:    vid,
      fecha:      fd,
      cliente:    nom,
      num:        num || '—',
      trat:       trat,
      tipo:       tipo,
      monto:      monto,
      comision:   +com.toFixed(2),
      asesor:     noAplica ? 'NO APLICA' : asesorRaw,
      sede:       sede,
      pago:       pago,
      estadoPago: estPago,
      noAplica:   noAplica
    });

    if (!noAplica) {
      if (esProd) { factProd += monto; comProd += com; cntProd++; }
      else        { factServ += monto; comServ += com; cntServ++; }

      if (!byAsesor[asesorRaw]) {
        byAsesor[asesorRaw] = {
          fact:0, comTotal:0, comServ:0, comProd:0,
          ventas:0, servicios:0, productos:0
        };
      }
      byAsesor[asesorRaw].fact     += monto;
      byAsesor[asesorRaw].comTotal += com;
      byAsesor[asesorRaw].ventas++;
      if (esProd) { byAsesor[asesorRaw].comProd += com; byAsesor[asesorRaw].productos++; }
      else        { byAsesor[asesorRaw].comServ += com; byAsesor[asesorRaw].servicios++;  }
    }
  });

  // Ranking
  // Calcular % clientes nuevos por asesor (cruzando con leads del mes)
  var leadNumsGlobal = {};
  try {
    var mesR  = rango.mes  || now.getMonth() + 1;
    var anioR = rango.anio || now.getFullYear();
    var desdeR = new Date(anioR, mesR-1, 1, 0,0,0);
    var hastaR = new Date(anioR, mesR, 0, 23,59,59);
    var shLdR  = _sh(CFG.SHEET_LEADS);
    var lrLdR  = shLdR.getLastRow();
    if (lrLdR >= 2) {
      shLdR.getRange(2,1,lrLdR-1,9).getValues().forEach(function(r) {
        if (!_inRango(r[LEAD_COL.FECHA]||r[0], desdeR, hastaR)) return;
        var n = _normNum(r[LEAD_COL.NUM_LIMPIO]||r[LEAD_COL.CELULAR]);
        if (n) { leadNumsGlobal[n]=true; leadNumsGlobal['51'+n]=true; leadNumsGlobal[n.replace(/^51/,'')]=true; }
      });
    }
  } catch(eL) {}

  // Contar nuevos por asesor en ventasMes
  var nuevosPorAsesor = {};
  ventasMes.forEach(function(v) {
    if (!v.asesor || v.noAplica) return;
    if (!nuevosPorAsesor[v.asesor]) nuevosPorAsesor[v.asesor] = {nuevos:0, total:0};
    nuevosPorAsesor[v.asesor].total++;
    if (v.num && v.num !== '—') {
      var clean = v.num.replace(/\D/g,'');
      if (leadNumsGlobal[clean] || leadNumsGlobal['51'+clean] || leadNumsGlobal[clean.replace(/^51/,'')]) {
        nuevosPorAsesor[v.asesor].nuevos++;
        v.esNuevo = true;
      }
    }
  });

  var ranking = Object.keys(byAsesor).map(function(nom) {
    var d = byAsesor[nom];
    var pctMeta = null;
    try {
      var mes  = rango.mes  || now.getMonth() + 1;
      var anio = rango.anio || now.getFullYear();
      var meta = _getMetaAsesor(nom, mes, anio) || 0;
      pctMeta  = meta > 0 ? +(d.comTotal / meta * 100).toFixed(1) : null;
    } catch(e) {}
    var nData     = nuevosPorAsesor[nom] || {nuevos:0, total:0};
    var pctNuevos = nData.total > 0 ? Math.round(nData.nuevos / nData.total * 100) : 0;
    return {
      nombre:    nom,
      fact:      +d.fact.toFixed(2),
      comTotal:  +d.comTotal.toFixed(2),
      comServ:   +d.comServ.toFixed(2),
      comProd:   +d.comProd.toFixed(2),
      ventas:    d.ventas,
      servicios: d.servicios,
      productos: d.productos,
      pctMeta:   pctMeta,
      pctNuevos: pctNuevos,
      cntNuevos: nData.nuevos
    };
  }).sort(function(a,b){ return b.comTotal - a.comTotal; });

  var factTotal = factServ + factProd;
  var comTotal  = comServ  + comProd;
  var cntTotal  = cntServ  + cntProd;

  var cards = {
    comTotal:  +comTotal.toFixed(2),
    comServ:   +comServ.toFixed(2),
    comProd:   +comProd.toFixed(2),
    cntTotal:  cntTotal,
    cntServ:   cntServ,
    cntProd:   cntProd,
    factTotal: +factTotal.toFixed(2),
    factServ:  +factServ.toFixed(2),
    factProd:  +factProd.toFixed(2),
    pctServ:   factTotal > 0 ? +(factServ / factTotal * 100).toFixed(1) : 0,
    pctProd:   factTotal > 0 ? +(factProd / factTotal * 100).toFixed(1) : 0
  };

  var historial   = _calcHistorial(rows, now, 6);
  var tablaReglas = null;
  try { tablaReglas = _loadTablasCom(); } catch(e) {}

  ventasMes.sort(function(a,b){ return b.fecha > a.fecha ? 1 : -1; });

  return {
    ok:          true,
    filtro:      filtro,
    rangoLabel:  rango.label,
    cards:       cards,
    ranking:     ranking,
    historial:   historial,
    tablaReglas: tablaReglas,
    ventasMes:   ventasMes,
    totalVentas: ventasMes.length
  };
}

function api_getAdminComisionesT(token, filtro) {
  _setToken(token);
  return api_getAdminComisionesPanel(filtro);
}

// ── Helpers rango ──────────────────────────────────────────

function _resolverRango(filtro, now) {
  var tipo = filtro.tipo || 'mes';
  var mes  = filtro.mes  || (now.getMonth() + 1);
  var anio = filtro.anio || now.getFullYear();

  if (tipo === 'dia') {
    var f = filtro.fecha || _date(now);
    return { ini:f, fin:f, mes:mes, anio:anio, label:f };
  }
  if (tipo === 'mes') {
    var ini = anio + '-' + String(mes).padStart(2,'0') + '-01';
    var fin = anio + '-' + String(mes).padStart(2,'0') + '-' + _diasDelMes(mes,anio);
    return { ini:ini, fin:fin, mes:mes, anio:anio, label:_mesLabel(mes) + ' ' + anio };
  }
  if (tipo === 'anio') {
    return { ini:anio+'-01-01', fin:anio+'-12-31', mes:null, anio:anio, label:'Año '+anio };
  }
  if (tipo === 'rango') {
    return { ini:filtro.fechaIni, fin:filtro.fechaFin, mes:null, anio:null,
             label:(filtro.fechaIni||'')+'→'+(filtro.fechaFin||'') };
  }
  var ini2 = anio+'-'+String(mes).padStart(2,'0')+'-01';
  var fin2 = anio+'-'+String(mes).padStart(2,'0')+'-'+_diasDelMes(mes,anio);
  return { ini:ini2, fin:fin2, mes:mes, anio:anio, label:_mesLabel(mes)+' '+anio };
}

function _enRango(fecha, rango) {
  return fecha >= rango.ini && fecha <= rango.fin;
}

function _diasDelMes(mes, anio) {
  return new Date(anio, mes, 0).getDate();
}

function _mesLabel(m) {
  return ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'][m-1]||'';
}

function _emptyPanel(filtro) {
  return {
    ok:true, filtro:filtro, rangoLabel:'', cards:{
      comTotal:0,comServ:0,comProd:0,cntTotal:0,cntServ:0,cntProd:0,
      factTotal:0,factServ:0,factProd:0,pctServ:0,pctProd:0
    },
    ranking:[],historial:[],tablaReglas:null,ventasMes:[],totalVentas:0
  };
}

function _calcHistorial(rows, now, nMeses) {
  var hist = [];
  for (var i = nMeses - 1; i >= 0; i--) {
    var d  = new Date(now.getFullYear(), now.getMonth() - i, 1);
    var ms = d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0');
    var hF = 0; var hC = 0;
    rows.forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]).slice(0,7) !== ms) return;
      var asr = _up(_norm(r[VENT_COL.ASESOR]));
      if (!asr || asr === 'NO APLICA') return;
      var m2 = Number(r[VENT_COL.MONTO]) || 0;
      var t2 = _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO';
      var cr = _comRate(t2 === 'PRODUCTO' ? 'PRODUCTO' : 'SERVICIO', m2);
      var cf = cr ? (cr.tipo === 'pct' ? m2 * cr.valor : cr.valor) : 0;
      hF += m2; hC += cf;
    });
    hist.push({ mes:ms, label:_mesLabel(d.getMonth()+1), fact:+hF.toFixed(2), com:+hC.toFixed(2) });
  }
  return hist;
}
// C01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · DETALLE ASESOR (historial + rentabilidad + ventas)
// ══════════════════════════════════════════════════════════════
// C02_START

function api_getDetalleAsesorCom(nombreAsesor, filtro) {
  cc_requireAdmin();
  nombreAsesor = _up(_norm(nombreAsesor));
  var now   = new Date();
  filtro    = filtro || { tipo:'mes', mes:now.getMonth()+1, anio:now.getFullYear() };
  var rango = _resolverRango(filtro, now);

  var shV     = _sh(CFG.SHEET_VENTAS);
  var lrV     = shV.getLastRow();
  var allRows = lrV >= 2 ? shV.getRange(2,1,lrV-1,20).getValues() : [];

  var ventas  = [];
  var comBase = 0; var factTot = 0;
  var comServ = 0; var comProd = 0;
  var cntServ = 0; var cntProd = 0;

  allRows.forEach(function(r, idx) {
    if (!_enRango(_date(r[VENT_COL.FECHA]), rango)) return;
    if (_up(_norm(r[VENT_COL.ASESOR])) !== nombreAsesor) return;

    var monto = Number(r[VENT_COL.MONTO]) || 0;
    var tipo  = _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO';
    var cr    = _comRate(tipo === 'PRODUCTO' ? 'PRODUCTO' : 'SERVICIO', monto);
    var com   = cr ? (cr.tipo === 'pct' ? monto * cr.valor : cr.valor) : 0;

    var numV = _normNum(r[VENT_COL.NUM_LIMPIO]||r[VENT_COL.CELULAR]);
    ventas.push({
      rowNum:  idx + 2,
      ventaId: _norm(r[VENT_COL.VENTA_ID]) || '',
      fecha:   _date(r[VENT_COL.FECHA]),
      cliente: (_norm(r[VENT_COL.NOMBRES])+' '+_norm(r[VENT_COL.APELLIDOS])).trim()||'—',
      num:     numV||'—',
      trat:    _norm(r[VENT_COL.TRATAMIENTO])||'—',
      tipo:    tipo,
      monto:   monto,
      comision:+com.toFixed(2),
      sede:    _up(_norm(r[VENT_COL.SEDE]))||'—',
      esNuevo: false  // se calcula abajo cruzando con leads del mes
    });

    comBase += com; factTot += monto;
    if (tipo === 'PRODUCTO') { comProd += com; cntProd++; }
    else                     { comServ += com; cntServ++; }
  });

  // Ajustes manuales
  var ajusteTotal = 0;
  try {
    var mes    = rango.mes  || now.getMonth()+1;
    var anio   = rango.anio || now.getFullYear();
    var mesStr = anio + '-' + String(mes).padStart(2,'0');
    var ss  = SpreadsheetApp.openById(CFG.SHEET_ID);
    var sha = ss.getSheetByName('COMISIONES_AJUSTES');
    if (sha && sha.getLastRow() >= 2) {
      sha.getRange(2,1,sha.getLastRow()-1,4).getValues().forEach(function(r) {
        if (_norm(r[1]) === mesStr && _up(_norm(r[2])) === nombreAsesor) {
          ajusteTotal += Number(r[3]) || 0;
        }
      });
    }
  } catch(e) {}

  // Historial 6 meses
  var histMeses = [];
  for (var i = 5; i >= 0; i--) {
    var d  = new Date(now.getFullYear(), now.getMonth() - i, 1);
    var ms = d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0');
    var hF = 0; var hC = 0; var hV = 0;
    allRows.forEach(function(r) {
      if (_date(r[VENT_COL.FECHA]).slice(0,7) !== ms) return;
      if (_up(_norm(r[VENT_COL.ASESOR])) !== nombreAsesor) return;
      var m2 = Number(r[VENT_COL.MONTO]) || 0;
      var t2 = _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO';
      var cr = _comRate(t2 === 'PRODUCTO' ? 'PRODUCTO' : 'SERVICIO', m2);
      hF += m2; hC += cr ? (cr.tipo==='pct'? m2*cr.valor : cr.valor) : 0; hV++;
    });
    histMeses.push({
      mes:ms, label:_mesLabel(d.getMonth()+1)+' '+d.getFullYear(),
      fact:+hF.toFixed(2), com:+hC.toFixed(2), ventas:hV
    });
  }

  // Rentabilidad vs sueldo
  var sueldo = 0;
  try {
    var shEq = _sh(CFG.SHEET_EQUIPO || 'EQUIPO');
    var lrEq = shEq.getLastRow();
    if (lrEq >= 2) {
      shEq.getRange(2,1,lrEq-1,15).getValues().forEach(function(r) {
        if (_up(_norm(r[0]))===nombreAsesor || _up(_norm(r[1]))===nombreAsesor) {
          sueldo = Number(r[6])||Number(r[5])||0;
        }
      });
    }
  } catch(e) {}

  var utilidad = factTot - sueldo;
  var ratio    = sueldo > 0 ? +(factTot / sueldo).toFixed(2) : null;

  // Meta
  var meta = 0; var pctMeta = null;
  try {
    var mesM  = rango.mes  || now.getMonth()+1;
    var anioM = rango.anio || now.getFullYear();
    meta    = _getMetaAsesor(nombreAsesor, mesM, anioM) || 0;
    pctMeta = meta > 0 ? +((comBase+ajusteTotal)/meta*100).toFixed(1) : null;
  } catch(e) {}

  // Marcar ventas de leads nuevos del mes
  try {
    var mes2   = rango.mes  || now.getMonth()+1;
    var anio2  = rango.anio || now.getFullYear();
    var mesStr2= anio2+'-'+String(mes2).padStart(2,'0');
    var shLd2  = _sh(CFG.SHEET_LEADS);
    var lrLd2  = shLd2.getLastRow();
    var leadNums2 = {};
    if (lrLd2 >= 2) {
      var desde2 = new Date(anio2, mes2-1, 1, 0,0,0);
      var hasta2 = new Date(anio2, mes2, 0, 23,59,59);
      shLd2.getRange(2,1,lrLd2-1,9).getValues().forEach(function(r) {
        if (!_inRango(r[LEAD_COL.FECHA]||r[0], desde2, hasta2)) return;
        var n = _normNum(r[LEAD_COL.NUM_LIMPIO]||r[LEAD_COL.CELULAR]);
        if (n) { leadNums2[n]=true; leadNums2['51'+n]=true; leadNums2[n.replace(/^51/,'')]=true; }
      });
    }
    ventas.forEach(function(v) {
      if (v.num && v.num !== '—') {
        var clean = v.num.replace(/\D/g,'');
        v.esNuevo = !!(leadNums2[clean] || leadNums2['51'+clean] || leadNums2[clean.replace(/^51/,'')]);
      }
    });
  } catch(eN) {}

  ventas.sort(function(a,b){ return b.fecha > a.fecha ? 1 : -1; });

  return {
    ok:true, nombre:nombreAsesor, filtro:filtro,
    ventas:ventas,
    comBase:   +comBase.toFixed(2),
    comServ:   +comServ.toFixed(2),
    comProd:   +comProd.toFixed(2),
    cntServ:   cntServ,
    cntProd:   cntProd,
    ajuste:    +ajusteTotal.toFixed(2),
    comFinal:  +(comBase+ajusteTotal).toFixed(2),
    factTotal: +factTot.toFixed(2),
    nVentas:   ventas.length,
    histMeses: histMeses,
    rentabilidad:{ sueldo:sueldo, fact:+factTot.toFixed(2), utilidad:+utilidad.toFixed(2), ratio:ratio },
    meta:meta, pctMeta:pctMeta
  };
}

function api_getDetalleAsesorComT(token, nombreAsesor, filtro) {
  _setToken(token);
  return api_getDetalleAsesorCom(nombreAsesor, filtro);
}
// C02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · EDITAR VENTA (asesor / NO APLICA / monto)
// ══════════════════════════════════════════════════════════════
// C03_START

function api_editarVentaComision(ventaId, cambios) {
  cc_requireAdmin();
  ventaId = _norm(ventaId);
  if (!ventaId) return { ok:false, error:'VentaId requerido' };

  var sh  = _sh(CFG.SHEET_VENTAS);
  var lr  = sh.getLastRow();
  if (lr < 2) return { ok:false, error:'Sin ventas' };

  var ids    = sh.getRange(2, VENT_COL.VENTA_ID+1, lr-1, 1).getValues();
  var rowNum = -1;
  for (var i = 0; i < ids.length; i++) {
    if (_norm(ids[i][0]) === ventaId) { rowNum = i + 2; break; }
  }
  if (rowNum === -1) return { ok:false, error:'Venta no encontrada: ' + ventaId };

  var fila   = sh.getRange(rowNum, 1, 1, 20).getValues()[0];
  var cambiosLog = [];

  if (cambios.asesor !== undefined && cambios.asesor !== null) {
    var nuevoAsesor = cambios.asesor === '' ? 'NO APLICA' : _up(_norm(cambios.asesor));
    sh.getRange(rowNum, VENT_COL.ASESOR+1).setValue(nuevoAsesor);
    cambiosLog.push('ASESOR: ' + _norm(fila[VENT_COL.ASESOR]) + ' → ' + nuevoAsesor);
  }

  if (cambios.monto !== undefined && cambios.monto !== null && !isNaN(Number(cambios.monto))) {
    var nuevoMonto = Number(cambios.monto);
    sh.getRange(rowNum, VENT_COL.MONTO+1).setValue(nuevoMonto);
    cambiosLog.push('MONTO: ' + fila[VENT_COL.MONTO] + ' → ' + nuevoMonto);
  }

  try {
    var s = cc_requireSession();
    _logAuditoria(s.idAsesor, 'EDIT_VENTA_COM', ventaId,
      cambiosLog.join(' | ') + (cambios.motivo ? ' | MOTIVO: '+cambios.motivo : ''));
  } catch(e) {}

  return { ok:true, ventaId:ventaId, cambios:cambiosLog };
}

function api_editarVentaComisionT(token, ventaId, cambios) {
  _setToken(token);
  return api_editarVentaComision(ventaId, cambios);
}
// C03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · LEER REGLAS DE COMISIONES
// ══════════════════════════════════════════════════════════════
// C04_START

function api_getReglasCom() {
  cc_requireAdmin();
  var tablas = null;
  try { tablas = _loadTablasCom(); } catch(e) {}

  var rowsRaw = [];
  try {
    var sh = _sh(CFG.SHEET_COMISIONES || 'TABLA DE COMISIONES');
    var lr = sh.getLastRow();
    if (lr >= 2) {
      sh.getRange(2,1,lr-1,5).getValues().forEach(function(r, i) {
        rowsRaw.push({ row:i+2, minProd:Number(r[0])||0, comProd:Number(r[1])||0, pctServ:Number(r[4])||0 });
      });
    }
  } catch(e) {}

  // Leer servRangos e incentivo desde PropertiesService (configuración extendida)
  var servRangos = [];
  var incentivo  = { bonoNuevo:0, bonoDesde:0 };
  try {
    var props = PropertiesService.getScriptProperties();
    var srStr = props.getProperty('SERV_RANGOS');
    var incStr= props.getProperty('INCENTIVO_COM');
    if (srStr)  servRangos = JSON.parse(srStr);
    if (incStr) incentivo  = JSON.parse(incStr);
  } catch(ep) {}

  // Si no hay servRangos guardados, crear uno desde el servPct flat existente
  if (!servRangos.length && tablas && tablas.serv) {
    servRangos = [{ min:0, pct: tablas.serv, fijo:0 }];
  }

  return {
    ok:true,
    tablas:     tablas,
    rowsRaw:    rowsRaw,
    servPct:    tablas ? tablas.serv : null,
    servRangos: servRangos,
    prodRangos: tablas ? tablas.prod : [],
    incentivo:  incentivo
  };
}

function api_getReglasComT(token) {
  _setToken(token);
  return api_getReglasCom();
}
// C04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · GUARDAR REGLAS (CRUD completo)
// ══════════════════════════════════════════════════════════════
// C05_START

function api_saveReglasCom(reglas) {
  cc_requireAdmin();
  if (!reglas) return { ok:false, error:'Sin datos' };

  var servPct    = Number(reglas.servPct)    || 0;
  var servRangos = reglas.servRangos         || [];
  var prodRangos = reglas.prodRangos         || [];
  var incentivo  = reglas.incentivo          || { bonoNuevo:0, bonoDesde:0 };

  if (!prodRangos.length) return { ok:false, error:'Sin rangos de productos' };
  if (!servRangos.length && servPct <= 0) return { ok:false, error:'Sin configuración de servicios' };

  // Si no hay servRangos, crear uno desde servPct
  if (!servRangos.length) servRangos = [{ min:0, pct:servPct, fijo:0 }];

  // Usar el pct del primer rango de servicios como servPct compatible
  var servPctEfectivo = servRangos[0].pct || servPct;

  prodRangos.sort(function(a,b){ return (Number(a.min)||0) - (Number(b.min)||0); });

  try {
    var sh = _sh(CFG.SHEET_COMISIONES || 'TABLA DE COMISIONES');
    var lr = sh.getLastRow();
    if (lr >= 2) sh.getRange(2, 1, lr-1, 5).clearContent();

    var data = prodRangos.map(function(rg, i) {
      return [
        Number(rg.min)||0,
        Number(rg.com)||0,
        '',
        i === 0 ? 0 : '',
        i === 0 ? servPctEfectivo : ''
      ];
    });
    sh.getRange(2, 1, data.length, 5).setValues(data);

    // Guardar servRangos e incentivo en PropertiesService
    try {
      var props = PropertiesService.getScriptProperties();
      props.setProperty('SERV_RANGOS',   JSON.stringify(servRangos));
      props.setProperty('INCENTIVO_COM', JSON.stringify(incentivo));
    } catch(ep) {}

    try { cache_delete(_cacheK('com','tabla')); } catch(ec) {}

    var s = cc_requireSession();
    _logAuditoria(s.idAsesor, 'SAVE_REGLAS_COM', 'TABLA',
      'servPct='+servPctEfectivo+' | servRangos='+servRangos.length+
      ' | prodRangos='+prodRangos.length+
      ' | bonoNuevo='+incentivo.bonoNuevo);

    return { ok:true, servPct:servPctEfectivo, servRangos:servRangos,
             prodRangos:prodRangos, incentivo:incentivo };
  } catch(e) {
    return { ok:false, error:e.message };
  }
}

function api_saveReglasComT(token, reglas) {
  _setToken(token);
  return api_saveReglasCom(reglas);
}
// C05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · AJUSTE MANUAL CON AUDITORÍA
// ══════════════════════════════════════════════════════════════
// C06_START

function api_updateComisionManual(idAsesor, mes, anio, ajuste, motivo) {
  cc_requireAdmin();
  if (!idAsesor || isNaN(ajuste)) return { ok:false, error:'Parámetros inválidos' };

  var mesStr = anio + '-' + String(mes).padStart(2,'0');
  var ss     = SpreadsheetApp.openById(CFG.SHEET_ID);
  var sh     = ss.getSheetByName('COMISIONES_AJUSTES');

  if (!sh) {
    sh = ss.insertSheet('COMISIONES_AJUSTES');
    sh.getRange(1,1,1,6).setValues([['FECHA','MES','ID_ASESOR','AJUSTE','MOTIVO','ADMIN']]);
    sh.setFrozenRows(1);
  }

  var s = cc_requireSession();
  sh.appendRow([new Date(), mesStr, _norm(idAsesor), Number(ajuste),
    _norm(motivo)||'Sin motivo', s.idAsesor||'—']);

  return { ok:true, idAsesor:idAsesor, mesStr:mesStr, ajuste:ajuste };
}

function api_updateComisionManualT(token, idAsesor, mes, anio, ajuste, motivo) {
  _setToken(token);
  return api_updateComisionManual(idAsesor, mes, anio, ajuste, motivo);
}
// C06_END

function test_AdminComisiones_v2() {
  Logger.log('=== GS_21_AdminComisiones v2.0 TEST ===');
  Logger.log('api_getAdminComisionesT(token, {tipo:"mes",mes:4,anio:2026})');
  Logger.log('api_getDetalleAsesorComT(token, "WILMER", {tipo:"mes",mes:4,anio:2026})');
  Logger.log('api_editarVentaComisionT(token, ventaId, {asesor:"NUEVO",motivo:"..."})');
  Logger.log('api_getReglasComT(token)');
  Logger.log('api_saveReglasComT(token, {servPct:0.005, prodRangos:[{min:0,com:0.3}]})');
  Logger.log('api_updateComisionManualT(token,asesor,mes,anio,ajuste,motivo)');
  Logger.log('=== OK ===');
}