/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_04_DataAccess.gs                        ║
 * ║  Módulo: Capa Única de Acceso a Datos                       ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config, GS_03_CoreHelpers             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * CONTENIDO:
 *   MOD-01 · Acceso seguro a hojas
 *   MOD-02 · Lectura de datos por dominio
 *   MOD-03 · Escritura de datos
 *   MOD-04 · Construcción de hojas auto-creadas
 *   MOD-05 · Trigger onEdit
 *
 * REGLA: Todo módulo funcional DEBE usar estas funciones
 *        para acceder a los Sheets. Nunca abrir hojas directamente.
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · ACCESO SEGURO A HOJAS
// ══════════════════════════════════════════════════════════════
// D01_START

/**
 * Leer filas de una hoja de forma segura
 * Retorna array vacío si la hoja tiene menos de 2 filas
 * @param {string} nombreHoja
 * @param {number} numCols - Número de columnas a leer
 * @returns {Array} Array de arrays (valores de cada fila)
 */
function da_readRows(nombreHoja, numCols) {
  var sh = _sh(nombreHoja);
  var lr = sh.getLastRow();
  if (lr < 2) return [];
  return sh.getRange(2, 1, lr - 1, numCols).getValues();
}

/**
 * Leer filas con filtro por fecha dentro de un rango
 * @param {string} nombreHoja
 * @param {number} numCols
 * @param {number} colFecha - Índice base 0 de la columna de fecha
 * @param {Date} desde
 * @param {Date} hasta
 * @returns {Array}
 */
function da_readRowsByDateRange(nombreHoja, numCols, colFecha, desde, hasta) {
  var rows = da_readRows(nombreHoja, numCols);
  return rows.filter(function(r) {
    return _inRango(r[colFecha], desde, hasta);
  });
}

/**
 * Append de una fila a una hoja
 * @param {string} nombreHoja
 * @param {Array} rowData
 */
function da_appendRow(nombreHoja, rowData) {
  _sh(nombreHoja).appendRow(rowData);
}

/**
 * Actualizar una celda específica
 * @param {string} nombreHoja
 * @param {number} row - Número de fila (base 1)
 * @param {number} col - Número de columna (base 1)
 * @param {*} value
 */
function da_setCell(nombreHoja, row, col, value) {
  _sh(nombreHoja).getRange(row, col).setValue(value);
}

/**
 * Actualizar múltiples celdas en una misma fila
 * @param {string} nombreHoja
 * @param {number} row
 * @param {Object} updates - {col: value, ...} (col base 1)
 */
function da_setRowCells(nombreHoja, row, updates) {
  var sh = _sh(nombreHoja);
  Object.keys(updates).forEach(function(col) {
    sh.getRange(row, Number(col)).setValue(updates[col]);
  });
}

/**
 * Escribir un rango completo de filas (batch)
 * @param {string} nombreHoja
 * @param {number} startRow
 * @param {number} startCol
 * @param {Array} data - Array 2D
 */
function da_setRange(nombreHoja, startRow, startCol, data) {
  if (!data || !data.length) return;
  var sh = _sh(nombreHoja);
  sh.getRange(startRow, startCol, data.length, data[0].length)
    .setValues(data);
}
// D01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · LECTURA DE DATOS POR DOMINIO
// ══════════════════════════════════════════════════════════════
// D02_START

/**
 * Lee todas las filas de LEADS en un rango de fechas
 * @param {Date} desde
 * @param {Date} hasta
 * @returns {Array} [{fecha, num, trat, anuncio, hora}, ...]
 */
function da_leadsData(desde, hasta) {
  var sh = _sh(CFG.SHEET_LEADS);
  var lr = sh.getLastRow();
  if (lr < 2) return [];

  return sh.getRange(2, 1, lr - 1, 9).getValues()
    .filter(function(r) { return r[0] && _inRango(r[0], desde, hasta); })
    .map(function(r) {
      return {
        fecha:   r[0],
        num:     _normNum(r[LEAD_COL.NUM_LIMPIO] || r[LEAD_COL.CELULAR]),
        trat:    _up(r[LEAD_COL.TRAT]),
        anuncio: _norm(r[LEAD_COL.ANUNCIO]),
        hora:    r[LEAD_COL.HORA]
      };
    })
    .filter(function(r) { return r.num; });
}

