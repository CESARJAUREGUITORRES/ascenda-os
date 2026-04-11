---
name: skill-supabase-architect
description: Patrones, convenciones y arquitectura de Supabase para AscendaOS / CREACTIVE OS. Usar cuando se diseñen tablas, funciones SQL, triggers, o integraciones browser→Supabase. Garantiza consistencia con las 24 tablas aos_* existentes y el modelo multi-tenant futuro.
---

# Supabase Architect — AscendaOS

## PROYECTO
- **ID:** `ituyqwstonmhnfshnaqz`
- **URL:** `https://ituyqwstonmhnfshnaqz.supabase.co`
- **Anon key:** en `aos_memory.supabase_anon_key` (para browser)
- **Service key:** en `aos_memory.supabase_service_key` (solo backend/scripts)

## CONVENCIÓN DE NOMBRES

```sql
-- Tablas: prefijo aos_ + nombre en snake_case
aos_leads, aos_llamadas, aos_ventas, aos_agenda
aos_pacientes, aos_asesores, aos_comisiones
aos_memoria, aos_codigo_fuente  -- tablas del sistema

-- Funciones RPC: prefijo aos_ + verbo_sustantivo
aos_kpis_dashboard(p_fecha_ini, p_fecha_fin, p_asesor)
aos_panel_asesor(p_asesor, p_id, p_hoy)
aos_semaforo_equipo(p_hoy)
aos_comisiones_asesor(p_asesor, p_id, p_mes, p_anio)
aos_seguimientos_asesor(p_asesor, p_id, p_hoy)
aos_cerrar_estado_abierto(p_id)

-- Triggers: trg_ + acción + tabla
trg_refresh_llammap
trg_sync_paciente_venta
```

## ARQUITECTURA DE LECTURA (BROWSER DIRECTO)

```javascript
// Cliente en AppShell.html — expuesto globalmente
var _SB = {
  url: 'https://ituyqwstonmhnfshnaqz.supabase.co',
  key: '[anon_key]'  // publishable — OK en frontend
};

// Usar siempre estas 3 funciones:
window.sb_rpc(fn, params)     // llama función SQL → POST /rest/v1/rpc/fn
window.sb_fetch(path, opts)   // request directo con headers auth
window.sb_get(table, params)  // query tabla con filtros

// Expuestos también como:
window.AOS_sbRpc(fn, params)
window.AOS_sbFetch(path, opts)
window.AOS_sbGet(table, params)
```

## PATRÓN DE RPC FUNCTION

```sql
-- Siempre: SECURITY DEFINER + SET search_path
CREATE OR REPLACE FUNCTION aos_mi_funcion(
  p_param1 TEXT,
  p_param2 DATE DEFAULT CURRENT_DATE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_resultado JSON;
BEGIN
  -- lógica aquí
  SELECT json_build_object(
    'ok', true,
    'data', array_agg(row_to_json(t))
  ) INTO v_resultado
  FROM (SELECT ...) t;
  
  RETURN v_resultado;
END;
$$;
```

## REGLA CRÍTICA — NUNCA DELETE EN TRIGGERS

```sql
-- ❌ PROHIBIDO — puede borrar datos de producción
CREATE TRIGGER trg_sync
AFTER INSERT ON aos_leads
FOR EACH ROW EXECUTE FUNCTION sync_con_delete();

-- ✅ CORRECTO — solo INSERT/UPDATE
CREATE OR REPLACE FUNCTION sync_seguro()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO aos_destino (...) VALUES (...)
  ON CONFLICT (clave) DO UPDATE SET ... ;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## TRIGGERS ACTIVOS (no tocar sin auditoría)

```
trg_refresh_llammap        → actualiza mapa de llamadas
trg_sync_paciente_venta    → sincroniza paciente cuando hay venta
trg_sync_paciente_contacto → ELIMINADO (causaba error) — no recrear
```

## TABLAS ESPECIALES DEL SISTEMA

```sql
-- aos_memory: memoria viva del proyecto
-- campos: id, categoria, clave, valor, updated_at
-- categorías activas: PROYECTO, EQUIPO, ARQU, ESTADO, 
--   FLUJO_TRABAJO, REGLAS, PENDIENTE, HISTORIAL_SESIONES,
--   DECISIONES_ARQ, CREACTIVE_OS, AGENTES, ROADMAP_BLOQUES,
--   RAILWAY_GITHUB, INSIGHTS, SESION_A_COMPLETA, SESION_B_PLAN

-- aos_codigo_fuente: espejo del código del proyecto
-- campos: id, nombre, tipo (gs/html/md), contenido, updated_at
-- 56 archivos: 29 gs + 20 html + 7 md
```

## MODELO MULTI-TENANT (pendiente implementar)

```sql
-- Tabla central de tenants
CREATE TABLE aos_tenants (
  id          SERIAL PRIMARY KEY,
  nombre      TEXT NOT NULL,
  vertical    TEXT NOT NULL, -- clinic, nails, legal, psych, barber, ecommerce
  plan        TEXT DEFAULT 'starter', -- starter, growth, scale
  activo      BOOLEAN DEFAULT true,
  demo        BOOLEAN DEFAULT false,
  creado_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Zi Vital = tenant_id = 1 (ya existe implícitamente)
-- Demo = tenant_id = 99
-- Nuevo cliente = nuevo INSERT

-- Migración futura: agregar tenant_id a tablas principales
ALTER TABLE aos_leads ADD COLUMN tenant_id INT DEFAULT 1;
ALTER TABLE aos_pacientes ADD COLUMN tenant_id INT DEFAULT 1;
-- etc.
```

## UPSERTAR VÍA REST API (Python/scripts)

```python
import json, urllib.request

def upsert_supabase(tabla, payload, conflict_col='nombre'):
    SUPABASE_URL = "https://ituyqwstonmhnfshnaqz.supabase.co"
    SERVICE_KEY = "[service_key]"  # nunca en frontend
    
    data = json.dumps(payload).encode('utf-8')
    url = f"{SUPABASE_URL}/rest/v1/{tabla}?{conflict_col}=eq.{payload[conflict_col]}"
    
    req = urllib.request.Request(url, data=data, method='PATCH',
        headers={
            'apikey': SERVICE_KEY,
            'Authorization': f'Bearer {SERVICE_KEY}',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
        })
    with urllib.request.urlopen(req) as r:
        return r.status  # 204 = OK
```

## TABLA aos_tabla_comisiones (activa)

```sql
-- Rangos reales migrados desde Google Sheets de Zi Vital
-- Estructura: asesor, rango_min, rango_max, porcentaje
-- Consultar vía: aos_comisiones_asesor(p_asesor, p_id, p_mes, p_anio)
```

## PERFORMANCE

```
Lectura directa browser → Supabase RPC: ~200-400ms
GAS intermediario → Supabase: +1-3s overhead por request
Solución implementada: sb_rpc() directo en todos los paneles migrados
Paneles migrados: ViewAdvisorFollowups, ViewAdminHome, 
                  ViewAdvisorCommissions, ViewAdvisorCalls
Pendientes migrar: ViewAdminMarketing
```
