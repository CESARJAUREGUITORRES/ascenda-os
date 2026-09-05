# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-05 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `P0 #467 — AUTH AVAILABILITY / SUPABASE-POSTGREST PRESSURE`  
**GitHub authority:** Issue `#467` = `OPEN / ACTIVE`  
**Exact entry main:** `6c34f833762e370dd709e5789f2ac3f40847349d`  
**Active branch:** `p0-467-foreground-priority-20260905`  
**WA-L10 #456:** `PAUSED — NO MUTABLE WORK WHILE P0 #467 IS ACTIVE`  
**Current production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**Active L4 allowlist:** `0`  
**L10 CANARY:** `NOT AUTHORIZED`  
**L11/general PROD:** `NOT AUTHORIZED`

## Incident evidence

Wilmer's login requests reach Railway, but `/api/auth/v3/login` terminates with `502` after the fixed 12 s Auth V3 upstream boundary. Railway logs identify `AUTH_UPSTREAM_TIMEOUT` against `aos_login_v3`; the app container itself remains healthy and lightly loaded.

Supabase is degraded beyond Auth: unrelated REST resources and RPCs return `503/504/522`, and direct management SQL currently cannot establish a usable connection. This is therefore a database/PostgREST availability incident, not a credential rejection and not a reason to weaken Auth V3/2FA.

The first sustained degradation begins immediately after a synchronized recurring background window around 09:38 UTC: snapshot, configuration/branding cache, medical CMP cache, template cache, agent cron scan and notification-push claim all align within seconds. The existing business-priority circuit suppresses several known background sources after failure, but the snapshot/config paths were not classified and there was no reversible incident-mode hard suppression before network I/O.

## Authorized P0 remediation scope

1. Preserve Auth V3/2FA fail-closed and the existing 12 s transport boundary; **no timeout inflation and no bypass**.
2. Add a reversible `AOS_FOREGROUND_PRIORITY_MODE=true` incident mode in the existing composed HTTPS preload.
3. In that mode, reject only classified non-critical background calls locally before Supabase network I/O, including snapshot/config cache paths that were previously uncovered.
4. Keep Auth, Call Center, Agenda, Sales, WhatsApp routing/authority and AI-key bootstrap on the normal transport path.
5. Enable the incident mode in Railway only after exact-head CI and protected merge/deploy.
6. Prove Supabase/PostgREST recovery with cheap reads/SQL and observe the timeout window before asking Wilmer to retry login.
7. After recovery, implement the durable scheduling fix: de-synchronize/serialize recurring background jobs and remove false-success recovery semantics rather than leaving emergency mode as the permanent architecture.

## Binding invariants

- Production WhatsApp remains `AUTO_OFF`, kill switch engaged, `auto_reply=false`, `ai_send=false`, `auto_routing=false`, `human_send=true`.
- Active L4 allowlist remains zero and autonomous outbound remains zero.
- No live autonomous provider dispatch and no CANARY transition during P0 #467.
- No auth timeout inflation, credential bypass, 2FA bypass, DB restart, project pause, or destructive recovery without separate evidence/authorization.
- No new polling/retry loop, persistent materialized analytical hot path or duplicate authority.
- `main` drift invalidates the candidate and requires revalidation.

## Exit boundary

P0 #467 can close only after exact-head CI, Railway deployment, foreground-priority recovery evidence, Supabase/PostgREST readiness, successful Auth V3 smoke, and a post-recovery observation window without renewed systemic 503/504/522 pressure. WA-L10 may resume only from the then-current exact main and with fresh SAFE-OFF evidence.