/**
 * Lee todas las llamadas en un rango de fechas
 * @param {Date} desde
 * @param {Date} hasta
 * @returns {Array}
 */
function da_llamadasData(desde, hasta) {
  var sh = _sh(CFG.SHEET_LLAMADAS);
  var lr = sh.getLastRow();
  if (lr < 2) return [];

  return sh.getRange(2, 1, lr - 1, 20).getValues()
    .filter(function(r) {
      return r[0] && _inRango(r[0], desde, hasta) &&
             _up(r[LLAM_COL.ESTADO]) !== "";
    })
    .map(function(r) {
      return {
        fecha:    r[0],
        num:      _normNum(r[LLAM_COL.NUM_LIMPIO] || r[LLAM_COL.NUMERO]),
        trat:     _up(r[LLAM_COL.TRATAMIENTO]),
        estado:   _up(r[LLAM_COL.ESTADO]),
        hora:     r[LLAM_COL.HORA],
        asesor:   _up(r[LLAM_COL.ASESOR]),
        idAsesor: _norm(r[LLAM_COL.ID_ASESOR]),
        intento:  Number(r[LLAM_COL.INTENTO]) || 1,
        ultTs:    r[LLAM_COL.ULT_TS],
        resultado:_up(r[LLAM_COL.RESULTADO])
      };
    })
    .filter(function(r) { return r.num; });
}

/**
 * Lee todas las ventas en un rango de fechas
 * @param {Date} desde
 * @param {Date} hasta
 * @returns {Array}
 */
function da_ventasData(desde, hasta) {
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return [];

  return sh.getRange(2, 1, lr - 1, 19).getValues()
    .filter(function(r) { return r[0] && _inRango(r[0], desde, hasta); })
    .map(function(r) {
      return {
        fecha:      r[VENT_COL.FECHA],
        nombres:    _norm(r[VENT_COL.NOMBRES]),
        apellidos:  _norm(r[VENT_COL.APELLIDOS]),
        dni:        _norm(r[VENT_COL.DNI]),
        celular:    _norm(r[VENT_COL.CELULAR]),
        trat:       _up(r[VENT_COL.TRATAMIENTO]),
        desc:       _norm(r[VENT_COL.DESCRIPCION]),
        pago:       _norm(r[VENT_COL.PAGO]),
        monto:      Number(r[VENT_COL.MONTO]) || 0,
        estadoPago: _norm(r[VENT_COL.ESTADO_PAGO]),
        asesor:     _up(r[VENT_COL.ASESOR]),
        atendio:    _norm(r[VENT_COL.ATENDIO]),
        sede:       _up(r[VENT_COL.SEDE]),
        tipo:       _up(r[VENT_COL.TIPO]),
        num:        _normNum(r[VENT_COL.NUM_LIMPIO] || r[VENT_COL.CELULAR]),
        ventaId:    _norm(r[VENT_COL.VENTA_ID]),
        nroDoc:     _norm(r[VENT_COL.NRO_DOC]),
        estadoDoc:  _norm(r[VENT_COL.ESTADO_DOC])
      };
    })
    .filter(function(r) { return r.num; });
}

/**
 * Lee todas las filas de ventas (sin filtro de fecha)
 * Usado por el módulo de comisiones
 * @returns {Array} Filas crudas del Sheet
 */
function da_ventasRows() {
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return [];
  return sh.getRange(2, 1, lr - 1, 19).getValues();
}

/**
 * Lee inversión de campañas por mes/año
 * @param {number} mesNum - 1-12
 * @param {number} anioNum
 * @param {string} mode - "mes" | "anio"
 * @returns {Object} {TRATAMIENTO: monto, ...}
 */
function da_inversionData(mesNum, anioNum, mode) {
  var inv = {};
  try {
    var sh = _sh(CFG.SHEET_INVERSION);
    var lr = sh.getLastRow();
    if (lr < 2) return inv;

    sh.getRange(2, 1, lr - 1, 3).getValues().forEach(function(r) {
      if (!r[0]) return;
      var trat    = _up(r[0]);
      var mesText = _up(r[1]);
      var monto   = Number(r[2]) || 0;
      var mesN    = MESES_ES.indexOf(mesText);

      if (mode === "anio") {
        if (mesN > 0) inv[trat] = (inv[trat] || 0) + monto;
      } else {
        if (mesN === mesNum) inv[trat] = (inv[trat] || 0) + monto;
      }
    });
  } catch(e) {}
  return inv;
}
// D02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · ESCRITURA DE DATOS
// ══════════════════════════════════════════════════════════════
// D03_START

