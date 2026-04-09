/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  AscendaOS v1 — GS_23_SheetSetup.gs                        ║
 * ║  Módulo: Setup de Estructura de Datos v2.0                  ║
 * ║  Autor: César Jáuregui / CREACTIVE                         ║
 * ║  Versión: 1.0.0                                             ║
 * ║  Dependencias: GS_01_Config                                 ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * PROPÓSITO:
 *   Ejecutar UNA SOLA VEZ para:
 *   1. Crear la hoja LOG_TURNOS con sus headers
 *   2. Crear / completar la hoja CONFIGURACION con valores base
 *   3. Agregar columna SUB_ESTADO a CONSOLIDADO DE LLAMADAS
 *   4. Agregar columnas PERMISOS y FOTO_URL a RRHH
 *   5. Agregar columna FOTO_URL a CONSOLIDADO_DE_PACIENTES
 *   6. Poblar CONFIGURACION con valores iniciales del sistema
 *
 * INSTRUCCIÓN DE USO:
 *   1. Abre Apps Script → GS_23_SheetSetup.gs
 *   2. Ejecuta: runSheetSetup_v2()
 *   3. Revisa el log para confirmar que todo se creó bien
 *   4. NO ejecutes dos veces — tiene protección anti-duplicado
 *
 * SEGURIDAD:
 *   Todas las funciones verifican si la columna/hoja ya existe
 *   antes de crearla. Es seguro ejecutar más de una vez pero
 *   no hará cambios si todo ya está creado.
 */

// ══════════════════════════════════════════════════════════════
// FUNCIÓN PRINCIPAL — ejecutar esta
// ══════════════════════════════════════════════════════════════

/**
 * runSheetSetup_v2 — Función principal de setup
 * Ejecutar UNA VEZ desde el editor de Apps Script
 */
function runSheetSetup_v2() {
  Logger.log("════════════════════════════════════════════════");
  Logger.log("  AscendaOS v2.0 — Sheet Setup iniciado");
  Logger.log("  " + new Date().toLocaleString("es-PE", {timeZone: "America/Lima"}));
  Logger.log("════════════════════════════════════════════════");

  var resultados = [];

  try {
    resultados.push(setup_CrearHojaLogTurnos());
  } catch(e) {
    resultados.push("❌ LOG_TURNOS: " + e.message);
  }

  try {
    resultados.push(setup_CrearHojaConfiguracion());
  } catch(e) {
    resultados.push("❌ CONFIGURACION: " + e.message);
  }

  try {
    resultados.push(setup_AgregarColSubEstadoLlamadas());
  } catch(e) {
    resultados.push("❌ SUB_ESTADO en LLAMADAS: " + e.message);
  }

  try {
    resultados.push(setup_AgregarColsRRHH());
  } catch(e) {
    resultados.push("❌ Cols RRHH: " + e.message);
  }

  try {
    resultados.push(setup_AgregarColFotoUrlPacientes());
  } catch(e) {
    resultados.push("❌ FOTO_URL en PACIENTES: " + e.message);
  }

  try {
    resultados.push(setup_PoblarConfiguracion());
  } catch(e) {
    resultados.push("❌ Poblar CONFIGURACION: " + e.message);
  }

  Logger.log("\n════════════════════════════════════════════════");
  Logger.log("  RESUMEN DEL SETUP:");
  Logger.log("════════════════════════════════════════════════");
  resultados.forEach(function(r) { Logger.log("  " + r); });
  Logger.log("════════════════════════════════════════════════");
  Logger.log("  Setup completado. Revisa el log.");
  Logger.log("════════════════════════════════════════════════");
}

// ══════════════════════════════════════════════════════════════
// FUNCIÓN 1 · CREAR HOJA LOG_TURNOS
// ══════════════════════════════════════════════════════════════

