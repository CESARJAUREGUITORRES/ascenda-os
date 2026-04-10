/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_22_AdminCalls.gs                        ║
 * ║  Módulo: Panel Maestro de Llamadas — Admin                  ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01–05, GS_06, GS_12                      ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · KPIs globales filtrados (día/mes/año/rango)
 *   MOD-02 · Monitoreo equipo + progreso por hora
 *   MOD-03 · Score de números por estado
 *   MOD-04 · Embudo de conversión
 *   MOD-05 · Bases por campaña (agrupado por LEAD_COL.TRAT)
 *   MOD-06 · Histórico anual + pico horario óptimo
 *   MOD-07 · Base sin llamar con semáforo por días
 *   MOD-08 · Lógica madre — cola priorizada con ficha contextual
 *   MOD-09 · Distribuciones por asesor (PropertiesService)
 *
 * NOTAS ARQUITECTÓNICAS:
 *   - CAMPAÑA = LEAD_COL.TRAT (col C de LEADS) = LLAM_COL.TRATAMIENTO
 *   - SERVICIO CLÍNICO = VENT_COL.TRATAMIENTO (diferente semántica)
 *   - Lógica anti-duplicado: CacheService.getScriptCache() con TTL diario
 *   - Distribuciones: PropertiesService clave DIST_CONFIG_[ASESOR_NORM]
 *   - Ficha contextual: cruza AGENDA + VENTAS + LLAMADAS por NUM_LIMPIO
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · KPIs GLOBALES FILTRADOS
// ══════════════════════════════════════════════════════════════
// AC01_START

/**
 * Construye el rango de fechas según el filtro seleccionado.
 * @param {string} modo  "dia" | "mes" | "anio" | "rango"
 * @param {string} desde  yyyy-MM-dd (solo para modo "rango")
 * @param {string} hasta  yyyy-MM-dd (solo para modo "rango")
 */
function _ac_buildFiltro(modo, desde, hasta) {
  var now  = new Date();
  var anio = now.getFullYear();
  var mes  = now.getMonth();
  var dia  = now.getDate();

  switch (_low(modo || 'mes')) {
    case 'dia':
      return {
        desde: new Date(anio, mes, dia, 0, 0, 0),
        hasta: new Date(anio, mes, dia, 23, 59, 59),
        label: 'Hoy'
      };
    case 'anio':
      return {
        desde: new Date(anio, 0, 1, 0, 0, 0),
        hasta: new Date(anio, 11, 31, 23, 59, 59),
        label: String(anio)
      };
    case 'rango':
      var d = desde ? new Date(desde + 'T00:00:00') : new Date(anio, mes, 1);
      var h = hasta  ? new Date(hasta  + 'T23:59:59') : new Date();
      return { desde: d, hasta: h, label: desde + ' al ' + hasta };
    default: // mes
      return {
        desde: new Date(anio, mes, 1, 0, 0, 0),
        hasta: new Date(anio, mes + 1, 0, 23, 59, 59),
        label: 'Este mes'
      };
  }
}

// ===== CTRL+F: api_getAdminCallsKpisT =====
/**
 * KPIs del panel de llamadas v2.0 — nueva batería.
 * KPI 1: Llamadas totales del período (filtrable por asesor)
 * KPI 2: Vírgenes históricos (global, nunca llamados, no filtra)
 * KPI 3: Leads contactados / total del período (fracción)
 * KPI 4: Citas agendadas — fuente: AGENDA_CITAS.TS_CREADO
 * KPI 5: Asistidos — citas con ESTADO=ASISTIO/EFECTIVA
 * KPI 6: Facturación call center — ventas donde ASESOR != vacío
 * @param {string} asesorNom  Nombre asesor o "" para equipo completo
 */
function api_getAdminCallsKpisT(token, modo, desde, hasta, asesorNom) {
  _setToken(token);
  cc_requireAdmin();

  var filtro  = _ac_buildFiltro(modo, desde, hasta);
  var desdeF  = filtro.desde;
  var hastaF  = filtro.hasta;
  var now     = new Date();
  var aseF    = asesorNom ? _up(asesorNom) : '';
  var anio    = now.getFullYear();

  // ── 1. Llamadas totales del período (filtrable por asesor) ──
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lrL = shL.getLastRow();
  var totalLlamadas = 0;
  var llamTodos = {}; // para vírgenes: todos los nums llamados alguna vez

  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 11).getValues().forEach(function(r) {
      var num = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      if (num) llamTodos[num] = true;
      if (aseF && _up(_norm(r[LLAM_COL.ASESOR])) !== aseF) return;
      if (_inRango(r[LLAM_COL.FECHA], desdeF, hastaF)) totalLlamadas++;
    });
  }

  // ── 2. Vírgenes históricos — global, no filtra por asesor ───
  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  var virgenesHistoricos = 0;
  var leadsDelPeriodo = {}; // num → true (para KPI 3)
  var totalLeadsPeriodo = 0;

  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
      var num  = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
      var hora = r[LEAD_COL.HORA] || r[LEAD_COL.FECHA];
      if (!num) return;
      // Vírgenes: nunca llamados en toda la historia
      if (!llamTodos[num]) virgenesHistoricos++;
      // Leads del período para KPI 3
      if (_inRango(hora, desdeF, hastaF)) {
        leadsDelPeriodo[num] = true;
        totalLeadsPeriodo++;
      }
    });
  }

  // ── 3. Leads contactados del período (fracción) ─────────────
  // De los leads que llegaron en el período, cuántos recibieron
  // al menos una llamada del asesor filtrado (o de cualquiera si global)
  var leadsContactados = 0;
  if (lrL >= 2) {
    var contactadosSet = {};
    shL.getRange(2, 1, lrL - 1, 11).getValues().forEach(function(r) {
      var num = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      if (!num || !leadsDelPeriodo[num] || contactadosSet[num]) return;
      if (aseF && _up(_norm(r[LLAM_COL.ASESOR])) !== aseF) return;
      if (_inRango(r[LLAM_COL.FECHA], desdeF, hastaF)) {
        contactadosSet[num] = true;
        leadsContactados++;
      }
    });
  }

  // ── 4. Citas agendadas — fuente: AGENDA_CITAS.TS_CREADO ─────
  var shA = _shAgenda();
  var lrA = shA.getLastRow();
  var citasAgendadas = 0;
  var citasAsistidas = 0;

  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 17).getValues().forEach(function(r) {
      var est = _up(r[AG_COL.ESTADO]);
      if (est === 'CANCELADA') return;
      if (aseF) {
        var aseAgenda = _up(_norm(r[AG_COL.ASESOR]));
        var idAgenda  = _norm(r[AG_COL.ID_ASESOR]);
        if (aseAgenda !== aseF) return;
      }
      var tsCreado = r[AG_COL.TS_CREADO] || r[AG_COL.FECHA];
      if (!_inRango(tsCreado, desdeF, hastaF)) return;
      citasAgendadas++;
      if (est === 'ASISTIO' || est === 'EFECTIVA') citasAsistidas++;
    });
  }

  // ── 5+6. Facturación call center ────────────────────────────
  // Ventas donde ASESOR no está vacío (atribuibles al call center)
  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  var factCallCenter = 0;
  var ventasCallCenter = 0;

  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 11).getValues().forEach(function(r) {
      if (!_inRango(r[VENT_COL.FECHA], desdeF, hastaF)) return;
      var aseVenta = _up(_norm(r[VENT_COL.ASESOR] || ''));
      if (!aseVenta) return; // sin asesor = no atribuible al call center
      if (aseF && aseVenta !== aseF) return;
      ventasCallCenter++;
      factCallCenter += Number(r[VENT_COL.MONTO]) || 0;
    });
  }

  var pctContactados = totalLeadsPeriodo > 0
    ? Math.round(leadsContactados / totalLeadsPeriodo * 100) : 0;
  var pctAsistencia  = citasAgendadas > 0
    ? Math.round(citasAsistidas / citasAgendadas * 100) : 0;

  return {
    ok: true,
    filtro:  { modo: modo || 'mes', label: filtro.label },
    asesor:  asesorNom || '',
    kpis: {
      // KPI 1
      totalLlamadas:      totalLlamadas,
      // KPI 2
      virgenesHistoricos: virgenesHistoricos,
      // KPI 3
      leadsContactados:   leadsContactados,
      totalLeadsPeriodo:  totalLeadsPeriodo,
      pctContactados:     pctContactados,
      // KPI 4
      citasAgendadas:     citasAgendadas,
      // KPI 5
      citasAsistidas:     citasAsistidas,
      pctAsistencia:      pctAsistencia,
      // KPI 6
      ventasCallCenter:   ventasCallCenter,
      factCallCenter:     Math.round(factCallCenter)
    }
  };
}
// AC01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · MONITOREO EQUIPO + PROGRESO POR HORA
// ══════════════════════════════════════════════════════════════
// AC02_START

