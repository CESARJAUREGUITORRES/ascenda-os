# ASCENDA CONVERSATIONS — CONV-L2 READINESS CURRENT

**Program:** CONV-001 #502
**Loop:** CONV-L2 #506
**State:** CLOSED · PRODUCTION-CERTIFIED HUMAN-MESSAGING BOUNDARY
**Owner authorization:** completed bounded human round-trip proof; L3 separately authorized in SHADOW/OFFLINE mode
**Starting main:** `cc04ad1a4b0b02be7813689e0196e641af391e46`
**Certified release:** `bea297e1c390b628c94542e63bc9365b82da98ce`
**Railway deployment:** `f16fb2f4-d2a2-44e1-b8f8-9a52a4ee1717` = SUCCESS
**Provider prerequisite:** CONV-L1 #505 CLOSED / PROVIDER CERTIFIED
**AI autonomy:** SAFE-OFF throughout L2

## Goal

Make the existing ASCENDA WhatsApp Hub operational on one canonical Conversation Core for human messaging and takeover, using the certified MetaCloudAdapter instead of creating another provider path.

## L2 scope

1. Canonical conversation lifecycle and ownership authority.
2. HUMAN / AI ownership state with human takeover always dominant.
3. Assignment / handoff contract.
4. Durable message + event ledger with idempotency and single-flight.
5. Lightweight inbox summary/read model.
6. Event-driven panel transport where supported; bounded adaptive fallback only.
7. Preserve the current ASCENDA panel shell and business authorities.
8. No autonomous AI send and no new external runtime dependency.

## Impact constraints

Protected:
- Agenda / booking;
- Call Center;
- Patients / identity;
- Sales / Revenue / commissions;
- Marketing;
- shared Supabase and background workers.

No duplicate patient, pricing, booking, attribution, consent or provider authority may be created.

## Execution loop

`CURRENT audit -> authority map -> smallest L2 core slice -> contracts/CI -> performance/security -> exact merge/deploy -> panel readback -> bounded real human message -> inbound reply/readback -> duplicate/takeover negatives -> closeout`

## Certified real proof

Use only the existing owner-controlled `zi vital` test conversation.

Required proof:
- panel loads canonical conversation;
- advisor/human send travels through the certified Meta gateway;
- provider accepts exactly once;
- status reconciles to sent/delivered;
- reply returns into the same canonical conversation;
- human takeover/ownership remains authoritative;
- no duplicate send/event/message;
- no autonomous AI send;
- protected DB pressure has no material regression.

The bounded L2 proof is complete. Autonomous AI and campaign traffic remain unauthorized. L3 received its own later owner boundary and is SHADOW/OFFLINE only.

## Closeout evidence

On 2026-09-12 the owner completed the authenticated panel round trip on the existing `zi vital` test conversation:

- `CONV L2 PANEL OK` persisted once as HUMAN OUTBOUND;
- one idempotency key and one provider message id;
- Meta status reconciled to DELIVERED;
- `L2 RESPUESTA OK` persisted once as INBOUND;
- inbound `message.received` + identity verification events persisted;
- both messages remained on the same canonical conversation id;
- conversation state remained `HUMAN_ACTIVE` with an ACTIVE owner assignment;
- duplicate-body counts were exactly 1 outbound / 1 inbound;
- active autonomous allowlist = 0;
- pending outbound = 0;
- active PostgreSQL queries >2s = 0 and >5s = 0 at final readback;
- Railway received the Meta webhook with HTTP 200 and the panel visibly rendered the reply.

GitHub Issue #506 is CLOSED / completed.

## Exit

**CONV-L2 EXIT = PASS.**

Real human messaging/takeover is operational from ASCENDA's panel/core with correct provider/local reconciliation, zero duplicate send in the certified proof, responsive UI and no observed protected DB-pressure regression.

CONV-L3 #507 is now the active separately-authorized SHADOW/OFFLINE loop. This does not authorize autonomous Meta sending.
