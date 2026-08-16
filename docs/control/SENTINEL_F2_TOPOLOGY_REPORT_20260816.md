# Sentinel F2 — System Registry & Topology Taxonomy — Topology Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `CURRENT / F2 EVIDENCE SNAPSHOT`  
**Repositorio:** `CESARJAUREGUITORRES/ascenda-os`  
**Git snapshot inicial:** `2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0`  
**Supabase project ref:** `ituyqwstonmhnfshnaqz`  
**Registry canónico:** `docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json`

---

## 1. Propósito

F2 construye el mapa verificable que Sentinel observará. No instala sensores ni declara salud. Cada capability permanece `UNKNOWN` hasta que fases posteriores asignen una señal verificable.

Este reporte es un snapshot de topología sustentado en GitHub, configuración de runtime y metadata read-only del catálogo vivo de PostgreSQL. No contiene datos de pacientes, mensajes, pagos ni payloads de negocio.

## 2. Fuentes de evidencia

Precedencia usada:

1. `main` de GitHub y archivos runtime actuales;
2. `app/railway.json` como configuración de arranque;
3. `pg_catalog` live de Supabase consultado solo lectura;
4. registry machine-readable F2;
5. Notion como continuidad visual.

El snapshot F2 parte de `main@2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0`. El contrato CI compara el registry contra el merge candidate real para detectar drift posterior del runtime o de superficies.

## 3. Superficies de producto

Se inventariaron **41 archivos HTML top-level en `app/public/`** y cada uno está asignado exactamente a un dominio. El contrato F2 descubre esos archivos dinámicamente y falla si aparece, desaparece o se duplica una superficie sin actualizar el registry.

Distribución inicial:

| Dominio | Superficies |
|---|---:|
| AUTH | 2 |
| SALES | 9 |
| CALL_CENTER | 5 |
| AGENDA | 4 |
| WHATSAPP | 2 |
| EMAIL | 1 |
| MARKETING | 2 |
| CLINICAL | 3 |
| INVENTORY | 1 |
| PEOPLE | 2 |
| KRONIA | 2 |
| STUDIO | 2 |
| FINANCE | 2 |
| PLATFORM | 4 |
| **Total** | **41** |

Esta clasificación representa ownership topológico para Sentinel, no autorización funcional del usuario ni un nuevo menú.

## 4. Runtime productivo verificado

Railway declara:

- `startCommand = node server-phase-s.js`;
- healthcheck `/health`;
- restart policy `ON_FAILURE`.

La cadena productiva actual tiene **8 procesos Node**:

```text
Railway
  └─ app/server-phase-s.js        [WHATSAPP / stabilization]
       └─ app/server-f5.js        [CLINICAL / historical identity intake]
            └─ app/server-wa4.js  [WHATSAPP / AI copilot]
                 └─ app/server-wa3.js [WHATSAPP / boxes + routing + human send]
                      └─ app/server-wa2.js [WHATSAPP / conversation inbox]
                           └─ app/server-f4.js [Revenue + WA-1 secure boundary]
                                └─ app/server-phase2.js [AUTH v3 boundary]
                                     └─ app/server.js [application core]
```

Cada edge se verificó en el archivo padre mediante `spawn(...)`. F2 registra el chain pero no afirma que cada proceso esté sano en tiempo real.

## 5. Catálogo vivo de Supabase

Consulta read-only a `pg_catalog` sobre el schema `public`:

- **254 tablas**;
- **141 tablas con RLS habilitado**;
- **38 vistas**;
- **1 materialized view**;
- **658 funciones públicas**;
- **522 funciones con prefijo `aos_`**.

Estos números son evidencia de dimensión del sistema, no una certificación de seguridad. F2 no evalúa si cada política RLS es correcta y no convierte objetos sin RLS en un hallazgo automáticamente. Esa evaluación pertenece a security/audit workstreams específicos.

## 6. Dominios canónicos F2

El registry congela **14 dominios**:

