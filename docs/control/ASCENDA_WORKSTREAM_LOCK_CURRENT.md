# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `P0 #457 — AUTH/LOGIN OUTAGE + SUPABASE REST 504 + LOGIN UX REGRESSIONS`  
**GitHub authority:** Issue `#457` = `OPEN / ACTIVE`  
**Superseded active lane:** `WA-L10 — PAUSED / SAFE-OFF` under issue `#456`  
**Parent roadmap:** Issue `#410`  
**P0 ENTRY main:** `efc3f24eb661895626ead146b6e539a172884e75`  
**Last closed WA lane:** `WA-L9 — AUTONOMOUS DEMO READY`  
**Effective WA production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**CANARY ACTIVATION:** `NOT AUTHORIZED`

## Incident evidence

Owner and Wilmer were force-logged out and cannot re-enter ASCENDA.

Observed UI/runtime failures:

- owner login: `AUTH_UPSTREAM_UNAVAILABLE`;
- Wilmer login: `No fue posible preparar el envío del código 2FA`;
- login visual mark replaced by generic `✦` despite canonical ASCENDA favicon/icon assets already existing;
- password field has no show/hide control.

Fresh Supabase evidence shows this is not only a login-form defect:

- project reports `ACTIVE_HEALTHY`, but PostgREST/API logs show broad repeated `504` across simple REST/RPC reads/writes and `/rest-admin/v1/ready`;
- PostgreSQL logs show repeated `terminating connection due to idle-in-transaction timeout` plus `canceling statement due to statement timeout`;
- even management SQL succeeds intermittently and then times out;
- therefore auth/2FA failures are a symptom of systemic DB/PostgREST pressure plus an overly strict pre-login Resend reconciliation dependency.

## Binding remediation rules

- P0 #457 is the only mutable HIGH/CRITICAL lane until production-certified closeout;
- WA-L10 implementation/canary work is paused;
- do not raise `statement_timeout`, browser timeout, or conceal pressure with longer waits;
- do not bypass 2FA or weaken auth;
- do not blindly retry non-idempotent login/2FA challenge creation after ambiguous upstream failure;
- restore app availability by reducing pressure/fan-out and eliminating unnecessary synchronous dependencies;
- preserve one source of truth for auth, identity and sessions;
- exact-head CI + anti-drift + protected merge + Railway + Supabase/API readback required;
- owner/Wilmer real login smoke is mandatory before P0 closure.

## P0 implementation scope

1. Determine/mitigate source of DB/PostgREST pressure and idle-in-transaction accumulation.
2. Harden auth availability without weakening security:
   - Resend-vault synchronization must not become an unnecessary synchronous blocker before every login;
   - auth transport errors remain fail-closed and explicit;
   - no unsafe automatic replay of challenge-creating calls.
3. Restore canonical ASCENDA login mark from existing canonical app asset(s).
4. Add accessible show/hide password control.
5. Add focused regression contracts for auth availability behavior and login UI.
6. Re-run cross-module P0 #432 regression matrix.

## Exit

Close only when:

- bounded repeated Supabase REST/admin checks are healthy;
- owner authenticates successfully through valid 2FA;
- Wilmer authenticates successfully through valid 2FA;
- canonical login logo/icon is restored;
- password visibility toggle works;
- no auth/2FA weakening;
- WA remains `AUTO_OFF` with kill switch engaged;
- root cause and prevention are documented.

After #457 closes and the lock is released, WA-L10 may resume from a fresh exact-main revalidation; no prior L10 certification survives this P0 main advance.