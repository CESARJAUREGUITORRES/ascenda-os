/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_13_Marketing.gs v4.2                    ║
 * ║  + subsanadas / nuncaContactadas en gestion                 ║
 * ║  + _buildTratStats filtra solo leads del mes                ║
 * ║  + historial: un forEach, asistieron, sin meses vacíos      ║
 * ║  + ventas matcheo robusto con/sin prefijo 51                ║
 * ╚══════════════════════════════════════════════════════════════╝
 */

function api_getMarketingDashboard(mes, anio) {
  cc_requireAdmin();
  var now  = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);

  var desde = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta = new Date(anio, mes, 0, 23, 59, 59);

  var leads  = da_leadsData(desde, hasta);
  var llam   = da_llamadasData(desde, hasta);
  var ventas = da_ventasData(desde, hasta);
  var invMap = da_inversionData(mes, anio, 'mes');

  var shAg = _shAgenda();
  var lrAg = shAg.getLastRow();
  var ag = lrAg >= 2
    ? shAg.getRange(2, 1, lrAg - 1, 22).getValues()
        .filter(function(r) { return _inRango(r[AG_COL.FECHA], desde, hasta); })
        .map(function(r) {
          return {
            numero: _normNum(r[AG_COL.NUMERO]),
            estado: _up(r[AG_COL.ESTADO]),
            trat:   _up(_norm(r[AG_COL.TRATAMIENTO]))
          };
        })
    : [];

  var leadNums         = {};
  var leadNumToAnuncio = {};
  var leadNumToTrat    = {};
  leads.forEach(function(l) {
    if (!l.num) return;
    leadNums[l.num]         = true;
    leadNumToAnuncio[l.num] = l.anuncio || '';
    leadNumToTrat[l.num]    = l.trat    || '';
  });

  var llamadosNums = {};
  var tipifCount   = {};
  var intentosMap  = {};
  var horaCount    = {};
  var diasContacto = [];

  llam.forEach(function(l) {
    var k = l.num;
    if (!k) return;
    var t = l.estado || 'SIN TIPIF';
    tipifCount[t] = (tipifCount[t] || 0) + 1;
    if (leadNums[k]) {
      llamadosNums[k] = true;
      intentosMap[k]  = (intentosMap[k] || 0) + 1;
    }
    var h  = _time(l.hora);
    var hh = h ? h.slice(0, 2) : '';
    if (hh) horaCount[hh] = (horaCount[hh] || 0) + 1;
  });

  leads.forEach(function(l) {
    var k = l.num;
    var primLlam = null;
    llam.forEach(function(ll) {
      if (ll.num !== k) return;
      var fd = _date(ll.fecha);
      if (!primLlam || fd < primLlam) primLlam = fd;
    });
    if (primLlam && l.fecha) {
      var d1   = new Date(_date(l.fecha) + 'T12:00:00');
      var d2   = new Date(primLlam       + 'T12:00:00');
      var diff = Math.max(0, Math.round((d2 - d1) / 86400000));
      diasContacto.push(diff);
    }
  });

  var nLeads    = leads.length;
  var nLlamados = Object.keys(llamadosNums).length;

  var citasNums = {};
  llam.forEach(function(l) {
    if (_up(l.estado) === 'CITA CONFIRMADA' && leadNums[l.num]) citasNums[l.num] = true;
  });
  var nCitas = Object.keys(citasNums).length;

  var asistNums = {};
  ag.forEach(function(a) {
    if (!leadNums[a.numero]) return;
    if (a.estado === 'ASISTIO' || a.estado === 'EFECTIVA') asistNums[a.numero] = true;
  });
  var nAsist = Object.keys(asistNums).length;

  var ventasNums = {};
  var factTotal  = 0;
  ventas.forEach(function(v) {
    var numV = _normNum(v.num || v.celular || '');
    if (!numV) return;
    var enLeads = leadNums[numV] ||
      leadNums['51' + numV] ||
      leadNums[numV.replace(/^51/, '')];
    if (enLeads) {
      ventasNums[numV] = true;
      factTotal += v.monto || 0;
    }
  });
  var nVentas = Object.keys(ventasNums).length;

  var invTotal = 0;
  try { invTotal = Object.values(invMap).reduce(function(s, v) { return s + v; }, 0); } catch(e) {}
  var roas = invTotal > 0 && factTotal > 0 ? +(factTotal / invTotal).toFixed(2) : null;
  var cac  = nVentas  > 0 && invTotal > 0  ? +(invTotal  / nVentas).toFixed(2)  : null;
  var cpl  = nLeads   > 0 && invTotal > 0  ? +(invTotal  / nLeads).toFixed(2)   : null;

  var tLlamados = nLeads    > 0 ? +(nLlamados / nLeads    * 100).toFixed(1) : 0;
  var tCitas    = nLlamados > 0 ? +(nCitas    / nLlamados * 100).toFixed(1) : 0;
  var tAsist    = nCitas    > 0 ? +(nAsist    / nCitas    * 100).toFixed(1) : 0;
  var tVentas   = nAsist    > 0 ? +(nVentas   / nAsist    * 100).toFixed(1) : 0;

  var nNC      = tipifCount['NO CONTESTA']      || 0;
  var nNI      = tipifCount['NO LE INTERESA']   || 0;
  var nDesc    = (tipifCount['SACAR DE LA BASE'] || 0) + nNI;
  var nSeg     = tipifCount['SEGUIMIENTO']      || 0;
  var nProv    = tipifCount['PROVINCIA']        || 0;
  var nSinLlam = Math.max(0, nLeads - nLlamados);
  var llamTot  = llam.length;

  var totalInt = Object.values(intentosMap).reduce(function(s, v) { return s + v; }, 0);
  var avgInt   = nLlamados > 0 ? +(totalInt / nLlamados).toFixed(1) : null;
  var avgDias  = diasContacto.length > 0
    ? +(diasContacto.reduce(function(s, v) { return s + v; }, 0) / diasContacto.length).toFixed(1)
    : null;

  var horaPico    = '—';
  var horaPicoMax = 0;
  Object.keys(horaCount).forEach(function(h) {
    if (horaCount[h] > horaPicoMax) { horaPicoMax = horaCount[h]; horaPico = h + ':00'; }
  });

  // ── SUBSANADAS: leads sin llamar del mes contactados en otro momento ──
  var todosLlamadosHistoria = {};
  try {
    var shLH = _sh(CFG.SHEET_LLAMADAS);
    var lrLH = shLH.getLastRow();
    if (lrLH >= 2) {
      shLH.getRange(2, 1, lrLH - 1, 10).getValues().forEach(function(r) {
        var n = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
        if (n) {
          todosLlamadosHistoria[n]                   = true;
          todosLlamadosHistoria['51' + n]            = true;
          todosLlamadosHistoria[n.replace(/^51/,'')] = true;
        }
      });
    }
  } catch(eH) {}

  var subsanadasCount  = 0;
  var nuncaContactadas = 0;
  leads.forEach(function(l) {
    if (!l.num || llamadosNums[l.num]) return;
    var fueContactado = todosLlamadosHistoria[l.num] ||
      todosLlamadosHistoria['51' + l.num] ||
      todosLlamadosHistoria[l.num.replace(/^51/, '')];
    if (fueContactado) { subsanadasCount++;   }
    else               { nuncaContactadas++;  }
  });
  var pctSubsanadas = nSinLlam > 0 ? Math.round(subsanadasCount  / nSinLlam * 100) : 0;
  var pctNunca      = nSinLlam > 0 ? Math.round(nuncaContactadas / nSinLlam * 100) : 0;

  var porAnuncio = _buildAnuncioStats(leads, llam, ag, ventas, invTotal, nLeads);
  var porTrat    = _buildTratStats(leads, llam, ag, ventas, invMap, invTotal, nLeads);
  var operacion  = _buildOperacionStats(llam, ventas, ag);

  var ventasLeads = ventas
    .filter(function(v) {
      var numV = _normNum(v.num || v.celular || '');
      return leadNums[numV] || leadNums['51'+numV] || leadNums[numV.replace(/^51/,'')];
    })
    .map(function(v) {
      return {
        fecha:   _date(v.fecha),
        nombre:  ((_norm(v.nombres)||'') + ' ' + (_norm(v.apellidos)||'')).trim(),
        celular: v.celular, trat: v.trat, monto: v.monto, sede: v.sede
      };
    })
    .sort(function(a, b) { return a.fecha < b.fecha ? 1 : -1; });

  var historial = _buildHistorialMeses(anio, mes, 6);

  return {
    ok: true, mes: mes, anio: anio,
    kpis: {
      leads: nLeads, llamados: nLlamados, llamadasTotal: llamTot,
      citas: nCitas, asistieron: nAsist, ventas: nVentas,
      factTotal: factTotal, invTotal: invTotal,
      roas: roas, cac: cac, cpl: cpl,
      ticketProm: nVentas > 0 ? +(factTotal / nVentas).toFixed(2) : 0
    },
    embudo: {
      leads: nLeads, llamados: nLlamados, citas: nCitas,
      asistieron: nAsist, ventas: nVentas, factTotal: factTotal,
      tasas: { llamados: tLlamados, citas: tCitas, asist: tAsist, ventas: tVentas }
    },
    gestion: {
      total:            llamTot,
      sinLlamar:        nSinLlam,
      subsanadas:       subsanadasCount,
      nuncaContactadas: nuncaContactadas,
      pctSubsanadas:    pctSubsanadas,
      pctNunca:         pctNunca,
      nc:               nNC,
      descartado:       nDesc,
      leadsTrabajados:  nLlamados,
      seguimiento:      nSeg,
      provincia:        nProv,
      avgIntentos:      avgInt,
      avgDiasContacto:  avgDias,
      asistieron:       nAsist,
      horaPico:         horaPico,
      pcts: {
        sinLlamar:   nLeads  > 0 ? Math.round(nSinLlam  / nLeads  * 100) : 0,
        nc:          llamTot > 0 ? Math.round(nNC        / llamTot * 100) : 0,
        descartado:  llamTot > 0 ? Math.round(nDesc      / llamTot * 100) : 0,
        trabajados:  nLeads  > 0 ? Math.round(nLlamados  / nLeads  * 100) : 0,
        seguimiento: llamTot > 0 ? Math.round(nSeg       / llamTot * 100) : 0,
        provincia:   llamTot > 0 ? Math.round(nProv      / llamTot * 100) : 0
      }
    },
    porAnuncio: porAnuncio, porTrat: porTrat, operacion: operacion,
    ventasLeads: ventasLeads, historial: historial
  };
}

