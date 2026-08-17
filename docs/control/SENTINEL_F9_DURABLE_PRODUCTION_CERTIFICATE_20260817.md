# Sentinel F9 — Durable Alert State / Outbox — Production Certificate

**Fecha:** 2026-08-17 (America/Lima)  
**Workstream:** Sentinel / F9 — Alert Routing, Telegram & Noise Control  
**PR:** #212  
**Base productiva al iniciar:** `a72a68c600dbacf04b778380d343f345bd5c71fc`  
**Estado de este bloque:** `F9-B DURABLE STATE = PRODUCTION_CERTIFIED`  
**Estado F9 global:** `EN CURSO — único gate pendiente: Telegram live configuration + real sanitized canary`

## 1. Alcance certificado

Este certificado cubre únicamente la capa durable de alertas y control de ruido:

- delivery ledger / outbox restart-safe;
- delivery ACK state;
- replay idempotente por `attempt_key`;
- cooldown durable por `decision_key` después de ACK;
- P2 digest queue durable;
- maintenance windows técnicas;
- concurrencia serializada con advisory locks;
- recovery / flapping keys deterministas;
- RLS + service_role-only RPC boundary;
- rollback/reapply;
- performance hotfix de FK digest→incident.

No declara que Telegram live esté activo.

## 2. Zero-Cost exact-head

Head funcional certificado antes del cierre documental:

`372d01e9b12774cb032e668b73da137fdfd8c168`

Workflow `Sentinel F9 Alert Routing Certificate`, run `31985875030`:

- `routing-fast` — PASS;
- `routing-linux` — PASS;
- `outbox-zero-cost` — PASS.

El job PostgreSQL aislado certificó:

`migration → RLS/ACL → replay → concurrent same-attempt → durable cooldown → digest dedupe → maintenance read → DB lint → performance-index rollback/reapply → F9 rollback/reapply → F8 preserved`

## 3. Producción Supabase

Proyecto: `ituyqwstonmhnfshnaqz`.

Historial live autoritativo:

- `20260817000618 sentinel_f8_incident_engine`;
- `20260817013916 sentinel_f9_alert_outbox`;
- `20260817014618 sentinel_f9_digest_incident_fk_index`.

Archivos fuente versionados:

- `supabase/migrations/20260817010000_sentinel_f9_alert_outbox.sql`;
- `supabase/migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql`;
- rollbacks correspondientes en `supabase/rollbacks/`.

## 4. Post-DDL security certificate

Live verification:

- 3/3 tablas F9 con RLS habilitado;
- 5/5 RPCs F9 `SECURITY DEFINER`;
- 5/5 con `search_path` fijo;
- `anon` EXECUTE = false;
- `authenticated` EXECUTE = false;
- `service_role` EXECUTE = true;
- acceso directo a tablas revocado;
- F8 preservado;
- sensitive-column scan F9 = `[]`;
- Supabase Security Advisor post-DDL = `0 lints`.

## 5. Canary durable productivo

Canary técnico, sin Telegram network call y sin PHI/PII:

`SENTINEL_F9_DURABLE_PRODUCTION_CANARY=PASS`

Validó:

- reserve → `RESERVED`;
- delivery ACK → `DELIVERED`;
- mismo attempt → `REPLAY`;
- mismo decision dentro cooldown → `SUPPRESSED_COOLDOWN`;
- nuevo attempt después cooldown → `RESERVED`;
- digest insert + duplicate dedupe;
- maintenance window read;
- limpieza de digest/maintenance synthetic residue.

Residuo de auditoría permitido: 2 dispatch rows sintéticos técnicos; no contienen mensaje renderizado, token, chat target, PHI ni PII.

## 6. Performance advisor

El advisor post-DDL detectó una FK F9 sin índice de cobertura:

`aos_sentinel_alert_digest_items_v1.incident_id`

Se corrigió con migración aditiva:

`20260817014618 sentinel_f9_digest_incident_fk_index`

El índice se valida y su rollback/reapply está incluido en Zero-Cost. Los avisos de `unused_index` inmediatamente después del despliegue no se interpretan como regresión y no justifican eliminar índices nuevos. Los demás avisos del advisor pertenecen a tablas/workstreams previos y quedan fuera de este certificado.

Referencia de remediación Supabase para foreign keys sin índice: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys

## 7. Telegram live gate

Preflight live, sin leer valores secretos:

- canonical integration name: `Sentinel Owner Alerts`;
- matching integrations: `0`;
- active integrations: `0`;
- secret rows: `0`;
- bot token present: `false`;
- owner chat target present: `false`.

Por tanto:

`F9_TELEGRAM_LIVE = BLOCKED_BY_CONFIGURATION`

Esto no es un fallo del router/outbox. Es ausencia de configuración humana/origen externo. Sentinel no inventará ni copiará credenciales de otros canales.

## 8. Boundary

Hasta que exista la integración canónica:

- no se envía Telegram real;
- no se registra ACK real de Telegram;
- F9 no se marca `100_COMPLETE`;
- F10 no se promueve como fase siguiente autoritativa.

Una vez configurados bot + owner chat en el vault existente, el gate restante será:

`provider preflight → one sanitized synthetic Telegram alert → provider ACK → durable DELIVERED → one recovery → noise/replay verification → F9 final certificate`.

## 9. Resultado

**F9-B durable persistence, RLS/ACL, concurrency, noise state, rollback and production canary: PASS.**  
**F9 global: EN CURSO, pendiente exclusivamente Telegram live.**
