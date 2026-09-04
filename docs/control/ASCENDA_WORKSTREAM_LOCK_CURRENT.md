# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-04 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L10 #456 — EVENT-DRIVEN AUTONOMOUS CANARY BRIDGE + TINY REAL CANARY`  
**GitHub authority:** Issue `#456` = `OPEN / ACTIVE`  
**Parent roadmap:** Issue `#410`  
**Exact entry main:** `4f4b3bef8073c04971418d8653e34695a9e89682`  
**Active branch:** `wa-l10-live-canary-bridge-20260904`  
**Last deployed L10 layer:** `L10-A SAFE-OFF observability · PR #463`  
**Build/certification safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**L10 CANARY owner authorization:** `GRANTED · EXACT CURRENT TEST CONVERSATION ONLY`  
**Authorization ref:** `OWNER-CHAT-20260904-L10-ZIVITAL-CANARY`  
**L11/general PROD:** `NOT AUTHORIZED`

## Fresh entry and owner gate

PR #463 merged the certified L10-A SAFE-OFF preparation to exact `main@4f4b3bef8073c04971418d8653e34695a9e89682`; Railway and Supabase production readbacks are healthy. Production WhatsApp inbound and human outbound were then proven live with the refreshed Meta token, and WA4 reported `copilotReady=true`.

On 2026-09-04 the owner separately authorized the previously frozen L10 CANARY sequence for only the current Zi Vital test conversation. The authorization is recorded on issue #456 and does not authorize broad customer traffic or L11.

## Authorized mutable scope

1. Build a durable event-driven bridge from a newly persisted inbound Meta `provider_message_id` to the existing governed WA4 conversation engine.
2. Enforce effective-once delivery using a durable provider-message job, bounded crash lease and deterministic idempotency; no polling or provider retry loop.
3. Keep L8 preflight + L4 as the only path permitted to authorize `/api/wa/auto-send`; the bridge may never call Meta directly.
4. Add an explicit level-1 `return_to_autonomous_canary` transition that releases current human assignment state without deleting assignment/routing history, and only when exact L10 scope + exact L4 conversation allowlist + effective CANARY are all present.
5. Certify code/DB/security/P0 regressions while production remains SAFE-OFF.
6. After exact-head merge, Railway SUCCESS and merged-lineage Supabase migration, prepare one L10 run, attach only the current test conversation, activate only that exact `CONVERSATION` allowlist, transition L4 `AUTO_OFF → CANARY`, disengage kill switch, and return that conversation to `AI_ACTIVE`.
7. Run a tiny real conversation canary with bounded turns; stop immediately on privacy, consent, duplicate, wrong fact/price, unsafe clinical, booking, provider/local divergence, runaway, budget or P0 regression.

## Binding invariants during implementation/certification

- Production stays `AUTO_OFF` and kill switch engaged until exact-head code + DB gates pass and the merged runtime is deployed.
- `auto_reply=false`, `ai_send=false`, `auto_routing=false`, `human_send=true` during build/certification.
- No live autonomous provider dispatch before activation readback.
- No active customer allowlist before the merged bridge/migration is certified.
- L4 remains the sole `AUTO_OFF|CANARY|PROD` authority; L8 remains mandatory preflight.
- L5/L6/L7 remain canonical booking, attribution and cost authorities.
- Human handoff always overrides autonomy; an owned/taken-over conversation cannot enqueue autonomous work.
- No browser-held provider/internal secrets, no raw webhook/message-body/recipient storage in L10 evidence.
- No second sender, second AI authority, browser polling, autonomous retry loop, timeout inflation or materialized hot-path analytics.

## Activation boundary now authorized

The owner authorization permits the existing L4 state machine to enter **CANARY only after** this branch reaches exact-head PASS, protected merge, Railway SUCCESS and merged-lineage Supabase PASS. The cohort is fixed to the current Zi Vital test conversation; broader PHONE/CAMPAIGN allowlisting is outside this authorization.

Activation must use authorization ref `OWNER-CHAT-20260904-L10-ZIVITAL-CANARY`, a short-lived exact `CONVERSATION` allowlist, bounded daily/max-turn/rate/cooldown controls, and immediate SAFE-OFF rollback capability.

## Exit boundary

WA-L10 can close only after real provider evidence shows one governed autonomous response path with no duplicate delivery and a bounded multi-turn test covering context, fact/price integrity, handoff and at least one booking-path interaction or a documented governed reason it was not exercised. L11/general production remains separately gated and is not authorized by this lock.