function setup_CrearHojaLogTurnos() {
  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);
  var nombreHoja = CFG.SHEET_TURNOS; // "LOG_TURNOS"

  // Verificar si ya existe
  var hojaExistente = ss.getSheetByName(nombreHoja);
  if (hojaExistente) {
    return "⏭️  LOG_TURNOS ya existe — sin cambios";
  }

  // Crear la hoja nueva
  var sh = ss.insertSheet(nombreHoja);

  // Headers (basados en TURN_COL de GS_01_Config)
  var headers = [
    "FECHA",           // A - TURN_COL.FECHA
    "ID_ASESOR",       // B - TURN_COL.ID_ASESOR
    "ASESOR",          // C - TURN_COL.ASESOR
    "HORA_ENTRADA",    // D - TURN_COL.HORA_ENTRADA
    "HORA_SALIDA",     // E - TURN_COL.HORA_SALIDA
    "MIN_BREAK",       // F - TURN_COL.MIN_BREAK
    "MIN_BANIO",       // G - TURN_COL.MIN_BANIO
    "MIN_ATENCION",    // H - TURN_COL.MIN_ATENCION
    "MIN_LIMPIEZA",    // I - TURN_COL.MIN_LIMPIEZA
    "MIN_CAPACITACION",// J - TURN_COL.MIN_CAPACITACION
    "MIN_OTROS",       // K - TURN_COL.MIN_OTROS
    "MIN_TRABAJO",     // L - TURN_COL.MIN_TRABAJO
    "TARDANZA_MIN",    // M - TURN_COL.TARDANZA_MIN
    "HORAS_EXTRA_MIN", // N - TURN_COL.HORAS_EXTRA_MIN
    "ESTADO_TURNO",    // O - TURN_COL.ESTADO_TURNO (ABIERTO/CERRADO)
    "TS_CREADO",       // P - TURN_COL.TS_CREADO
    "TS_ACTUALIZADO"   // Q - TURN_COL.TS_ACTUALIZADO
  ];

  sh.getRange(1, 1, 1, headers.length).setValues([headers]);

  // Formato del header
  var headerRange = sh.getRange(1, 1, 1, headers.length);
  headerRange.setBackground("#1a73e8");
  headerRange.setFontColor("#ffffff");
  headerRange.setFontWeight("bold");
  headerRange.setFontSize(10);

  // Anchos de columna
  sh.setColumnWidth(1, 100); // FECHA
  sh.setColumnWidth(2, 90);  // ID_ASESOR
  sh.setColumnWidth(3, 110); // ASESOR
  sh.setColumnWidth(4, 110); // HORA_ENTRADA
  sh.setColumnWidth(5, 110); // HORA_SALIDA
  sh.setColumnWidths(6, 10, 85); // cols F-O: minutos

  // Congelar la fila de headers
  sh.setFrozenRows(1);

  return "✅ LOG_TURNOS creada con " + headers.length + " columnas";
}

// ══════════════════════════════════════════════════════════════
// FUNCIÓN 2 · CREAR / COMPLETAR HOJA CONFIGURACION
// ══════════════════════════════════════════════════════════════

function setup_CrearHojaConfiguracion() {
  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);
  var nombreHoja = CFG.SHEET_CONFIG; // "CONFIGURACION"

  var sh = ss.getSheetByName(nombreHoja);
  var esNueva = false;

  if (!sh) {
    sh = ss.insertSheet(nombreHoja);
    esNueva = true;
  }

  // Verificar si ya tiene headers
  var primeraFila = sh.getRange(1, 1, 1, 5).getValues()[0];
  var tieneHeaders = _norm(primeraFila[0]) === "CLAVE";

  if (!tieneHeaders) {
    // Crear headers
    var headers = ["CLAVE", "VALOR", "DESCRIPCION", "UPDATED_AT", "UPDATED_BY"];
    sh.getRange(1, 1, 1, headers.length).setValues([headers]);

    var headerRange = sh.getRange(1, 1, 1, headers.length);
    headerRange.setBackground("#34a853");
    headerRange.setFontColor("#ffffff");
    headerRange.setFontWeight("bold");

    sh.setColumnWidth(1, 200); // CLAVE
    sh.setColumnWidth(2, 250); // VALOR
    sh.setColumnWidth(3, 300); // DESCRIPCION
    sh.setColumnWidth(4, 160); // UPDATED_AT
    sh.setColumnWidth(5, 120); // UPDATED_BY
    sh.setFrozenRows(1);
  }

  if (esNueva) {
    return "✅ CONFIGURACION creada con headers";
  }
  return "⏭️  CONFIGURACION ya existe — headers verificados";
}

