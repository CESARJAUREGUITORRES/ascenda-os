# WhatsApp Revenue Hub — S14 Web Push + Notification Standard

Status: BUILDING
Date: 2026-08-17
Base: S13 certified and merged

## Objective
Create a reusable ASCENDA notification transport standard with WhatsApp as the first production channel.

## Invariants
- Human WhatsApp alerts only: current owner + HUMAN_ACTIVE + INBOUND.
- AI/Copilot traffic must not generate human advisor push storms.
- Web Push delivery must never block or change Meta webhook acknowledgement.
- VAPID private key must never be committed to GitHub or exposed to the browser.
- Device subscriptions are tied to the authenticated ASCENDA actor.
- Notification payloads use a common versioned envelope for future channels.
- Channel-specific icon and route are carried in the envelope.
- WhatsApp preview is sanitized and truncated before notification delivery.

## Generic notification envelope
- version: AOS_PUSH_V1
- channel: WHATSAPP | SENTINEL | future channels
- event_type
- recipient_user_id
- title
- body
- icon
- badge
- tag
- route
- entity_id
- dedupe_key
- created_at

## S14 scope
1. Push subscription persistence per ASCENDA user/device.
2. VAPID auto-provisioning into Supabase Vault.
3. Authenticated `/api/push/config`, subscribe and unsubscribe endpoints.
4. Generic service-worker `push` and `notificationclick` handling.
5. WhatsApp notification UX: registered name, fallback phone number, sanitized message preview, WhatsApp channel icon.
6. Inbound webhook dispatch to assigned HUMAN_ACTIVE owner only.
7. Fail-open push delivery: Meta ingestion/ACK remains authoritative.
8. Delivery health and stale-subscription retirement.
9. S14 CI contract and regression gates for S12/S13.

## Provider blocker tracked separately
Current outbound Meta error observed in production UI: `META_190 Authentication Error`. It remains a provider-credential gate and must not be bypassed by S14. At the next outbound gate, replace the Railway `WHATSAPP_ACCESS_TOKEN` with a valid Meta System User token and re-run provider-health before testing send.
