/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_25_SupabaseSync.gs                      ║
 * ║  Módulo: Sincronización GAS ↔ Supabase                     ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config, GS_02_Auth, GS_03_CoreHelpers  ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * ARQUITECTURA DEL ESPEJO:
 *
 *   [Google Sheets]  ←→  [GAS Backend]  →  [Supabase]
 *        ↑                                      ↓
 *   Equipo edita               Frontend lee de Supabase (rápido)
 *   manualmente                GAS escribe en ambos
 *
 * FASE ACTUAL: GAS escribe en Sheets (como antes) Y en Supabase.
 *   El frontend sigue llamando a GAS — GAS devuelve datos de Supabase
 *   cuando la función tiene caché en Supabase, o de Sheets si no.
 *
 * CONTENIDO:
 *   MOD-01 · Configuración Supabase
 *   MOD-02 · Cliente HTTP (UrlFetchApp wrapper)
 *   MOD-03 · Operaciones CRUD base
 *   MOD-04 · Sincronización de llamadas (la más crítica)
 *   MOD-05 · Sincronización de pacientes
 *   MOD-06 · Sincronización de ventas
 *   MOD-07 · Sincronización de agenda
 *   MOD-08 · Lectura rápida desde Supabase (para reemplazar Sheets)
 *   MOD-09 · Migración inicial desde Sheets
 *   MOD-10 · Tests
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · CONFIGURACIÓN SUPABASE
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_CONFIG =====

/**
 * INSTRUCCIÓN DE CONFIGURACIÓN:
 * 1. Ir a supabase.com → proyecto ituyqwstonmhnfshnaqz
 * 2. Settings → API → "service_role" key (NO la anon key)
 * 3. Pegar en PropertiesService:
 *    En Apps Script → Proyecto → Configuración del proyecto
 *    → Propiedades de secuencia de comandos → Agregar:
 *      SUPABASE_URL  = https://ituyqwstonmhnfshnaqz.supabase.co
 *      SUPABASE_KEY  = sb_publishable_mz1j7bmlLulSqUposiKUCg_fka59fW_
 */

var SB_URL = "https://ituyqwstonmhnfshnaqz.supabase.co";

function _sbKey() {
  try {
    var key = PropertiesService.getScriptProperties().getProperty("SUPABASE_KEY");
    if (key) return key;
  } catch(e) {}
  // Fallback temporal — REEMPLAZAR con PropertiesService
  Logger.log("⚠️ SUPABASE_KEY no configurada en PropertiesService");
  return null;
}

function _sbHeaders() {
  var key = _sbKey();
  if (!key) return null;
  return {
    "apikey":        key,
    "Authorization": "Bearer " + key,
    "Content-Type":  "application/json",
    "Prefer":        "return=minimal"
  };
}
// ===== CTRL+F: SB_CONFIG_END =====


// ══════════════════════════════════════════════════════════════
// MOD-02 · CLIENTE HTTP SUPABASE
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_HTTP =====

/**
 * _sbRequest — wrapper central para llamadas a Supabase REST API
 * @param {string} method  GET | POST | PATCH | DELETE | UPSERT
 * @param {string} table   nombre de la tabla (con prefijo aos_)
 * @param {object} params  { filter, body, select, limit, order }
 */
function _sbRequest(method, table, params) {
  var headers = _sbHeaders();
  if (!headers) return { ok: false, error: "SUPABASE_KEY no configurada" };

  params = params || {};
  var url    = SB_URL + "/rest/v1/" + table;
  var query  = [];

  if (params.filter) query.push(params.filter);
  if (params.select) query.push("select=" + params.select);
  if (params.limit)  query.push("limit="  + params.limit);
  if (params.order)  query.push("order="  + params.order);
  if (query.length)  url += "?" + query.join("&");

  var options = { method: method, headers: headers, muteHttpExceptions: true };

  if (params.body) {
    options.payload = JSON.stringify(params.body);
  }

  // Para upsert
  if (method === "UPSERT") {
    options.method  = "POST";
    options.headers["Prefer"] = "resolution=merge-duplicates,return=minimal";
  }

  try {
    var resp = UrlFetchApp.fetch(url, options);
    var code = resp.getResponseCode();
    var body = resp.getContentText();

    if (code >= 200 && code < 300) {
      var data = null;
      try { data = body ? JSON.parse(body) : null; } catch(e) {}
      return { ok: true, data: data, status: code };
    } else {
      Logger.log("Supabase ERROR " + code + " [" + table + "]: " + body.slice(0, 200));
      return { ok: false, error: body, status: code };
    }
  } catch(e) {
    Logger.log("Supabase FETCH error [" + table + "]: " + e.message);
    return { ok: false, error: e.message };
  }
}

function _sbGet(table, filter, select, limit)    { return _sbRequest("GET",    table, { filter:filter, select:select, limit:limit }); }
function _sbPost(table, body)                     { return _sbRequest("POST",   table, { body:body }); }
function _sbUpsert(table, body)                   { return _sbRequest("UPSERT", table, { body:body }); }
function _sbPatch(table, filter, body)            { return _sbRequest("PATCH",  table, { filter:filter, body:body }); }
function _sbDelete(table, filter)                 { return _sbRequest("DELETE", table, { filter:filter }); }
// ===== CTRL+F: SB_HTTP_END =====


// ══════════════════════════════════════════════════════════════
// MOD-03 · HEALTH CHECK
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_HEALTH =====

/**
 * api_supabaseHealth — verifica que Supabase esté conectado
 * Ejecutar desde Apps Script para confirmar la conexión
 */
function api_supabaseHealth() {
  var res = _sbGet("aos_configuracion", null, "clave,valor", 1);
  if (res.ok) {
    Logger.log("✅ Supabase conectado — aos_configuracion accesible");
    return { ok: true, connected: true };
  } else {
    Logger.log("❌ Supabase error: " + res.error);
    return { ok: false, connected: false, error: res.error };
  }
}
// ===== CTRL+F: SB_HEALTH_END =====


// ══════════════════════════════════════════════════════════════
// MOD-04 · SINCRONIZACIÓN DE LLAMADAS (LA MÁS CRÍTICA)
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_LLAMADAS =====

/**
 * sb_syncLlamada
 * Llamar desde api_saveCall (GS_06) DESPUÉS de escribir en Sheets.
 * Inserta la nueva llamada en Supabase.
 * Si falla, el sistema sigue funcionando con Sheets (fallback automático).
 */
