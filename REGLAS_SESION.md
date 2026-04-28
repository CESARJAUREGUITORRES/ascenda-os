# REGLAS DE SESIÓN — ASCENDAOS
## Lo que debe pasar SIEMPRE antes de escribir una línea de código
### Actualizado: 27/04/2026

---

## 1. AL INICIAR SESIÓN

### 1A — Leer el transcript anterior
```
Antes de responder CUALQUIER cosa, leer /mnt/transcripts/ para entender:
- Qué se hizo en la última sesión
- Qué quedó pendiente
- Qué bugs se reportaron
```

### 1B — Verificar estado de producción
```bash
# ¿Railway está arriba?
curl -s -o /dev/null -w "%{http_code}" https://ascenda-os-production.up.railway.app/app

# ¿Qué versión está en producción?
curl -s https://ascenda-os-production.up.railway.app/app.html | grep '_APP_VERSION'

# ¿Hay RPCs duplicadas?
SELECT proname, count(*) FROM pg_proc 
WHERE proname LIKE 'aos_%' GROUP BY proname HAVING count(*) > 1;
```

### 1C — Listar lo que NO se toca
Hacer una lista explícita de funcionalidades que FUNCIONAN y que NO se van a modificar en esta sesión. César debe aprobar esta lista.

---

## 2. ANTES DE CADA CAMBIO

### 2A — Declarar intención
Decirle a César EXACTAMENTE:
- Qué archivo voy a tocar
- Qué función voy a modificar
- Qué otras funciones llaman a esa función (grep)
- Qué podría romperse

### 2B — Medir impacto con grep
```bash
# Antes de tocar la función X, buscar QUIÉN la llama:
grep -rn 'nombreFuncion' app/public/*.html app/public/*.js

# Antes de tocar una RPC, buscar QUIÉN la llama:
grep -rn 'nombre_rpc' app/public/*.html app/public/*.js
```

### 2C — César aprueba
NO escribir código hasta que César diga "procede" o "dale".

---

## 3. AL ESCRIBIR CÓDIGO

### 3A — Supabase RPCs
```sql
-- SIEMPRE eliminar TODAS las versiones antes de crear:
DROP FUNCTION IF EXISTS nombre(text);
DROP FUNCTION IF EXISTS nombre(text, date, date);
DROP FUNCTION IF EXISTS nombre(text, date, date, text);
-- Luego crear la nueva:
CREATE OR REPLACE FUNCTION nombre(...)

-- DESPUÉS de crear, verificar que es única:
SELECT proname, proargnames FROM pg_proc WHERE proname = 'nombre';
-- Debe devolver EXACTAMENTE 1 fila
```

### 3B — JavaScript
```javascript
// SIEMPRE guard null en getElementById:
var el = document.getElementById('x');
if(el) el.style.display = 'none';

// SIEMPRE guard doble-submit:
if(STATE._guardando) return;
STATE._guardando = true;
// ... acción ...
// En TODOS los caminos (then, catch, else):
STATE._guardando = false;

// SIEMPRE try-catch en funciones que abren overlays:
function abrirAlgo() {
  try {
    // ... código ...
    abrirOv('ov-nombre');
  } catch(e) {
    console.error(e);
    cerrarOv('ov-nombre');
    toast('Error', 'err');
  }
}
```

### 3C — NO hacer
- NO cambiar la firma de una RPC sin eliminar la vieja
- NO agregar parámetros nuevos a RPCs existentes (crear una nueva con otro nombre)
- NO tocar funciones que no están relacionadas con el bug actual
- NO "mejorar" o "limpiar" código que funciona
- NO hacer más de 1 fix por commit

---

## 4. ANTES DE PUSH

### 4A — Checklist obligatorio
```bash
# 1. Verificar sintaxis de TODOS los archivos modificados:
node --check archivo.js
node -e "new Function(require('fs').readFileSync('archivo.html','utf8').match(/<script>([\s\S]*?)<\/script>/)[1])"

# 2. Verificar que no hay RPCs duplicadas:
SELECT proname, count(*) FROM pg_proc WHERE proname = 'NOMBRE_RPC';
-- Debe ser 1

# 3. Verificar que RLS está deshabilitado en tablas nuevas:
SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'TABLA_NUEVA';
-- relrowsecurity debe ser false

# 4. Verificar que solo se modificaron los archivos necesarios:
git diff --name-only
-- Solo debe listar los archivos del cambio actual
```

