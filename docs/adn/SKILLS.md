# SKILLS.md — CREACTIVE OS
## Capacidades Transversales del Ecosistema | Versión 3.0
## Enriquecida con experiencia real — AscendaOS / Zi Vital

---

## QUÉ ES ESTE ARCHIVO

Las Skills son capacidades permanentes activas en TODOS los agentes, en TODO momento. No se activan con un comando: operan de fondo, como el sistema operativo sobre el que corren los agentes.

---

# SKILLS TÉCNICAS PERMANENTES

---

## SKILL-T01 | CONTROL+F FIRST

**Descripción:** Todo cambio de código viene con una ancla buscable, siempre.

**Aplicación:**
- Nombre exacto de función: `function nombreExacto()`
- Comentario único de ancla: `// ===== INICIO: NOMBRE_MÓDULO =====`
- ID HTML exacto: `id="nombre-elemento"`
- Texto literal único buscable en el archivo

**Prohibido:** "más abajo", "por el medio", "cerca del final"

**Ejemplo correcto:**
```
BUSCAR con Ctrl+F: function procesarFormulario()
PEGAR: Justo DESPUÉS del cierre de esa función (después de })
```

---

## SKILL-T02 | BLOQUES SIEMPRE COMPLETOS

**Descripción:** Nunca fragmentos. Bloques cerrados y copiables.

- Todas las llaves `{}` presentes y balanceadas
- Funciones completas de inicio a fin
- Sin `// ... resto del código`
- Si es largo: PARTE 1/3, PARTE 2/3, PARTE 3/3

---

## SKILL-T03 | PLAN ANTES DE CÓDIGO

**Protocolo:**
```
1. Diagrama o descripción del flujo
2. Lista de archivos a crear/modificar
3. Impacto en módulos existentes
4. Orden de implementación
5. CÓDIGO — solo después
```

---

## SKILL-T04 | SEPARACIÓN DE ARCHIVOS POR RESPONSABILIDAD

```
GS_XX_NombreModulo.gs  → backend, lógica de negocio
ViewNombre.html        → frontend, una vista por archivo
GS_01_Config.gs        → constantes e IDs (nunca hardcodear)
GS_03_CoreHelpers.gs   → helpers reutilizables (nunca duplicar)
GS_04_DataAccess.gs    → SIEMPRE usar da_* para leer Sheets
```

**Regla AscendaOS:** Si una función lee Sheets directamente sin pasar por `da_*`, es un bug potencial.

---

## SKILL-T05 | NOMENCLATURA DE MÓDULOS Y ANCLAS

```javascript
// ===== MOD-01-START: AUTENTICACIÓN =====
// ... código ...
// ===== MOD-01-END: AUTENTICACIÓN =====
```

**Nomenclatura de archivos AscendaOS:**
- Backend: `GS_XX_NombreModulo.gs` (GS_00 a GS_28+)
- Frontend: `ViewAdminNombre.html` o `ViewAdvisorNombre.html`
- Docs: `NOMBRE.md`

---

## SKILL-T06 | CHECKLIST DE PRUEBA OBLIGATORIO

```
CHECKLIST — [nombre del cambio]
═══════════════════════════════

ANTES:
  □ Archivo guardado sin errores de sintaxis
  □ [GAS] Función de prueba ejecutada manualmente

PRUEBA BÁSICA:
  □ [acción] → [resultado esperado]

PRUEBA DE BORDE:
  □ Campo vacío, usuario sin permiso, sin datos

ÉXITO: [señal visual esperada]
FALLO: [error común] → [qué hacer]
```

---

## SKILL-T07 | INVESTIGAR ANTES DE INVENTAR

1. Buscar en GitHub con términos específicos
2. Evaluar: stars, actividad, documentación
3. Citar fuente siempre
4. Evaluar aplicabilidad al stack GAS/Supabase
5. Adaptar, no copiar ciegamente

---

## SKILL-T08 | SEGURIDAD COMO CAPA ESTRUCTURAL

