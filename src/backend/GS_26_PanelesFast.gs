/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_26_PanelesFast.gs                       ║
 * ║  FASE 1: Un solo request por panel                          ║
 * ║  Versión: 1.0.0                                             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * PROBLEMA RESUELTO:
 *   Antes: 8 requests × 1.5s overhead GAS = 12s por panel
 *   Ahora: 1 request × 1.5s overhead + Supabase 5ms = ~1.5s
 *
 * REGLA PERMANENTE para todos los bloques siguientes:
 *   - Cada panel tiene UN solo endpoint _Fast que lo carga todo
 *   - El endpoint llama una función SQL en Supabase
 *   - GAS solo es el middleware, no la base de datos
 *   - Fallback automático a funciones individuales si Supabase falla
 *
 * CONTENIDO:
 *   F01 · api_getPanelAsesorFastT  → panel completo del asesor
 *   F02 · api_getPanelAdminFastT   → panel completo del admin
 *   F03 · api_getPanelCallCenterFastT → call center con next lead
 */

// ══════════════════════════════════════════════════════════════
// F01 · PANEL ASESOR COMPLETO — 1 solo request
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getPanelAsesorFastT =====

/**
 * Devuelve TODO lo que necesita ViewAdvisorHome en un solo request.
 * Reemplaza:
 *   api_getMyScoreMesT        → embudo del mes
 *   api_getAdvisorDashboardT  → comisiones + atenciones
 *   api_getMisSemanaT         → calendario semanal (se mantiene separado)
 *   api_getMySeguimientosT    → seguimientos pendientes
 *
 * Tiempo: ~1.5s (1 round-trip GAS) vs ~8s (5 round-trips antes)
 */
function api_getPanelAsesorFastT(token) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  var hoy = _date(now);
  var mesI = now.getFullYear() + "-" + String(now.getMonth()+1).padStart(2,"0") + "-01";

  // INTENTO 1: Supabase (~5ms de query + ~1s overhead GAS = ~1.5s total)
  try {
    var sbKey = _sbKey();
    if (sbKey) {
      var res = _sbRequest("POST", "rpc/aos_panel_asesor", {
        body: {
          p_asesor:     _up(s.asesor),
          p_id_asesor:  s.idAsesor,
          p_hoy:        hoy,
          p_mes_inicio: mesI
        }
      });

      if (res.ok && res.data) {
        var d = res.data;

        // Enriquecer con comisiones desde GAS (tabla config)
        var comData = null;
        try { comData = _calcComisionesAsesor(s, now); } catch(e) {}

        // Seguimientos pendientes vencidos
        var segsData = null;
        try {
          var segRes = _sbGet("aos_seguimientos",
            "id_asesor=eq." + s.idAsesor +
            "&estado=eq.PENDIENTE" +
            "&fecha_programada=lte." + hoy,
            "id,fecha_programada,numero,tratamiento,obs_recontacto",
            20
          );
          if (segRes.ok) segsData = segRes.data || [];
        } catch(e) {}

        return {
          ok: true,
          fromSupabase: true,
          asesor: s.asesor,
          role:   s.role,
          embudo: {
            llamadas:   d.llamMes    || 0,
            citas:      d.citasMes   || 0,
            asistieron: d.asistMes   || 0,
            ventas:     d.ventasMes  || 0,
            fact:       d.factMes    || 0,
            sinContacto: d.sinContacto || 0,
            convPct:    d.convPct    || 0
          },
          kpisHoy: {
            llamHoy:  d.llamHoy  || 0,
            citasHoy: d.citasHoy || 0,
            segsVenc: d.segsVenc || 0
          },
          comisiones: comData,
          seguimientos: segsData || [],
          ts: _time(now)
        };
      }
    }
  } catch(e) {
    Logger.log("api_getPanelAsesorFastT Supabase error: " + e.message);
  }

  // FALLBACK: funciones individuales (más lento pero siempre funciona)
  Logger.log("api_getPanelAsesorFastT: usando fallback Sheets");
  try {
    var scoreRes = api_getMyScoreMes(now.getMonth()+1, now.getFullYear());
    var d2 = (scoreRes && scoreRes.datos) || {};
    var segRes2 = api_listFollowups("hoy");
    return {
      ok: true, fromSupabase: false,
      asesor: s.asesor, role: s.role,
      embudo: {
        llamadas: d2.llamadas||0, citas: d2.citas||0,
        asistieron: d2.asistieron||0, ventas: d2.ventas||0,
        fact: d2.fact||0, sinContacto: 0, convPct: 0
      },
      kpisHoy: { llamHoy: 0, citasHoy: 0, segsVenc: segRes2 && segRes2.totales ? segRes2.totales.vencido||0 : 0 },
      comisiones: null,
      seguimientos: segRes2 && segRes2.items ? segRes2.items.slice(0,10) : [],
      ts: _time(now)
    };
  } catch(e2) {
    return { ok: false, error: e2.message };
  }
}
// ===== CTRL+F: api_getPanelAsesorFastT_END =====


