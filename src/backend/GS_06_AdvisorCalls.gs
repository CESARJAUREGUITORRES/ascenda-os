/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_06_AdvisorCalls.gs                      ║
 * ║  Módulo: Panel Call Center Asesor                           ║
 * ║  Versión: 3.1.0 — 100% Supabase (SES-009 final)            ║
 * ║  Dependencias: GS_25_SupabaseSync (_sbRequest, SB_URL)      ║
 * ║                GS_02_Auth (_setToken, cc_requireSession)     ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * REGLA DE ORO:
 *   LECTURAS  → 100% Supabase (este archivo)
 *   ESCRITURAS → da_saveCallOutcome en GS_04 (Sheets + sync SB)
 *
 * RPCS VERIFICADAS (11/04/2026):
 *   aos_siguiente_lead   → {ok, lead:{num,trat,anuncio,fecha,intento,rowNum}, tier, tierNum}
 *   aos_cola_leads       → {ok, leads:[{num,trat,anuncio,fecha,intento,prioridad,tipo}], stats}
 *   aos_panel_asesor     → {llamHoy,citasHoy,llamMes,citasMes,asistMes,ventasMes,factMes,
 *                           leadsNuevos,leadsLlamados,leadsCitas,
 *                           llamadasHoy[{hora,num,trat,estado,subEstado,obs}],
 *                           tipifMes[{estado,cnt}], resumenAnual[], ventasAnual[]}
 *   aos_comisiones_asesor → {comTotal,comServ,comProd,factTotal,nVentas,meta,pct,ranking,
 *                            detalle[],anual[],topClientes[]}
 *   aos_get_seguimientos  → tabla {id,fecha_prog,hora_prog,numero,tratamiento,obs,tipo,whatsapp}
 *   aos_semana_asesor     → {dias:[{fecha,dia,dia_sem,es_hoy,es_pasado,tiene_turno,llamadas}]}
 *   aos_search_pacientes  → [{nombres,apellidos,telefono,sede,estado}]
 *   aos_get_historial_paciente → {paciente,ventas[],citas[],llamadas[],totalFact,...}
 *   aos_get_tratamientos  → [{nombre}]
 *   aos_cerrar_seguimiento → void
 *   aos_monitoreo_equipo  → {filas[{nombre,id_asesor,llamadas,citas,fact}]}
 */


// ══════════════════════════════════════════════════════════════
// IDs GOOGLE CALENDAR (sin cambios)
// ══════════════════════════════════════════════════════════════
var HORARIO_DOCTOR_CAL_ID   = "3784316650e1124f3eb82be4f123001347a18fb1808e4292e0d0503925d4f967@group.calendar.google.com";
var HORARIO_PERSONAL_CAL_ID = "2db1abef4cf3589e8646a162324c5818ef5732918ae8a113c1792e759a43e0c2@group.calendar.google.com";


// ══════════════════════════════════════════════════════════════
// UTIL · HELPERS INTERNOS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: _sbRpc =====

function _sbRpc(nombre, params) {
  try {
    var r = _sbRequest('POST', 'rpc/' + nombre, { body: params || {} });
    if (!r || !r.ok) { Logger.log('[SB] ' + nombre + ': ' + JSON.stringify(r)); return null; }
    return r.data;
  } catch (e) { Logger.log('[SB] ' + nombre + ' exc: ' + e.message); return null; }
}

function _ctx(token) {
  try {
    _setToken(token);
    var s = cc_requireSession();
    return { ok: true, asesor: (s.asesor||'').toUpperCase(), idAsesor: s.idAsesor||'', role: s.role||'', sede: s.sede||'' };
  } catch (e) { return { ok: false, msg: e.message }; }
}

function _hoy()   { return Utilities.formatDate(new Date(), 'America/Lima', 'yyyy-MM-dd'); }
function _mesIni(){ return _hoy().slice(0, 7) + '-01'; }


// ══════════════════════════════════════════════════════════════
// MOD-01 · SIGUIENTE LEAD (cola pre-cargada)
// RPC: aos_siguiente_lead → {ok, lead:{num,trat,...}, tier}
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getNextLeadT =====

