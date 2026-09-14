# ASCENDA Conversations — CONV-L5 Certification

Issue: #509

## Objective
Prove continuity across commercial conversation, governed media, provider-approved templates, booking/rebooking preparation, explicit confirmation and deterministic human takeover without opening autonomous production authority.

## Reused certified authorities
- CONV-L1 `MetaCloudAdapter` for provider media/template transport and provider template read-model.
- CONV-L2 ownership/human takeover.
- CONV-L4 business truth and bounded ToolGateway.
- WA-L5/AGV2 booking memory, real availability, explicit-confirmation proof and transactional BOOK/REBOOK authority.
- Agenda V2 remains the only appointment ledger; Google Calendar/Contacts side effects remain downstream of the certified booking event/outbox path.

## New L5 continuity slice
- `app/conversation-l5-continuity.js`: bounded orchestration facade.
- `aos_conv_l5_media_catalog_v1`: service-role-only allowlist for commercial image/video/document assets. Only `active=true AND approved_for_whatsapp=true` rows are exposed.
- Provider templates are exposed only when Meta reports `status=APPROVED`.
- `prepareBooking` uses `aos_wa_l5_prepare_confirmation_v1`.
- `confirmBooking` accepts only canonical inbound provider-message proof through `aos_wa_l5_mark_explicit_confirmation_v1`; it deliberately does not call the commit RPC.
- Commit authority remains `aos_wa_l5_commit_confirmed_v1`, behind existing L4 CANARY/PROD + kill-switch + allowlist gates.
- Handoff reuses `aos_wa3_handoff_request_v1`.

## Safety invariants
- AUTO_OFF remains binding in production.
- Kill switch remains engaged until separately authorized canary.
- AI send and auto reply remain OFF.
- No autonomous provider send is enabled by this L5 slice.
- No browser receives service-role credentials.
- Media URLs must be HTTPS and explicitly approved.
- Templates must be provider-approved.
- Booking write requires explicit inbound confirmation and the existing L4/AGV2 authority.
- Human takeover always wins.

## Certification sequence
1. Exact-head CONV-L5 gate PASS.
2. Existing WA-L5 booking regression PASS.
3. Meta adapter regression PASS.
4. General Ascenda CI / performance regressions PASS.
5. Merge exact head.
6. Apply additive media-catalog migration to production.
7. Railway exact-merge deployment SUCCESS.
8. Production readback: table/ACL present, autonomous controls still SAFE-OFF, provider template catalog readable, no autonomous writes.
9. Human canary: one controlled real conversation proves info → price/promo → objection → intent → real availability → explicit confirmation → booking, plus approved media/template continuity and human takeover.

The human canary is a separate manual step. Reaching canary-ready does not authorize autonomous mode or broad customer traffic.
