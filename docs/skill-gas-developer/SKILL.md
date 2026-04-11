---
name: skill-gas-developer
description: Reglas y patrones específicos para desarrollar en Google Apps Script (GAS) dentro del ecosistema AscendaOS / CREACTIVE OS. Usar cuando se escriba, edite o audite cualquier archivo .gs del proyecto. Garantiza compatibilidad ES5, arquitectura modular correcta, y uso de los helpers compartidos del sistema.
---

# GAS Developer — AscendaOS

## RESTRICCIONES CRÍTICAS DE LENGUAJE (ES5)

GAS corre en V8 moderno PERO el proyecto usa patrones ES5 por compatibilidad y estabilidad probada. NUNCA usar:

```javascript
// ❌ PROHIBIDO
const arr = [...otroArr];           // spread operator
const obj = {...otroObj};           // object spread  
const fn = (a, b = 'default') => {}; // arrow + default params
import { algo } from './modulo';    // ES modules
eval('codigo');                     // eval
Array.from(nodeList);               // en contextos GAS legacy

// ✅ CORRECTO
var arr = otroArr.slice();
var obj = JSON.parse(JSON.stringify(otroObj));
function fn(a, b) { b = b || 'default'; }
// funciones globales accesibles entre archivos .gs automáticamente
```

## ARQUITECTURA DE ARCHIVOS

```
GS_00_Shell.gs          → doGet(), getViewHtml() — punto de entrada WebApp
GS_01_Config.gs         → TODAS las constantes: IDs sheets, columnas, config
GS_02_Auth.gs           → login, tokens, roles, permisos
GS_03_CoreHelpers.gs    → helpers compartidos (nunca duplicar aquí)
GS_04_DataAccess.gs     → da_* funciones — ÚNICA forma de leer Sheets
GS_05_Cache.gs          → CacheService wrappers
GS_06_AdvisorCalls.gs   → lógica call center asesor
GS_25_SupabaseSync.gs   → sincronización GAS → Supabase
GS_28_CodigoSync.gs     → subir/bajar código desde Supabase
```

**Nomenclatura obligatoria:** `GS_XX_NombreModulo.gs` para backend, `ViewAdminNombre.html` o `ViewAdvisorNombre.html` para frontend.

## REGLA #1 — SIEMPRE usar da_* para leer Sheets

```javascript
// ❌ NUNCA — índices hardcodeados, rompe con cualquier cambio de columna
var sheet = SpreadsheetApp.openById(ID).getSheetByName('LEADS');
var data = sheet.getDataRange().getValues();
var nombre = data[i][3]; // ¿qué columna es esta? nadie sabe

// ✅ SIEMPRE — a través de DataAccess con constantes
var leads = da_leadsData();  // retorna array de objetos con nombres
var nombre = leads[i][LEAD_COL.NOMBRE]; // legible y mantenible
```

**Funciones da_* disponibles en GS_04:**
- `da_leadsData()` — todos los leads
- `da_llamadasData()` — historial de llamadas
- `da_ventasData()` — ventas registradas
- `da_inversionData()` — inversión por campaña
- `da_agendaData()` — citas agendadas

## REGLA #2 — Constantes SIEMPRE desde GS_01_Config.gs

```javascript
// ❌ NUNCA hardcodear
var sheet = SpreadsheetApp.openById('1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM');
var col = data[i][5]; // columna 5 de qué?

// ✅ SIEMPRE referenciar constantes
var sheet = SpreadsheetApp.openById(SHEET_ID);
var telefono = row[LEAD_COL.TELEFONO];
var tratamiento = row[LLAM_COL.TRATAMIENTO];
```

**Grupos de constantes en GS_01:**
- `LEAD_COL.*` — columnas de hoja LEADS
- `LLAM_COL.*` — columnas de hoja LLAMADAS  
- `VENT_COL.*` — columnas de hoja VENTAS
- `AG_COL.*` — columnas de hoja AGENDA_CITAS
- `SHEET_ID` — ID del spreadsheet principal

## REGLA #3 — PropertiesService para secrets

```javascript
// ❌ NUNCA en código
var key = 'eyJhbGci...'; // expuesto en GitHub

// ✅ SIEMPRE
var key = PropertiesService.getScriptProperties().getProperty('SUPABASE_KEY');
```

## REGLA #4 — GAS solo para escrituras y lógica compleja

```javascript
// GAS maneja:
// ✅ Guardar llamada en Sheet + sync Supabase
// ✅ Login y generación de tokens
// ✅ Lógica de cálculo de comisiones
// ✅ Triggers de sincronización

// Supabase directo (browser) maneja:
// ✅ Leer KPIs del panel (~300ms vs 1-3s por GAS)
// ✅ Historial de llamadas
// ✅ Semáforo de equipo en tiempo real
// ✅ Comisiones del asesor
```

## REGLA #5 — Join universal: NUMERO_LIMPIO

```javascript
// El campo que conecta LEADS → LLAMADAS → AGENDA → VENTAS
// Siempre normalizar antes de comparar:
function limpiarNumero(num) {
  return String(num || '').replace(/\D/g, '').slice(-9);
}
var numLimpio = limpiarNumero(row[LEAD_COL.TELEFONO]);
```

## LÓGICA MADRE — Call Center (8 pasos, NO modificar sin auditoría)

```
Prioridad 1: Vírgenes mes actual (nunca contactados este mes)
Prioridad 2: No asistió cita últimas 2 semanas
Prioridad 3: Vírgenes históricos (nunca contactados nunca)
Prioridad 4: Sin contacto mes actual
Prioridad 5: Canceló/reprogramó cita
Prioridad 6: Base antigua sin convertir
Prioridad 7: Pacientes activos recompra 90 días
Prioridad 8: Sin contacto histórico

Anti-duplicado: CacheService key = COLA_HOY_[ASESOR]_[FECHA]
Config distribución: PropertiesService key = DIST_CONFIG_[ASESOR_NORM]
```

## SEMÁNTICA IMPORTANTE

```
Campaña = LEAD_COL.TRAT = LLAM_COL.TRATAMIENTO
  → tipo de campaña de marketing (HIFU, ENZIMAS FACIALES, etc.)
  → NO es el tratamiento clínico aplicado

VENT.TRATAMIENTO = servicio clínico realmente entregado
  → diferente semántica al campo de campaña
```

## ANCHORS CTRL+F — OBLIGATORIO en todo código

```javascript
// ===== MOD-XX-START: NOMBRE_MODULO =====
// ... código ...
// ===== MOD-XX-END: NOMBRE_MODULO =====
```

## NUNCA USAR

```javascript
GS_27_SyncBidireccional.gs  // BORRA DATOS DE PRODUCCIÓN — prohibido
// Sync automático con DELETE
// Índices de columna numéricos hardcodeados
// Credenciales en código fuente
```

## FLUJO DE DEPLOY

```
1. Yo edito en Supabase (aos_codigo_fuente)
2. Push automático a GitHub
3. César copia contenido del archivo desde Supabase
4. Pega en Apps Script editor
5. Despliega nueva versión del WebApp
→ El paso 5 SIEMPRE requiere mano humana (Google no permite API deploy)
```
