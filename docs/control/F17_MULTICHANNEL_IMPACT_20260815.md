# ASCENDA OS — F17 MULTICHANNEL CHANGE IMPACT REPORT

## Identificación

**Título del cambio:** CIA V3 F17 — SMS / WhatsApp / Future Channels  
**Fecha:** 2026-08-15  
**Solicitante:** ASCENDA OS governance  
**Rama:** `feature/cia-phase17-multichannel-20260815-v2`  
**Base exacta:** `c5781f439a688b3df3937cc827f859b8fde834ae`  
**Riesgo:** 🔴 HIGH

## Objetivo

Extender el Audience Engine existente a SMS, WhatsApp y futuros canales sin crear una segunda verdad de audiencias, leads o clientes por canal. El provider/backend debe permanecer intercambiable y los hechos inbound/outbound deben quedar enlazados con attribution y routing existentes.

## Gate previo obligatorio

F17 no puede mutar producción hasta que F16 pruebe de forma autoritativa `aos_cia_email_f17_readiness_v1() => READY_F17_EMAIL_CERTIFIED` con `ready_for_f17=true` y se satisfagan los criterios de salida del Issue #104.

Fresh preflight 2026-08-15 13:36 Lima:
- production `to_regprocedure('public.aos_cia_email_f17_readiness_v1()')` = `NULL`;
- `READY_F17_EMAIL_CERTIFIED` / `ready_for_f17=true` no puede probarse;
- GitHub Issue #104 permanece OPEN;
- F16 PR #114 permanece OPEN, DRAFT, unmerged y non-mergeable;
- por tanto: **F17 producción BLOQUEADA**; solo discovery, diseño y CI sintético están autorizados.

## CURRENT main / WhatsApp baseline

CURRENT `main` = `c5781f439a688b3df3937cc827f859b8fde834ae` e incluye `WA-2: Conversation Store + Live WhatsApp Inbox`.

Contratos WA presentes en el árbol actual:
- `aos_wa_messages_v1`;
- `aos_wa_events_v1`;
- `aos_wa_outbound_requests_v1`;
- WA-2 conversation projection / event store;
- server-authoritative WhatsApp gateway/inbox runtime and shadow admin UI.

Fresh production read-only evidence confirms RLS + FORCE RLS remain enabled on:
- `aos_wa_messages_v1`;
- `aos_wa_events_v1`;
- `aos_wa_outbound_requests_v1`;
- `aos_webhook_log`;
- `aos_meta_config`.

WA-1/WA-2 are treated as existing channel facts/transport infrastructure to integrate with the Audience Engine, not as separate audience truth.

## Hard architectural invariant

**NO duplicated audience/customer/lead tables by channel.**

F17 must reuse canonical Audience/Activation + identity contracts. Any channel-specific persistence is limited to provider-neutral message/conversation/event/request facts, provider delivery facts, and narrowly scoped configuration/adapter state.

## Planned provider-neutral contracts — design only, not applied

1. **Channel endpoint identity**
   - references canonical person/lead/contact identity;
   - normalized endpoint form (e.g. E.164 for phone);
   - no parallel customer truth.

2. **Message/send request fact**
   - channel, direction, purpose, activation/audience linkage;
   - idempotency key;
   - provider adapter identifier, never provider-coupled audience semantics.

3. **Provider outcome fact**
   - accepted/sent/delivered/failed/undeliverable/read where provider supplies it;
   - provider event ID + replay-safe uniqueness;
   - timestamp provenance and auditability.

4. **Conversation / inbound event fact**
   - canonical conversation linkage where channel supports it;
   - inbound webhook provenance;
   - attribution linkage without phone-only inference.

5. **Consent / opt-out / suppression gate**
   - authoritative source reference;
   - UNKNOWN defaults to fail-closed for marketing sends;
   - channel-specific legal/provider restrictions are policy facts, not new audience tables.

## Seguridad

- server-authoritative authorization; browser never receives service credentials;
- fail-closed permission model;
- environment-only secrets;
- signed webhooks, timestamp/replay window and provider-event idempotency;
- zero phone numbers, message contents, PII/PHI, tokens or secrets in CI/issues/logs;
- no provider spend/activation without verified configuration and owner authorization where a new paid/critical action is required.

## Test plan antes de cualquier producción

1. Synthetic fixtures only.
2. Identity/E.164 normalization positives + invalid/ambiguous negatives.
3. Duplicate send request idempotency.
4. Duplicate/replayed webhook rejection.
5. Invalid signature / stale timestamp rejection.
6. Opt-out / suppression / UNKNOWN-consent fail-closed tests.
7. Attribution linkage to canonical activation/audience facts.
8. Cross-channel invariant: no duplicated audience tables and no channel-owned lead/customer truth.
9. Exact-head Zero-Cost/self-hosted CI; no paid runner fallback.
10. Production read-only preflight before additive migration/canary.
11. Canary + rollback/recovery + zero-residue proof before certification.

## Current status

- F17 branch refreshed from CURRENT main: YES (`feature/cia-phase17-multichannel-20260815-v2`).
- Impact Report before code/schema changes: YES.
- F16 authoritative readiness: **BLOCKED**.
- F17 production migrations: **NONE AUTHORIZED / NONE APPLIED BY THIS LOOP**.
- Provider activation/spend: **NONE**.
- Next legal move while blocked: discovery/design/CI preparation only.

## Gate de salida F17

F17 can be declared `100_COMPLETE / PRODUCTION CERTIFIED` only after all of the following are real and current:
- F16 readiness returns `READY_F17_EMAIL_CERTIFIED` and `ready_for_f17=true`;
- Issue #104 exit criteria are satisfied/closed;
- same Audience Engine, no audience duplication by channel;
- provider-neutral contracts + channel/provider facts;
- inbound/outbound tracking + attribution linkage;
- consent/suppression/opt-out fail-closed;
- signed/replay-safe/idempotent webhooks;
- exact-head CI green;
- production canary smoke + rollback/recovery + zero-residue proof;
- authoritative F18 readiness contract created only after real F17 certification;
- clean production PR merged per governance.
