/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_00_Repairs.gs                           ║
 * ║  Módulo: Reparaciones previas al Sheet — Capa 0 Bloque 3   ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config, GS_03_CoreHelpers             ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * ⚠️  IMPORTANTE: Ejecutar UNA SOLA VEZ, en el orden indicado.
 *     Cada función es idempotente (segura de re-ejecutar).
 *     Revisar el log después de cada ejecución.
 *
 * CONTENIDO:
 *   MOD-01 · R-01: Corregir header SEGUIMIENTOS col D
 *   MOD-02 · R-02: Agregar headers faltantes en LLAMADAS
 *   MOD-03 · R-03: Migrar NO CONTESTA → SIN CONTACTO (8,855 filas)
 *   MOD-04 · R-04: Backfill VENTA_ID en 600 ventas históricas
 *   MOD-05 · R-05/06: Agregar columnas nuevas en VENTAS
 *   MOD-06 · R-07: Agregar columnas nuevas en AGENDA
 *   MOD-07 · R-08: Agregar columnas nuevas en PACIENTES
 *   MOD-08 · R-09: Normalizar NUM_LIMPIO en VENTAS
 *   MOD-09 · R-10: Normalizar NUMERO en AGENDA
 *   MOD-10 · Función maestra: ejecutar todas en orden
 *   MOD-11 · Test de verificación post-reparación
 */

// ══════════════════════════════════════════════════════════════
// MOD-01 · R-01: SEGUIMIENTOS — Restaurar header col D
// ══════════════════════════════════════════════════════════════
// R01_START

/**
 * R-01: La celda D1 de SEGUIMIENTOS tiene un número de teléfono
 * (986293339) en lugar del header "NUMERO".
 * Impacto: toda lectura de números de seguimiento falla silenciosamente.
 */
function repair_R01_seguimientosHeader() {
  var sh = _sh(CFG.SHEET_SEGUIMIENTOS);
  var actual = _norm(sh.getRange(1, 4).getValue());

  if (actual === "NUMERO") {
    Logger.log("R-01: ✅ Ya corregido — col D ya tiene 'NUMERO'");
    return { ok: true, accion: "ya_corregido" };
  }

  Logger.log("R-01: Valor actual en D1: '" + actual + "' → corrigiendo...");
  sh.getRange(1, 4).setValue("NUMERO");
  Logger.log("R-01: ✅ Header 'NUMERO' restaurado en SEGUIMIENTOS col D");
  return { ok: true, accion: "corregido", valorAnterior: actual };
}
// R01_END

// ══════════════════════════════════════════════════════════════
// MOD-02 · R-02: LLAMADAS — Agregar headers faltantes
// ══════════════════════════════════════════════════════════════
// R02_START

/**
 * R-02: Las columnas H,J,K,L,M,N,O,P,Q,R,S,T de LLAMADAS
 * existen con datos pero sin encabezado visible.
 * Solo escribe donde la celda está vacía (idempotente).
 */
function repair_R02_llamadasHeaders() {
  var sh = _sh(CFG.SHEET_LLAMADAS);
  var fila1 = sh.getRange(1, 1, 1, 21).getValues()[0];

  // Mapa col (base 1) → header esperado según LLAM_COL de GS_01
  var headers = {
    1:  "FECHA",
    2:  "NUMERO",
    3:  "TRATAMIENTO",
    4:  "ESTADO",
    5:  "OBSERVACION",
    6:  "HORA DE LLAMADA",
    7:  "ASESOR",
    8:  "_RESERVADO_H",       // col H — reservado en GS_01
    9:  "NUMERO_LIMPIO",
    10: "ID_ASESOR",
    11: "ANUNCIO",
    12: "ORIGEN",
    13: "INTENTO",
    14: "ULT_TS",
    15: "PROX_REIN",
    16: "RESULTADO",
    17: "SESSION_ID",
    18: "DEVICE",
    19: "WHATSAPP",
    20: "TS_LOG",
    21: "SUB_ESTADO"
  };

  var corregidos = [];
  Object.keys(headers).forEach(function(colBase1) {
    var idx = Number(colBase1) - 1;
    var esperado = headers[colBase1];
    var actual = _norm(fila1[idx]);
    if (!actual) {
      sh.getRange(1, Number(colBase1)).setValue(esperado);
      corregidos.push("col " + colBase1 + " → " + esperado);
    }
  });

  if (corregidos.length === 0) {
    Logger.log("R-02: ✅ Todos los headers de LLAMADAS ya existen");
  } else {
    Logger.log("R-02: ✅ Headers agregados en LLAMADAS: " + corregidos.join(", "));
  }
  return { ok: true, corregidos: corregidos };
}
// R02_END

