# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-16 America/Lima  
**ACTIVE PRODUCT LANE:** `AGENDA-UX-V1 — DESIGN MAY START ON STABLE BOOKING CORE`  
**BOOKING CLOSEOUT STATUS:** `BOOKING-V3.9 / COORD-CITAS-V1.1 — TECHNICAL PASS · HUMAN CLOSEOUT PARTIAL`  
**OWNER AUTHORIZATION:** `validar baseline y comenzar diseño nuevo de Agenda sin alterar el core`  
**PAUSED HIGH/CRITICAL LANE:** `CONV-L4 #508 — preserved; resume only by explicit owner reprioritization`  
**Production safety:** Conversations autonomy remains `SAFE-OFF`.

## Stable functional baseline

- Canonical appointment ledger: `public.aos_agenda_citas`. No parallel agenda/backend.
- Public booking confirmation: complete Zi Vital data contract + branding from `aos_configuracion`.
- Owner visually approved the refreshed booking confirmation email on 2026-09-16: **HUMAN PASS**.
- Patient 360 canonical selection/fusion handling is deployed; owner confirmed patient records can be opened again: **HUMAN PASS**.
- Governed `Mi link web` center is deployed; owner confirmed the new panel is visible and acceptable: **HUMAN PASS**.
- Production readback: **10 active users / 10 active permanent advisor links**.
- Admin monitor exposes `Web`; current readback remains **3 organic WEB bookings / 0 personal-link bookings** before personal-link canary.
- Coordination Comercial receives appointment reports from the canonical appointment ledger.
- First live automatic report (RUVILA / reactivated appointment) was written with `report_status=SENT`, no error, and owner approved the visual structure: **HUMAN PASS**.
- Comercial canonical group membership: CESAR, SRA CARMEN, MIREYA, RODRIGO, RUVILA, WILMER.
- Automatic report human template V1.1:
  classification → patient → DNI/CE → phone → email → sede → date → time → treatment → attention/professional → observations → advisor/origin.
  Internal appointment ID/channel/campaign remain auditable in DB but are omitted from the visible card.

## Coordination composer

- Both advisor and admin coordination surfaces were patched against DOM replacement while typing.
- Admin coordination redundant overlapping 15s poll was removed; 8s channel refresh remains authoritative.
- Draft/focus/cursor preservation and typing guards are deployed.
- Latest production deployment containing these changes reached **SUCCESS**.
- **Human micro-canary still required:** type continuously for >10 seconds in Coordination and confirm the text no longer clears before send.

## Advisor personal-link attribution

- Governed dashboard RPC: `aos_booking_advisor_link_dashboard_v38(p_token)`.
- User identity derives from canonical app session; callers cannot select another advisor.
- Invalid app token returns `UNAUTHORIZED`.
- UI exposes one personal permanent tokenized link per user.
- **Human personal-link canary still required:** the owner must create one booking from the copied `Mi link web` URL containing `?t=...`.
- Expected evidence: `source_channel=ADVISOR_LINK` + owner user ID + non-null `source_link_token`.
- Only after this owner canary should every advisor create one controlled booking from their own link.

## COORD-CITAS automatic trigger

- Trigger: `trg_zzz_aos_coord_appointment_report_v1` on INSERT of canonical `aos_agenda_citas`.
- Covers Agenda, Call Center, direct Agenda, organic WEB, advisor links, EMAIL and future governed booking surfaces because it observes the canonical ledger rather than individual UIs.
- Reporting failures are isolated and never block booking persistence.
- Idempotency/audit ledger: `aos_coord_appointment_reports`.
- Current production evidence: **1 report / 1 SENT / 0 ERROR**.

## Production runtime

- Current Railway production deployment `719a621f-442e-499a-87fc-367e92a8301f`
- Commit: `395ef1dd90e6d3a51e9f41d5d9d3a3bcfa1ae14f`
- Status: **SUCCESS**.

## Agenda redesign authorization

The Agenda visual redesign may begin now because the booking core, patient identity, email, Google integration, link authority, source attribution and coordination reporting are separated from presentation.

Design rules:
1. Do not create a second appointment ledger or booking API.
2. Preserve `aos_agenda_citas` as authority.
3. Preserve booking classification/attribution contracts.
4. Preserve notification, Zi Vital email and Google Calendar/Contacts flows.
5. UI/theme changes may alter layout, colors, typography, hierarchy and interaction design only through governed existing contracts.
6. The future ASCENDA CLINIC website/theme remains presentation-only and consumes the same core.

## Remaining human closeout while Agenda UX work proceeds

1. Coordination composer >10-second typing micro-canary.
2. César personal-link booking → verify `ADVISOR_LINK`.
3. After owner PASS, one personal-link booking per advisor.

These checks do **not** block starting `AGENDA-UX-V1`; they block only final BOOKING-V3.9 certification.