1. `AUTH`
2. `SALES`
3. `CALL_CENTER`
4. `AGENDA`
5. `WHATSAPP`
6. `EMAIL`
7. `MARKETING`
8. `CLINICAL`
9. `INVENTORY`
10. `PEOPLE`
11. `KRONIA`
12. `STUDIO`
13. `FINANCE`
14. `PLATFORM`

Dominios críticos iniciales: `AUTH`, `SALES`, `CALL_CENTER`, `AGENDA`, `WHATSAPP`, `CLINICAL`, `FINANCE`, `PLATFORM`.

## 7. Topología crítica resumida

### AUTH

```text
login.html / auth-recovery.html
  → server-phase2.js
  → aos_login_v3 / aos_verificar_2fa_v3 / aos_app_actor_v3
  → aos_login_challenges_v3 / aos_app_sessions_v3 / aos_usuarios
  → Supabase
```

### SALES

```text
sales + sales-intelligence + cartera + commissions + catalog
  → server-f4.js / server.js
  → sales/cartera gateways
  → ventas + pagos + cotizaciones + metas + product identity
  → Supabase
```

### CALL CENTER

```text
calls + coordinacion + followups
  → server.js
  → lead queue / next lead / call contracts
  → aos_leads + aos_llamadas + aos_cola_config + aos_seguimientos
  → Supabase
```

### AGENDA

```text
agenda + citas + agendar
  → server.js
  → agenda RPCs
  → aos_agenda_citas + horarios + links_agenda
  → Supabase
```

### WHATSAPP

```text
admin-whatsapp*
  → Phase S → F5 → WA4 → WA3 → WA2 → F4
  → conversations/messages/boxes/routing/outbound/AI tables
  → Supabase
  → Meta WhatsApp Graph API
  → Groq/Gemini/OpenAI where AI copilot applies
```

### CLINICAL

```text
patients + F5 historical intake
  → server.js / server-f5.js
  → patient + clinical + F5 identity objects
  → Supabase
```

`CLINICAL` carries `sensitivity=PHI`; telemetry policy remains `metadata-only-no-PHI`.

### FINANCE

```text
admin-billing + caja
  → server.js
  → caja/comprobantes/documentos fiscales
  → Supabase
```

### PLATFORM

```text
Railway → 8-node Node runtime chain
GitHub Actions → self-hosted CI
configuration/integrations → Supabase
```

## 8. Dependencias externas registradas

- Supabase — database/auth/REST/RPC.
- Railway — production runtime host.
- Meta WhatsApp — messaging provider.
- Resend — email provider.
- Groq — AI provider.
- Gemini — AI provider.
- OpenAI — AI provider.
- GitHub Actions — CI/control plane.

La presencia de una dependencia en el registry no significa que esté configurada o disponible; su estado F2 es `UNKNOWN`.

## 9. Regla anti false-green

F2 **prohíbe** el estado `HEALTHY` en el registry. El contrato automático recorre todo el JSON y falla ante cualquier claim `HEALTHY`.

Razón: F2 responde “qué existe y cómo se conecta”, no “qué está funcionando ahora”. Esa salud comienza a instrumentarse desde F3/F4/F5/F6 según el tipo de señal.

## 10. Coverage

Baseline F2:

- public HTML classification: `41/41`;
- runtime chain: `8/8`;
- domains: `14`;
- critical domains with capabilities: `8/8`;
- unmapped critical nodes: `0`;
- health claims: `0`;
- PHI/PII telemetry authorized: `false`.

## 11. Anti-scope

F2 no autoriza ni realiza:

- cambios en `app/`;
- migrations/RPC/table changes;
- nuevos secrets;
- Sentry SDK;
- OpenTelemetry runtime;
- Uptime Kuma deployment;
- Telegram;
- Sentinel tables;
- product UI changes;
- production mutation.

El resultado de F2 es registry + contratos + evidencia + continuidad.

## 12. Handoff esperado

F2 puede cerrarse solo si el registry sigue coincidiendo con el merge candidate, el contrato pasa en self-hosted CI, el diff permanece fuera de runtime/DB, el certificado final queda en `main` y Notion deja F3 como única fase `Siguiente`.
