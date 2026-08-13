# ASCENDA OS — PERFORMANCE GUARD v1.1 FINAL

**Status:** CLOSED / VALIDATED  
**Date:** 2026-08-12 America/Lima  
**Scope:** runtime write semantics + Email Marketing phantom-flow leak + availability protection

## 1. Root cause closed

A legacy Node helper accepted only `(endpoint, body)` and always sent HTTP POST while several older call sites passed a third `'PATCH'` argument expecting an update. The helper also sent only `url.pathname`, dropping the query string/filter.

Result: intended filtered PATCH operations became unfiltered POST requests. In Email Marketing this created phantom `aos_email_flujo_ejecuciones` rows with `flujo_id = NULL`; later worker cycles queried a nonexistent parent flow (`id=eq.null`) and generated repeated 400 responses and unnecessary database work.

## 2. Production runtime remediation

Performance Guard v1.1 is deployed in production and validated through feature/staging/main CI gates.

Runtime changes in `app/server.js`:

- `sbPost(endpoint, body, method)` preserves default POST behavior;
- explicit PATCH call sites now actually use PATCH;
- query strings/filters are preserved through `url.pathname + url.search`;
- Email Marketing due-worker excludes rows whose `flujo_id` is null;
- `_procesarPasoFlujo` has a defensive null-flow guard;
- redundant full-table email-alert probe removed.

This restores the intended semantics of legacy PATCH call sites instead of removing their business functionality.

## 3. Production data cleanup

Before cleanup:

- active invalid null-flow executions: **3,412**
- active valid executions: **334**
- cancelled historical null-flow rows: **10,205**
- latest phantom-row creation observed: `2026-08-13 01:01:31.786454+00`

The cleanup migration was applied only after the new runtime was deployed and no new phantom rows had appeared.

Migration behavior:

- **0 rows deleted**;
- only `estado='activo' AND flujo_id IS NULL` rows changed to `cancelado`;
- 334 valid active executions preserved;
- a validated CHECK constraint prevents future active executions without a parent `flujo_id`;
- a partial due-date index supports valid active flow processing;
- pre/post aggregate evidence persisted in `aos_log_auditoria`.

After cleanup:

- active invalid null-flow executions: **0**
- active valid executions: **334**
- cancelled null-flow rows: **13,617**

Audit evidence:

- PRECHECK: invalid active 3,412 / valid active 334
- POSTCHECK: invalid active 0 / valid active 334

## 4. Database health after cleanup

Post-migration health check:

- connections: **6**
- active: **1** diagnostic connection
- idle-in-transaction: **0**
- active queries >5 s: **0**

January financial checksum remained unchanged:

- **191 sales**
- **S/91,029.60**

## 5. Related Performance Guard v1 state

The original overload remediation remains active:

- dynamic panel intervals cleaned when navigating modules;
- duplicate Home Admin polling removed;
- hidden-tab polling suspended;
- expensive panel reads staggered;
- background snapshot reduced and mutex-protected;
- agent due-check guarded without changing business cron schedules;
- Studio scheduler anti-overlap protection;
- background backoff/circuit behavior;
- agent-log numeric trigger fixed.

These changes reduce redundant load; they do not remove ASCENDA capabilities.

## 6. Residual Studio 401

A separate request to `aos_studio_contenido` continues returning 401 approximately once per minute.

Read-only investigation established:

- the productive ASCENDA Studio scheduler responds 200;
- the repository contains the productive query only in `app/server.js`;
- Supabase has no `pg_cron` or `pg_net` extension generating the request;
- therefore the 401 is consistent with an external/stale client or runner, not PostgreSQL itself.

This is low-cost technical debt. Do **not** weaken RLS/authentication to make the 401 disappear. Trace the external caller separately when practical.

## 7. Definition of done

- [x] runtime fix deployed before cleanup
- [x] feature/staging/main CI gates passed
- [x] no new phantom rows observed before cleanup
- [x] invalid active rows quarantined without deletion
- [x] all valid active rows preserved
- [x] future active null-flow rows blocked by constraint
- [x] due-worker index installed
- [x] audit evidence persisted
- [x] January financial checksum unchanged
- [x] PostgreSQL healthy after remediation

**Performance Guard v1.1 = CLOSED / VALIDATED.**

## 8. Next boundary

Return to the canonical business-data sequence:

**FEBRUARY 2026 — READ-ONLY AUDIT FIRST.**

No February writes before its semantic reconciliation matrix and Impact Report are complete.
