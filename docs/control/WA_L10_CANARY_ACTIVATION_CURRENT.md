# WA-L10 — CURRENT CANARY ACTIVATION CONTRACT

**Date:** 2026-09-04 America/Lima  
**Issue:** #456  
**Entry main:** `4f4b3bef8073c04971418d8653e34695a9e89682`  
**Branch:** `wa-l10-live-canary-bridge-20260904`  
**Authorization ref:** `OWNER-CHAT-20260904-L10-ZIVITAL-CANARY`

## Production evidence before this branch

- Meta inbound webhook reaches ASCENDA and persists the current test conversation.
- Human-owned ASCENDA outbound reaches the real WhatsApp test number and Meta delivery callbacks return through the webhook.
- `/api/wa3/provider-health` returned HTTP 200 after the refreshed credential was deployed.
- WA4 startup reports `copilotReady=true`; production model secrets are loaded server-side.
- L4 production remains `AUTO_OFF`, kill switch engaged, auto reply/send/routing OFF, human-send ON and active autonomous allowlist count zero.
- Current test conversation is `9c48cc78-2ca0-48ee-8011-cb7fc2081996`; before activation it is human-owned / `AI_COPILOT`, so L4 correctly refuses autonomous send until an explicit governed ownership return occurs.

## Why the bridge is required

The signed F4 webhook currently persists inbound messages and acknowledges Meta but does not invoke WA4 AI or `/api/wa/auto-send`. Existing L4/L8 already provide the correct provider-send authority, so L10 adds orchestration only:

`signed inbound -> durable provider_message job -> existing WA4 governed suggestion -> L8 -> L4 -> existing /api/wa/auto-send -> Meta`

No second sender or second authority is created.

## Effective-once contract

- A provider message id is durably queued only when effective L4 CANARY is active, the conversation has exact L10 run scope, the L4 allowlist contains that exact conversation, and no human ownership/takeover/handoff boundary is active.
- Work is claimed with at most two append-only attempts. A second attempt is possible only after a stale lease, for crash recovery; there is no timer/polling/retry loop.
- The outbound idempotency key is a deterministic SHA-256 function of the inbound provider message id.
- L4 authority and the existing outbound reservation remain the final duplicate guard.
- Terminal SENT/BLOCKED/HANDOFF/ERROR outcomes are append-only, redacted evidence.

## Governed return from human ownership

`aos_wa_l10_return_to_autonomous_canary_v1` may run only for a level-1 WhatsApp administrator and only after:

1. the L10 run and exact conversation scope exist;
2. the scope recipient hash still matches the conversation canonical address;
3. L4 is effective CANARY with kill switch disengaged;
4. an active exact `CONVERSATION` allowlist entry exists.

The function releases current ACTIVE/QUEUED assignment rows as historical `RELEASED`, writes a routing audit event, clears current owner/takeover/handoff projections and sets the conversation to `AI_ACTIVE`. It does not delete ownership history.

## Deployment/activation order

1. Exact-head CI PASS while production remains SAFE-OFF.
2. Protected merge to main.
3. Apply merged L10 bridge migration before the new Railway container begins serving CANARY traffic.
4. Railway SUCCESS + WA4 bridge startup marker + provider health recheck.
5. Freeze fresh PRE counts and create one L10 run while SAFE-OFF.
6. Attach only conversation `9c48cc78-2ca0-48ee-8011-cb7fc2081996` using its recipient hash.
7. Add a short-lived L4 `CONVERSATION` allowlist entry for that exact UUID.
8. Call existing L4 control with `mode=CANARY`, kill switch false, bounded limits and authorization ref `OWNER-CHAT-20260904-L10-ZIVITAL-CANARY`.
9. Call governed return-to-autonomous for that same run/conversation.
10. Read back effective CANARY + exact scope + `AI_ACTIVE` ownerless state before asking for the first customer-side test message.

## Initial limits

Initial live canary target: one exact conversation, no broad routing, maximum 6 autonomous turns/conversation, daily cap 12, global rate 3/min, conversation rate 1/min, cooldown 10 seconds, duplicate window 120 seconds. Human sending remains globally available but requires human ownership; auto-routing remains OFF.

## Immediate stop conditions

Return to `AUTO_OFF + kill=true`, deactivate the exact allowlist and request human handoff on any privacy/identity or consent violation, duplicate delivery, wrong governed fact/price, unsafe clinical response, invalid booking mutation, provider/local divergence, repeated model/provider failure, runaway activity, budget breach or P0/cross-module regression.

## L11 boundary

This authorization and implementation are only for L10 CANARY. They do not authorize general-production `PROD`, broad allowlisting or L11 rollout.
