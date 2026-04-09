# MEMORY.md — AscendaOS v1
## Contexto activo para continuar en cualquier chat

---

## IDENTIDAD DEL PROYECTO

- **Sistema:** AscendaOS v1 — CRM para clínica estética Zi Vital (Lima, Perú)
- **Stack:** Google Apps Script + Google Sheets + WebApp HTML/CSS/JS
- **Sheet ID:** `1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM`
- **Repo GitHub:** `https://github.com/CESARJAUREGUITORRES/ascenda-os`
- **Operador:** César Jáuregui (director, no programador)
- **Fecha última sesión:** 2026-04-08

---

## ARQUITECTURA DEL SISTEMA

### Google Apps Script (backend)
```
GS_00_Shell.gs          ← sirve el HTML como WebApp
GS_01_Config.gs         ← constantes, IDs de hojas, columnas (CFG, LLAM_COL, LEAD_COL, etc.)
GS_02_Auth.gs           ← autenticación, sesiones, tokens
GS_03_CoreHelpers.gs    ← funciones utilitarias (_up, _norm, _date, _inRango, etc.)
GS_04_AccesoADatos.gs   ← acceso a hojas (_sh, _shAgenda, _shLlamadas, etc.)
GS_05_Cache.gs          ← caché de datos
GS_06_AdvisorCalls.gs   ← panel call center (MOD-01 a MOD-10)
GS_07_AdvisorMetrics.gs ← métricas y ranking del equipo
GS_08_Agenda.gs         ← gestión de citas
GS_09_Pacientes.gs      ← perfil de pacientes (api_getPatientProfileT)
GS_10_Ventas.gs         ← ventas
GS_11_Comisiones.gs     ← comisiones
GS_12_AdminDashboard.gs ← dashboard admin
GS_13_Marketing.gs      ← marketing/leads
GS_18_MigrationCompat.gs← compatibilidad y aliases de funciones
GS_LeadsCampana.gs      ← NUEVO: api_getLeadsCampanaMesT (pendiente instalar)
```

### HTML (frontend)
```
ViewAdvisorCalls.html   ← PRINCIPAL — panel call center del asesor (v2.6 activa)
ViewAdvisorHome.html    ← home del asesor
AppShell.html           ← shell principal que carga las vistas
Iniciar sesión.html     ← login
```

---

## ESTADO ACTUAL DEL PANEL CALL CENTER (ViewAdvisorCalls.html v2.6)

### Layout completo
```
[DISPONIBILIDAD DE ATENCIÓN — vista semanal siempre visible]
  - 7 columnas (Lu-Do) con doctoras/enfermería del día
  - Click en día → cartilla de texto con info del turno
  - Filtros: Todas/Doctora/Enf. + selector de sede
  - Navegación semana ‹ ›

[KPIs strip: Llamadas hoy | Citas hoy | Conv% | Sin contacto | Ranking]

[cc-layout 2 cols]
  [COL IZQ: Call Panel]
    - Badge nombre paciente (si existe en base)
    - Número grande + tratamiento + #intento + fecha
    - Anuncio/pregunta de entrada
    - Botones: Llamar ahora | WhatsApp
    - Tipificación + sub-tipificación SIN CONTACTO
    - Textarea observación
    - Guardar resultado
    - Llamada manual a cliente (modal)
    - Historial de hoy (tabla)

  [COL DER: Tabs — Score | Segs | Top]
    Score:
      - Filtro: selector mes + Mes/Semana/Hoy
      - 2 columnas: TOTAL GENERAL | LEADS CAMPAÑA
      - Tipificaciones (misma fila, card)
      - Tabla resumen anual (misma fila, card, oculta meses vacíos)
    Segs:
      - Contadores: Vencidos | Hoy | Próximos (clickeables como filtro)
      - Lista con: WA | Llamar | Cerrar | Reagendar
      - Click en número → ficha 360°
    Top:
      - 20 mejores clientes por facturación
      - Click → ficha 360°
```