```
□ Credenciales hardcodeadas → NUNCA
□ SUPABASE_KEY (service) → solo PropertiesService backend
□ Publishable key → OK en frontend para lecturas
□ Validación de inputs → siempre en backend GAS
□ Rol verificado antes de ejecutar → siempre
□ Datos sensibles en logs → nunca
```

---

## SKILL-T09 | GESTIÓN DE MEMORIA SUPABASE *(nueva — aprendida en Zi Vital)*

**Descripción:** La memoria del proyecto vive en `aos_memory` (Supabase), no en el chat.

**Protocolo al INICIAR sesión:**
```
1. SELECT * FROM aos_memory ORDER BY categoria
2. SELECT nombre, tipo, LENGTH(contenido) FROM aos_codigo_fuente ORDER BY tipo, nombre
→ Con eso tengo TODO el contexto. Sin pegar documentos en el chat.
```

**Protocolo al CERRAR sesión:**
```
1. UPDATE aos_memory con nuevos estados completados
2. UPDATE pendientes resueltos / agregar nuevos
3. INSERT en HISTORIAL_SESIONES el log de la sesión
4. Todo queda persistente para la próxima sesión
```

**Por qué importa:** Sin esto, cada sesión empieza desde cero. Con esto, arranca en 2 mensajes con contexto completo.

**Creada:** 2026-04-10 | **Basada en:** migración Supabase Sesión A

---

## SKILL-T10 | RESOLVER CONFLICTOS GIT ANTES DE SUBIR *(nueva — aprendida en Zi Vital)*

**Descripción:** Detectar y limpiar markers de conflicto Git antes de cualquier deploy o subida a Supabase.

**Detección:**
```python
import re
conflict_pattern = re.compile(r'<<<<<<< HEAD|=======|>>>>>>>')
# Si encuentra → resolver antes de subir
```

**Regla de resolución:** Siempre mantener versión HEAD (`<<<<<<< HEAD ... =======`) y descartar incoming (`======= ... >>>>>>>`), salvo instrucción explícita del operador.

**Archivos afectados en Zi Vital (11/04/2026):** AppShell, Login, ViewAdminHome (20 conflictos), ViewAdvisorFollowups (8), ViewAdvisorHome, ViewAdvisorCalls, ViewAdvisorCommissions.

**Por qué importa:** Los markers `<<<<<<<` rompían el HTML silenciosamente — el sistema cargaba pero con lógica duplicada o faltante.

**Creada:** 2026-04-11 | **Basada en:** subida RAR frontend Sesión B

---

## SKILL-T11 | SUBIDA MASIVA VÍA REST API *(nueva — aprendida en Zi Vital)*

**Descripción:** Para subir archivos grandes a Supabase, usar REST API directo desde Python, no SQL strings en el MCP tool.

**Por qué:** Los HTMLs de AscendaOS pesan 10-100KB. Pasarlos como string SQL supera los límites del tool. La REST API acepta el payload JSON sin restricción de tamaño.

**Patrón:**
```python
import json, urllib.request

def upsert_supabase(nombre, tipo, contenido):
    payload = json.dumps({"nombre": nombre, "tipo": tipo, "contenido": contenido}).encode('utf-8')
    url = f"{SUPABASE_URL}/rest/v1/aos_codigo_fuente?nombre=eq.{nombre}"
    req = urllib.request.Request(url, data=payload, method='PATCH',
        headers={'apikey': KEY, 'Authorization': f'Bearer {KEY}',
                 'Content-Type': 'application/json', 'Prefer': 'return=minimal'})
    with urllib.request.urlopen(req) as r:
        return r.status  # 204 = actualizado
```

**Creada:** 2026-04-11 | **Basada en:** subida 20 HTML desde RAR

---

# SKILLS COMERCIALES PERMANENTES

---

## SKILL-C01 | OJO COMERCIAL PARALELO

Mientras construyo técnico, pregunto internamente:
- ¿Resuelve un dolor real del Buyer Persona?
- ¿Es diferenciador o commodity?
- ¿Tiene nombre marketeable?
- ¿Justifica subir el precio o retiene clientes?

---

## SKILL-C02 | BENCHMARK CONSTANTE DE PRECIOS

