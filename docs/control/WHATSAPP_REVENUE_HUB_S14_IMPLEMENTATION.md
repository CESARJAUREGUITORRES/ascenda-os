# WhatsApp Revenue Hub — S14 Implementation Checkpoint

Date: 2026-08-17
Status: IMPLEMENTED IN FEATURE BRANCH / CI PENDING
Branch: `feature/wa-s14-web-push-notification-standard`

## Implemented
- Generic `AOS_PUSH_V1` notification envelope.
- Web Push subscription registration per ASCENDA actor and browser/PWA device.
- VAPID auto-provisioning with private key stored in Supabase Vault.
- F17 authenticated `/api/push/config`, `/api/push/subscribe`, `/api/push/unsubscribe` endpoints.
- F17 WhatsApp inbound push dispatch after Meta webhook acknowledgement (fail-open).
- HUMAN_ACTIVE + assigned owner + INBOUND + current provider message targeting.
- Per-device dedupe delivery ledger and automatic stale subscription retirement on 404/410.
- Closed-app service-worker `push` handler.
- Duplicate suppression while an ASCENDA `/app` client is already open.
- WhatsApp channel-aware notification title/icon.
- Registered contact name with phone fallback.
- Sanitized/truncated message preview (140 characters max).
- Historical S12/S13 regression contracts updated for the explicitly approved preview policy.
- S14 dedicated CI contract and rollback SQL.

## Notification standard
Every future push channel should provide:
`version`, `channel`, `event_type`, `title`, `body`, `icon`, `badge`, `tag`, `route`, `entity_id`, `dedupe_key`, `created_at`, `data`.

## WhatsApp provider gate
Outbound remains fail-closed while Meta returns `META_190 Authentication Error`. S14 does not bypass or alter Meta authentication. Before the next outbound send test, Railway `WHATSAPP_ACCESS_TOKEN` must be replaced with a valid Meta System User token and provider-health must pass.

## Remaining gates
1. CI S14 + S12 + S13 + Ascenda baseline.
2. Apply Supabase migration.
3. Merge PR after green gates.
4. Confirm VAPID auto-provisioning and device subscription in production.
5. Closed-PWA inbound live test.
6. Replace Meta token and re-certify outbound send separately.