// ══════════════════════════════════════════════════════════════
// F02 · PANEL ADMIN COMPLETO — 1 solo request
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getPanelAdminFastT =====

/**
 * Devuelve TODO lo que necesita ViewAdminHome en un solo request.
 * Reemplaza:
 *   api_getAdminHomeKpisT      → KPIs ejecutivos
 *   api_getAdminKpisFromSupabaseT → KPIs desde Supabase
 *   api_getTeamSemaforoT       → semáforo del equipo
 *   api_getMarketingTickerT    → ticker de marketing (se mantiene por separado)
 *
 * Tiempo: ~1.5s total vs ~6-8s antes
 */
function api_getPanelAdminFastT(token) {
  _setToken(token);
  cc_requireAdmin();
  var now  = new Date();
  var hoy  = _date(now);
  var ayer = _date(new Date(now.getTime() - 86400000));
  var mesI = now.getFullYear() + "-" + String(now.getMonth()+1).padStart(2,"0") + "-01";

  // INTENTO: Supabase
  try {
    var sbKey = _sbKey();
    if (sbKey) {
      var res = _sbRequest("POST", "rpc/aos_panel_admin", {
        body: { p_hoy: hoy, p_ayer: ayer, p_mes_inicio: mesI }
      });

      if (res.ok && res.data) {
        var d = res.data;

        // Enriquecer semáforo con estado operativo de Supabase
        var semRows = (d.semaforo || []).map(function(f) {
          var mins = f.mins_sin !== null ? Number(f.mins_sin) : null;
          var sem  = _calcSemaforo(mins, "ACTIVO");
          return {
            idAsesor: f.id_asesor,
            nombre:   (f.nombre || "").toUpperCase(),
            llamadas: f.llamadas || 0,
            citas:    f.citas    || 0,
            ultTs:    f.ult_ts   ? new Date(f.ult_ts).toLocaleTimeString("es-PE") : "—",
            minsSin:  mins,
            estado:   mins === null ? "INACTIVO" : (mins < 5 ? "EN LLAMADA" : "ACTIVO"),
            semaforo: sem,
            sede:     f.sede || ""
          };
        });

        // Alertas basadas en semáforo
        var alertas = semRows
          .filter(function(f) { return f.semaforo === "rojo"; })
          .map(function(f) {
            return {
              tipo: "inactivo",
              nivel: "rojo",
              mensaje: f.nombre + " inactivo hace " + f.minsSin + " min"
            };
          });

        // Cachear el resultado (TTL 90s)
        try {
          var cacheKey = "AOS_PANEL_ADMIN_" + hoy;
          cache_set(cacheKey, { ok:true, kpis: d.kpis, ventasHoy: d.ventasHoy,
            semaforo: { ok:true, filas: semRows }, tipif: d.tipif,
            alertas: alertas, fromSupabase: true, ts: _time(now) }, 90);
        } catch(ec) {}

        return {
          ok: true,
          kpis:      Object.assign({}, d.kpis, { alertas: alertas.length }),
          ventasHoy: d.ventasHoy || [],
          semaforo:  { ok: true, filas: semRows, totLlam: semRows.reduce(function(s,f){return s+f.llamadas;},0), totCitas: semRows.reduce(function(s,f){return s+f.citas;},0), alertas: alertas.length, ts: _time(now) },
          tipif:     d.tipif     || [],
          alertas:   alertas,
          fromSupabase: true,
          ts: _time(now)
        };
      }
    }
  } catch(e) {
    Logger.log("api_getPanelAdminFastT Supabase error: " + e.message);
  }

  // FALLBACK: caché local si existe
  try {
    var cacheKey2 = "AOS_PANEL_ADMIN_" + hoy;
    var cached = cache_get(cacheKey2);
    if (cached) return cached;
  } catch(ec) {}

  // FALLBACK final: funciones individuales
  Logger.log("api_getPanelAdminFastT: usando fallback Sheets");
  var kpis = api_getAdminHomeKpisV2();
  var sem  = api_getTeamSemaforo();
  return {
    ok: true, fromSupabase: false,
    kpis:      kpis && kpis.kpis     ? kpis.kpis     : {},
    ventasHoy: kpis && kpis.ventasHoy ? kpis.ventasHoy : [],
    semaforo:  sem  || { ok:true, filas:[] },
    tipif:     [],
    alertas:   kpis && kpis.alertas  ? kpis.alertas  : [],
    ts: _time(now)
  };
}
// ===== CTRL+F: api_getPanelAdminFastT_END =====