function _buildAnuncioStats(leads, llam, ag, ventas, invTotal, nLeads) {
  var map = {};
  var add = function(k, f, n) {
    if (!k) k = '(sin anuncio)';
    if (!map[k]) map[k] = { nombre:k, leads:0, llamadas:0, citas:0, asistieron:0, ventas:0, fact:0 };
    map[k][f] = (map[k][f] || 0) + (n || 1);
  };
  var leadNums = {};
  var numToAn  = {};
  leads.forEach(function(l) {
    var an = l.anuncio || '(sin anuncio)';
    add(an, 'leads', 1);
    if (l.num) { leadNums[l.num] = true; numToAn[l.num] = an; }
  });
  llam.forEach(function(l) {
    if (!l.num || !leadNums[l.num]) return;
    var an = numToAn[l.num] || '(sin anuncio)';
    add(an, 'llamadas', 1);
    if (_up(l.estado) === 'CITA CONFIRMADA') add(an, 'citas', 1);
  });
  ag.forEach(function(a) {
    if (!leadNums[a.numero]) return;
    var an = numToAn[a.numero];
    if (!an) return;
    if (a.estado === 'ASISTIO' || a.estado === 'EFECTIVA') add(an, 'asistieron', 1);
  });
  ventas.forEach(function(v) {
    if (!leadNums[v.num]) return;
    var an = numToAn[v.num];
    if (!an) return;
    add(an, 'ventas', 1);
    add(an, 'fact', v.monto);
  });
  return Object.values(map)
    .filter(function(d) { return d.leads > 0; })
    .sort(function(a, b) { return b.leads - a.leads; })
    .slice(0, 12)
    .map(function(d) {
      var inv  = invTotal > 0 && nLeads > 0 ? +(invTotal * d.leads / nLeads).toFixed(2) : 0;
      var roas = inv > 0 && d.fact > 0 ? +(d.fact / inv).toFixed(2) : null;
      return Object.assign({}, d, {
        pctCita:  d.leads > 0 ? +(d.citas      / d.leads * 100).toFixed(1) : 0,
        pctAsist: d.citas > 0 ? +(d.asistieron / d.citas * 100).toFixed(1) : 0,
        inv: inv, roas: roas
      });
    });
}

