# CIA V3 — Master Alignment CURRENT

**Revalidated:** 2026-08-17 America/Lima  
**Control issue:** #268  
**Production Supabase:** `ituyqwstonmhnfshnaqz`

## Source-of-truth hierarchy

1. production Supabase live state and readiness RPCs;
2. GitHub CURRENT `main`, runtime files, migrations and exact-head checks;
3. current phase validation/impact evidence;
4. `aos_memory` CIA keys;
5. Notion visual control.

If these disagree, stop implementation and synchronize control state first.

## Current program state

| Phase | Name | State |
|---|---|---|
| F0 | Baseline & Contracts | CLOSED 100% |
| F1 | Identity Resolver | CLOSED 100% |
| F2 | Commercial Facts | CLOSED 100% |
| F3 | Segmentation Engine | CLOSED 100% |
| F4 | Audience Resolver | CLOSED 100% |
| F5 | Panel Central Skeleton | CLOSED 100% |
| F6 | Audience Library Persistence | CLOSED 100% |
| F7 | Snapshots & Activation | CLOSED 100% |
| F8 | Channel Context & Availability | CLOSED 100% |
| F9 | Assignment Engine | CLOSED 100% |
| F10 | Advisor Control Center | CLOSED 100% |
| F11 | Call Center Integration V3 | CLOSED 100% |
| F12 | Advisor Work Views | CLOSED 100% |
| F13 | Requests & Approval Engine | CLOSED 100% |
| F14 | Commercial Intelligence Shadow | CLOSED 100% |
| F15 | KronIA + Multiagent Orchestration | CLOSED 100% |
| F16 | Email Integration | PRODUCTION CERTIFIED / CLOSED 100% |
| F17 | SMS / WhatsApp / Future Channels | IN PROGRESS / 75% control estimate |
| F18 | Attribution, Learning & Hardening | PENDING / 0% |

## Fresh live handshake

`aos_cia_email_f17_readiness_v1()`:

- `status=READY_F17_EMAIL_CERTIFIED`
- `ready_for_f17=true`
- all 7 F16 release gates true
- `illegal_send_states=0`
- browser direct table access false for anon/authenticated

`aos_cia_f18_readiness_v1()`:

- `status=IN_PROGRESS_MULTICHANNEL_GOVERNANCE`
- `ready_for_f18=false`
- true: contracts, WhatsApp bridge, outbound policy, rollback
- false: webhook replay, canary
- `illegal_send_states=0`
- browser direct table access false for anon/authenticated

Therefore no earlier phase is currently marked as forgotten/open. The active functional phase is F17; F18 remains blocked.

## CURRENT GitHub baseline

At revalidation, CURRENT `main` is `644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`, merge of PR #265.

PR #265 fixed a production-chain gap discovered by the S15/notification workstream. Its physical runtime effect is shared infrastructure; it is not itself evidence that CIA F17's remaining replay/canary gates passed.

## CIA-specific open items

### F17 functional exit

1. prove signed WhatsApp webhook traversal end-to-end through the F17 boundary;
2. prove byte-equivalent/replay-safe handling and no duplicate side effects;
3. run exactly one allowlist canary with no broad-send/provider-spend expansion;
4. require the production readiness RPC to mark replay + canary true;
5. run rollback/recovery and exact-head post-deploy smoke;
6. close F17 only when `ready_for_f18=true` and the documented certified status is returned.

### Repository integrity

- #238 remains open for Supabase remote/local migration-history parity. F17-owned history must be reconciled without replaying historical production DDL merely to repair metadata.
- PR #258 is an audit snapshot, not a production fix.
- #250 is the independent blank-DB/pre-history baseline problem. Keep it outside F17 functional scope.

### Stale/superseded work

- PR #261 is draft, stale and unmergeable after #265. Do not merge it wholesale.
- historical F17 V1…V20 branches/impact reports are evidence, not active release branches.
- old F16 release PR #114 is historical/superseded because F16 is already production certified.

## Project isolation map

| Workstream | Owns | CIA relationship |
|---|---|---|
| CIA V3 | audiences, activation, assignment, governed channel contracts, attribution | active project in this chat |
| WhatsApp Hub / WA1-WA4 / Phase S | chat transport, inbox, routing, boxes, handoff, UX | transport dependency only |
| S14/S15 Notifications | Web Push, topbar/inbox notifications, notification auth | separate product; currently shares runtime wrapper |
| Revenue F5 | historical sales/patient consolidation and provenance | separate project/data dependency |
| KronIA K1 | KronIA auth/session/secrets hardening | separate security project |
| Sentinel | observability/security monitoring | F18 may consume evidence; separate roadmap |

## Release sequencing rule

The one self-hosted certification lane is serialized. During a CIA release freeze, unrelated HIGH/CRITICAL runtime/migration merges wait until CIA exact-head deployment smoke completes. Documentation/read-only investigation can continue in parallel.

## F18 entry condition

Do not start F18 implementation until:

- F17 production readiness is certified and `ready_for_f18=true`;
- F17 closeout issue/PR evidence is clean;
- migration-history parity for the F17-owned slice is reconciled or explicitly classified with an approved non-blocking rationale;
- CURRENT docs, `aos_memory` and Notion agree on the same checkpoint.

F18 then owns final attribution/outcomes, learning feedback, security hardening, jobs/recovery, observability integration, documentation and end-to-end certification of CIA V3.
