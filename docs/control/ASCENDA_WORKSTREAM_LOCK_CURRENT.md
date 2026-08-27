# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-27 America/Lima  
**WA-7A.4 exact head:** `ac58ceced7b6d06bec1792bbb4aa27d97f8e3db3`  
**WA-7A.4 merge:** `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6`  
**WA-7A.4:** `TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`  
**ACTIVE LOCK:** `WA-4A — KNOWLEDGE FABRIC`

## Owner directive

Continue WhatsApp Revenue Hub with at most one HIGH/CRITICAL mutable workstream at a time.

**Only WA-4A is mutable now.** All other HIGH/CRITICAL workstreams remain read-only/regression-only unless WA-4A proves a strict dependency.

## Preserved portfolio state

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- Notifications S13–S15.5 = CLOSED / regression-only.
- CIA, Sentinel, KronIA and unrelated product/data work = read-only/regression-only unless strict dependency.

## WA-7A foundation preserved

- WA-7A.0 owns PHONE/BSUID/PARENT_BSUID channel continuity.
- WA-7A.1 reuses REV/F5/F6 as canonical patient identity authority.
- WA-7A.2 owns channel verification and identifier lineage.
- WA-7A.3 owns explicit immutable acquisition provenance.
- WA-7A.4 owns TEST-certified marketing eligibility evidence and promotion package.

No parallel customer/person master exists.

Mandatory separation:

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`

`ATTRIBUTION EVIDENCE != CONSENT`

## WA-7A.4 closeout

PR #378 exact head `ac58ceced7b6d06bec1792bbb4aa27d97f8e3db3` merged with expected head to `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6`.

Exact-head TEST gates:

- WA-7A.4 Marketing Eligibility Foundation `33103975948` = SUCCESS;
- Ascenda CI `33103975951` = SUCCESS.

Scope delivered in TEST:

- immutable conversation-scoped eligibility ledger;
- GLOBAL/MARKETING/UTILITY/AUTHENTICATION/CALL scopes;
- explicit consent/suppression/source/evidence/policy/timestamp;
- replay/idempotency + replay conflict;
- explicit re-consent after denial/suppression;
- BSUID/PARENT_BSUID reachability without requiring phone;
- username does not create reachability;
- CTWA/touchpoint/message receipt/phone/BSUID/username cannot grant consent;
- CIA-F17 recipient controls reused read-only as deny/suppression guard only;
- CIA ALLOWED cannot grant WA consent;
- RLS/ACL/immutable evidence + destructive rollback guard;
- WA-7A.3/2/1/0 regressions.

Production was deliberately untouched: WA-7A.4 migration is not recorded; table/view are absent; patients/leads/WA counts remain unchanged. The migration + rollback are queued for controlled PROD promotion after Supabase renewal/recovery.

Railway automatic merge deploy = SUCCESS. No `app/` runtime behavior was changed by WA-7A.4.

## WA-4A — allowed mutations

Goal: establish a governed Knowledge Fabric for WhatsApp human/Copilot use without creating duplicate source-of-truth systems.

Allowed discover/build when necessary:

- inventory certified catalog/service/price/branch/FAQ/protocol/business-rule sources;
- inventory existing WA4 Copilot retrieval/context code and safe-off controls;
- define knowledge authority tiers, provenance/evidence refs, freshness and version rules;
- read-only adapters/indexes/read models over certified sources;
- narrowly scoped normalized knowledge artifacts when source systems cannot provide usable retrieval contracts;
- conflict/freshness/fallback logic;
- TEST fixtures and retrieval/evidence contracts;
- private service-only APIs required for governed retrieval.

Must not:

- create a second patient/product/revenue/customer truth master;
- use generic LLM knowledge as authority over governed ASCENDA facts;
- expose unnecessary clinical/sensitive data to Copilot context;
- activate autonomous AI send, auto-reply or auto-routing;
- activate campaigns, bulk sender, Meta Ads Sync or WA-7C router;
- mutate REV/F5 canonical identity to improve retrieval;
- bypass Auth V3/2FA or ownership boundaries.

## Mandatory WA-4A invariants

- governed source facts + evidence references outrank generic model knowledge;
- knowledge answers must be traceable to source/version/freshness where applicable;
- stale/conflicting/missing facts fail closed or are surfaced as unknown, not invented;
- retrieval context must follow least-data/least-privilege;
- existing WA4 Copilot infrastructure remains SAFE-OFF until later certified activation;
- TEST-first rule remains active: build/certify PROD-ready packages without production promotion while Supabase recovery is pending.

## Lock transition rule

WA-4A remains the sole mutable HIGH/CRITICAL lane until its scoped TEST closeout is certified and GitHub CURRENT + Notion LAST are updated. Only then may the lock move to `WA-4B — Sales Playbook Engine`.
