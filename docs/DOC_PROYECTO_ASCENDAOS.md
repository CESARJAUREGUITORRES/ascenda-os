# DOC_PROYECTO_ASCENDAOS.md
## Documento de respaldo completo · AscendaOS v1 · CreActive OS
### Carpeta: /docs · Última actualización: Abril 2026

---

## ¿QUÉ ES ESTE DOCUMENTO?

Este archivo es el respaldo completo del proyecto AscendaOS. Contiene toda la arquitectura, decisiones de diseño, roadmap, patrones de código y visión de largo plazo. Está pensado para que cualquier sesión nueva con Claude pueda retomar el trabajo exactamente donde lo dejó, sin perder contexto.

**Usar así:** pegar el bloque de contexto activo (sección 1) al inicio de cualquier sesión nueva.

---

## SECCIÓN 1 · CONTEXTO ACTIVO

```
Proyecto: AscendaOS v1 — CRM Clínica Zi Vital
Stack: Google Apps Script + Google Sheets + WebApp HTML/CSS/JS
Sheet ID: 1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM
Deploy URL: script.google.com/macros/s/AKfycbyVoliSxxF3gJTX71Yi3tTd7L1sAUSyFj3HPmBYVaFCGKy69uWLzJV6nDcYjVBn-L5/exec
Repo: github.com/CESARJAUREGUITORRES/ascenda-os

Estado actual: Bloque 2 completado. Siguiente: Bloque 2.5 (ficha contextual asesor).
Necesito GS_06_AdvisorCalls.gs y ViewCallCenter.html para continuar.
```

---

## SECCIÓN 2 · ESTRUCTURA DEL PROYECTO

### Stack técnico
- **Backend:** Google Apps Script (.gs) — funciones `api_*` expuestas vía `doGet`
- **Frontend:** HTML/CSS/JS en archivos `View*.html` — llamadas con `google.script.run`
- **Datos:** Google Sheets como base de datos
- **Auth:** sistema propio con tokens en PropertiesService
- **Config persistente:** PropertiesService
- **Anti-duplicado:** CacheService (TTL diario)

### Nomenclatura de archivos
```
GS_01_Core.gs              → helpers globales, auth, columnas
GS_02_*.gs                 → módulos operativos del sistema
GS_06_AdvisorCalls.gs      → lógica del call center del asesor
GS_21_AdminComisiones.gs   → panel de comisiones
GS_22_AdminCalls.gs        → panel maestro de llamadas admin
GS_23_EtiquetasBase.gs     → (pendiente) genera BASE_ETIQUETAS
GS_24_Pacientes360.gs      → (pendiente) backend pacientes 360

ViewCallCenter.html         → panel del asesor
ViewAdminComisiones.html    → panel comisiones admin
ViewAdminCalls.html         → panel llamadas admin
ViewAdminPatients.html      → (pendiente) pacientes 360
```

### Convenciones de código obligatorias
```javascript
// Anclas de búsqueda CTRL+F — en cada función pública
// ===== CTRL+F: nombre_funcion =====

// Bloque start/end — en cada módulo
// AC01_START ... AC01_END

// Helpers globales — NO duplicar, importar de GS_01
_sh(nombre)          → obtener hoja por nombre
_normNum(num)        → normalizar número de teléfono
_up(str)             → uppercase + trim
_norm(str)           → normalizar nombre para comparar
_inRango(fecha,d,h)  → verificar si fecha está en rango
_shAgenda()          → helper específico para hoja AGENDA_CITAS
```

---

## SECCIÓN 3 · EQUIPO Y DATOS OPERATIVOS

### Equipo activo
| Nombre | Rol | Sede |
|--------|-----|------|
| WILMER | Asesor | San Isidro |
| RUVILA | Asesor | Pueblo Libre |
| MIREYA | Asesor | Ambas |
| SRA CARMEN | Asesor | San Isidro |
| CESAR | Admin | Ambas |

### Semántica crítica
```
CAMPAÑA           = LEAD_COL.TRAT = LLAM_COL.TRATAMIENTO
                    (HIFU, ENZIMAS FACIALES, CAPILAR, HIDROFACIAL, etc.)
VENT.TRATAMIENTO  = servicio clínico vendido en la venta
                    (diferente semántica — no mezclar)
ANUNCIO           = texto del anuncio específico dentro de la campaña
```

