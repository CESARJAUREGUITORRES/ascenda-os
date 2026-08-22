# ASCENDA Conversations — WA-3 Multiagent V2 Impact Report

**Phase:** WA-3 — Human Operations Multiagent V2  
**Entry baseline:** `main@4428683fcd8ecf2ff46939e1b730bb2eb9d03961`  
**Risk:** HIGH  
**Strategy:** additive / fail-closed / exact-owner / Zero-Cost certification

## Objective
Complete the last operational mile of WA-3 without rewriting the certified V1 routing/ownership core: explicit agent readiness, privacy-preserving queue visibility, safe concurrent claim, supervisor readiness visibility and a small operational UI inside the existing WhatsApp Hub.

## Preserved V1 authority
WA-3 V1 remains authoritative for boxes, membership, assignments, route/reassign/release, ownership, `max_active`, append-only routing events and exact-owner human send authorization. V2 delegates the ownership mutation to `aos_wa3_claim_next_v1` and does not modify its `FOR UPDATE SKIP LOCKED` semantics.

## Additive V2 objects
- `aos_wa_agent_presence_v1`
- `aos_wa3_agent_presence_touch_v1`
- `aos_wa3_queue_summary_v1`
- `aos_wa3_claim_next_v2`
- `app/server-wa3-v2.js`
- `app/public/wa-multiagent-v2-panel.js`

## Privacy boundary
A non-owner may see only aggregate queue information for boxes where they are an active member: box identity, queued count, personal active load, capacity and claim readiness. V2 queue surfaces never return customer phone, message body, timeline or unowned conversation identifier.

## Readiness contract
Statuses: `AVAILABLE`, `AWAY`, `OFFLINE`.

Claim requires a fresh `AVAILABLE` heartbeat (120-second freshness window). `AWAY`, `OFFLINE` or stale presence fail closed. Presence transitions are audited; repeated AVAILABLE heartbeat does not create audit storms.

## Supervisor boundary
Only an authenticated WA admin may read `/api/wa3/team-summary`. The response contains operational user identity, effective readiness, active load and box memberships only; no customer data is fetched or returned.

## Runtime
The additive chain is:

`server-wa4.js → server-wa3-v2.js → server-wa3.js → server-wa2.js → lower runtime`

WA-4 remains Copilot-only and WA-3 V1 remains human-send authority.

## UI
The existing native WhatsApp Hub gains a compact operational console with:
- Disponible / Ausente / Offline;
- total queue and per-box queue counts;
- current load / max capacity;
- `Tomar siguiente`;
- claim feedback;
- admin team readiness summary.

This is not the WA-3.5 Revenue Inbox redesign. It is only the minimum UI required to certify multiagent operations.

## Security invariants
1. `whatsapp-agent` remains explicit; no automatic grants.
2. App actor resolution still requires 2FA.
3. Presence/queue/claim RPCs are service-role-only.
4. V2 server derives actor from the strong app token before any service-role mutation.
5. Agent queue visibility contains no customer PII.
6. Non-owner message/send/release isolation remains V1 authority.
7. Concurrent claims cannot create two current owners.
8. `auto_routing_enabled` stays false during the canary.
9. `ai_send_enabled` stays false.
10. `copilot_enabled` and `auto_reply_enabled` stay false.

## Tests
- existing WA-3 V1 pgTAP suite remains mandatory;
- V2 pgTAP covers panel access, 2FA, readiness, stale heartbeat, OFFLINE/AWAY denial, queue privacy and capacity;
- real concurrent two-session claim test proves exactly one current owner;
- two parallel FAST Windows lanes cover syntax/UI and security/wrapper-chain contracts;
- Zero-Cost Linux applies exact V1+V2 migrations, lint, pgTAP, concurrency and layered rollback.

## Rollback
1. Do not grant/revoke employee panels as part of the build.
2. Keep auto-routing and AI OFF.
3. Remove V2 runtime mount (`server-wa4 → server-wa3`) if runtime regression occurs.
4. Apply `20260822173000_wa3_multiagent_readiness_v2.rollback.sql` to remove only readiness/aggregate-queue V2 objects.
5. Confirm WA-3 V1 ownership/send authority remains present.
6. WA-1/WA-2 and Notifications S13-S15.5 remain untouched.

## Production canary gate
Infrastructure may deploy before employee access is granted. Final WA-3 certification requires explicit owner selection of two real canary users, controlled `whatsapp-agent` grant + `VENTAS_GENERAL` membership, small `max_active`, Agent A claim, Agent B negative cross-owner checks, release, Agent B claim and exact ownership-transfer evidence.

Meta token is not rotated pre-emptively. After deploy, `/api/wa3/provider-health` decides whether credential action is necessary.