function api_getNextLeadT(token) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, sin_leads: true, msg: 'Sin sesión' };
  try {
    var d = _sbRpc('aos_siguiente_lead', { p_asesor: c.asesor, p_id_asesor: c.idAsesor, p_hoy: _hoy() });
    if (!d || !d.ok || !d.lead) return { ok: false, sin_leads: true, msg: (d && d.msg) || 'Sin leads pendientes.' };
    var l = d.lead;
    return {
      ok: true,
      lead: { num: l.num||'', trat: l.trat||'', intento: l.intento||1, rowNum: l.rowNum||0,
               fecha: String(l.fecha||''), wa: 'https://wa.me/51'+(l.num||'').replace(/\D/g,''),
               contexto: l.contexto||null },
      tier:    d.tier    || 'TIER 1',
      tierNum: d.tierNum || 1,
      anuncio: { nombre: l.anuncio||l.trat||'', pregunta: l.anuncio?('¿Te interesa '+l.anuncio+'?'):'' }
    };
  } catch (e) { Logger.log('getNextLead: '+e.message); return { ok: false, sin_leads: true, msg: 'Error al cargar lead' }; }
}

// ===== CTRL+F: api_cargarColaLeadsT =====
// Carga 20 leads de la Lógica Madre (8 tiers) para la cola pre-cargada
// RPC: aos_cola_leads → {ok, leads:[...], stats}  ← KEY: "leads" (no "items")

function api_cargarColaLeadsT(token, tipoCola) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, items: [] };
  try {
    var d = _sbRpc('aos_cola_leads', { p_asesor: c.asesor, p_id_asesor: c.idAsesor, p_hoy: _hoy(), p_limite: 20, p_tipo_cola: tipoCola||'global' });
    if (!d || !d.leads) return { ok: false, items: [] };
    var items = (d.leads||[]).map(function(l) {
      return { num: l.num||'', trat: l.trat||'', intento: l.intento||1, rowNum: 0,
               fecha: String(l.fecha||''), wa: 'https://wa.me/51'+(l.num||'').replace(/\D/g,''),
               tier: l.tipo||'', anuncio: { nombre: l.anuncio||l.trat||'', pregunta: '' } };
    });
    return { ok: true, items: items, total: items.length, stats: d.stats||{} };
  } catch (e) { Logger.log('cargarCola: '+e.message); return { ok: false, items: [] }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-02 · GUARDAR LLAMADA (escritura — delega a GS_04)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_saveCallT =====

function api_saveCallT(token, payload) { _setToken(token); return api_saveCall(payload); }


// ══════════════════════════════════════════════════════════════
// MOD-03 · LLAMADAS DE HOY + DATOS DEL MES
// RPC: aos_panel_asesor
// Alimenta: KPI cards + tabla historial + score panel
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getMyCallsTodayT =====

function api_getMyCallsTodayT(token) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, items: [], total: 0, citas: 0 };
  try {
    var d = _sbRpc('aos_panel_asesor', { p_asesor: c.asesor, p_id_asesor: c.idAsesor, p_hoy: _hoy(), p_mes_inicio: _mesIni() });
    if (!d) return { ok: false, items: [], total: 0, citas: 0 };
    var items = (d.llamadasHoy||[]).map(function(l) {
      return { hora: String(l.hora||'').slice(0,5), num: l.num||'', trat: l.trat||'',
               estado: l.estado||'', subEstado: l.subEstado||'', obs: l.obs||'' };
    });
    return {
      ok: true, items: items, total: Number(d.llamHoy)||0, citas: Number(d.citasHoy)||0,
      datos: { llamadas: Number(d.llamMes)||0, citas: Number(d.citasMes)||0, asistieron: Number(d.asistMes)||0,
               ventas: Number(d.ventasMes)||0, fact: parseFloat(d.factMes)||0, clientesUnicos: 0 }
    };
  } catch (e) { Logger.log('getCallsToday: '+e.message); return { ok: false, items: [], total: 0, citas: 0 }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-04 · SCORE POR MES / TABLA ANUAL
// RPC: aos_panel_asesor (extrae resumenAnual + ventasAnual)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getMyScoreMesT =====

function api_getMyScoreMesT(token, mes, anio) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false };
  var now = new Date();
  mes  = Number(mes)  || (now.getMonth()+1);
  anio = Number(anio) || now.getFullYear();
  var mesStr = anio+'-'+(mes<10?'0'+mes:mes)+'-01';
  var mesKey = anio+'-'+(mes<10?'0'+mes:mes);
  try {
    var d = _sbRpc('aos_panel_asesor', { p_asesor: c.asesor, p_id_asesor: c.idAsesor, p_hoy: _hoy(), p_mes_inicio: mesStr });
    if (!d) return { ok: false };
    var esActual = (mes===now.getMonth()+1 && anio===now.getFullYear());
    var rMes = (d.resumenAnual||[]).filter(function(r){return String(r.mesKey||'').slice(0,7)===mesKey;})[0]||null;
    var vMes = (d.ventasAnual ||[]).filter(function(v){return String(v.mesKey||'').slice(0,7)===mesKey;})[0]||null;
    return { ok: true, datos: {
      llamadas:   esActual?(Number(d.llamMes)||0):(rMes?Number(rMes.llamadas):0),
      citas:      esActual?(Number(d.citasMes)||0):(rMes?Number(rMes.citas):0),
      asistieron: esActual?(Number(d.asistMes)||0):0,
      ventas:     esActual?(Number(d.ventasMes)||0):(vMes?Number(vMes.ventas):0),
      fact:       esActual?(parseFloat(d.factMes)||0):(vMes?parseFloat(vMes.fact)||0:0),
      clientesUnicos: 0, mes: mes, anio: anio
    }};
  } catch (e) { Logger.log('getScoreMes: '+e.message); return { ok: false }; }
}

