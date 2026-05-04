# LECCIONES DE 1,000 COMMITS — ASCENDA OS
## Lo que aprendimos, lo que mejorar, y las nuevas reglas

**Fecha:** 3 mayo 2026
**Commits:** 1,000 | **Sesiones:** ~35 | **Líneas de código:** 28,081
**Tablas Supabase:** 161 | **Archivos frontend:** 52

---

## DATOS REALES DEL PROYECTO

```
192 features (19.2%)
204 fixes (20.4%)
17 refactors/audits (1.7%)
~587 cambios incrementales (58.7%)
```

**Insight #1:** Por cada feature, hubo 1.06 fixes. Esto significa que casi la mitad del trabajo fue corregir cosas que se rompieron. 

**Insight #2:** Solo 1.7% del trabajo fue auditoría/refactor. Esto es muy bajo — debería ser al menos 10%.

**Insight #3:** Los 10 archivos más editados (app.html con 134 ediciones) muestran que concentramos mucho en pocos archivos. Esto genera fragilidad.

---

## LOS 7 ERRORES RECURRENTES QUE DETECTAMOS

### 1. CONSTRUIR SIN AUDITAR PRIMERO
**Patrón:** Agregar funcionalidad nueva → romper algo existente → fix urgente.
**Ejemplo:** El cron scheduler se construyó sin anti-duplicados. Luego hubo que hacer fix urgente.
**Regla nueva:** SIEMPRE auditar el estado actual antes de agregar código nuevo. Si no hay auditoría previa, no hay código nuevo.

### 2. FUNCIONES SIN CATCH / SIN NULL GUARD
**Patrón:** fetch() sin .catch(), getElementById sin verificar null.
**Ejemplo:** 6 fetch sin catch detectados en auditoría de Studio.
**Regla nueva:** TODO fetch lleva .catch(). TODO getElementById se verifica con null guard. Sin excepciones.

### 3. ESTADOS INCOMPLETOS EN BD
**Patrón:** Agregar un nuevo flujo pero no agregar los estados necesarios en el CHECK constraint.
**Ejemplo:** EN_PROCESO y ERROR_PUBLICACION no existían cuando se construyó el cron.
**Regla nueva:** Al crear cualquier flujo nuevo, listar TODOS los estados posibles ANTES de escribir código. Agregarlos al constraint inmediatamente.

### 4. ENDPOINTS EN ORDEN INCORRECTO EN SERVER
**Patrón:** Agregar endpoint después del "FIN" marker → el catch-all lo intercepta primero.
**Ejemplo:** /api/studio/connections devolvía login.html porque estaba después del marker.
**Regla nueva:** UN SOLO marker "FIN STUDIO API" al final de todos los endpoints. Nunca markers intermedios.

### 5. FECHAS HARDCODED
**Patrón:** Insertar datos con año específico (2026) que no funcionan al año siguiente.
**Ejemplo:** Fechas estacionales con año 2026 hardcoded.
**Regla nueva:** Toda fecha recurrente usa make_date() con EXTRACT(YEAR FROM CURRENT_DATE). Nunca años hardcoded.

### 6. DUPLICACIÓN DE LÓGICA
**Patrón:** La misma lógica de publicación existía en el endpoint Y en el cron.
**Ejemplo:** studioPublishToNetwork se creó para el cron pero el endpoint tenía su propia versión.
**Regla nueva:** Una función, un lugar. Si necesitas la misma lógica en 2 lugares, extráela a función compartida.

### 7. FALTA DE PREVIEW ANTES DE EJECUTAR
**Patrón:** Acciones destructivas o masivas sin confirmación visual.
**Ejemplo:** El lote de 30 imágenes se procesaba sin mostrar qué haría antes.
**Regla nueva:** Toda acción que afecte más de 1 registro muestra preview antes de ejecutar.

---

## NUEVAS REGLAS DE TRABAJO (v2.0)

### REGLA 1 — AUDITAR → PLANIFICAR → CONSTRUIR (nunca al revés)
```
ANTES de tocar cualquier archivo:
1. grep para verificar qué existe
2. Contar funciones y líneas actuales
3. Verificar IDs, onclick, fetch/catch
4. Solo entonces planificar el cambio
```

### REGLA 2 — SYNTAX CHECK DESPUÉS DE CADA EDICIÓN
```
Después de CADA str_replace:
- node -c server.js (si se tocó server)
- new Function(js) para cada .html
- Nunca acumular 3+ ediciones sin check
```

### REGLA 3 — DROP + CREATE para RPCs, COUNT = 1
```
- Toda RPC nueva: CREATE OR REPLACE
- Verificar que no existe duplicada ANTES
- Después: SELECT count(*) WHERE routine_name = 'nombre'
```

