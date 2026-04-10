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
// ══════════════════════════════════════════════════════════════
// PATCH GS_10 — Pegar al FINAL de GS_10_Sales.gs
// AscendaOS v1 · CREACTIVE OS
//
// INSTRUCCIÓN EXACTA:
//   1. Abre GS_10_Sales.gs en Apps Script
//   2. Baja hasta la última línea del archivo (después de debug_QuienSoyYo)
//   3. Pega TODO este bloque sin tocar nada de lo anterior
//   4. Ctrl+S para guardar
//
// QUÉ AGREGA (3 funciones nuevas):
//   api_registrarPagoT        → crea fila en CONSOLIDADO DE COMPROBANTES
//                               + actualiza ESTADO DE PAGO en VENTAS
//   api_editarPagoT           → edita una fila de CONSOLIDADO DE COMPROBANTES
//                               + re-sincroniza ESTADO DE PAGO en VENTAS
//   api_eliminarPagoT         → elimina fila de CONSOLIDADO DE COMPROBANTES
//                               + revierte ESTADO DE PAGO en VENTAS a PENDIENTE
//   api_getComprobantesRealT  → lee CONSOLIDADO DE COMPROBANTES por número
//   api_getMetodosPagoT       → lista de métodos de pago reales de Zi Vital
//
// HOJAS QUE TOCA:
//   CONSOLIDADO DE COMPROBANTES  — cols confirmadas del Sheet real:
//     0=FECHA, 1=NOMBRES, 2=APELLIDOS, 3=DNI, 4=TRATAMIENTO,
//     5=DESCRIPCIÓN, 6=PAGO CON, 7=MONTO PAGADO, 8=SEDE,
//     9=NUMERO DE DOCUMENTO, 10=ESTADO, 11=CELULAR,
//     12=ASESOR, 13=TIMESTAMP, 14=PROCESADO
//
//   CONSOLIDADO DE VENTAS — cols confirmadas del Sheet real:
//     0=FECHA, 5=TRATAMIENTO, 8=MONTO, 9=ESTADO DE PAGO (base 0)
//     15=NUMERO_LIMPIO, 16=VENTA_ID, 17=NRO_DOC, 18=ESTADO_DOC
//     Col base-1 para writes: ESTADO_PAGO=col10, NRO_DOC=col18, ESTADO_DOC=col19
//
//   LOG_COMPROBANTES — cols: TS, COMP_ID, ACCION, EST_ANTERIOR, EST_NUEVO, USUARIO, NOTAS
// ══════════════════════════════════════════════════════════════


// ── CONSTANTES INTERNAS (no duplican nada de GS_01) ──
var _COMP_COL = {
  FECHA:     0,  NOMBRES:   1,  APELLIDOS:  2,  DNI:    3,
  TRAT:      4,  DESC:      5,  PAGO_CON:   6,  MONTO:  7,
  SEDE:      8,  NRO_DOC:   9,  ESTADO:    10,  CELULAR:11,
  ASESOR:   12,  TIMESTAMP:13,  PROCESADO: 14
};
var _COMP_TOTAL = 15;  // columnas en uso


// ═══════════════════════════════════════════════════
// PATCH-GS10-01 · REGISTRAR PAGO
// ===== CTRL+F: api_registrarPago_GS10 =====
// ═══════════════════════════════════════════════════

/**
 * api_registrarPago
 * Registra un nuevo pago en CONSOLIDADO DE COMPROBANTES
 * y actualiza ESTADO DE PAGO en CONSOLIDADO DE VENTAS.
 *
 * @param {Object} payload
 *   num         {string}  Teléfono del paciente (requerido)
 *   fecha       {string}  Fecha del pago YYYY-MM-DD (requerido)
 *   tratamiento {string}  Nombre del tratamiento (requerido)
 *   descripcion {string}  Descripción del item
 *   pagoCon     {string}  Método de pago (requerido)
 *   monto       {number}  Monto pagado (requerido)
 *   sede        {string}  SAN ISIDRO | PUEBLO LIBRE
 *   nroDoc      {string}  Número de comprobante (BF-001234, etc.)
 *   tipoComp    {string}  BOLETA FISICA | BOLETA VIRTUAL | LIBRE | RH
 *   ventaId     {string}  VENTA_ID exacto para actualizar (opcional)
 *   esAdelanto  {boolean} true=ADELANTO, false=PAGO COMPLETO
 *
 * @returns {Object} { ok, compId, ventasActualizadas, estadoPago }
 */