// ══════════════════════════════════════════════════════════════
// MOD-03 · R-03: LLAMADAS — Migrar NO CONTESTA → SIN CONTACTO
// ══════════════════════════════════════════════════════════════
// R03_START

/**
 * R-03: 8,855 filas tienen "NO CONTESTA" en col D (ESTADO).
 * Migrar a "SIN CONTACTO" para unificar dashboards y filtros.
 * Opera en lotes de 500 filas para no exceder límites de GAS.
 *
 * IMPORTANTE: Solo migra col D (ESTADO). La col U (SUB_ESTADO)
 * recibirá "NO CONTESTA" como sub-estado si está vacía,
 * preservando la granularidad del dato original.
 */
function repair_R03_migrateNoContesta() {
  var sh = _sh(CFG.SHEET_LLAMADAS);
  var lr = sh.getLastRow();
  if (lr < 2) {
    Logger.log("R-03: Sin datos en LLAMADAS");
    return { ok: true, migradas: 0 };
  }

  var BATCH    = 500;
  var migradas = 0;
  var inicio   = 2;

  while (inicio <= lr) {
    var fin     = Math.min(inicio + BATCH - 1, lr);
    var numRows = fin - inicio + 1;

    // Leer estado (col D=4) y sub_estado (col U=21)
    var colEstado    = sh.getRange(inicio, 4, numRows, 1).getValues();
    var colSubEstado = sh.getRange(inicio, 21, numRows, 1).getValues();

    var nuevoEstado    = [];
    var nuevoSubEstado = [];
    var cambio = false;

    for (var i = 0; i < numRows; i++) {
      var est = _up(_norm(colEstado[i][0]));
      var sub = _norm(colSubEstado[i][0]);

      if (est === "NO CONTESTA") {
        nuevoEstado.push(["SIN CONTACTO"]);
        // Preservar granularidad: si sub_estado vacío, poner "NO CONTESTA"
        nuevoSubEstado.push([sub || "NO CONTESTA"]);
        migradas++;
        cambio = true;
      } else {
        nuevoEstado.push([colEstado[i][0]]);
        nuevoSubEstado.push([colSubEstado[i][0]]);
      }
    }

    if (cambio) {
      sh.getRange(inicio, 4, numRows, 1).setValues(nuevoEstado);
      sh.getRange(inicio, 21, numRows, 1).setValues(nuevoSubEstado);
    }

    inicio += BATCH;
    Utilities.sleep(100); // Pausa anti-throttle
  }

  Logger.log("R-03: ✅ Migradas " + migradas + " filas NO CONTESTA → SIN CONTACTO");
  Logger.log("R-03:    Sub-estado 'NO CONTESTA' preservado en col U");
  return { ok: true, migradas: migradas };
}
// R03_END

// ══════════════════════════════════════════════════════════════
// MOD-04 · R-04: VENTAS — Backfill VENTA_ID
// ══════════════════════════════════════════════════════════════
// R04_START

/**
 * R-04: 600 ventas históricas sin VENTA_ID en col Q (índice 16).
 * Genera V-XXXXXXXX único para cada fila vacía.
 * Idempotente: solo escribe donde Q está vacío.
 */
function repair_R04_backfillVentaId() {
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) {
    Logger.log("R-04: Sin datos en VENTAS");
    return { ok: true, generados: 0 };
  }

  // Leer col Q (VENTA_ID = índice 16, col base 1 = 17)
  var colQ     = sh.getRange(2, 17, lr - 1, 1).getValues();
  var generados = 0;
  var updates  = [];

  for (var i = 0; i < colQ.length; i++) {
    var vid = _norm(colQ[i][0]);
    if (!vid) {
      updates.push({ row: i + 2, vid: "V-" + _uid().replace(/-/g,"").slice(0,8).toUpperCase() });
      generados++;
    }
  }

  // Escribir en lotes de 200
  var BATCH = 200;
  for (var j = 0; j < updates.length; j += BATCH) {
    var lote = updates.slice(j, j + BATCH);
    lote.forEach(function(u) {
      sh.getRange(u.row, 17).setValue(u.vid);
    });
    Utilities.sleep(150);
  }

  Logger.log("R-04: ✅ VENTA_ID generado para " + generados + " ventas históricas");
  return { ok: true, generados: generados };
}
// R04_END

