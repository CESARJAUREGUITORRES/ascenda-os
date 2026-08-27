# WA-7A.4 — Marketing Eligibility Foundation — Evidence / TEST Plan

**Captured:** 2026-08-27 America/Lima  
**Baseline main:** `3bc7a70af661db7409cc77747ac63122abe8ee11`  
**Execution mode:** `TEST / ZERO-COST / PROD-PROMOTION DEFERRED`

## Necessity gate

`BUILD = YES` · `NEW CONSENT MASTER = NO` · `PROD MUTATION = NO`.

Existing CIA-F17 already owns `aos_cia_channel_recipient_controls_v1` with `consent_status`, `suppression_status`, source/evidence and fail-closed send preparation. It must be reused, not duplicated.

However it cannot be the complete WhatsApp eligibility authority because `aos_cia_normalize_contact_key_v1(text)` is phone-centric (Peru 9-digit contact key), while WA-7A.0 explicitly supports PHONE / BSUID / PARENT_BSUID and phone is optional. CIA-F17 also stores only a current `contact_key + channel` snapshot and does not provide WA conversation-scoped immutable/category evidence.

Production inventory before build:

- `aos_cia_channel_recipient_controls_v1`: 0 rows;
- `aos_cia_channel_send_requests_v1`: 0 rows;
- `aos_cia_channel_inbound_facts_v1`: 7 rows;
- `aos_cia_channel_send_events_v1`: 0 rows;
- CIA recipient controls are RLS + FORCE RLS;
- existing service_role table grants are broad and are NOT widened or mutated by WA-7A.4;
- WA production currently has 2 conversations and active legacy PHONE aliases; BSUID-capable schema already exists.

## Current provider/policy boundary

Current WhatsApp Business Messaging Policy requires prior opt-in before business-initiated contact and requires businesses to honor opt-out/block/discontinue requests. Current best practices recommend category-aware opt-in and separate call opt-in. WA-7A.4 models those requirements without hard-coding legal conclusions into runtime.

## Minimum build

WA-7A.4 adds only a WhatsApp conversation-scoped eligibility evidence layer:

- append-only `aos_wa_marketing_eligibility_events_v1`;
- scopes: `GLOBAL`, `MARKETING`, `UTILITY`, `AUTHENTICATION`, `CALL`;
- consent: `UNKNOWN / ALLOWED / DENIED`;
- suppression: `UNKNOWN / CLEAR / SUPPRESSED`;
- immutable source/evidence/policy/timestamp;
- deterministic replay key and replay-conflict detection;
- explicit re-consent required to reverse an earlier denial/suppression;
- weak facts (`ATTRIBUTION`, `CTWA`, `TOUCHPOINT`, `PHONE`, `BSUID`, `USERNAME`, `MESSAGE_RECEIPT`) cannot grant `ALLOWED`;
- `aos_wa_marketing_eligibility_v1` current projection;
- reachability derives only from active PHONE/BSUID/PARENT_BSUID aliases; username is not reachability;
- CIA-F17 is read-only secondary guard: active DENIED/SUPPRESSED can block, but CIA ALLOWED never grants WA consent;
- service-only record/check functions;
- RLS + FORCE RLS; no anon/authenticated access;
- rollback fails closed once evidence exists.

## Mandatory invariants

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`

`ATTRIBUTION EVIDENCE != CONSENT`

Suppression wins. Missing consent fails closed. A reachable address is not permission. A CTWA click or inbound message is not blanket marketing consent. A category opt-in does not imply call opt-in. Opt-out can only be reversed by a new explicit re-consent event.

## Scope exclusions

WA-7A.4 does **not**:

- create a customer/person master;
- mutate `aos_pacientes`, `aos_leads`, REV/F5/F6 or Marketing Attribution V2;
- modify `app/wa-gateway.js`;
- activate bulk sending, broadcasts or campaigns;
- activate Meta Ads Sync, Campaign Flow Router, AI send, auto-reply or auto-routing;
- promote schema to production while the owner-directed TEST-first / Supabase-402 hold remains active.

## Zero-Cost test matrix

1. no alias → `UNREACHABLE / NOT_ELIGIBLE`;
2. BSUID alias → reachable but no consent → `UNKNOWN`, send blocked;
3. CTWA/attribution source cannot grant consent;
4. explicit MARKETING opt-in → eligible on reachable BSUID-only conversation;
5. MARKETING opt-in does not grant CALL;
6. exact replay is idempotent;
7. changed payload under same event key fails replay conflict;
8. opt-out wins immediately;
9. silent reactivation after opt-out is forbidden;
10. explicit re-consent can restore the scoped permission;
11. CIA suppression blocks;
12. CIA ALLOWED alone cannot grant WA consent;
13. GLOBAL suppression overrides scoped permission;
14. evidence UPDATE/DELETE blocked;
15. anon/authenticated ACL blocked;
16. service-role read/insert only on evidence ledger;
17. rollback blocked while evidence exists;
18. rollback + clean reapply passes after synthetic evidence cleanup;
19. WA-7A.3/7A.2/7A.1/7A.0 DB regressions pass;
20. Zero-Cost policy passes on self-hosted runner.

## Production promotion package

The migration and rollback are committed but must remain unapplied to production until the production-recovery loop is authorized after Supabase renewal.

Promotion order when PROD recovers:

`revalidate exact main → verify WA-7A.0..7A.3 production state → fingerprint patients/leads/WA/Marketing → apply wa7a4 migration → ACL/readback → synthetic-free eligibility readback → REST/Auth health → provider/human canaries where applicable → certify PROD`.

Until that promotion, the correct certification label is:

`WA-7A.4 = TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`.