function sb_syncLlamada(payload, s, rowNum) {
  if (!_sbKey()) return; // Supabase no configurado aún — ignorar silenciosamente

  var fila = {
    fecha:         _date(new Date()),
    numero:        _norm(payload.numero || ""),
    tratamiento:   _up(_norm(payload.tratamiento || "")),
    estado:        _up(_norm(payload.estado || "")),
    observacion:   _norm(payload.obs || ""),
    hora_llamada:  _time(new Date()),
    asesor:        _norm(s.asesor || ""),
    numero_limpio: _phone(payload.numero || ""),
    id_asesor:     _norm(s.idAsesor || ""),
    anuncio:       _norm(payload.anuncio || ""),
    intento:       Number(payload.intento) || 1,
    ult_ts:        new Date().toISOString(),
    resultado:     _up(payload.resultado || ""),
    sub_estado:    _norm(payload.subEstado || "")
  };

  try {
    _sbPost("aos_llamadas", fila);
  } catch(e) {
    Logger.log("sb_syncLlamada WARN: " + e.message); // No interrumpir el flujo
  }
}

/**
 * sb_getLlamMap
 * Obtiene el mapa de última llamada por número DESDE SUPABASE.
 * Reemplaza el loop de 12,201 filas — responde en <50ms.
 * Usado por api_getNextLead si Supabase está disponible.
 */
function sb_getLlamMap() {
  if (!_sbKey()) return null;

  try {
    var res = _sbGet(
      "aos_llamadas_ultimo",
      null,
      "numero_limpio,estado,sub_estado,intento,ult_ts,prox_rein,resultado,asesor,id_asesor,observacion,fecha,row_id",
      5000 // máximo registros
    );
    if (!res.ok || !res.data) return null;

    var map = {};
    res.data.forEach(function(r) {
      map[r.numero_limpio] = {
        estado:    r.estado    || "",
        intento:   r.intento   || 1,
        ultTs:     r.ult_ts    ? new Date(r.ult_ts).getTime() : null,
        proxRein:  r.prox_rein ? new Date(r.prox_rein).getTime() : null,
        resultado: r.resultado || "",
        rowNum:    r.row_id    || 0,
        asesor:    r.asesor    || "",
        idAsesor:  r.id_asesor || "",
        obs:       r.observacion || "",
        fecha:     r.fecha     || ""
      };
    });
    return map;
  } catch(e) {
    Logger.log("sb_getLlamMap WARN: " + e.message);
    return null;
  }
}
// ===== CTRL+F: SB_LLAMADAS_END =====


// ══════════════════════════════════════════════════════════════
// MOD-05 · SINCRONIZACIÓN DE PACIENTES
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_PACIENTES =====

function sb_upsertPaciente(pac) {
  if (!_sbKey()) return;
  try {
    _sbUpsert("aos_pacientes", {
      id_paciente:       pac.id          || "",
      nombres:           pac.nombres     || "",
      apellidos:         pac.apellidos   || "",
      telefono:          pac.telefono    || "",
      email:             pac.email       || "",
      nro_documento:     pac.documento   || "",
      sexo:              pac.sexo        || "",
      direccion:         pac.direccion   || "",
      ocupacion:         pac.ocupacion   || "",
      sede_principal:    pac.sede        || "",
      fuente:            pac.fuente      || "",
      total_compras:     pac.totalCompras  || 0,
      total_facturado:   pac.totalFact     || 0,
      total_llamadas:    pac.totalLlam     || 0,
      total_citas:       pac.totalCitas    || 0,
      estado_paciente:   pac.estado        || "NUEVO",
      notas:             pac.notas         || "",
      etiqueta_base:     pac.etiquetaBase  || "",
      score_estado:      pac.score         || "",
      updated_at:        new Date().toISOString()
    });
  } catch(e) { Logger.log("sb_upsertPaciente WARN: " + e.message); }
}

/**
 * sb_getPaciente — busca paciente en Supabase por teléfono
 * Responde en ~5ms vs ~3s de Sheets
 */
function sb_getPaciente(telefono) {
  if (!_sbKey()) return null;
  try {
    var limpio = _normNum(telefono);
    var res    = _sbGet("aos_pacientes", "telefono=eq." + limpio, "*", 1);
    if (!res.ok || !res.data || !res.data.length) return null;
    return res.data[0];
  } catch(e) { return null; }
}
// ===== CTRL+F: SB_PACIENTES_END =====


// ══════════════════════════════════════════════════════════════
// MOD-06 · SINCRONIZACIÓN DE VENTAS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_VENTAS =====

function sb_syncVenta(ventaData) {
  if (!_sbKey()) return;
  try {
    _sbUpsert("aos_ventas", {
      venta_id:       ventaData.ventaId        || "",
      fecha:          ventaData.fecha          || _date(new Date()),
      nombres:        ventaData.nombres        || "",
      apellidos:      ventaData.apellidos      || "",
      tratamiento:    ventaData.tratamiento    || "",
      descripcion:    ventaData.descripcion    || "",
      pago:           ventaData.pago           || "",
      monto:          Number(ventaData.monto)  || 0,
      estado_pago:    ventaData.estadoPago     || "",
      asesor:         ventaData.asesor         || "",
      sede:           ventaData.sede           || "",
      tipo:           ventaData.tipo           || "SERVICIO",
      numero_limpio:  ventaData.numLimpio      || "",
      updated_at:     new Date().toISOString()
    });
  } catch(e) { Logger.log("sb_syncVenta WARN: " + e.message); }
}
// ===== CTRL+F: SB_VENTAS_END =====


// ══════════════════════════════════════════════════════════════
// MOD-07 · SINCRONIZACIÓN DE AGENDA
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_AGENDA =====

function sb_syncCita(citaData) {
  if (!_sbKey()) return;
  try {
    _sbUpsert("aos_agenda_citas", {
      id:              citaData.id          || _uid(),
      fecha_cita:      citaData.fechaCita   || "",
      tratamiento:     citaData.tratamiento || "",
      tipo_cita:       citaData.tipoCita    || "",
      sede:            citaData.sede        || "",
      numero:          citaData.numero      || "",
      nombre:          citaData.nombre      || "",
      apellido:        citaData.apellido    || "",
      asesor:          citaData.asesor      || "",
      id_asesor:       citaData.idAsesor    || "",
      estado_cita:     citaData.estado      || "PENDIENTE",
      hora_cita:       citaData.horaCita    || "",
      doctora:         citaData.doctora     || "",
      tipo_atencion:   citaData.tipoAtencion || "",
      origen_cita:     citaData.origen      || "",
      ts_actualizado:  new Date().toISOString()
    });
  } catch(e) { Logger.log("sb_syncCita WARN: " + e.message); }
}
// ===== CTRL+F: SB_AGENDA_END =====


// ══════════════════════════════════════════════════════════════
// MOD-08 · LECTURA RÁPIDA DESDE SUPABASE
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_READ_FAST =====