// ===== CTRL+F: api_getMonitoreoEquipoT =====
/**
 * Retorna el estado tiempo real del equipo (igual que Home Admin)
 * más datos de progreso por hora filtrable por asesor.
 * Reutiliza api_getTeamSemaforo() de GS_12.
 */
function api_getMonitoreoEquipoT(token) {
  _setToken(token);
  cc_requireAdmin();
  // Reusar el semáforo ya existente en GS_12
  return api_getTeamSemaforo();
}

// ===== CTRL+F: api_getProgresoPorHoraT =====
/**
 * Progreso de llamadas y citas agrupado por hora del día.
 * Solo devuelve horas con datos o en curso.
 * @param {string} asesor  nombre del asesor o "todos"
 * @param {string} modo    "dia" | "mes" | "anio" | "rango"
 */
function api_getProgresoPorHoraT(token, asesor, modo, desde, hasta) {
  _setToken(token);
  cc_requireAdmin();

  var filtro = _ac_buildFiltro(modo || 'dia', desde, hasta);
  var shL    = _sh(CFG.SHEET_LLAMADAS);
  var lrL    = shL.getLastRow();
  if (lrL < 2) return { ok: true, horas: [], picoHora: null };

  var filtroAsesor = _up(asesor || 'todos');
  var byHora = {}; // "HH" → { llamadas, citas }

  shL.getRange(2, 1, lrL - 1, 7).getValues().forEach(function(r) {
    if (!_inRango(r[LLAM_COL.FECHA], filtro.desde, filtro.hasta)) return;
    var nomAsesor = _up(_norm(r[LLAM_COL.ASESOR]));
    if (filtroAsesor !== 'TODOS' && nomAsesor !== filtroAsesor) return;

    var horaRaw = r[LLAM_COL.HORA];
    var hh = '';
    try {
      var horaObj = horaRaw instanceof Date ? horaRaw : new Date(horaRaw);
      if (!isNaN(horaObj.getTime())) {
        hh = String(horaObj.getHours()).padStart(2, '0');
      }
    } catch(e) {}
    if (!hh) return;

    if (!byHora[hh]) byHora[hh] = { hora: hh + ':00', llamadas: 0, citas: 0 };
    byHora[hh].llamadas++;
    if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') byHora[hh].citas++;
  });

  var horaActual = new Date().getHours();
  var resultado = Object.keys(byHora)
    .sort(function(a, b) { return Number(b) - Number(a); }) // desc: más reciente primero
    .map(function(hh) {
      var item = byHora[hh];
      var conv = item.llamadas > 0 ? Math.round(item.citas / item.llamadas * 100) : 0;
      return {
        hora:     item.hora,
        horaNum:  Number(hh),
        llamadas: item.llamadas,
        citas:    item.citas,
        conv:     conv,
        enCurso:  Number(hh) === horaActual
      };
    });

  // Pico: hora con mayor conv% (mínimo 5 llamadas para ser válida)
  var picoHora = null;
  var maxConv  = 0;
  resultado.forEach(function(h) {
    if (h.llamadas >= 5 && h.conv > maxConv) {
      maxConv  = h.conv;
      picoHora = h.hora;
    }
  });

  return { ok: true, horas: resultado, picoHora: picoHora, asesor: asesor || 'todos' };
}
// AC02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · SCORE DE NÚMEROS POR ESTADO
// ══════════════════════════════════════════════════════════════
// AC03_START

// ===== CTRL+F: api_getScoreNumerosT =====
/**
 * Clasifica todos los leads en: activos, sinContacto, provincia,
 * retirados, inactivos, virgenes.
 * Filtrable por período (afecta qué leads se consideran).
 */
function api_getScoreNumerosT(token, modo, desde, hasta) {
  _setToken(token);
  cc_requireAdmin();

  var filtro = _ac_buildFiltro(modo || 'anio', desde, hasta);
  var shLd   = _sh(CFG.SHEET_LEADS);
  var lrLd   = shLd.getLastRow();
  var shL    = _sh(CFG.SHEET_LLAMADAS);
  var lrL    = shL.getLastRow();

  // Leer último estado por número en LLAMADAS
  var ultimoEstado = {}; // num → { estado, subEstado }
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 21).getValues().forEach(function(r) {
      var num  = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      var ts   = r[LLAM_COL.ULT_TS] ? new Date(r[LLAM_COL.ULT_TS]) : null;
      if (!num) return;
      if (!ultimoEstado[num] || (ts && ts > ultimoEstado[num].ts)) {
        ultimoEstado[num] = {
          estado:    _up(r[LLAM_COL.ESTADO]),
          subEstado: _norm(r[LLAM_COL.SUB_ESTADO] || ''),
          ts:        ts
        };
      }
    });
  }

  var score = { activos: 0, sinContacto: 0, provincia: 0, retirados: 0, inactivos: 0, virgenes: 0 };
  var vistos = {};

  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
      var num  = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
      var hora = r[LEAD_COL.HORA] || r[LEAD_COL.FECHA];
      if (!num || vistos[num]) return;
      if (!_inRango(hora, filtro.desde, filtro.hasta)) return;
      vistos[num] = true;

      var ult = ultimoEstado[num];
      if (!ult) {
        score.virgenes++;
        return;
      }

      var est = ult.estado;
      if (est === 'SACAR DE LA BASE') {
        score.retirados++;
      } else if (est === 'PROVINCIA' || est === 'PROVINCIAS') {
        score.provincia++;
      } else if (est === 'SIN CONTACTO' || est === 'NO CONTESTA') {
        score.sinContacto++;
      } else if (est === 'NO LE INTERESA' || est === 'NO INTERESA') {
        score.inactivos++;
      } else if (est === 'CITA CONFIRMADA' || est === 'SEGUIMIENTO') {
        score.activos++;
      } else {
        // Cualquier otro estado con registro = activo
        score.activos++;
      }
    });
  }

  var total = score.activos + score.sinContacto + score.provincia +
              score.retirados + score.inactivos + score.virgenes;

  return {
    ok: true,
    score: score,
    total: total,
    pcts: {
      activos:    total > 0 ? Math.round(score.activos    / total * 100) : 0,
      sinContacto:total > 0 ? Math.round(score.sinContacto/ total * 100) : 0,
      virgenes:   total > 0 ? Math.round(score.virgenes   / total * 100) : 0
    }
  };
}
// AC03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · EMBUDO DE CONVERSIÓN
// ══════════════════════════════════════════════════════════════
// AC04_START

