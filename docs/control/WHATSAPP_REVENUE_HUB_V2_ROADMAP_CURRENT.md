# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-25 America/Lima  
**WA-7A.1 merge:** `0bdac2d8e171fbc8883835cb7cfdda0b39339807`  
**WA-7A.0:** `CLOSED`  
**WA-7A.1:** `CLOSED — CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK`  
**ACTIVE NEXT:** `WA-7A.2 — IDENTITY VERIFICATION & CONTINUITY`  
**LIVE recovery debt:** Supabase REST/Auth HTTP 402 + fresh provider/BSUID canary

## North Star

`Meta Ads / Business Username / Organic / QR / Web → WhatsApp → explicit provenance + channel identity → canonical identity → conversation → handling state + sales stage → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a governed conversation/channel product, not a CRM replacement.
- Phone is a contact point, not a mandatory WhatsApp primary key.
- BSUID is a scoped WhatsApp channel alias, not canonical person identity.
- Username is display/search metadata only.
- Canonical identity remains governed by REV/F5/F6.
- WA-7A.1 reuses REV identity authority; no parallel customer master exists.
- Acquisition touchpoints remain separate from channel/person identity.
- `BSUID != ctwa_clid/touchpoint`.
- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.
- CODE/CI/DB certification is distinct from fresh LIVE provider certification.

## Phase graph

`WA-V2-0 ✅ → WA-3 ✅ OFFLINE → WA-3.5 ✅ OFFLINE → WA-7A.0 ✅ → WA-7A.1 ✅ → WA-7A.2 ACTIVE → WA-7A.3 → WA-7A.4 → WA-4A → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

## WA-7A.0 — Identity Compatibility — CLOSED

Delivered PHONE/BSUID/PARENT_BSUID transport compatibility, generic recipient semantics, alias continuity, conflict fail-closed behavior and PHONE backward compatibility. Fresh provider/BSUID LIVE remains a post-402 recertification gate.

## WA-7A.1 — Identity Resolution — CLOSED

**Decision:** no new identity engine or customer master was necessary.

Existing authorities reused:

- canonical `aos_pacientes` subject;
- REV/F5/F6 Patient Identity Bridge V2;
- `aos_rev_patient_identity_alias_v2`;
- WA-7A.0 channel alias ledger.

Minimal bridge delivered:

`WA conversation + aliases → governed PHONE evidence → REV → MATCH | UNRESOLVED | IDENTITY_CONFLICT`.

Rules proven:

- BSUID alone never identifies a canonical patient;
- username never resolves identity;
- historical PHONE evidence may preserve identity continuity when a later inbound is BSUID-only;
- genuine BSUID-only with no canonical evidence remains `UNRESOLVED`;
- REV conflict remains fail-closed;
- multiple active PHONE aliases resolving to different canonical patients remain fail-closed;
- no canonical patient/REV mutation occurs.

Closeout evidence:

- PR #375 exact head `ab432ddf5f7b0b8c1be9afb2ba3dfe7e616855b3`;
- merge `0bdac2d8e171fbc8883835cb7cfdda0b39339807`;
- dedicated WA-7A.1 run `32903271309` SUCCESS;
- Ascenda CI run `32903271282` SUCCESS;
- production migration applied and read back;
- 2 current conversations resolve to `UNRESOLVED`, which matches the absence of exact REV identity evidence;
- 21 messages and 2 PHONE aliases preserved;
- no runtime code changed, so Railway is N/A for this slice;
- browser/Auth/provider LIVE remains blocked by Supabase 402.

## WA-7A.2 — Identity Verification & Continuity — ACTIVE

**Goal:** preserve channel identity when provider identifiers change or a contact point is disclosed later, without corrupting canonical identity.

Discover first:

- Meta/provider `user_id_update` or current equivalent;
- parent-BSUID semantics and availability;
- `REQUEST_CONTACT_INFO` response shape;
- contact-share origin/evidence;
- outgoing status recipient-user identity when contractually reliable;
- Contact Book scope/limitations;
- existing source/verification facts in ASCENDA before adding schema.

Required behavior:

- old BSUID → new BSUID lineage/supersession, not destructive overwrite;
- newly disclosed phone joins the existing channel relationship when evidence permits, without creating a second customer master;
- distinguish `VERIFIED / CLAIMED / UNKNOWN / CONFLICT`;
- typed/manual phone is not automatically VERIFIED;
- source/evidence/timestamps remain auditable;
- Contact Book is assistance, not canonical identity;
- reuse WA-7A.1 bridge + REV authority;
- replay/idempotency/concurrency and rollback must be tested;
- no Attribution/Ads/AI expansion in this slice.

Exit:

- identifier changes preserve lineage;
- conflicting disclosure remains fail-closed;
- no canonical fact is overwritten silently;
- Zero-Cost/exact-head gates green;
- production apply/readback only when safe;
- LIVE provider-dependent semantics certified only when REST/Auth/provider access permits.

## WA-7A.3 — Attribution Ingress

Persist immutable first-inbound CTWA/referral/source/ad/lead/campaign evidence when supplied. `BSUID != touchpoint`; no attribution from phone/username alone; no broad Ads sync.

## WA-7A.4 — Marketing Eligibility Foundation

Separate recipient identity, reachability and marketing eligibility/consent/preferences/suppression. No bulk sender yet.

## Later roadmap

- `WA-4A` Knowledge Fabric;
- `WA-4B` Sales Playbook Engine;
- `WA-4C` AI Sales Copilot Canary, human approval first;
- `WA-5` multimedia/audio/media library;
- `WA-6` governed business tools;
- `WA-7B` Meta Ads Sync;
- `WA-7C` Campaign Flow Router + WhatsApp Flows;
- `WA-7D` Revenue Stitching;
- `WA-8` Production/SLO/Security/FinOps;
- `WA-9..14` later expansion.

## Standard phase loop

`REVALIDATE CURRENT → DISCOVER → NECESSITY GATE → BUILD MINIMUM → CONTRACT TESTS → EXACT-HEAD CI → ANTI-DRIFT → PROD APPLY WHEN SAFE → READBACK → MERGE EXPECTED HEAD → RAILWAY IF RUNTIME CHANGED → LIVE CANARY WHEN AVAILABLE → CERTIFY OR FAIL-CLOSED → GitHub CURRENT → Notion LAST → NEXT LOCK`.
