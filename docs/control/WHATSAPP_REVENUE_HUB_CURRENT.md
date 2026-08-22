# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Estado:** V2 ACTIVE / WA-V2-0 BASELINE & GOVERNANCE  
**Fecha:** 2026-08-22 (America/Lima)  
**Entry main:** `26171abe38bb4bb6f6364aff6624ddc3d0d39580`  
**Supabase:** `ituyqwstonmhnfshnaqz`

## 1. North Star V2

Convertir WhatsApp en el Revenue Conversation System nativo de ASCENDA:

`Meta Ads / orgánico → WhatsApp → provenance → identity → conversation → sales stage → knowledge → AI/humano → tools → cita/seguimiento/llamada → asistencia → venta → revenue → attribution → learning → optimization`.

WhatsApp no crea un CRM paralelo. Consume fuentes canónicas de ASCENDA y conserva trazabilidad de fuente, actor, acción y resultado.

## 2. Exact-current runtime

Railway CURRENT entra por:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

`app/railway.json` preloads Sentry plus backend-only email runtime compatibility and reports `/health` as the healthcheck path.

Current source still injects `wa-shell-integration.js`; that bootstrap still mounts `notification-push-s14.js` S15.5. Therefore the notification and native-Hub code remains physically present after the later Revenue, MKT, Sales Explorer and Cartero/email work.

Railway combined status for entry main: **SUCCESS**.

## 3. Certified baseline — preserve, do not reopen without regression

### WA-0 — Recovery & Architecture
**CLOSED.**

### WA-1 — Secure WhatsApp Gateway
**CORE LIVE.** Signed inbound, idempotent canonical ledger and governed outbound boundary were demonstrated.

### WA-2 — Conversation Store & Live Inbox
**CORE LIVE.** Conversation projection, inbox/timeline and same-origin private APIs are present.

### WA-3 — Boxes, Routing & Human Handoff
**CORE LIVE / V2 MULTIAGENT INCOMPLETE.** Ownership, assignment, routing events, exact-owner human-send boundary and manual routing primitives exist. The next WA-3 work is genuine multiagent operation, not rebuilding WA-3 from zero.

### WA-4 — AI Sales Agent / Copilot
**INFRA DEPLOYED / OFF.** Control, audit schema, model router and safety boundary exist; production AI runs remain zero. Auto-reply remains structurally off.

### Notifications S13 → S15.5
**CLOSED / 100% CERTIFIED / REGRESSION ONLY.** Closed-PWA Web Push and Windows notification were physically demonstrated; click opens installed ASCENDA while respecting Auth; final notification ACL cutover is complete.

## 4. Live WhatsApp baseline — 2026-08-22

| Métrica | Valor |
|---|---:|
| canonical messages | 15 |
| inbound | 11 |
| outbound persisted | 4 |
| conversations | 2 |
| events | 25 |
| outbound requests | 9 |
| routing events | 11 |
| active boxes | 2 |
| active memberships | 2 |
| active assignments | 1 |
| AI runs | 0 |

Boxes:

- `VENTAS_GENERAL` — ACTIVE / MANUAL / default;
- `WA_TEST` — ACTIVE / MANUAL.

Both active memberships currently belong to the same operational actor, so multiagent production has not yet been proven.

Controls:

- `human_send_enabled=true`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `copilot_enabled=false`;
- `auto_reply_enabled=false`;
- AI daily budget: USD 0.50.

## 5. Meta provider / outbound status

Historical outbound ledger:

- ACCEPTED = 4;
- FAILED `META_190` = 4;
- FAILED `META_SEND_REJECTED` = 1.

The transport path itself has historical positive evidence, but current Meta credential/provider health is **NOT RECERTIFIED** on this V2 baseline. Before using WhatsApp to sell in production, run a current provider health check and controlled allowlisted outbound canary with a long-lived/system-user credential stored server-side only.

No token may be pasted into chat or committed to Git/Notion/frontend.

## 6. New ASCENDA ecosystem available to WhatsApp

Live upstream truth now available:

| Domain | Live baseline |
|---|---:|
| canonical patients | 7,702 |
| canonical sales | 1,331 |
| leads | 5,880 |
| F5 source rows | 15,498 |
| F5 identity memberships | 15,498 |
| F5 identity clusters | 8,716 |
| F5 previews | 8,716 |
| CIA contact identity | 11,911 |
| CIA canonical-linked contacts | 7,083 |
| CIA email facts | 11,911 |

