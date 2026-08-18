# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Captured from control baseline:** `main@93fcc9a5171703ee6750f67c3c17373a323dc2ab`  
**Runtime inherited:** S15.3 / `ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**ACTIVE PORTFOLIO OWNER:** `WA-NOTIFICATIONS-CLOSEOUT`

## Owner override

The current owner instruction is to finish and certify the WhatsApp Revenue Hub + Notifications recovery before another HIGH/CRITICAL project continues. This supersedes the earlier CIA-first handoff encoded in the previous CURRENT control layer.

## Runtime

Railway outer command remains the S15.3 chain beginning at `server-phase-s-f17.js`.

Effective chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`

## Program map

| Program | Closed / validated input | Remaining | Portfolio state |
|---|---|---|---|
| WhatsApp + Notifications | WA0/WA2/WA3 historical closure; S15.3 inbound recovery proven; S15.4 DB recovery live | fresh Push endpoint, closed-PWA DELIVERED/click, legacy ACL cutover, Meta outbound token/canary, WA closeout revalidation | **ACTIVE** |
| CIA | CIA-F0..F16 closed | CIA-F17 4/6; CIA-F18 blocked | **PAUSED / READ-ONLY** |
| Revenue | REV-F1..F4 closed | REV-F5/F6/F7 | **PAUSED** |
| Sentinel | SEN-F1..F13 closed | regression-only/deferred maintenance | **FROZEN / REGRESSION-ONLY** |
| KronIA | K0 closed | K1–K8 | **PAUSED / REBUILD FROM THEN-CURRENT** |
| Migration governance | safe owner slices | #238 owner parity; #250 baseline | **MAINTENANCE ONLY** |

## WhatsApp / Notifications live state

S15.3 physical canary `PRUEBA 6 S15.3` proved real inbound traversal and canonical persistence. The same canary exposed a provider-terminal Push subscription (`WEB_PUSH_410`).

Production Supabase now contains `20260818013809_s15_4_push_retired_subscription_recovery`, which prevents an inactive provider-terminal endpoint from being silently reactivated with identical keys and requests a browser-side reset. The stale CESAR endpoint remains inactive.

The legacy notification ACL cutover is deliberately pending until a new real closed-PWA canary reaches Push `DELIVERED` and native notification click/deep-link is proven.

Meta outbound `TOKEN_INVALID_OR_EXPIRED` is a separate known blocker and must be solved after inbound + Push certification with a long-lived System User token in Railway; no provider secret enters GitHub/chat.

## Paused inputs

### CIA
CIA-F17 remains exactly 4/6: contracts/WhatsApp bridge/outbound policy/rollback true; signed replay/idempotency and real allowlisted CIA canary not yet certified. No CIA mutation while WA owns the lock.

### Revenue
REV-F5 and later remain paused. No concurrent historical ingest/rebuild/apply or canonical patient mutation.

### KronIA
K1–K8 remain paused. Stale K1 branches/PRs are evidence only and must rebuild from future CURRENT.

### Sentinel
SEN-F1..F13 remains closed. Run only regressions required as sensors for the WA release unless a real Sentinel regression is demonstrated.

## Closeout requirement

Before WA releases the lock:

1. exact main/runtime and S15.4 merge/deploy captured;
2. fresh active Push subscription verified while terminal endpoint remains inactive;
3. closed-PWA inbound produces Push `DELIVERED` and native Windows notification;
4. notification click/deep-link verified;
5. duplicate/noise behavior verified;
6. final legacy notification ACL cutover applied and audited;
7. Meta outbound credential/canary resolved and controlled;
8. WA1/WA2/WA3/WA4/Phase S/S13/S14/S15 regressions re-run;
9. no unresolved HIGH/CRITICAL issue remains inside declared closeout scope;
10. GitHub CURRENT docs + `aos_memory` + Notion reconciled.

The next portfolio owner is **not preassigned**; it requires an explicit owner-approved handoff after WA closeout.