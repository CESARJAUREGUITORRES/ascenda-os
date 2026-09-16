# BOOKING-V3.1 — Attribution

## Goal
Every appointment can be measured by acquisition source without changing booking/calendar authority.

Canonical channels: `WEB`, `EMAIL_MARKETING`, `ADVISOR_LINK`, `WHATSAPP`, `CALL_CENTER`, `MANUAL`.

Dimensions: source channel, campaign, advisor, link token, appointment id and Lima booking date.

## Compatibility
Legacy `WEB-PUBLICA` maps to `WEB`. Legacy `AUTO-AGENDA` maps to `ADVISOR_LINK`. Existing `asesor` remains the advisor attribution authority. Existing notification events remain the only notification stream.

## Admin counters
`aos_booking_attribution_daily_v1` exposes daily counts by source/campaign/advisor. These counters are admin analytics and must not be mixed with Call Center competitive score.

## Canary gate
1. Open permanent/public booking URL and create a test appointment.
2. Verify appointment appears in Agenda and source is WEB.
3. Generate an advisor link, create a second test appointment, verify source ADVISOR_LINK and advisor attribution.
4. Verify existing confirmation email/calendar path remains operational.
5. Verify admin in-app notification and Web Push on the authorized PWA.
6. Verify advisor notification only for the attributed advisor according to existing policy.
7. Verify daily attribution counter increments exactly once per appointment.
8. Verify desktop and Samsung portrait/landscape remain usable.

Human canary is PASS only after real-device notification delivery is observed; deployment success alone is not sufficient.
