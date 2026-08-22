# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-08-22 America/Lima  
**GitHub entry baseline:** `main@26171abe38bb4bb6f6364aff6624ddc3d0d39580`  
**ACTIVE WORKSTREAM:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT GATE:** `WA-V2-0 — BASELINE & GOVERNANCE`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
8. exact GitHub CURRENT + Railway exact deploy + Supabase LIVE;
9. fresh scoped rows in `aos_memory`;
10. Notion executive continuity.

Historical chat/doc snapshots never override exact CURRENT + live production.

## Portfolio state

- REV-F5 — **PRODUCTION CERTIFIED — 100%**;
- REV-F6 — **PRODUCTION CERTIFIED — 100%**;
- REV-F7 — paused while WA owns the mutable lane;
- MKT Integrity Loop 6 V2.3 — **PAUSED / RECOVERABLE at 0/5 genuine operations**;
- WhatsApp Revenue Hub V2 — **ACTIVE**;
- Notifications S13–S15.5 — **CLOSED / 100% CERTIFIED / REGRESSION ONLY**;
- CIA, Sentinel, KronIA and unrelated feature/data work — read-only/regression-only unless WA proves a strict dependency.

## Runtime exact-current entry

Current `main` at handoff: `26171abe38bb4bb6f6364aff6624ddc3d0d39580`.

Railway combined status for that commit: **SUCCESS**.

Production chain remains:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

`app/railway.json` also preloads Sentry plus the backend-only email runtime compatibility module. The WhatsApp shell mount and S15.5 Push bootstrap remain present in current source.

## Certified WhatsApp baseline preserved

Already demonstrated and not to be reopened without regression:

- Meta signed inbound;
- WA canonical message/event persistence;
- live inbox and native ASCENDA shell integration;
- WA-3 ownership/handoff boundary;
- human-send path with historical ACCEPTED provider sends;
- PWA Web Push self-healing;
- closed-PWA Windows notification;
- click → installed ASCENDA PWA → Auth gate;
- final notification ACL cutover.

Notification infrastructure is not the current work item.

## WhatsApp live baseline — 2026-08-22 revalidation

- messages = **15**: 11 INBOUND / 4 OUTBOUND;
- conversations = **2**;
- events = **25**;
- outbound requests = **9**;
- routing events = **11**;
- active boxes = **2** (`VENTAS_GENERAL`, `WA_TEST`);
- active box memberships = **2** for the current single operational actor;
- active assignments = **1**;
- AI runs = **0**;
- `human_send_enabled=true`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `copilot_enabled=false`;
- `auto_reply_enabled=false`;
- AI provider configured = Groq GPT-OSS fast/reasoning/safety, daily budget USD 0.50.

Outbound credential/provider health is **not current-certified**. Historical outbound request outcomes:

- ACCEPTED = 4;
- FAILED `META_190` = 4;
- FAILED `META_SEND_REJECTED` = 1.

Before production selling, perform current provider health and a controlled outbound canary using a long-lived/system-user Meta credential stored only server-side.

## New ecosystem truth now available to WA

Live counts at WA-V2 entry:

- canonical patients = **7,702**;
- canonical sales = **1,331**;
- leads = **5,880**;
- F5 source rows = **15,498**;
- F5 identity memberships = **15,498**;
- F5 identity clusters = **8,716**;
- F5 previews = **8,716**;
- CIA contact identity rows = **11,911**;
- CIA canonical-linked contacts = **7,083**;
- CIA email facts = **11,911**.

WA must consume this evidence through Customer/Identity/Revenue contracts. Do not build another CRM, patient master, sales ledger or email master inside WhatsApp.

## Knowledge baseline

`aos_catalogo_servicios` live:

- 221 total / 221 active;
- 221 with price;
- 175 with commercial description;
- 198 with benefits;
- 167 with contraindications;
- 221 with FAQ payload;
- 0 with populated tags.

This is enough for structured grounding, but not yet enough for a mature Knowledge Fabric. Tags, source authority, versioning, policy validity and provenance still need explicit V2 work.

## Meta attribution gap

Current WA messages with explicit attribution:

- `campaign_source`: 0/15;
- `ad_id`: 0/15;
- `lead_id`: 0/15;
- `raw_referral`: 0/15.

Do not infer ad/campaign attribution from phone matching alone. WA-7A will own Meta referral/provenance ingress.

## WA V2 execution order

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
14. WA-9→WA-14 expansion only after core certification.

## Safety invariants

- one HIGH/CRITICAL mutable workstream;
- no secrets in frontend/Git/Notion/chat;
- no auto-reply AI before controlled autonomy gates;
- no diagnosis/clinical advice automation;
- no attribution invented from phone alone;
- no duplicate CRM/agenda/sales/email truth layer;
- exact-head + live readback before 100% claims;
- updates land GitHub first, then `aos_memory`, then Notion last.
