# PROTOCOLO DE DESARROLLO ASCENDAOS
## Reglas, Fases y Checklist para Desarrollo Seguro
### Versión 1.0 — 27/04/2026

---

## CONTEXTO DEL PROBLEMA

El 27 de abril de 2026 se perdió un día completo de trabajo por errores en cascada:
- Fixes que rompían funcionalidades existentes
- RPCs duplicadas en Supabase que causaban fallos silenciosos
- Scripts cacheados que no se actualizaban en el navegador
- Cambios en múltiples archivos sin verificar el flujo completo

Este documento establece las reglas para que esto NO vuelva a pasar.

---

## REGLAS INNEGOCIABLES

### R1 — NO TOCAR LO QUE FUNCIONA
Si algo opera correctamente en producción, NO se modifica a menos que César lo pida explícitamente. "Mejorar" código que funciona está PROHIBIDO.

### R2 — UN CAMBIO A LA VEZ
- Hago UN fix o UNA funcionalidad
- Push a producción
- César confirma que funciona
- RECIÉN paso al siguiente
- NUNCA "arreglo 5 cosas de una vez"

### R3 — AUDITAR ANTES DE TOCAR
Antes de modificar CUALQUIER función:
1. Leer la función completa
2. Buscar qué otras funciones la llaman (grep)
3. Listar el impacto en otros archivos
4. Informar a César antes de editar

### R4 — DROP ANTES DE CREATE EN SUPABASE
```sql
-- SIEMPRE hacer esto:
DROP FUNCTION IF EXISTS nombre_funcion(tipos_parametros);
CREATE OR REPLACE FUNCTION nombre_funcion(...)
```
NUNCA crear una función sin eliminar las versiones anteriores. Las RPCs duplicadas causan fallos silenciosos.

### R5 — VERIFICAR SINTAXIS ANTES DE PUSH
```bash
node --check archivo.js
# Para HTML con script embebido:
node -e "var h=require('fs').readFileSync('archivo.html','utf8');var m=h.match(/<script>([\s\S]*?)<\/script>/);new Function(m[1]);"
```

### R6 — VERIFICAR DEPLOY ANTES DE CONFIRMAR
```bash
# Esperar deploy y verificar que el código nuevo está en producción
curl -s https://ascenda-os-production.up.railway.app/ARCHIVO | grep 'TEXTO_NUEVO'
```

### R7 — NO ASUMIR QUE FUNCIONA
Después de cada push, verificar:
- ¿La RPC existe y es única? (SELECT count(*) FROM pg_proc WHERE proname = 'xxx')
- ¿El código llegó al servidor? (curl + grep)
- ¿El navegador tiene la versión nueva? (_APP_VERSION)

### R8 — CACHE-BUSTER SIEMPRE
Todos los scripts externos se cargan con `?v=_APP_VERSION`. Al hacer cambios en .js, incrementar _APP_VERSION en app.html.

### R9 — GUARD CONTRA NULL EN TODO getElementById
```javascript
// MAL:
document.getElementById('x').style.display = 'none';

// BIEN:
var el = document.getElementById('x');
if(el) el.style.display = 'none';
```

### R10 — GUARD CONTRA DOBLE-SUBMIT EN TODA ACCIÓN
```javascript
if(STATE._guardando) return;
STATE._guardando = true;
// ... hacer la acción ...
STATE._guardando = false; // en TODOS los caminos (éxito, error, catch)
```

---

## FASES DE TRABAJO POR SESIÓN

### FASE 1 — ACTIVACIÓN (5 min)
1. César dice qué proyecto y qué tarea
2. Leo el transcript de la sesión anterior
3. Verifico el estado actual de producción
4. Listo lo que está funcionando (NO TOCAR)
5. Listo lo que hay que hacer

### FASE 2 — PLANIFICACIÓN (5 min)
1. Presento el plan con pasos numerados
2. Para cada paso: archivos que se tocan + impacto
3. César aprueba o ajusta
4. NO empiezo a codificar hasta que César apruebe

### FASE 3 — EJECUCIÓN (por paso)
Para CADA paso del plan:
1. Audito el código existente (grep + view)
2. Hago el cambio mínimo necesario
3. Verifico sintaxis
4. Push
5. Verifico deploy
6. César prueba
7. César confirma → paso siguiente
8. César reporta error → diagnostico y corrijo SOLO eso

### FASE 4 — CIERRE (5 min)
1. Lista de lo completado con ✅
2. Lista de lo pendiente
3. Datos de prueba limpiados si aplica
4. SESSION_LOG para el repo
5. Contexto para la próxima sesión

---

## CHECKLIST PRE-PUSH

Antes de CADA `git push`, verificar:

- [ ] ¿Toqué SOLO los archivos necesarios para este cambio?
- [ ] ¿Verifiqué sintaxis de TODOS los archivos modificados?
- [ ] ¿Hice DROP de RPCs viejas antes de CREATE?
- [ ] ¿Verifiqué que no hay RPCs duplicadas en Supabase?
- [ ] ¿Puse guards null en todo getElementById nuevo?
- [ ] ¿Puse guard doble-submit en toda acción de guardar?
- [ ] ¿Incrementé _APP_VERSION si modifiqué archivos .js?
- [ ] ¿El cambio rompe alguna otra funcionalidad? (grep dependencias)

