# ASCENDA APP PWA V2 — Contract Freeze

Issue: #517  
Branch: `app-pwa-v2-517`  
Base SHA: `aa00b7bc75340cc956311ff1fcc6b5bd0f0e2186`

## 1. Scope

This workstream evolves ASCENDA OS as the primary installed PWA for Windows, Android and iOS Home Screen.

It MUST NOT change:
- Meta permissions;
- WhatsApp provider gateway;
- Conversation routing;
- AI send authority;
- AUTO routing;
- kill switch / SAFE-OFF;
- business authority for sales, appointments, commissions or call-center lead selection.

Notifications are side effects. Failure to notify MUST NOT fail the business transaction.

## 2. Device identity

Web Push endpoint is transport identity, not device identity.

Canonical installation identity:
- `installation_id`: random UUID generated once per installed/browser surface and persisted locally;
- `device_id`: server-side UUID mapped to authenticated user + installation_id;
- endpoint may rotate without creating a new device.

Capabilities are detected, not guessed solely from user agent:
- service_worker_supported;
- push_supported;
- notification_permission;
- badge_supported;
- tel_supported;
- standalone;
- focused/visible where available;
- os_family/form_factor are descriptive hints only.

## 3. Presence truth

Presence is effective only when state and liveness agree.

Inputs:
1. declared labor state: ACTIVO, EN LLAMADA, BREAK, BAÑO, ATENCIÓN, LIMPIEZA, CAPACITACIÓN, CIERRE_TURNO;
2. authenticated heartbeat;
3. device/session last_seen.

Rules:
- current heartbeat + declared state => state is effective;
- stale heartbeat => OFFLINE/STALE regardless of stale `aos_estado_equipo` value;
- no sensor/location/camera inference for private states;
- admin sees explicit state + elapsed time + liveness quality.

## 4. Notification lifecycle

Canonical lifecycle:
`CREATED -> ELIGIBLE -> QUEUED -> PROVIDER_ACCEPTED -> DEVICE_HANDLED -> OPENED -> ACTIONED|ACKNOWLEDGED`.

Never label PROVIDER_ACCEPTED or Web Push HTTP acceptance as read/seen.

## 5. Channels

Allowed channel vocabulary:
- WHATSAPP
- SALES
- COMMISSION
- AGENDA
- CHAT
- TASKS
- AGENTS
- SENTINEL
- SYSTEM

## 6. Priority

Canonical priority:
- LOW
- NORMAL
- HIGH
- CRITICAL

Priority belongs to the business event, not to the transport.

## 7. Privacy

Lock-screen payloads default to low-information summaries.
Sensitive patient/treatment content is revealed only after authenticated open inside ASCENDA.

## 8. TTL

Every push-eligible event must carry or derive an expiry.

Old events remain auditable in-app but expired push deliveries are not replayed.

Initial policy:
- human WhatsApp: short TTL;
- agent/sentinel critical: short TTL + escalation policy;
- sales/commission: hours;
- agenda: contextual to appointment timing;
- chat: short push TTL, persistent message;
- tasks: until due/ack policy;
- manual notifications: explicit TTL.

## 9. Foreground policy

Do not suppress OS notification merely because any ASCENDA client exists.

Policy inputs:
- client focused;
- client visibility;
- event priority;
- user/device preferences.

Default:
- focused + visible + non-critical => in-app toast/inbox;
- hidden/unfocused => OS notification;
- CRITICAL => OS + in-app, subject to dedupe and policy.

## 10. Backlog safety

Before enabling generic S15 delivery:
- snapshot pending rows;
- assign expiry;
- collapse obsolete digests;
- mark expired rows without sending;
- establish a cutover timestamp;
- enable delivery for post-cutover events only.

No mass replay.

## 11. Communication

Internal coordination uses existing `aos_mensajes` plus unified notification events.

Delivery targets:
- user;
- group;
- role;
- sede;
- all authorized users.

Urgent communication may require explicit acknowledgement.

## 12. Call-center semantics

PWA `tel:` handoff remains supported.

Current `visibilitychange` timing MUST be treated as:
- `time_outside_app_sec`, not confirmed call duration.

Confirmed call duration requires a trusted native or CTI provider source.

## 13. Rollout

Order:
1. schema/contracts;
2. actor-bound APIs;
3. inactive UI;
4. device canary;
5. push canary;
6. one advisor;
7. one sede;
8. both sedes;
9. full rollout.

Every phase requires rollback and negative-auth checks.

## 14. Non-interference gate

Files and migrations may be prepared on this branch while CONV-L1 #505 is active.

No production deployment or shared service-worker/app-shell cutover from this branch until:
- exact diff review confirms no WhatsApp/Meta runtime regression;
- current production SHA is revalidated;
- canary scope is explicitly selected.