function _buildTratStats(leads, llam, ag, ventas, invMap, invTotal, nLeads) {
  var map = {};
  var add = function(k, f, n) {
    if (!k) k = '(sin trat.)';
    if (!map[k]) map[k] = { nombre:k, leads:0, llamadas:0, citas:0, asistieron:0, ventas:0, fact:0 };
    map[k][f] = (map[k][f] || 0) + (n || 1);
  };
  var leadNums  = {};
  var numToTrat = {};
  leads.forEach(function(l) {
    var t = l.trat || '(sin trat.)';
    add(t, 'leads', 1);
    if (l.num) { leadNums[l.num] = true; numToTrat[l.num] = t; }
  });
  llam.forEach(function(l) {
    if (!l.num || !leadNums[l.num]) return;
    var t = numToTrat[l.num] || l.trat || '(sin trat.)';
    add(t, 'llamadas', 1);
    if (_up(l.estado) === 'CITA CONFIRMADA') add(t, 'citas', 1);
  });
  ag.forEach(function(a) {
    if (!leadNums[a.numero]) return;
    var t = a.trat || numToTrat[a.numero] || '(sin trat.)';
    if (a.estado === 'ASISTIO' || a.estado === 'EFECTIVA') add(t, 'asistieron', 1);
  });
  ventas.forEach(function(v) {
    var numV = _normNum(v.num || v.celular || '');
    var enLeads = leadNums[numV] || leadNums['51'+numV] || leadNums[numV.replace(/^51/,'')];
    if (!enLeads) return;
    var t = v.trat || numToTrat[numV] || '(sin trat.)';
    add(t, 'ventas', 1);
    add(t, 'fact', v.monto);
  });
  return Object.values(map)
    .filter(function(d) { return d.leads > 0 || d.ventas > 0 || d.fact > 0; })
    .sort(function(a, b) { return b.leads - a.leads; })
    .slice(0, 15)
    .map(function(d) {
      var invTrat = (invMap && invMap[d.nombre]) ||
        (invTotal > 0 && nLeads > 0 ? +(invTotal * d.leads / nLeads).toFixed(2) : 0);
      var roas = invTrat > 0 && d.fact > 0 ? +(d.fact / invTrat).toFixed(2) : null;
      var roi  = invTrat > 0 ? +((d.fact - invTrat) / invTrat * 100).toFixed(1) : null;
      return {
        nombre: d.nombre, leads: d.leads, llamadas: d.llamadas,
        citas: d.citas, asistieron: d.asistieron, ventas: d.ventas, fact: d.fact,
        pctCita:  d.leads > 0 ? +(d.citas      / d.leads * 100).toFixed(1) : 0,
        pctAsist: d.citas > 0 ? +(d.asistieron / d.citas * 100).toFixed(1) : 0,
        inv: invTrat, roas: roas, roi: roi
      };
    });
}