// ══════════════════════════════════════════════════════════════
// FUNCIÓN 3 · AGREGAR SUB_ESTADO A CONSOLIDADO DE LLAMADAS
// ══════════════════════════════════════════════════════════════

function setup_AgregarColSubEstadoLlamadas() {
  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);
  var sh = ss.getSheetByName(CFG.SHEET_LLAMADAS);

  if (!sh) return "❌ Hoja LLAMADAS no encontrada";

  // Verificar si la columna ya existe
  var ultimaCol = sh.getLastColumn();
  if (ultimaCol < 1) return "❌ Hoja LLAMADAS vacía";

  var headers = sh.getRange(1, 1, 1, ultimaCol).getValues()[0];

  // Buscar si SUB_ESTADO ya existe
  for (var i = 0; i < headers.length; i++) {
    if (_up(_norm(headers[i])) === "SUB_ESTADO") {
      return "⏭️  SUB_ESTADO ya existe en LLAMADAS (col " + (i+1) + ") — sin cambios";
    }
  }

  // La nueva columna va en la posición LLAM_COL.SUB_ESTADO + 1 (base 1)
  // LLAM_COL.SUB_ESTADO = 20 (base 0) = columna 21 (base 1)
  var nuevaColBase1 = LLAM_COL.SUB_ESTADO + 1; // = 21

  // Verificar que la hoja tiene suficientes columnas o agregar
  var colActual = sh.getLastColumn();
  if (colActual < nuevaColBase1) {
    // Si tiene menos de 21 cols, agregar el header directamente en col 21
    sh.getRange(1, nuevaColBase1).setValue("SUB_ESTADO");
  } else {
    // Si tiene más cols, insertar la columna en la posición correcta
    // (solo si el contenido de esa col no es ya SUB_ESTADO)
    var valorEnCol = _norm(sh.getRange(1, nuevaColBase1).getValue());
    if (_up(valorEnCol) !== "SUB_ESTADO") {
      sh.insertColumnAfter(nuevaColBase1 - 1);
      sh.getRange(1, nuevaColBase1).setValue("SUB_ESTADO");
    }
  }

  // Formatear el header
  var cell = sh.getRange(1, nuevaColBase1);
  cell.setBackground("#ff9800");
  cell.setFontColor("#ffffff");
  cell.setFontWeight("bold");
  sh.setColumnWidth(nuevaColBase1, 140);

  // Agregar validación de datos en la columna (solo 2 en adelante)
  var ultimaFila = Math.max(sh.getLastRow(), 2);
  var rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(["NO CONTESTA", "SIN SERVICIO", "NUMERO NO EXISTE"], true)
    .setAllowInvalid(true)
    .build();
  sh.getRange(2, nuevaColBase1, ultimaFila - 1, 1).setDataValidation(rule);

  return "✅ SUB_ESTADO agregado a LLAMADAS (col " + nuevaColBase1 + " = U)";
}

// ══════════════════════════════════════════════════════════════
// FUNCIÓN 4 · AGREGAR PERMISOS Y FOTO_URL A RRHH
// ══════════════════════════════════════════════════════════════