// ===== CTRL+F: api_getEmbudoConversionT =====
/**
 * Embudo: total llamadas → citas agendadas → asistidos → ventas → facturación.
 * Incluye delta vs período anterior.
 */
function api_getEmbudoConversionT(token, modo, desde, hasta, asesorNom) {
  _setToken(token);
  cc_requireAdmin();

  var filtro = _ac_buildFiltro(modo || 'mes', desde, hasta);
  var df = filtro.desde, hf = filtro.hasta;

  // Calcular período anterior (misma duración, inmediatamente antes)
  var durMs  = hf.getTime() - df.getTime();
  var dfPrev = new Date(df.getTime() - durMs - 1);
  var hfPrev = new Date(df.getTime() - 1);

  // ── Llamadas (filtrable por asesor) ──────────────────────
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lrL = shL.getLastRow();
  var totalLlamadas = 0, prevLlamadas = 0;
  var filtroAse = asesorNom ? _up(asesorNom) : '';
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 11).getValues().forEach(function(r) {
      if (filtroAse && _up(_norm(r[LLAM_COL.ASESOR])) !== filtroAse) return;
      if (_inRango(r[0], df,     hf))     totalLlamadas++;
      if (_inRango(r[0], dfPrev, hfPrev)) prevLlamadas++;
    });
  }

  // ── Citas agendadas ───────────────────────────────────────
  // FIX: Contar por TS_CREADO (cuándo se confirmó la cita en el período),
  // NO por AG_COL.FECHA (fecha futura de la cita). Así "citas del mes" =
  // citas confirmadas/creadas durante ese mes, independientemente de
  // cuándo está agendada la visita.
  var shA = _shAgenda();
  var lrA = shA.getLastRow();
  var totalCitas = 0, totalAsistidos = 0, prevCitas = 0;
  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 17).getValues().forEach(function(r) {
      if (filtroAse && _up(_norm(r[AG_COL.ASESOR])) !== filtroAse) return;
      var est    = _up(r[AG_COL.ESTADO]);
      if (est === 'CANCELADA') return;
      // Usar TS_CREADO (col P, índice 15) si existe, si no caer a FECHA
      var tsCreado = r[AG_COL.TS_CREADO] || r[AG_COL.FECHA];
      if (_inRango(tsCreado, df, hf)) {
        totalCitas++;
        if (est === 'ASISTIO' || est === 'EFECTIVA') totalAsistidos++;
      }
      if (_inRango(tsCreado, dfPrev, hfPrev)) prevCitas++;
    });
  }

  // ── Ventas ────────────────────────────────────────────────
  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  var totalVentas = 0, totalFact = 0, prevVentas = 0;
  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 11).getValues().forEach(function(r) {
      if (filtroAse && _up(_norm(r[VENT_COL.ASESOR])) !== filtroAse) return;
      if (_inRango(r[VENT_COL.FECHA], df, hf)) {
        totalVentas++;
        totalFact += Number(r[VENT_COL.MONTO]) || 0;
      }
      if (_inRango(r[VENT_COL.FECHA], dfPrev, hfPrev)) prevVentas++;
    });
  }

  function _delta(actual, prev) {
    if (!prev || prev === 0) return null;
    return Math.round((actual - prev) / prev * 100);
  }

  return {
    ok: true,
    filtro: filtro.label,
    embudo: [
      { label: 'Llamadas',    valor: totalLlamadas, delta: _delta(totalLlamadas, prevLlamadas), pct: 100 },
      { label: 'Citas',       valor: totalCitas,    delta: _delta(totalCitas, prevCitas),
        pct: totalLlamadas > 0 ? Math.round(totalCitas / totalLlamadas * 100) : 0 },
      { label: 'Asistidos',   valor: totalAsistidos, delta: null,
        pct: totalCitas > 0 ? Math.round(totalAsistidos / totalCitas * 100) : 0 },
      { label: 'Ventas',      valor: totalVentas,   delta: _delta(totalVentas, prevVentas),
        pct: totalAsistidos > 0 ? Math.round(totalVentas / totalAsistidos * 100) : 0 },
      { label: 'Facturado',   valor: totalFact,     delta: null,
        pct: totalVentas > 0 ? Math.round(totalFact / totalVentas) : 0,
        esMonto: true }
    ]
  };
}
// AC04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · BASES POR CAMPAÑA
// ══════════════════════════════════════════════════════════════
// AC05_START

// ===== CTRL+F: api_getBasesCampanasT =====
/**
 * Agrupa leads por campaña (LEAD_COL.TRAT).
 * Para cada campaña: nº contactos, último día actualización,
 * facturación acumulada, días de inactividad, semáforo.
 */
function api_getBasesCampanasT(token) {
  _setToken(token);
  cc_requireAdmin();

  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  if (lrLd < 2) return { ok: true, bases: [] };

  // ── 1. Agrupar leads por campaña ─────────────────────────
  var campanas = {}; // campNorm → { nombre, numeros, ultIngreso }
  shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
    var num   = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
    var camp  = _up(_norm(r[LEAD_COL.TRAT] || ''));
    var hora  = r[LEAD_COL.HORA] || r[LEAD_COL.FECHA];
    if (!num || !camp) return;
    if (!campanas[camp]) campanas[camp] = { nombre: camp, numeros: {}, ultIngreso: null };
    campanas[camp].numeros[num] = true;
    var d = hora ? new Date(hora) : null;
    if (d && !isNaN(d) && (!campanas[camp].ultIngreso || d > campanas[camp].ultIngreso)) {
      campanas[camp].ultIngreso = d;
    }
  });

  // ── 2. Cruzar con ventas para facturación ─────────────────
  var shV  = _sh(CFG.SHEET_VENTAS);
  var lrV  = shV.getLastRow();
  var ventPorNum = {}; // num → acum monto
  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 16).getValues().forEach(function(r) {
      var num   = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
      var monto = Number(r[VENT_COL.MONTO]) || 0;
      if (num) ventPorNum[num] = (ventPorNum[num] || 0) + monto;
    });
  }

  // ── 3. Cruzar con llamadas (fecha última llamada por campaña) ─
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lrL = shL.getLastRow();
  var ultLlamPorCamp = {}; // campNorm → Date
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 6).getValues().forEach(function(r) {
      var camp = _up(_norm(r[LLAM_COL.TRATAMIENTO] || ''));
      var hora = r[LLAM_COL.HORA];
      if (!camp || !hora) return;
      var d = new Date(hora);
      if (!isNaN(d) && (!ultLlamPorCamp[camp] || d > ultLlamPorCamp[camp])) {
        ultLlamPorCamp[camp] = d;
      }
    });
  }

  var now = new Date();
  var bases = Object.keys(campanas).map(function(camp) {
    var c         = campanas[camp];
    var numList   = Object.keys(c.numeros);
    var factCamp  = numList.reduce(function(s, n) { return s + (ventPorNum[n] || 0); }, 0);
    var ultLlam   = ultLlamPorCamp[camp];
    var ultAct    = c.ultIngreso;
    var diasInact = ultLlam ? Math.floor((now - ultLlam) / 86400000) : null;
    var semaforo  = diasInact === null ? 'gris' :
                    diasInact <= 2     ? 'verde' :
                    diasInact <= 7     ? 'amarillo' : 'rojo';

    return {
      nombre:     c.nombre,
      contactos:  numList.length,
      ultActualizacion: ultAct ? _date(ultAct) : '—',
      ultLlamada: ultLlam ? _date(ultLlam) : 'Sin llamadas',
      facturacion: factCamp,
      diasInactividad: diasInact,
      semaforo:   semaforo
    };
  });

  // Ordenar: mayor cantidad de contactos primero
  bases.sort(function(a, b) { return b.contactos - a.contactos; });

  return { ok: true, bases: bases, total: bases.length };
}
// AC05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · HISTÓRICO ANUAL + PICO HORARIO ÓPTIMO
// ══════════════════════════════════════════════════════════════
// AC06_START