function _buildOperacionStats(llam, ventas, ag) {
  var map = {};
  var add = function(k, f, n) {
    if (!k || k === '') k = '(sin trat.)';
    if (!map[k]) map[k] = { nombre:k, llamadas:0, citas:0, asistieron:0, ventas:0, fact:0 };
    map[k][f] = (map[k][f] || 0) + (n || 1);
  };
  llam.forEach(function(l) {
    var t = _up(_norm(l.trat || ''));
    if (!t) return;
    add(t, 'llamadas', 1);
    if (_up(l.estado) === 'CITA CONFIRMADA') add(t, 'citas', 1);
  });
  ag.forEach(function(a) {
    if (!a.trat) return;
    if (a.estado === 'ASISTIO' || a.estado === 'EFECTIVA') add(a.trat, 'asistieron', 1);
  });
  ventas.forEach(function(v) {
    var t = _up(_norm(v.trat || ''));
    if (!t) return;
    add(t, 'ventas', 1);
    add(t, 'fact', v.monto || 0);
  });
  return Object.values(map)
    .filter(function(d) { return d.llamadas > 0 || d.ventas > 0; })
    .sort(function(a, b) { return b.llamadas - a.llamadas; })
    .slice(0, 15)
    .map(function(d) {
      return {
        nombre: d.nombre, llamadas: d.llamadas, citas: d.citas,
        asistieron: d.asistieron, ventas: d.ventas, fact: d.fact,
        pctCita: d.llamadas > 0 ? +(d.citas  / d.llamadas * 100).toFixed(1) : 0,
        conv:    d.llamadas > 0 ? +(d.ventas / d.llamadas * 100).toFixed(1) : 0
      };
    });
}