function setup_AgregarColsRRHH() {
  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);
  var sh = ss.getSheetByName(CFG.SHEET_RRHH);

  if (!sh) return "❌ Hoja RRHH no encontrada";

  var resultado = [];
  var ultimaCol = sh.getLastColumn();
  var headers = sh.getRange(1, 1, 1, ultimaCol).getValues()[0];

  // Mapear headers existentes (en mayúsculas para comparar)
  var headersUpper = headers.map(function(h) { return _up(_norm(h)); });

  // ── PERMISOS (col Q = índice 16 = base1 17) ──────────────────
  var colPermisos = RRHH_COL.PERMISOS + 1; // = 17
  if (headersUpper.indexOf("PERMISOS") === -1) {
    if (ultimaCol < colPermisos) {
      sh.getRange(1, colPermisos).setValue("PERMISOS");
    } else {
      sh.insertColumnAfter(colPermisos - 1);
      sh.getRange(1, colPermisos).setValue("PERMISOS");
    }
    // Formatear header
    var cellP = sh.getRange(1, colPermisos);
    cellP.setBackground("#673ab7");
    cellP.setFontColor("#ffffff");
    cellP.setFontWeight("bold");
    sh.setColumnWidth(colPermisos, 80);

    // Poblar con permisos por defecto según el rol de cada asesor
    var ultimaFila = sh.getLastRow();
    if (ultimaFila > 1) {
      var datosRoles = sh.getRange(2, RRHH_COL.PUESTO + 1, ultimaFila - 1, 1).getValues();
      for (var i = 0; i < datosRoles.length; i++) {
        var rol = _up(_norm(datosRoles[i][0]));
        var permisoDefault = PERMISOS_DEFAULT[rol] || PERMISOS_DEFAULT["ASESOR"];
        sh.getRange(i + 2, colPermisos).setValue(permisoDefault);
      }
    }
    resultado.push("✅ PERMISOS agregado a RRHH (col " + colPermisos + " = Q)");
  } else {
    resultado.push("⏭️  PERMISOS ya existe en RRHH");
  }

  // ── FOTO_URL (col R = índice 17 = base1 18) ───────────────────
  var colFoto = RRHH_COL.FOTO_URL + 1; // = 18
  // Refrescar ultimaCol después de posible inserción
  ultimaCol = sh.getLastColumn();
  headers = sh.getRange(1, 1, 1, ultimaCol).getValues()[0];
  headersUpper = headers.map(function(h) { return _up(_norm(h)); });

  if (headersUpper.indexOf("FOTO_URL") === -1) {
    if (ultimaCol < colFoto) {
      sh.getRange(1, colFoto).setValue("FOTO_URL");
    } else {
      sh.insertColumnAfter(colFoto - 1);
      sh.getRange(1, colFoto).setValue("FOTO_URL");
    }
    var cellF = sh.getRange(1, colFoto);
    cellF.setBackground("#e91e63");
    cellF.setFontColor("#ffffff");
    cellF.setFontWeight("bold");
    sh.setColumnWidth(colFoto, 250);
    resultado.push("✅ FOTO_URL agregado a RRHH (col " + colFoto + " = R)");
  } else {
    resultado.push("⏭️  FOTO_URL ya existe en RRHH");
  }

  return resultado.join(" | ");
}

// ══════════════════════════════════════════════════════════════
// FUNCIÓN 5 · AGREGAR FOTO_URL A CONSOLIDADO_DE_PACIENTES
// ══════════════════════════════════════════════════════════════

function setup_AgregarColFotoUrlPacientes() {
  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);
  var sh = ss.getSheetByName(CFG.SHEET_PACIENTES);

  if (!sh) return "❌ Hoja PACIENTES no encontrada";

  var ultimaCol = sh.getLastColumn();
  var headers = sh.getRange(1, 1, 1, ultimaCol).getValues()[0];
  var headersUpper = headers.map(function(h) { return _up(_norm(h)); });

  if (headersUpper.indexOf("FOTO_URL") !== -1) {
    return "⏭️  FOTO_URL ya existe en PACIENTES — sin cambios";
  }

  // PAC_COL.FOTO_URL = 20 → col 21 en base 1
  var nuevaColBase1 = PAC_COL.FOTO_URL + 1; // = 21

  if (ultimaCol < nuevaColBase1) {
    sh.getRange(1, nuevaColBase1).setValue("FOTO_URL");
  } else {
    sh.insertColumnAfter(nuevaColBase1 - 1);
    sh.getRange(1, nuevaColBase1).setValue("FOTO_URL");
  }

  var cell = sh.getRange(1, nuevaColBase1);
  cell.setBackground("#e91e63");
  cell.setFontColor("#ffffff");
  cell.setFontWeight("bold");
  sh.setColumnWidth(nuevaColBase1, 250);

  return "✅ FOTO_URL agregado a PACIENTES (col " + nuevaColBase1 + " = U)";
}

// ══════════════════════════════════════════════════════════════
// FUNCIÓN 6 · POBLAR HOJA CONFIGURACION CON VALORES INICIALES
// ══════════════════════════════════════════════════════════════