// ══════════════════════════════════════════════════════════════
// MOD-05 · R-05/06: VENTAS — Agregar columnas nuevas
// ══════════════════════════════════════════════════════════════
// R05_START

/**
 * R-05: Agregar headers faltantes que GS_01 define pero el Sheet no tiene.
 * R-06: Agregar columnas del Bloque 3.
 *
 * Estado actual del Sheet (col → header):
 *   A-N (0-13): FECHA..TIPO ✅
 *   O (14): vacío → agregar _VACIO
 *   P (15): NUMERO_LIMPIO ✅
 *   Q (16): VENTA_ID ✅ (después de R-04)
 *   R (17): vacío → agregar NRO_DOC
 *   S (18): vacío → agregar ESTADO_DOC
 *   T (19): vacío → agregar AGRUPADOR_DIA (Bloque 3)
 *   U (20): vacío → agregar COMPROBANTE_ID (Bloque 3)
 *   V (21): vacío → agregar TIPO_COMPROBANTE (Bloque 3)
 */
function repair_R05R06_ventasColumnas() {
  var sh = _sh(CFG.SHEET_VENTAS);
  var maxCol = 22; // hasta col V
  var fila1  = sh.getRange(1, 1, 1, maxCol).getValues()[0];

  var columnas = {
    15: "_VACIO",          // col O (base 1 = 15)
    18: "NRO_DOC",         // col R
    19: "ESTADO_DOC",      // col S
    20: "AGRUPADOR_DIA",   // col T — Bloque 3
    21: "COMPROBANTE_ID",  // col U — Bloque 3
    22: "TIPO_COMPROBANTE" // col V — Bloque 3
  };

  var agregados = [];
  Object.keys(columnas).forEach(function(colBase1) {
    var idx     = Number(colBase1) - 1;
    var header  = columnas[colBase1];
    var actual  = idx < fila1.length ? _norm(fila1[idx]) : "";
    if (!actual) {
      sh.getRange(1, Number(colBase1)).setValue(header);
      agregados.push("col " + colBase1 + "(" + _colLetra(Number(colBase1)) + ") → " + header);
    }
  });

  if (agregados.length === 0) {
    Logger.log("R-05/06: ✅ Columnas de VENTAS ya existen");
  } else {
    Logger.log("R-05/06: ✅ Columnas agregadas en VENTAS: " + agregados.join(" | "));
  }
  return { ok: true, agregados: agregados };
}
// R05_END

// ══════════════════════════════════════════════════════════════
// MOD-06 · R-07: AGENDA — Agregar columnas nuevas
// ══════════════════════════════════════════════════════════════
// R07_START

/**
 * R-07: AGENDA_CITAS actualmente tiene 21 cols (hasta col U).
 * Faltan:
 *   col V (22): GCAL_EVENT_ID — ya definido en GS_01 AG_COL.GCAL_ID
 *   col W (23): ORIGEN_CITA — nuevo en Bloque 3
 *               Valores: LLAMADA | MANUAL | 360 | WEB | BOT
 */
function repair_R07_agendaColumnas() {
  var sh = _sh(CFG.SHEET_AGENDA);
  var fila1 = sh.getRange(1, 1, 1, 24).getValues()[0];

  var columnas = {
    22: "GCAL_EVENT_ID", // col V
    23: "ORIGEN_CITA"    // col W — Bloque 3
  };

  var agregados = [];
  Object.keys(columnas).forEach(function(colBase1) {
    var idx    = Number(colBase1) - 1;
    var header = columnas[colBase1];
    var actual = idx < fila1.length ? _norm(fila1[idx]) : "";
    if (!actual) {
      sh.getRange(1, Number(colBase1)).setValue(header);
      agregados.push("col " + colBase1 + "(" + _colLetra(Number(colBase1)) + ") → " + header);
    }
  });

  if (agregados.length === 0) {
    Logger.log("R-07: ✅ Columnas de AGENDA ya existen");
  } else {
    Logger.log("R-07: ✅ Columnas agregadas en AGENDA: " + agregados.join(" | "));
  }
  return { ok: true, agregados: agregados };
}
// R07_END