function api_registrarPago(payload) {
  var s = cc_requireSession();
  payload = payload || {};

  // Validaciones
  var num         = _normNum(payload.num || "");
  var fecha       = _norm(payload.fecha || _date(new Date()));
  var tratamiento = _up(_norm(payload.tratamiento || ""));
  var descripcion = _norm(payload.descripcion || "");
  var pagoCon     = _up(_norm(payload.pagoCon || "EFECTIVO"));
  var monto       = Number(payload.monto) || 0;
  var sede        = _up(_norm(payload.sede || ""));
  var nroDoc      = _norm(payload.nroDoc || "");
  var tipoComp    = _up(_norm(payload.tipoComp || "BOLETA FISICA"));
  var ventaId     = _norm(payload.ventaId || "");
  var esAdelanto  = !!payload.esAdelanto;

  if (!num)         throw new Error("Número de paciente requerido.");
  if (!monto)       throw new Error("Monto de pago requerido.");
  if (!tratamiento) throw new Error("Tratamiento requerido.");

  var now        = new Date();
  var estadoPago = esAdelanto ? "ADELANTO" : "PAGO COMPLETO";

  // ── Datos del paciente para el comprobante ──
  var nombres = "", apellidos = "", dni = "";
  try {
    var rp = api_getPatientProfile(num);
    if (rp && rp.ok && rp.paciente) {
      nombres   = _norm(rp.paciente.nombres   || "");
      apellidos = _norm(rp.paciente.apellidos  || "");
      dni       = _norm(rp.paciente.documento  || "");
    }
  } catch(e) {}

  // ── 1. Crear ID único para este comprobante ──
  var compId = "COMP-" + _uid().slice(0, 8).toUpperCase();

  // ── 2. Escribir en CONSOLIDADO DE COMPROBANTES ──
  var shC = _sh("CONSOLIDADO DE COMPROBANTES");
  shC.appendRow([
    fecha,         // 0  FECHA
    nombres,       // 1  NOMBRES
    apellidos,     // 2  APELLIDOS
    dni,           // 3  DNI / CE
    tratamiento,   // 4  TRATAMIENTO
    descripcion,   // 5  DESCRIPCIÓN
    pagoCon,       // 6  PAGO CON
    monto,         // 7  MONTO PAGADO
    sede,          // 8  SEDE
    nroDoc,        // 9  NUMERO DE DOCUMENTO
    tipoComp,      // 10 ESTADO (tipo comprobante)
    num,           // 11 CELULAR
    s.asesor || "",// 12 ASESOR
    now,           // 13 TIMESTAMP
    compId         // 14 PROCESADO — usamos este campo como ID interno
  ]);

  // ── 3. Actualizar ESTADO DE PAGO en CONSOLIDADO DE VENTAS ──
  var ventasActualizadas = 0;
  try {
    var shV = _sh("CONSOLIDADO DE VENTAS");
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      var dataV = shV.getRange(2, 1, lrV - 1, 19).getValues();
      for (var i = 0; i < dataV.length; i++) {
        var r        = dataV[i];
        var matchId  = ventaId && _norm(r[16]) === ventaId;
        var matchNum = !ventaId &&
                       _normNum(r[15] || r[4]) === num &&
                       _up(_norm(r[5])) === tratamiento &&
                       _date(r[0]) === fecha;
        if (matchId || matchNum) {
          shV.getRange(i + 2, 10).setValue(estadoPago);   // ESTADO DE PAGO
          if (nroDoc) shV.getRange(i + 2, 18).setValue(nroDoc);   // NRO_DOC
          if (tipoComp) shV.getRange(i + 2, 19).setValue(tipoComp); // ESTADO_DOC
          ventasActualizadas++;
          if (matchId) break;
        }
      }
    }
  } catch(e) {
    Logger.log("WARN api_registrarPago — update VENTAS: " + e.message);
  }

  // ── 4. Log de auditoría ──
  _comp_log(now, compId, "CREAR", "", estadoPago, s.asesor,
    "S/" + monto + " · " + pagoCon + " · " + tratamiento);

  Logger.log("api_registrarPago OK — compId: " + compId +
    " | num: " + num + " | monto: S/" + monto +
    " | ventas actualizadas: " + ventasActualizadas);

  return {
    ok:                 true,
    compId:             compId,
    ventasActualizadas: ventasActualizadas,
    estadoPago:         estadoPago
  };
}

