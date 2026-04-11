---
name: skill-multitenant-builder
description: Protocolo para implementar arquitectura multi-tenant en AscendaOS sin romper el sistema actual de Zi Vital. Usar cuando se diseñe la tabla de tenants, se migre estructura existente, o se incorpore un nuevo cliente vertical. Garantiza que el ecosistema CREACTIVE OS sobreviva si un cliente desconecta.
---

# Multi-Tenant Builder — AscendaOS

## POR QUÉ EXISTE ESTE SKILL

AscendaOS nació como producto personalizado para Zi Vital. Si Zi Vital desconecta, actualmente el sistema muere con ellos — toda la estructura está acoplada a un solo cliente.

La visión es: **AscendaOS es el software madre. Zi Vital es el cliente piloto.**

El multi-tenant resuelve esto sin reescribir nada — se agrega una capa de aislamiento que permite que múltiples clientes usen la misma base de código con datos completamente separados.

## ESTRUCTURA DE TENANTS

```sql
-- Tabla central — crear en Supabase
CREATE TABLE aos_tenants (
  id           SERIAL PRIMARY KEY,
  slug         TEXT UNIQUE NOT NULL,    -- 'zi-vital', 'demo', 'clinica-abc'
  nombre       TEXT NOT NULL,
  vertical     TEXT NOT NULL,           -- ver lista abajo
  plan         TEXT DEFAULT 'starter',  -- starter, growth, scale
  activo       BOOLEAN DEFAULT true,
  demo         BOOLEAN DEFAULT false,
  config       JSONB DEFAULT '{}',      -- branding, colores, logo
  creado_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Verticales válidos:
-- clinic | nails | legal | psych | barber | ecommerce | generic

-- Datos iniciales
INSERT INTO aos_tenants (slug, nombre, vertical, plan, demo) VALUES
  ('zi-vital', 'Zi Vital', 'clinic', 'growth', false),
  ('demo-clinic', 'Demo Clínica', 'clinic', 'scale', true);
-- zi-vital = id 1 (el que ya existe implícitamente en todos los datos)
-- demo = id 2 (datos ficticios para mostrar a prospectos)
```

## MIGRACIÓN SIN ROMPER PRODUCCIÓN

**Principio:** No modificar tablas existentes mientras Zi Vital esté activo. Agregar `tenant_id` con valor DEFAULT 1 (= Zi Vital).

```sql
-- Fase 1: Agregar columna con default — NO rompe nada
ALTER TABLE aos_leads      ADD COLUMN IF NOT EXISTS tenant_id INT DEFAULT 1;
ALTER TABLE aos_pacientes  ADD COLUMN IF NOT EXISTS tenant_id INT DEFAULT 1;
ALTER TABLE aos_llamadas   ADD COLUMN IF NOT EXISTS tenant_id INT DEFAULT 1;
ALTER TABLE aos_ventas     ADD COLUMN IF NOT EXISTS tenant_id INT DEFAULT 1;
ALTER TABLE aos_agenda     ADD COLUMN IF NOT EXISTS tenant_id INT DEFAULT 1;
ALTER TABLE aos_asesores   ADD COLUMN IF NOT EXISTS tenant_id INT DEFAULT 1;

-- Todos los datos existentes quedan como tenant_id = 1 (Zi Vital)
-- Zi Vital nunca nota el cambio

-- Fase 2 (futuro): Foreign key y Row Level Security
ALTER TABLE aos_leads ADD CONSTRAINT fk_tenant 
  FOREIGN KEY (tenant_id) REFERENCES aos_tenants(id);

-- Fase 3 (cuando haya 2+ clientes): RLS policies
ALTER TABLE aos_leads ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON aos_leads
  USING (tenant_id = current_setting('app.tenant_id')::INT);
```

## REGLAS DE ORO MULTI-TENANT

```
R-MT-01: DEFAULT 1 en todas las columnas tenant_id
         → Zi Vital nunca nota la migración

R-MT-02: NUNCA filtrar por tenant en código GAS existente
         → Los filtros se agregan solo en nuevos módulos

R-MT-03: La demo (tenant_id = 2) tiene datos ficticios permanentes
         → Nunca borrarlos — son para mostrar a prospectos

R-MT-04: Si un cliente cancela → activo = false, datos se archivan
         → NUNCA delete de datos de un tenant

R-MT-05: Cada tenant tiene su config en JSONB
         → logo_url, color_primario, color_secundario, nombre_app
         → AscendaOS se "viste" con la marca del cliente
```

## ONBOARDING DE NUEVO CLIENTE

```
1. INSERT en aos_tenants (slug, nombre, vertical, plan)
2. Crear hoja en Google Sheets con estructura base
3. Configurar PropertiesService con SHEET_ID del nuevo cliente
4. Crear usuario admin en aos_asesores con tenant_id correcto
5. El sistema ya funciona — misma app, datos separados
```

## BRANDING DINÁMICO POR TENANT

```javascript
// En GS_01_Config.gs — leer config del tenant activo
function getTenantConfig(tenantId) {
  var config = sb_rpc('aos_tenant_config', {p_tenant_id: tenantId});
  return {
    nombre: config.nombre || 'AscendaOS',
    logo: config.config.logo_url || '',
    colorPrimario: config.config.color_primario || '#0A4FBF',
    colorSecundario: config.config.color_secundario || '#00C9A7'
  };
}
// Los PDFs, el header, y los correos se generan con estos valores
// Default = colores corporativos CREACTIVE OS (azul + cyan)
```

## INSTANCIA DEMO — REGLAS

```
tenant_id = 2, demo = true
Datos ficticios: ~50 pacientes, ~200 llamadas, ~30 ventas
Nombres inventados, nunca datos reales de Zi Vital
Siempre disponible para mostrar a prospectos
Se resetea periódicamente con script de seed
Acceso: demo@ascendaos.com / demo123
```

## ROADMAP DE IMPLEMENTACIÓN

```
AHORA (sin romper nada):
  □ Crear tabla aos_tenants
  □ INSERT Zi Vital (id=1) + Demo (id=2)  
  □ ALTER TABLE con DEFAULT 1 en tablas principales

SIGUIENTE (cuando haya segundo cliente):
  □ Foreign keys
  □ RLS policies en Supabase
  □ Filtros por tenant en nuevas funciones RPC

CUANDO HAYA 5+ CLIENTES (Fase 2 Node.js):
  □ Middleware de autenticación por tenant
  □ Subdominios: zi-vital.ascendaos.com
  □ Billing por tenant en Stripe
```

## DETECTAR SI UN MÓDULO ESTÁ LISTO PARA MULTI-TENANT

```
✅ Listo si:
  - Acepta tenant_id como parámetro
  - Las queries filtran por tenant_id
  - No hardcodea nombres de clientes

❌ No listo si:
  - Hardcodea 'Zi Vital' en strings
  - Asume que todos los datos son del mismo cliente
  - No tiene parámetro de tenant en funciones RPC
```