// ══════════════════════════════════════════════════════════════
// MOD-07 · R-08: PACIENTES — Agregar columnas Bloque 3
// ══════════════════════════════════════════════════════════════
// R08_START

/**
 * R-08: CONSOLIDADO_DE_PACIENTES tiene 21 cols (hasta col U = FOTO_URL).
 * Agregar para Bloque 3:
 *   col V (22): ETIQUETA_BASE
 *   col W (23): SCORE_ESTADO — ACTIVO | EN_RIESGO | INACTIVO
 *   col X (24): DIAS_ULTIMA_VISITA — número, calculado por recalcularTodosPacientes()
 */
function repair_R08_pacientesColumnas() {
  var sh    = _sh(CFG.SHEET_PACIENTES);
  var fila1 = sh.getRange(1, 1, 1, 25).getValues()[0];

  var columnas = {
    22: "ETIQUETA_BASE",      // col V
    23: "SCORE_ESTADO",       // col W
    24: "DIAS_ULTIMA_VISITA"  // col X
  };

  var agregados = [];
  Object.keys(columnas).forEach(function(colBase1) {
    var idx    = Number(colBase1) - 1;
    var header = columnas[colBase1];
    var actual = idx < fila1.length ? _norm(fila1[idx]) : "";
    if (!actual) {
      sh.getRange(1, Number(colBase1)).setValue(header);
      agregados.push("col " + colBase1 + "(" + _colLetra(Number(colBase1)) + ") → " + header);
    }
  });

  if (agregados.length === 0) {
    Logger.log("R-08: ✅ Columnas de PACIENTES ya existen");
  } else {
    Logger.log("R-08: ✅ Columnas agregadas en PACIENTES: " + agregados.join(" | "));
  }
  return { ok: true, agregados: agregados };
}
// R08_END

// ══════════════════════════════════════════════════════════════
// MOD-08 · R-09: VENTAS — Normalizar NUM_LIMPIO (col P)
// ══════════════════════════════════════════════════════════════
// R09_START

/**
 * R-09: Col P (NUMERO_LIMPIO) de VENTAS existe pero algunos valores
 * tienen formato inconsistente (+51, espacios, 10+ dígitos).
 * Estandarizar a 9 dígitos sin prefijos para que el cruce con
 * PACIENTES funcione correctamente.
 */
function repair_R09_normalizarVentasNumero() {
  var sh = _sh(CFG.SHEET_VENTAS);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, normalizados: 0 };

  // Leer col E (CELULAR=5, base1=5) y col P (NUM_LIMPIO=16, base1=16)
  var colCelular  = sh.getRange(2, 5, lr - 1, 1).getValues();
  var colNumLimp  = sh.getRange(2, 16, lr - 1, 1).getValues();

  var normalizados = 0;
  var nuevos = [];

  for (var i = 0; i < colNumLimp.length; i++) {
    var actual  = _normNum(colNumLimp[i][0]);
    var celular = _normNum(colCelular[i][0]);
    // Usar el que esté disponible, normalizar ambos igual
    var fuente  = actual || celular;
    var limpio  = _phone(fuente);

    var actualRaw = _norm(colNumLimp[i][0]).replace(/\D/g,"").slice(-9);
    if (limpio && limpio !== actualRaw) {
      nuevos.push([limpio]);
      normalizados++;
    } else {
      nuevos.push([colNumLimp[i][0]]);
    }
  }

  if (normalizados > 0) {
    sh.getRange(2, 16, lr - 1, 1).setValues(nuevos);
  }

  Logger.log("R-09: ✅ " + normalizados + " números normalizados en VENTAS col P");
  return { ok: true, normalizados: normalizados };
}
// R09_END

// ══════════════════════════════════════════════════════════════
// MOD-09 · R-10: AGENDA — Normalizar NUMERO (col F)
// ══════════════════════════════════════════════════════════════
// R10_START

/**
 * R-10: Col F (NUMERO) de AGENDA tiene números con formato inconsistente.
 * 102 citas no se vinculan a pacientes por esta razón.
 * Normalizar igual que R-09.
 */