// ===== CTRL+F: api_getMyCallsByMesT =====
// Devuelve items del mes para calcular tipificaciones en el frontend

function api_getMyCallsByMesT(token, mes, anio) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, items: [] };
  var now = new Date();
  mes  = Number(mes)  || (now.getMonth()+1);
  anio = Number(anio) || now.getFullYear();
  var mesStr = anio+'-'+(mes<10?'0'+mes:mes)+'-01';
  try {
    var d = _sbRpc('aos_panel_asesor', { p_asesor: c.asesor, p_id_asesor: c.idAsesor, p_hoy: _hoy(), p_mes_inicio: mesStr });
    if (!d) return { ok: false, items: [] };
    // Expandir tipifMes a items individuales para compatibilidad con el frontend
    var items = [];
    (d.tipifMes||[]).forEach(function(t){ for(var i=0;i<Number(t.cnt||0);i++) items.push({estado:t.estado||''}); });
    return { ok: true, items: items, total: items.length };
  } catch (e) { Logger.log('getCallsByMes: '+e.message); return { ok: false, items: [] }; }
}

// ══════════════════════════════════════════════════════════════
// MOD-04b · HISTÓRICO ANUAL COMPLETO (UNA sola llamada)
// RPC: aos_historico_asesor_anual
// Reemplaza las 12 llamadas paralelas de loadTablaAnual
// Out: {ok, anio, meses:[{mes_num,mes_label,llamadas,citas,asistieron,ventas,fact,es_actual}]}
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getHistoricoAnualAsesorT =====

