# MEMORY.md — AscendaOS v1
## Contexto activo — Última actualización: 2026-04-08
## Para continuar: pega este archivo al inicio del nuevo chat

---

## PROYECTO

- **Sistema:** AscendaOS v1 — CRM clínica estética Zi Vital (Lima, Perú)
- **Stack:** Google Apps Script + Google Sheets + WebApp HTML/CSS/JS
- **Sheet ID:** `1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM`
- **Repo GitHub:** `https://github.com/CESARJAUREGUITORRES/ascenda-os`
- **Operador:** César Jáuregui

---

## ARCHIVOS DEL PROYECTO (en GAS)

```
GS_00_Shell.gs          ← sirve el HTML como WebApp
GS_01_Config.gs         ← constantes CFG, LLAM_COL, LEAD_COL, VENT_COL, AG_COL
GS_02_Auth.gs           ← sesiones y tokens
GS_03_CoreHelpers.gs    ← _up, _norm, _normNum, _date, _inRango, etc.
GS_04_DataAccess.gs     ← _sh, _shAgenda, _shLlamadas, etc.
GS_05_Cache.gs          ← caché
GS_06_AdvisorCalls.gs   ← PRINCIPAL: MOD-01 a MOD-10 + api_getLeadsCampanaMesT
GS_07_AdvisorMetrics.gs ← ranking equipo
GS_08_Agenda.gs         ← citas
GS_09_Patients.gs       ← api_getPatientProfileT
GS_10_Sales.gs          ← ventas
GS_18_MigrationCompat.gs← aliases de compatibilidad
```

---

## COLUMNAS REALES DEL GOOGLE SHEET (verificadas en GS_01_Config.gs)

```javascript
// CONSOLIDADO DE LLAMADAS
LLAM_COL = {
  FECHA: 0,        // A
  NUMERO: 1,       // B
  TRATAMIENTO: 2,  // C
  ESTADO: 3,       // D  ← SIN CONTACTO, CITA CONFIRMADA, etc.
  OBS: 4,          // E
  HORA: 5,         // F
  ASESOR: 6,       // G  ← nombre del asesor
  NUM_LIMPIO: 8,   // I  ← KEY para cruces
  ID_ASESOR: 9,    // J  ← ZIV-002, etc.
  SUB_ESTADO: 20   // U  ← NO CONTESTA / SIN SERVICIO / NUMERO NO EXISTE
}

// CONSOLIDADO DE LEADS
LEAD_COL = {
  FECHA: 0,        // A
  CELULAR: 1,      // B
  TRAT: 2,         // C
  ANUNCIO: 3,      // D
  PREGUNTAS: 4,    // E
  HORA: 5,         // F  ← HORA INGRESO DE LEAD (filtrar por mes)
  NUM_LIMPIO: 7    // H  ← KEY para cruces
}

// CONSOLIDADO DE VENTAS
VENT_COL = {
  FECHA: 0,        // A
  NOMBRES: 1,      // B
  APELLIDOS: 2,    // C
  CELULAR: 4,      // E
  MONTO: 8,        // I  ← importe
  ASESOR: 10,      // K
  NUM_LIMPIO: 15   // P  ← KEY para cruces
}
```

---

## NOMBRES DE HOJAS (CFG en GS_01_Config.gs)

```javascript
CFG.SHEET_LLAMADAS     = "CONSOLIDADO DE LLAMADAS"
CFG.SHEET_LEADS        = "CONSOLIDADO DE LEADS"
CFG.SHEET_VENTAS       = "CONSOLIDADO DE VENTAS"
CFG.SHEET_AGENDA       = "AGENDA_CITAS"
CFG.SHEET_SEGUIMIENTOS = "SEGUIMIENTOS"
CFG.SHEET_PACIENTES    = "CONSOLIDADO_DE_PACIENTES"
```

---

## CALENDARIOS GOOGLE CALENDAR

```
DOCTORAS:
  ID: 3784316650e1124f3eb82be4f123001347a18fb1808e4292e0d0503925d4f967@group.calendar.google.com
  Formato SUMMARY: "(PROCED)DRA YESSICA PEREZ 5PM - 7.30PM"
  Sede en LOCATION: "Av. Javier Prado Este 996" → SAN ISIDRO
                    "Av. Brasil 1170"            → PUEBLO LIBRE
  Nota: eventos en fechas específicas, NO recurrentes

ENFERMERÍA:
  ID: 2db1abef4cf3589e8646a162324c5818ef5732918ae8a113c1792e759a43e0c2@group.calendar.google.com
  Formato SUMMARY: "🟢 MIREYA - Turno Enfermería | SAN ISIDRO"
  Personal: MIREYA, WILMER, RUVILA
  Nota: eventos de todo el día, múltiples por día
```