function repair_R10_normalizarAgendaNumero() {
  var sh = _sh(CFG.SHEET_AGENDA);
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, normalizados: 0 };

  // Col F = NUMERO (AG_COL.NUMERO = 5, base1 = 6)
  var colNum = sh.getRange(2, 6, lr - 1, 1).getValues();

  var normalizados = 0;
  var nuevos = [];

  for (var i = 0; i < colNum.length; i++) {
    var raw    = colNum[i][0];
    var limpio = _phone(_norm(raw));
    var actual = _norm(raw).replace(/\D/g,"").slice(-9);

    if (limpio && limpio !== actual) {
      nuevos.push([limpio]);
      normalizados++;
    } else {
      nuevos.push([raw]);
    }
  }

  if (normalizados > 0) {
    sh.getRange(2, 6, lr - 1, 1).setValues(nuevos);
  }

  Logger.log("R-10: ✅ " + normalizados + " números normalizados en AGENDA col F");
  return { ok: true, normalizados: normalizados };
}
// R10_END

// ══════════════════════════════════════════════════════════════
// MOD-10 · FUNCIÓN MAESTRA — Ejecutar todas las reparaciones
// ══════════════════════════════════════════════════════════════
// MASTER_START

/**
 * ▶️ EJECUTAR ESTA FUNCIÓN DESDE EL EDITOR DE APPS SCRIPT
 *
 * Corre todas las reparaciones en el orden correcto.
 * Tiempo estimado: 3-6 minutos (el paso más lento es R-03 con 8,855 filas).
 * Idempotente: segura de ejecutar más de una vez.
 */
function repair_ejecutarTodo() {
  var inicio = new Date();
  Logger.log("╔══════════════════════════════════════════════════╗");
  Logger.log("║  AscendaOS — Reparaciones Capa 0 Bloque 3      ║");
  Logger.log("║  Inicio: " + inicio.toLocaleString() + "           ║");
  Logger.log("╚══════════════════════════════════════════════════╝");

  var resultados = {};

  try {
    Logger.log("\n── R-01: Restaurar header SEGUIMIENTOS col D ──");
    resultados.r01 = repair_R01_seguimientosHeader();
  } catch(e) { Logger.log("R-01 ERROR: " + e.message); resultados.r01 = { ok: false, error: e.message }; }

  try {
    Logger.log("\n── R-02: Agregar headers LLAMADAS ──");
    resultados.r02 = repair_R02_llamadasHeaders();
  } catch(e) { Logger.log("R-02 ERROR: " + e.message); resultados.r02 = { ok: false, error: e.message }; }

  try {
    Logger.log("\n── R-04: Backfill VENTA_ID en VENTAS ──");
    resultados.r04 = repair_R04_backfillVentaId();
  } catch(e) { Logger.log("R-04 ERROR: " + e.message); resultados.r04 = { ok: false, error: e.message }; }

  try {
    Logger.log("\n── R-09: Normalizar NUM_LIMPIO en VENTAS ──");
    resultados.r09 = repair_R09_normalizarVentasNumero();
  } catch(e) { Logger.log("R-09 ERROR: " + e.message); resultados.r09 = { ok: false, error: e.message }; }

  try {
    Logger.log("\n── R-10: Normalizar NUMERO en AGENDA ──");
    resultados.r10 = repair_R10_normalizarAgendaNumero();
  } catch(e) { Logger.log("R-10 ERROR: " + e.message); resultados.r10 = { ok: false, error: e.message }; }

  try {
    Logger.log("\n── R-03: Migrar NO CONTESTA → SIN CONTACTO (lento, ~2min) ──");
    resultados.r03 = repair_R03_migrateNoContesta();
  } catch(e) { Logger.log("R-03 ERROR: " + e.message); resultados.r03 = { ok: false, error: e.message }; }

  try {
    Logger.log("\n── R-05/06: Columnas nuevas en VENTAS ──");
    resultados.r0506 = repair_R05R06_ventasColumnas();
  } catch(e) { Logger.log("R-05/06 ERROR: " + e.message); resultados.r0506 = { ok: false, error: e.message }; }

  try {
    Logger.log("\n── R-07: Columnas nuevas en AGENDA ──");
    resultados.r07 = repair_R07_agendaColumnas();
  } catch(e) { Logger.log("R-07 ERROR: " + e.message); resultados.r07 = { ok: false, error: e.message }; }

  try {
    Logger.log("\n── R-08: Columnas nuevas en PACIENTES ──");
    resultados.r08 = repair_R08_pacientesColumnas();
  } catch(e) { Logger.log("R-08 ERROR: " + e.message); resultados.r08 = { ok: false, error: e.message }; }

  var fin = new Date();
  var duracion = Math.round((fin - inicio) / 1000);

  Logger.log("\n╔══════════════════════════════════════════════════╗");
  Logger.log("║  REPARACIONES COMPLETADAS                       ║");
  Logger.log("║  Duración: " + duracion + " segundos                        ║");
  Logger.log("╚══════════════════════════════════════════════════╝");
  Logger.log("\nRESUMEN:");
  Object.keys(resultados).forEach(function(k) {
    var r = resultados[k];
    Logger.log("  " + k.toUpperCase() + ": " + (r.ok ? "✅" : "❌") + " " + JSON.stringify(r));
  });
  Logger.log("\n✅ Sistema listo para ejecutar recalcularTodosPacientes() (Capa 1)");

  return resultados;
}
// MASTER_END

