# ASCENDA OS — MEMORY CURRENT

**Captured from control baseline:** `main@93fcc9a5171703ee6750f67c3c17373a323dc2ab`  
**Runtime:** S15.3; S15.4 DB recovery live, client release pending exact-current merge  
**ACTIVE WORKSTREAM:** `WA-NOTIFICATIONS-CLOSEOUT`

## Authority

Read in order:

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`
6. WhatsApp Revenue Hub CURRENT control + notification closeout docs
7. exact GitHub + live Supabase/Railway
8. `aos_memory`
9. Notion

Historical docs/chat checkpoints never override CURRENT.

## Runtime

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

S15.3 fixed Phase S → F17 buffered request framing without bypassing downstream WA4/WA3/WA2/F4.

## Active WA / Notifications state

- WA0/WA2/WA3 previously closed; WA1 and WA4 require closeout revalidation against CURRENT before final percentage/certificate.
- `PRUEBA 6 S15.3` persisted as real inbound and updated the HUMAN_ACTIVE CESAR-owned conversation, proving the inbound regression was repaired.
- the same canary created a Web Push attempt that returned provider `WEB_PUSH_410`.
- stale CESAR PWA subscription is terminal/inactive; it must not be blindly reactivated.
- production migration `20260818013809_s15_4_push_retired_subscription_recovery` is live and returns `reset_required=true` for the retired endpoint while preserving service-role-only execution.
- S15.4 client must unsubscribe the terminal PushSubscription and register a fresh provider endpoint.
- final legacy notification ACL cutover remains withheld until a real closed-PWA Push reaches `DELIVERED` and the notification click/deep-link is proven.
- Meta outbound remains separately blocked by `TOKEN_INVALID_OR_EXPIRED`; fix only after inbound + Push certification, using a long-lived System User token in Railway and never exposing the token in source/chat.

## Paused programs

- CIA: F0–F16 closed; CIA-F17 4/6; F18 blocked. Read-only while WA owns lock.
- Revenue: F1–F4 closed; F5/F6/F7 paused.
- Sentinel: F1–F13 closed/regression-only.
- KronIA: K0 closed; K1–K8 paused.
- #238/#250: maintenance lanes only; no independent concurrent mutation.

## Lock sequence

There is **no automatic next project**. Finish `WA-NOTIFICATIONS-CLOSEOUT`, reconcile GitHub/runtime/Supabase/aos_memory/Notion, then obtain/record the next explicit owner-approved lock.

## Institutional learning

- one global HIGH/CRITICAL mutable workstream;
- shared runners do not imply shared project state;
- exact-current revalidation is mandatory after every unrelated `main` advance;
- wrapper topology tests must include wire-level HTTP framing, not syntax/topology only;
- provider Push 404/410 is terminal endpoint evidence;
- a Push subscription row does not certify delivery—real provider `DELIVERED` evidence is required;
- runtime activation does not equal phase completion;
- old green CI cannot certify a stale branch;
- GitHub/runtime/live DB are technical authority; Notion is continuity and is updated last.