function api_getHistoricoAnualAsesorT(token, anio) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, meses: [] };
  anio = Number(anio) || new Date().getFullYear();
  try {
    var d = _sbRpc('aos_historico_asesor_anual', {
      p_asesor:    c.asesor,
      p_id_asesor: c.idAsesor,
      p_anio:      anio
    });
    if (!d) return { ok: false, meses: [] };
    return { ok: true, anio: anio, meses: d.meses || [] };
  } catch (e) { Logger.log('getHistoricoAnual: '+e.message); return { ok: false, meses: [] }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-05 · PANEL FAST HOME (embudo + comisiones reales)
// RPC: aos_panel_asesor + aos_comisiones_asesor
// IMPORTANTE: comisiones ≠ facturación. comTotal = S/38.94 (no S/9094)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getPanelAsesorFastT =====

function api_getPanelAsesorFastT(token) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false };
  var now = new Date();
  try {
    var d = _sbRpc('aos_panel_asesor', { p_asesor: c.asesor, p_id_asesor: c.idAsesor, p_hoy: _hoy(), p_mes_inicio: _mesIni() });
    if (!d) return { ok: false };

    // Comisiones reales desde la RPC específica
    var com = _sbRpc('aos_comisiones_asesor', {
      p_asesor: c.asesor, p_id_asesor: c.idAsesor,
      p_mes: now.getMonth()+1, p_anio: now.getFullYear()
    });

    var comTotal = com ? (parseFloat(com.comTotal)||0) : 0;
    var meta     = com ? (parseFloat(com.meta)||100)   : 100;
    var pct      = com ? (Number(com.pct)||0)          : 0;
    var ranking  = com ? ('#'+(com.ranking||1))        : '#1';

    return {
      ok: true,
      embudo: {
        llamadas:   Number(d.llamMes)  ||0,
        citas:      Number(d.citasMes) ||0,
        asistieron: Number(d.asistMes) ||0,
        ventas:     Number(d.ventasMes)||0,
        fact:       parseFloat(d.factMes)||0
      },
      comisiones: { total: comTotal, meta: meta, pct: pct, rank: ranking }
    };
  } catch (e) { Logger.log('getPanelFast: '+e.message); return { ok: false }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-06 · CALENDARIO DE SEMANA (Home)
// RPC: aos_semana_asesor → {dias[{fecha,dia,dia_sem,es_hoy,es_pasado,tiene_turno}]}
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getMisSemanaT =====

function api_getMisSemanaT(token) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, dias: [] };
  var now = new Date(), dow = now.getDay();
  var lunes = new Date(now);
  lunes.setDate(now.getDate() + (dow===0?-6:1-dow));
  lunes.setHours(0,0,0,0);
  var lunesStr = Utilities.formatDate(lunes,'America/Lima','yyyy-MM-dd');
  var hoyStr   = _hoy();
  try {
    var r = _sbRpc('aos_semana_asesor', { p_asesor: c.asesor, p_fecha_lunes: lunesStr });
    if (!r || !r.dias) return _semanaVacia(lunesStr, hoyStr);
    var dias = (r.dias||[]).map(function(d) {
      return { fecha: d.fecha||'', dia: parseInt(d.dia,10)||0,
               diaSem: String(d.dia_sem||'').slice(0,2),
               esHoy: !!d.es_hoy, esPasado: !!d.es_pasado,
               tieneTurno: !!d.tiene_turno, sede: d.tiene_turno?'SAN ISIDRO':'',
               llamadas: Number(d.llamadas)||0 };
    });
    return { ok: true, dias: dias };
  } catch (e) { Logger.log('getMisSemana: '+e.message); return _semanaVacia(lunesStr, hoyStr); }
}

function _semanaVacia(lunesStr, hoyStr) {
  var n=['LU','MA','MI','JU','VI','SA','DO'], out=[];
  for(var i=0;i<7;i++){var d=new Date(lunesStr+'T12:00:00');d.setDate(d.getDate()+i);var f=Utilities.formatDate(d,'America/Lima','yyyy-MM-dd');out.push({fecha:f,dia:d.getDate(),diaSem:n[i],esHoy:f===hoyStr,esPasado:f<hoyStr,tieneTurno:false,sede:'',llamadas:0});}
  return { ok: true, dias: out };
}


// ══════════════════════════════════════════════════════════════
// MOD-07 · SEGUIMIENTOS DEL ASESOR
// RPC: aos_get_seguimientos → tabla {id,fecha_prog,hora_prog,numero,tratamiento,obs,tipo,whatsapp}
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getMySeguimientosT =====