/**
 * Guarda una venta nueva en CONSOLIDADO DE VENTAS
 * @param {Object} payload
 * @param {Object} ctx - Contexto de sesión
 * @returns {Object} {ok, ventaId}
 */
function da_saveVenta(payload, ctx) {
  payload = payload || {};
  var now = new Date();
  var num = _phone(payload.celular || "");
  if (!num)                    throw new Error("Falta celular.");
  if (!_norm(payload.tratamiento)) throw new Error("Falta tratamiento.");
  if (!payload.monto)          throw new Error("Falta monto.");

  var vid = "V-" + _uid().slice(0, 8).toUpperCase();

  // Determinar tipo automáticamente si no viene
  var tipo = _up(payload.tipo || "");
  if (!tipo) {
    var trat = _up(payload.tratamiento || "");
    tipo = (trat.indexOf("COMPRA DE PRODUCTO") >= 0 ||
            trat === "PRODUCTO") ? "PRODUCTO" : "SERVICIO";
  }

  _sh(CFG.SHEET_VENTAS).appendRow([
    _date(now),
    _norm(payload.nombres || ""),
    _norm(payload.apellidos || ""),
    _norm(payload.dni || ""),
    "'" + num,
    _norm(payload.tratamiento || ""),
    _norm(payload.descripcion || ""),
    _norm(payload.pago || ""),
    Number(payload.monto) || 0,
    _norm(payload.estadoPago || ESTADO_PAGO.PENDIENTE),
    _norm(ctx.asesor),
    _norm(payload.atendio || ""),
    _up(_norm(ctx.sede || payload.sede || "")),
    tipo,
    "",           // col O - reservado
    num,          // col P - NUM_LIMPIO
    vid           // col Q - VENTA_ID
  ]);

  return { ok: true, ventaId: vid };
}

/**
 * Guarda un resultado de llamada (nueva fila o actualiza existente)
 * @param {Object} payload
 * @param {Object} ctx
 * @returns {Object} {ok, created|updated}
 */
function da_saveCallOutcome(payload, ctx) {
  payload = payload || {};
  var sh  = _sh(CFG.SHEET_LLAMADAS);
  var now = new Date();

  var ESTADO  = _up(payload.estado || "");
  var OBS     = _norm(payload.obs || "");
  var PROX    = _norm(payload.proxReintentoTs || "");

  if (ESTADO && ESTADOS_LLAMADA.indexOf(ESTADO) === -1) {
    throw new Error("Estado inválido: \"" + ESTADO + "\"");
  }

  var proxDt = PROX ? new Date(PROX) : null;
  var RES = "";
  if (ESTADO === "SEGUIMIENTO") {
    RES = "REINTENTAR";
    if (!proxDt || isNaN(proxDt)) {
      throw new Error("SEGUIMIENTO requiere fecha programada.");
    }
  } else if (ESTADO) {
    RES = "CERRADO";
  }

  var rowNum = Number(payload.rowNum || 0);

  if (rowNum >= 2) {
    // Actualizar fila existente
    sh.getRange(rowNum, LLAM_COL.ESTADO + 1).setValue(ESTADO);
    sh.getRange(rowNum, LLAM_COL.OBS + 1).setValue(OBS);
    sh.getRange(rowNum, LLAM_COL.HORA + 1).setValue(_datetime(now));
    sh.getRange(rowNum, LLAM_COL.ASESOR + 1).setValue(_norm(ctx.asesor));
    var rowData = sh.getRange(rowNum, 1, 1, 10).getValues()[0];
    if (!_norm(rowData[LLAM_COL.ID_ASESOR])) {
      sh.getRange(rowNum, LLAM_COL.ID_ASESOR + 1).setValue(_norm(ctx.idAsesor));
    }
    sh.getRange(rowNum, LLAM_COL.ULT_TS + 1).setValue(now);
    sh.getRange(rowNum, LLAM_COL.PROX_REIN + 1)
      .setValue(RES === "REINTENTAR" ? proxDt : "");
    sh.getRange(rowNum, LLAM_COL.RESULTADO + 1).setValue(RES);
    sh.getRange(rowNum, LLAM_COL.TS_LOG + 1).setValue(now);
    return { ok: true, updated: true };
  }

  // Crear fila nueva
  var num = _phone(payload.numero || "");
  if (!num) throw new Error("Falta número.");

  sh.appendRow([
    _date(now),                          // A FECHA
    "'" + num,                           // B NUMERO
    _norm(payload.tratamiento || ""),    // C TRATAMIENTO
    ESTADO,                              // D ESTADO
    OBS,                                 // E OBS
    _datetime(now),                      // F HORA
    _norm(ctx.asesor),                   // G ASESOR
    "",                                  // H reservado
    "",                                  // I NUM_LIMPIO (se llena aparte)
    _norm(ctx.idAsesor),                 // J ID_ASESOR
    _norm(payload.anuncio || ""),        // K ANUNCIO
    _norm(payload.origen || "MANUAL"),   // L ORIGEN
    1,                                   // M INTENTO
    now,                                 // N ULT_TS
    RES === "REINTENTAR" ? proxDt : "",  // O PROX_REIN
    RES,                                 // P RESULTADO
    "",                                  // Q SESSION_ID
    "",                                  // R DEVICE
    _wa(num),                            // S WHATSAPP
    now                                  // T TS_LOG
  ]);

  return { ok: true, created: true };
}
// D03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · CONSTRUCCIÓN DE HOJAS AUTO-CREADAS
// Estas funciones aseguran que las hojas existan con sus headers
// ══════════════════════════════════════════════════════════════
// D04_START