### Funciones JS clave (v2.6)
| Función | Descripción |
|---------|-------------|
| `loadMetrics()` | KPIs superiores (hoy) |
| `loadLead()` | Carga próximo lead a llamar |
| `loadHistorial()` | Llamadas de hoy |
| `loadScorePanel()` | Score + tipif + tabla anual |
| `loadSegsPanel()` | Seguimientos pendientes |
| `loadTopPanel()` | Top 20 clientes |
| `recargarCalendario()` | Llama `api_getSemanaCalT` |
| `renderSemana(diasData)` | Renderiza 7 columnas |
| `mostrarCartilla(diaData)` | Cartilla texto doctora/enf |
| `loadTablaAnual()` | 12 meses del año |
| `abrirModalManual()` | Modal llamada manual |
| `buscarPacLive(q)` | Búsqueda live de pacientes |

### APIs del GAS que usa el frontend
| API | Módulo | Estado |
|-----|--------|--------|
| `api_getNextLeadT` | GS_06 MOD-01 | ✅ |
| `api_saveCallT` | GS_06 MOD-02 | ✅ |
| `api_getMyCallsTodayT` | GS_06 MOD-04 | ✅ |
| `api_getMySeguimientosT` | GS_06 MOD-03 | ✅ |
| `api_cerrarSeguimientoT` | GS_06 MOD-03 | ✅ |
| `api_getMyScoreMesT` | GS_06 MOD-07 | ✅ |
| `api_getMyCallsByMesT` | GS_06 MOD-07 | ✅ |
| `api_getMyTopClientesT` | GS_06 MOD-08 | ✅ |
| `api_searchPatientsLiveT` | GS_06 MOD-09 | ✅ |
| `api_getPatientProfileT` | GS_09 | ✅ |
| `api_getTeamRankingT` | GS_07 | ✅ |
| `api_getSemanaCalT` | **FALTA en GAS** | ⚠️ pendiente |
| `api_getLeadsCampanaMesT` | **FALTA en GAS** | ⚠️ pendiente |
| `api_getDoctorInfoT` | GS_06 MOD-10 | ✅ |

---

## PROBLEMAS PENDIENTES CRÍTICOS

### 1. `api_getSemanaCalT` no instalada en el GAS
**Síntoma:** El calendario semanal no muestra datos reales de doctoras/enfermería.  
**Causa:** La función existe en `GS_06_PARCHE_SEMANA_LEADS.gs` pero César no la ha pegado al final de `GS_06_AdvisorCalls.gs`.  
**Fix:** Pegar contenido de `GS_06_PARCHE_SEMANA_LEADS.gs` al FINAL de `GS_06_AdvisorCalls.gs`.

### 2. `api_getLeadsCampanaMesT` no instalada en el GAS
**Síntoma:** Columna "Leads Campaña" en Score muestra guiones.  
**Causa:** Misma — está en el parche pendiente.  
**Fix:** Mismo archivo `GS_06_PARCHE_SEMANA_LEADS.gs`.

### 3. ViewAdvisorCalls.html v2.6 no instalada correctamente
**Síntoma:** Errores en F12: `:28:55 textContent`, `:96:45 style`, `:124:21 innerHTML`.  
**Causa:** El GAS sigue ejecutando el archivo original (v24_base). Los números de línea de los errores coinciden exactamente con v24_base.  
**Fix:** En GAS editor → ViewAdvisorCalls.html → Ctrl+A → Delete → Pegar contenido nuevo → Ctrl+S → Redesplegar.  
**Verificación:** En F12 Console debe aparecer: `AscendaOS ViewAdvisorCalls v2.6 CARGADO ✓`

---

## ESTRUCTURA DE DATOS (columnas reales verificadas)

### CONSOLIDADO DE LLAMADAS
```
Col A (0) = FECHA
Col B (1) = NUMERO
Col D (3) = ESTADO
Col G (6) = ASESOR
Col I (8) = NUMERO_LIMPIO  ← key para cruces
Col J (9) = ID_ASESOR (ZIV-002, etc.)
```