### Índices de columnas (base 0)
```javascript
LLAM_COL = {
  FECHA: 0, NUMERO: 1, TRATAMIENTO: 2, ESTADO: 3, OBS: 4,
  HORA: 5, ASESOR: 6, NUM_LIMPIO: 8, ID_ASESOR: 9,
  ANUNCIO: 10, INTENTO: 12, ULT_TS: 13, SUB_ESTADO: 20
}
LEAD_COL = {
  FECHA: 0, CELULAR: 1, TRAT: 2, ANUNCIO: 3, HORA: 5, NUM_LIMPIO: 7
}
VENT_COL = {
  FECHA: 0, NOMBRES: 1, TRATAMIENTO: 5, MONTO: 8, ESTADO_PAGO: 9,
  ASESOR: 10, SEDE: 12, NUM_LIMPIO: 15, VENTA_ID: 16
}
AG_COL = {
  ID: 0, FECHA: 1, TRATAMIENTO: 2, NUMERO: 5, ASESOR: 10,
  ID_ASESOR: 11, ESTADO: 12, VENTA_ID: 13, TS_CREADO: 15,
  HORA_CITA: 17, DOCTORA: 19
}
```

---

## SECCIÓN 4 · ROADMAP COMPLETO

```
✅ BLOQUE 0   Bugs críticos
✅ BLOQUE 1   Comisiones Admin
              GS_21_AdminComisiones.gs + ViewAdminComisiones.html
✅ BLOQUE 2   Llamadas Admin
              GS_22_AdminCalls.gs v3.3 (1475 líneas, 10 módulos)
              ViewAdminCalls.html v3.3 (777 líneas)

⏳ BLOQUE 2.5 Ficha contextual en panel del asesor
              GS_06 patch + ViewCallCenter patch
              REQUIERE: GS_06 actual + ViewCallCenter.html actual

⏳ BLOQUE 3   Pacientes 360°
              GS_23_EtiquetasBase.gs (nueva)
              GS_24_Pacientes360.gs (nueva)
              ViewAdminPatients.html (nueva)

⏳ BLOQUE 4   Configuración del sistema
              Datos empresa, logo, colores, email de envío

⏳ BLOQUE 5   Equipo + fotos + permisos
              Perfiles, CMP doctores, rango enfermeros, skills por usuario

⏳ BLOQUE 6   Agenda + Mis Citas
              Vista semanal, crear cita manual, actualizar estado

⏳ BLOQUE 7   Call Center — cerrar pendientes

⏳ BLOQUE 8   Notificaciones de ventas

⏳ BLOQUE 9   Catálogo de Servicios KB

⏳ BLOQUE 10  Catálogo de Productos

⏳ BLOQUE 11  Almacén central

⏳ BLOQUE 12  Sistema de Caja
```

---

## SECCIÓN 5 · BLOQUE 2 — DETALLE COMPLETO

### KPIs v2 — nueva batería aprobada
| # | Nombre | Fuente | Filtra período | Filtra asesor |
|---|--------|--------|---------------|---------------|
| 1 | Llamadas totales | LLAMADAS | ✅ | ✅ |
| 2 | Vírgenes históricos | LEADS vs LLAMADAS | ❌ siempre global | ❌ |
| 3 | Leads contactados / total | fracción "81/120" | ✅ | ✅ |
| 4 | Citas agendadas | AGENDA.TS_CREADO | ✅ | ✅ |
| 5 | Asistidos | AGENDA.ESTADO | ✅ | ✅ |
| 6 | Facturación call center | VENTAS donde ASESOR≠vacío en S/ | ✅ | ✅ |

### Lógica madre — 8 pasos de prioridad
```
1. Vírgenes del mes actual           → máxima prioridad
2. No asistió a cita (últimas 2sem)  → seguimiento urgente
3. Vírgenes históricos               → mismo nivel que paso 1
4. Sin contacto mes actual           → reintentar en horario pico
5. Canceló / reprogramó cita         → intención activa presente
6. Base antigua sin convertir        → de más reciente a más antiguo
7. Pacientes activos recompra 90d    → oferta complementaria
8. Sin contacto histórico            → último recurso
```

Anti-duplicado: `CacheService` clave `COLA_HOY_[ASESOR]_[FECHA]`
Distribuciones: `PropertiesService` clave `DIST_CONFIG_[ASESOR_NORM]`

