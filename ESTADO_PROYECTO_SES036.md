# ESTADO COMPLETO DEL PROYECTO — ASCENDA OS + STUDIO
## Sesión SES-036 | 4 mayo 2026 | 1,009 commits

---

## DATOS DUROS

| Métrica | Valor |
|---|---|
| Commits | 1,009 |
| Tablas Supabase | 162 |
| RPCs | 205 |
| Archivos frontend | 38 (28,403 líneas) |
| Server.js | 3,087 líneas |
| Pacientes | 7,166 |
| Llamadas | 17,046 |
| Citas agenda | 1,619 |
| Ventas | 692 |
| Seguimientos | 188 |
| FAQs catálogo | 612 |
| Integraciones conectadas | 6 (Gemini, Groq, Supabase, Railway, Resend, GitHub) |
| Integraciones pendientes | 43 |

---

## PANELES — QUÉ FUNCIONA Y QUÉ FALTA

### 1. FLUJO CLÍNICO (Agenda → Atención → Insumos)
**Estado: 🟡 Parcial — El flujo existe pero falta validar y pulir**

| Paso | Estado | Qué falta |
|---|---|---|
| Paciente llega | ✅ Se busca en agenda | - |
| Filiación/Triaje | ✅ Chips ENF/DRA | - |
| Atención enfermería | ✅ Panel existe | Validar flujo real |
| Atención doctora | 🟡 Panel existe | Falta panel específico de doctora |
| Pago en caja | ✅ Funciona | - |
| Consentimiento | 🟡 Existe | Validar flujo |
| Descuento insumos | 🔴 UI existe pero vinculo auto tratamiento→insumos no | Construir |
| Plan de trabajo | 🟡 Existe | Validar programación |
| Programar sesiones | ✅ Tab Programar existe | Validar con datos reales |
| Caso enfermería+doctora mismo día | 🟡 BD soporta | Validar que no se mezclen |
| Receta médica/enfermería | 🟡 Existe | Validar PDF |

### 2. AGENDA Y AGENDAMIENTO
**Estado: 🟡 Funcional con mejoras pendientes**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Agenda diaria | ✅ | - |
| Slots por doctora | ✅ | - |
| Auto-agendamiento (/agendar) | ✅ v4 | Validar en producción |
| Links de agendamiento (tokens 48h) | ✅ | Validar |
| Calendario de doctoras con turnos | ✅ | - |
| Google Calendar sincronización | 🔴 | API conectada pero no integrada al flujo |
| Google Contacts al agendar | 🔴 | No construido |
| Email confirmación cita | ✅ | - |
| Email reagendar | 🟡 | Existe pero falta probar |

### 3. LLAMADAS / CALL CENTER
**Estado: ✅ Funcional con mejoras pendientes**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Cola de leads (Lógica Madre 8 tiers) | ✅ | - |
| Score mensual | ✅ | - |
| Tipificación | ✅ | - |
| Historial de llamadas | ✅ | - |
| Calendario con días de doctora | ✅ | - |
| Card contextual del cliente | 🟡 DEUDA-2A | Agregar (patch ~50 líneas) |
| Asistente AI para el asesor | 🔴 | Diseñado pero no construido |
| Plantillas de WhatsApp | 🟡 | Existen pero falta validar |

### 4. INVENTARIO
**Estado: ✅ Funcional**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Stock por sede | ✅ | - |
| Ingreso de inventario | ✅ | - |
| Conteo | ✅ | - |
| Movimientos | ✅ | - |
| Descuento por venta (productos) | ✅ Auto | - |
| Descuento por tratamiento (insumos) | 🔴 | No vinculado automáticamente |
| Alertas bajo stock | 🟡 | Existe pero validar |

### 5. CATÁLOGO
**Estado: ✅ Funcional**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Categorías + servicios | ✅ | - |
| 612 FAQs | ✅ | - |
| Cotización inteligente | ✅ | - |
| Promociones | ✅ | - |
| Repositorio | ✅ | - |

### 6. VENTAS Y COMISIONES
**Estado: 🟡 Funcional con mejoras pendientes**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Registro de ventas | ✅ | - |
| Comisiones por asesor | ✅ | - |
| Ventas por sede | 🟡 | Falta filtro claro por sede |
| Etiquetas por servicio | 🔴 | No implementado |
| Etiquetas por campaña/marketing | 🔴 | No implementado |
| Juntar ventas+comisiones en panel | 💡 Idea | Sub-chips |
| Comprobantes | 🟡 | Panel existe, validar flujo |
| PDF de comprobante con QR | 🟡 | Diseñado, validar |

### 7. FACTURACIÓN
**Estado: 🟡 Panel existe**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Panel de facturación | ✅ | - |
| Registro manual SUNAT | 🟡 | Existe pero validar |
| Comprobantes sin etiquetar (alarma) | 🟡 | Diseñado |
| Flujo comprobante → boleta/factura | 🟡 | Validar |

### 8. MARKETING
**Estado: 🟡 Básico**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Panel marketing admin | ✅ Básico | - |
| Leads por campaña | ✅ | - |
| Email marketing | ✅ 17 templates | - |
| Conexión con redes sociales | 🔴 | Necesita tokens de Meta/TikTok |
| Datos reales de redes | 🔴 | Sin APIs conectadas |
| Complementar con Studio | 💡 | Pestaña nueva o sub-tab |