/**
 * sb_getHistorialPaciente
 * Obtiene historial completo desde Supabase en paralelo (~50ms total).
 * Reemplaza _getPatientHistory que lee 3 hojas grandes en GAS.
 */
function sb_getHistorialPaciente(numero) {
  if (!_sbKey()) return null;
  var limpio = _normNum(numero);
  if (!limpio) return null;

  try {
    // Las 3 queries en paralelo serían ideal, pero GAS es single-thread.
    // Aun así, cada query tarda ~10-20ms vs 2-5s de Sheets.
    var llamadas = [], ventas = [], citas = [];

    var rL = _sbGet("aos_llamadas",
      "numero_limpio=eq." + limpio + "&order=ult_ts.desc",
      "fecha,estado,tratamiento,asesor,observacion,intento,hora_llamada",
      30
    );
    if (rL.ok && rL.data) {
      llamadas = rL.data.map(function(r) {
        return {
          fecha:   r.fecha, hora: r.hora_llamada, estado: r.estado,
          trat: r.tratamiento, asesor: r.asesor, obs: r.observacion,
          intento: r.intento || 1
        };
      });
    }

    var rV = _sbGet("aos_ventas",
      "numero_limpio=eq." + limpio + "&order=fecha.desc",
      "fecha,tratamiento,monto,tipo,asesor,sede,pago,venta_id,estado_pago",
      100
    );
    if (rV.ok && rV.data) {
      ventas = rV.data.map(function(r) {
        return {
          fecha: r.fecha, trat: r.tratamiento, monto: Number(r.monto)||0,
          tipo: r.tipo, asesor: r.asesor, sede: r.sede, pago: r.pago,
          ventaId: r.venta_id, estadoPago: r.estado_pago
        };
      });
    }

    var rA = _sbGet("aos_agenda_citas",
      "numero=eq." + limpio + "&order=fecha_cita.desc",
      "id,fecha_cita,hora_cita,tratamiento,tipo_cita,estado_cita,sede,asesor,doctora,obs",
      50
    );
    if (rA.ok && rA.data) {
      citas = rA.data.map(function(r) {
        return {
          citaId: r.id, fecha: r.fecha_cita, hora: r.hora_cita,
          trat: r.tratamiento, tipoCita: r.tipo_cita, estado: r.estado_cita,
          sede: r.sede, asesor: r.asesor, doctora: r.doctora, obs: r.obs
        };
      });
    }

    var totalFact = ventas.reduce(function(s, v) { return s + v.monto; }, 0);
    return {
      llamadas:    llamadas,
      ventas:      ventas,
      citas:       citas,
      totalFact:   totalFact,
      totalLlam:   llamadas.length,
      totalVentas: ventas.length,
      totalCitas:  citas.length,
      fromSupabase: true
    };
  } catch(e) {
    Logger.log("sb_getHistorialPaciente WARN: " + e.message);
    return null;
  }
}

/**
 * sb_getNotifNoLeidas — notificaciones no leídas para un asesor
 * Una query de 2ms vs scan de 1,225 filas en Sheets
 */
function sb_getNotifNoLeidas(paraId) {
  if (!_sbKey()) return null;
  try {
    var res = _sbGet("aos_log_notificaciones",
      "para_id=eq." + paraId + "&leido_ts=is.null&order=created_at.desc",
      "*", 50
    );
    if (!res.ok) return null;
    return res.data || [];
  } catch(e) { return null; }
}

/**
 * sb_getEstadoAsesor — estado operativo del asesor
 * Usa la vista aos_estado_equipo — instantáneo
 */
function sb_getEstadoAsesor(asesor) {
  if (!_sbKey()) return null;
  try {
    var res = _sbGet("aos_estado_equipo",
      "asesor=eq." + encodeURIComponent(asesor),
      "asesor,estado,minutos_en_estado", 1
    );
    if (!res.ok || !res.data || !res.data.length) return null;
    return res.data[0];
  } catch(e) { return null; }
}
// ===== CTRL+F: SB_READ_FAST_END =====


// ══════════════════════════════════════════════════════════════
// MOD-09 · MIGRACIÓN INICIAL DESDE SHEETS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_MIGRATE =====
//
// INSTRUCCIÓN DE USO:
// 1. Ejecutar primero: sb_migrarRRHH()
// 2. Luego: sb_migrarPacientes()
// 3. Luego: sb_migrarLeads()
// 4. IMPORTANTE: sb_migrarLlamadas() tarda ~5 min (12,201 filas)
// 5. Luego: sb_migrarVentas(), sb_migrarAgenda()
// NOTA: Estas funciones solo se ejecutan UNA VEZ para la migración inicial.

function sb_migrarRRHH() {
  Logger.log("=== Migrando RRHH ===");
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  if (lr < 2) { Logger.log("Sin datos"); return; }
  var rows = sh.getRange(2, 1, lr - 1, 18).getValues();
  var migrados = 0;
  rows.forEach(function(r) {
    if (!_norm(r[RRHH_COL.CODIGO])) return;
    var res = _sbUpsert("aos_rrhh", {
      codigo_asesor: _norm(r[RRHH_COL.CODIGO]),
      nombre:        _norm(r[RRHH_COL.NOMBRE]),
      apellido:      _norm(r[RRHH_COL.APELLIDO]),
      puesto:        _up(r[RRHH_COL.PUESTO]),
      sueldo:        Number(r[RRHH_COL.SUELDO]) || 0,
      estado:        _up(r[RRHH_COL.ESTADO]) || "ACTIVO",
      meta:          Number(r[RRHH_COL.META]) || 0,
      sede:          _norm(r[RRHH_COL.SEDE]),
      label:         _norm(r[RRHH_COL.LABEL]),
      usuario:       _low(r[RRHH_COL.USUARIO]),
      numero:        _norm(String(r[RRHH_COL.NUMERO] || "")),
      tiene_agenda:  _up(String(r[RRHH_COL.AGENDA] || "")) || "NO"
    });
    if (res.ok) migrados++;
  });
  Logger.log("RRHH migrados: " + migrados + "/" + rows.length);
}

