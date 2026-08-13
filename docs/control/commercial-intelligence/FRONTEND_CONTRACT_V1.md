# ASCENDA OS — COMMERCIAL INTELLIGENCE FRONTEND CONTRACT V1

**Estado:** CURRENT CONTRACT / Phase 0  
**Fecha:** 2026-08-13  
**Ámbito:** nuevo panel ADMIN `Bases & Audiencias` y sus integraciones contextuales.

---

# 1. FUENTE DE VERDAD VISUAL

El frontend productivo real vive en `app/public/`. El nuevo módulo debe reutilizar el lenguaje visual existente de `admin-calls.html` y `admin-marketing.html`.

Tokens observados y aprobados:

- tipografía UI: `DM Sans`;
- títulos/KPI: `Exo 2`;
- primary blue: `#0A4FBF`;
- navy: `#071D4A` / `#0D1B3E`;
- cyan accent: `#00C9A7`;
- border: `#DDE4F5`;
- soft background: `#F8FAFF`, `#F0F4FC`, `#EBF2FF`;
- success: `#059669` / `#16A34A`;
- warning: `#D97706`;
- danger: `#DC2626`;
- purple analytical accent: `#7C3AED`;
- cards: white, border 1px, radius aprox. 14px;
- modals: white, radius aprox. 20px, shadow navy suave;
- overlay: navy transparente + `backdrop-filter: blur(...)`.

No introducir una librería visual ajena solo para este panel sin justificarla.

---

# 2. PROHIBICIONES UX

No usar como experiencia productiva normal:

- `alert()`;
- `confirm()`;
- `prompt()`;
- modales nativos/oscuros no integrados;
- tablas sin estados loading/empty/error;
- controles que expongan SQL/campos internos;
- acciones destructivas sin explicación/confirmación propia;
- UI que permita a asesor autoasignarse base por manipulación cliente.

---

# 3. NUEVO PANEL ADMIN

Nombre visible inicial:

## `Bases & Audiencias`

Nombre técnico del dominio:

`Commercial Intelligence & Audience OS`

Debe registrarse en el shell productivo `app/public/app.html` como panel administrativo propio cuando llegue Fase 5.

No convertir `admin-marketing.html` ni el modal de `admin-calls.html` en el panel maestro.

---

# 4. NAVEGACIÓN FINAL PREVISTA

El panel central tendrá tabs/áreas:

1. **Dashboard**
2. **Audiencias**
3. **Constructor**
4. **Distribución**
5. **Asesores**
6. **Oportunidades IA**
7. **Solicitudes**
8. **Segmentación**
9. **Activaciones**
10. **Historial / Auditoría**

La disponibilidad de tabs depende de fase/feature flag/permisos; no todos deben aparecer habilitados desde el primer deploy.

---

# 5. DASHBOARD

Debe responder sin intervención manual:

- contactos totales;
- audiencias activas;
- dinámicas/snapshots;
- contactos sin trabajar relevantes;
- activaciones vigentes;
- carga por asesor;
- bases próximas a agotarse;
- oportunidades detectadas;
- solicitudes pendientes;
- métricas de uso del motor;
- freshness/última actualización.

El dashboard lee datos vivos/derivados; no requiere “reconstruir bases” manualmente.

---

# 6. AUDIENCE BUILDER — LAYOUT

Desktop objetivo:

### Columna izquierda — Sources / Facts

- Perfil / CRM
- Leads
- Llamadas
- Agenda
- Ventas
- Productos
- Servicios
- Seguimientos
- Email / engagement
- Segmentación
- Asesor / ownership cuando corresponda

### Centro — Builder

- grupos AND/OR;
- máximo inicial de 2 niveles visuales de anidación;
- chips/reglas editables;
- exclusiones explícitas;
- presets;
- duplicate/delete rule;
- validación inmediata.

### Derecha — Live Preview

- total audiencia;
- datos válidos por canal;
- elegibles;
- disponibles ahora;
- identity conflicts;
- muestra de contactos;
- reasons/exclusions;
- freshness.

En tablet/móvil las columnas pasan a pasos/accordion sin perder funcionalidad.

---

# 7. AUDIENCE LIBRARY

Cada audiencia muestra:

- nombre;
- descripción corta;
- tipo `DYNAMIC` / `SNAPSHOT`;
- versión;
- total actual o congelado;
- última resolución;
- owner/creador;
- activaciones actuales;
- estado;
- alertas de cambios relevantes.

Acciones administrativas:

- Abrir
- Duplicar
- Editar nueva versión
- Usar / Activar
- Archivar
- Ver historial

No sobrescribir versiones históricas utilizadas por campañas/activaciones.

---

# 8. CONTEXTUAL PICKER

Los paneles consumidores reutilizan la biblioteca con una “lente” contextual.

## Call Center

Columnas mínimas:

- audiencia;
- total;
- elegibles llamada;
- disponibles ahora;
- asignados;
- sin trabajar;
- próxima expiración/agotamiento.

Acciones ADMIN:

- seleccionar;
- distribuir;
- activar cola;
- abrir gestión avanzada.

## Email

- total;
- con email;
- identidad reconciliada;
- elegibles;
- nunca enviados/UNKNOWN;
- último email.

## SMS / WhatsApp futuros

Mismo patrón, sin duplicar audiencias.

---

# 9. DISTRIBUCIÓN

El administrador debe poder seleccionar:

### método

- un asesor;
- equitativo;
- porcentaje;
- cantidades;
- policy asistida/recomendada.

### modo

- snapshot/lote;
- cola dinámica;
- temporal;
- jornada;
- hasta completar.

### capacidad

- cantidad;
- lease/expiración;
- top-up policy;
- prioridad.

Antes de confirmar mostrar preview:

