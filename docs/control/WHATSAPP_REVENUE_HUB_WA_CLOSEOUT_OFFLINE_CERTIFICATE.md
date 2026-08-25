# ASCENDA Conversations — WA-CLOSEOUT OFFLINE CERTIFICATE

**Captured:** 2026-08-24 America/Lima  
**Runtime baseline:** `main@43c1ac717622b9c1a809f6883980e7e60f00ef89`  
**Source merge:** PR #368 — Supabase 402 quota circuit  
**Certification mode:** CODE / CI / ZERO-COST / no Supabase Cloud mutation

## Verdict model

This certificate uses three states only:

- `PASS-OFFLINE`: code/contract/Zero-Cost evidence is complete for the implemented capability.
- `BLOCKED-LIVE`: implementation is ready but production evidence cannot be renewed while Supabase returns HTTP 402 or while an external provider canary is unavailable.
- `FUTURE-PHASE`: approved roadmap capability that is not part of WA-3 closeout and must not be counted as a defect in this certificate.

There are no `UNKNOWN` rows in the implemented WA-1 → WA-3 / notifications / WA-4-infrastructure scope.

## Evidence anchor

PR #368 exact head: `81f7f6e5f329bc9184f4d4f611de6d0ca48b5608`.

Exact-head successful gates for that final head:

- Ascenda CI — run `32792393890` — PASS.
- Phase S WA3 Stabilization — run `32792393973` — PASS; includes the final quota-circuit behavioral contract.
- WA-2 Conversation Store & Live Inbox Zero-Cost — run `32792393969` — PASS.
- WA-3 V2 Multiagent FAST — run `32792393859` — PASS.
- WA-3 Boxes Routing Handoff / Zero-Cost — run `32792393938` — PASS.
- S15 Unified Notification Events — run `32792393894` — PASS.
- WA-4 AI Sales Router — run `32792393949` — PASS.
- Performance Guard — run `32792393960` — PASS.
- ASC-PERF Audit 360 — run `32792393877` — PASS.

The same exact tree was merged as `main@43c1ac717622b9c1a809f6883980e7e60f00ef89`, and Railway reported SUCCESS for that merge SHA.

Sentinel F4's independent `F2_PUBLIC_HTML_DRIFT` is an existing cross-workstream static fingerprint debt and is not created by WA-CLOSEOUT. It is not reclassified as a WhatsApp defect.

## Capability matrix