function api_getMySeguimientosT(token) {
  var c = _ctx(token);
  if (!c.ok) return { ok: true, items: [], totales: {} };
  var hoy = _hoy();
  try {
    var rows = _sbRpc('aos_get_seguimientos', { p_asesor: c.asesor, p_id_asesor: c.idAsesor, p_hoy: hoy });
    if (!rows) return { ok: true, items: [], totales: {} };
    var arr = Array.isArray(rows) ? rows : [];
    var items = arr.map(function(s) {
      var fecha = s.fecha_prog ? String(s.fecha_prog).slice(0,10) : '';
      var hora  = s.hora_prog  ? String(s.hora_prog).slice(0,5)  : '';
      var venc  = fecha && fecha < hoy;
      var esHoy = fecha === hoy;
      return {
        segId:    s.id||'', num: s.numero||'', trat: s.tratamiento||'', obs: s.obs||'',
        fecha: fecha, hora: hora,
        fechaHora: fecha ? (fecha+(hora?' '+hora:'')) : '',
        vencido: venc && !esHoy, esHoy: esHoy,
        tipo: s.tipo||(venc?'vencido':esHoy?'hoy':'proximo'),
        whatsapp: s.whatsapp||('https://wa.me/51'+(s.numero||'').replace(/\D/g,''))
      };
    });
    var totales = {
      vencido: items.filter(function(x){return x.vencido;}).length,
      hoy:     items.filter(function(x){return x.esHoy;}).length,
      proximo: items.filter(function(x){return !x.vencido&&!x.esHoy;}).length,
      total:   items.length
    };
    return { ok: true, items: items, totales: totales };
  } catch (e) { Logger.log('getMisSegs: '+e.message); return { ok: true, items: [], totales: {} }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-08 · CERRAR SEGUIMIENTO
// RPC: aos_cerrar_seguimiento → void
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_cerrarSeguimientoT =====

function api_cerrarSeguimientoT(token, segId) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false };
  try { _sbRpc('aos_cerrar_seguimiento', { p_id: String(segId) }); return { ok: true }; }
  catch (e) { Logger.log('cerrarSeg: '+e.message); return { ok: false }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-09 · BÚSQUEDA LIVE DE PACIENTES
// RPC: aos_search_pacientes → [{nombres,apellidos,telefono,sede,estado}]
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_searchPatientsLiveT =====

function api_searchPatientsLiveT(token, query) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, items: [] };
  query = String(query||'').trim();
  if (query.length < 2) return { ok: true, items: [] };
  try {
    var rows = _sbRpc('aos_search_pacientes', { p_query: query, p_limit: 8 });
    if (!rows) return { ok: false, items: [] };
    var items = (Array.isArray(rows)?rows:[]).map(function(p){
      return { nombres: p.nombres||'', apellidos: p.apellidos||'', telefono: p.telefono||'', sede: p.sede||'', trat: '', estado: p.estado||'ACTIVO' };
    });
    return { ok: true, items: items };
  } catch (e) { Logger.log('searchPat: '+e.message); return { ok: false, items: [] }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-10 · FICHA PACIENTE 360°
// RPC: aos_get_historial_paciente → {paciente,ventas[],citas[],llamadas[],totalFact,...}
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getPatient360T =====

function api_getPatient360T(token, num) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false };
  num = String(num||'').replace(/\D/g,'');
  if (!num) return { ok: false };
  try {
    var d = _sbRpc('aos_get_historial_paciente', { p_numero: num });
    if (!d) return { ok: false };
    return {
      ok: true, num: num,
      paciente:       d.paciente||{},
      compras:        d.ventas||[],
      citas:          d.citas||[],
      llamadas:       d.llamadas||[],
      totalFact:      parseFloat(d.totalFact)||0,
      totalCompras:   Number(d.totalCompras)||0,
      totalCitas:     Number(d.totalCitas)||0,
      totalContactos: Number(d.totalContactos)||0,
      whatsapp: 'https://wa.me/51'+num
    };
  } catch (e) { Logger.log('getPatient360: '+e.message); return { ok: false }; }
}

function api_getPatientProfileT(token, num) {
  var r = api_getPatient360T(token, num);
  return (r&&r.ok)?{ok:true, paciente:r.paciente}:{ok:false};
}

function api_saveNotasPacienteT(token, num, notas) {
  _setToken(token);
  return api_updatePatientNotes?api_updatePatientNotes(num,notas):{ok:false};
}


// ══════════════════════════════════════════════════════════════
// MOD-11 · TOP CLIENTES DEL ASESOR (facturación histórica total)
// RPC: aos_top_clientes_asesor → {ok, items:[{num,nombre,compras,
//       total_historico,ult_compra,ult_fecha_cita,ult_estado_cita}]}
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getMyTopClientesT =====