### CONSOLIDADO DE LEADS
```
Col A (0) = FECHA
Col B (1) = CELULAR
Col C (2) = TRATAMIENTO
Col D (3) = ANUNCIO
Col E (4) = PREGUNTAS
Col F (5) = HORA INGRESO DE LEAD  ← key para filtrar por mes
Col G (6) = NUMERO_LIMPIO          ← key para cruces
```

---

## CALENDARIOS GOOGLE CALENDAR

### Doctoras
- **ID:** `3784316650e1124f3eb82be4f123001347a18fb1808e4292e0d0503925d4f967@group.calendar.google.com`
- **Formato SUMMARY:** `(PROCED)DRA YESSICA PEREZ 5PM - 7.30PM`
- **Sede en LOCATION:** `Av. Javier Prado Este 996` = SAN ISIDRO / `Av. Brasil 1170` = PUEBLO LIBRE
- **Característica:** Eventos en fechas específicas, NO recurrentes

### Enfermería
- **ID:** `2db1abef4cf3589e8646a162324c5818ef5732918ae8a113c1792e759a43e0c2@group.calendar.google.com`
- **Formato SUMMARY:** `🟢 MIREYA - Turno Enfermería | SAN ISIDRO`
- **Enfermeros:** MIREYA, WILMER, RUVILA
- **Característica:** Eventos de todo el día, múltiples por día, sede en SUMMARY y LOCATION

---

## SEDES
- **San Isidro:** Av. Javier Prado Este 996
- **Pueblo Libre:** Av. Brasil 1170

---

## ARCHIVOS ENTREGADOS (estado al 2026-04-08)

| Archivo | Descripción | Estado |
|---------|-------------|--------|
| `ViewAdvisorCalls.html` | Panel call center v2.6 | ✅ listo para instalar |
| `GS_06_PARCHE_SEMANA_LEADS.gs` | `api_getSemanaCalT` + `api_getLeadsCampanaMesT` | ⚠️ pendiente instalar |

---

## PRÓXIMOS PASOS (por orden de prioridad)

1. **Instalar correctamente** `ViewAdvisorCalls.html` v2.6 en el GAS
2. **Agregar el parche** `GS_06_PARCHE_SEMANA_LEADS.gs` al final de `GS_06_AdvisorCalls.gs`
3. **Verificar** que el calendar se muestra y los leads de campaña cargan
4. **Fix top clientes** → ficha 360° muestra datos vacíos (mapeo `res.historial.*` vs `res.*`)
5. **Fase 10:** ViewAdvisorAgenda (pendiente)

---

## CÓMO USAR ESTE ARCHIVO EN UN NUEVO CHAT

Pega al inicio del chat:
```
Continúa el trabajo en AscendaOS v1. Lee el contexto completo en:
https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/MEMORY.md

Y el archivo principal en:
https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/src/frontend/ViewAdvisorCalls.html
```

---

## INSTRUCCIÓN PARA INSTALACIÓN EN GAS

### Pasos exactos para actualizar ViewAdvisorCalls.html
1. Ir a script.google.com → proyecto AscendaOS
2. Panel izquierdo → click en `ViewAdvisorCalls.html`
3. Editor → `Ctrl+A` (seleccionar todo) → `Delete` (borrar)
4. Abrir el archivo nuevo → `Ctrl+A` → `Ctrl+C`
5. Volver al GAS editor → `Ctrl+V`
6. `Ctrl+S` para guardar
7. Deploy → Manage deployments → lápiz (editar) → Version: "New version" → Deploy
8. **Verificar:** F12 Console → debe mostrar mensaje azul "AscendaOS ViewAdvisorCalls v2.6 CARGADO ✓"

### Pasos para agregar el parche del GAS
1. Panel izquierdo → click en `GS_06_AdvisorCalls.gs`
2. Ir al FINAL del archivo (Ctrl+End)
3. Abrir `GS_06_PARCHE_SEMANA_LEADS.gs` → Ctrl+A → Ctrl+C
4. Volver al GAS → Ctrl+End → Enter → Ctrl+V
5. Ctrl+S → Redesplegar