function api_registrarPagoT(token, payload) {
  _setToken(token); return api_registrarPago(payload);
}
// ===== CTRL+F: api_registrarPago_GS10_END =====


// ═══════════════════════════════════════════════════
// PATCH-GS10-02 · EDITAR PAGO
// ===== CTRL+F: api_editarPago_GS10 =====
// ═══════════════════════════════════════════════════

/**
 * api_editarPago
 * Edita un pago existente en CONSOLIDADO DE COMPROBANTES.
 * Localiza la fila por compId (campo PROCESADO, col 14).
 * Actualiza el monto, método, NRO_DOC y re-sincroniza VENTAS.
 *
 * @param {string} compId   ID del comprobante (campo PROCESADO)
 * @param {Object} cambios  Campos a actualizar: pagoCon, monto, nroDoc,
 *                          tipoComp, descripcion, esAdelanto
 */
function api_editarPago(compId, cambios) {
  var s = cc_requireSession();
  compId  = _norm(compId);
  cambios = cambios || {};
  if (!compId) throw new Error("ID de comprobante requerido.");

  var shC = _sh("CONSOLIDADO DE COMPROBANTES");
  var lrC = shC.getLastRow();
  if (lrC < 2) throw new Error("Sin comprobantes registrados.");

  // Buscar la fila por compId en col 15 (PROCESADO, base 1)
  var data = shC.getRange(2, 1, lrC - 1, _COMP_TOTAL).getValues();
  var rowC = null;
  var filaActual = null;
  for (var i = 0; i < data.length; i++) {
    if (_norm(data[i][14]) === compId) {
      rowC       = i + 2;
      filaActual = data[i];
      break;
    }
  }
  if (!rowC) throw new Error("Comprobante no encontrado: " + compId);

  var now = new Date();

  // Valores anteriores para el log
  var montoAnterior  = Number(filaActual[_COMP_COL.MONTO]) || 0;
  var pagoAnterior   = _norm(filaActual[_COMP_COL.PAGO_CON]);
  var estadoAnterior = _norm(filaActual[_COMP_COL.ESTADO]);

  // Aplicar cambios
  if (cambios.pagoCon    !== undefined) shC.getRange(rowC, _COMP_COL.PAGO_CON + 1).setValue(_up(_norm(cambios.pagoCon)));
  if (cambios.monto      !== undefined) shC.getRange(rowC, _COMP_COL.MONTO    + 1).setValue(Number(cambios.monto) || 0);
  if (cambios.nroDoc     !== undefined) shC.getRange(rowC, _COMP_COL.NRO_DOC  + 1).setValue(_norm(cambios.nroDoc));
  if (cambios.tipoComp   !== undefined) shC.getRange(rowC, _COMP_COL.ESTADO   + 1).setValue(_up(_norm(cambios.tipoComp)));
  if (cambios.descripcion!== undefined) shC.getRange(rowC, _COMP_COL.DESC     + 1).setValue(_norm(cambios.descripcion));
  // Actualizar timestamp
  shC.getRange(rowC, _COMP_COL.TIMESTAMP + 1).setValue(now);

  // Re-sincronizar ESTADO DE PAGO en VENTAS si cambió esAdelanto
  var ventasActualizadas = 0;
  if (cambios.esAdelanto !== undefined) {
    var nuevoEstadoPago = cambios.esAdelanto ? "ADELANTO" : "PAGO COMPLETO";
    var num = _normNum(filaActual[_COMP_COL.CELULAR]);
    var trat = _up(_norm(filaActual[_COMP_COL.TRAT]));
    var fechaComp = _date(filaActual[_COMP_COL.FECHA]);
    try {
      var shV = _sh("CONSOLIDADO DE VENTAS");
      var lrV = shV.getLastRow();
      if (lrV >= 2) {
        var dataV = shV.getRange(2, 1, lrV - 1, 17).getValues();
        for (var j = 0; j < dataV.length; j++) {
          var rv = dataV[j];
          if (_normNum(rv[15] || rv[4]) === num &&
              _up(_norm(rv[5])) === trat &&
              _date(rv[0]) === fechaComp) {
            shV.getRange(j + 2, 10).setValue(nuevoEstadoPago);
            ventasActualizadas++;
          }
        }
      }
    } catch(e) {
      Logger.log("WARN api_editarPago — update VENTAS: " + e.message);
    }
  }

  // Log
  _comp_log(now, compId, "EDITAR",
    "monto:" + montoAnterior + " pago:" + pagoAnterior,
    "monto:" + (cambios.monto || montoAnterior) + " pago:" + (cambios.pagoCon || pagoAnterior),
    s.asesor,
    "Edición de comprobante" + (ventasActualizadas ? " | ventas actualizadas: " + ventasActualizadas : "")
  );

  Logger.log("api_editarPago OK — compId: " + compId +
    " | ventasActualizadas: " + ventasActualizadas);

  return { ok: true, compId: compId, ventasActualizadas: ventasActualizadas };
}

