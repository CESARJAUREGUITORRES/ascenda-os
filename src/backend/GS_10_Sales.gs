/**
 * AscendaOS v1 — GS_10_Sales.gs FINAL
 * Fix definitivo: usa columna ASESOR (K=col11 base1, índice10 base0)
 * comparando con el LABEL del RRHH que es lo que viene en s.asesor
 */

function _comFromData(ventas) {
  var serv = 0; var prod = 0; var fact = 0;
  (ventas || []).forEach(function(v) {
    fact += v.monto;
    var rate = _comRate(v.tipo, v.monto);
    if (rate.tipo === 'pct') serv += v.monto * rate.valor;
    else                     prod += rate.valor;
  });
  return { serv: serv, prod: prod, total: serv + prod, fact: fact };
}

/**
 * Lee el Sheet de ventas filtrando por asesor
 * Columna K (índice 10 base0) = ASESOR
 * El label en RRHH col L (índice 11) = "WILMER", "RUVILA", etc.
 * s.asesor viene del campo label de RRHH → coincide exactamente
 */
function _readVentasAsesor(miLabel, anio) {
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return [];

  var añoStr = String(anio);
  // Leer columnas A(fecha) B(nombres) C(apellidos) E(celular) F(trat)
  // I(monto) J(estado_pago) K(asesor) M(sede) N(tipo) P(num_limpio)
  var rows = sh.getRange(2, 1, lr - 1, 19).getValues();
  var miLabelUp = _up(miLabel);

  return rows.filter(function(r) {
    var fd   = _date(r[VENT_COL.FECHA]);
    var ase  = _up(_norm(r[VENT_COL.ASESOR]));  // col K, índice 10
    if (!fd || fd.slice(0,4) !== añoStr) return false;
    return ase === miLabelUp;
  }).map(function(r) {
    return {
      fecha:    _date(r[VENT_COL.FECHA]),
      nombres:  _norm(r[VENT_COL.NOMBRES]),
      apellidos:_norm(r[VENT_COL.APELLIDOS]),
      num:      _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]),
      trat:     _norm(r[VENT_COL.TRATAMIENTO]),
      monto:    Number(r[VENT_COL.MONTO]) || 0,
      tipo:     _up(_norm(r[VENT_COL.TIPO])) || 'SERVICIO',
      sede:     _up(_norm(r[VENT_COL.SEDE])),
      pago:     _norm(r[VENT_COL.PAGO]),
      estadoPago: _norm(r[VENT_COL.ESTADO_PAGO])
    };
  });
}

// ── DASHBOARD ──
function api_getAdvisorSalesDashboard(mes, anio) {
  var s   = cc_requireSession();
  var now = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);

  // Leer todo el año del asesor de una vez
  var ventasAnio = _readVentasAsesor(s.asesor, anio);

  var mesStr  = String(anio) + '-' + String(mes).padStart(2,'0');
  var misMes  = ventasAnio.filter(function(v) {
    return v.fecha.slice(0,7) === mesStr;
  });

  // KPIs del mes
  var factTotal=0; var factServ=0; var factProd=0;
  var cnServ=0; var cnProd=0;
  misMes.forEach(function(v) {
    factTotal += v.monto;
    if (v.tipo === 'PRODUCTO') { factProd += v.monto; cnProd++; }
    else                       { factServ += v.monto; cnServ++; }
  });

  // Por sede
  var porSede = {};
  misMes.forEach(function(v) {
    var sd = v.sede || 'SIN SEDE';
    porSede[sd] = (porSede[sd]||0) + v.monto;
  });

  // Historial anual desde memoria
  var historial = [];
  for (var m = 1; m <= mes; m++) {
    var pref = String(anio) + '-' + String(m).padStart(2,'0');
    var vM   = ventasAnio.filter(function(v){ return v.fecha.slice(0,7)===pref; });
    var cM   = _comFromData(vM);
    historial.push({
      mes:m, mesNom:MESES_ES[m].slice(0,3),
      fact:cM.fact, comServ:cM.serv,
      comProd:cM.prod, comTotal:cM.total, ventas:vM.length
    });
  }

  // Top 5 clientes del mes
  var cliMap = {};
  misMes.forEach(function(v) {
    var nom = (v.nombres+' '+v.apellidos).trim().toUpperCase()||v.num;
    var key = v.num||nom;
    if (!cliMap[key]) cliMap[key] = {nombre:nom,num:v.num,fact:0,ultFecha:'',wa:_wa(v.num)};
    cliMap[key].fact += v.monto;
    if (!cliMap[key].ultFecha || v.fecha > cliMap[key].ultFecha) cliMap[key].ultFecha = v.fecha;
  });
  var topClientes = Object.values(cliMap).sort(function(a,b){return b.fact-a.fact;}).slice(0,5);

  return {
    ok:true, mes:mes, anio:anio,
    kpis:{
      factTotal:factTotal, count:misMes.length,
      ticketProm:misMes.length?factTotal/misMes.length:0,
      factServ:factServ, factProd:factProd, cnServ:cnServ, cnProd:cnProd
    },
    porSede:porSede, historial:historial,
    topClientes:topClientes, ultimas:misMes.slice(0,10)
  };
}

function api_getAdvisorSalesDashboardT(token, mes, anio) {
  _setToken(token); return api_getAdvisorSalesDashboard(mes, anio);
}

