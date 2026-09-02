# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Captured:** 2026-08-22 America/Lima  
**Entry baseline:** `main@26171abe38bb4bb6f6364aff6624ddc3d0d39580`  
**ACTIVE WORKSTREAM:** `WHATSAPP-REVENUE-HUB-V2`  
**ACTIVE GATE:** `WA-V2-0 — BASELINE & GOVERNANCE`

## Mandatory bootstrap before any write

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. `docs/MEMORY_CURRENT.md`;
6. `docs/adn/AGENTS_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
8. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
9. `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`;
10. exact GitHub `main`, Railway exact deploy/runtime and live Supabase WA state;
11. WhatsApp Control Maestro / Roadmap Maestro V2 in Notion only after technical truth is read.

Historical docs/chat checkpoints never override CURRENT + live persisted state.

## Reliability / performance gate

For every HIGH/CRITICAL mutation, the reliability doctrine is a transversal exit gate. Preserve operational critical paths, keep analytics/background work out of synchronous revenue writes, do not mask slow SQL by raising browser timeouts, and require realistic LIVE readback when the defect or risk is user-, browser-, load- or concurrency-dependent.

A WhatsApp phase is not complete if it regresses Agenda, Call Center, Marketing, Sales/Commissions or shared Supabase pressure.

## Portfolio ownership

`WHATSAPP-REVENUE-HUB-V2` owns the single HIGH/CRITICAL mutable lane by explicit owner directive dated 2026-08-22.

Previous `MKT-INTEGRITY-HOTFIX-V3 / LOOP 6 V2.3` is PAUSED / recoverable at 0/5 genuine post-cutover operations. It is not terminally certified and must not mutate while WA owns the lane.

REV-F5 and REV-F6 are production-certified upstream inputs. REV-F7, CIA feature mutation, KronIA and unrelated work remain paused/read-only.

## Exact-current runtime

Railway production chain:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

`app/railway.json` preloads Sentry and backend-only email compatibility before the outer runtime. Current source still mounts `wa-shell-integration.js`, and that bootstrap still mounts `notification-push-s14.js` S15.5.

## Certified WA evidence — regression only

Do not re-open without a demonstrated regression:

- signed Meta inbound;
- canonical WA message/event ledger;
- WA-2 live inbox/conversation store;
- WA-3 ownership/human-send boundary;
- native shell integration;
- Web Push subscription self-heal;
- closed-PWA Windows notification;
- notification click opens installed PWA and respects Auth;
- final notification ACL cutover.

## Live WA entry baseline

- 15 messages: 11 inbound / 4 outbound;
- 2 conversations;
- 25 events;
- 9 outbound requests;
- 11 routing events;
- 2 active boxes (`VENTAS_GENERAL`, `WA_TEST`);
- 2 active memberships for the current single operational actor;
- 1 active assignment;
- 0 AI runs;
- human send ON;
- auto routing OFF;
- AI send OFF;
- Copilot OFF;
- auto reply OFF.

Historical outbound outcomes include 4 ACCEPTED, 4 `META_190` failures and 1 `META_SEND_REJECTED`. Provider credential health must be re-certified before selling.

## Upstream ecosystem now available to WA

- patients: 7,702;
- sales: 1,331;
- leads: 5,880;
- CIA contact/email facts: 11,911;
- F5 provenance: 15,498 rows / 15,498 memberships / 8,716 clusters / 8,716 previews;
- catalog: 221 active services.

Consume canonical sources; do not create parallel CRM, identity, sales, agenda, email or attribution truth.

## WA-V2-0 rule

WA-V2-0 is control/docs/baseline only. No runtime, schema, routing, AI or Meta mutation belongs in this gate.

Exit only after exact-head GitHub merge, Railway SUCCESS/readback, live Supabase baseline reconciliation, `aos_memory` update and Notion-last reconciliation.

## Next functional gate

After WA-V2-0 PASS, run `WA-3 — HUMAN OPERATIONS MULTIAGENT` in discover-first mode.

Preserve fail-closed defaults during the first canary:

- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `auto_reply_enabled=false`.

`WA-3.5 Revenue Inbox UX` remains planned but must not contaminate ownership/security contracts before WA-3 closes.