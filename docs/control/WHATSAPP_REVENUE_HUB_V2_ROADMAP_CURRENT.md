# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-27 America/Lima  
**WA-7A.0:** CLOSED  
**WA-7A.1:** CLOSED  
**WA-7A.2:** CLOSED AT DEMONSTRATED BOUNDARY  
**WA-7A.3:** CLOSED AT DEMONSTRATED BOUNDARY  
**WA-7A.4:** `TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`  
**ACTIVE NEXT:** `WA-4A — KNOWLEDGE FABRIC`  
**PROD recovery debt:** Supabase REST/Auth HTTP 402 + queued TEST-certified promotions

## North Star

`Meta Ads / Business Username / Organic / QR / Web → WhatsApp → explicit provenance + channel identity → canonical identity → conversation → governed eligibility → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a governed conversation/channel product, not a CRM replacement.
- Phone is a contact point, not a mandatory WhatsApp primary key.
- BSUID is a scoped WhatsApp channel alias, not canonical person identity.
- Username is display/search metadata only.
- Canonical patient identity remains governed by REV/F5/F6.
- Acquisition touchpoints remain separate from channel/person identity.
- Marketing eligibility remains separate from identity/reachability/attribution.
- Knowledge must reference governed source authority instead of duplicating canonical truth.
- `BSUID != ctwa_clid/touchpoint`.
- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.
- `ATTRIBUTION EVIDENCE != CONSENT`.
- TEST certification and PROD promotion are separate gates while the current Supabase hold remains active.

## Phase graph

`WA-V2-0 ✅ → WA-3 ✅ OFFLINE → WA-3.5 ✅ OFFLINE → WA-7A.0 ✅ → WA-7A.1 ✅ → WA-7A.2 ✅ → WA-7A.3 ✅ → WA-7A.4 ✅ TEST/PROD-READY → WA-4A ACTIVE → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

## WA-7A.0 → WA-7A.3 — preserved

- WA-7A.0: PHONE/BSUID/PARENT_BSUID transport compatibility and channel continuity.
- WA-7A.1: read-only conversation → governed canonical patient identity resolution.
- WA-7A.2: channel verification/evidence and non-destructive identifier lineage.
- WA-7A.3: explicit provider acquisition provenance as immutable touchpoint evidence.

Fresh provider canaries remain separately recovery-gated where Supabase REST/Auth is required.

## WA-7A.4 — Marketing Eligibility Foundation — TEST CLOSED

**Necessity:** `BUILD YES / NEW CONSENT MASTER NO / PROD MUTATION NO`.

PR #378 exact head `ac58ceced7b6d06bec1792bbb4aa27d97f8e3db3` merged with expected head to `95bd4acb806c2cee8b7e6d5dadba8b078beb15f6`.

Delivered in isolated Zero-Cost TEST:

- immutable conversation-scoped eligibility evidence;
- GLOBAL/MARKETING/UTILITY/AUTHENTICATION/CALL scopes;
- explicit consent/suppression/source/evidence/policy/timestamps;
- BSUID/PARENT_BSUID reachability without requiring phone;
- username excluded from reachability;
- CTWA/touchpoint/message receipt/PHONE/BSUID/USERNAME cannot grant consent;
- opt-out/suppression precedence;
- silent reversal prohibited; explicit re-consent required;
- CIA-F17 controls reused read-only as deny/suppression blocker only;
- CIA `ALLOWED` does not grant WhatsApp permission;
- current eligibility read model + service-only checker;
- replay/idempotency, RLS/ACL, immutability and rollback guards;
- WA-7A.3/2/1/0 regressions.

Exact-head gates:

- `ASCENDA WA-7A.4 Marketing Eligibility Foundation` run `33103975948` = SUCCESS;
- `Ascenda CI` run `33103975951` = SUCCESS.

Production promotion intentionally deferred:

- WA-7A.4 migration not recorded in PROD;
- WA-7A.4 table/view absent;
- production counts preserved: 7702 patients, 6061 leads, 21 WA messages, 2 conversations, 39 events, 0 attribution touchpoints.

Railway merge deployment = SUCCESS. No app/runtime behavior was added by WA-7A.4.

Certificate: `docs/control/WHATSAPP_WA_7A_4_MARKETING_ELIGIBILITY_CERTIFICATE_20260827.md`.

## WA-4A — Knowledge Fabric — ACTIVE

**Goal:** provide governed, traceable business knowledge to WhatsApp human/Copilot workflows while keeping canonical truth in its existing source systems.

Discovery targets:

- catalog/service/product facts and prices;
- branches/locations/business-hours and operational rules;
- approved FAQs and sales/service explanations;
- protocol/business-rule knowledge suitable for commercial conversations;
- existing WA4 Copilot/context retrieval code;
- existing tables/files/read models that already hold approved knowledge;
- provenance/evidence refs, freshness/version and conflict rules;
- least-data boundaries for any patient/customer context.

Required authority hierarchy:

`certified source-system fact → approved derived knowledge with evidence ref → safe unknown/fallback`.

Generic LLM knowledge may assist language generation but must not override governed ASCENDA facts.

WA-4A must fail safely on stale/conflicting/missing facts and must not fabricate service availability, price, clinical claims, policies or business rules.

No autonomous AI send, auto-reply, auto-routing, campaign activation or broad customer data exposure is allowed.

Under current TEST-first strategy, any necessary migration/runtime artifact must be fully certified in Zero-Cost and left PROD-ready in the promotion queue rather than applied to production.

## Later roadmap

- `WA-4B` Sales Playbook Engine;
- `WA-4C` AI Sales Copilot Canary, human approval first;
- `WA-5` multimedia/audio/media library;
- `WA-6` governed business tools;
- `WA-7B` Meta Ads Sync;
- `WA-7C` Campaign Flow Router + WhatsApp Flows;
- `WA-7D` Revenue Stitching;
- `WA-8` Production/SLO/Security/FinOps;
- `WA-9..14` later expansion.

## Standard TEST-first phase loop

`REVALIDATE CURRENT → DISCOVER → NECESSITY GATE → BUILD MINIMUM IN ISOLATED TEST → CONTRACT/SECURITY/REGRESSION TESTS → EXACT-HEAD ZERO-COST CI → ANTI-DRIFT → MERGE EXPECTED HEAD → VERIFY PROD REMAINS UNCHANGED → RAILWAY ONLY AS REPO REVALIDATION WHEN AUTO-TRIGGERED → TEST CERTIFICATE / PROD-READY PACKAGE → GitHub CURRENT → Notion LAST → NEXT LOCK`.

When Supabase PROD recovers, a separate promotion loop applies queued packages in certified order with production fingerprints/readback and physical canaries.
