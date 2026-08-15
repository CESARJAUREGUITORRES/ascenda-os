# ASCENDA OS — F17 Multichannel Discovery Snapshot

**Captured from:** `main@c5781f439a688b3df3937cc827f859b8fde834ae`  
**Scope:** safe discovery/design only; no production mutation.

## Dependency state

- F8 `Channel Context & Availability` is closed/certified and defines `Audience Total → Eligible → Available Now`, with UNKNOWN fail-closed and CALL/EMAIL/SMS channel semantics.
- F16 is not production-certified for F17: the production readiness RPC is absent, Issue #104 is open, and the clean release remains unmerged.
- Therefore this document records integration contracts only.

## WhatsApp current-state inventory

### Provider / transport

Current implementation is Meta WhatsApp Cloud API oriented, but WA-1 already separates parsing/transport helpers from storage. Provider-specific logic lives behind server-side gateway code; secrets are expected from environment.

### Inbound security

`app/wa-gateway.js` implements HMAC SHA-256 verification for Meta `X-Hub-Signature-256` using timing-safe comparison. Webhook extraction normalizes inbound messages/statuses into sanitized message/event facts rather than exposing raw webhook payloads as browser-readable truth.

### Phone normalization

Current WA helper normalizes by stripping non-digits and bounds length. Outbound validation requires 8–15 digits. F17 should not silently treat that helper as canonical E.164 identity; it must bind channel endpoints to the existing canonical person/lead identity resolver and introduce stricter country/ambiguity handling only through additive, tested contracts.

### Outbound idempotency

`aos_wa_outbound_requests_v1` reserves an idempotency key before provider send. PENDING/ACCEPTED/FAILED retries must not blindly resend. This is a strong pattern to generalize into provider-neutral F17 send-request semantics.

### Message / provider outcome facts

`aos_wa_messages_v1` stores normalized inbound/outbound facts with provider message ID, direction, status, provider timestamps, attribution hints, pricing and delivery/read/failure timestamps.

`aos_wa_events_v1` provides a unique event ledger keyed by provider-derived event identity.

### Conversation store

WA-2 adds canonical WhatsApp conversation projection/events and a server-authoritative inbox. The browser does not receive Supabase service credentials. Access requires ASCENDA app token, 2FA, panel permission and active administrator hierarchy checks.

### Attribution

WA facts already carry `campaign_source`, `ad_id`, `lead_id` and referral metadata. Existing architecture explicitly forbids attributing a sale to marketing by phone coincidence alone. F17 must preserve explicit provenance IDs and link them to Audience/Activation/touchpoint facts.

### Consent / suppression

No F17-authoritative multichannel consent source is certified yet. F16 is expected to establish governed suppression/consent patterns. Until that dependency is certified, UNKNOWN marketing consent must remain fail-closed. No provider send should be enabled from F17 prep.

## SMS current-state inventory

Repository search finds SMS references in generic runtime/agent/coordination surfaces, but no current dedicated production SMS provider adapter, signed inbound webhook, canonical SMS send ledger or provider certification equivalent to WA-1/WA-2 was proven in this loop.

Therefore SMS status is `UNCONFIGURED/UNVERIFIED`, not ready. F17 must define the provider-neutral contract first and add a provider adapter only when configuration and authorization are verified.

## Canonical F17 contract direction

F17 should generalize the strong WA/F16 patterns without moving audience truth into channel tables:

1. canonical audience/activation and identity remain authoritative;
2. channel endpoint = identity-linked contact point, not a new customer record;
3. send request = provider-neutral idempotent command fact;
4. message = normalized direction/content-metadata fact;
5. provider event = immutable delivery/status fact with replay-safe unique key;
6. conversation = optional channel capability, never audience truth;
7. consent/suppression decision = governed policy result with fail-closed UNKNOWN;
8. attribution = explicit activation/touchpoint/provenance linkage;
9. provider adapter = interchangeable implementation selected after policy/configuration checks.

## Negative tests required before production

- duplicate send request;
- duplicate provider event;
- stale/replayed webhook;
- invalid signature;
- missing provider secret/config;
- unauthorized actor / missing 2FA / missing panel permission;
- invalid or ambiguous phone endpoint;
- opt-out / suppression / UNKNOWN consent;
- cross-channel duplicate audience/customer/lead table detector;
- attribution without explicit provenance must not be promoted to deterministic marketing attribution.

## Production gate

No F17 migration/canary/provider activation may occur until production exposes `aos_cia_email_f17_readiness_v1()` and it returns `READY_F17_EMAIL_CERTIFIED` with `ready_for_f17=true`, with Issue #104 exit criteria satisfied.