1. Identificar 3-5 competidores con precios públicos
2. Mapear qué incluye cada tier
3. Posicionar: disruptor (-20-30%), paridad, o premium
4. **Nunca** poner precio sin este benchmark

---

## SKILL-C03 | CIERRE DE SESIÓN CON VALOR COMERCIAL

Al cerrar sesiones técnicas:
- ¿Lo construido hoy tiene nombre que un cliente entendería?
- ¿Algún feature merece estar en el pitch deck?
- ¿Detectamos algo que un competidor no tiene?

---

## SKILL-C04 | VERTICALES CREACTIVE OS *(nueva)*

**Descripción:** Cada módulo de AscendaOS es potencialmente replicable en otras verticales.

**Mapa actual:**
| Módulo | AscendaClinic | AscendaLegal | AscendaPsych | AscendaFinance |
|--------|--------------|--------------|--------------|----------------|
| Call Center | ✅ | Leads clientes | Captación | Prospección |
| Pacientes 360 | ✅ | Clientes/casos | Pacientes | Clientes |
| Comisiones | ✅ | Abogados | Terapeutas | Asesores |
| Agenda | ✅ | Audiencias | Sesiones | Reuniones |

**Regla:** Al construir cualquier módulo, diseñarlo para que pueda parametrizarse para otro vertical sin reescribir.

**Creada:** 2026-04-11

---

# SKILL-META | CREAR Y ACTUALIZAR SKILLS

---

## SKILL-META01 | CREAR NUEVA SKILL

**Activar cuando:**
- Se resolvió un problema recurrente elegantemente
- Se encontró un patrón que volverá a aparecer
- El operador dice "esto lo hacemos seguido"

**Formato:**
```markdown
## SKILL-XX | NOMBRE

**Descripción:** Una línea.
**Cuándo activar:** [situaciones]
**Protocolo:** [pasos]
**Por qué importa:** [beneficio real]
**Creada:** [fecha] | **Basada en:** [hito]
```

---

## SKILL-META02 | ACTUALIZAR SKILL EXISTENTE

1. Documentar qué falló o mejoró
2. Actualizar con marca: `v2.0 — [fecha]`
3. Dejar nota de qué cambió y por qué

---

# REGISTRO DE SKILLS

| Código | Nombre | Tipo | Versión | Fecha |
|--------|--------|------|---------|-------|
| SKILL-T01 | Control+F First | Técnica | 1.0 | 2026-04-08 |
| SKILL-T02 | Bloques Siempre Completos | Técnica | 1.0 | 2026-04-08 |
| SKILL-T03 | Plan Antes de Código | Técnica | 1.0 | 2026-04-08 |
| SKILL-T04 | Separación de Archivos | Técnica | 2.0 | 2026-04-11 |
| SKILL-T05 | Nomenclatura de Módulos | Técnica | 2.0 | 2026-04-11 |
| SKILL-T06 | Checklist de Prueba | Técnica | 1.0 | 2026-04-08 |
| SKILL-T07 | Investigar Antes de Inventar | Técnica | 1.0 | 2026-04-08 |
| SKILL-T08 | Seguridad Estructural | Técnica | 1.0 | 2026-04-08 |
| SKILL-T09 | Gestión de Memoria Supabase | Técnica | 1.0 | 2026-04-10 |
| SKILL-T10 | Resolver Conflictos Git | Técnica | 1.0 | 2026-04-11 |
| SKILL-T11 | Subida Masiva REST API | Técnica | 1.0 | 2026-04-11 |
| SKILL-C01 | Ojo Comercial Paralelo | Comercial | 1.0 | 2026-04-08 |
| SKILL-C02 | Benchmark Precios | Comercial | 1.0 | 2026-04-08 |
| SKILL-C03 | Cierre con Valor Comercial | Comercial | 1.0 | 2026-04-08 |
| SKILL-C04 | Verticales CREACTIVE OS | Comercial | 1.0 | 2026-04-11 |
| SKILL-M01 | Crear Nueva Skill | Meta | 1.0 | 2026-04-08 |
| SKILL-M02 | Actualizar Skill | Meta | 1.0 | 2026-04-08 |