// ══════════════════════════════════════════════════════════════
// F03 · INVALIDAR CACHÉ DE PANELES (llamar al guardar datos)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: invalidarPanelesFast =====

function invalidarPanelesFast() {
  var hoy = _date(new Date());
  try { cache_delete("AOS_PANEL_ADMIN_" + hoy); } catch(e) {}
  try { cache_delete("AOS_DASH_KPIS_"   + hoy); } catch(e) {}
  try { cache_delete("AOS_DASH_SEM_"    + hoy); } catch(e) {}
  // Refrescar vista materializada de llamadas
  try { _sbRequest("POST", "rpc/aos_refresh_llammap", {}); } catch(e) {}
}
// ===== CTRL+F: invalidarPanelesFast_END =====


// ══════════════════════════════════════════════════════════════
// TEST
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: test_PanelesFast =====

function test_PanelesFast() {
  Logger.log("=== TEST FASE 1 — Paneles Fast ===");

  var t1 = new Date().getTime();
  var r1 = api_getPanelAdminFastT("dummy"); // usará sesión si existe
  Logger.log("Panel Admin: " + (new Date().getTime()-t1) + "ms | Supabase: " + (r1.fromSupabase ? "✅" : "❌ (fallback)"));
  if (r1.ok && r1.kpis) {
    Logger.log("  KPIs: llamHoy=" + r1.kpis.llamHoy + " citasHoy=" + r1.kpis.citasHoy);
    Logger.log("  Semáforo asesores: " + ((r1.semaforo && r1.semaforo.filas) ? r1.semaforo.filas.length : 0));
  }

  Logger.log("=== FIN TEST ===");
}
// ===== CTRL+F: test_PanelesFast_END =====


// ══════════════════════════════════════════════════════════════
// HELPER — Cálculo comisiones asesor (usado por F01)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: _calcComisionesAsesor =====

