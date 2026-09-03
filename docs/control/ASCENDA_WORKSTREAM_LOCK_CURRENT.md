# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L6 — Meta Campaign Context & Attribution`  
**GitHub authority:** Issue `#447`  
**Entry main:** `e790153523c4cc0d842b57cd57544dadc1a0c85a`  
**Branch:** `wa-l6-meta-ctwa-attribution-20260903`  
**Last closed lane:** `WA-L5 — Conversational BOOK/REBOOK Wiring`  
**Effective production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**CANARY:** `NOT AUTHORIZED` — separate explicit owner authorization required for autonomous send.

## WA-L6 objective

Expand explicit Meta Click-to-WhatsApp acquisition evidence into governed campaign context and explainable downstream attribution:

`Meta/CTWA evidence → conversation → explicit campaign context → BOOK/REBOOK → appointment → attendance → sale/revenue`.

Attribution must remain evidence-driven. Phone, name, username, BSUID or canonical patient identity alone never establish acquisition provenance.

## LIVE entry snapshot

Read immediately before acquiring L6:

- WA-L5 = `CLOSED · PRODUCTION CERTIFIED · DORMANT`;
- L4 mode = `AUTO_OFF`;
- kill switch = `ENGAGED`;
- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`;
- WhatsApp conversations = `2`;
- WhatsApp messages = `21`;
- WA events = `39`;
- `aos_wa_attribution_touchpoints_v1 = 0`;
- `aos_wa4_campaign_context_map_v1 = 0`;
- `aos_wa4_booking_actions_v1 = 0`;
- `aos_booking_operations_v2 = 0`;
- `aos_agenda_events_v2 = 0`;
- Agenda total = `3,205`;
- Ventas = `1,393` at entry readback.

The existing WA-7A.3 ingress already stores provider-supplied referral/CTWA evidence in append-only `aos_wa_events_v1` and exposes private `aos_wa_attribution_touchpoints_v1`. L6 must reuse that authority rather than create a parallel customer/touchpoint master.

## Frozen L6 behavior

- preserve explicit provider referral/CTWA/source evidence only;
- `ctwa_clid`, `ad_id`, `campaign_id`, `adset_id` and provider lead identifiers may exist only when directly supplied by trusted provider evidence;
- organic WhatsApp must remain explicitly separate from paid Meta/CTWA;
- `ad_id/campaign_id → treatment/promotion/booking_goal` requires explicit evidence-backed governed mapping;
- no inference from ad/campaign names, headlines, URLs, phone, identity or treatment text;
- mapping writes are server-governed and auditable; browser/runtime direct writes remain denied;
- revenue stitching uses explicit keys: touchpoint/conversation → AGV2 booking operation → appointment → explicit `venta_id_match` → canonical sale;
- attendance derives from the appointment state, not from phone/name similarity;
- multiple valid touchpoints may coexist and must remain visible rather than silently collapsed;
- no `aos_leads`, `aos_pacientes`, canonical Agenda or canonical Sales mutation merely to certify L6;
- Marketing Attribution V2 remains authoritative for its existing lead/call/cita/sale model and is not rewritten;
- a fresh real provider CTWA click is a separate LIVE evidence gate and may remain `LIVE_PENDING` if no real referral arrives during certification.

## L6 exit gates

1. deterministic provider referral/campaign parser contract;
2. explicit paid Meta/CTWA vs organic classification;
3. governed evidence-backed campaign-context authority;
4. deterministic conversation → BOOK/REBOOK → attendance → sale stitch using explicit IDs only;
5. ambiguity/fabrication/phone-only attribution fail closed;
6. dedicated L6 CI + WA-7A.3 ingress + WA4C/L4/L5 + AGV2 regressions GREEN;
7. cross-module regression: Agenda, Call Center, Marketing, Sales/Commissions, Patients/Identity, shared DB pressure;
8. anti-drift;
9. expected-head merge;
10. DDL/runtime deployment from merged lineage;
11. LIVE readback while `AUTO_OFF + kill switch ON`;
12. no synthetic production touchpoint/campaign/revenue attribution inserted for certification;
13. issue closeout + Notion/CURRENT sync.

## Frozen prerequisite

WA-L4 and WA-L5 remain `CLOSED · PRODUCTION CERTIFIED`. L6 does not weaken L4 authority controls, does not bypass AGV2 transactional booking authority, and does not authorize autonomous outbound.

The cross-module reliability doctrine remains binding:
`docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`.

## Still forbidden without separate authorization

- `AUTO_OFF → CANARY` for autonomous WhatsApp;
- disengaging the L4 kill switch;
- `auto_reply_enabled=true`;
- `ai_send_enabled=true`;
- autonomous `auto_routing_enabled=true`;
- autonomous Meta dispatch;
- bulk sends/broadcasts/campaign activation;
- Meta Ads bulk sync or campaign creation;
- synthetic production attribution evidence;
- phone/name-only revenue attribution.
