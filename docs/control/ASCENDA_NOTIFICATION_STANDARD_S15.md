# ASCENDA Notification Standard — S15

Status: implementation candidate, gated by PR certification and production migration.

## Canonical rule
Every new ASCENDA notification must be represented as a versioned business event and projected through the same notification layer. Modules must not create isolated browser notifications, ad-hoc polling tables, or duplicate unread counters when an existing domain counter is already authoritative.

Transport stack:

`business event -> aos_notificaciones -> in-app bell / coordination projection -> AOS_PUSH_V1 -> service worker -> OS notification`

WhatsApp keeps its real-time HUMAN_ACTIVE alert path for assigned inbound conversations and uses the same `AOS_PUSH_V1` envelope when the PWA is closed.

## Recipient identity
New events bind to `aos_usuarios.id` through `para_user_id`. Legacy `para` names remain for compatibility only. The alias `ADMIN` resolves to the active level-1/admin user.

## Channels
- `WHATSAPP` — assigned human conversations.
- `SALES` — sales activity and admin sales digests.
- `COMMISSION` — commission adjustments and commission deltas carried by sales notifications.
- `AGENDA` — appointments, attendance, no-show, cancellation and rescheduling.
- `CHAT` — internal coordination messages.
- `TASKS` — task assignment.
- `SENTINEL` — reserved canonical channel for system observability alerts; existing Sentinel dispatch remains authoritative until explicitly migrated.
- `SYSTEM` — manual/general ASCENDA notifications.

Each channel has a distinct visual identity/icon. Future channels must add their icon and policy before emitting notifications.

## Noise-control policy
Notifications are not row-by-row mirrors of every database write.

- Advisor sales: grouped in short 15-second buckets; amount and calculated commission delta accumulate.
- Admin sales: grouped in 60-second operational digests.
- Advisor new appointments: grouped in 15-second buckets.
- Admin new appointments: grouped in 60-second operational digests.
- Admin attendance/no-show: grouped in 60-second digests.
- Chat: **Web Push only**. The existing chat unread counter remains the in-app source of truth to avoid double badges.
- Task assignment and status-changing appointment events: immediate.
- Web Push dispatch uses per-device dedupe and stale subscription retirement inherited from S14.

## Event registry S15
- `SALE_ADDED`
- `ADMIN_SALES_DIGEST`
- `COMMISSION_ADJUSTED`
- `APPOINTMENT_CREATED`
- `ADMIN_APPOINTMENT_DIGEST`
- `APPOINTMENT_ATTENDED`
- `APPOINTMENT_NO_SHOW`
- `APPOINTMENT_CANCELLED`
- `APPOINTMENT_RESCHEDULED`
- `ADMIN_ATTENDED_DIGEST`
- `ADMIN_NO_SHOW_DIGEST`
- `INTERNAL_CHAT_MESSAGE`
- `TASK_ASSIGNED`
- `MANUAL_NOTIFICATION`

## UX contract
When ASCENDA is open, generic Web Push is suppressed by the service worker and delegated to the in-app notification center. The center renders a channel-distinct toast and can deep-link to the relevant module.

When ASCENDA is closed, the service worker renders the OS/PWA notification and opens the route encoded by the event.

The topbar bell, Advisor Coordination and Admin Coordination must consume the canonical notification projection rather than unrelated notification tables.

## Compatibility
Historical `aos_notificaciones` rows remain in place and are not replayed through Web Push. New columns default historical rows to `push_enabled=false` and `push_status=SKIPPED`.

The existing `aos_enviar_notificacion(...)` signature is retained and internally projects into S15.

## Safety invariants
- Notification dispatch failure must never fail a WhatsApp webhook, clinical write, sale insertion, appointment update, or the F17 runtime.
- Push pump uses overlap protection and `FOR UPDATE SKIP LOCKED` claims.
- A device receives a given `dedupe_key` at most once through the S14 dispatch ledger.
- No Meta authentication or WhatsApp ownership/routing policy is bypassed by S15.
- No synthetic production sale or appointment should be created solely to test notifications; use a manual notification or test task canary first.

## Extension procedure
For every future notification:
1. Define the business event and recipient authority.
2. Add/update `aos_notification_policies_v1` with channel, priority, aggregation window, icon and route.
3. Emit through `aos_notification_emit_v1` or a governed domain trigger/service.
4. Add CI assertions for recipient, dedupe, aggregation and routing.
5. Verify in-app + closed-PWA behavior before general activation.