### Fixes técnicos aplicados en Bloque 2
- **Diciembre fantasma:** filtro triple — `getFullYear() < 2026` + `mk.indexOf(anioStr) === 0` + ventas solo a meses que ya existen con llamadas
- **Embudo citas:** usa `AG_COL.TS_CREADO` (cuando se agendó) no `AG_COL.FECHA` (fecha futura de la cita)
- **Distribuciones timeout:** eliminada llamada a `api_getColaAdminT` por asesor, reemplazada por conteo ligero O(leads)
- **Null safety:** todo el JS usa helpers `setEl()` / `showEl()` que verifican existencia del elemento

---

## SECCIÓN 6 · BLOQUE 2.5 — FICHA CONTEXTUAL ASESOR

### Qué hace
Enriquecer `api_getNextLeadT` en GS_06 para que el número que llega al asesor traiga su historia completa. El asesor no llama "a ciegas".

### Impacto por archivo
| Archivo | Cambio | Riesgo |
|---------|--------|--------|
| GS_06 | Patch ~50 líneas al final de `api_getNextLeadT` | Ninguno — no toca lógica de tiers |
| ViewCallCenter.html | Bloque condicional si existe `lead.contexto` | Ninguno — condicional |
| GS_22 | Sin cambios — `_ac_buildFicha` ya implementada en MOD-08 | — |

### Datos por tipo de cliente
```
VIRGEN:         origen, campaña, días desde ingreso
CON HISTORIAL:  intentos, último asesor, observación, última cita + estado
PACIENTE ACTIVO: última compra, total facturado, sugerencia de recompra
```

### Mockup del bloque contextual en la tarjeta
```
┌─ Contexto del cliente (azul claro) ─────────┐
│ Último contacto: hace 8d · RUVILA            │
│ Última cita:     05 abr · HIFU · NO ASISTIÓ  │
│ Última compra:   Enzimas S/200 · 12 feb      │
│ Acción:  preguntar por la cita del 05 abr    │
└──────────────────────────────────────────────┘
```

---

## SECCIÓN 7 · BLOQUE 3 — PACIENTES 360°

### 8 Zonas del panel
| # | Zona | Descripción |
|---|------|-------------|
| 1 | Ficha identidad | Datos personales editables — cambio refleja en todo el sistema |
| 2 | Historia clínica | Formulario completo N.T. MINSA para medicina estética |
| 3 | Compras por día | Cards agrupadas + PDF comprobante con branding |
| 4 | Citas | Historial + crear nueva + actualiza AGENDA_CITAS |
| 5 | Historial llamadas | Todas las llamadas, tipificaciones, observaciones |
| 6 | Notas equipo | Multi-rol con tipo de nota por perfil |
| 7 | Documentos y fotos | Consentimientos, antes/después, contratos — subida a Drive |
| 8 | Seguimiento programado | Recontactos calculados por tratamiento/producto |

### Features adicionales
- Score del paciente: activo / en riesgo / inactivo (días desde última visita)
- Timeline unificado: llamadas + citas + compras + notas en orden cronológico
- Alertas de contraindicaciones: banner rojo visible si alergias o embarazo
- Buscador con autocompletado por nombre, apellido, DNI, teléfono
- Detección de duplicados + opción de fusionar (solo admin)

### Historia clínica — campos MINSA + medicina estética Perú

**Identificación personal:**
- DNI o carné de extranjería
- Nombres y apellidos completos
- Fecha de nacimiento / edad
- Sexo / estado civil / grado de instrucción
- Ocupación / distrito / dirección completa
- Teléfono / correo electrónico
- Contacto de emergencia (nombre + teléfono)

**Antecedentes médicos:**
- Alergias a medicamentos (campo libre)
- Alergias a materiales: látex, metales, otros
- Enfermedades crónicas: diabetes, HTA, coagulopatía, tiroides, otras
- Medicamentos actuales (nombre + dosis)
- Suplementos y vitaminas actuales
- Vacunas recientes relevantes
- Cirugías anteriores (fecha + tipo)
- Tratamientos estéticos previos
- Formación de queloides (sí/no)
- Implantes: silicona, metal, otros
- Marcapasos o dispositivos médicos (sí/no)