function setup_PoblarConfiguracion() {
  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);
  var sh = ss.getSheetByName(CFG.SHEET_CONFIG);

  if (!sh) return "❌ Hoja CONFIGURACION no encontrada (ejecuta setup_CrearHojaConfiguracion primero)";

  var ahora = new Date().toISOString();
  var autor  = "SETUP_v2";

  // Verificar qué claves ya existen
  var ultimaFila = sh.getLastRow();
  var clavesExistentes = {};
  if (ultimaFila > 1) {
    var datosExistentes = sh.getRange(2, 1, ultimaFila - 1, 1).getValues();
    for (var i = 0; i < datosExistentes.length; i++) {
      var clave = _norm(datosExistentes[i][0]);
      if (clave) clavesExistentes[clave] = true;
    }
  }

  // Valores iniciales del sistema
  var configs = [
    // ── Empresa ─────────────────────────────────────────────────
    ["empresa_nombre",         "AscendaOS",             "Nombre de la empresa o clínica",           ahora, autor],
    ["empresa_ruc",            "",                      "RUC principal de la empresa",              ahora, autor],
    ["empresa_ruc_2",          "",                      "RUC secundario si aplica",                 ahora, autor],
    ["empresa_direccion",      "",                      "Dirección física",                         ahora, autor],
    ["empresa_telefono",       "",                      "Teléfono de contacto",                     ahora, autor],
    ["empresa_email",          "",                      "Email corporativo",                        ahora, autor],
    ["empresa_logo_url",       "",                      "URL del logo de la empresa",               ahora, autor],
    ["empresa_nombre_app",     "AscendaOS",             "Nombre que aparece en la interfaz",        ahora, autor],
    // ── Sistema ─────────────────────────────────────────────────
    ["sistema_tz",             "America/Lima",          "Zona horaria del sistema (Perú)",          ahora, autor],
    ["sistema_idioma",         "es",                    "Idioma del sistema",                       ahora, autor],
    ["sistema_color_primario", "#0A4FBF",               "Color primario de la marca (hex)",         ahora, autor],
    ["sistema_color_acento",   "#00C9A7",               "Color de acento turquesa (hex)",           ahora, autor],
    ["sistema_version",        "2.0.0",                 "Versión actual del sistema",               ahora, autor],
    // ── Horarios ────────────────────────────────────────────────
    ["horario_lv_inicio",      "10:30",                 "Hora inicio L-V (formato HH:MM)",          ahora, autor],
    ["horario_lv_fin",         "20:30",                 "Hora fin L-V (formato HH:MM)",             ahora, autor],
    ["horario_sab_inicio",     "09:30",                 "Hora inicio Sábado (formato HH:MM)",       ahora, autor],
    ["horario_sab_fin",        "18:00",                 "Hora fin Sábado (formato HH:MM)",          ahora, autor],
    ["horario_tolerancia_min", "5",                     "Minutos de tolerancia para tardanza",      ahora, autor],
    ["horario_max_break_min",  "45",                    "Máximo de break acumulado por turno (min)",ahora, autor],
    // ── Sedes ───────────────────────────────────────────────────
    ["sedes_activas",          "SAN ISIDRO,PUEBLO LIBRE","Sedes separadas por coma",                ahora, autor],
    // ── Comisiones (referencia, los valores reales en TABLA DE COMISIONES) ──
    ["comisiones_serv_base",   "0.005",                 "% base comisión servicios (0.5%)",         ahora, autor],
    ["comisiones_prod_tipo",   "fijo",                  "Tipo comisión productos: fijo o pct",      ahora, autor]
  ];

  // Agregar solo las que no existen
  var nuevas = configs.filter(function(c) { return !clavesExistentes[c[0]]; });

  if (nuevas.length === 0) {
    return "⏭️  CONFIGURACION ya tiene todos los valores iniciales";
  }

  var filaInicio = ultimaFila < 1 ? 2 : ultimaFila + 1;
  sh.getRange(filaInicio, 1, nuevas.length, 5).setValues(nuevas);

  // Colorear filas alternas para legibilidad
  for (var r = 0; r < nuevas.length; r++) {
    if ((filaInicio + r) % 2 === 0) {
      sh.getRange(filaInicio + r, 1, 1, 5).setBackground("#f8f9fa");
    }
  }

  return "✅ CONFIGURACION: " + nuevas.length + " valores iniciales agregados";
}