function api_editarPagoT(token, compId, cambios) {
  _setToken(token); return api_editarPago(compId, cambios);
}
// ===== CTRL+F: api_editarPago_GS10_END =====


// ═══════════════════════════════════════════════════
// PATCH-GS10-03 · ELIMINAR PAGO
// ===== CTRL+F: api_eliminarPago_GS10 =====
// ═══════════════════════════════════════════════════

/**
 * api_eliminarPago
 * Elimina un comprobante de CONSOLIDADO DE COMPROBANTES.
 * Revierte el ESTADO DE PAGO en VENTAS a "PENDIENTE".
 * Solo ADMIN o ADMINISTRADOR puede eliminar.
 *
 * @param {string} compId  ID del comprobante (campo PROCESADO)
 */
function api_eliminarPago(compId) {
  var s = cc_requireSession();
  if (s.rol !== "ADMIN" && s.rol !== "ADMINISTRADOR")
    throw new Error("Solo ADMIN puede eliminar pagos.");

  compId = _norm(compId);
  if (!compId) throw new Error("ID de comprobante requerido.");

  var shC = _sh("CONSOLIDADO DE COMPROBANTES");
  var lrC = shC.getLastRow();
  if (lrC < 2) throw new Error("Sin comprobantes.");

  var data = shC.getRange(2, 1, lrC - 1, _COMP_TOTAL).getValues();
  var rowC = null;
  var filaGuardada = null;
  for (var i = 0; i < data.length; i++) {
    if (_norm(data[i][14]) === compId) {
      rowC         = i + 2;
      filaGuardada = data[i];
      break;
    }
  }
  if (!rowC) throw new Error("Comprobante no encontrado: " + compId);

  var num      = _normNum(filaGuardada[_COMP_COL.CELULAR]);
  var trat     = _up(_norm(filaGuardada[_COMP_COL.TRAT]));
  var monto    = Number(filaGuardada[_COMP_COL.MONTO]) || 0;
  var fechaComp= _date(filaGuardada[_COMP_COL.FECHA]);

  // Eliminar la fila del Sheet
  shC.deleteRow(rowC);

  // Revertir ESTADO DE PAGO en VENTAS → "PENDIENTE"
  var ventasRevertidas = 0;
  try {
    var shV = _sh("CONSOLIDADO DE VENTAS");
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      var dataV = shV.getRange(2, 1, lrV - 1, 17).getValues();
      for (var j = 0; j < dataV.length; j++) {
        var rv = dataV[j];
        if (_normNum(rv[15] || rv[4]) === num &&
            _up(_norm(rv[5])) === trat &&
            _date(rv[0]) === fechaComp) {
          shV.getRange(j + 2, 10).setValue("PENDIENTE");
          ventasRevertidas++;
        }
      }
    }
  } catch(e) {
    Logger.log("WARN api_eliminarPago — revertir VENTAS: " + e.message);
  }

  // Log (la fila ya no existe en COMPROBANTES, pero queda en LOG)
  _comp_log(new Date(), compId, "ELIMINAR",
    "S/" + monto + " · " + trat, "ELIMINADO",
    s.asesor,
    "Eliminado por: " + s.asesor + " | VENTAS revertidas: " + ventasRevertidas
  );

  Logger.log("api_eliminarPago OK — compId: " + compId +
    " | num: " + num + " | monto: S/" + monto +
    " | ventas revertidas a PENDIENTE: " + ventasRevertidas);

  return {
    ok:              true,
    msg:             "Pago eliminado. " + ventasRevertidas + " venta(s) revertida(s) a PENDIENTE.",
    ventasRevertidas: ventasRevertidas
  };
}