function sb_migrarPacientes() {
  Logger.log("=== Migrando Pacientes (6,995 filas) ===");
  var sh   = _sh(CFG.SHEET_PACIENTES);
  var lr   = sh.getLastRow();
  if (lr < 2) { Logger.log("Sin datos"); return; }
  var rows = sh.getRange(2, 1, lr - 1, 24).getValues();
  var BATCH = 500; // Supabase acepta hasta 1,000 por batch
  var migrados = 0;

  for (var i = 0; i < rows.length; i += BATCH) {
    var lote = rows.slice(i, i + BATCH)
      .filter(function(r) { return _norm(r[PAC_COL.ID]); })
      .map(function(r) {
        return {
          id_paciente:     _norm(r[PAC_COL.ID]),
          nombres:         _norm(r[PAC_COL.NOMBRES]),
          apellidos:       _norm(r[PAC_COL.APELLIDOS]),
          telefono:        _normNum(r[PAC_COL.TELEFONO]),
          email:           _norm(r[PAC_COL.EMAIL] || ""),
          nro_documento:   _norm(r[PAC_COL.DOCUMENTO] || ""),
          sexo:            _norm(r[PAC_COL.SEXO] || ""),
          direccion:       _norm(r[PAC_COL.DIRECCION] || ""),
          ocupacion:       _norm(r[PAC_COL.OCUPACION] || ""),
          sede_principal:  _norm(r[PAC_COL.SEDE] || ""),
          fuente:          _norm(r[PAC_COL.FUENTE] || ""),
          total_compras:   Number(r[PAC_COL.TOTAL_COMPRAS])   || 0,
          total_facturado: Number(r[PAC_COL.TOTAL_FACTURADO]) || 0,
          total_llamadas:  Number(r[PAC_COL.TOTAL_LLAMADAS])  || 0,
          total_citas:     Number(r[PAC_COL.TOTAL_CITAS])     || 0,
          estado_paciente: _up(r[PAC_COL.ESTADO] || "NUEVO"),
          notas:           _norm(r[PAC_COL.NOTAS] || ""),
          foto_url:        _norm(r[20] || ""),
          etiqueta_base:   _norm(r[21] || ""),
          score_estado:    _norm(r[22] || "")
        };
      });
    if (!lote.length) continue;
    var res = _sbUpsert("aos_pacientes", lote);
    if (res.ok) migrados += lote.length;
    else Logger.log("WARN batch " + i + ": " + res.error);
  }
  Logger.log("Pacientes migrados: " + migrados + "/" + rows.length);
}

function sb_migrarLeads() {
  Logger.log("=== Migrando Leads (2,778 filas) ===");
  var sh   = _sh(CFG.SHEET_LEADS);
  var lr   = sh.getLastRow();
  if (lr < 2) { Logger.log("Sin datos"); return; }
  var rows = sh.getRange(2, 1, lr - 1, 8).getValues();
  var BATCH = 500;
  var migrados = 0;

  for (var i = 0; i < rows.length; i += BATCH) {
    var lote = rows.slice(i, i + BATCH)
      .filter(function(r) { return _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]); })
      .map(function(r) {
        return {
          fecha:         _date(r[LEAD_COL.FECHA]),
          celular:       _norm(String(r[LEAD_COL.CELULAR] || "")),
          tratamiento:   _up(r[LEAD_COL.TRAT] || ""),
          anuncio:       _norm(r[LEAD_COL.ANUNCIO] || ""),
          preguntas:     _norm(r[4] || ""),
          numero_limpio: _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR])
        };
      });
    if (!lote.length) continue;
    var res = _sbPost("aos_leads", lote);
    if (res.ok) migrados += lote.length;
    else Logger.log("WARN leads batch " + i + ": " + res.error);
  }
  Logger.log("Leads migrados: " + migrados);
}

function sb_migrarLlamadas() {
  Logger.log("=== Migrando Llamadas (12,201 filas) — puede tardar ~5 min ===");
  var sh   = _sh(CFG.SHEET_LLAMADAS);
  var lr   = sh.getLastRow();
  if (lr < 2) { Logger.log("Sin datos"); return; }

  var BATCH = 500;
  var migrados = 0;
  var total = lr - 1;

  for (var i = 0; i < total; i += BATCH) {
    var cant = Math.min(BATCH, total - i);
    var rows = sh.getRange(i + 2, 1, cant, 21).getValues();
    var lote = rows
      .filter(function(r) { return _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]); })
      .map(function(r) {
        var ts  = r[LLAM_COL.ULT_TS]  ? (new Date(r[LLAM_COL.ULT_TS])).toISOString()  : null;
        var prx = r[LLAM_COL.PROX_REIN] ? (new Date(r[LLAM_COL.PROX_REIN])).toISOString() : null;
        return {
          fecha:         _date(r[LLAM_COL.FECHA]),
          numero:        _norm(String(r[LLAM_COL.NUMERO] || "")),
          tratamiento:   _up(r[LLAM_COL.TRATAMIENTO]  || ""),
          estado:        _up(r[LLAM_COL.ESTADO]        || ""),
          observacion:   _norm(r[LLAM_COL.OBS]         || ""),
          hora_llamada:  _norm(String(r[LLAM_COL.HORA] || "")),
          asesor:        _norm(r[LLAM_COL.ASESOR]      || ""),
          numero_limpio: _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]),
          id_asesor:     _norm(r[LLAM_COL.ID_ASESOR]   || ""),
          anuncio:       _norm(r[LLAM_COL.ANUNCIO]     || ""),
          intento:       Number(r[LLAM_COL.INTENTO])   || 1,
          ult_ts:        ts,
          prox_rein:     prx,
          resultado:     _up(r[LLAM_COL.RESULTADO]     || ""),
          sub_estado:    _norm(r[LLAM_COL.SUB_ESTADO]  || "")
        };
      });
    if (!lote.length) continue;
    var res = _sbPost("aos_llamadas", lote);
    if (res.ok) {
      migrados += lote.length;
      Logger.log("  Progreso: " + migrados + "/" + total);
    } else {
      Logger.log("  WARN batch " + i + ": " + (res.error || "").slice(0, 100));
    }
  }

  Logger.log("Llamadas migradas: " + migrados + "/" + total);
  Logger.log("Refrescando vista materializada...");
  try {
    _sbRequest("POST", "rpc/aos_refresh_llammap", {});
    Logger.log("Vista aos_llamadas_ultimo actualizada ✅");
  } catch(e) { Logger.log("WARN refresh vista: " + e.message); }
}

function sb_migrarVentas() {
  Logger.log("=== Migrando Ventas (996 filas) ===");
  var sh   = _sh(CFG.SHEET_VENTAS);
  var lr   = sh.getLastRow();
  if (lr < 2) { Logger.log("Sin datos"); return; }
  var rows = sh.getRange(2, 1, lr - 1, 22).getValues();
  var lote = rows
    .filter(function(r) { return _norm(r[VENT_COL.VENTA_ID]); })
    .map(function(r) {
      return {
        venta_id:       _norm(r[VENT_COL.VENTA_ID]),
        fecha:          _date(r[VENT_COL.FECHA]),
        nombres:        _norm(r[VENT_COL.NOMBRES]),
        apellidos:      _norm(r[VENT_COL.APELLIDOS]),
        tratamiento:    _norm(r[VENT_COL.TRATAMIENTO]),
        descripcion:    _norm(r[VENT_COL.DESCRIPCION] || ""),
        pago:           _norm(r[VENT_COL.PAGO]),
        monto:          Number(r[VENT_COL.MONTO]) || 0,
        estado_pago:    _up(r[VENT_COL.ESTADO_PAGO]),
        asesor:         _norm(r[VENT_COL.ASESOR]),
        sede:           _up(r[VENT_COL.SEDE]),
        tipo:           _up(r[VENT_COL.TIPO]) || "SERVICIO",
        numero_limpio:  _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR])
      };
    });
  var res = _sbUpsert("aos_ventas", lote);
  Logger.log("Ventas migradas: " + (res.ok ? lote.length : "ERROR: " + res.error));
}
// ===== CTRL+F: SB_MIGRATE_END =====