// ===== CTRL+F: api_getHistoricoAnualT =====
/**
 * Tabla de resumen por mes del año actual.
 * Solo incluye meses con datos. Calcula pico horario óptimo.
 */
function api_getHistoricoAnualT(token, asesorNom) {
  _setToken(token);
  cc_requireAdmin();

  var filtroAseHist = asesorNom ? _up(asesorNom) : '';
  var now  = new Date();
  var anio = now.getFullYear();
  var byMes = {}; // "YYYY-MM" → datos

  function _mesKey(fecha) {
    var d = fecha instanceof Date ? fecha : new Date(fecha);
    if (isNaN(d)) return null;
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0');
  }

  // ── Leads por mes ─────────────────────────────────────────
  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  var leadNumsPorMes = {}; // mesKey → Set nums

  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
      var hora = r[LEAD_COL.HORA] || r[LEAD_COL.FECHA];
      var num  = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
      if (!hora || !num) return;
      var d = new Date(hora);
      if (isNaN(d) || d.getFullYear() !== anio) return;
      var mk = _mesKey(d);
      if (!leadNumsPorMes[mk]) leadNumsPorMes[mk] = {};
      leadNumsPorMes[mk][num] = true;
    });
  }

  Object.keys(leadNumsPorMes).forEach(function(mk) {
    if (!byMes[mk]) byMes[mk] = { leads: 0, llamados: 0, citas: 0, ventas: 0, fact: 0, virgenes: 0, subsanadas: 0 };
    byMes[mk].leads = Object.keys(leadNumsPorMes[mk]).length;
  });

  // ── Llamadas por mes ──────────────────────────────────────
  var shL = _sh(CFG.SHEET_LLAMADAS);
  var lrL = shL.getLastRow();
  var byHoraGlobal = {}; // "HH" → { llamadas, citas }

  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 21).getValues().forEach(function(r) {
      var fecha = r[LLAM_COL.FECHA];
      var d = fecha instanceof Date ? fecha : new Date(fecha);
      if (isNaN(d) || d.getFullYear() !== anio) return;
      // Filtrar por asesor si se especificó
      if (filtroAseHist && _up(_norm(r[LLAM_COL.ASESOR])) !== filtroAseHist) return;
      var mk  = _mesKey(d);
      var num = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      if (!mk || !num) return;

      if (!byMes[mk]) byMes[mk] = { leads: 0, llamados: 0, citas: 0, ventas: 0, fact: 0, virgenes: 0, subsanadas: 0 };

      // Solo leads del mismo mes → llamados únicos
      if (leadNumsPorMes[mk] && leadNumsPorMes[mk][num]) {
        byMes[mk].llamados++;
      }
      if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') byMes[mk].citas++;

      // Pico horario: todos los años
      var horaRaw = r[LLAM_COL.HORA];
      try {
        var horaObj = horaRaw instanceof Date ? horaRaw : new Date(horaRaw);
        if (!isNaN(horaObj)) {
          var hh = String(horaObj.getHours()).padStart(2, '0');
          if (!byHoraGlobal[hh]) byHoraGlobal[hh] = { llamadas: 0, citas: 0 };
          byHoraGlobal[hh].llamadas++;
          if (_up(r[LLAM_COL.ESTADO]) === 'CITA CONFIRMADA') byHoraGlobal[hh].citas++;
        }
      } catch(e) {}
    });
  }

  // ── Ventas por mes ────────────────────────────────────────
  // FIX v1.2: Validar que la fecha sea del año actual Y que ya exista
  // en byMes (creado por leads o llamadas). Así evitamos crear entradas
  // de meses que no tienen actividad de call center aunque tengan ventas.
  var shV = _sh(CFG.SHEET_VENTAS);
  var lrV = shV.getLastRow();
  var anioStr = String(anio) + '-';
  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 9).getValues().forEach(function(r) {
      var raw = r[VENT_COL.FECHA];
      if (!raw) return;
      var d = raw instanceof Date ? raw : new Date(raw);
      // Doble validación: año correcto y no es fecha serial inválida
      if (isNaN(d) || d.getFullYear() !== anio || d.getFullYear() < 2026) return;
      var mk = _mesKey(d);
      if (!mk || mk.indexOf(anioStr) !== 0) return;
      // Solo sumar ventas a meses que ya existen (tienen leads o llamadas)
      // Esto evita que aparezca "Diciembre" solo por ventas sin llamadas
      if (byMes[mk]) {
        byMes[mk].ventas++;
        byMes[mk].fact += Number(r[VENT_COL.MONTO]) || 0;
      }
    });
  }

  // ── Construir resultado ───────────────────────────────────
  var mesCurrent = _mesKey(now);
  var meses = Object.keys(byMes)
    .filter(function(mk) {
      // Solo meses del año actual con llamadas registradas
      return mk.indexOf(anioStr) === 0 && byMes[mk].llamados > 0;
    })
    .sort()
    .map(function(mk) {
      var d = new Date(mk + '-01');
      var m = byMes[mk];
      var ll = m.llamados > 0 ? m.llamados : 1;
      return {
        mesKey:    mk,
        mes:       MESES_ES[d.getMonth() + 1] || mk,
        esCurrent: mk === mesCurrent,
        leads:     m.leads,
        llamados:  m.llamados,
        pctLlamados: m.leads > 0 ? Math.round(m.llamados / m.leads * 100) : 0,
        citas:     m.citas,
        pctConv:   m.llamados > 0 ? Math.round(m.citas / m.llamados * 100) : 0,
        ventas:    m.ventas,
        fact:      Math.round(m.fact)
      };
    });

  // ── Pico horario óptimo ───────────────────────────────────
  var picoHora = null; var maxConvHora = 0;
  Object.keys(byHoraGlobal).forEach(function(hh) {
    var h = byHoraGlobal[hh];
    if (h.llamadas >= 10) { // mínimo 10 llamadas para ser estadísticamente válido
      var conv = Math.round(h.citas / h.llamadas * 100);
      if (conv > maxConvHora) { maxConvHora = conv; picoHora = hh + ':00'; }
    }
  });

  return { ok: true, meses: meses, picoHora: picoHora, picoConv: maxConvHora, anio: anio };
}
// AC06_END

