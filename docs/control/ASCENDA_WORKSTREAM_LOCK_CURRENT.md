# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `NONE`  
**Last closed lane:** `WA-L6 — Meta Campaign Context & Attribution`  
**WA-L6 status:** `CLOSED · PRODUCTION CERTIFIED · DORMANT / SAFE-OFF`  
**GitHub authority:** Issue `#447` = `CLOSED / completed`  
**Certified exact-head:** `2af4f8a45d5a53179f9133ede90777d14c2be9d3`  
**Merge SHA:** `4d29c019a46b0b624039586f37cce2356a3fc960`  
**Supabase migration:** `wa_l6_meta_attribution_v1` · LIVE version `20260903171338`  
**NEXT ELIGIBLE:** `WA-L7 — NOT STARTED`  
**Effective production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**CANARY:** `NOT AUTHORIZED` — separate explicit owner authorization required.

## WA-L6 certified closeout

L6 extended provider-supplied Meta/CTWA evidence into governed and explainable attribution without guessing customer acquisition provenance:

`provider touchpoint → conversation_id → AGV2 BOOK/REBOOK → appointment_id → attendance → explicit venta_id_match → canonical venta_id`.

Certified guarantees:

- provider evidence only; no fabricated CTWA/ad/campaign/adset/lead IDs;
- paid CTWA, provider referral and no-provider-attribution remain explicit;
- `ad_id/campaign_id → treatment/promotion/booking_goal` requires governed evidence + admin 2FA;
- mapping audit is append-only;
- no phone/name/username/BSUID attribution joins for revenue;
- provider/mapping campaign conflicts fail closed;
- multiple provider touchpoints remain `MULTIPLE_TOUCHPOINTS_REVIEW`; no silent first/last-touch selection;
- no synthetic PROD attribution was inserted during certification;
- Marketing Attribution V2 remains authoritative for its existing model and was not rewritten.

## Certification evidence

- PR `#448` merged with expected-head protection;
- exact-head CI = `10/10 SUCCESS` including dedicated L6, WA-7A.3/7A.2/7A.0, WA-1, WA4C FULL LOCAL, Performance Guard, Audit 360, PHASE S WA3 and Ascenda CI;
- anti-drift = PASS;
- Railway = SUCCESS on merge SHA;
- LIVE objects present: `aos_wa_l6_campaign_context_audit_v1`, `aos_wa_l6_conversation_acquisition_v1`, `aos_wa_l6_attribution_journey_v1`;
- governed RPC present: `aos_wa_l6_campaign_context_upsert_v1(text,jsonb)`;
- L6 audit rows after deploy = `0`;
- active governed campaign mappings after deploy = `0`;
- no L6-specific security/performance WARN/ERROR blocker; global advisor backlog remains separate.

## LIVE dormant safety readback

- mode = `AUTO_OFF`;
- kill switch = `ENGAGED`;
- effective autonomous send = `false`;
- active allowlist = `0`;
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- `human_send=true`;
- autonomous decisions = `0`;
- AUTO outbound requests = `0`;
- authority-bound outbound = `0`;
- WA4 booking actions = `0`;
- Booking Ops V2 = `0`;
- Agenda Events V2 = `0`.

## Cross-module readback at closeout

- Agenda = `3,206`;
- Call Center = `37,100`;
- Marketing leads = `6,694`;
- Ventas = `1,393`;
- Commissions rows = `0`;
- Pacientes = `7,758`.

These are current LIVE counts and may evolve with normal production activity. L6 deployment was DDL/read-only attribution authority and did not perform certification DML against Agenda, Leads, Sales or Patients.

## Next boundary

`WA-L7` is **eligible but NOT STARTED**. No HIGH/CRITICAL lane is currently acquired.

Still forbidden without separate owner authorization:

- `AUTO_OFF → CANARY`;
- disengaging the kill switch;
- enabling `auto_reply`, `ai_send` or autonomous routing;
- autonomous provider dispatch;
- bulk sends/broadcasts;
- synthetic production attribution;
- phone/name-only attribution.

A fresh real CTWA provider proof remains a later LIVE evidence gate and does not block the dormant L6 production certification.

The cross-module reliability doctrine remains binding: `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`.
