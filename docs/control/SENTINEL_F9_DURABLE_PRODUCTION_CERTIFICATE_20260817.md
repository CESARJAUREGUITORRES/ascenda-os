# Sentinel F9 — Alert Routing / Owner Notifications — Production Certificate

**Fecha:** 2026-08-17 (America/Lima)  
**Workstream:** Sentinel / F9 — Alert Routing, Owner Notifications & Noise Control  
**PR durable:** #212  
**PR terminal in-app:** #214  
**Main terminal:** `2a55e61fb9ab5ae6543da4c706cf6813e7910078`  
**Estado F9 global:** `CERRADA / 100_COMPLETE`  
**Telegram:** `F9-T DEFERRED / NON-BLOCKING`

## 1. Alcance certificado

F9 queda cerrada con transporte owner obligatorio `ascenda-in-app`, desacoplado del transporte externo Telegram. Cubre:

- P0/P1 inmediato;
- P2 digest durable de 15 min;
- P3 panel-only;
- delivery ledger / outbox restart-safe;
- ACK durable;
- replay idempotente y cooldown post-ACK;
- escalation bypass;
- maintenance suppression + P0 bypass;
- flapping summary/suppression;
- una recovery por transición elegible;
- Auth V3 + `PASSWORD_2FA` para feed owner/admin;
- read receipts separados de `DELIVERED`;
- kill switch service-only;
- F9 fail-open respecto de F8;
- Zero PHI/PII/secrets/free-text payloads.

F9 no ejecuta diagnóstico ni remediación. F10 inicia diagnóstico read-only; F11 AI/MCP triage; F12 remediation.

## 2. F9-B durable state — certificado

Historial live autoritativo:

- `20260817000618 sentinel_f8_incident_engine`;
- `20260817013916 sentinel_f9_alert_outbox`;
- `20260817014618 sentinel_f9_digest_incident_fk_index`.

Archivos Git fuente:

- `supabase/migrations/20260817010000_sentinel_f9_alert_outbox.sql`;
- `supabase/migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql`.

F9-B ya había certificado RLS/ACL, concurrencia, replay, cooldown, digest, maintenance, DB lint, rollback/reapply y canary durable.

## 3. F9-C ASCENDA in-app — exact-head CI

Head funcional certificado:

`0f4078593e746eb55a8d6105acf696b13ecd1c64`

PASS:

- F9 In-App Certificate run `31994735238`;
- F9 Alert Routing Certificate run `31994735153`;
- Ascenda CI run `31994735275`;
- Revenue Operations run `31994735198`.

El primer intento Linux tuvo HTTP 429 de GitHub al descargar `actions/checkout@v4`; se reejecutaron solo los jobs afectados y el mismo head pasó. No hubo cambio de código para ocultar el falso rojo de infraestructura.

## 4. Producción F9-C

Proyecto Supabase: `ituyqwstonmhnfshnaqz`.

Archivo Git:

`supabase/migrations/20260817043000_sentinel_f9_inapp_owner_alerts.sql`

Historial live autoritativo:

`20260817174233 sentinel_f9_inapp_owner_alerts`

Verificación post-DDL:

- tablas soporte F9-C con RLS + FORCE RLS;
- sin grants directos a `anon/authenticated`;
- RPC privilegiadas SECURITY DEFINER + `search_path` fijo;
- routing/publish/config service-role-only;
- owner feed/read valida sesión app activa, no revocada/no expirada, `PASSWORD_2FA`, usuario activo y jerarquía <= 2;
- trigger in-app activo;
- `inapp_enabled=true`;
- `telegram_enabled=false`;
- runtime errors = `0`.

## 5. Canary productivo A — delivery/replay/recovery

F8 creó `SEN-2026-0002` como `OPEN/P1` mediante su boundary certificado.

F9 produjo exactamente:

1. `IMMEDIATE` → `ascenda-in-app` → `DELIVERED` → ACK `inapp:3`;
2. replay exacto F8 → sin duplicar signal ni dispatch;
3. transición F8 a `RESOLVED` → una sola `RECOVERY` → `DELIVERED` → ACK `inapp:4`.

Final: `SEN-2026-0002 = RESOLVED`, runtime errors `0`.

## 6. Canary productivo B — kill switch / F8 survival