// ══════════════════════════════════════════════════════════════
// MOD-11 · TEST DE VERIFICACIÓN POST-REPARACIÓN
// ══════════════════════════════════════════════════════════════
// TEST_START

/**
 * Ejecutar después de repair_ejecutarTodo() para verificar resultados.
 * Lee el Sheet y comprueba que todas las reparaciones se aplicaron.
 */
function repair_verificar() {
  Logger.log("=== VERIFICACIÓN POST-REPARACIÓN ===");

  var ok = true;

  // ── Verificar R-01: SEGUIMIENTOS col D ──
  var shSeg = _sh(CFG.SHEET_SEGUIMIENTOS);
  var headerD = _norm(shSeg.getRange(1, 4).getValue());
  if (headerD === "NUMERO") {
    Logger.log("✅ R-01: SEGUIMIENTOS col D = 'NUMERO'");
  } else {
    Logger.log("❌ R-01: SEGUIMIENTOS col D = '" + headerD + "' (esperado: NUMERO)");
    ok = false;
  }

  // ── Verificar R-02: Headers LLAMADAS ──
  var shLlam = _sh(CFG.SHEET_LLAMADAS);
  var h9  = _norm(shLlam.getRange(1, 9).getValue());
  var h10 = _norm(shLlam.getRange(1, 10).getValue());
  var h21 = _norm(shLlam.getRange(1, 21).getValue());
  if (h9 && h10 && h21) {
    Logger.log("✅ R-02: Headers LLAMADAS OK (col9=" + h9 + ", col10=" + h10 + ", col21=" + h21 + ")");
  } else {
    Logger.log("❌ R-02: Faltan headers en LLAMADAS (col9=" + h9 + ", col10=" + h10 + ", col21=" + h21 + ")");
    ok = false;
  }

  // ── Verificar R-03: NO CONTESTA migrado ──
  var lrLlam = shLlam.getLastRow();
  if (lrLlam >= 2) {
    var estados = shLlam.getRange(2, 4, Math.min(lrLlam - 1, 500), 1).getValues();
    var noContesta = estados.filter(function(r) { return _up(_norm(r[0])) === "NO CONTESTA"; }).length;
    if (noContesta === 0) {
      Logger.log("✅ R-03: Sin registros 'NO CONTESTA' en muestra de 500 filas");
    } else {
      Logger.log("⚠️  R-03: Aún hay " + noContesta + " registros 'NO CONTESTA' (muestra 500 filas)");
    }
  }

  // ── Verificar R-04: VENTA_ID ──
  var shVent = _sh(CFG.SHEET_VENTAS);
  var lrVent = shVent.getLastRow();
  if (lrVent >= 2) {
    var vids = shVent.getRange(2, 17, Math.min(lrVent - 1, 50), 1).getValues();
    var sinVid = vids.filter(function(r) { return !_norm(r[0]); }).length;
    if (sinVid === 0) {
      Logger.log("✅ R-04: VENTA_ID presente en muestra de 50 filas");
    } else {
      Logger.log("❌ R-04: " + sinVid + " filas sin VENTA_ID en muestra de 50 filas");
      ok = false;
    }
  }

  // ── Verificar R-05/06: Columnas VENTAS ──
  var fila1V = shVent.getRange(1, 1, 1, 23).getValues()[0];
  var colsVentas = { 15: "_VACIO", 20: "AGRUPADOR_DIA", 21: "COMPROBANTE_ID", 22: "TIPO_COMPROBANTE" };
  var faltanV = [];
  Object.keys(colsVentas).forEach(function(c) {
    if (!_norm(fila1V[Number(c)-1])) faltanV.push(colsVentas[c]);
  });
  if (faltanV.length === 0) {
    Logger.log("✅ R-05/06: Columnas de VENTAS OK");
  } else {
    Logger.log("❌ R-05/06: Faltan columnas en VENTAS: " + faltanV.join(", "));
    ok = false;
  }

  // ── Verificar R-07: Columnas AGENDA ──
  var shAg  = _sh(CFG.SHEET_AGENDA);
  var fila1A = shAg.getRange(1, 1, 1, 24).getValues()[0];
  var h22A = _norm(fila1A[21]);
  var h23A = _norm(fila1A[22]);
  if (h22A && h23A) {
    Logger.log("✅ R-07: AGENDA col V=" + h22A + ", col W=" + h23A);
  } else {
    Logger.log("❌ R-07: Faltan columnas en AGENDA (col V=" + h22A + ", col W=" + h23A + ")");
    ok = false;
  }

  // ── Verificar R-08: Columnas PACIENTES ──
  var shPac  = _sh(CFG.SHEET_PACIENTES);
  var fila1P = shPac.getRange(1, 1, 1, 25).getValues()[0];
  var h22P = _norm(fila1P[21]);
  var h23P = _norm(fila1P[22]);
  var h24P = _norm(fila1P[23]);
  if (h22P && h23P && h24P) {
    Logger.log("✅ R-08: PACIENTES col V=" + h22P + ", col W=" + h23P + ", col X=" + h24P);
  } else {
    Logger.log("❌ R-08: Faltan columnas en PACIENTES (V=" + h22P + ", W=" + h23P + ", X=" + h24P + ")");
    ok = false;
  }

  Logger.log("\n" + (ok ? "✅ TODAS LAS REPARACIONES VERIFICADAS — Listo para Capa 1" : "⚠️  HAY PROBLEMAS — Revisar los ❌ arriba y re-ejecutar"));
  return { ok: ok };
}
// TEST_END

