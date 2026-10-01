# BOOKING DB ISOLATION LOOP — CURRENT

Captured: 2026-09-30 America/Lima / 2026-10-01 UTC
Owner request: stabilize Zi Vital native web booking without changing the approved landing UX or October availability semantics.
Production Supabase: `ituyqwstonmhnfshnaqz`
Railway project/service: `8def5cac-6aa4-42f1-96cc-8c9cf7d7d3a3` / `bd208ab8-1e71-4c52-94e2-0d6b2bdebce4`

## Incident evidence

- Booking connector `/health` stayed fast while `/bootstrap` produced upstream timeouts.
- Railway compute remained low; the constrained path was Supabase/PostgREST.
- Supabase logs showed repeated statement timeouts and long-running commercial/admin reads.
- `aos_caja_ventas_dia` was normally sub-second before the incident and degraded sharply after 22:00 UTC, confirming shared DB degradation rather than an intrinsically broken booking RPC.
- CIA A2 installed row refresh triggers plus a statement trigger on hot commercial tables. The statement trigger synchronously called `aos_cia_catalog_recount_if_dirty_v1(0)`, placing an audience-wide recount inside hot write transactions.

## Loop

### P0-A — Emergency foreground protection

Set Railway `AOS_FOREGROUND_PRIORITY_MODE=true`.
Expected behavior:
- notification pump paused;
- reminder/background cron paused;
- optional WA bootstrap/background lanes paused;
- booking/auth/foreground traffic remains outside the background classifier.

Rollback: set `AOS_FOREGROUND_PRIORITY_MODE=false` after DB/booking readback is green.

### P0-B — Remove CIA aggregate recount from booking/commercial transaction path

Migration: `supabase/migrations/20261001005000_p0_booking_db_isolation_v1.sql`.

Target behavior:
- row-level CIA contact freshness remains intact;
- source statement trigger only marks catalog state dirty;
- statement trigger does **not** execute an audience aggregate recount;
- a new explicit `aos_cia_catalog_refresh_deferred_v1()` entry point coalesces deferred refreshes with a minimum interval.

Rollback:
- restore the previous `aos_cia_runtime_recount_statement_v1()` definition only if synchronous recount is explicitly re-authorized after load testing.

### P0-C — Persistence Triple-Proof

Do not certify P0-B until all three pass:
1. execution receipt from production migration;
2. direct live readback of `pg_get_functiondef(public.aos_cia_runtime_recount_statement_v1())` proving no call to `aos_cia_catalog_recount_if_dirty_v1(0)`;
3. independent invariant proving all expected CIA row/statement triggers still exist and the booking tables/data are unchanged.

### P0-D — Booking smoke, read-only first

Required checks in this order:
1. `/api/ascenda-connect/booking/v1/health` = 200;
2. `/bootstrap` = 200;
3. Capilar catalog resolves the approved doctor route;
4. Carolina provider profile resolves;
5. October provider-days returns the real published days;
6. a selected October date returns real slots;
7. no specialist-selection screen is shown when only one eligible provider has future availability.

No synthetic production appointment is created for smoke testing.

### P0-E — Restore normal background mode

Only after P0-C and P0-D are green:
- set Railway `AOS_FOREGROUND_PRIORITY_MODE=false`;
- verify notification/background lanes resume without reintroducing booking latency;
- observe Supabase 5xx/522 and statement-timeout rate for a bounded validation window.

## Non-regression invariants

- Do not alter the approved landing visual composition.
- Do not change October to September or fabricate availability.
- Do not show providers with no future turns as selectable booking options.
- Do not bypass `aos_booking_provider_days_v3` / live availability for slot truth.
- Do not loosen auth, RLS, grants, service-role handling, origin allowlists, or booking idempotency.
- CIA analytics may be briefly stale; patient booking availability must not wait for an audience aggregate recount.

## Current status

- P0-A: APPLIED in Railway production.
- P0-B source migration: COMMITTED to `main` as incident recovery.
- P0-B live Supabase application: BLOCKED by current production DB connection timeout; do not falsely certify.
- P0-C/P0-D/P0-E: PENDING until live DB accepts the migration and readback passes.
