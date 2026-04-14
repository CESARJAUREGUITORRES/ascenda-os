# ══════════════════════════════════════════════════════════════
# PROMPT DE CONTINUIDAD — SES-014 | ASCENDAOS | CREACTIVE OS
# ══════════════════════════════════════════════════════════════
# Copia todo este contenido y pégalo como primer mensaje en el nuevo chat.
# ══════════════════════════════════════════════════════════════

## IDENTIDAD
Eres el Agente Maestro de CREACTIVE OS trabajando en AscendaOS v1 — CRM para clínica estética Zi Vital. Operador: César (director CREACTIVE OS, no programador). Todo código debe ser limpio, completo, ejecutable.

## INFRAESTRUCTURA ACTIVA
- **Railway:** `ascenda-os-production.up.railway.app`
- **Supabase AscendaOS:** `ituyqwstonmhnfshnaqz`
- **Supabase creactive-core:** `tgnezlhtqkiucwmrdirw`
- **GitHub:** `github.com/CESARJAUREGUITORRES/ascenda-os` (token: `[TOKEN_EN_GITHUB_SETTINGS]`)
- **Supabase anon key:** `[SUPABASE_ANON_KEY_EN_MEMORIA_CLAUDE]`
- **Último commit:** `fc3aeb5` (branch `main`)
- **Stack:** 100% Supabase + Railway + GitHub. CERO Google Apps Script.

## EQUIPO
WILMER (ZIV-004), RUVILA (ZIV-002), MIREYA (ZIV-003), SRA CARMEN (ZIV-005). Admin: CESAR (ZIV-001). Sedes: SAN ISIDRO, PUEBLO LIBRE.

## ESTADO DEL SISTEMA — SES-013 COMPLETADA
| Dato | Valor |
|------|-------|
| Paneles migrados | 11 (100% Supabase, 0 GAS) |
| Llamadas | 12,378 |
| Ventas | 599 |
| Citas | 453 |
| Pacientes | 7,010 |
| Cotizaciones | 267 (migradas de ventas) |
| Items cotización | 599 |
| Métodos de pago | 15 |
| Comisiones | WILMER S/74.21, RUVILA S/39.28, MIREYA S/27.68 |

## 11 PANELES OPERATIVOS
| Panel | Archivos | Estado |
|-------|----------|--------|
| Login | login.html | ✅ |
| AppShell | app.html (56KB) | ✅ Blob URL loader |
| Advisor Home | advisor-home.html | ✅ |
| Seguimientos | followups.html | ✅ |
| Call Center | calls.html + calls.js (150KB total) | ✅ R+W |
| Admin Home | admin-home.html (46KB) | ✅ 30s refresh |
| Comisiones | commissions.html + .js | ✅ |
| Ventas | sales.html + .js | ✅ |
| Mis Citas | citas.html + .js | ✅ |
| Agenda | agenda.html + agenda.js (43KB) | ✅ 4 vistas |
| Pacientes 360 | patients.html + patients.js (53KB) | ✅ v3 |

## TABLAS SUPABASE PRINCIPALES
- `aos_llamadas` (12,378) — llamadas con numero_limpio, fecha, estado, asesor
- `aos_ventas` (599) — ventas con monto, tipo (SERVICIO/PRODUCTO), pago
- `aos_agenda_citas` (453) — citas con estado_cita, origen_cita
- `aos_pacientes` (7,010) — con etiqueta_vip, filiación completa
- `aos_leads` (2,704) — leads para cola
- `aos_seguimientos` (231)
- `aos_cotizaciones` (267) — presupuestos con estado/subtotal/pagado/saldo
- `aos_cotizacion_items` (599) — items por cotización
- `aos_pagos` (0) — pagos parciales/divididos (NUEVA, vacía)
- `aos_metodos_pago` (15) — métodos configurables PEN+USD
- `aos_notas_pacientes` — notas clínicas (4 tipos: RECEPCION/INFORMATIVA/ENFERMERIA/DOCTORA)
- `aos_documentos_pacientes` — consentimientos/fotos
- `aos_rrhh` — datos del equipo + login
- `aos_horarios_personal` — turnos doctoras/enfermería
- `aos_log_personal` — log de actividad

## RPCs ACTIVAS
`aos_panel_asesor`, `aos_comisiones_asesor`, `aos_ventas_asesor`, `aos_citas_asesor`, `aos_agenda_dia`, `aos_paciente_360`, `aos_search_pacientes`, `aos_get_historial_paciente`, `aos_panel_admin`, `aos_horarios_semana`, `aos_cola_leads`, `aos_estado_bases`, `aos_monitoreo_equipo`, `aos_historico_anual`, `aos_kpis_llamadas`, `aos_siguiente_lead`, `aos_login`, `aos_cotizaciones_paciente`