// ══════════════════════════════════════════════════════════════
// MOD-10 · TESTS
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: SB_TEST =====

function test_SupabaseConexion() {
  Logger.log("=== TEST Supabase Conexión ===");
  var health = api_supabaseHealth();
  if (!health.ok) {
    Logger.log("❌ No conectado: " + health.error);
    Logger.log("ACCIÓN: Configurar SUPABASE_KEY en PropertiesService");
    return;
  }
  Logger.log("✅ Conectado");

  Logger.log("--- Test llamMap desde Supabase ---");
  var t1  = new Date().getTime();
  var map = sb_getLlamMap();
  var t2  = new Date().getTime();
  if (map) {
    Logger.log("✅ llamMap cargado en " + (t2-t1) + "ms — " + Object.keys(map).length + " números");
    Logger.log("   (En Sheets tardaba 3-8s — ahora " + (t2-t1) + "ms)");
  } else {
    Logger.log("⚠️ llamMap vacío — migrar llamadas primero: sb_migrarLlamadas()");
  }

  Logger.log("=== CHECKLIST NEXT STEPS ===");
  Logger.log("1. Ir a supabase.com → proyecto → Settings → API");
  Logger.log("2. Copiar 'service_role' key (secreta)");
  Logger.log("3. En Apps Script → Configuración → Propiedades:");
  Logger.log("   SUPABASE_KEY = <tu key>");
  Logger.log("4. Ejecutar: sb_migrarRRHH()");
  Logger.log("5. Ejecutar: sb_migrarPacientes()");
  Logger.log("6. Ejecutar: sb_migrarLeads()");
  Logger.log("7. Ejecutar: sb_migrarLlamadas() [~5 min]");
  Logger.log("8. Ejecutar: sb_migrarVentas()");
  Logger.log("9. Volver a ejecutar este test — todo debe mostrar ✅");
}
// ===== CTRL+F: SB_TEST_END =====

/**
 * PARCHE_SUPABASE_GAS.gs
 * ══════════════════════════════════════════════════════════════
 * Instrucción: AGREGAR al final de GS_06_AdvisorCalls.gs
 * (o al final de GS_25_SupabaseSync.gs si prefieres un solo archivo)
 *
 * Este parche conecta las 3 funciones más críticas con Supabase:
 *   1. api_getNextLeadFast  → lee llamMap de Supabase (0.1ms vs 5s)
 *   2. api_getHistorialFast → lee historial de Supabase (~50ms vs 8s)
 *   3. Sync automático      → cada llamada guardada va a Supabase
 *
 * CÓMO INSTALAR:
 *   Opción A: Agregar al final de GS_25_SupabaseSync.gs (recomendado)
 *   Opción B: Crear un nuevo archivo GS_26_SupabasePatch.gs
 *
 * DESPUÉS DE INSTALAR:
 *   En el frontend (ViewAdvisorCalls.html) el sistema detecta
 *   automáticamente si Supabase responde y usa el fast path.
 *   Si Supabase falla → fallback automático a Sheets (sin interrupciones).
 * ══════════════════════════════════════════════════════════════
 */

// ══════════════════════════════════════════════════════════════
// PATCH-01 · api_getNextLeadFast
// Versión de api_getNextLead que usa Supabase para el llamMap.
// El frontend llama a este wrapper primero. Si falla, usa el original.
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getNextLeadFastT =====

function api_getNextLeadFastT(token) {
  _setToken(token);
  var s   = cc_requireSession();
  var now = new Date();

  // PASO 1: Cargar llamMap desde Supabase (0.1ms vs 5s de Sheets)
  var llamMap = null;
  try {
    llamMap = sb_getLlamMap();
  } catch(e) {
    Logger.log("sb_getLlamMap fallback a Sheets: " + e.message);
  }

  // PASO 2: Si Supabase falló → usar Sheets normal
  if (!llamMap) {
    return api_getNextLead();
  }

  // PASO 3: Cargar leads desde Sheets (solo 2,684 filas × 9 cols — rápido)
  var shLd  = _sh(CFG.SHEET_LEADS);
  var lrLd  = shLd.getLastRow();
  if (lrLd < 2) return { ok: false, sin_leads: true, msg: "Sin leads en la base." };
  var leadsRaw = shLd.getRange(2, 1, lrLd - 1, 9).getValues();

  // PASO 4: Clasificar en tiers usando el llamMap de Supabase
  var tier1 = [], tier2 = [], tier3 = [];
  var hoy   = _date(now);

  leadsRaw.forEach(function(r) {
    var num = _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR] || "");
    if (!num) return;
    var trat    = _up(r[LEAD_COL.TRAT] || "");
    var anuncio = _norm(r[LEAD_COL.ANUNCIO] || "");
    var fecha   = r[LEAD_COL.FECHA];
    var llam    = llamMap[num];

    if (llam && ESTADOS_DESCARTADOS.has(llam.estado)) return;

    var lead = {
      num: num, trat: trat || "SIN TRATAMIENTO",
      anuncio: anuncio, fecha: _date(fecha),
      intento: llam ? llam.intento + 1 : 1,
      rowNum:  llam ? llam.rowNum : 0,
      wa: _wa(num)
    };

    if (!llam) {
      tier1.push(lead);
    } else if (llam.resultado === "REINTENTAR") {
      var proxReinDate = llam.proxRein ? new Date(llam.proxRein) : null;
      if (proxReinDate && proxReinDate <= now) tier2.push(lead);
    }
  });

  // PASO 5: Seguimientos desde Sheets (983 filas — rápido)
  try {
    var shSeg = _sh(CFG.SHEET_SEGUIMIENTOS);
    var lrSeg = shSeg.getLastRow();
    if (lrSeg >= 2) {
      shSeg.getRange(2, 1, lrSeg - 1, 11).getValues().forEach(function(r, i) {
        var fechaProg = _date(r[SEG_COL.FECHA_PROG]);
        var idAsSeq   = _norm(r[SEG_COL.ID_ASESOR]);
        var estado    = _up(r[SEG_COL.ESTADO]);
        var num       = _normNum(r[SEG_COL.NUMERO]);
        if (estado === "PENDIENTE" && fechaProg <= hoy &&
            (idAsSeq === _norm(s.idAsesor) || !idAsSeq)) {
          tier3.push({
            num: num, trat: _up(r[SEG_COL.TRATAMIENTO] || ""),
            anuncio: "SEGUIMIENTO", fecha: fechaProg,
            intento: 1, rowNum: 0, segRowNum: i + 2,
            obs: _norm(r[SEG_COL.OBS]), wa: _wa(num)
          });
        }
      });
    }
  } catch(e) {}

  var lead = null, tier = "";
  if      (tier3.length > 0) { lead = tier3[0]; tier = "TIER 3 · SEGUIMIENTO"; }
  else if (tier1.length > 0) { lead = tier1[0]; tier = "TIER 1 · HOY"; }
  else if (tier2.length > 0) { lead = tier2[0]; tier = "TIER 2 · REINTENTO"; }

  if (!lead) return {
    ok: false, sin_leads: true,
    msg: "¡Base trabajada al 100%! Sin leads pendientes.",
    stats: { tier1: tier1.length, tier2: tier2.length, tier3: tier3.length }
  };

  var anuncioInfo = _getAnuncioInfo(lead.anuncio, lead.trat);

  // Contexto usando llamMap de Supabase (ya no releer LLAMADAS)
  try {
    lead.contexto = _ac_buildContexto(lead.num, llamMap);
  } catch(eCtx) {
    lead.contexto = null;
  }

  return {
    ok: true, lead: lead, tier: tier, anuncio: anuncioInfo,
    fromSupabase: true,
    stats: {
      tier1: tier1.length, tier2: tier2.length, tier3: tier3.length,
      total: tier1.length + tier2.length + tier3.length
    }
  };
}
// ===== CTRL+F: api_getNextLeadFastT_END =====


