# ASCENDA OS — EMAIL FLOW NULL-LEAK INCIDENT

**Date:** 2026-08-12 America/Lima  
**Track:** Performance Guard v1.1  
**Risk:** HIGH availability/data-quality bug; no patient/financial data remediation in this change

## Finding

After Performance Guard v1 stabilized Supabase, API logs still showed repeated 400 responses for:

`aos_email_flujos?id=eq.null`

Read-only inspection found:

- 3,746 active email-flow execution rows;
- 3,412 active rows had `flujo_id = NULL`;
- 334 active rows had a valid `flujo_id` and complete required runtime fields;
- historical cancelled rows with null `flujo_id` also exist and are retained as evidence.

The invalid active rows contain no valid patient/flow identity and are not executable business flows.

## Root cause

`app/server.js` defines `sbPost(endpoint, body)` as an unconditional HTTP POST and historically ignores extra arguments.

Several older call sites use:

`sbPost(filteredEndpoint, body, 'PATCH')`

expecting an update.

Two defects combine:

1. the third `'PATCH'` argument was ignored, so the request remained POST;
2. the helper used only `url.pathname`, dropping the query string/filter.

In email-flow progression, a supposed update therefore inserted a brand-new row with default/null parent identity. Subsequent worker cycles attempted to load its parent flow and queried `id=eq.null`, producing repeated 400s and unnecessary work.

## Remediation design

### Runtime

- `sbPost` explicitly supports the existing optional PATCH convention;
- request path preserves `url.search`, so filtered updates keep their filter;
- normal two-argument POST behavior remains unchanged;
- email-flow due-worker filters `flujo_id=not.is.null`;
- `_procesarPasoFlujo` has a second defensive null guard;
- redundant `aos_email_alertas` existence probe removed from every alert write.

### Database

Versioned migration:

- does **not delete** invalid historical rows;
- changes only invalid `estado='activo' AND flujo_id IS NULL` rows to `cancelado`;
- leaves valid active flow executions untouched;
- records aggregate pre/post evidence in `aos_log_auditoria`;
- installs a constraint preventing future active rows without `flujo_id`;
- adds a partial due-date index for valid active executions.

## Safety invariants

Before production migration:

- valid active executions must be counted separately;
- no valid non-null `flujo_id` row may be updated by the cleanup filter;
- January financial checksum remains 191 / S/91,029.60;
- no change to sales, patients, Agenda, commissions or marketing attribution.

After deployment/migration:

- active null-flow executions = 0;
- valid active executions remain present;
- no repeated `aos_email_flujos?id=eq.null` requests;
- no new 400 burst from flow progression;
- Postgres health remains stable.

## Rollback

Runtime rollback: redeploy previous production commit.

Database cleanup is intentionally non-destructive: rows remain in the table as `cancelado`. If rollback of the constraint is ever required, drop `aos_email_flujo_ejecuciones_active_requires_flow`; do not reactivate phantom executions unless independent evidence proves they were legitimate.