/** Hoja AGENDA_CITAS */
function _shAgenda() {
  return _ensureSheet(CFG.SHEET_AGENDA, [
    "ID", "FECHA_CITA", "TRATAMIENTO", "TIPO_CITA", "SEDE",
    "NUMERO", "NOMBRE", "APELLIDO", "DNI", "CORREO",
    "ASESOR", "ID_ASESOR", "ESTADO_CITA", "VENTA_ID_MATCH",
    "OBS", "TS_CREADO", "TS_ACTUALIZADO", "HORA_CITA",
    "ETIQUETA_CAMPANA", "DOCTORA_ASIGNADA", "TIPO_ATENCION", "GCAL_EVENT_ID"
  ]);
}

/** Hoja SEGUIMIENTOS */
function _shSeguimientos() {
  return _ensureSheet(CFG.SHEET_SEGUIMIENTOS, [
    "ID", "FECHA_PROGRAMADA", "HORA_PROGRAMADA", "NUMERO",
    "TRATAMIENTO", "ASESOR", "ID_ASESOR", "OBS_RECONTACTO",
    "ESTADO", "TS_CREADO", "TS_ACTUALIZADO"
  ]);
}

/** Hoja SATISFACCION */
function _shSatisfaccion() {
  return _ensureSheet(CFG.SHEET_SATISFACCION, [
    "ID", "FECHA_ATENCION", "NUMERO", "NOMBRE_PACIENTE", "ASESOR",
    "P1_PRESENTACION", "P2_COMUNICACION", "P3_EXPLICACION",
    "P4_ATENCION", "P5_SATISFACCION_TRAT", "P6_RECOMENDACION",
    "FEEDBACK", "NOTA_PONDERADA", "FECHA_RESPUESTA", "ESTADO", "TS_CREADO"
  ]);
}

/** Hoja HORARIOS_DOCTORAS */
function _shHorarios() {
  return _ensureSheet(CFG.SHEET_HORARIOS, [
    "ID", "DOCTORA_LABEL", "DIA_SEMANA", "HORA_INICIO", "HORA_FIN",
    "SEDE", "CAP_DOCTORA", "CAP_ENFERMERIA", "ACTIVO", "GCAL_ID", "TS_CREADO"
  ]);
}

/** Hoja CONSOLIDADO_DE_PACIENTES */
function _shPacientes() {
  var ss = _ss();
  var sh = ss.getSheetByName(CFG.SHEET_PACIENTES);
  if (!sh) throw new Error(
    "Hoja " + CFG.SHEET_PACIENTES + " no encontrada. Creala primero."
  );
  return sh;
}

/**
 * Inicializa todas las hojas necesarias del sistema
 * Ejecutar una sola vez al configurar el proyecto
 */