Con F9 in-app deshabilitado, F8 creó `SEN-2026-0003` normalmente. F9 produjo `0` dispatches. F9 se reactivó inmediatamente.

Al resolver `SEN-2026-0003`, F9 mantuvo `0` recovery porque no existía una entrega previa. Final `RESOLVED`, runtime errors `0`.

Esto certifica que F9 puede apagarse/fallar sin detener F8.

## 7. Auth, privacidad y advisors

Live negative auth:

- token inválido en owner feed → `SENTINEL_OWNER_2FA_REQUIRED`;
- token inválido en mark-read → `SENTINEL_OWNER_2FA_REQUIRED`.

Positive owner 2FA pasó en el fixture Zero-Cost exact-SQL. No se extrajo token real ni se creó login sintético productivo.

Privacidad:

- sin PHI/PII real en canaries;
- sin bot token/chat target;
- sin columnas libres de message/payload/secret en soporte F9-C;
- runtime error rows `0`.

Performance Advisor: sin F9-C unindexed FK ni multiple-permissive-policy. Dos índices F9-C nuevos aparecen todavía como `unused_index`; se conservan hasta contar con volumen representativo.

Los avisos legacy globales de otros módulos no se reclasifican como defectos F9.

## 8. Deploy y smoke post-merge

PR #214 fusionado al SHA:

`main@2a55e61fb9ab5ae6543da4c706cf6813e7910078`

Post-merge CI sobre `main`:

- F9-C `inapp-fast` — PASS;
- F9-C `inapp-zero-cost` — PASS;
- F9 routing FAST — PASS;
- F9 routing Linux — PASS;
- F9 durable outbox Zero-Cost — PASS;
- Runtime baseline — PASS.

Smoke HTTP productivo read-only desde `ASCENDA-FAST-02 / ZIVITAL`, run `32052546981`, job `95455181080`:

- `/health` HTTP 200;
- body: `{"ok":true,"service":"ascenda-phase-s","child_alive":true,"inner_ready":true}`;
- `/sentinel-inapp-notifications.js` HTTP 200 + firma `AOS_sentinelPollNow`;
- `/phase2-service-worker.js` HTTP 200 + inyección Sentinel presente;
- `/app.html` HTTP 200 + shell `btn-notif` / `np-list` presente;
- `SENTINEL_F9_PRODUCTION_HTTP_SMOKE=PASS`.

No se declara una interacción manual con un token owner real porque no se ejecutó; la autorización positiva queda cubierta por el fixture exact-SQL y la frontera live negativa. Esto no bloquea el baseline técnico F9.

## 9. Supabase Branching / migration-history parity — deuda transversal separada

El GitHub App de Supabase reporta repetidamente:

`Remote migration versions not found in local migrations directory.`

Los logs muestran el mismo error en `main` antes y después de PR #214. La causa es histórica: varias migraciones fueron aplicadas live con un timestamp de historial distinto al timestamp del filename Git. Ejemplos Sentinel:

- F8 Git `20260816233500` vs live `20260817000618`;
- F9-B Git `20260817010000` vs live `20260817013916`;
- F9-B index Git `20260817015500` vs live `20260817014618`;
- F9-C Git `20260817043000` vs live `20260817174233`.

Supabase compara timestamps para determinar paridad. Esta deuda no es introducida por F9-C y no afecta el schema/runtime productivo ya certificado. Se debe resolver como workstream transversal mediante auditoría completa + `supabase migration repair`; no se deben copiar/renombrar migraciones ni reejecutar DDL para maquillar el historial.

## 10. Rollback

Rollbacks versionados F9-B/F9-C pasaron Zero-Cost rollback/reapply preservando F8.

En producción no se ejecuta rollback porque los gates están verdes. Ante defecto UI, primer control: `inapp_enabled=false`; rollback de schema solo si existe evidencia de defecto de schema/runtime.

## 11. Telegram

`F9-T = DEFERRED / NON-BLOCKING`.

El adapter Telegram continúa soportado y probado. Las credenciales live siguen ausentes. Su aprovisionamiento puede completarse después sin reabrir F9 salvo evidencia nueva de defecto.

## 12. Resultado terminal

**F9 Alert Routing / Owner Notifications / Noise Control: `100_COMPLETE`.**

Gate de promoción:

`F1–F9 = 100_COMPLETE → F10 Diagnostic Runner = NEXT / EN CURSO`.
