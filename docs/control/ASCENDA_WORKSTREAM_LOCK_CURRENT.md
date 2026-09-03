# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `NONE`  
**Last closed lane:** `WA-L7 — WhatsApp/AI Cost Intelligence`  
**WA-L7 status:** `CLOSED · PRODUCTION CERTIFIED · DORMANT / SAFE-OFF`  
**GitHub authority:** Issue `#449` = `CLOSED / completed`  
**WA-L7 certified exact-head:** `1ea6a4f61c1e03a38e902aefc7ad6f74efbfb109`  
**WA-L7 merge SHA:** `41c25a6a54d0043b6f0f7a679677942968fe6566`  
**Supabase PROD:** `20260903182220 · wa_l7_cost_intelligence_v1`  
**Railway:** `SUCCESS` on merged lineage `41c25a6a54d0043b6f0f7a679677942968fe6566`  
**Effective production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**NEXT ELIGIBLE:** `WA-L8 — Security Gate for Autonomous Canary · NOT STARTED`  
**CANARY:** `NOT AUTHORIZED` — separate explicit owner authorization required.

## WA-L7 production closeout

WA-L7 converts already-existing Meta status telemetry and WA-4 AI run telemetry into governed, reproducible cost intelligence without moving analytics into WhatsApp operational hot paths.

Certified path:

`provider pricing evidence + AI usage telemetry → effective-dated pricing authority → conversation-scoped Meta/AI cost reconciliation → WA-L6 strong-key journey → booking / attendance / explicit sale / revenue KPIs → lazy admin mini-panel`.

### Exact-head / merge evidence

- ENTRY baseline frozen at `main@4a34f0f982f7d740f3d0817a04a6d7442a9f826e`;
- sole HIGH/CRITICAL WA-L7 lock acquired at `ae796fb6357a36bbc9714844fb7aac4ff4521f65`;
- PR `#450` head certified at `1ea6a4f61c1e03a38e902aefc7ad6f74efbfb109`;
- **8/8 exact-head workflows SUCCESS**:
  - Ascenda CI;
  - WA-2 Conversation Store & Live Inbox;
  - Phase S WA3 Stabilization;
  - WA-L7 Cost Intelligence;
  - Sentinel F6 Business Health Certificate;
  - WA-4C FULL LOCAL Integration;
  - Performance Guard;
  - ASC-PERF Audit 360;
- anti-drift PASS: `main` remained at `ae796fb6357a36bbc9714844fb7aac4ff4521f65` immediately before merge;
- merge executed with `expected_head_sha=1ea6a4f61c1e03a38e902aefc7ad6f74efbfb109`;
- merged/deployed lineage: `41c25a6a54d0043b6f0f7a679677942968fe6566`;
- Railway status: `SUCCESS`.

### PROD objects and governance

LIVE objects:

- `aos_wa_l7_pricing_authority_v1`;
- `aos_wa_l7_meta_cost_events_v1`;
- `aos_wa_l7_ai_cost_events_v1`;
- `aos_wa_l7_conversation_cost_v1(uuid)`;
- `aos_wa_l7_journey_cost_v1(uuid)`.

Pricing authority guarantees:

- append-only effective-dated versions;
- explicit provider/model/category/market/currency/evidence lineage;
- `VERIFIED` vs `LEGACY_ESTIMATE` remains explicit;
- no default/fabricated provider price;
- PROD pricing rows after deployment = `0`;
- provider `billable=false` is an explicit `KNOWN 0`, not a guessed zero;
- unresolved billable provider pricing remains `UNKNOWN/PARTIAL`;
- AI historical estimates remain `PARTIAL` when token usage cannot be reproducibly split across differently-priced models;
- cross-currency revenue/cost comparison fails closed until governed FX exists.

Security readback:

- anon/auth pricing-table SELECT = `false`;
- anon/auth L7 cost RPC execution = `false`;
- service-role L7 cost RPC execution = `true`;
- no browser direct Supabase cost access.

### LIVE cost/readback

Real existing L6 conversations were read through L7 after deploy:

- one conversation has `7` outbound provider events, all `billable=false` → Meta `KNOWN · 0`;
- AI runs = `0` → AI `KNOWN · 0`;
- aggregate conversation cost = `KNOWN · 0`;
- no synthetic pricing, booking, sale, attribution or patient rows were inserted for certification;
- current L6 journeys remain explicit `NO_PROVIDER_ATTRIBUTION` where provider attribution is absent;
- zero-cost denominator correctly produces no fabricated revenue/cost ratio.

Scoped PROD performance probes under the existing `3s` boundary:

- conversation cost RPC ≈ `670 ms`;
- journey cost RPC ≈ `520 ms`;
- sampled probes used shared-buffer hits and no physical reads;
- no statement-timeout increase;
- no materialized view or synchronous refresh;
- no L7 trigger on message, AI-run, booking, Agenda or Sales hot paths;
- UI cost enrichment is conversation-scoped, lazy, independently survivable and TTL/coalesced rather than added to the inbox-list polling path.

### SAFE-OFF / cross-module readback

After Railway + Supabase PROD deployment:

- mode = `AUTO_OFF`;
- kill switch = `ENGAGED`;
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- `human_send=true`;
- autonomous outbound = `0`;
- AI runs = `0`;
- WA-L7 pricing authority rows = `0`;
- WA-L6 journey rows = `2`;
- Booking Ops V2 rows = `0`;
- Agenda rows = `3,206`;
- Ventas rows = `1,393`;
- Pacientes rows = `7,758`;
- Marketing leads = `6,694`;
- Call Center rows = `37,106` at closeout; the increase from the earlier L6 snapshot is normal live business traffic, not L7 DML.

WA-L7 performed no business-ledger mutation as part of deployment or certification.

## Retained strong-key boundary

WA-L6 remains the authoritative journey dependency:

`provider touchpoint → conversation_id → AGV2 BOOK/REBOOK → appointment_id → attendance → explicit venta_id_match → canonical venta_id`.

WA-L7 adds monetary reconciliation only through those strong identifiers. It does **not** introduce phone/name/username/BSUID-only attribution or identity joins.

## Continuation boundary

`WA-L8 — Security Gate for Autonomous Canary` is now **NEXT ELIGIBLE / NOT STARTED**.

This closeout does **not** authorize:

- `AUTO_OFF → CANARY`;
- disengaging the kill switch;
- autonomous reply/send/routing;
- provider autonomous dispatch;
- bulk sends/broadcasts;
- soft identity attribution;
- WA-L9 or WA-L10 implementation.

Any CANARY transition remains a separate owner authorization and production certification boundary.

The transversal reliability doctrine remains binding: `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`.