// ══════════════════════════════════════════════════════════════
// MOD-07 · BASE SIN LLAMAR CON SEMÁFORO + ALERTAS
// ══════════════════════════════════════════════════════════════
// AC07_START

// ===== CTRL+F: api_getBaseVirgenesT =====
/**
 * Lista de leads sin llamar (nunca contactados) del período.
 * Incluye semáforo por días de antigüedad.
 * También retorna alertas estratégicas.
 */
function api_getBaseVirgenesT(token, modo, desde, hasta, limit) {
  _setToken(token);
  cc_requireAdmin();

  var filtro = _ac_buildFiltro(modo || 'mes', desde, hasta);
  limit = limit || 100;

  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  if (lrLd < 2) return { ok: true, items: [], alertas: [] };

  // Leer todos los números que ya tuvieron llamada
  var shL   = _sh(CFG.SHEET_LLAMADAS);
  var lrL   = shL.getLastRow();
  var llamados = {};
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 9).getValues().forEach(function(r) {
      var num = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      if (num) llamados[num] = true;
    });
  }

  var now    = new Date();
  var items  = [];
  var vRojo  = 0, vAmarillo = 0, vVerde = 0;

  shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
    var num   = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
    var hora  = r[LEAD_COL.HORA] || r[LEAD_COL.FECHA];
    var camp  = _up(_norm(r[LEAD_COL.TRAT] || ''));
    var anuncio = _norm(r[LEAD_COL.ANUNCIO] || '');
    if (!num || llamados[num]) return;
    if (!_inRango(hora, filtro.desde, filtro.hasta)) return;

    var fechaObj = hora ? new Date(hora) : null;
    var dias = fechaObj && !isNaN(fechaObj) ? Math.floor((now - fechaObj) / 86400000) : null;
    var sem  = dias === null ? 'gris' : dias <= 2 ? 'verde' : dias <= 7 ? 'amarillo' : 'rojo';

    if (sem === 'rojo')     vRojo++;
    else if (sem === 'amarillo') vAmarillo++;
    else if (sem === 'verde')    vVerde++;

    if (items.length < limit) {
      items.push({
        num:     num,
        campana: camp,
        anuncio: anuncio,
        fechaIngreso: hora ? _date(fechaObj) : '—',
        dias:    dias,
        semaforo: sem,
        wa:      _wa(num)
      });
    }
  });

  // Ordenar: más antiguo primero (mayor días = más urgente)
  items.sort(function(a, b) { return (b.dias || 0) - (a.dias || 0); });

  // ── Alertas estratégicas ──────────────────────────────────
  var alertas = [];
  var totalVirgenes = vRojo + vAmarillo + vVerde;

  if (vRojo > 0) {
    alertas.push({
      tipo: 'urgente',
      nivel: 'rojo',
      mensaje: vRojo + ' leads sin contactar hace más de 7 días — se enfrían',
      accion: 'Priorizar en cola inmediatamente'
    });
  }
  if (totalVirgenes > 50) {
    alertas.push({
      tipo: 'volumen',
      nivel: 'amarillo',
      mensaje: totalVirgenes + ' leads vírgenes sin contactar en el período',
      accion: 'Revisar capacidad del equipo'
    });
  }

  return {
    ok: true,
    items: items,
    resumen: { total: totalVirgenes, rojo: vRojo, amarillo: vAmarillo, verde: vVerde },
    alertas: alertas
  };
}
// AC07_END

// ══════════════════════════════════════════════════════════════
// MOD-08 · LÓGICA MADRE — COLA PRIORIZADA CON FICHA
// ══════════════════════════════════════════════════════════════
// AC08_START

// ===== CTRL+F: api_getColaAdminT =====
/**
 * Construye la cola priorizada para un asesor según la lógica madre
 * o su configuración personalizada.
 * Incluye ficha contextual para cada número.
 * Anti-duplicado: CacheService marca los llamados hoy por asesor.
 */
