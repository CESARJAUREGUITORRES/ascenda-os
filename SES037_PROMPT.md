# SES-037 — PROMPT DE CONTINUIDAD
## Cerrar CRM: Validar flujo clínico → Inventario → Agenda → Call Center → Marketing → Ventas → Comprobantes

---

## CONTEXTO INMEDIATO

Venimos de SES-036 (3-4 mayo 2026, ~40 commits, 1,010 totales). Se construyó Ascenda Studio v20 pero el CRM necesita cerrarse primero.

**DECISIÓN:** Cerrar el CRM antes de Studio/Chatbot/KronIA. Presentación el miércoles.

---

## CONEXIONES — LEER PRIMERO

```
Supabase AscendaOS: ituyqwstonmhnfshnaqz
Supabase Creactive-core: tgnezlhtqkiucwmrdirw
GitHub: CESARJAUREGUITORRES/ascenda-os (1,010 commits)
Railway: ascenda-os-production.up.railway.app (200 OK)
Deploy: auto desde GitHub → Railway (1-2 min)

MEMORIA: SELECT categoria, clave, valor FROM aos_memory ORDER BY categoria, clave;
ESTADO: Leer /ESTADO_PROYECTO_SES036.md en el repo
REGLAS: SELECT valor FROM aos_memory WHERE clave LIKE 'regla_post1000%';
LECCIONES: Leer /LECCIONES_1000_COMMITS.md en el repo
APIs CONECTADAS: SELECT nombre, tipo, estado, api_key FROM aos_integraciones WHERE estado='conectado';
```

---

## APIs DISPONIBLES (YA CONECTADAS — leer de aos_integraciones)

| API | Tipo | Uso | Estado |
|---|---|---|---|
| Google Gemini | gemini | Imágenes AI 500/día gratis | ✅ CON KEY |
| Groq (Llama 3.3 70B) | groq | Copys AI ilimitados gratis | ✅ CON KEY |
| Supabase | supabase | BD PostgreSQL | ✅ |
| Railway | railway | Servidor Node.js | ✅ |
| Resend | resend | Emails | ✅ |
| GitHub | github | Repositorio | ✅ |

**43 integraciones pendientes en aos_integraciones** — las keys se configuran desde Configuración → Integraciones.

---

## ARCHIVOS CLAVE

```
app/public/app.html         — 1,932 líneas (shell principal)
app/public/attendance.html   — 2,575 líneas (flujo clínico)
app/public/caja.html         — 3,135 líneas (caja/pagos)
app/public/calls.html        — 1,434 líneas (call center)
app/public/calls.js          — 956 líneas
app/public/studio.html       — 2,314 líneas (Ascenda Studio)
app/public/studio-creator.html — 645 líneas (editor visual)
app/public/admin-config.html — 1,623 líneas (configuración)
app/public/admin-home.html   — 928 líneas (dashboard admin)
app/server.js                — 3,087 líneas (servidor Node.js)
```

---

## DATOS EN PRODUCCIÓN

- 7,166 pacientes
- 17,046 llamadas
- 1,619 citas
- 692 ventas
- 188 seguimientos
- 612 FAQs en catálogo
- 162 tablas Supabase
- 205 RPCs

---

## ORDEN DE TRABAJO PARA ESTA SESIÓN

### 1. Flujo clínico completo
Validar: Agenda → Asistió → Atención → ENF/DRA → Plan trabajo → Descuento insumos → Programar
- Caso enfermería sola
- Caso doctora sola
- Caso enfermería + doctora mismo día
- Panel de atención de doctora
- Descuento automático de insumos por tratamiento

### 2. Inventario (pulir)
- Conectar descuento de insumos con atención
- Validar alertas bajo stock
- Flujo completo

### 3. Catálogo (validar)
- Verificar FAQs, promos, servicios
- Que todo se refleje correctamente

### 4. Agenda (mejorar)
- Links de agendamiento (validar)
- Google Calendar + Contacts (conectar)
- Email reagendamiento
- Modal admin 2 columnas

### 5. Call Center (mejorar)
- Card contextual del cliente (DEUDA-2A)
- Plantillas WhatsApp
- Asistente AI con Groq gratis

### 6. Panel Llamadas Admin
- Mejorar administración de bases
- Integrar agentes AI

### 7. Marketing
- Conectar redes reales (tokens en integraciones)
- Datos reales en panel
- Nueva pestaña complementaria

### 8. Ventas + Comisiones
- Sub-chips (juntar)
- Etiquetas por servicio/campaña/sede
- Filtros mejorados

### 9. Comprobantes/Facturación
- PDF con QR
- Flujo completo
- Alarmas

---

## REGLAS DE TRABAJO (12 reglas post-1000 commits)

1. AUDITAR → PLANIFICAR → CONSTRUIR (nunca al revés)
2. Syntax check después de CADA edición
3. Todo fetch con .catch, todo getElementById con null guard
4. UN SOLO marker FIN en server para endpoints
5. Datos dinámicos nunca hardcoded
6. Preview antes de ejecutar acciones masivas
7. Auditoría completa cada 50 commits
8. Ratio fix/feature meta < 0.5
9. Todo estado de flujo en CHECK constraint ANTES de codificar
10. Función compartida cuando misma lógica en 2+ lugares
11. SESSION LOG al cierre
12. Cada tabla nueva: id default, CHECK constraints, created_at

---

## PENDIENTES HEREDADOS DE SESIONES ANTERIORES

- DEUDA-2A: Card contextual en panel asesor (GS_06 patch ~50 líneas)
- Fix buscador pacientes modal Agendar
- ViewAdminCalls KPIs parámetros filtro
- Panel atención doctoras
- Optimizar polling
- Notificaciones reales + sonidos
- Turnos/horarios guardados en config

---

## OPTIMIZACIÓN DE TRABAJO (investigación mayo 2026)

### Sistema de Memoria Jerárquica:
- **NIVEL 1** — Claude Memory (30 slots): Solo conexiones + instrucción de leer Supabase + plan activo
- **NIVEL 2** — Supabase aos_memory (157+ registros): TODO el contexto técnico, sesiones, reglas, estado
- **NIVEL 3** — Archivos .md en repo: Documentación profunda
- **NIVEL 4** — Transcripts: Historial completo de conversaciones

### Ahorro de Tokens:
- grep antes de view (no leer archivos completos)
- str_replace quirúrgico (no regenerar archivos)
- Syntax check INMEDIATO después de cada edición
- UN commit = UN cambio conceptual
- Guardar en Supabase INMEDIATAMENTE (no esperar al final)

### Flujo de Sesión:
- INICIO: Leer aos_memory + integraciones + últimos commits + Railway status (2 min)
- DURANTE: Guardar decisiones inmediatamente, commit por feature, syntax check siempre
- CIERRE: Actualizar estado en BD, commit final, verificar Railway

### Repos de Referencia:
- VILA-Lab/Dive-into-Claude-Code (98.4% es infraestructura, 1.6% es AI)
- shanraisshan/claude-code-best-practice (vertical slices, recaps)
- t0ddharris/claude-code-skills (brief→start pattern)
- Anthropic cookbook: memory + context engineering
