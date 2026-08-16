# Sentinel F8 — Production Persistence Impact Report

**Fecha:** 2026-08-16 (America/Lima)  
**Fase:** F8 — Sentinel Incident Engine (`SEN-*`)  
**Branch:** `feature/sentinel-f8-incident-engine`  
**PR:** #208 — DRAFT / DO NOT MERGE  
**Riesgo del cambio productivo:** HIGH  
**Estado productivo:** `NOT AUTHORIZED / NOT APPLIED`  

## 1. Objetivo del cambio

Persistir de forma canónica e idempotente los incidentes Sentinel `SEN-*` y su timeline técnico, utilizando PostgreSQL/Supabase como runtime store mínimo.

Este cambio **no modifica datos clínicos/comerciales existentes** y no activa todavía alertas, IA ni remediación.

## 2. Objetos propuestos

### Tablas nuevas

1. `public.aos_sentinel_incident_counters_v1`
   - secuencia anual transaccional para `SEN-YYYY-NNNN`.
2. `public.aos_sentinel_incidents_v1`
   - estado canónico del incidente.
3. `public.aos_sentinel_incident_signals_v1`
   - ledger idempotente por `event_id` y señal normalizada sanitizada.
4. `public.aos_sentinel_incident_timeline_v1`
   - timeline técnico inmutable por eventos tipados.

### Funciones nuevas

Helpers de validación:

- `aos_sentinel_evidence_refs_valid_v1(jsonb)`
- `aos_sentinel_correlation_valid_v1(jsonb)`

Boundary server-only:

- `aos_sentinel_ingest_signal_v1(jsonb)`
- `aos_sentinel_transition_incident_v1(text,text,timestamptz)`
- `aos_sentinel_get_incident_v1(text)`

## 3. Seguridad

- RLS habilitado en las cuatro tablas.
- Sin políticas de acceso directo para `anon`/`authenticated`.
- Se revocan accesos directos a tablas incluso para `service_role`; la operación se concentra en RPCs `SECURITY DEFINER` de mínimo alcance.
- RPCs operativos: `service_role` only.
- `search_path` fijo/vacío en funciones `SECURITY DEFINER`.
- Sin columnas de payload raw.
- Sin nombres, teléfonos, DNI, emails, mensajes, prompts, request bodies, cookies, tokens o secretos.
- Evidence refs = `kind + id` técnico únicamente.
- Correlation = release/SHA/deployment/request/trace/confidence sanitizados.

## 4. Integridad/concurrencia

La migración utiliza:

- `event_id` como PK del ledger de señales;
- unique parcial `(environment, incident_fingerprint)` para un solo incidente activo de una familia;
- advisory transaction lock por `event_id`;
- advisory transaction lock por `environment + incident_fingerprint`;
- counter anual actualizado dentro de la misma transacción;
- ingest completo en una única transacción PostgreSQL;
- replay exacto como no-op;
- reopen de 60 min solo con evento nuevo y mismo fingerprint;
- rollback target/remediación no forman parte de la RPC F8.

## 5. Impacto operativo esperado

### Escrituras nuevas

Solo cuando F8 se active posteriormente:

- 1 ledger row por `event_id` nuevo;
- insert/update del incidente correspondiente;
- 1 o más rows pequeñas de timeline.

No se actualizan tablas existentes de pacientes, ventas, llamadas, WhatsApp o Email.

### Lecturas nuevas

Lectura por incident ID y futuras consultas de panel/diagnóstico. El panel aún no se implementa en F8.

### Disponibilidad

ASCENDA debe seguir operando si Sentinel persistence falla. La observabilidad nunca debe bloquear funciones clínicas/comerciales.

## 6. Coste

- No se crea hosting nuevo.
- No se activa un plan pago.
- Se reutiliza PostgreSQL/Supabase ya existente.
- Incremento esperado: almacenamiento/IO técnico pequeño, sujeto a medición posterior.
- No hay pay-as-you-go automático autorizado.

## 7. Preflight productivo read-only

Ejecutado el 2026-08-16 sin DDL ni escrituras de negocio.

Validaciones:

- roles `anon`, `authenticated`, `service_role` disponibles;
- no existen las cuatro tablas F8 propuestas;
- no existen las cinco funciones F8 propuestas;
- por tanto no se detectó colisión de nombres al momento del preflight.

Resultado: `SENTINEL_F8_PRODUCTION_READONLY_PREFLIGHT=PASS`.

## 8. Zero-Cost gate requerido

Antes de producción deben quedar PASS en Supabase local aislado:

- compilación completa de migración;
- RLS/ACL;
- service_role-only RPC;
- lifecycle;
- replay idempotente;
- multi-signal convergence;
- reopen 60m;
- dos llamadas simultáneas del mismo `event_id`;
- dos eventos simultáneos del mismo `incident_fingerprint`;
- severity escalation;
- DB lint;
- rollback completo;
- reapply limpio y fixture repetido.

Hasta que este gate no esté verde, producción permanece bloqueada.

## 9. Rollback

Archivo versionado:

`supabase/rollbacks/20260816233500_sentinel_f8_incident_engine_rollback.sql`

El rollback elimina únicamente los objetos F8 nuevos.

**Advertencia:** una vez que existan incidentes reales, ejecutar rollback elimina el runtime store F8. Por eso el rollback productivo solo se autoriza como respuesta a una falla de rollout/canary y nunca como operación rutinaria.

## 10. Canary productivo propuesto tras autorización

1. checksum/objeto de migration aplicado;
2. verificar RLS y grants;
3. ingest de un evento sintético `zero_phi_pii` controlado;
4. replay del mismo `event_id` → no-op;
5. segunda signal class con mismo incident fingerprint → mismo `SEN-*`;
6. transición controlada a RESOLVED;
7. reopen sintético dentro de ventana;
8. consulta por RPC protegida;
9. eliminar/archivar únicamente evidencia sintética según procedimiento aprobado;
10. confirmar que ASCENDA runtime y `/health` permanecen sanos.

No se utilizarán pacientes ni datos reales para el canary.

## 11. Condición de autorización

La autorización productiva debe ser explícita y limitarse a:

- aplicar **esta migración F8** al Supabase productivo;
- ejecutar el canary sintético descrito;
- verificar RLS/ACL/replay/concurrencia/rollback readiness;
- ejecutar rollback solo si un gate de rollout falla.

No autoriza F9, Telegram, IA, auto-remediation ni otros cambios.

## 12. Estado actual

`PRODUCTION DDL = BLOCKED` hasta:

1. `F8-G12 Zero-Cost DB = PASS`;
2. Impact Report revisado;
3. autorización productiva expresa del owner.