---

## ESTADO ACTUAL DEL PANEL CALL CENTER (ViewAdvisorCalls.html v2.6)

### Verificación de versión
Cuando está instalado correctamente, el F12 Console muestra:
`AscendaOS ViewAdvisorCalls v2.6` en azul

### Layout
```
[DISPONIBILIDAD DE ATENCIÓN — vista semanal siempre visible]
  7 columnas Lu-Do con doctoras/enfermería reales del GCal
  Click en día → cartilla de texto con nombre, tipo, horario, sede

[KPIs: Llamadas hoy | Citas hoy | Conv% | Sin contacto | Ranking]

[2 columnas]
  [COL IZQ: Call Panel]
    Badge nombre paciente + número grande + tratamiento
    Anuncio/pregunta de entrada
    Llamar | WhatsApp | Tipificación | Observación | Guardar
    Llamada manual a cliente (modal con búsqueda live)
    Historial de hoy

  [COL DER: Tabs Score | Segs | Top]
    Score:
      Filtro: mes + Mes/Semana/Hoy
      2 cards: TOTAL GENERAL | LEADS CAMPAÑA
      Tipificaciones + Tabla resumen anual
    Segs: filtros Vencidos/Hoy/Próximos clickeables
    Top: 20 mejores clientes por facturación
```

---

## BUGS ENCONTRADOS Y RESUELTOS HOY (2026-04-08)

### Bug raíz de los errores del F12 (:28:55, :96:45, :124:21)
**Causa:** El GAS tenía instalado el `ViewAdvisorCalls.html` original (v24_base), no el v2.6.
**Síntoma:** Errores `textContent/innerHTML/style` en null porque el archivo viejo referenciaba IDs eliminados.
**Fix:** Instalar el `ViewAdvisorCalls.html` v2.6 correcto.

### Bug en api_getLeadsCampanaMesT
**Causa:** El parche usaba `r[6]` para NUM_LIMPIO de LEADS pero `LEAD_COL.NUM_LIMPIO = 7`.
También `r[7]` para MONTO de ventas pero `VENT_COL.MONTO = 8`.
**Fix:** Reescrita con las constantes reales del GS_01_Config.

### Bug api_getSemanaCalT duplicada
**Causa:** Existía en GS_06 L825 Y en el parche L1135 → GAS ejecutaba la última.
**Fix:** Eliminado el parche duplicado. La versión en L825 es la correcta.

---

## PENDIENTES PARA EL PRÓXIMO CHAT

### PRIORIDAD 1 — Instalar los 2 archivos finales
1. `ViewAdvisorCalls.html` → reemplazar en GAS (Ctrl+A, Delete, pegar, Ctrl+S)
2. `GS_06_AdvisorCalls.gs` → reemplazar en GAS (mismos pasos)
3. Redesplegar
4. Verificar: F12 Console muestra "AscendaOS ViewAdvisorCalls v2.6 ✓"

### PRIORIDAD 2 — Eliminar GS_LeadsCampana.gs del proyecto GAS
Ese archivo tiene constantes inventadas (HOJA_LEADS, LEADS_COL) que no existen.
Abrir GAS → click derecho en GS_LeadsCampana.gs → Delete.

### PRIORIDAD 3 — Verificar funcionalidad
Después de instalar:
- [ ] F12: no debe haber errores Bs
- [ ] Calendario: muestra turnos reales del GCal (solo días con eventos)
- [ ] Leads Campaña: muestra números en las 4 cards
- [ ] Score Total: muestra llamadas, citas, ventas del mes

### PRIORIDAD 4 — Top Clientes → Ficha 360°
El click en Top abre la ficha pero no muestra datos.
Causa probable: la ficha espera `res.compras` pero la API retorna `res.historial.ventas`.
Requiere revisar `api_getPatientProfileT` en GS_09_Patients.gs.

---

## INSTRUCCIÓN PARA EL PRÓXIMO CHAT

```
Soy César, continúo el desarrollo de AscendaOS v1.

Contexto completo del proyecto en:
https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/docs/MEMORY.md

Archivos clave:
- GS_06: https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/src/backend/GS_06_AdvisorCalls.gs
- HTML: https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/src/frontend/ViewAdvisorCalls.html

[Describe qué quieres hacer]
```

---

## NOTAS TÉCNICAS IMPORTANTES

- El repo GitHub es PÚBLICO → Claude puede leer los raw URLs directamente
- Actualizar el repo después de cada sesión con `git commit` y `git push`
- Al pegar archivos en GAS: Ctrl+A → Delete → Ctrl+V → Ctrl+S → Redesplegar
- El redespliegue requiere: Deploy → Manage deployments → lápiz → New version → Deploy
