# WA-7A.3 — Attribution Ingress — Evidence & Necessity Gate

**Captured:** 2026-08-27 America/Lima  
**Baseline:** `main@6c5b7199a9f9f27bd2062d5c61fc0f15b2be9a51`  
**Status:** BUILD / CERTIFICATION IN PROGRESS

## Decision

`BUILD = YES` and `NEW PHYSICAL TOUCHPOINT TABLE = NO`.

ASCENDA already has the required boundaries:

- signed Meta ingress in `app/server-f4.js`;
- identity-safe parser and PHONE/BSUID continuity in `app/wa-gateway.js`;
- canonical message ledger `aos_wa_messages_v1`;
- idempotent event ledger `aos_wa_events_v1` with unique `event_key`;
- deterministic message → `conversation_id` projection;
- WA-7A.1 read-only conversation → canonical patient bridge;
- Marketing Attribution V2 downstream analytics.

The missing slice is explicit acquisition evidence preservation. WA-7A.3 therefore reuses `aos_wa_events_v1` with event type `attribution.touchpoint`, adds a private read-only adapter view, and does not create another CRM, customer master, identity authority or marketing lead store.

## Provider contract revalidated

Current Meta WhatsApp Cloud API examples keep Click-to-WhatsApp acquisition metadata on the inbound message `referral` object, including `source_url`, `source_id`, `source_type`, `headline`, `body` and media metadata. Provider integrations can additionally expose a CTWA click id (`ctwa_clid` / provider equivalent) for Conversions API stitching.

Execution references revalidated on 2026-08-27:

- Meta WhatsApp Business Platform Postman collection — Received Message Triggered by Click to WhatsApp Ads.
- Meta WhatsApp Business Platform Postman collection — Messages Object / referral semantics.
- Twilio WhatsApp inbound webhook documentation — `ReferralCtwaClid`.

WA-7A.3 stores a CTWA click id only when explicitly supplied. It never fabricates it from `source_id`, phone, BSUID, username or canonical patient identity.

## Reuse boundary

### Reused as immutable evidence ledger

`aos_wa_events_v1`

Deterministic key:

`attribution:touchpoint:<provider_message_id>`

Payload fields are sanitized and bounded:

- evidence version;
- channel/provider/business scope;
- provider message id;
- `ctwa_clid` when explicitly supplied;
- `source_id`;
- `source_type`;
- safe HTTPS `source_url`;
- `ad_id` only when source type is explicitly `ad`;
- provider lead id when supplied;
- explicit campaign source when supplied;
- headline/body/media type;
- provider observed timestamp.

No phone, BSUID, username or raw webhook body is stored in attribution evidence.

### Read-only adapter

`aos_wa_attribution_touchpoints_v1`

It joins:

`immutable event → provider_message_id → canonical WA message → conversation_id → optional WA-7A.1 canonical patient resolution`.

The canonical patient link remains a read-only projection. Attribution evidence never mutates identity to obtain a match.

## Production discovery

Pre-build production readback:

- messages: 21;
- conversations: 2;
- WA events: 39;
- referral-bearing messages: 0;
- messages with `campaign_source`: 0;
- messages with `ad_id`: 0;
- messages with `lead_id`: 0;
- `attribution.touchpoint` events: 0.

A privilege drift was found: production `service_role` currently has broader rights on `aos_wa_events_v1` than WA-1's original append-only intent. WA-7A.3 reconciles this by revoking runtime UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER and retaining SELECT/INSERT, plus an explicit mutation guard for accepted attribution events.

## Marketing Attribution boundary

Marketing Attribution V2 remains authoritative for existing lead/call/cita/sale analytics. Its current `aos_marketing_touchpoints_v2()` derives historical marketing touchpoints from `aos_leads` and is not replaced.

WA-7A.3 does **not** auto-create an `aos_leads` row from a WhatsApp referral. The new adapter is the governed first-mile provenance source that later revenue stitching can consume without inventing a marketing lead or phone-only attribution.

## Hard invariants

- `BSUID != touchpoint`;
- channel identity != acquisition provenance;
- username never attributes;
- phone never attributes by itself;
- canonical patient identity never attributes by itself;
- absent referral/provenance evidence => no attribution touchpoint;
- repeated provider delivery => same touchpoint key;
- one person/conversation may have multiple legitimate touchpoints;
- accepted touchpoint evidence is append-only and auditable;
- no `aos_pacientes`, REV canonical or `aos_leads` mutation;
- no Meta Ads bulk sync;
- no campaign activation, AI send, auto-reply or auto-routing.

## LIVE boundary

Fresh provider CTWA end-to-end remains a separate LIVE gate. It must not be replaced by historical evidence, service-role Auth bypass or synthetic production attribution.