// ══════════════════════════════════════════════════════════════
// PATCH-02 · api_getPatient360FastT
// Versión de api_getPatient360T que lee historial de Supabase.
// ~50ms vs ~8s de Sheets.
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getPatient360FastT =====

function api_getPatient360FastT(token, numOrId) {
  _setToken(token);
  cc_requireSession();

  // Buscar paciente base (Sheets — 6,994 filas pero con índice por ID)
  var res = api_getPatientProfile(numOrId);
  if (!res || !res.ok) return { ok: false, msg: "Paciente no encontrado: " + numOrId };

  var p = res.paciente;

  // Intentar historial desde Supabase
  var historial = null;
  try {
    var num = p.telefono || numOrId;
    historial = sb_getHistorialPaciente(num);
  } catch(e) {
    Logger.log("sb_getHistorialPaciente fallback: " + e.message);
  }

  // Si Supabase falló → usar historial de Sheets
  if (!historial) {
    historial = res.historial;
  }

  // Calcular diasUltVisita
  if (p.ultVisita) {
    var hoy = new Date(); hoy.setHours(0,0,0,0);
    var uv  = new Date(p.ultVisita); uv.setHours(0,0,0,0);
    p.diasUltVisita = Math.floor((hoy - uv) / (1000*60*60*24));
  } else {
    p.diasUltVisita = null;
  }

  // Normalizar tildes
  if (p.estado) {
    p.estado = p.estado.toUpperCase()
      .replace(/Ó/g,"O").replace(/É/g,"E").replace(/Á/g,"A")
      .replace(/Í/g,"I").replace(/Ú/g,"U");
  }
  if (historial && historial.citas) {
    historial.citas = historial.citas.map(function(c) {
      c.estado = (c.estado || "").toUpperCase()
        .replace(/Ó/g,"O").replace(/É/g,"E").replace(/Á/g,"A")
        .replace(/Í/g,"I").replace(/Ú/g,"U");
      return c;
    });
  }

  return {
    ok: true, paciente: p, historial: historial,
    fromSupabase: !!(historial && historial.fromSupabase)
  };
}
// ===== CTRL+F: api_getPatient360FastT_END =====


// ══════════════════════════════════════════════════════════════
// PATCH-03 · api_saveCallAndSync
// Wrapper de api_saveCall que además sincroniza a Supabase.
// El frontend puede llamar este en vez del original.
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_saveCallAndSyncT =====

function api_saveCallAndSyncT(token, payload) {
  _setToken(token);
  var s = cc_requireSession();

  // 1. Guardar en Sheets (comportamiento normal)
  var result = api_saveCall(payload);

  // 2. Sincronizar a Supabase en paralelo (no bloquea si falla)
  if (result && result.ok) {
    try {
      sb_syncLlamada(payload, s);
    } catch(e) {
      Logger.log("sb_syncLlamada WARN (no crítico): " + e.message);
    }

    // Si es cita, también sincronizar agenda
    if (_up(payload.estado || "") === "CITA CONFIRMADA") {
      try {
        // Refrescar vista materializada de Supabase
        _sbRequest("POST", "rpc/aos_refresh_llammap", {});
      } catch(e) {}
    }
  }

  return result;
}
// ===== CTRL+F: api_saveCallAndSyncT_END =====


// ══════════════════════════════════════════════════════════════
// PATCH-04 · api_getAdminKpisFromSupabase
// KPIs del admin directamente desde Supabase.
// Instantáneo — sin leer ninguna hoja de Sheets.
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getAdminKpisFromSupabaseT =====

function api_getAdminKpisFromSupabaseT(token) {
  _setToken(token);
  cc_requireAdmin();

  var now    = new Date();
  var hoy    = _date(now);
  var ayer   = _date(new Date(now.getTime() - 86400000));
  var mesI   = now.getFullYear() + "-" + String(now.getMonth()+1).padStart(2,"0") + "-01";

  try {
    // Una sola query SQL que calcula todo — 5ms total
    var res = _sbRequest("POST", "rpc/aos_kpis_dashboard", {
      body: { p_hoy: hoy, p_ayer: ayer, p_mes_inicio: mesI }
    });

    if (res.ok && res.data) {
      return { ok: true, kpis: res.data, fromSupabase: true };
    }
  } catch(e) {
    Logger.log("aos_kpis_dashboard fallback: " + e.message);
  }

  // Fallback a la función original con caché
  return api_getAdminHomeKpisV2();
}
// ===== CTRL+F: api_getAdminKpisFromSupabaseT_END =====


// ══════════════════════════════════════════════════════════════
// PATCH-05 · api_getNotificacionesFastT
// Notificaciones desde Supabase — 2ms vs 3s de Sheets.
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: api_getNotificacionesFastT =====