**Específico para mujeres:**
- Embarazo actual o posible (sí/no/posible)
- Lactancia (sí/no)
- Anticonceptivos hormonales (sí/no + tipo)
- Fecha de última menstruación
- Fecha de último papanicolau

**Hábitos:**
- Tabaco (no fuma / ocasional / habitual)
- Alcohol (no / ocasional / frecuente)
- Actividad física (sedentario / moderado / activo)
- Horas de sueño aproximadas

**Consentimiento:** foto o firma digital por procedimiento (obligatorio antes de atención)

### Seguimiento programado por tratamiento
| Tratamiento / Producto | Ciclo de recontacto | Lógica |
|------------------------|---------------------|--------|
| Toxina botulínica | 4–6 meses | Fecha aplicación + 120/180 días |
| Ácido hialurónico | 12–18 meses | Fecha aplicación + 365/540 días |
| HIFU | 12 meses | Fecha aplicación + 365 días |
| Pastillas / productos | Variable | (unidades ÷ dosis_diaria) + margen |

El sistema genera aviso en el call center X días antes del vencimiento para recontactar. Etiquetas automáticas sugieren tratamiento complementario. Base para chatbot AI futuro.

### PDFs — 4 tipos
| Tipo | Datos especiales |
|------|-----------------|
| Comprobante de compra | QR + código interno + puede agrupar varios pagos del día |
| Cotización | Editable antes de emitir |
| Receta médica | CMP del doctor + especialidad |
| Receta de enfermería | Rango: técnico / licenciado |

**Reglas de branding:**
- Logo cargado en Configuración → esquina superior izquierda
- Color primario de marca → encabezado del documento
- Color secundario → acentos y separadores
- Default si no hay config: azul corporativo `#1A4FD6`
- Todos enviables por email desde el panel

**Gestión de comprobantes:**
- Sin vínculo SUNAT aún → número de comprobante se ingresa manualmente
- Estado configurable: pendiente / emitido / anulado
- Alarma en panel del cliente si hay comprobantes sin etiquetar
- Panel de Facturación también muestra estado de comprobantes

### Roles y permisos
| Rol | Puede |
|-----|-------|
| Admin | Todo + eliminar registros + fusionar historias |
| Asesor | Leer todo + notas de ventas + crear citas |
| Recepción | Crear citas + notas de recepción + ver datos básicos |
| Doctor | Historia clínica completa + notas médicas + recetas + descuentos + insumos |
| Enfermero | Notas enfermería + receta enfermería + plan de trabajo + insumos |

Permisos granulares configurables por usuario desde panel Configuración.

### Hojas nuevas a crear en el Sheet
```
BASE_ETIQUETAS
  → NUM_LIMPIO | ETIQUETA_BASE | CAMPAÑA | MES_INGRESO
  → ULT_LLAMADA | ULT_CITA | ULT_COMPRA | TOTAL_FACT
  → ASESOR_ASIGNADO | TS_ACTUALIZADO

NOTAS_PACIENTES
  → ID | FECHA | NUM_PACIENTE | TEXTO | ROL | USUARIO | TIPO_NOTA

DOCUMENTOS_PACIENTES
  → ID | FECHA | TIPO | URL_DRIVE | USUARIO | NUM_PACIENTE

SEGUIMIENTOS_PROGRAMADOS
  → ID | NUM | TRATAMIENTO | FECHA_ULT_APLICACION
  → DIAS_CICLO | FECHA_RECONTACTO | ESTADO | ASESOR

HISTORIA_CLINICA
  → DNI (clave primaria) + todos los campos MINSA descritos arriba
```

### Columnas nuevas en hojas existentes
```
CONSOLIDADO_DE_PACIENTES:
  + ETIQUETA_BASE
  + SCORE_ESTADO (activo/riesgo/inactivo)
  + DIAS_ULTIMA_VISITA
  + TOTAL_FACTURADO_HISTORICO
  + TIENE_HISTORIA_CLINICA (booleano)

CONSOLIDADO DE VENTAS:
  + AGRUPADOR_DIA (fecha+num para agrupar compras del mismo día)
  + COMPROBANTE_ID
  + TIPO_COMPROBANTE

AGENDA_CITAS:
  + ORIGEN_CITA (llamada/manual/360/web)
```

---

## SECCIÓN 8 · VISIÓN DE LARGO PLAZO — CREACTIVE OS