function api_getColaAdminT(token, asesorNom, limit) {
  _setToken(token);
  cc_requireAdmin();

  asesorNom = _up(asesorNom || '');
  limit     = limit || 10;
  var now   = new Date();
  var hoy   = _date(now);

  // Configuración del asesor
  var config = _ac_getDistConfig(asesorNom);

  // Anti-duplicado: números ya llamados HOY por este asesor
  var cacheKey   = 'COLA_HOY_' + asesorNom.replace(/\s/g, '_') + '_' + hoy;
  var llamHoySet = {};
  try {
    var cache = CacheService.getScriptCache();
    var cached = cache.get(cacheKey);
    if (cached) llamHoySet = JSON.parse(cached);
  } catch(e) {}

  // Leer hojas
  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  var shL  = _sh(CFG.SHEET_LLAMADAS);
  var lrL  = shL.getLastRow();
  var shA  = _shAgenda();
  var lrA  = shA.getLastRow();
  var shV  = _sh(CFG.SHEET_VENTAS);
  var lrV  = shV.getLastRow();

  // ── Mapa de leads con su fecha de ingreso ─────────────────
  var leadsMap = {}; // num → { fecha, campana, anuncio }
  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
      var num  = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
      var hora = r[LEAD_COL.HORA] || r[LEAD_COL.FECHA];
      var camp = _up(_norm(r[LEAD_COL.TRAT] || ''));
      if (!num) return;
      // Filtro de campaña si config lo especifica
      if (config.tipo === 'campana' && config.valor && _up(config.valor) !== camp) return;
      var d = hora ? new Date(hora) : null;
      if (!leadsMap[num] || (d && d > leadsMap[num].fechaObj)) {
        leadsMap[num] = { fechaObj: d, fecha: d ? _date(d) : '', campana: camp, anuncio: _norm(r[LEAD_COL.ANUNCIO] || '') };
      }
    });
  }

  // ── Mapa de último estado en llamadas ─────────────────────
  var ultEstadoMap = {}; // num → { estado, fecha, asesor, subEstado, intento }
  var llamHoyPorAsesor = {}; // num → true si este asesor llamó hoy
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 21).getValues().forEach(function(r) {
      var num  = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      var ts   = r[LLAM_COL.ULT_TS] ? new Date(r[LLAM_COL.ULT_TS]) : null;
      if (!num) return;
      if (!ultEstadoMap[num] || (ts && ts > ultEstadoMap[num].ts)) {
        ultEstadoMap[num] = {
          estado:    _up(r[LLAM_COL.ESTADO]),
          subEstado: _norm(r[LLAM_COL.SUB_ESTADO] || ''),
          fecha:     _date(r[LLAM_COL.FECHA]),
          asesor:    _up(_norm(r[LLAM_COL.ASESOR])),
          obs:       _norm(r[LLAM_COL.OBS] || '').slice(0, 80),
          intento:   Number(r[LLAM_COL.INTENTO]) || 1,
          ts:        ts
        };
      }
      // Anti-duplicado diario: ¿llamó este asesor hoy?
      if (_date(r[LLAM_COL.FECHA]) === hoy && _up(_norm(r[LLAM_COL.ASESOR])) === asesorNom) {
        llamHoyPorAsesor[num] = true;
      }
    });
  }

  // ── Mapa de última cita por número ───────────────────────
  var ultCitaMap = {}; // num → { fecha, tratamiento, estado, doctora, sede, ventaId }
  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 22).getValues().forEach(function(r) {
      var num  = _normNum(r[AG_COL.NUMERO]);
      var fch  = _date(r[AG_COL.FECHA]);
      if (!num) return;
      if (!ultCitaMap[num] || fch > ultCitaMap[num].fecha) {
        ultCitaMap[num] = {
          fecha:      fch,
          hora:       _normHora(r[AG_COL.HORA_CITA]),
          trat:       _norm(r[AG_COL.TRATAMIENTO]),
          tipoCita:   _norm(r[AG_COL.TIPO_CITA]),
          estado:     _norm(r[AG_COL.ESTADO]),
          doctora:    _norm(r[AG_COL.DOCTORA]),
          sede:       _up(_norm(r[AG_COL.SEDE])),
          asesor:     _norm(r[AG_COL.ASESOR]),
          ventaId:    _norm(r[AG_COL.VENTA_ID]),
          obs:        _norm(r[AG_COL.OBS] || '').slice(0, 80)
        };
      }
    });
  }

  // ── Mapa de última venta por número ──────────────────────
  var ultVentaMap = {}; // num → { fecha, trat, monto, nVentas, totalFact }
  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 16).getValues().forEach(function(r) {
      var num   = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
      var fch   = _date(r[VENT_COL.FECHA]);
      var monto = Number(r[VENT_COL.MONTO]) || 0;
      if (!num) return;
      if (!ultVentaMap[num]) ultVentaMap[num] = { fecha: '', trat: '', monto: 0, nVentas: 0, totalFact: 0 };
      ultVentaMap[num].nVentas++;
      ultVentaMap[num].totalFact += monto;
      if (fch > ultVentaMap[num].fecha) {
        ultVentaMap[num].fecha = fch;
        ultVentaMap[num].trat  = _norm(r[VENT_COL.TRATAMIENTO]);
        ultVentaMap[num].monto = monto;
      }
    });
  }

  // ── Clasificar leads en los 8 pasos de la lógica madre ───
  var mesActual = now.getFullYear() * 100 + now.getMonth();
  var hace90    = new Date(now.getTime() - 90 * 86400000);
  var hace14    = new Date(now.getTime() - 14 * 86400000);

  var pasos = [[], [], [], [], [], [], [], []]; // 8 cubetas

  Object.keys(leadsMap).forEach(function(num) {
    // Excluir si este asesor ya llamó hoy (anti-duplicado)
    if (llamHoyPorAsesor[num] || llamHoySet[num]) return;

    var lead  = leadsMap[num];
    var ult   = ultEstadoMap[num];
    var cita  = ultCitaMap[num];
    var venta = ultVentaMap[num];
    var est   = ult ? ult.estado : '';

    // Excluir descartados
    if (ESTADOS_DESCARTADOS.has(est)) return;

    var fechaLead = lead.fechaObj;
    var mesLead   = fechaLead ? fechaLead.getFullYear() * 100 + fechaLead.getMonth() : 0;
    var esNuevo   = mesLead === mesActual;
    var esVirgen  = !ult;

    // PASO 1: Vírgenes del mes actual
    if (esVirgen && esNuevo) { pasos[0].push(num); return; }

    // PASO 2: No asistió a cita (últimas 2 semanas)
    if (cita && cita.estado === 'NO ASISTIO') {
      var dCita = new Date(cita.fecha);
      if (!isNaN(dCita) && dCita >= hace14) { pasos[1].push(num); return; }
    }

    // PASO 3: Vírgenes históricos (antes del mes actual, nunca llamados)
    if (esVirgen && !esNuevo) { pasos[2].push(num); return; }

    // PASO 4: Sin contacto del mes actual
    if ((est === 'SIN CONTACTO' || est === 'NO CONTESTA') && mesLead === mesActual) {
      pasos[3].push(num); return;
    }

    // PASO 5: Canceló o reprogramó cita
    if (cita && (cita.estado === 'CANCELADA' || cita.estado === 'REAGENDADA')) {
      pasos[4].push(num); return;
    }

    // PASO 6: Base antigua sin convertir (mes anterior, con contacto)
    if (ult && mesLead < mesActual && est !== 'CITA CONFIRMADA') {
      pasos[5].push(num); return;
    }

    // PASO 7: Pacientes activos para recompra (compra últimos 90 días)
    if (venta && new Date(venta.fecha) >= hace90) {
      pasos[6].push(num); return;
    }

    // PASO 8: Sin contacto histórico (meses anteriores)
    if (est === 'SIN CONTACTO' || est === 'NO CONTESTA') {
      pasos[7].push(num); return;
    }
  });

  // ── Construir lista ordenada con fichas ────────────────────
  var labels = [
    'Virgen · Mes actual',
    'No asistió · Últimas 2 semanas',
    'Virgen · Histórico',
    'Sin contacto · Mes actual',
    'Canceló / reprogramó cita',
    'Base antigua sin convertir',
    'Paciente activo · Recompra',
    'Sin contacto · Histórico'
  ];

  var cola = [];
  for (var p = 0; p < pasos.length && cola.length < limit; p++) {
    // Ordenar cada paso de más reciente a más antiguo
    var paso = pasos[p].sort(function(a, b) {
      var fa = leadsMap[a] && leadsMap[a].fechaObj ? leadsMap[a].fechaObj.getTime() : 0;
      var fb = leadsMap[b] && leadsMap[b].fechaObj ? leadsMap[b].fechaObj.getTime() : 0;
      return fb - fa;
    });
    paso.forEach(function(num) {
      if (cola.length >= limit) return;
      cola.push(_ac_buildFicha(num, p, labels[p], leadsMap, ultEstadoMap, ultCitaMap, ultVentaMap));
    });
  }

  return {
    ok:      true,
    cola:    cola,
    asesor:  asesorNom,
    config:  config,
    totales: pasos.map(function(p, i) { return { paso: i + 1, label: labels[i], count: p.length }; })
  };
}

/**
 * Construye la ficha contextual de un número para el asesor.
 */
function _ac_buildFicha(num, paso, label, leadsMap, ultEstadoMap, ultCitaMap, ultVentaMap) {
  var lead  = leadsMap[num] || {};
  var ult   = ultEstadoMap[num];
  var cita  = ultCitaMap[num];
  var venta = ultVentaMap[num];

  var ficha = {
    num:     num,
    wa:      _wa(num),
    paso:    paso + 1,
    label:   label,
    campana: lead.campana  || '',
    anuncio: lead.anuncio  || '',
    fechaIngreso: lead.fecha || '',
    diasDesdeIngreso: lead.fechaObj ? Math.floor((new Date() - lead.fechaObj) / 86400000) : null
  };

  // Contexto del último contacto
  if (ult) {
    ficha.ultimoContacto = {
      fecha:     ult.fecha,
      estado:    ult.estado,
      subEstado: ult.subEstado,
      asesor:    ult.asesor,
      intentos:  ult.intento,
      obs:       ult.obs
    };
  }

  // Contexto de la última cita
  if (cita) {
    ficha.ultimaCita = {
      fecha:    cita.fecha,
      hora:     cita.hora,
      trat:     cita.trat,
      tipoCita: cita.tipoCita,
      estado:   cita.estado,
      doctora:  cita.doctora,
      sede:     cita.sede,
      asesor:   cita.asesor,
      tieneVenta: !!cita.ventaId,
      obs:      cita.obs
    };
    // Acción sugerida según estado de la cita
    ficha.accionSugerida =
      cita.estado === 'NO ASISTIO' ? 'Preguntar por la cita que no pudo asistir' :
      cita.estado === 'CANCELADA'  ? 'Ofrecer reagendar — tenía interés demostrado' :
      cita.estado === 'REAGENDADA' ? 'Confirmar la nueva fecha' :
      cita.estado === 'ASISTIO'    ? 'Seguimiento post-visita — ofrecer complementario' :
      'Continuar gestión';
  }

  // Contexto de ventas
  if (venta) {
    ficha.ultimaCompra = {
      fecha:      venta.fecha,
      trat:       venta.trat,
      monto:      venta.monto,
      nVentas:    venta.nVentas,
      totalFact:  venta.totalFact
    };
  }

  return ficha;
}
// AC08_END