function _calcComisionesAsesor(s, now) {
  // Usa caché si está disponible
  var cacheKey = "AOS_COM_" + s.idAsesor + "_" + (now.getMonth()+1) + "_" + now.getFullYear();
  try {
    var cached = cache_get(cacheKey);
    if (cached) return cached;
  } catch(e) {}

  try {
    var mes  = now.getMonth() + 1;
    var anio = now.getFullYear();
    var shV  = _sh(CFG.SHEET_VENTAS);
    var lrV  = shV.getLastRow();
    var desde = new Date(anio, mes-1, 1, 0,0,0);
    var hasta = new Date(anio, mes, 0, 23,59,59);
    var total = 0, count = 0;

    if (lrV >= 2) {
      shV.getRange(2, 1, lrV-1, 12).getValues().forEach(function(r) {
        if (!_inRango(r[VENT_COL.FECHA], desde, hasta)) return;
        if (_up(r[VENT_COL.ASESOR]) !== _up(s.asesor)) return;
        total += Number(r[VENT_COL.MONTO]) || 0;
        count++;
      });
    }

    var meta    = 100; // default — se carga de RRHH
    var asesores = _asesoresRaw();
    var myRRHH  = asesores.find(function(a) { return a.idAsesor === s.idAsesor; });
    if (myRRHH && myRRHH.meta) meta = myRRHH.meta;

    var pct = meta > 0 ? Math.round(total / meta * 100) : 0;
    var result = { total: total, count: count, meta: meta, pct: pct };
    try { cache_set(cacheKey, result, 300); } catch(e) {} // 5 min caché
    return result;
  } catch(e) { return null; }
}
// ===== CTRL+F: _calcComisionesAsesor_END =====


// ══════════════════════════════════════════════════════════════
// F04 · CALL CENTER INICIO — 1 solo request
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getCallCenterInicioT =====

/**
 * Devuelve todo lo que necesita el call center al abrir.
 * Reemplaza: loadMetrics + loadHistorial + loadFunnel (3 requests)
 * loadLead sigue separado — necesita lógica de tiers compleja
 * loadTrats sigue separado — es pequeño y estático
 *
 * Total requests al abrir: 5-8 → 3 (este + loadLead + loadTrats)
 * Tiempo: 3 × 1.5s en paralelo = ~3s vs ~10-15s antes
 */
function api_getCallCenterInicioT(token) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();
  var hoy = _date(now);
  var mesI = now.getFullYear() + "-" + String(now.getMonth()+1).padStart(2,"0") + "-01";

  try {
    var sbKey = _sbKey();
    if (sbKey) {
      var res = _sbRequest("POST", "rpc/aos_call_center_inicio", {
        body: {
          p_asesor:     _up(s.asesor),
          p_id_asesor:  s.idAsesor,
          p_hoy:        hoy,
          p_mes_inicio: mesI
        }
      });

      if (res.ok && res.data) {
        return { ok: true, fromSupabase: true,
          kpisHoy:     res.data.kpisHoy     || {},
          llamadasHoy: res.data.llamadasHoy || [],
          tipif:       res.data.tipif       || [],
          anual:       res.data.anual       || []
        };
      }
    }
  } catch(e) {
    Logger.log("api_getCallCenterInicioT Supabase error: " + e.message);
  }

  // Fallback: construir desde Sheets
  try {
    var hoyRes  = api_getMyCallsToday();
    var items   = (hoyRes && hoyRes.items) ? hoyRes.items : [];
    var scCnt   = items.filter(function(x){return x.estado==='SIN CONTACTO'||x.estado==='NO CONTESTA';}).length;
    var convPct = items.length > 0 ? Math.round((hoyRes.citas||0)/items.length*100) : 0;
    return {
      ok: true, fromSupabase: false,
      kpisHoy: {
        llamHoy: items.length, citasHoy: hoyRes.citas||0,
        sinCont: scCnt, convPct: convPct,
        llamMes: 0, citasMes: 0, leadsMes: 0, ranking: 99
      },
      llamadasHoy: items,
      tipif: [], anual: []
    };
  } catch(e2) {
    return { ok: false, error: e2.message };
  }
}
// ===== CTRL+F: api_getCallCenterInicioT_END =====