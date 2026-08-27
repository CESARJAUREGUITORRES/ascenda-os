# WA-7A.4 — Marketing Eligibility Foundation — TEST Certificate

**Date:** 2026-08-27 America/Lima  
**Status:** `TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`  
**Certified exact head:** `ac58ceced7b6d06bec1792bbb4aa27d97f8e3db3`  
**PR:** `#378`  
**Merge:** `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6`  
**Execution mode:** `ZERO-COST TEST-FIRST`  

## Decision

Necessity gate = `BUILD YES / NEW CONSENT MASTER NO / PROD MUTATION NO`.

WA-7A.4 does not create a second CRM/customer/person authority and does not treat phone, BSUID, username, inbound receipt or CTWA attribution as consent. Existing CIA-F17 recipient controls are reused read-only as a secondary deny/suppression guard; CIA `ALLOWED` never grants WhatsApp consent.

## Delivered package

- immutable conversation-scoped eligibility ledger `aos_wa_marketing_eligibility_events_v1`;
- scopes `GLOBAL / MARKETING / UTILITY / AUTHENTICATION / CALL`;
- `UNKNOWN / ALLOWED / DENIED` consent and `UNKNOWN / CLEAR / SUPPRESSED` suppression states;
- source/ref/policy/evidence/timestamps and optional expiry;
- exact replay idempotency and changed-payload replay conflict;
- explicit re-consent required after prior denial/suppression;
- weak sources `ATTRIBUTION / CTWA / TOUCHPOINT / PHONE / BSUID / USERNAME / MESSAGE_RECEIPT` cannot grant `ALLOWED`;
- current read-only `aos_wa_marketing_eligibility_v1` projection;
- reachability from active PHONE/BSUID/PARENT_BSUID aliases only; username does not create reachability;
- CIA-F17 DENIED/SUPPRESSED can block; CIA ALLOWED/CLEAR cannot grant permission;
- fail-closed `aos_wa_marketing_eligibility_check_v1`;
- service-only append/check boundary; anon/authenticated denied;
- service runtime evidence ledger = SELECT+INSERT only;
- immutable UPDATE/DELETE guard;
- destructive rollback blocked once accepted evidence exists.

Hard invariants:

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`

`ATTRIBUTION EVIDENCE != CONSENT`

## Exact-head TEST / Zero-Cost evidence

On exact head `ac58ceced7b6d06bec1792bbb4aa27d97f8e3db3`:

- `ASCENDA WA-7A.4 Marketing Eligibility Foundation` run `33103975948` = SUCCESS;
- `Ascenda CI` run `33103975951` = SUCCESS.

Dedicated Zero-Cost run passed:

- self-hosted Zero-Cost policy;
- static authority/scope invariants;
- isolated Supabase boot;
- WA-1/WA-2/WA-3/WA-7A.0/1/2/3 prerequisite replay;
- PostgreSQL lint;
- BSUID-only reachability without consent;
- explicit MARKETING opt-in;
- MARKETING/CALL scope separation;
- CTWA/attribution cannot grant consent;
- exact replay and replay-conflict behavior;
- opt-out precedence;
- silent reversal blocked;
- explicit re-consent restore;
- CIA suppression blocker;
- CIA ALLOWED non-grant behavior;
- GLOBAL suppression precedence;
- immutable evidence ACL/trigger;
- rollback fail-closed;
- clean rollback/reapply;
- WA-7A.3/7A.2/7A.1/7A.0 database regressions.

## Production non-apply proof

By owner directive, WA-7A.4 was **not promoted to production**.

Post-merge production readback proves:

- migration `wa7a4_marketing_eligibility_v1` recorded = false;
- `aos_wa_marketing_eligibility_events_v1` exists = false;
- `aos_wa_marketing_eligibility_v1` exists = false;
- patients = `7702`;
- leads = `6061`;
- WA messages = `21`;
- WA conversations = `2`;
- WA events = `39`;
- real attribution touchpoints = `0`.

The migration + rollback remain committed as the queued PROD promotion package.

## Railway

Merge `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6` triggered the repository's automatic Railway deployment even though WA-7A.4 changes no application runtime. Railway status = `SUCCESS` for `ascenda-os-production.up.railway.app`.

This does not constitute WA-7A.4 PROD schema promotion.

## External production hold

Supabase production REST/Auth remains under the existing HTTP 402 recovery debt. SQL management availability is not used to bypass the owner-directed TEST-first strategy.

## Closeout

`WA-7A.4 = TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`.

The next sole mutable HIGH/CRITICAL lane is:

`WA-4A — KNOWLEDGE FABRIC`.

WA-4A starts discover-first. Existing WA4/Copilot infrastructure remains SAFE-OFF; approved business facts and evidence references must outrank generic LLM knowledge, and no AI/autonomous send activation is implied by activating the phase.