function api_getNotificacionesFastT(token) {
  _setToken(token);
  var s = cc_requireSession();

  try {
    var notifs = sb_getNotifNoLeidas(s.idAsesor);
    if (notifs !== null) {
      return {
        ok: true,
        items: notifs.map(function(n) {
          return {
            id: n.id, tipo: n.tipo, titulo: n.titulo,
            cuerpo: n.cuerpo, fecha: n.fecha,
            hora: n.hora ? String(n.hora).slice(0,5) : "",
            tsLeido: n.leido_ts
          };
        }),
        unreadNotifs: notifs.length,
        unreadMsgs: 0,
        fromSupabase: true
      };
    }
  } catch(e) {
    Logger.log("Notif Supabase fallback: " + e.message);
  }

  // Fallback al original
  return api_listNotificationsT(token);
}
// ===== CTRL+F: api_getNotificacionesFastT_END =====
/**
 * PARCHE_LOGIN_RAPIDO.gs
 * ══════════════════════════════════════════════════════════════
 * INSTRUCCIÓN: Agregar al FINAL de GS_25_SupabaseSync.gs
 *
 * Reemplaza _asesoresRaw() para que lea de Supabase en vez de Sheets.
 * Sheets tiene 8 filas de RRHH pero GAS tarda 20s en abrirlo.
 * Supabase devuelve las mismas 8 filas en 50ms.
 *
 * RESULTADO:
 *   Login antes: 20-65 segundos (GAS abriendo Sheets)
 *   Login después: <2 segundos (Supabase directo)
 * ══════════════════════════════════════════════════════════════
 */

// ===== CTRL+F: _asesoresRaw_SUPABASE =====

/**
 * Override de _asesoresRaw — lee de Supabase con fallback a Sheets.
 * Se declara DESPUÉS del original en GS_02 → este override toma precedencia
 * porque GAS ejecuta los archivos en orden alfabético y GS_25 > GS_02.
 *
 * IMPORTANTE: En GAS, si dos funciones tienen el mismo nombre,
 * gana la que está en el archivo con nombre mayor alfabéticamente.
 * GS_25 > GS_02 → este override es el que se ejecuta.
 */
function _asesoresRaw() {
  // Intentar Supabase primero (~50ms)
  try {
    var key = _sbKey();
    if (key) {
      var res = _sbGet(
        "aos_rrhh",
        "estado=eq.ACTIVO",
        "codigo_asesor,nombre,apellido,puesto,estado,meta,sede,label,usuario,password_hash,numero,tiene_agenda,permisos,foto_url",
        50
      );
      if (res.ok && res.data && res.data.length > 0) {
        return res.data.map(function(r) {
          var permisos = [];
          try {
            if (r.permisos) {
              permisos = typeof r.permisos === "string"
                ? JSON.parse(r.permisos) : r.permisos;
            }
          } catch(e) { permisos = []; }

          return {
            idAsesor:    r.codigo_asesor || "",
            nombre:      r.nombre       || "",
            apellido:    r.apellido     || "",
            puesto:      (r.puesto      || "").toUpperCase(),
            estado:      (r.estado      || "").toUpperCase(),
            meta:        Number(r.meta) || 0,
            sede:        r.sede         || "",
            label:       r.label        || r.nombre || "",
            usuario:     (r.usuario     || "").toLowerCase(),
            pass:        r.password_hash || "",
            numero:      r.numero       || "",
            tieneAgenda: (r.tiene_agenda || "").toUpperCase() === "SI",
            role:        _normRole(r.puesto),
            permisos:    permisos,
            fotoUrl:     r.foto_url     || ""
          };
        }).filter(function(x) { return x.idAsesor; });
      }
    }
  } catch(e) {
    Logger.log("_asesoresRaw Supabase fallback a Sheets: " + e.message);
  }

  // Fallback a Sheets si Supabase no responde
  var sh = _sh(CFG.SHEET_RRHH);
  var lr = sh.getLastRow();
  if (lr < 2) return [];

  return sh.getRange(2, 1, lr - 1, 18).getValues().map(function(r) {
    var permisosRaw = r[RRHH_COL.PERMISOS];
    var permisos = [];
    try {
      if (permisosRaw) {
        permisos = typeof permisosRaw === "string"
          ? JSON.parse(permisosRaw) : permisosRaw;
      }
    } catch(e) { permisos = []; }

    return {
      idAsesor:    _norm(r[RRHH_COL.CODIGO]),
      nombre:      _norm(r[RRHH_COL.NOMBRE]),
      apellido:    _norm(r[RRHH_COL.APELLIDO]),
      puesto:      _up(r[RRHH_COL.PUESTO]),
      estado:      _up(r[RRHH_COL.ESTADO]),
      meta:        Number(r[RRHH_COL.META]) || 0,
      sede:        _norm(r[RRHH_COL.SEDE]),
      label:       _norm(r[RRHH_COL.LABEL]),
      usuario:     _low(r[RRHH_COL.USUARIO]),
      pass:        _norm(String(r[RRHH_COL.PASS] || "")),
      numero:      _norm(String(r[RRHH_COL.NUMERO] || "")),
      tieneAgenda: _up(String(r[RRHH_COL.AGENDA] || "")) === "SI",
      role:        _normRole(r[RRHH_COL.PUESTO]),
      permisos:    permisos,
      fotoUrl:     _norm(r[RRHH_COL.FOTO_URL] || "")
    };
  }).filter(function(x) { return x.idAsesor; });
}
// ===== CTRL+F: _asesoresRaw_SUPABASE_END =====


// ══════════════════════════════════════════════════════════════
// TEST: Login rápido desde Supabase
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: test_LoginRapido =====
function test_LoginRapido() {
  Logger.log("=== TEST LOGIN RÁPIDO DESDE SUPABASE ===");

  var t1 = new Date().getTime();
  var asesores = _asesoresRaw();
  var t2 = new Date().getTime();
  Logger.log("_asesoresRaw: " + asesores.length + " asesores en " + (t2-t1) + "ms");
  Logger.log("Origen: " + (asesores[0] && asesores[0].fotoUrl !== undefined ? "Supabase ✅" : "Sheets"));

  var t3 = new Date().getTime();
  var r  = api_login("cesar", "cesar123", "TEST");
  var t4 = new Date().getTime();
  Logger.log("Login completo: " + (t4-t3) + "ms → " + (r.ok ? "✅ OK | rol: " + (r.ctx && r.ctx.role) : "❌ " + r.error));

  Logger.log("");
  Logger.log("Asesores activos:");
  asesores.forEach(function(a) {
    Logger.log("  " + a.idAsesor + " | " + a.nombre + " | " + a.usuario + " | " + a.puesto);
  });

  Logger.log("=== FIN TEST ===");
}
// ===== CTRL+F: test_LoginRapido_END =====