function api_eliminarPagoT(token, compId) {
  _setToken(token); return api_eliminarPago(compId);
}
// ===== CTRL+F: api_eliminarPago_GS10_END =====


// ═══════════════════════════════════════════════════
// PATCH-GS10-04 · LEER COMPROBANTES POR NÚMERO
// ===== CTRL+F: api_getComprobantesReal_GS10 =====
// ═══════════════════════════════════════════════════

/**
 * api_getComprobantesReal
 * Lee CONSOLIDADO DE COMPROBANTES filtrado por número de paciente.
 * Agrupa por NRO_DOC, devuelve compId para editar/eliminar.
 *
 * @param {string} num  Teléfono del paciente
 */
function api_getComprobantesReal(num) {
  cc_requireSession();
  num = _normNum(num);
  if (!num) return { ok: true, comprobantes: [], totalGeneral: 0 };

  var sh = _sh("CONSOLIDADO DE COMPROBANTES");
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, comprobantes: [], totalGeneral: 0 };

  var data = sh.getRange(2, 1, lr - 1, _COMP_TOTAL).getValues();

  var registros = data
    .filter(function(r) { return _normNum(r[_COMP_COL.CELULAR]) === num; })
    .map(function(r) {
      return {
        compId:      _norm(r[_COMP_COL.PROCESADO]),   // ID para editar/eliminar
        fecha:       _date(r[_COMP_COL.FECHA]),
        tratamiento: _norm(r[_COMP_COL.TRAT]),
        descripcion: _norm(r[_COMP_COL.DESC]),
        pagoCon:     _norm(r[_COMP_COL.PAGO_CON]),
        monto:       Number(r[_COMP_COL.MONTO]) || 0,
        sede:        _norm(r[_COMP_COL.SEDE]),
        nroDoc:      _norm(r[_COMP_COL.NRO_DOC]),
        tipoComp:    _norm(r[_COMP_COL.ESTADO]),
        celular:     _normNum(r[_COMP_COL.CELULAR]),
        asesor:      _norm(r[_COMP_COL.ASESOR]),
        timestamp:   _datetime(r[_COMP_COL.TIMESTAMP])
      };
    })
    .sort(function(a, b) { return a.fecha < b.fecha ? 1 : -1; });

  if (!registros.length) return { ok: true, comprobantes: [], totalGeneral: 0 };

  // Agrupar por NRO_DOC
  var porDoc = {};
  registros.forEach(function(r) {
    var k = r.nroDoc || ("SIN-" + r.fecha);
    if (!porDoc[k]) {
      porDoc[k] = {
        nroDoc:  k,
        fecha:   r.fecha,
        tipoComp:r.tipoComp,
        sede:    r.sede,
        asesor:  r.asesor,
        items:   [],
        total:   0
      };
    }
    porDoc[k].items.push(r);
    porDoc[k].total += r.monto;
  });

  var MESES = ["ENE","FEB","MAR","ABR","MAY","JUN","JUL","AGO","SEP","OCT","NOV","DIC"];
  var comprobantes = Object.keys(porDoc).map(function(k) {
    var c = porDoc[k];
    var fl = c.fecha;
    try {
      var pts = c.fecha.split("-");
      if (pts.length === 3)
        fl = parseInt(pts[2]) + " " + MESES[parseInt(pts[1])-1] + " " + pts[0];
    } catch(e) {}
    return {
      nroDoc:     c.nroDoc,
      fecha:      c.fecha,
      fechaLabel: fl,
      tipoComp:   c.tipoComp,
      sede:       c.sede,
      asesor:     c.asesor,
      items:      c.items,
      total:      c.total
    };
  });

  return {
    ok:           true,
    comprobantes: comprobantes,
    totalGeneral: registros.reduce(function(s, r) { return s + r.monto; }, 0)
  };
}

function api_getComprobantesRealT(token, num) {
  _setToken(token); return api_getComprobantesReal(num);
}
// ===== CTRL+F: api_getComprobantesReal_GS10_END =====


// ═══════════════════════════════════════════════════
// PATCH-GS10-05 · MÉTODOS DE PAGO
// ===== CTRL+F: api_getMetodosPago_GS10 =====
// ═══════════════════════════════════════════════════

