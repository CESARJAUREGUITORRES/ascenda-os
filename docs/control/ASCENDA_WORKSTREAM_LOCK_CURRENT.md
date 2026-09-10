# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-09 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `P0 #485 — AUTH/WHATSAPP FALSE-2FA + POLLING-PRESSURE RECURRENCE`  
**GitHub authority:** Issue `#485` = `OPEN / ACTIVE`  
**Exact entry main:** `07e5ac06ae82ea586d7239fa69a75532384460a1`  
**Active branch:** `p0-485-auth-wa-stability-20260909`  
**WA-L10 #456:** `PAUSED — RESUME ONLY AFTER P0 #485 PROD LOAD/RECURRENCE PASS`  
**Current production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**Active L4 allowlist:** `0`  
**L10 CANARY:** `NOT AUTHORIZED DURING P0`  
**L11/general PROD:** `NOT AUTHORIZED`

## Incident evidence

At approximately 19:13–19:17 Lima on 2026-09-09, immediately after the real R7 notification gate, production again developed cross-module Supabase/PostgREST latency. The owner observed intermittent login failure, global slowness and a WhatsApp Hub screen titled `Sesión 2FA requerida` while the underlying failure code was `WA3_INBOX_UNAVAILABLE`. The system later recovered and fresh `/api/wa3/provider-health` returned HTTP 200 / READY on the same deployment.

The failure exposed two distinct correctness problems plus a load amplifier: WA3 actor verification collapsed upstream database failure into the same null result used for an invalid session; the native UI rendered any mount failure as a 2FA error; and overlapping native/supervisor refresh loops repeatedly requested inbox, queue and team summaries. `team-summary` itself performs multiple aggregate reads plus per-agent effective-presence RPCs.

This is an availability/classification incident, not authority to weaken authentication and not authority to activate the autonomous WhatsApp agent.

## Authorized P0 remediation scope

1. Preserve Auth V3/2FA fail-closed and existing transport timeout boundaries; **no timeout inflation and no bypass**.
2. Distinguish definitive authentication denial from upstream Auth/PostgREST unavailability. Upstream failure must be retryable 503-class state, not false 403/2FA.
3. Keep a short positive actor-verification cache, longer definitive-negative cache and in-flight coalescing; never negative-cache upstream outages.
4. Coalesce/cache bounded supervisor queue/team summaries and cap request-rate exposure without blocking human mutations.
5. Increase browser read-cache intervals, add exponential backoff/stale-safe reads, stop zombie-session network churn after definitive auth denial, and preserve the valid ASCENDA shell during WA 5xx.
6. Replace the misleading 2FA recovery card with a retryable WhatsApp-service-unavailable state when the error is operational rather than authentication-related.
7. Add deterministic P0 regression and bounded recurrence/load gates before production merge.
8. Deploy only while L4/L8 remain SAFE-OFF, then verify production Auth/WA availability, DB pressure and no request storm before releasing this lock.

## Binding invariants

- Production WhatsApp remains `AUTO_OFF`, kill switch engaged, `auto_reply=false`, `ai_send=false`, `auto_routing=false`, `human_send=true`.
- Active L4 allowlist remains zero and autonomous outbound remains zero.
- No live autonomous provider dispatch and no CANARY transition during P0 #485.
- No auth timeout inflation, credential bypass, 2FA bypass, DB restart, project pause, or destructive recovery without separate evidence/authorization.
- No new hot polling loop, persistent materialized analytical hot path, second sender, second identity authority or duplicate routing authority.
- `main` drift invalidates the candidate and requires exact-current revalidation.

## Exit boundary

P0 #485 can close only after exact-head CI, protected merge, Railway SAFE-OFF deployment, production readback and a bounded recurrence/load test proving: Auth/WA errors are classified correctly; no false 2FA/logout is produced by WA 5xx; stale clients back off; supervisor reads are coalesced; login/critical WA endpoints stay inside existing boundaries; and Postgres has no sustained waiting or >2 s / >5 s active-query buildup during the test.

Only after that PASS may WA-L10 #456 resume **exactly** at the prepared one-conversation R7 CANARY gate. `AUTO_OFF -> CANARY` still requires a new explicit owner activation authorization after this P0 is closed.
