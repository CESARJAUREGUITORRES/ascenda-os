---
name: skill-session-manager
description: Protocolo completo para iniciar y cerrar sesiones de trabajo en AscendaOS con Claude. Usar al comenzar cualquier sesión de desarrollo o al finalizarla. Garantiza contexto completo en 2 mensajes, ahorro máximo de tokens, y que ningún conocimiento se pierda entre sesiones.
---

# Session Manager — AscendaOS / CREACTIVE OS

## PROTOCOLO DE INICIO DE SESIÓN

### Mensaje de inicio estándar (copiar y pegar):
```
NUEVO CHAT. Activa el Ultra Prompt.
Consulta el estado del proyecto en Supabase:
- SELECT * FROM aos_memory ORDER BY categoria
- SELECT nombre, tipo, LENGTH(contenido) as chars FROM aos_codigo_fuente ORDER BY tipo, nombre
Proyecto: ituyqwstonmhnfshnaqz
Continuamos el desarrollo de AscendaOS v1.
```

### Lo que Claude hace al recibir ese mensaje:
```
1. Lee aos_memory → obtiene TODO el contexto del proyecto
2. Lee inventario de aos_codigo_fuente → sabe qué archivos existen
3. Identifica pendientes activos de la sesión anterior
4. Está listo para trabajar SIN que expliques nada más
```

### Credenciales activas (en aos_memory):
```
Supabase ID:       ituyqwstonmhnfshnaqz
Supabase anon:     aos_memory → supabase_anon_key
Supabase service:  aos_memory → supabase_service_key
GitHub token:      aos_memory → github_token
GitHub repo:       CESARJAUREGUITORRES/ascenda-os
Sheet ID:          1rtl0SxBjck4gXM-ahj_aVudzi1NDoOpk29JbwI95jKM
```

## PROTOCOLO DE CIERRE DE SESIÓN (/sesion-cierre)

### Paso 1 — Registrar la sesión en historial
```sql
INSERT INTO aos_memory (categoria, clave, valor) VALUES
('HISTORIAL_SESIONES', 'ses_XXX', 
 'SES-XXX YYYY-MM-DD: [resumen en 2 líneas de qué se hizo y qué quedó pendiente]');
```

### Paso 2 — Actualizar estados completados
```sql
UPDATE aos_memory SET valor = 'v2.0 COMPLETADO — [descripción]', updated_at = NOW()
WHERE clave = 'estado_[modulo]';
```

### Paso 3 — Actualizar pendientes
```sql
-- Resolver completados
DELETE FROM aos_memory WHERE clave = 'pend_X' AND valor LIKE '%ya resuelto%';

-- Agregar nuevos pendientes detectados
INSERT INTO aos_memory (categoria, clave, valor) VALUES
('PENDIENTE', 'pend_nuevo', 'Descripción del nuevo pendiente detectado');
```

### Paso 4 — Capturar insights del día
```sql
INSERT INTO aos_memory (categoria, clave, valor) VALUES
('INSIGHTS', 'ins_XXX_[tema]', 'INSIGHT: descripción del aprendizaje o idea capturada');
```

### Paso 5 — Detectar y crear skills nuevas
```
¿Se resolvió un problema de forma elegante que volverá a aparecer?
→ Crear SKILL.md en /docs/skills/skill-[nombre]/
→ Subir a GitHub
→ Registrar en SKILLS.md
```

### Paso 6 — Sincronizar GitHub
```python
# Claude hace push directo con el token
# de todos los archivos actualizados en Supabase
# Commit message: "sess(YYYY-MM-DD): [descripción corta]"
```

## FLUJO DE TRABAJO DURANTE LA SESIÓN

### Para editar código (parche mínimo):
```
1. Claude lee el archivo desde aos_codigo_fuente (no pedir al usuario)
2. Identifica el cambio mínimo necesario
3. Actualiza en Supabase via REST API
4. Hace push a GitHub
5. Informa a César: "Actualicé [archivo]. Copia el contenido de 
   Supabase y pega en Apps Script, luego despliega."
```

### Para código nuevo:
```
1. T-01 Arquitecto define estructura
2. T-02 Dev escribe el código
3. T-04 Seguridad revisa
4. Se sube a Supabase + GitHub
5. César despliega en Apps Script
```

### Para diagnosticar problemas:
```
1. Claude lee los archivos relevantes desde Supabase
2. Auditoría con semáforo 🟢🟡🔴⚫
3. Propone parche mínimo
4. NO reescribir módulos completos que funcionan
```

## REGLAS DE AHORRO DE TOKENS

```
✅ Claude lee código de Supabase (no pedir que lo pegues)
✅ Solo parches mínimos en el chat, no archivos completos
✅ Una sola pregunta por mensaje cuando necesites aclaraciones
✅ Contexto completo viene de aos_memory, no del chat

❌ No pegar bloques grandes de código en el chat
❌ No re-explicar el proyecto al inicio de sesión
❌ No copiar/pegar código que ya está en Supabase
```

## ESTRUCTURA DE CARPETAS GITHUB

```
ascenda-os/
  src/
    backend/   ← 29 archivos GS_*.gs
    frontend/  ← 20 archivos View*.html
  docs/
    adn/       ← SOUL.md, AGENTS.md, SKILLS.md, ULTRAPROMPMT_MAESTRO.md
    skills/    ← skill-gas-developer/, skill-supabase-architect/, etc.
    MEMORY.md, DOC_PROYECTO_ASCENDAOS.md, ROADMAP_ASCENDAOS.md
  .github/
    workflows/ ← sync-supabase.yml (corre cada hora)
```

## CATEGORÍAS DE aos_memory (referencia rápida)

```
PROYECTO          → IDs, URLs, stack, operador
EQUIPO            → credenciales de asesores y sedes
ARQU              → decisiones de arquitectura activas
ESTADO            → versión actual de cada módulo
FLUJO_TRABAJO     → protocolos de trabajo aprobados
REGLAS            → reglas no negociables del sistema
PENDIENTE         → tareas pendientes priorizadas
HISTORIAL_SESIONES → log de cada sesión de trabajo
DECISIONES_ARQ    → DA-01 a DA-XX con fecha y razón
CREACTIVE_OS      → visión empresa, verticales, filosofía
AGENTES           → resumen de los 10 agentes del sistema
ROADMAP_BLOQUES   → estado de bloques de desarrollo
RAILWAY_GITHUB    → plan de migración futura
INSIGHTS          → aprendizajes y ideas capturadas
SESION_A/B_PLAN   → planes de sesiones específicas
```

## SEÑALES DE QUE LA SESIÓN FUE EXITOSA

```
✅ ao_memory actualizado con el log de la sesión
✅ Archivos modificados subidos a Supabase
✅ Push a GitHub con commit descriptivo
✅ Pendientes resueltos marcados / nuevos registrados
✅ Al menos 1 insight capturado
✅ César puede arrancar la próxima sesión con 1 mensaje
```

## SEÑAL DE QUE ALGO SALIÓ MAL

```
⚠️ Hay código en el chat pero no en Supabase
⚠️ La sesión terminó sin actualizar aos_memory
⚠️ No hay commit en GitHub de los cambios del día
⚠️ César tiene que re-explicar contexto en la siguiente sesión
```