function inicializarSistema() {
  _shAgenda();
  _shSeguimientos();
  _shSatisfaccion();
  _shHorarios();
  _notifSheet();
  _msgSheet();
  _estadoSheet();
  Logger.log("✅ Todas las hojas del sistema inicializadas correctamente.");
  Logger.log("Próximo paso: ejecutar test_Auth() para verificar acceso a RRHH.");
}
// D04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · TRIGGER onEdit
// Actualiza automáticamente el tipo de venta al editar VENTAS
// ══════════════════════════════════════════════════════════════
// D05_START

/**
 * onEdit — Trigger automático de Sheets
 * Cuando se edita CONSOLIDADO DE VENTAS, auto-detecta el tipo
 */
function onEdit(e) {
  try {
    var sh = e.range.getSheet();
    if (sh.getName() !== CFG.SHEET_VENTAS) return;

    var startRow = e.range.getRow();
    var numRows  = e.range.getNumRows();
    if (startRow === 1) return;

    var firstDataRow = startRow < 2 ? 2 : startRow;
    var lastDataRow  = startRow + numRows - 1;
    if (lastDataRow < 2) return;

    var COL_TRAT = VENT_COL.TRATAMIENTO + 1;  // base 1 para getRange
    var COL_TIPO = VENT_COL.TIPO + 1;
    var totalRows = lastDataRow - firstDataRow + 1;
    if (totalRows < 1) return;

    var tratRange = sh.getRange(firstDataRow, COL_TRAT, totalRows, 1).getValues();
    var tipoRange = sh.getRange(firstDataRow, COL_TIPO, totalRows, 1).getValues();

    var newTipos = tratRange.map(function(row, i) {
      var trat       = _up(_norm(row[0]));
      var tipoActual = _norm(tipoRange[i][0]);
      if (tipoActual !== "") return [tipoActual];
      if (!trat) return [""];
      var esProd = trat.indexOf("COMPRA DE PRODUCTO") >= 0 ||
                   trat.indexOf("PRODUCTO") >= 0;
      return [esProd ? "PRODUCTO" : "SERVICIO"];
    });

    sh.getRange(firstDataRow, COL_TIPO, totalRows, 1).setValues(newTipos);
  } catch(err) {
    Logger.log("onEdit error: " + err.message);
  }
}

/**
 * backfillTipo — Rellena el tipo en filas sin tipo
 * Ejecutar una sola vez para normalizar datos históricos
 */
function backfillTipo() {
  var sh   = _sh(CFG.SHEET_VENTAS);
  var lr   = sh.getLastRow();
  if (lr < 2) { Logger.log("Sin datos"); return; }

  var trats = sh.getRange(2, VENT_COL.TRATAMIENTO + 1, lr - 1, 1).getValues();
  var tipos = sh.getRange(2, VENT_COL.TIPO + 1,        lr - 1, 1).getValues();

  var result = trats.map(function(row, i) {
    var tipoActual = _norm(tipos[i][0]);
    if (tipoActual !== "") return [tipoActual];
    var trat = _up(_norm(row[0]));
    if (!trat) return [""];
    var esProd = trat.indexOf("COMPRA DE PRODUCTO") >= 0 ||
                 trat.indexOf("PRODUCTO") >= 0;
    return [esProd ? "PRODUCTO" : "SERVICIO"];
  });

  sh.getRange(2, VENT_COL.TIPO + 1, lr - 1, 1).setValues(result);
  Logger.log("backfillTipo: " + (lr - 1) + " filas procesadas.");
}
// D05_END

/**
 * TEST: Verificar acceso a todas las hojas críticas
 */
function test_DataAccess() {
  Logger.log("=== AscendaOS GS_04_DataAccess TEST ===");
  var hojas = [
    CFG.SHEET_RRHH, CFG.SHEET_LLAMADAS, CFG.SHEET_LEADS,
    CFG.SHEET_VENTAS, CFG.SHEET_AGENDA
  ];
  hojas.forEach(function(nombre) {
    try {
      var sh = _sh(nombre);
      Logger.log("✅ " + nombre + " — " + sh.getLastRow() + " filas");
    } catch(e) {
      Logger.log("❌ " + nombre + " — ERROR: " + e.message);
    }
  });
  Logger.log("=== FIN TEST ===");
}