/**
 * PATCH GS_13_Marketing.gs
 * ════════════════════════════════════════════════════════
 * PROBLEMA: _buildHistorialMeses muestra llamados = total llamadas del mes
 *           (ej: 1387) en vez de leads únicos contactados (ej: 50)
 *
 * FIX: Cruzar llamadas con leads del mes para contar
 *      solo leads únicos que recibieron al menos 1 llamada
 *
 * INSTRUCCIÓN:
 * Ctrl+F en GS_13_Marketing.gs: "function _buildHistorialMeses"
 * Selecciona desde esa línea hasta el "}" de cierre (antes de la línea vacía)
 * Reemplaza con el bloque de abajo
 * ════════════════════════════════════════════════════════
 */

// ===== CTRL+F: function _buildHistorialMeses =====
function _buildHistorialMeses(anio, mesActual, n) {
  var hist = [];
  var now  = new Date();

  for (var i = 0; i < n; i++) {
    var m = mesActual - i;
    var a = anio;
    if (m <= 0) { m += 12; a--; }

    var esFuturo = (a > now.getFullYear()) ||
      (a === now.getFullYear() && m > now.getMonth() + 1);
    if (esFuturo) continue;

    var desde2 = new Date(a, m - 1, 1, 0, 0, 0);
    var hasta2 = new Date(a, m,     0, 23, 59, 59);

    var llds = da_leadsData(desde2, hasta2);
    var llms = da_llamadasData(desde2, hasta2);
    var vcs  = da_ventasData(desde2, hasta2);

    if (llds.length === 0 && llms.length === 0 && vcs.length === 0) continue;

    // ── FIX: contar leads únicos contactados en el mes ──
    // Construir índice de leads del mes
    var leadNumsMes = {};
    llds.forEach(function(l) {
      if (l.num) {
        leadNumsMes[l.num] = true;
        leadNumsMes['51' + l.num] = true;
        leadNumsMes[l.num.replace(/^51/, '')] = true;
      }
    });

    // Contar leads únicos que recibieron al menos 1 llamada
    var llamadosSet = {};
    llms.forEach(function(ll) {
      if (!ll.num) return;
      var esLead = leadNumsMes[ll.num] ||
        leadNumsMes['51' + ll.num] ||
        leadNumsMes[ll.num.replace(/^51/, '')];
      if (esLead) llamadosSet[ll.num] = true;
    });
    var nLlamados = Object.keys(llamadosSet).length;

    // Ventas que son de leads del mes
    var ventasLeadsMes = 0;
    var factLeadsMes   = 0;
    vcs.forEach(function(v) {
      var numV = v.num || '';
      var esLead = leadNumsMes[numV] ||
        leadNumsMes['51' + numV] ||
        leadNumsMes[numV.replace(/^51/, '')];
      if (esLead) {
        ventasLeadsMes++;
        factLeadsMes += v.monto || 0;
      }
    });

    // Citas y asistidos del mes
    var shAg2 = _shAgenda();
    var lrAg2 = shAg2.getLastRow();
    var nC    = 0;
    var nAs   = 0;
    if (lrAg2 >= 2) {
      shAg2.getRange(2, 1, lrAg2 - 1, 14).getValues().forEach(function(r) {
        if (!_inRango(r[AG_COL.FECHA], desde2, hasta2)) return;
        var est = _up(r[AG_COL.ESTADO]);
        if (est !== 'CANCELADA') nC++;
        if (est === 'ASISTIO' || est === 'EFECTIVA') nAs++;
      });
    }

    // Facturación total del mes (todas las ventas, no solo leads)
    var fVTotal = vcs.reduce(function(s, v) { return s + v.monto; }, 0);

    hist.push({
      mes:        m,
      anio:       a,
      mesNom:     MESES_ES[m].slice(0, 3),
      leads:      llds.length,
      llamados:   nLlamados,      // ← FIX: leads únicos contactados
      citas:      nC,
      asistieron: nAs,
      ventas:     vcs.length,     // total ventas del mes
      fact:       fVTotal,        // facturación total del mes
      conv:       llds.length > 0 ? +(vcs.length / llds.length * 100).toFixed(1) : 0
    });
  }

  return hist.reverse();
}