- candidatos;
- excluidos;
- ya asignados;
- resultado por asesor;
- carga antes/después;
- reason codes relevantes.

---

# 10. VISTA ASESOR

El asesor normal no administra audiencias globales.

Puede ver:

- su base/cola actual;
- disponibles;
- pendientes;
- seguimientos;
- rellamadas;
- prioridades personales permitidas;
- progreso;
- citas/ventas relacionadas a su trabajo;
- mensajes/notificaciones de KronIA.

Puede pedir a KronIA una vista de sus propios contactos sin aprobación si no cambia ownership.

Si solicita contactos fuera de su universo, la UI genera una solicitud administrativa; no ejecuta autoasignación.

---

# 11. SOLICITUDES / APPROVALS

Pop-up/side panel ADMIN con:

- solicitante;
- acción solicitada;
- base actual;
- pendientes actuales;
- nueva audiencia;
- cantidad;
- disponibilidad recalculable;
- recomendación IA si existe;
- evidencia/confidence;
- expiración de propuesta.

Botones:

- Aprobar
- Aprobar con cambios
- Rechazar
- Revisar audiencia

Al aprobar se debe revalidar estado actual antes de ejecutar.

---

# 12. OPORTUNIDADES IA

Cards explicables, no “magia”.

Cada recomendación debe mostrar:

- oportunidad;
- tamaño;
- prioridad;
- motivo;
- facts usados;
- advisor sugerido si aplica;
- score;
- confidence;
- sample size;
- generated_at;
- valid_until;
- CTA `Preparar`, `Crear audiencia`, `Revisar`, `Ignorar`.

Shadow Mode puede registrar recomendaciones sin mostrarlas inicialmente.

---

# 13. SEGMENTACIÓN

Separar visualmente:

- Value Tier: STANDARD / PREMIUM / GOLD / DIAMANTE;
- Lifecycle;
- Engagement;
- Traits.

Mostrar policy/version/calculated_at y explicación del nivel.

No usar una única badge VIP para representar todo el comportamiento del cliente.

---

# 14. ESTADOS UI OBLIGATORIOS

Cada bloque de datos soporta:

- skeleton/loading;
- success;
- empty;
- partial/UNKNOWN;
- stale;
- error retryable;
- permission denied;
- feature disabled.

Un dato `UNKNOWN` debe mostrarse distinto a `NO`.

---

# 15. AUTO-REFRESH / FRESHNESS

La interfaz no debe pedir al administrador actualizar bases manualmente.

Mecanismo final puede combinar:

- refresh al entrar;
- invalidación por eventos relevantes;
- polling moderado en dashboards operativos;
- caché con TTL para facts agregados;
- background jobs para analytics.

Siempre mostrar `Actualizado hace X` cuando el dato no sea request-time.

Evitar polling agresivo que repita el problema histórico de trabajo background innecesario.

---

# 16. ACCESSIBILITY / RESPONSIVE

Mínimos:

- keyboard focus visible;
- botones reales para acciones;
- labels accesibles;
- contraste legible;
- no depender solo de color;
- tablas con overflow controlado;
- mobile/tablet usable;
- touch targets razonables;
- modales con scroll interno y cierre consistente.

---

# 17. COMPONENTES REUTILIZABLES OBJETIVO

No es obligatorio extraerlos todos en Fase 5, pero el CSS/JS debe diseñarse para reutilización:

- `AOSCard`
- `AOSKPI`
- `AOSTag`
- `AOSModal`
- `AOSToast`
- `AOSTabs`
- `AOSDataTable`
- `AOSRuleChip`
- `AOSReasonList`
- `AOSFreshnessBadge`
- `AOSApprovalCard`

Con la arquitectura estática actual pueden implementarse como patrones CSS/JS compartidos sin imponer un framework nuevo.

---

# 18. WIREFRAME FUNCIONAL V1

```text
┌ Bases & Audiencias ─────────────────────────────────────────────────────┐
│ Dashboard | Audiencias | Constructor | Distribución | Asesores | IA ... │
├─────────────────────────────────────────────────────────────────────────┤
│ 11,571 contactos | 0 audiencias | X sin llamar | X seguimientos | ...  │
├─────────────────────────────────────────────────────────────────────────┤
│ Oportunidades / alertas / freshness / carga por asesor                 │
└─────────────────────────────────────────────────────────────────────────┘

CONSTRUCTOR
┌────────────────┬──────────────────────────────────┬─────────────────────┐
│ Facts          │ AND                              │ 412 contactos       │
│ • Leads        │ Tratamiento = ENZIMAS            │ 397 teléfono válido │
│ • Llamadas     │ AND Nunca compró ENZIMAS         │ 366 disp. llamada   │
│ • Agenda       │ AND (Nunca llamado OR >30 días)  │ 244 con email       │
│ • Ventas       │ AND Sin cita futura              │ 2 conflicts         │
│ ...            │                                  │ Ver muestra         │
└────────────────┴──────────────────────────────────┴─────────────────────┘
```

---

# 19. FEATURE FLAG UX

Cuando una capacidad no esté liberada:

- ocultar si no aporta contexto; o
- mostrar como `Próximamente`/`En validación` si ayuda a entender roadmap;
- nunca dejar botones que aparenten ejecutar pero no hagan nada sin feedback claro.

El panel central puede aparecer read-only antes que distribución/escritura.

---

# 20. ACCEPTANCE FRONTEND GATE

Una fase con UI no cierra hasta validar:

1. mismo shell ASCENDA;
2. desktop/tablet/mobile;
3. loading/empty/error/UNKNOWN;
4. roles correctos;
5. no native dialogs;
6. no SQL/identificadores internos expuestos innecesariamente;
7. no regresión navegación/sesión;
8. smoke test visual;
9. rollback/flag;
10. performance aceptable.
