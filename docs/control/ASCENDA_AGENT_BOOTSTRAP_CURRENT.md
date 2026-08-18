# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Control baseline:** `main@addd14f2a57f06ec54b5ace10e042f4d8b69a85a`  
**Runtime:** S15.3  
**ACTIVE WORKSTREAM:** `CIA-F17/F18-CLOSEOUT`

## Mandatory bootstrap

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/MEMORY_CURRENT.md`
6. CIA CURRENT Control Maestro + CIA-F17 checkpoint only
7. exact `main`, Railway runtime and F17 Supabase readiness
8. relevant branch/PR/checks

Do not resume Revenue, WhatsApp, KronIA, Sentinel maintenance, #238 or #250 as a competing mutable workstream while CIA owns the lock.

## Runtime

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

S15.3 fixed buffered HTTP framing for F17 webhook/governed traffic.

## CIA-F17 entry contract

At portfolio handoff:

- contracts=true
- WhatsApp bridge=true
- outbound policy=true
- rollback=true
- webhook replay=false
- canary=false
- ready_for_f18=false
- illegal send states=0
- governed inbound facts=1
- governed send requests/events=0
- WA messages=12

Do not turn this into 5/6 by inference. The remaining gates need explicit signed replay/idempotency and real allowlisted canary evidence.

PR #261 is evidence-only and must not merge as-is. Start remaining F17 work from CURRENT.

## CIA-F17 next actions

1. freeze exact CURRENT and live readiness;
2. inventory only unresolved F17 history/parity/runtime scope;
3. run isolated F17 DB/replay/security/rollback gates;
4. validate authentic signed Meta webhook + replay/idempotency;
5. execute only owner-approved allowlisted canary, broad send OFF;
6. reconcile ledgers/outcomes and rollback;
7. require F17 6/6 and `ready_for_f18=true`;
8. then execute CIA-F18 under the same CIA lock;
9. close CIA, update memory/Notion, and hand lock to Revenue.

## Certification rule

No percentage, runtime merge, sibling PASS, skipped check or old CI certifies CIA-F17. Use exact-head CURRENT, live readiness, security, rollback/recovery and required real canary evidence.