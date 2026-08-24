# ASCENDA Conversations — WA-CLOSEOUT Supabase 402 Circuit Impact Report

**Workstream:** `WA-CLOSEOUT`  
**Entry:** `main@48e7c7022bcd8bff6f2a9757717c17246e6b3e59`  
**Risk:** HIGH  
**Mode:** fail-closed / no production DB mutation / Zero-Cost + exact-head CI

## Incident

Supabase project `ituyqwstonmhnfshnaqz` is `ACTIVE_HEALTHY`, but current API logs show repeated HTTP `402` responses while the Free-plan egress quota is exhausted. WA recurrent callers continue reaching Supabase during the blocked billing window, especially `aos_wa3_actor_v1` from Phase S / WA3V2 and notification RPCs from F17.

The application is therefore creating avoidable failed traffic while production cannot serve reliable data. A 402 must not be treated like a transient application error that deserves tight retry loops.

## Objective

Introduce a process-local Supabase quota circuit for the WA runtime family so that the first upstream 402 opens a bounded cooldown and subsequent matching calls fail locally without issuing another network request until a controlled probe window reopens.

## Implementation scope

To avoid rewriting already-certified wrappers, the circuit is loaded as a small runtime preload through the existing Railway `NODE_OPTIONS` chain:

- `app/supabase-quota-circuit.js` — pure state machine;
- `app/supabase-quota-circuit-preload.cjs` — scoped `https.request` interceptor;
- `app/railway.json` — adds the preload to the existing Sentry/email preload chain.

The interceptor is intentionally narrow. It applies only when both conditions are true:

1. request hostname equals the configured ASCENDA Supabase hostname;
2. `User-Agent` belongs to the WA runtime family: `AscendaOS-Phase-S/*`, `AscendaOS-WA2/*`, `AscendaOS-WA3/*`, `AscendaOS-WA3V2/*`, `AscendaOS-WA4/*`, or `AscendaOS-F17/*`.

Other runtime traffic is not intercepted. The state remains process-local because each wrapper runs in a separate Node process and inherits `NODE_OPTIONS`.

## Required semantics

1. First real upstream `402` opens the circuit.
2. Circuit remains open for a bounded cooldown; default: 15 minutes, bounded to 1–60 minutes.
3. While open, matching requests fail locally with deterministic `SUPABASE_QUOTA_BLOCKED` and compatibility metadata `upstreamStatus=402` / `upstream_status=402`.
4. No credentials, session tokens, customer data or provider payload are stored by the circuit.
5. 401/403/429/5xx do not open the quota circuit.
6. Cooldown expiry permits one probe; parallel probes are suppressed.
7. Any non-402 probe result releases the quota circuit; a successful 2xx probe therefore rearms normal operation immediately.
8. Security remains fail-closed: no actor, 2FA, ownership, RLS or permission bypass.
9. Production data/schema are untouched.
10. The circuit is not a substitute for the August 29 production revalidation gate.

## Performance intent

During a quota block, Supabase request volume from each covered WA process should collapse from recurrent polling cadence to at most one quota probe per cooldown window, rather than one failed request per UI/pump tick.

This is a protection budget, not a live production performance certification. Exact live request-rate verification remains blocked until Supabase quota resets.

## Tests

- pure state-machine contract for open → local short-circuit → cooldown → single probe → reset;
- negative contract: 401/403/429/500 never open the quota circuit;
- preload behavior contract proves first target 402 reaches the caller, all six WA runtime user-agent families short-circuit after opening, and a non-target runtime remains untouched;
- static contract proves Railway loads the preload and the WA runtime allowlist/host scope are present;
- historical runtime contracts normalize only this exact certified preload and continue rejecting arbitrary wrappers;
- existing Phase S / WA-2 / WA-3 / WA-4 / S14 / S15 contracts remain mandatory;
- Performance Guard remains mandatory;
- Zero-Cost WA-3 FINAL local Supabase/pgTAP/concurrency/rollback remains mandatory.

## Rollback

Remove the preload from `app/railway.json` and revert the two helper files. No SQL rollback and no production data recovery are required because this slice makes no DB/schema mutation.

## Production state

Do not use Supabase Cloud for certification while 402 persists. After reset, the WA-PROD-CERT sequence must explicitly confirm `402 → 200`, then exercise auth/2FA, WA smoke, inbound/outbound, ownership, boxes, alerts and egress metrics before any `PRODUCTION CERTIFIED 100%` claim.