// ══════════════════════════════════════════════════════════════
// HELPER INTERNO: Letra de columna (base 1)
// ══════════════════════════════════════════════════════════════
// HELPER_START

/**
 * Convierte número de columna (base 1) a letra(s)
 * Ej: 1→A, 26→Z, 27→AA, 28→AB
 */
function _colLetra(n) {
  var s = "";
  while (n > 0) {
    n--;
    s = String.fromCharCode(65 + (n % 26)) + s;
    n = Math.floor(n / 26);
  }
  return s;
}
// HELPER_END

/**
 * ══════════════════════════════════════════════════════════════
 * CHECKLIST DE PRUEBA — Ejecutar después de repair_ejecutarTodo()
 * ══════════════════════════════════════════════════════════════
 *
 * 1. Abrir Sheet → hoja SEGUIMIENTOS → verificar que D1 = "NUMERO"
 * 2. Abrir hoja CONSOLIDADO DE LLAMADAS → verificar que fila 1
 *    tenga headers en TODAS las columnas hasta col U
 * 3. Buscar cualquier celda en col D de LLAMADAS → no debe decir "NO CONTESTA"
 * 4. Abrir hoja CONSOLIDADO DE VENTAS → col Q debe tener V-XXXXXXXX en cada fila
 * 5. VENTAS fila 1: debe tener columnas hasta col V (TIPO_COMPROBANTE)
 * 6. AGENDA fila 1: debe tener col V = GCAL_EVENT_ID, col W = ORIGEN_CITA
 * 7. PACIENTES fila 1: debe tener col V = ETIQUETA_BASE, col W = SCORE_ESTADO, col X = DIAS_ULTIMA_VISITA
 * 8. Ejecutar repair_verificar() y ver que todos salen ✅
 *
 * Si todo OK → ejecutar recalcularTodosPacientes() (GS_23 — Capa 1)
 */