### 4B — Commit message claro
```
tipo: descripción corta

QUÉ CAMBIÉ:
- Archivo X: función Y — razón

QUÉ VERIFIQUÉ:
- RPCs únicas: ✅
- Sintaxis: ✅
- Impacto en otros archivos: ninguno

QUÉ NO TOQUÉ:
- Lista de archivos que no se modificaron
```

---

## 5. DESPUÉS DE PUSH

### 5A — Esperar deploy
```bash
# Esperar 60 segundos, luego verificar:
sleep 60
curl -s https://ascenda-os-production.up.railway.app/ARCHIVO | grep 'TEXTO_NUEVO'
```

### 5B — Decirle a César qué probar
Instrucciones EXACTAS paso a paso:
1. Recarga la página con Ctrl+Shift+R
2. Ve a [panel específico]
3. Haz [acción específica]
4. Deberías ver [resultado esperado]
5. Si ves [resultado incorrecto], es [tal problema]

### 5C — Esperar confirmación
NO pasar al siguiente cambio hasta que César confirme que funciona.

---

## 6. FLUJO CLÍNICO — PUNTOS DE VERIFICACIÓN

Después de CUALQUIER cambio en agenda.js, attendance.html, o caja.html, verificar mentalmente que estos 10 puntos siguen funcionando:

```
□ 1. Crear cita en Agenda → aparece en la lista
□ 2. Poner Asistió + seleccionar enfermero → solo enfermeros en dropdown
□ 3. Guardar → atención se crea (1 sola, no duplicada)
□ 4. Paciente aparece en panel de la enfermera
□ 5. Triaje → signos vitales + NEWS2 → guarda en Supabase
□ 6. Plan de trabajo → buscar + agregar → guarda sin duplicar
□ 7. Caja → detecta plan → muestra precio y sesiones correctos
□ 8. Grabar venta → nombre correcto, monto correcto, estado correcto
□ 9. Paciente NO desaparece del panel enfermera después de pagar
□ 10. Procedimiento → solo muestra tratamientos pagados
```

Si el cambio que estoy haciendo PODRÍA afectar alguno de estos puntos, DECIRLE A CÉSAR antes de hacer el cambio.

---

## 7. ERRORES FATALES — NUNCA REPETIR

### ERROR 1: RPC duplicada (ventas no se graban)
- Causa: CREATE sin DROP previo
- Síntoma: la venta "se graba" pero no aparece
- Prevención: SIEMPRE DROP antes de CREATE + verificar count=1

### ERROR 2: Script cacheado (código viejo en navegador)
- Causa: agenda.js/caja.html se cachea sin cache-buster
- Síntoma: el fix está en el servidor pero el navegador usa la versión vieja
- Prevención: incrementar _APP_VERSION en app.html cada vez que se modifica un .js

### ERROR 3: Atención duplicada/fantasma
- Causa: PATCH cuando debería ser DELETE+CREATE
- Síntoma: paciente aparece 2 veces o no aparece
- Prevención: patrón delete-then-create para atenciones

### ERROR 4: Pantalla azul (overlay sin contenido)
- Causa: getElementById retorna null, JS crashea, overlay queda abierto
- Síntoma: pantalla azul, no se puede cerrar
- Prevención: try-catch + click-outside-to-close en TODOS los overlays

### ERROR 5: "CLIENTE DIRECTO" en ventas
- Causa: VT.pac no tiene los campos esperados
- Síntoma: la venta se graba sin nombre del paciente
- Prevención: verificar pac.numero || pac.numero_limpio || pac.celular

### ERROR 6: Estado PAGO COMPLETO cuando fue ADELANTO
- Causa: lógica de comparación incorrecta en el frontend
- Síntoma: venta con saldo aparece como pagada
- Prevención: verificar monto_pagado vs monto_total, no conteo de items

---

## 8. REGLA DE ORO

> Si no estoy 100% seguro de que mi cambio no rompe nada,
> NO lo hago. Le pregunto a César primero.
> Es mejor preguntar 10 veces que romper 1 vez.