### 9. EQUIPO
**Estado: ✅ Sólido**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Gestión de usuarios | ✅ | - |
| Roles y permisos | ✅ | - |
| Fotos + CMP doctoras | ✅ | - |
| Servicios por usuario | ✅ | - |
| Turnos/horarios vinculados | 🔴 | No guardados en config |

### 10. CONFIGURACIÓN
**Estado: ✅ Muy completo**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Empresa (datos, logo) | ✅ | - |
| Integraciones | ✅ 49 registradas | Faltan keys |
| Assets de marca | ✅ | - |
| Seguridad | 🟡 | Existe pero falta auditoría |

### 11. CHAT DE EQUIPO + TAREAS
**Estado: 🟡 Construido**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Chat | ✅ | Pulir |
| Tareas | ✅ | Pulir |
| Coordinación | ✅ | Validar |

### 12. HOME (Dashboard)
**Estado: 🟡 Funcional**

| Funcionalidad | Estado | Qué falta |
|---|---|---|
| Admin home | ✅ | - |
| Asesor home | ✅ | - |
| Notificaciones reales | 🔴 | No conectadas |
| Sonidos | 🔴 | No implementados |
| Resumen por asesor/sede | 🟡 | Existe pero mejorar |

### 13. PACIENTES 360
**Estado: 🔴 No construido — Bloque 3 aprobado**

8 zonas diseñadas:
1. Tarjeta de identidad editable
2. Historia clínica (MINSA estética)
3. Compras agrupadas por día + PDF
4. Citas + crear-desde-aquí
5. Historial de llamadas + tipificaciones
6. Notas multi-rol
7. Documentos + fotos antes/después
8. Seguimientos programados por tratamiento

---

## ASCENDA STUDIO — ESTADO REAL

| Componente | Estado |
|---|---|
| Panel con 7 tabs | ✅ Estructura |
| Chat AI (copys con Groq) | ✅ Funciona GRATIS |
| Chat AI (imágenes con Gemini) | ✅ Código listo, cuota diaria 500 imgs |
| Creator HTML (editor visual) | ✅ Funciona |
| Templates (10) | ✅ |
| Cron scheduler | ✅ Código listo |
| Endpoints de publicación (IG/FB/LI) | ✅ Código listo |
| Conexión a redes sociales | 🔴 Sin tokens configurados |
| UX profesional | 🔴 Necesita rediseño |
| Flujo completo punta a punta | 🔴 No probado |

---

## PLAN DE ACCIÓN — ORDEN PROPUESTO

### FASE 1: CERRAR EL CRM (5-8 sesiones)

**Sesión A — Flujo clínico completo:**
- Validar: Agenda → Asistió → Atención → ENF/DRA → Insumos
- Construir: descuento automático de insumos por tratamiento
- Validar: caso enfermería + doctora mismo día
- Panel de atención de doctora

**Sesión B — Agenda y agendamiento:**
- Validar link de auto-agendamiento
- Conectar Google Calendar + Google Contacts
- Email de reagendamiento
- Optimizar modal de agendar (admin)

**Sesión C — Llamadas y seguimiento:**
- Card contextual del cliente (DEUDA-2A)
- Plantillas de WhatsApp validar
- Asistente AI para asesor (con Groq gratis)

**Sesión D — Ventas, comisiones, facturación:**
- Etiquetas por servicio y campaña
- Filtro por sede
- Juntar ventas+comisiones (sub-chips)
- Validar flujo de comprobantes y facturación
- PDF con QR

**Sesión E — Inventario, catálogo, equipo:**
- Descuento de insumos por tratamiento
- Validar alertas bajo stock
- Turnos/horarios guardados en config
- Validar catálogo completo

**Sesión F — Marketing + Home + Notificaciones:**
- Conectar redes sociales (tokens en integraciones)
- Datos reales en panel marketing
- Notificaciones reales
- Sonidos
- Home optimizado

**Sesión G — Pacientes 360:**
- Las 8 zonas del Bloque 3

### FASE 2: CIBERSEGURIDAD (1-2 sesiones)
- Auditoría de permisos por rol
- Validación backend
- Rate limiting + sanitización
- Sesiones y tokens

### FASE 3: STUDIO REAL (2-3 sesiones)
- UX profesional
- Flujo completo con APIs de redes
- Conectar con datos CRM

### FASE 4: CHATBOT + KRONIA (2-3 sesiones)
- WhatBot con FAQs
- KronIA calibrado

---

## INTEGRACIONES QUE NECESITAS CONFIGURAR

### PRIORIDAD ALTA (necesarias para CRM):
| Integración | Para qué | Acción tuya |
|---|---|---|
| Google Calendar | Turnos doctoras → agenda | Pegar token en Integraciones |
| Google Contacts | Guardar pacientes al agendar | Pegar token en Integraciones |
| WhatsApp Business | Chatbot + notificaciones | Crear app en Meta, pegar token |
| Facebook/Instagram | Publicar + métricas | Crear app en Meta, pegar token |

### PRIORIDAD MEDIA (para Studio):
| Integración | Para qué |
|---|---|
| OpenAI | Imágenes premium ($0.04/img) |
| LinkedIn | Publicar contenido |
| TikTok | Publicar videos |

### YA CONECTADAS Y FUNCIONANDO:
| Integración | Uso |
|---|---|
| Gemini | Imágenes AI (500/día gratis) |
| Groq | Copys AI (ilimitado gratis) |
| Supabase | Base de datos |
| Railway | Servidor |
| Resend | Emails |
| GitHub | Repositorio |