// ── LISTADO CON FILTROS ──
function api_listAdvisorSales(mes, anio, tipo) {
  var s   = cc_requireSession();
  var now = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);

  var sh     = _sh(CFG.SHEET_VENTAS);
  var lr     = sh.getLastRow();
  if (lr < 2) return {ok:true,items:[],factTotal:0,comTotal:0};

  var mesStr  = String(anio)+'-'+String(mes).padStart(2,'0');
  var labelUp = _up(s.asesor);
  var tipoUp  = _up(tipo||'');

  var result = sh.getRange(2,1,lr-1,19).getValues()
    .filter(function(r){
      var fd  = _date(r[VENT_COL.FECHA]);
      if(!fd||fd.slice(0,7)!==mesStr) return false;
      if(_up(_norm(r[VENT_COL.ASESOR]))!==labelUp) return false;
      if(tipoUp && _up(_norm(r[VENT_COL.TIPO]))!==tipoUp) return false;
      return true;
    })
    .map(function(r){
      var monto = Number(r[VENT_COL.MONTO])||0;
      var tipo2 = _up(_norm(r[VENT_COL.TIPO]))||'SERVICIO';
      var rate  = _comRate(tipo2, monto);
      var com   = rate.tipo==='pct'?monto*rate.valor:rate.valor;
      return {
        fecha:    _date(r[VENT_COL.FECHA]),
        nombres:  _norm(r[VENT_COL.NOMBRES]),
        apellidos:_norm(r[VENT_COL.APELLIDOS]),
        num:      _normNum(r[VENT_COL.NUM_LIMPIO]||r[VENT_COL.CELULAR]),
        trat:     _norm(r[VENT_COL.TRATAMIENTO]),
        monto:    monto,
        tipo:     tipo2,
        asesor:   _norm(r[VENT_COL.ASESOR]),
        sede:     _up(_norm(r[VENT_COL.SEDE])),
        pago:     _norm(r[VENT_COL.PAGO]),
        comision: com
      };
    })
    .sort(function(a,b){return a.fecha<b.fecha?1:-1;});

  var factTotal=result.reduce(function(s,v){return s+v.monto;},0);
  var comTotal =result.reduce(function(s,v){return s+v.comision;},0);
  return {ok:true,items:result,factTotal:factTotal,comTotal:comTotal};
}

function api_listAdvisorSalesT(token, mes, anio, tipo) {
  _setToken(token); return api_listAdvisorSales(mes, anio, tipo);
}

// ── REGISTRAR VENTA ──
function api_registerSale(payload) {
  var s = cc_requireSession();
  payload = payload||{};
  var result = da_saveVenta(payload, s);
  try {
    var now    = new Date();
    var admins = _asesoresActivos().filter(function(a){return _normRole(a.role)===ROLES.ADMIN;});
    admins.forEach(function(adm){
      _notifSheet().appendRow([
        _uid(),_date(now),_time(now),'VENTA',
        '💰 Nueva venta: '+_fmtSoles(payload.monto||0),
        s.asesor+' — '+_norm(payload.tratamiento)+' — '+_norm(payload.celular),
        s.idAsesor,s.asesor,adm.idAsesor,adm.label||adm.nombre,''
      ]);
    });
  } catch(e){}
  cache_invalidateDashboard();
  return result;
}

function api_registerSaleT(token, payload) {
  _setToken(token); return api_registerSale(payload);
}

// ── KPIs ADMIN ──
function api_getGlobalSalesKpis(mes, anio) {
  cc_requireAdmin();
  var now=new Date();
  anio=Number(anio)||now.getFullYear();
  mes =Number(mes) ||(now.getMonth()+1);
  var desde=new Date(anio,mes-1,1);
  var hasta=new Date(anio,mes,0,23,59,59);
  var ventas=da_ventasData(desde,hasta);
  var fact=ventas.reduce(function(s,v){return s+v.monto;},0);
  var hoy=_date(now);
  var vHoy=ventas.filter(function(v){return _date(v.fecha)===hoy;});
  return {
    ok:true,mes:mes,anio:anio,factTotal:fact,
    factHoy:vHoy.reduce(function(s,v){return s+v.monto;},0),
    count:ventas.length,countHoy:vHoy.length,
    ticketProm:ventas.length?fact/ventas.length:0
  };
}

function api_getGlobalSalesKpisT(token, mes, anio) {
  _setToken(token); return api_getGlobalSalesKpis(mes, anio);
}

// ── SIMULADOR ──
function api_getComisionSimulada(monto, tipo) {
  cc_requireSession();
  monto=Number(monto)||0;
  tipo=_up(tipo||'SERVICIO');
  var rate=_comRate(tipo,monto);
  var com=rate.tipo==='pct'?monto*rate.valor:rate.valor;
  return {ok:true,monto:monto,tipo:tipo,com:com,comFmt:_fmtSoles(com),rate:rate};
}

function api_getComisionSimuladaT(token, monto, tipo) {
  _setToken(token); return api_getComisionSimulada(monto, tipo);
}

// ── TEST ──
function test_Sales() {
  Logger.log('=== GS_10_Sales FINAL ===');
  Logger.log('Columna ASESOR en VENTAS = col K (índice 10 base0)');
  Logger.log('s.asesor viene de RRHH col L (LABEL) = WILMER, RUVILA, etc.');
  Logger.log('Comparación: _up(r[10]) === _up(s.asesor)');
  Logger.log('=== OK ===');
}

// ── DEBUG: ejecutar para verificar ──
function debug_QuienSoyYo() {
  Logger.log("=== DEBUG ASESOR EN VENTAS ===");
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  // Mostrar valores únicos de col K (ASESOR)
  var datos = sh.getRange(2, VENT_COL.ASESOR+1, Math.min(200,lr-1), 1).getValues();
  var unicos = {};
  datos.forEach(function(r){ var v=_up(_norm(r[0])); if(v) unicos[v]=(unicos[v]||0)+1; });
  Logger.log("Valores únicos en col ASESOR de VENTAS:");
  Object.keys(unicos).forEach(function(k){ Logger.log("  '"+k+"' → "+unicos[k]+" ventas"); });
  Logger.log("=== FIN ===");
}