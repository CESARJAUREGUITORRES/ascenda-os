# ASCENDA Conversations — WA-CLOSEOUT Supabase 402 Circuit Impact Report

**Workstream:** `WA-CLOSEOUT`  
**Entry:** `main@48e7c7022bcd8bff6f2a9757717c17246e6b3e59`  
**Risk:** HIGH  
**Mode:** fail-closed / no production DB mutation / Zero-Cost + exact-head CI

## Incident

Supabase project `ituyqwstonmhnfshnaqz` is `ACTIVE_HEALTHY`, but current API logs show repeated HTTP `402` responses while the Free-plan egress quota is exhausted. WA recurrent callers continue reaching Supabase during the blocked billing window, especially `aos_wa3_actor_v1` from Phase S / WA3V2 and notification RPCs from F17.

The application is therefore creating avoidable failed traffic while production cannot serve reliable data. A 402 must not be treated like a transient application error that deserves tight retry loops.

## Objective

Introduce a process-local Supabase quota circuit for WA runtime wrappers so that the first upstream 402 opens a bounded cooldown and subsequent Supabase calls fail locally without issuing another network request until a controlled probe window reopens.

## Scope

Adopt one shared helper in the WA runtime processes that currently own recurrent Supabase calls:

- `app/server-phase-s.js`;
- `app/server-wa3-v2.js`;
- `app/server-f17.js`.

The helper is process-local by design because these wrappers run as separate Node processes.

## Required semantics

1. First real upstream `402` opens the circuit.
2. Circuit remains open for a bounded cooldown; default target: 15 minutes.
3. While open, requests fail locally with a deterministic `SUPABASE_QUOTA_BLOCKED` error and `upstreamStatus=402` / `upstream_status=402` compatibility metadata.
4. No credentials, session tokens, customer data or provider payload are stored by the circuit.
5. 401/403/429/5xx do not open the quota circuit.
6. Successful probe after cooldown closes/rearms normal operation.
7. Security remains fail-closed: no actor, 2FA, ownership, RLS or permission bypass.
8. Production data/schema are untouched.
9. The circuit is not a substitute for the August 29 production revalidation gate.

## Performance intent

During a quota block, Supabase request volume from each covered WA process should collapse from recurrent polling cadence to at most one quota probe per cooldown window, rather than one failed request per UI/pump tick.

This is a protection budget, not a live production performance certification. Exact live request-rate verification remains blocked until Supabase quota resets.

## Tests

- pure unit/behavior contract for open → short-circuit → cooldown → successful probe reset;
- negative contract: 401/403/429/500 never open this quota circuit;
- wrapper static/runtime contract confirms all three WA callers use the shared circuit;
- existing Phase S / WA-2 / WA-3 / WA-4 / S14 / S15 contracts remain green;
- Performance Guard remains green;
- Zero-Cost WA-3 FINAL local Supabase/pgTAP/concurrency/rollback remains green.

## Rollback

Revert the helper adoption commit(s). No SQL rollback and no production data recovery are required because this slice makes no DB/schema mutation.

## Production state

Do not use Supabase Cloud for certification while 402 persists. After reset, the WA-PROD-CERT sequence must explicitly confirm `402 → 200`, then exercise auth/2FA, WA smoke, inbound/outbound, ownership, boxes, alerts and egress metrics before any `PRODUCTION CERTIFIED 100%` claim.