// ══════════════════════════════════════════════════════════════
// MOD-09 · DISTRIBUCIONES POR ASESOR (PropertiesService)
// ══════════════════════════════════════════════════════════════
// AC09_START

/**
 * Clave PropertiesService para guardar config de asesor.
 */
function _ac_distKey(asesorNom) {
  return 'DIST_CONFIG_' + _up(asesorNom).replace(/\s/g, '_').replace(/[^A-Z0-9_]/g, '');
}

/**
 * Obtiene la configuración de distribución de un asesor.
 * Default: lógica global.
 */
function _ac_getDistConfig(asesorNom) {
  try {
    var props = PropertiesService.getScriptProperties();
    var raw   = props.getProperty(_ac_distKey(asesorNom));
    if (raw) return JSON.parse(raw);
  } catch(e) {}
  return { tipo: 'global', valor: null, filtros: [] };
}

// ===== CTRL+F: api_getDistribucionesT =====
/**
 * Retorna la configuración de distribución de todos los asesores.
 * v1.1 FIX: conteo ligero O(leads) en lugar de O(leads x asesores).
 */
function api_getDistribucionesT(token) {
  _setToken(token);
  cc_requireAdmin();

  var asesores = _asesoresActivosCached().filter(function(a) {
    return a.role === ROLES.ASESOR;
  });

  // Conteo ligero: leer leads/llamadas UNA vez para todos los asesores
  var shLd = _sh(CFG.SHEET_LEADS);
  var lrLd = shLd.getLastRow();
  var shL  = _sh(CFG.SHEET_LLAMADAS);
  var lrL  = shL.getLastRow();

  var descartados = {};
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 10).getValues().forEach(function(r) {
      var num = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      if (num && ESTADOS_DESCARTADOS.has(_up(r[LLAM_COL.ESTADO]))) {
        descartados[num] = true;
      }
    });
  }

  var totalDisponibles = 0;
  var vLD = {};
  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
      var num = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
      if (!num || vLD[num]) return;
      vLD[num] = true;
      if (!descartados[num]) totalDisponibles++;
    });
  }

  var result = asesores.map(function(a) {
    var nom    = _up(a.label || a.nombre);
    var config = _ac_getDistConfig(nom);
    return {
      idAsesor:          _norm(a.idAsesor),
      nombre:            nom,
      sede:              a.sede || '',
      config:            config,
      colaActual:        totalDisponibles,
      descripcionConfig: _ac_describeConfig(config)
    };
  });

  return { ok: true, asesores: result };
}

/**
 * Descripción legible de la configuración de distribución.
 */
function _ac_describeConfig(config) {
  if (!config || config.tipo === 'global') return 'Lógica global prediseñada';
  if (config.tipo === 'campana') return 'Campaña: ' + (config.valor || '—');
  if (config.tipo === 'etiqueta') return 'Tratamiento: ' + (config.valor || '—');
  if (config.tipo === 'provincia') return 'Filtro provincia: ' + (config.valor || 'activo');
  if (config.tipo === 'pacientes_activos') return 'Solo pacientes activos (recompra)';
  if (config.tipo === 'adelantos') return 'Solo con adelanto pendiente';
  return 'Configuración personalizada';
}

// ===== CTRL+F: api_saveDistribucionT =====
/**
 * Guarda la configuración de distribución de un asesor.
 * @param {string} asesorNom  Nombre del asesor
 * @param {object} config     { tipo, valor, filtros }
 *   tipo: "global" | "campana" | "etiqueta" | "provincia" | "pacientes_activos" | "adelantos"
 *   valor: nombre de campaña/etiqueta/provincia (null para global)
 *   filtros: array de filtros adicionales ["excluir_llamados_hoy", "solo_sin_contacto", ...]
 */
function api_saveDistribucionT(token, asesorNom, config) {
  _setToken(token);
  cc_requireAdmin();

  if (!asesorNom) return { ok: false, error: 'Falta nombre del asesor' };
  var tiposValidos = ['global', 'campana', 'etiqueta', 'provincia', 'pacientes_activos', 'adelantos'];
  if (config && config.tipo && tiposValidos.indexOf(config.tipo) < 0) {
    return { ok: false, error: 'Tipo de configuración inválido: ' + config.tipo };
  }

  try {
    var props = PropertiesService.getScriptProperties();
    var key   = _ac_distKey(asesorNom);
    if (!config || config.tipo === 'global') {
      props.deleteProperty(key); // Sin configuración = usa global
    } else {
      props.setProperty(key, JSON.stringify(config));
    }
    return { ok: true, asesor: asesorNom, config: config || { tipo: 'global', valor: null, filtros: [] } };
  } catch(e) {
    return { ok: false, error: e.message };
  }
}

// ===== CTRL+F: api_resetDistribucionT =====
/**
 * Restablece la distribución de un asesor a la lógica global.
 */
function api_resetDistribucionT(token, asesorNom) {
  _setToken(token);
  cc_requireAdmin();
  try {
    PropertiesService.getScriptProperties().deleteProperty(_ac_distKey(asesorNom));
    return { ok: true, asesor: asesorNom, reset: true };
  } catch(e) {
    return { ok: false, error: e.message };
  }
}

// ===== CTRL+F: api_getCampanasListT =====
/**
 * Lista de campañas disponibles para el selector del modal de distribución.
 */
function api_getCampanasListT(token) {
  _setToken(token);
  cc_requireAdmin();

  var shLd  = _sh(CFG.SHEET_LEADS);
  var lrLd  = shLd.getLastRow();
  var camps = {};
  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 3).getValues().forEach(function(r) {
      var camp = _up(_norm(r[LEAD_COL.TRAT] || ''));
      if (camp) camps[camp] = (camps[camp] || 0) + 1;
    });
  }
  var lista = Object.keys(camps).sort().map(function(c) {
    return { nombre: c, contactos: camps[c] };
  });
  return { ok: true, campanas: lista };
}
// AC09_END

// ══════════════════════════════════════════════════════════════
// MOD-10 · BASES POR TIPO — tabs de gestión
// ══════════════════════════════════════════════════════════════
// AC10_START

/**
 * Retorna la lista de bases clasificadas según el tipo de tab seleccionado.
 * Tipos: "campana" | "tipificacion" | "estado_cita" | "venta" | "mes_ingreso" | "provincia"
 * Cada base incluye: nombre, contactos, facturacion, semaforo, diasSinLlamar
 *
 * ===== CTRL+F: api_getBasesPorTipoT =====
 */
