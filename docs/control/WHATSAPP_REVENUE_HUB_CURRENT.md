# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Captured:** 2026-08-27 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**WA-7A.4 exact head:** `ac58ceced7b6d06bec1792bbb4aa27d97f8e3db3`  
**WA-7A.4 merge:** `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6`  
**WA-7A.4:** `TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`  
**ACTIVE MUTABLE SUBPHASE:** `WA-4A — Knowledge Fabric`  
**PROD hold:** Supabase REST/Auth HTTP 402 + owner-directed TEST-first promotion queue

## Current phase state

- `WA-V2-0 — Baseline & Governance` = CLOSED.
- `WA-3 — Human Operations Multiagent` = OFFLINE CERTIFIED / LIVE recovery debt.
- `WA-3.5 — Revenue Inbox UX` = OFFLINE CERTIFIED 100% / LIVE recovery debt.
- `WA-7A.0 — Identity Compatibility` = CLOSED.
- `WA-7A.1 — Identity Resolution` = CLOSED.
- `WA-7A.2 — Identity Verification & Continuity` = CLOSED at demonstrated PROD technical boundary.
- `WA-7A.3 — Attribution Ingress` = CLOSED at demonstrated PROD technical/runtime boundary.
- `WA-7A.4 — Marketing Eligibility Foundation` = TEST CERTIFIED / PROD-READY / PROD promotion queued.
- `WA-4A — Knowledge Fabric` = ACTIVE MUTABLE SUBPHASE.
- `WA-4B`, `WA-4C`, `WA-5`, `WA-6`, `WA-7B/C/D`, `WA-8`, `WA-9..14` remain later roadmap.

## Canonical architecture

`channel alias != canonical patient identity != acquisition touchpoint != marketing eligibility != knowledge evidence`.

Canonical patient identity remains REV/F5/F6. WA consumes certified upstream truth; it does not recreate patient, revenue, catalog or acquisition masters.

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.

`ATTRIBUTION EVIDENCE != CONSENT`.

## WA-7A.4 closeout

Necessity gate: `BUILD YES / NEW CONSENT MASTER NO / PROD MUTATION NO`.

Existing CIA-F17 recipient controls were discovered and reused only as a read-only deny/suppression guard. Their phone-centric `contact_key` cannot safely represent BSUID-only WhatsApp recipients and their `ALLOWED` state does not grant WA consent.

TEST package adds:

- immutable WA conversation-scoped eligibility events;
- GLOBAL/MARKETING/UTILITY/AUTHENTICATION/CALL scope separation;
- consent/suppression/source/evidence/policy timestamps;
- explicit re-consent requirement after denial/suppression;
- active PHONE/BSUID/PARENT_BSUID reachability; username excluded;
- CTWA/attribution/message/identifier facts cannot grant marketing permission;
- current fail-closed eligibility projection and service-only check;
- immutable/RLS/ACL/rollback security boundary.

Exact-head `ac58ceced7b6d06bec1792bbb4aa27d97f8e3db3`:

- WA-7A.4 Zero-Cost run `33103975948` = SUCCESS;
- Ascenda CI `33103975951` = SUCCESS.

PR #378 merged with expected head to `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6`.

## Production proof / promotion queue

WA-7A.4 was deliberately not applied to production.

After merge:

- WA-7A.4 migration recorded = false;
- WA-7A.4 table = absent;
- WA-7A.4 view = absent;
- patients = 7702;
- leads = 6061;
- messages = 21;
- conversations = 2;
- events = 39;
- real attribution touchpoints = 0.

Migration + rollback remain in GitHub as the PROD-ready promotion package.

Railway automatic deploy for merge `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6` = SUCCESS. WA-7A.4 introduced no `app/` runtime change, so this is deployment revalidation, not schema promotion.

## Safety state

No bulk sender, campaigns, Meta Ads Sync, Campaign Router, AI send, auto-reply or auto-routing was activated.

Existing governed runtime controls remain outside WA-7A.4 scope.

## WA-4A — Knowledge Fabric — ACTIVE

Goal: make WhatsApp human/Copilot reasoning consume governed ASCENDA business facts with evidence references, source authority, freshness and conflict handling.

Discover first:

- current catalog/services/prices/branches/business rules/FAQ/protocol sources;
- existing WA4 Copilot/context retrieval contracts;
- existing product/CIA/Agenda/Revenue/read-model sources that should be referenced rather than copied;
- existing knowledge tables/files/embeddings if any;
- sensitive-data boundaries for Copilot context;
- freshness/version/provenance gaps.

Required authority principle:

`governed source facts + evidence refs > derived approved knowledge > generic LLM knowledge`.

Generic model knowledge must not silently override ASCENDA facts. Missing/stale/conflicting business facts degrade safely instead of being invented.

Existing `server-wa4.js` Copilot infrastructure remains SAFE-OFF; WA-4A activation does not mean Copilot/AI send activation.

Certificate: `docs/control/WHATSAPP_WA_7A_4_MARKETING_ELIGIBILITY_CERTIFICATE_20260827.md`.  
Evidence: `docs/control/WHATSAPP_WA_7A_4_MARKETING_ELIGIBILITY_EVIDENCE.md`.  
Roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.  
Lock: `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.