function api_getMyTopClientesT(token, limit) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, items: [] };
  limit = Number(limit)||20;
  try {
    var d = _sbRpc('aos_top_clientes_asesor', {
      p_asesor:    c.asesor,
      p_id_asesor: c.idAsesor,
      p_limite:    limit
    });
    if (!d || !d.items) return { ok: false, items: [] };
    var items = (d.items||[]).map(function(cl, i) {
      var ultV = cl.ult_compra || '';
      return {
        pos:             i+1,
        nombre:          cl.nombre || cl.num || '—',
        num:             cl.num    || '',
        fact:            parseFloat(cl.total_historico) || 0,
        nVentas:         Number(cl.compras) || 0,
        ultVisita:       ultV,
        ult_compra:      cl.ult_compra      || '',
        ult_fecha_cita:  cl.ult_fecha_cita  || '',
        ult_estado_cita: cl.ult_estado_cita || '',
        wa: 'https://wa.me/51'+(cl.num||'').replace(/\D/g,'')
      };
    });
    return { ok: true, items: items, total: items.length };
  } catch (e) { Logger.log('getTopClientes: '+e.message); return { ok: false, items: [] }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-12 · CATÁLOGO DE TRATAMIENTOS
// RPC: aos_get_tratamientos → [{nombre}]
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_listTratamientosT =====

function api_listTratamientosT(token) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, items: [] };
  try {
    var rows = _sbRpc('aos_get_tratamientos', {});
    if (!rows) return { ok: false, items: [] };
    var items = (Array.isArray(rows)?rows:[]).map(function(r){return r.nombre||'';}).filter(Boolean);
    return { ok: true, items: items };
  } catch (e) { Logger.log('listTrats: '+e.message); return { ok: false, items: [] }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-13 · ESTADO DEL ASESOR
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_setEstadoAsesorT =====

function api_setEstadoAsesorT(token, estado) {
  _setToken(token);
  try { api_setEstadoAsesor(estado); } catch(e) {}
  return { ok: true };
}


// ══════════════════════════════════════════════════════════════
// MOD-14 · RANKING DEL EQUIPO
// RPC: aos_monitoreo_equipo → {filas[{nombre,id_asesor,llamadas,citas,fact}]}
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getTeamRankingT =====

function api_getTeamRankingT(token) {
  var c = _ctx(token);
  if (!c.ok) return { ok: false, ranking: [] };
  try {
    var d = _sbRpc('aos_monitoreo_equipo', { p_hoy: _hoy() });
    if (!d) return { ok: false, ranking: [] };
    var ranking = (d.filas||[]).map(function(f,i){
      return { pos:i+1, nombre:f.nombre||'', idAsesor:f.id_asesor||'', llamadas:Number(f.llamadas)||0, citas:Number(f.citas)||0, fact:parseFloat(f.fact)||0 };
    });
    return { ok: true, ranking: ranking };
  } catch (e) { Logger.log('getTeamRanking: '+e.message); return { ok: false, ranking: [] }; }
}


// ══════════════════════════════════════════════════════════════
// MOD-15 · CALENDARIO DE DISPONIBILIDAD
// Fuente PRIMARIA: aos_horarios_semana (Supabase) — rápido, sin OAuth
// Fuente SECUNDARIA: Google Calendar (fallback para cuando no hay datos en SB)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getSemanaCalT =====
// Parámetros: token, semanaOffset (ignorado si se pasa lunesStr), sede, lunesStr (opcional)

function api_getSemanaCalT(token, semanaOffset, sede, lunesStr) {
  _setToken(token); cc_requireSession();
  sede = (sede || '').toUpperCase();

  var now   = new Date(), dow = now.getDay();
  var lunes;
  if (lunesStr) {
    // Usar el lunes exacto que pasó el frontend
    lunes = new Date(lunesStr + 'T12:00:00');
  } else {
    semanaOffset = semanaOffset || 0;
    lunes = new Date(now);
    lunes.setDate(now.getDate() + (dow === 0 ? -6 : 1 - dow) + semanaOffset * 7);
  }
  lunes.setHours(0, 0, 0, 0);
  var lunesISO = Utilities.formatDate(lunes, 'America/Lima', 'yyyy-MM-dd');
  var hoy      = _hoy();

  var DIAS_ES = {1:'LU',2:'MA',3:'MI',4:'JU',5:'VI',6:'SA',0:'DO'};

  try {
    // ── Leer de Supabase (fuente primaria) ──────────────────
    var sb = _sbRpc('aos_horarios_semana', {
      p_fecha_lunes: lunesISO,
      p_sede:        sede || '',
      p_rol:         ''
    });

    if (sb && sb.ok && sb.dias && sb.dias.length) {
      var diasSB = sb.dias.map(function(d) {
        var turnos = d.turnos || [];
        var doctoras   = turnos.filter(function(t){ return t.rol === 'DOCTORA'; });
        var enfermeria = [];
        var porSede = {};
        turnos.filter(function(t){ return t.rol === 'ENFERMERIA'; }).forEach(function(t){
          if (!porSede[t.sede]) porSede[t.sede] = [];
          porSede[t.sede].push(t.personal);
        });
        Object.keys(porSede).forEach(function(s){ enfermeria.push({ sede: s, nombres: porSede[s] }); });

        return {
          fecha:      d.fecha,
          dia:        new Date(d.fecha + 'T12:00:00').getDate(),
          diaSem:     d.dia_sem || 'LU',
          estado:     turnos.length ? 'disponible' : 'sin_horario',
          doctoras:   doctoras.map(function(doc){
            return { label: doc.personal, tipo: doc.tipo_turno, horaIni: doc.hora_inicio, horaFin: doc.hora_fin, sede: doc.sede };
          }),
          enfermeria: enfermeria,
          esHoy:      d.fecha === hoy,
          esPasado:   d.fecha < hoy
        };
      });

      return { ok: true, semanaOffset: semanaOffset, dias: diasSB, fuente: 'supabase', desde: lunesISO, hasta: sb.domingo || '' };
    }
  } catch (eS) { Logger.log('CalSB error: ' + eS.message); }

  // ── Fallback: Google Calendar REST API ─────────────────────
  var hasta = new Date(lunes); hasta.setDate(lunes.getDate() + 6); hasta.setHours(23, 59, 59);
  var evDocRes = _leerEventosCalendarRango(HORARIO_DOCTOR_CAL_ID,   lunes, hasta);
  var evEnfRes = _leerEventosCalendarRango(HORARIO_PERSONAL_CAL_ID, lunes, hasta);
  var resultado = [];

  for (var i = 0; i < 7; i++) {
    var d = new Date(lunes); d.setDate(lunes.getDate() + i);
    var fd = Utilities.formatDate(d, 'America/Lima', 'yyyy-MM-dd');
    var doctoras = [], enfermeria = [];
    (evDocRes[fd] || []).forEach(function(ev) {
      var p = _parsearEventoDoctor(ev.titulo), s = _sedeDesdeLocation(ev.location || '');
      if (sede && s && s !== sede) return;
      doctoras.push({ label: p.nombre, tipo: p.tipo, horaIni: ev.horaIni, horaFin: ev.horaFin, sede: s });
    });
    var porSede = {};
    (evEnfRes[fd] || []).forEach(function(ev) {
      var nombre = _parsearNombreEnfermero(ev.titulo), s = _sedeDesdeLocation(ev.location || '');
      if (!nombre || (sede && s && s !== sede)) return;
      if (!porSede[s]) porSede[s] = []; porSede[s].push(nombre);
    });
    Object.keys(porSede).forEach(function(s) { enfermeria.push({ sede: s, nombres: porSede[s] }); });
    resultado.push({
      fecha: fd, dia: d.getDate(), diaSem: DIAS_ES[d.getDay()],
      estado: (!doctoras.length && !enfermeria.length) ? 'sin_horario' : 'disponible',
      doctoras: doctoras, enfermeria: enfermeria,
      esHoy: fd === hoy, esPasado: d < new Date(now.getFullYear(), now.getMonth(), now.getDate())
    });
  }
  return { ok: true, semanaOffset: semanaOffset, dias: resultado, fuente: 'gcal', desde: lunesStr, hasta: Utilities.formatDate(hasta, 'America/Lima', 'yyyy-MM-dd') };
}

function _parsearEventoDoctor(s){s=s||'';var t=s.match(/\(([^)]+)\)/);var tipo=t?t[1].toUpperCase():'CONSULTA';var nombre=s.replace(/\([^)]*\)/g,'').replace(/\s+\d{1,2}[:.:]?\d{0,2}\s*[aApP][mM].*$/,'').trim().toUpperCase();return{nombre:nombre||s.trim().toUpperCase(),tipo:tipo};}
function _parsearNombreEnfermero(s){var m=(s||'').match(/([A-ZÁÉÍÓÚÑ]{3,})/);if(!m)return'';var n=m[1].toUpperCase();return['TURNO','ENFERMERIA','VITAL','SAN','ISIDRO','PUEBLO','LIBRE'].indexOf(n)>=0?'':n;}
function _sedeDesdeLocation(loc){loc=(loc||'').toLowerCase();if(loc.indexOf('brasil')>=0||loc.indexOf('pueblo libre')>=0)return'PUEBLO LIBRE';if(loc.indexOf('javier prado')>=0||loc.indexOf('san isidro')>=0)return'SAN ISIDRO';return'';}
/**
 * _leerEventosCalendarRango
 * Usa Calendar REST API v3 para leer calendarios de grupo compartidos.
 * CalendarApp.getCalendarById() falla con group calendars externos.
 * La REST API funciona mientras el script tenga scope calendar.readonly.
 */