### Objetivo estratégico
Cada proyecto construido con esta metodología alimenta un sistema de conocimiento que permite replicar el trabajo en otros sectores de forma cada vez más rápida y precisa.

### Agentes especializados a crear al terminar el CRM
| Agente | Tipo | Función |
|--------|------|---------|
| T-Arquitecto | Técnico | Define estructura modular de cualquier sistema nuevo |
| T-Developer | Técnico | Patrones GAS + HTML, nomenclatura, helpers, anti-patrones |
| C-Producto | Comercial | Adapta paneles base a un sector específico |
| C-Blueprint | Comercial | Analiza necesidades nuevas y mapea qué construir |

### Verticales identificadas
| Producto | Sector | Estado | Notas |
|----------|--------|--------|-------|
| AscendaClinic | Clínicas estéticas | 🔨 En construcción | Base actual del proyecto |
| AscendaLegal | Abogados + comercial | 📋 Definido | Expedientes en lugar de HC |
| AscendaPsych | Psicólogos + citas | 📋 Definido | Notas de sesión en lugar de HC |
| AscendaFinance | Finanzas personales/empresa | ⚠️ Refactorizar | HTML monolítico → módulos |

### Patrón de expansión estandarizado
```
1. Blueprint sectorial → qué necesita ese tipo de negocio
2. Mapear paneles del core → cuáles de los 12 aplican sin cambios
3. Identificar adaptaciones → qué cambia de lógica o nomenclatura
4. Crear módulos específicos → lo que es nuevo en ese sector
5. Entregar producto vertical completo
```

### Los 12 paneles reutilizables del core
```
01. Monitoreo equipo en tiempo real
02. KPIs con filtro período + asesor
03. Embudo de conversión
04. Histórico anual
05. Gestión de bases con tabs
06. Distribución de colas (lógica madre)
07. Pacientes / Clientes 360
08. Comisiones por asesor
09. Agenda + calendario
10. Call center con ficha contextual
11. Facturación + PDFs con branding
12. Configuración de empresa
```

---

## SECCIÓN 9 · METODOLOGÍA DE TRABAJO

```
REGLA 1   Auditar antes de intervenir
          → Leer el código existente completo antes de escribir una línea

REGLA 2   Arquitectura antes que código
          → Definir estructura, hojas, flujo de datos → luego implementar

REGLA 3   Documento completo, no parches
          → Entregar siempre el archivo completo actualizado

REGLA 4   Nomenclatura estricta
          → Backend: GS_XX_NombreModulo.gs
          → Frontend: ViewNombrePanel.html

REGLA 5   Anclas CTRL+F en todo código
          → // ===== CTRL+F: nombre_funcion =====
          → Permite encontrar cualquier función en segundos

REGLA 6   Checklist de prueba en cada entrega
          → Qué probar, qué resultado esperado, cómo verificar

REGLA 7   SESSION_LOG al cerrar cada sesión
          → Qué se hizo, qué queda pendiente, qué datos se necesitan

REGLA 8   Helpers compartidos no se duplican
          → Reutilizar siempre de GS_01/GS_03/GS_04

REGLA 9   PropertiesService para configs persistentes
          → Nunca hardcodear valores que puedan cambiar

REGLA 10  CacheService para anti-duplicado diario
          → TTL máximo 6 horas para datos de cola

REGLA 11  Mobile-first en HTML
          → Diseñar para pantalla de teléfono primero

REGLA 12  Respuesta ejecutable
          → Dar instrucciones exactas, no teoría. Código listo para pegar.
```

---

## SECCIÓN 10 · PRÓXIMOS PASOS INMEDIATOS

```
[ ] 1. Recibir ViewCallCenter.html + GS_06_AdvisorCalls.gs del repo
[ ] 2. Implementar Bloque 2.5 — ficha contextual en panel del asesor
[ ] 3. Verificar que el parche no rompe lógica de tiers existente
[ ] 4. Confirmar con el equipo que la ficha aparece correctamente
[ ] 5. Iniciar Bloque 3 — crear hojas nuevas en el Sheet primero
[ ] 6. Implementar GS_23_EtiquetasBase.gs
[ ] 7. Implementar GS_24_Pacientes360.gs + ViewAdminPatients.html
```

---

*AscendaOS v1 · CreActive OS · César Jáuregui Torres*
*Documento de respaldo — carpeta /docs*
*Generado: Abril 2026*