---

## CHECKLIST POST-PUSH

Después de CADA `git push`, verificar:

- [ ] ¿Railway desplegó? (esperar ~60 seg)
- [ ] ¿El código nuevo está en el servidor? (curl + grep)
- [ ] ¿Las RPCs son únicas? (SELECT count FROM pg_proc)
- [ ] ¿RLS está deshabilitado en tablas nuevas?

---

## ARCHIVOS CRÍTICOS — IMPACTO ALTO

Estos archivos afectan múltiples flujos. Modificar con extremo cuidado:

| Archivo | Impacto | Qué puede romperse |
|---------|---------|---------------------|
| app.html | TODO el sistema | Login, navegación, auto-reload, estados |
| agenda.js | Citas + Atenciones | Flujo Asistió→Panel enfermera |
| attendance.html | Flujo clínico completo | Triaje, evaluación, plan, procedimiento |
| caja.html | Ventas + Pagos | Cotizaciones, ventas, comisiones |
| admin-home.html | Panel admin | Monitoreo, alertas, KPIs |

### Regla especial para estos archivos:
- Leer el archivo COMPLETO antes de editar
- Buscar TODAS las funciones que se llaman entre sí
- Probar mentalmente el flujo completo después del cambio

---

## FLUJO CLÍNICO — NO ROMPER

```
AGENDA (Nueva cita)
  ↓
AGENDA (Asistió + seleccionar enfermero)
  ↓ [Crea atención en aos_atenciones]
  ↓ [Selector muestra SOLO enfermeros]
PANEL ENFERMERA (Mis Atenciones)
  ↓ [Paciente aparece en la lista]
TRIAJE
  ↓ [Signos vitales + NEWS2 + IMC]
  ↓ [Guarda en aos_notas_clinicas]
EVALUACIÓN
  ↓ [Preguntas + conclusión]
  ↓ [Guarda en aos_notas_clinicas]
PLAN DE TRABAJO
  ↓ [Buscar catálogo + agregar items]
  ↓ [Guarda en aos_planes_trabajo + aos_plan_trabajo_items + aos_notas_clinicas]
  ↓ [NO se duplica al guardar 2 veces]
CAJA
  ↓ [Detecta plan → badge "Plan disponible"]
  ↓ [Modal muestra tratamientos con precio y sesiones correctos]
  ↓ [Venta se graba con nombre, monto, estado correctos]
  ↓ [ADELANTO si pagó parcial, PAGO COMPLETO si pagó todo]
  ↓ [Paciente NO desaparece del panel enfermera después de pagar]
PROCEDIMIENTO
  ↓ [Solo muestra tratamientos PAGADOS]
  ↓ [Chips clickeables por tratamiento]
  ↓ [Programar para otro día → crea cita futura]
  ↓ [Realizado → marca plan_item como COMPLETADO]
```

Cada paso de este flujo DEBE funcionar después de cualquier cambio.

---

## ERRORES COMUNES Y CÓMO EVITARLOS

### Error: "CLIENTE DIRECTO" en ventas
- Causa: pac.numero no existe en el objeto del paciente
- Fix: usar pac.numero || pac.celular || pac.numero_limpio
- Prevención: SIEMPRE verificar qué campos tiene VT.pac antes de grabar

### Error: Pantalla azul (overlay sin contenido)
- Causa: getElementById retorna null → crash → overlay abierto sin contenido
- Fix: try-catch en toda función que abre overlay + click-outside-to-close
- Prevención: R9 — guard null en todo getElementById

### Error: Venta duplicada
- Causa: sin guard doble-submit, botón se presiona 2 veces
- Fix: VT._guardando = true antes de grabar
- Prevención: R10 — guard doble-submit en toda acción

### Error: RPC falla silenciosamente
- Causa: 2 funciones con el mismo nombre pero diferentes parámetros
- Fix: DROP FUNCTION IF EXISTS antes de CREATE
- Prevención: R4 — DROP antes de CREATE

### Error: Script cacheado (código viejo en el navegador)
- Causa: app.html cacheaba scripts sin recargar
- Fix: cache-buster con ?v=_APP_VERSION
- Prevención: R8 — cache-buster siempre

### Error: Paciente desaparece del panel enfermera
- Causa: la CTE de la RPC excluía pacientes con ventas
- Fix: no excluir consultas por ventas
- Prevención: R3 — auditar impacto antes de tocar RPCs

---

## CÓMO REPORTAR UN BUG (para César)

Para que pueda diagnosticar rápido:
1. **Qué hiciste** (paso a paso)
2. **Qué esperabas** que pasara
3. **Qué pasó** realmente
4. **Screenshot** de la pantalla
5. **Screenshot de F12 → Console** (si hay errores rojos)

---

## COMPROMISO

Este protocolo existe para proteger el trabajo de César y su equipo.
Cada regla nació de un error real que causó problemas reales.
No hay excusa para repetir los mismos errores.