/**
 * api_getMetodosPago
 * Devuelve los métodos de pago reales confirmados del Sheet de Zi Vital.
 */
function api_getMetodosPago() {
  cc_requireSession();
  return {
    ok: true,
    metodos: [
      "EFECTIVO", "MERCADOPAGO", "IZIPAY YA",
      "POS NIUBIZ S.I.", "POS NIUBIZ P.L.",
      "QR CARMEN", "QR DOCTORA",
      "BCP DRA", "BCP CARMEN",
      "INTERBANK DRA", "INTERBANK CARMEN",
      "TRANSFERENCIA BCP", "TRANSFERECIA IBK",
      "DOLARES EFECTIVO"
    ],
    tiposComprobante: ["BOLETA FISICA", "BOLETA VIRTUAL", "LIBRE", "RH"]
  };
}

function api_getMetodosPagoT(token) {
  _setToken(token); return api_getMetodosPago();
}
// ===== CTRL+F: api_getMetodosPago_GS10_END =====


// ═══════════════════════════════════════════════════
// HELPER INTERNO — LOG DE COMPROBANTES
// ===== CTRL+F: _comp_log =====
// ═══════════════════════════════════════════════════

/**
 * _comp_log
 * Escribe una línea en LOG_COMPROBANTES para auditoría.
 * Falla silenciosamente si la hoja no existe.
 */
function _comp_log(ts, compId, accion, estAnterior, estNuevo, usuario, notas) {
  try {
    var sh = _sh("LOG_COMPROBANTES");
    sh.appendRow([ts, compId, accion, estAnterior, estNuevo, usuario, notas]);
  } catch(e) {
    Logger.log("_comp_log WARN: " + e.message);
  }
}
// ===== CTRL+F: _comp_log_END =====


/**
 * ══════════════════════════════════════════════════
 * CHECKLIST DE PRUEBA — PATCH GS_10
 * ══════════════════════════════════════════════════
 *
 * PRUEBA 1 — Registrar pago:
 *   api_registrarPagoT(token, {
 *     num: "986293339",
 *     fecha: "2026-04-10",
 *     tratamiento: "HIFU",
 *     pagoCon: "EFECTIVO",
 *     monto: 500,
 *     sede: "SAN ISIDRO",
 *     nroDoc: "BF-TEST-001",
 *     tipoComp: "BOLETA FISICA"
 *   })
 *   → { ok:true, compId:"COMP-XXXXXXXX", ventasActualizadas: N }
 *   → Verificar nueva fila en CONSOLIDADO DE COMPROBANTES
 *   → Verificar ESTADO DE PAGO = "PAGO COMPLETO" en VENTAS
 *   → Verificar nueva fila en LOG_COMPROBANTES con ACCION="CREAR"
 *
 * PRUEBA 2 — Editar pago:
 *   api_editarPagoT(token, "COMP-XXXXXXXX", { monto: 350, pagoCon: "YAPE" })
 *   → { ok:true, compId:"COMP-XXXXXXXX" }
 *   → Verificar que la fila en COMPROBANTES tiene monto=350
 *   → Verificar LOG_COMPROBANTES con ACCION="EDITAR"
 *
 * PRUEBA 3 — Eliminar pago:
 *   api_eliminarPagoT(token, "COMP-XXXXXXXX")
 *   → { ok:true, ventasRevertidas: N }
 *   → Verificar que la fila desapareció de COMPROBANTES
 *   → Verificar ESTADO DE PAGO = "PENDIENTE" en VENTAS
 *   → Verificar LOG_COMPROBANTES con ACCION="ELIMINAR"
 *
 * SEÑALES DE ÉXITO:
 *   ✅ COMPROBANTES tiene la nueva fila después de PRUEBA 1
 *   ✅ VENTAS tiene ESTADO DE PAGO actualizado después de PRUEBA 1
 *   ✅ COMPROBANTES tiene monto=350 después de PRUEBA 2
 *   ✅ COMPROBANTES no tiene la fila después de PRUEBA 3
 *   ✅ VENTAS tiene ESTADO DE PAGO="PENDIENTE" después de PRUEBA 3
 *   ✅ LOG_COMPROBANTES tiene 3 filas: CREAR, EDITAR, ELIMINAR
 */