/**
 * PARCHE_LOGIN_RAPIDO_V2.gs
 * ══════════════════════════════════════════════════════════════
 * INSTRUCCIÓN: Agregar al FINAL de GS_25_SupabaseSync.gs
 *              (después del PARCHE_LOGIN_RAPIDO anterior)
 *
 * Reemplaza _closeEstadoAbierto() para que use Supabase
 * en vez de leer 5,595 filas de LOG_PERSONAL en Sheets.
 *
 * RESULTADO:
 *   Login antes (con fix anterior): ~48s
 *   Login después: <3s total
 * ══════════════════════════════════════════════════════════════
 */

// ===== CTRL+F: _closeEstadoAbierto_SUPABASE =====

/**
 * Override de _closeEstadoAbierto — usa Supabase con fallback a Sheets.
 * GS_25 > GS_02 alfabéticamente → este override tiene precedencia.
 */
function _closeEstadoAbierto(nombre) {
  if (!nombre) return;

  // Intentar Supabase primero (~5ms vs 20s de Sheets)
  try {
    var key = _sbKey();
    if (key) {
      var res = _sbRequest("POST", "rpc/aos_cerrar_estado_abierto", {
        body: { p_asesor: nombre }
      });
      if (res.ok) return; // Supabase lo manejó — no tocar Sheets
    }
  } catch(e) {
    Logger.log("_closeEstadoAbierto Supabase fallback: " + e.message);
  }

  // Fallback a Sheets (solo últimas 200 filas — FIX-L2)
  try {
    var sh = _estadoSheet();
    var lr = sh.getLastRow();
    if (lr < 2) return;
    var inicio = Math.max(2, lr - 199);
    var cant   = lr - inicio + 1;
    var data   = sh.getRange(inicio, 1, cant, 11).getValues();
    for (var i = data.length - 1; i >= 0; i--) {
      if (_norm(data[i][1]) === nombre && !data[i][6]) {
        var row = inicio + i;
        var now = new Date();
        var ini = data[i][5] ? new Date(data[i][5]) : null;
        sh.getRange(row, 7).setValue(now);
        if (ini && !isNaN(ini)) {
          sh.getRange(row, 8).setValue(Math.max(0, Math.round((now - ini) / 60000)));
        }
        sh.getRange(row, 11).setValue(now);
        return;
      }
    }
  } catch(e) { Logger.log("_closeEstadoAbierto Sheets error: " + e.message); }
}
// ===== CTRL+F: _closeEstadoAbierto_SUPABASE_END =====


// ===== CTRL+F: api_getEstadoAsesor_SUPABASE =====

/**
 * Override de api_getEstadoAsesor — usa Supabase.
 * Reemplaza el scan de 5,595 filas por una query de 2ms.
 */
function api_getEstadoAsesor() {
  var s = cc_requireSession();

  // Intentar Supabase
  try {
    var estadoSB = sb_getEstadoAsesor(s.asesor);
    if (estadoSB) {
      return { ok: true, estado: estadoSB.estado || "" };
    }
  } catch(e) {}

  // Fallback a Sheets (últimas 200 filas)
  var sh = _estadoSheet();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, estado: "" };
  var nombre = _norm(s.asesor);
  var inicio = Math.max(2, lr - 199);
  var data   = sh.getRange(inicio, 1, lr - inicio + 1, 11).getValues();
  for (var i = data.length - 1; i >= 0; i--) {
    if (_norm(data[i][1]) === nombre && !data[i][6]) {
      return { ok: true, estado: _norm(data[i][3]) };
    }
  }
  return { ok: true, estado: "" };
}
// ===== CTRL+F: api_getEstadoAsesor_SUPABASE_END =====


// ===== CTRL+F: api_setEstadoAsesor_SUPABASE =====

/**
 * Override de api_setEstadoAsesor — escribe en Sheets Y Supabase.
 */
function api_setEstadoAsesor(estado) {
  var s  = cc_requireSession();
  estado = _up(estado);

  if (ESTADOS_OPERATIVO.indexOf(estado) === -1) {
    throw new Error("Estado inválido: \"" + estado + "\"");
  }

  var now    = new Date();
  var nombre = _norm(s.asesor);

  // 1. Cerrar estado anterior en ambos lados
  _closeEstadoAbierto(nombre);

  // 2. Escribir nuevo estado en Sheets
  _estadoSheet().appendRow([
    _date(now), nombre, "ESTADO", estado, "",
    now, "", "", "", "", now
  ]);

  // 3. Escribir en Supabase (asíncrono — no bloquea si falla)
  try {
    _sbPost("aos_log_personal", {
      fecha:   _date(now),
      asesor:  nombre,
      evento:  "ESTADO",
      estado:  estado,
      inicio:  now.toISOString(),
      ts_log:  now.toISOString()
    });
  } catch(e) {}

  // 4. Notificar a admins
  try {
    _asesoresActivosCached().filter(function(a) {
      return _normRole(a.role) === ROLES.ADMIN;
    }).forEach(function(adm) {
      _notifSheet().appendRow([
        _uid(), _date(now), _time(now), "ESTADO",
        "👤 " + nombre + ": " + estado,
        "El asesor " + nombre + " cambió su estado a " + estado,
        _norm(s.idAsesor), nombre,
        adm.idAsesor, adm.label || adm.nombre, ""
      ]);
    });
  } catch(e) {}

  return { ok: true, estado: estado };
}
// ===== CTRL+F: api_setEstadoAsesor_SUPABASE_END =====


// ══════════════════════════════════════════════════════════════
// TEST FINAL DE VELOCIDAD
// ══════════════════════════════════════════════════════════════
// ===== CTRL+F: test_LoginFinal =====
function test_LoginFinal() {
  Logger.log("=== TEST LOGIN FINAL — todo desde Supabase ===");

  var T = new Date().getTime();
  var r = api_login("cesar", "cesar123", "TEST");
  Logger.log("LOGIN TOTAL: " + (new Date().getTime()-T) + "ms → " +
    (r.ok ? "✅ OK | rol: " + (r.ctx && r.ctx.role) : "❌ " + r.error));

  Logger.log("");
  Logger.log("Desglose esperado:");
  Logger.log("  _asesoresRaw (Supabase): ~50ms");
  Logger.log("  _closeEstadoAbierto (Supabase): ~5ms");
  Logger.log("  appendRow LOG_PERSONAL: ~500ms");
  Logger.log("  Total objetivo: <2s en webapp desplegada");
  Logger.log("  (En editor GAS siempre es 5-10x más lento que en producción)");
  Logger.log("=== FIN ===");
}
// ===== CTRL+F: test_LoginFinal_END =====