This changes the WhatsApp opportunity materially: the Hub can now be grounded in a certified customer identity layer, sales truth, lifecycle/read models and email/contact facts instead of operating only on a small conversation ledger.

## 7. Knowledge/catalog baseline

`aos_catalogo_servicios`:

- 221 total / 221 active;
- 221 with price;
- 175 with commercial description;
- 198 with benefits;
- 167 with contraindications;
- 221 with FAQ payload;
- 0 with populated tags.

Structured grounding is already possible, but Knowledge Fabric still needs source authority, versioning, validity, tags, evidence refs and selective enterprise-document connectors.

## 8. Meta attribution gap

Current explicit WA provenance coverage:

- `campaign_source`: 0/15;
- `ad_id`: 0/15;
- `lead_id`: 0/15;
- `raw_referral`: 0/15.

Do not infer campaign attribution from phone coincidence alone. WA-7A will own Meta referral/touchpoint ingress and later connect ad → adset → campaign → treatment/playbook → appointment → sale.

## 9. Handling State vs Sales Stage

Keep separate dimensions.

Handling State:

- `AI_AUTO`;
- `AI_COPILOT`;
- `HUMAN_ACTIVE`;
- `WAITING_CUSTOMER`;
- `CLOSED`.

Sales Stage future V2:

- `NEW`;
- `DISCOVERY`;
- `QUALIFIED`;
- `OFFER`;
- `OBJECTION`;
- `BOOKING_INTENT`;
- `BOOKED`;
- `FOLLOW_UP`;
- `WON`;
- `LOST`.

Do not overload routing/ownership state with commercial funnel state.

## 10. V2 phases

1. `WA-V2-0` — Baseline & Governance — ACTIVE.
2. `WA-3` — Human Operations Multiagent.
3. `WA-3.5` — Revenue Inbox UX.
4. `WA-7A` — Meta Attribution Ingress.
5. `WA-4A` — Knowledge Fabric.
6. `WA-4B` — Sales Playbook Engine.
7. `WA-4C` — AI Sales Copilot canary.
8. `WA-5` — Multimedia / Audio / Media Library.
9. `WA-6` — Agenda / Follow-up / Call Center tools.
10. `WA-7B` — Meta Ads Sync.
11. `WA-7C` — Campaign Flow Router + WhatsApp Flows.
12. `WA-7D` — Revenue Stitching.
13. `WA-8` — Production / SLO / Security / FinOps.
14. `WA-9 → WA-14` — Supervisor Intelligence, Customer 360, Lifecycle Automation, Controlled AI Autonomy, Revenue Optimization and reusable platform core.

Authoritative V2 roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.

## 11. Immediate NEXT after WA-V2-0

`WA-3 — HUMAN OPERATIONS MULTIAGENT`.

Discover and certify:

- explicit `whatsapp-agent` permissions;
- 2+ real authorized agents;
- memberships / `max_active`;
- claim / reassign / release;
- supervisor override;
- presence/readiness;
- ownership ACL;
- no cross-owner leakage;
- queue/unread integrity;
- routing audit events;
- rollback.

Initial topology to evaluate, not blindly create:

- `BOT_INBOX`;
- `VENTAS_GENERAL`;
- `FOLLOW_UP`;
- `ESCALAMIENTO_CLINICO`.

During first WA-3 canary keep auto-routing and AI auto-send OFF.

## 12. WA-3.5 preserved plan

After WA-3 closes, evolve the native Hub into a Revenue Inbox:

- smart queues, unread/SLA/hot lead/follow-up;
- campaign/treatment/sede/stage/owner filters;
- cleaner conversation timeline + sent/delivered/read;
- quick replies/templates/media/internal notes/drafts/shortcuts;
- Agenda/call actions;
- right panel: DETAILS / COPILOT / CUSTOMER 360 / CAMPAIGN / ACTIVITY;
- notification click → Auth if needed → restore exact conversation destination.

## 13. Rules

- no secrets in frontend/Git/docs/chat;
- no autonomous diagnosis;
- no SQL arbitrary from AI;
- no auto-reply AI before controlled autonomy gates;
- no parallel CRM/customer master;
- no parallel agenda;
- no parallel sales/email truth;
- no attribution fabricated from phone matching;
- idempotent/audited writes;
- fail-closed recovery;
- exact-head + live evidence before 100% claims.
