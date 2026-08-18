# ASCENDA OS — S15.4 Web Push Retired-Subscription Recovery

**Date:** 2026-08-17 Lima  
**Workstream:** `WA-*` / S14-S15 notification transport  
**Production Supabase:** `ituyqwstonmhnfshnaqz`  

## Incident evidence

After S15.3 repaired the WhatsApp webhook framing regression, the real physical canary `PRUEBA 6 S15.3` proved the inbound path healthy:

- canonical message persisted in `aos_wa_messages_v1`;
- canonical event `message.received` persisted in `aos_wa_events_v1`;
- conversation remained `HUMAN_ACTIVE` with owner CESAR;
- conversation counters and preview updated correctly.

The same canary created a Web Push dispatch, but the push provider returned HTTP **410 Gone** (`WEB_PUSH_410`). This proves the notification dispatch path executed but the browser/PWA endpoint registered earlier was no longer accepted by the push provider.

## Root cause

S14 correctly retired a subscription after provider `404/410` by setting `active=false` and incrementing `failure_count`. However, the browser boot flow reused `PushManager.getSubscription()` and called the subscription upsert again. The original upsert blindly reactivated any matching endpoint and reset its failure counter.

That created a potential recovery loop:

`provider 410 -> DB inactive -> PWA reopens -> same local endpoint re-upserted active -> provider 410 again`.

## S15.4 remediation

Production migration ledger:

`20260818013809_s15_4_push_retired_subscription_recovery`

The subscription RPC now treats an inactive endpoint with recorded failures and identical endpoint keys as terminal. It returns:

- `ok=true`
- `registered=false`
- `reset_required=true`
- `reason=PUSH_SUBSCRIPTION_RETIRED`

without reactivating the row.

The PWA client consumes `reset_required=true`, calls `PushSubscription.unsubscribe()` locally, requests a fresh PushManager subscription using the existing VAPID public key and registers the new endpoint. Recovery is attempted once; if the provider/browser returns the same retired identity again, the client fails closed with `PUSH_SUBSCRIPTION_RECOVERY_FAILED` rather than looping.

## Production smoke already completed

A server-side replay of the current retired CESAR subscription returned `reset_required=true`. The stale row remained `active=false`, `failure_count=1`, proving the migration does not resurrect terminal subscriptions.

## Invariants learned

1. Provider `404/410` is a terminal identity signal, not a transient delivery failure.
2. Server-side retirement is insufficient if browser state still exposes the same PushSubscription.
3. Subscription upsert must distinguish manual disable/re-enable from provider-terminal retirement.
4. Recovery requires coordinated server signal + browser `unsubscribe()` + fresh `subscribe()`.
5. No Web Push layer is certified only because a subscription row exists; a real provider delivery must reach `DELIVERED`.

## Remaining certification gate

After deployment of the client recovery:

1. reopen ASCENDA PWA with notification permission already granted;
2. verify old subscription stays inactive and a new active subscription appears;
3. send a new inbound WhatsApp canary while ASCENDA is fully closed;
4. require dispatch `DELIVERED`, native Windows notification and successful click/deep-link;
5. only then execute the pending legacy notification ACL cutover.