function api_getMarketingDashboardT(token, mes, anio) {
  _setToken(token); return api_getMarketingDashboard(mes, anio);
}

function api_getAdminCallsPanel(mes, anio, asesor) {
  cc_requireAdmin();
  var now = new Date();
  anio = Number(anio) || now.getFullYear();
  mes  = Number(mes)  || (now.getMonth() + 1);
  var desde    = new Date(anio, mes - 1, 1, 0, 0, 0);
  var hasta    = new Date(anio, mes,     0, 23, 59, 59);
  var asesorUp = _up(asesor || '');
  var items = da_llamadasData(desde, hasta)
    .filter(function(l) { return !asesorUp || _up(l.asesor) === asesorUp; })
    .map(function(l) {
      return {
        fecha: _date(l.fecha), hora: _time(l.hora), asesor: _up(l.asesor),
        num: l.num, trat: l.trat, estado: l.estado, intento: l.intento || 1
      };
    })
    .sort(function(a, b) { return (a.fecha+a.hora) < (b.fecha+b.hora) ? 1 : -1; });
  var total = items.length;
  var citas = items.filter(function(x) { return x.estado === 'CITA CONFIRMADA'; }).length;
  var nc    = items.filter(function(x) { return x.estado === 'NO CONTESTA'; }).length;
  var seg   = items.filter(function(x) { return x.estado === 'SEGUIMIENTO'; }).length;
  var porAsesor = {};
  items.forEach(function(x) {
    var aa = x.asesor || 'SIN ASESOR';
    if (!porAsesor[aa]) porAsesor[aa] = { total:0, citas:0, nc:0 };
    porAsesor[aa].total++;
    if (x.estado === 'CITA CONFIRMADA') porAsesor[aa].citas++;
    if (x.estado === 'NO CONTESTA')     porAsesor[aa].nc++;
  });
  return {
    ok: true, mes: mes, anio: anio, items: items.slice(0, 200),
    kpis: { total:total, citas:citas, nc:nc, seg:seg,
      conv: total > 0 ? +(citas/total*100).toFixed(1) : 0 },
    porAsesor: porAsesor
  };
}
function api_getAdminCallsPanelT(token, mes, anio, asesor) {
  _setToken(token); return api_getAdminCallsPanel(mes, anio, asesor);
}

function test_Marketing() {
  Logger.log('=== GS_13_Marketing v4.2 OK ===');
}