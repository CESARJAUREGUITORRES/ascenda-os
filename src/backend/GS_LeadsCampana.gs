// ══════════════════════════════════════════════════════════
// GS_06 PARCHE — api_getLeadsCampanaMesT
// Cruza LEADS + LLAMADAS + VENTAS para calcular métricas
// de leads nuevos del mes (campaña) vs base anterior
// ══════════════════════════════════════════════════════════
// Buscar con Ctrl+F: api_getLeadsCampanaMesT

/**
 * Retorna métricas de Leads de Campaña del período:
 * - leadsNuevos:    leads cuya fecha de ingreso cae en el período
 * - leadsLlamados:  de esos leads, cuántos fueron llamados (número único)
 * - leadsCitas:     de esos leads, cuántos tuvieron CITA CONFIRMADA
 * - leadsVentas:    de esos leads, cuántos tienen venta en el período
 * - leadsFact:      facturación total de esos leads
 * - clientesUnicos: números únicos llamados en el período (sin importar de dónde)
 * - clientesUnicosCamp: números únicos llamados que son leads nuevos
 */
function api_getLeadsCampanaMesT(token, mes, anio) {
  _setToken(token);
  cc_requireSession();

  var now = new Date();
  mes  = mes  || (now.getMonth() + 1);
  anio = anio || now.getFullYear();

  // Rango del período
  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta  = new Date(anio, mes,    0, 23, 59, 59);

  // ── 1. Leer hoja de LEADS: columnas relevantes ────────
  // Buscamos leads cuya fecha de ingreso esté dentro del período
  var leadsNuevosPorNum = {};   // num → fecha_ingreso
  try {
    var shL = SpreadsheetApp.openById(SHEET_ID).getSheetByName(HOJA_LEADS);
    if (shL) {
      var lrL = shL.getLastRow();
      if (lrL >= 2) {
        // Columna A = fecha ingreso, columna que tenga el número limpio
        // Ajustar índices según la estructura real del sheet
        var dataL = shL.getRange(2, 1, lrL - 1, 20).getValues();
        dataL.forEach(function(r) {
          var fechaIn = r[LEADS_COL.FECHA_INGRESO] || r[0];
          var numLimpio = _numLimpio(r[LEADS_COL.NUM_LIMPIO] || r[LEADS_COL.TELEFONO] || r[3]);
          if (!numLimpio) return;
          if (_inRango(fechaIn, desde, hasta)) {
            leadsNuevosPorNum[numLimpio] = fechaIn;
          }
        });
      }
    }
  } catch(e) {
    Logger.log('api_getLeadsCampanaMesT LEADS: ' + e.message);
  }

  var totalLeads = Object.keys(leadsNuevosPorNum).length;

  // ── 2. Leer LLAMADAS del período ──────────────────────
  var llamadasPorNum = {};     // num → {count, estados}
  var numericosUnicos = {};    // todos los números llamados en el período
  try {
    var shC = _shLlamadas();
    var lrC = shC.getLastRow();
    if (lrC >= 2) {
      var asesorActual = cc_getSession().idAsesor || cc_getSession().nombre;
      var dataC = shC.getRange(2, 1, lrC - 1, 20).getValues();
      dataC.forEach(function(r) {
        var fechaLl  = r[LLAM_COL.FECHA] || r[0];
        var asesor   = _up(r[LLAM_COL.ASESOR] || r[2]);
        var num      = _numLimpio(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.TELEFONO] || r[1]);
        var estado   = _up(r[LLAM_COL.ESTADO] || r[5]);
        if (!num || !_inRango(fechaLl, desde, hasta)) return;
        if (asesor && asesorActual && asesor !== asesorActual.toUpperCase()) return;
        // Contar para totales
        if (!numericosUnicos[num]) numericosUnicos[num] = [];
        numericosUnicos[num].push(estado);
        // Contar para leads de campaña
        if (leadsNuevosPorNum[num]) {
          if (!llamadasPorNum[num]) llamadasPorNum[num] = { count: 0, estados: [] };
          llamadasPorNum[num].count++;
          llamadasPorNum[num].estados.push(estado);
        }
      });
    }
  } catch(e) {
    Logger.log('api_getLeadsCampanaMesT LLAMADAS: ' + e.message);
  }

  var leadsLlamados = Object.keys(llamadasPorNum).length;
  var clientesUnicos = Object.keys(numericosUnicos).length;
  var clientesUnicosCamp = leadsLlamados;

  // Citas de leads de campaña
  var leadsCitas = Object.keys(llamadasPorNum).filter(function(num) {
    return llamadasPorNum[num].estados.some(function(e) {
      return e === 'CITA CONFIRMADA' || e === 'CITA';
    });
  }).length;

  // ── 3. Cruzar con VENTAS del período ─────────────────
  var leadsVentas = 0;
  var leadsFact   = 0;
  try {
    var shV = _shVentas();
    var lrV = shV.getLastRow();
    if (lrV >= 2) {
      var dataV = shV.getRange(2, 1, lrV - 1, 20).getValues();
      dataV.forEach(function(r) {
        var fechaV  = r[VTAS_COL.FECHA] || r[0];
        var num     = _numLimpio(r[VTAS_COL.NUM_LIMPIO] || r[VTAS_COL.TELEFONO] || r[3]);
        var monto   = parseFloat(r[VTAS_COL.MONTO] || r[7]) || 0;
        if (!num || !_inRango(fechaV, desde, hasta)) return;
        if (leadsNuevosPorNum[num]) {
          leadsVentas++;
          leadsFact += monto;
        }
      });
    }
  } catch(e) {
    Logger.log('api_getLeadsCampanaMesT VENTAS: ' + e.message);
  }

  return {
    ok:               true,
    mes:              mes,
    anio:             anio,
    leadsNuevos:      totalLeads,
    leadsLlamados:    leadsLlamados,
    pctLlamados:      totalLeads > 0 ? Math.round(leadsLlamados / totalLeads * 100) : 0,
    leadsCitas:       leadsCitas,
    leadsVentas:      leadsVentas,
    leadsFact:        leadsFact,
    clientesUnicos:   clientesUnicos,
    clientesUnicosCamp: clientesUnicosCamp
  };
}

// Helper: normalizar número a dígitos
function _numLimpio(val) {
  if (!val) return '';
  return String(val).replace(/[^0-9]/g, '');
}