### REGLA 4 — UN COMMIT = UN CAMBIO CONCEPTUAL
```
NO: 5 features + 3 fixes en un solo commit
SÍ: 1 feature completa con su fix incluido
Excepción: commits de auditoría pueden incluir múltiples fixes
```

### REGLA 5 — CADA TABLA NUEVA = VERIFICAR DEFAULTS + CONSTRAINTS
```
Al crear tabla:
- id text DEFAULT gen_random_uuid()::text (nunca sin default)
- CHECK constraints para todos los campos de estado
- created_at timestamptz DEFAULT now()
- Verificar que el INSERT no falle silenciosamente
```

### REGLA 6 — CADA ENDPOINT NUEVO = VERIFICAR ORDEN EN SERVER
```
- Todos los /api/studio/* van ANTES del catch-all de archivos
- UN SOLO marker "FIN STUDIO API"
- Probar con curl inmediatamente después de deploy
```

### REGLA 7 — FRONTEND: NULL GUARD OBLIGATORIO
```
Siempre:
  var el = $('id'); if(!el) return;
  
Nunca:
  $('id').innerHTML = '...';  // Puede explotar si no existe
```

### REGLA 8 — FETCH: SIEMPRE CON CATCH
```
Siempre:
  fetch(url).then(fn).catch(function(e){ console.error(e) });

Alternativa:
  safeFetch(url, opts).then(fn);
```

### REGLA 9 — DATOS DINÁMICOS, NUNCA HARDCODED
```
NO: INSERT VALUES ('2026-05-11', 'Día de la Madre')
SÍ: RPC que calcula make_date(EXTRACT(YEAR FROM CURRENT_DATE)::int, 5, 11)
```

### REGLA 10 — PREVIEW ANTES DE EJECUTAR
```
Toda acción que:
- Afecte más de 1 registro
- Publique a una red social
- Elimine datos
- Genere en lote

→ DEBE mostrar preview con datos concretos antes de ejecutar
```

### REGLA 11 — SESSION LOG AL CIERRE
```
Al cerrar sesión:
1. Contar commits de la sesión
2. Listar features + fixes
3. _APP_VERSION actualizada
4. Verificar Railway 200 OK
5. Listar PENDIENTES para siguiente sesión
```

### REGLA 12 — AUDITORÍA CADA 50 COMMITS
```
Cada 50 commits:
- Syntax check de TODOS los archivos
- Verificar que TODOS los onclick tienen función
- Verificar que TODOS los IDs referenciados existen
- Verificar que TODAS las RPCs funcionan
- Listar y corregir deuda técnica
```

---

## MÉTRICAS DE CALIDAD A MONITOREAR

| Métrica | Actual | Meta |
|---|---|---|
| Ratio fix/feature | 1.06 | < 0.5 |
| % auditorías | 1.7% | > 10% |
| Fetch sin catch | 6 | 0 |
| IDs huérfanos | 0 | 0 |
| RPCs verificadas | 100% | 100% |
| Deploy exitoso | 99%+ | 100% |

---

## PATRONES QUE FUNCIONARON BIEN

1. **Auditoría profunda con node -e**: Detectó errores que no se ven a simple vista
2. **Verificar con curl después de deploy**: Detectó el problema del endpoint connections
3. **Commits descriptivos**: Facilitan buscar qué se cambió y cuándo
4. **RPC SECURITY DEFINER**: Evita problemas de permisos con anon key
5. **_APP_VERSION como cache buster**: Garantiza que el usuario ve la versión actual
6. **Supabase Storage con bucket público**: Simplifica URLs de imágenes
7. **Cron con lock (EN_PROCESO)**: Evita publicaciones duplicadas
8. **Preview de lote antes de ejecutar**: Evita errores masivos

---

## LO QUE CAMBIÓ EN NUESTRO FLUJO DE TRABAJO

### ANTES (commits 1-500):
- Construir rápido → romper → fix urgente
- Sin auditoría previa
- Commits grandes con muchos cambios
- Sin null guards
- Sin catch en fetch

### AHORA (commits 500-1000):
- Auditar → planificar → construir → verificar
- Syntax check después de cada edición
- Commits más pequeños y descriptivos
- Null guards en todo
- Global error handler + catches

### PARA LOS PRÓXIMOS 1000:
- Ratio fix/feature < 0.5
- Auditoría cada 50 commits (automática)
- Tests básicos antes de cada deploy
- Zero fetch sin catch
- Zero IDs huérfanos
- Documentación inline mejorada