// ══════════════════════════════════════════════════════════════
// FUNCIÓN DE VERIFICACIÓN (ejecutar después del setup)
// ══════════════════════════════════════════════════════════════

/**
 * test_VerificarSetup — Ejecutar después de runSheetSetup_v2
 * Verifica que todo quedó correctamente creado
 */
function test_VerificarSetup() {
  Logger.log("═══════════════════════════════════════════════");
  Logger.log("  AscendaOS v2.0 — Verificación de Setup");
  Logger.log("═══════════════════════════════════════════════");

  var ss = SpreadsheetApp.openById(CFG.SHEET_ID);

  // 1. Verificar LOG_TURNOS
  var shTurnos = ss.getSheetByName(CFG.SHEET_TURNOS);
  if (shTurnos) {
    var headersTurnos = shTurnos.getRange(1, 1, 1, shTurnos.getLastColumn()).getValues()[0];
    Logger.log("✅ LOG_TURNOS existe | Cols: " + headersTurnos.length);
    Logger.log("   Headers: " + headersTurnos.slice(0, 5).join(", ") + "...");
  } else {
    Logger.log("❌ LOG_TURNOS NO existe");
  }

  // 2. Verificar CONFIGURACION
  var shConfig = ss.getSheetByName(CFG.SHEET_CONFIG);
  if (shConfig) {
    var filas = shConfig.getLastRow() - 1;
    Logger.log("✅ CONFIGURACION existe | Filas de datos: " + filas);
  } else {
    Logger.log("❌ CONFIGURACION NO existe");
  }

  // 3. Verificar cols RRHH
  var shRRHH = ss.getSheetByName(CFG.SHEET_RRHH);
  if (shRRHH) {
    var colsRRHH = shRRHH.getLastColumn();
    var headersRRHH = shRRHH.getRange(1, 1, 1, colsRRHH).getValues()[0];
    var tienePermisos = headersRRHH.some(function(h) { return _up(_norm(h)) === "PERMISOS"; });
    var tieneFoto = headersRRHH.some(function(h) { return _up(_norm(h)) === "FOTO_URL"; });
    Logger.log("RRHH (" + colsRRHH + " cols):");
    Logger.log("  " + (tienePermisos ? "✅" : "❌") + " PERMISOS");
    Logger.log("  " + (tieneFoto    ? "✅" : "❌") + " FOTO_URL");
  }

  // 4. Verificar SUB_ESTADO en LLAMADAS
  var shLlam = ss.getSheetByName(CFG.SHEET_LLAMADAS);
  if (shLlam) {
    var colsLlam = shLlam.getLastColumn();
    var headersLlam = shLlam.getRange(1, 1, 1, colsLlam).getValues()[0];
    var tieneSub = headersLlam.some(function(h) { return _up(_norm(h)) === "SUB_ESTADO"; });
    Logger.log("LLAMADAS (" + colsLlam + " cols):");
    Logger.log("  " + (tieneSub ? "✅" : "❌") + " SUB_ESTADO (col U esperada)");
  }

  // 5. Verificar FOTO_URL en PACIENTES
  var shPac = ss.getSheetByName(CFG.SHEET_PACIENTES);
  if (shPac) {
    var colsPac = shPac.getLastColumn();
    var headersPac = shPac.getRange(1, 1, 1, colsPac).getValues()[0];
    var tieneFotoPac = headersPac.some(function(h) { return _up(_norm(h)) === "FOTO_URL"; });
    Logger.log("PACIENTES (" + colsPac + " cols):");
    Logger.log("  " + (tieneFotoPac ? "✅" : "❌") + " FOTO_URL (col U esperada)");
  }

  // 6. Verificar el FIX del nombre de INVERSION
  var shInv = ss.getSheetByName(CFG.SHEET_INVERSION);
  if (shInv) {
    Logger.log("✅ INVERSION encontrada con nombre: '" + CFG.SHEET_INVERSION + "'");
  } else {
    Logger.log("⚠️  INVERSION no encontrada con nombre: '" + CFG.SHEET_INVERSION + "'");
    Logger.log("   Buscar manualmente el nombre real de la hoja en el Sheet");
  }

  Logger.log("═══════════════════════════════════════════════");
  Logger.log("  Verificación completada");
  Logger.log("═══════════════════════════════════════════════");
}