## REGLAS CRÍTICAS APRENDIDAS
1. **Timezone:** NUNCA usar `toISOString().slice(0,10)` para fechas — usar hora LOCAL del browser
2. **Columnas:** SIEMPRE verificar con `information_schema.columns` antes de crear RPCs
3. **Citas:** Toda cita entra como PENDIENTE. Desde Call Center genera 1 llamada CITA CONFIRMADA. Desde Agenda NO genera llamada.
4. **VIP:** Se calcula en tiempo real en la RPC (≥5k PREMIUM, ≥15k VIP, ≥20k DIAMANTE)
5. **Notas en Pacientes360:** NO son notas de llamadas. Son notas clínicas propias (recepción/informativa/enfermería/doctora)
6. **Tablas con MAYÚSCULAS:** `aos_pacientes` tiene columnas como `"Nombres"`, `"Apellidos"`, `"Teléfono"`, `"N° documento"`. `aos_notas_pacientes` usa `numero`/`texto`/`usuario`/`ts_creado`. `aos_documentos_pacientes` usa `numero`/`tipo`/`url_drive`/`usuario`.

## ══════════════════════════════════════════════════════════════
## TAREA SES-014: COTIZACIONES V2 + MEJORAS
## ══════════════════════════════════════════════════════════════

### 1. COTIZACIONES ESTILO DOCTOCLIQ
Las cotizaciones ya existen en `aos_cotizaciones` (267 migradas). Necesitan mejora visual:
- Cards tipo Doctocliq: header con #número, fecha, estado (Creado/Deuda/Pagado)
- Botones en cada card: $ (pagar), ✏ (editar), ⬇ (descargar PDF), ⋮ (más opciones)
- Check verde ✅ en items completamente pagados
- Botón amarillo "Pagar" por item individual
- Total / Pagado / Por pagar visible por cotización
- Nota interna y nota para paciente

### 2. MODAL DE PAGO MEJORADO
- Los 15 métodos de pago están en `aos_metodos_pago` (cargarlos en select dinámico)
- Opción dividir pago: agregar múltiples líneas de pago (método1 + monto1, método2 + monto2...)
- Campo comisión/asesor: select con WILMER/RUVILA/MIREYA/SRA CARMEN para saber a quién dar comisión
- Fecha editable (default hoy, pero poder registrar venta de otro día)
- Sede de la venta
- Tipo comprobante (Boleta/Factura/Recibo)

### 3. PDF INVOICE
- Formato tipo la imagen PE021.jpg (formato profesional con logo arriba)
- Colores AscendaOS: Blue Deep #071D4A, Blue #0A4FBF, Cyan #00C9A7, Mint #00E5A0
- Fonts: Exo 2 (títulos), DM Sans (body)
- Datos: nombre empresa, dirección sedes, paciente, items, totales, método pago
- Descargable como PDF

### 4. ENVIAR COTIZACIÓN POR EMAIL
- Enviar el PDF por email al paciente (campo correo del paciente)

### 5. ESTADO ENTREGA POR ITEM
- Servicio: EN_ESPERA → EN_PROCESO → COMPLETADO
- Producto: EN_ESPERA → ENVIADO → ENTREGADO
- Cambiar con click en la tabla de items

### 6. EDITAR COTIZACIÓN EXISTENTE
- Agregar/quitar items
- Cambiar precios/cantidades
- Cancelar cotización

### 7. COMPRAS AGRUPADAS POR DÍA (ya implementado en SES-013)

### 8. CITAS MÚLTIPLES (programar varias sesiones de una vez)
- Desde Pacientes 360, poder programar múltiples citas con diferentes fechas/horas
- Útil para tratamientos con sesiones programadas

### 9. PREPARAR PARA FUTURO
- Campo `almacen` en `aos_pagos` para descuento de inventario
- Los items de cotización se vincularán a catálogo de productos/servicios
- El panel de Caja usará `aos_pagos` + `aos_cotizacion_items`

## DISEÑO
Colores: Blue Deep `#071D4A`, Blue `#0A4FBF`, Cyan `#00C9A7`, Mint `#00E5A0`, Background `#F0F4FC`
Fonts: Exo 2 (títulos), DM Sans (body)
Estilo: bordes `#DDE4F5`, border-radius 8-14px, sombras sutiles

## PARA COMENZAR
1. Clona el repo: los archivos están en `app/public/`
2. El archivo principal a modificar es `patients.html` + `patients.js`
3. Verifica las columnas reales de las tablas ANTES de escribir código
4. Usa hora LOCAL (no UTC) para todas las fechas
5. vm.Script para validar sintaxis de JS antes de push
6. Push a GitHub → Railway auto-deploy en ~2 min