function api_getBasesPorTipoT(token, tipo) {
  _setToken(token);
  cc_requireAdmin();

  tipo = _low(tipo || 'campana');
  var now   = new Date();
  var shLd  = _sh(CFG.SHEET_LEADS);
  var lrLd  = shLd.getLastRow();
  var shL   = _sh(CFG.SHEET_LLAMADAS);
  var lrL   = shL.getLastRow();
  var shV   = _sh(CFG.SHEET_VENTAS);
  var lrV   = shV.getLastRow();
  var shA   = _shAgenda();
  var lrA   = shA.getLastRow();

  // ── Mapa: num → última llamada (estado, fecha, asesor) ────
  var ultLlam = {}; // num → { estado, fecha, asesor, ts }
  var ultLlamPorGrupo = {}; // grupo → Date última llamada (para semáforo)
  if (lrL >= 2) {
    shL.getRange(2, 1, lrL - 1, 14).getValues().forEach(function(r) {
      var num  = _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]);
      var ts   = r[LLAM_COL.ULT_TS] ? new Date(r[LLAM_COL.ULT_TS]) : null;
      if (!num) return;
      if (!ultLlam[num] || (ts && ts > ultLlam[num].ts)) {
        ultLlam[num] = {
          estado: _up(r[LLAM_COL.ESTADO]),
          fecha:  _date(r[LLAM_COL.FECHA]),
          asesor: _up(_norm(r[LLAM_COL.ASESOR])),
          trat:   _up(_norm(r[LLAM_COL.TRATAMIENTO])),
          ts:     ts
        };
      }
    });
  }

  // ── Mapa: num → facturación total ─────────────────────────
  var ventPorNum = {};
  if (lrV >= 2) {
    shV.getRange(2, 1, lrV - 1, 16).getValues().forEach(function(r) {
      var num   = _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]);
      var monto = Number(r[VENT_COL.MONTO]) || 0;
      if (num) ventPorNum[num] = (ventPorNum[num] || 0) + monto;
    });
  }

  // ── Mapa: num → última cita ────────────────────────────────
  var ultCita = {};
  if (lrA >= 2) {
    shA.getRange(2, 1, lrA - 1, 13).getValues().forEach(function(r) {
      var num = _normNum(r[AG_COL.NUMERO]);
      var fch = _date(r[AG_COL.FECHA]);
      if (!num) return;
      if (!ultCita[num] || fch > ultCita[num].fecha) {
        ultCita[num] = {
          fecha:  fch,
          estado: _up(r[AG_COL.ESTADO]),
          trat:   _norm(r[AG_COL.TRATAMIENTO])
        };
      }
    });
  }

  // ── Función agrupadora según tipo ─────────────────────────
  function _getGrupo(num, leadRow) {
    var ult  = ultLlam[num];
    var cita = ultCita[num];
    var vent = ventPorNum[num];
    var hora = leadRow[LEAD_COL.HORA] || leadRow[LEAD_COL.FECHA];
    var d    = hora ? new Date(hora) : null;

    switch (tipo) {
      case 'campana':
        return _up(_norm(leadRow[LEAD_COL.TRAT] || '')) || 'SIN CAMPAÑA';

      case 'tipificacion':
        if (!ult) return 'VIRGEN — SIN LLAMAR';
        return ult.estado || 'SIN TIPIFICAR';

      case 'estado_cita':
        if (!cita) return 'SIN CITA';
        return cita.estado || 'SIN ESTADO';

      case 'venta':
        if (!vent || vent === 0) return 'SIN VENTA';
        var hace90 = new Date(now.getTime() - 90 * 86400000);
        var ultVentFecha = ult && ult.ts ? ult.ts : null;
        return ultVentFecha && ultVentFecha >= hace90 ? 'COMPRÓ — ÚLTIMOS 90 DÍAS' : 'COMPRÓ — HISTÓRICO';

      case 'mes_ingreso':
        if (!d || isNaN(d)) return 'SIN FECHA';
        return MESES_ES[d.getMonth() + 1] + ' ' + d.getFullYear();

      case 'provincia':
        var num9 = String(num).replace(/\D/g, '');
        // Números que NO empiezan con 9 o empiezan con 51+otro prefijo
        var esLima = /^9[0-9]{8}$/.test(num9);
        if (!esLima) return 'PROVINCIA';
        if (ult && (ult.estado === 'PROVINCIA' || ult.estado === 'PROVINCIAS')) return 'MARCADO COMO PROVINCIA';
        return 'LIMA';

      default:
        return 'OTRO';
    }
  }

  // ── Agrupar todos los leads ────────────────────────────────
  var grupos = {}; // nombre → { nums, fact, ultLlamadaTs }
  var vistos = {};
  if (lrLd >= 2) {
    shLd.getRange(2, 1, lrLd - 1, 8).getValues().forEach(function(r) {
      var num = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]);
      if (!num || vistos[num]) return;
      vistos[num] = true;
      var grupo = _getGrupo(num, r);
      if (!grupos[grupo]) grupos[grupo] = { nombre: grupo, nums: {}, fact: 0, ultLlamadaTs: null };
      grupos[grupo].nums[num] = true;
      grupos[grupo].fact += ventPorNum[num] || 0;
      var ts = ultLlam[num] ? ultLlam[num].ts : null;
      if (ts && (!grupos[grupo].ultLlamadaTs || ts > grupos[grupo].ultLlamadaTs)) {
        grupos[grupo].ultLlamadaTs = ts;
      }
    });
  }

  // ── Construir resultado con semáforo ──────────────────────
  var bases = Object.keys(grupos).sort().map(function(g) {
    var gr = grupos[g];
    var contactos = Object.keys(gr.nums).length;
    var diasSin   = gr.ultLlamadaTs
      ? Math.floor((now - gr.ultLlamadaTs) / 86400000)
      : null;
    var semaforo  = diasSin === null ? 'gris'
                  : diasSin <= 2     ? 'verde'
                  : diasSin <= 7     ? 'amarillo' : 'rojo';
    return {
      nombre:        gr.nombre,
      contactos:     contactos,
      facturacion:   Math.round(gr.fact),
      semaforo:      semaforo,
      diasSinLlamar: diasSin,
      ultLlamada:    gr.ultLlamadaTs ? _date(gr.ultLlamadaTs) : null
    };
  });

  // Ordenar: más contactos primero
  bases.sort(function(a, b) { return b.contactos - a.contactos; });

  return { ok: true, tipo: tipo, bases: bases, total: bases.length };
}
// AC10_END

// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════

function test_GS22_AdminCalls() {
  Logger.log('=== GS_22_AdminCalls v1.0 TEST ===');
  Logger.log('MOD-01: api_getAdminCallsKpisT');
  Logger.log('MOD-02: api_getMonitoreoEquipoT + api_getProgresoPorHoraT');
  Logger.log('MOD-03: api_getScoreNumerosT');
  Logger.log('MOD-04: api_getEmbudoConversionT');
  Logger.log('MOD-05: api_getBasesCampanasT');
  Logger.log('MOD-06: api_getHistoricoAnualT');
  Logger.log('MOD-07: api_getBaseVirgenesT');
  Logger.log('MOD-08: api_getColaAdminT (lógica madre)');
  Logger.log('MOD-09: api_getDistribucionesT / api_saveDistribucionT / api_resetDistribucionT');
  Logger.log('=== OK ===');
}