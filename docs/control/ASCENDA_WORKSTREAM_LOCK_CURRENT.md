# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L7 — WhatsApp/AI Cost Intelligence`  
**GitHub authority:** Issue `#449` = `OPEN`  
**Frozen ENTRY baseline:** `main@4a34f0f982f7d740f3d0817a04a6d7442a9f826e`  
**Last closed lane:** `WA-L6 — Meta Campaign Context & Attribution`  
**WA-L6 status:** `CLOSED · PRODUCTION CERTIFIED · DORMANT / SAFE-OFF`  
**WA-L6 certified exact-head:** `2af4f8a45d5a53179f9133ede90777d14c2be9d3`  
**WA-L6 merge SHA:** `4d29c019a46b0b624039586f37cce2356a3fc960`  
**Effective production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**CANARY:** `NOT AUTHORIZED` — separate explicit owner authorization required.

## WA-L7 active boundary

WA-L7 is the **sole mutable HIGH/CRITICAL lane**. All other HIGH/CRITICAL workstreams remain read-only/regression-only unless they are a strict dependency required to make L7 correct.

L7 must reuse existing telemetry and strong-key authorities rather than rebuild them:

- Meta status ingress already persists provider-observed `pricing_category`, `pricing_model` and `billable`;
- `aos_wa_ai_runs_v1` already persists append-only AI provider/model/token/latency/`estimated_cost_usd` telemetry;
- WA-L6 already provides strong-key attribution journey stitching from provider evidence to `conversation_id`, booking/rebook, appointment, attendance and explicit sale linkage;
- Marketing Attribution V2 remains authoritative for its existing model and must not be rewritten.

Required L7 path:

`provider pricing evidence + AI usage telemetry → governed versioned pricing authority → reconciliable cost ledger/read model → conversation_id → WA-L6 strong-key journey → booking/attendance/sale/revenue cost intelligence → bounded admin UI/KPIs`.

## Binding L7 guarantees

- no provider or AI monetary price fabrication;
- unknown/unmapped price is `UNKNOWN/PARTIAL`, never silently `0`;
- pricing authority is versioned/effective-dated so historical cost remains reproducible;
- no phone/name/username/BSUID-only cost or revenue joins;
- no heavy global analytical view on synchronous message/call/booking hot paths;
- no synchronous materialized-view refresh/rebuild on writes;
- bounded indexed reads and no synchronized browser retry fan-out;
- no synthetic PROD cost/attribution/business rows for certification;
- L4 send authority remains separate.

## WA-L6 certified closeout retained as dependency

L6 strong-key chain remains authoritative:

`provider touchpoint → conversation_id → AGV2 BOOK/REBOOK → appointment_id → attendance → explicit venta_id_match → canonical venta_id`.

Certified L6 guarantees retained:

- provider evidence only; no fabricated CTWA/ad/campaign/adset/lead IDs;
- paid CTWA, provider referral and no-provider-attribution remain explicit;
- `ad_id/campaign_id → treatment/promotion/booking_goal` requires governed evidence + admin 2FA;
- mapping audit is append-only;
- no phone/name/username/BSUID attribution joins for revenue;
- provider/mapping campaign conflicts fail closed;
- multiple provider touchpoints remain `MULTIPLE_TOUCHPOINTS_REVIEW`;
- no synthetic PROD attribution;
- Marketing Attribution V2 remains authoritative for its existing model.

## Entry safety state

At L7 entry, production remains dormant:

- mode = `AUTO_OFF`;
- kill switch = `ENGAGED`;
- effective autonomous send = `false`;
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- `human_send=true`.

Still forbidden without separate owner authorization:

- `AUTO_OFF → CANARY`;
- disengaging the kill switch;
- enabling autonomous reply/send/routing;
- autonomous provider dispatch;
- bulk sends/broadcasts;
- synthetic production attribution/cost rows;
- soft identity attribution.

## L7 exit sequence

`ENTRY audit → pricing authority Meta+AI → cost ledger/reconciliation → strong-key journey cost view → KPIs/UI → dedicated CI + L6/L5/L4 regressions + performance matrix → anti-drift → expected-head merge → Railway → Supabase PROD dormant → SAFE-OFF readback → issue closeout → release lock → Notion/CURRENT sync`.

The cross-module reliability doctrine remains binding: `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`.