| Capability | Offline verdict | Evidence / boundary |
|---|---|---|
| Meta webhook HMAC over exact raw bytes | PASS-OFFLINE | WA-1 helper tests + aggregate closeout contract |
| Replay identity / provider_message_id / event_key | PASS-OFFLINE | WA-1 tests + deterministic replay fixture |
| Canonical conversation projection | PASS-OFFLINE | WA-2 Zero-Cost pgTAP |
| Duplicate provider retry without count/unread inflation | PASS-OFFLINE | WA-2 pgTAP |
| Out-of-order inbound chronology | PASS-OFFLINE | WA-2 pgTAP protects latest preview/reopen/read boundaries |
| Governed outbound text/template/image/document/audio link payloads | PASS-OFFLINE | WA-1 helper tests + closeout media fixture; this is not WA-5 private media storage |
| Idempotent outbound reservation | PASS-OFFLINE | source/runtime contract on `aos_wa_outbound_requests_v1` |
| Ambiguous Meta timeout/missing message id | PASS-OFFLINE | remains `PENDING`, `retry_safe:false`; no blind resend |
| Definite provider rejection | PASS-OFFLINE | fail-closed FAILED path |
| Delivery `sent/delivered/read/failed` projection | PASS-OFFLINE | gateway source + S13 timeline contract |
| Auth V3 / 2FA continuity | PASS-OFFLINE | server actor gate + cache bridge; no strong-token localStorage downgrade |
| Explicit `whatsapp-agent` access | PASS-OFFLINE | WA-3 V2 pgTAP |
| Presence AVAILABLE/AWAY/OFFLINE + stale fail-closed | PASS-OFFLINE | WA-3 V2/final pgTAP + physical MIREYA presence canary |
| `max_active` capacity | PASS-OFFLINE | WA-3 V2 pgTAP |
| Human queue privacy | PASS-OFFLINE | aggregate queue exposes no phone/conversation id |
| Explicit handoff | PASS-OFFLINE | only `HUMAN_REQUESTED` is claimable; repeat request idempotent |
| Concurrent claim | PASS-OFFLINE | WA-3 Zero-Cost single-owner concurrency gate |
| Exact-owner human send boundary | PASS-OFFLINE | WA-3/Phase S source+contract |
| Supervisor/manual intervention | PASS-OFFLINE | WA-3 final contract |
| Release/reassign primitives and audit | PASS-OFFLINE | WA-3 contracts; release does not silently enable bot automation |
| Alert exact-owner + HUMAN_ACTIVE + inbound-only | PASS-OFFLINE | S12/S13/S14/S15 contracts |
| Closed-PWA Web Push / notification auth bridge | PASS-OFFLINE | S14/S15.4/S15.5 regression contracts |
| AI Copilot infrastructure safe-OFF | PASS-OFFLINE | WA-4 exact-owner/budget/audit tests; `copilot=false`, `auto_reply=false` |
| AI autonomous send | FUTURE-PHASE | intentionally OFF; controlled autonomy belongs to later gates |
| Supabase 402 retry storm containment | PASS-OFFLINE | PR #368 circuit: WA runtime family, host-scoped, process-local, single probe |
| Current Meta credential/provider readiness | BLOCKED-LIVE | requires provider health + real allowlisted canary |
| Current Supabase read/write production path | BLOCKED-LIVE | require observed `402 → 200` before live certification |
| Consolidated CESAR↔MIREYA human handoff/send/reassign canary | BLOCKED-LIVE | production-only evidence still required |
| WA-3.5 Revenue Inbox UX | FUTURE-PHASE | next active build after this closeout |
| WA-7A attribution ingress | FUTURE-PHASE | follows WA-3.5 |
| WA-4A/B/C knowledge/playbook/copilot | FUTURE-PHASE | cannot be collapsed into existing WA-4 infrastructure |
| WA-5 private multimedia/STT/media library | FUTURE-PHASE | HTTPS payload support is not private media pipeline certification |
| WA-6 Agenda/follow-up/call tools | FUTURE-PHASE | reuse canonical ASCENDA systems |

## Canonical lifecycle note

The current persisted conversation state model uses:

`NEW / AI_ACTIVE / HUMAN_REQUESTED / HUMAN_ACTIVE / AI_COPILOT / WAITING_CUSTOMER / APPOINTMENT_PENDING / APPOINTMENT_BOOKED / WON / LOST / CLOSED`.

There is no separate literal `BOT_ACTIVE` state in the current schema. Do not add one merely to satisfy checklist wording. Bot/non-human handling must be interpreted through the canonical state and routing contracts until WA-4B formalizes Handling State vs Sales Stage.

## Production hold

`WA CODE / CI / ZERO-COST = eligible for offline certification once the aggregate WA-CLOSEOUT workflow is green at PR #369 exact head.`

`WA PRODUCTION CERTIFIED 100% = NOT YET.`

Production certification remains fail-closed until all of the following are observed on one exact deployed SHA:

1. Supabase `402 → 200` recovery;
2. Railway exact-SHA success and `/health`;
3. Auth V3 + 2FA continuity;
4. provider health current;
5. signed inbound real event;
6. allowlisted human outbound within the 24h customer window;
7. sent/delivered/read or explicit terminal provider state;
8. explicit `HUMAN_REQUESTED → queue → claim → send → reassign → access isolation → readback/release` canary with CESAR/MIREYA;
9. alert and notification smoke;
10. egress/request-rate observation after the 402 circuit is live.

## Next lock

After PR #369 is green/merged and GitHub/Notion are reconciled, the mutable WhatsApp lock moves to:

`WA-3.5 — Revenue Inbox UX`.