function _leerEventosCalendarRango(calId, desde, hasta) {
  var result = {};
  var TZ = (CFG && CFG.TZ) ? CFG.TZ : 'America/Lima';

  // ── Intento 1: CalendarApp (funciona si el calendar es de la cuenta del script)
  try {
    var cal = CalendarApp.getCalendarById(calId);
    if (cal) {
      cal.getEvents(desde, hasta).forEach(function(ev) {
        var start = ev.getStartTime(), end = ev.getEndTime(), allDay = ev.isAllDayEvent();
        var titulo = ev.getTitle() || '', loc = ev.getLocation() || '';
        var dia = new Date(start.getFullYear(), start.getMonth(), start.getDate());
        var diaFin = new Date(end.getFullYear(), end.getMonth(), end.getDate());
        if (allDay) diaFin.setDate(diaFin.getDate() - 1);
        while (dia <= diaFin) {
          var fd = Utilities.formatDate(dia, TZ, 'yyyy-MM-dd');
          if (!result[fd]) result[fd] = [];
          result[fd].push({
            titulo:  titulo,
            horaIni: allDay ? '' : Utilities.formatDate(start, TZ, 'HH:mm'),
            horaFin: allDay ? '' : Utilities.formatDate(end,   TZ, 'HH:mm'),
            location: loc, allDay: allDay
          });
          dia.setDate(dia.getDate() + 1);
        }
      });
      // Si encontró eventos, devolver — si no, también devolver (puede estar vacío)
      return result;
    }
  } catch(e1) { Logger.log('Cal CalendarApp['+calId.slice(0,20)+']: ' + e1.message); }

  // ── Intento 2: Calendar REST API v3 (funciona con calendarios de grupo compartidos)
  try {
    var token = ScriptApp.getOAuthToken();
    var timeMin = Utilities.formatDate(desde, TZ, "yyyy-MM-dd'T'HH:mm:ss") + 'Z';
    var timeMax = Utilities.formatDate(hasta, TZ, "yyyy-MM-dd'T'HH:mm:ss") + 'Z';
    var url = 'https://www.googleapis.com/calendar/v3/calendars/'
              + encodeURIComponent(calId)
              + '/events?timeMin=' + encodeURIComponent(timeMin)
              + '&timeMax=' + encodeURIComponent(timeMax)
              + '&singleEvents=true&orderBy=startTime&maxResults=100';
    var resp = UrlFetchApp.fetch(url, {
      headers: { Authorization: 'Bearer ' + token },
      muteHttpExceptions: true
    });
    if (resp.getResponseCode() !== 200) {
      Logger.log('Cal REST['+calId.slice(0,20)+']: HTTP ' + resp.getResponseCode());
      return result;
    }
    var data = JSON.parse(resp.getContentText());
    (data.items || []).forEach(function(ev) {
      var titulo  = ev.summary  || '';
      var loc     = ev.location || '';
      var allDay  = !!(ev.start && ev.start.date && !ev.start.dateTime);
      var startDt = allDay ? new Date(ev.start.date + 'T00:00:00') : new Date(ev.start.dateTime);
      var endDt   = allDay ? new Date(ev.end.date   + 'T00:00:00') : new Date(ev.end.dateTime);
      var horaIni = allDay ? '' : Utilities.formatDate(startDt, TZ, 'HH:mm');
      var horaFin = allDay ? '' : Utilities.formatDate(endDt,   TZ, 'HH:mm');
      var dia = new Date(startDt.getFullYear(), startDt.getMonth(), startDt.getDate());
      var diaFin = new Date(endDt.getFullYear(), endDt.getMonth(), endDt.getDate());
      if (allDay) diaFin.setDate(diaFin.getDate() - 1);
      while (dia <= diaFin) {
        var fd = Utilities.formatDate(dia, TZ, 'yyyy-MM-dd');
        if (!result[fd]) result[fd] = [];
        result[fd].push({ titulo: titulo, horaIni: horaIni, horaFin: horaFin, location: loc, allDay: allDay });
        dia.setDate(dia.getDate() + 1);
      }
    });
  } catch(e2) { Logger.log('Cal REST['+calId.slice(0,20)+']: ' + e2.message); }

  return result;
}
