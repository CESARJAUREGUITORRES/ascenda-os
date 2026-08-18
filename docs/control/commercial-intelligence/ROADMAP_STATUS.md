# CIA V3 — Roadmap Status CURRENT

**Revalidated:** 2026-08-17 America/Lima  
**Production Supabase:** `ituyqwstonmhnfshnaqz`  
**Control issue:** #268

| Phase | Name | Status | Current evidence / next gate |
|---|---|---|---|
| F0 | Baseline & Contracts | CLOSED 100% | Historical closure retained |
| F1 | Identity Resolver | CLOSED 100% | Historical closure retained |
| F2 | Commercial Facts | CLOSED 100% | Historical closure retained |
| F3 | Segmentation Engine | CLOSED 100% | Historical closure retained |
| F4 | Audience Resolver | CLOSED 100% | Historical closure retained |
| F5 | Panel Central Skeleton | CLOSED 100% | Historical closure retained |
| F6 | Audience Library Persistence | CLOSED 100% | Historical closure retained |
| F7 | Snapshots & Activation | CLOSED 100% | Historical closure retained |
| F8 | Channel Context & Availability | CLOSED 100% | Historical closure retained |
| F9 | Assignment Engine | CLOSED 100% | Historical closure retained |
| F10 | Advisor Control Center | CLOSED 100% | Historical closure retained |
| F11 | Call Center Integration V3 | CLOSED 100% | Historical closure retained |
| F12 | Advisor Work Views | CLOSED 100% | Historical closure retained |
| F13 | Requests & Approval Engine | CLOSED 100% | Historical closure retained |
| F14 | Commercial Intelligence Shadow | CLOSED 100% | Historical closure retained |
| F15 | KronIA + Multiagent Orchestration | CLOSED 100% | Historical closure retained |
| F16 | Email Integration | PRODUCTION CERTIFIED / CLOSED 100% | Live `READY_F17_EMAIL_CERTIFIED`; 7/7 release gates true |
| F17 | SMS / WhatsApp / Future Channels | IN PROGRESS / 75% control estimate | Live 4/6; pending webhook replay + canary; #238 integrity parity |
| F18 | Attribution, Learning & Hardening | PENDING / 0% | Blocked until F17 returns `ready_for_f18=true` |

## CURRENT handshake

### F16 → F17

- `status=READY_F17_EMAIL_CERTIFIED`
- `ready_for_f17=true`
- provider configured
- signed webhook verified
- canary passed
- gateway/UI/legacy ACL/rollback gates true
- `illegal_send_states=0`
- direct browser access blocked

### F17 → F18

- `status=IN_PROGRESS_MULTICHANNEL_GOVERNANCE`
- `ready_for_f18=false`
- true: contracts, WhatsApp bridge, outbound policy, rollback
- false: webhook replay, canary
- `illegal_send_states=0`
- direct browser access blocked

## Current GitHub control

- CURRENT main at revalidation: `644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`.
- PR #265: merged; corrected the shared production runtime chain.
- PR #261: stale/draft/unmergeable; do not merge as-is.
- Issue #238: open; migration-history parity closeout integrity.
- Issue #250: open; separate blank-DB/pre-history baseline program.
- Issue #268: open until GitHub docs, `aos_memory` and Notion are synchronized.

## Active lane

**Only active CIA implementation phase: F17.**

Do not start F18 or count work from WhatsApp Hub, S14/S15 Notifications, Revenue F5, KronIA K1 or Sentinel as F17 progress. Shared code/runtime is a dependency boundary, not shared roadmap ownership.

## Next closeout order

1. Finish control-plane synchronization (#268).
2. Fresh CIA-only F17 branch from CURRENT.
3. Signed webhook replay/idempotency proof.
4. One fixed allowlist canary.
5. Reconcile F17-owned #238 migration-history slice.
6. Exact-head CI + rollback/recovery + production smoke.
7. Require `ready_for_f18=true`; close F17 100%.
8. Start F18 and final CIA V3 hardening/attribution certification.
