# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-25 America/Lima  
**Runtime baseline:** `main@6e6e69eac108e3a4497425d5c53b757760185ccc`  
**WA-7A.0:** `CLOSED — CODE/CI/ZERO-COST/PROD-SCHEMA/PHONE-COMPAT CERTIFIED`  
**ACTIVE NEXT:** `WA-7A.1 — IDENTITY RESOLUTION`  
**LIVE recovery debt:** Supabase REST/Auth HTTP 402 + fresh provider/BSUID canary

## North Star

`Meta Ads / Business Username / Organic / QR / Web → WhatsApp → explicit provenance + channel identity → canonical identity → conversation → handling state + sales stage → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a governed conversation/channel product, not a CRM replacement.
- Phone is a contact point, not a mandatory WhatsApp primary key.
- BSUID is a portfolio-scoped WhatsApp channel alias.
- Username is informational/display data and never routing/canonical identity authority.
- Canonical person resolution remains governed by REV/F5.
- Acquisition touchpoints are separate from person/channel identity.
- `BSUID != ctwa_clid/touchpoint`.
- Phone matching alone is never attribution authority.
- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.
- CODE/CI/DB certification is distinct from fresh LIVE provider certification.

## Phase graph

`WA-V2-0 ✅ → WA-3 ✅ OFFLINE → WA-3.5 ✅ OFFLINE → WA-7A.0 ✅ → WA-7A.1 ACTIVE → WA-7A.2 → WA-7A.3 → WA-7A.4 → WA-4A → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

## WA-7A.0 — Identity Compatibility — CLOSED

Delivered:

- PHONE + BSUID and BSUID-only transport contracts;
- parent-BSUID support;
- username display-only metadata;
- generic `PHONE|BSUID` outbound recipient contract;
- alias continuity ledger;
- PHONE↔BSUID convergence within current phone-number-id scope;
- conflict fail-closed through `WA7A0_IDENTITY_CONFLICT`;
- WA-2 PHONE key backward compatibility;
- WA-3 authorization/ownership preserved;
- S14 target resolution no longer requires phone when provider-message evidence exists;
- rollback blocks destructive downgrade after BSUID evidence.

Closeout:

- PR #374 merged;
- exact head `8d081b9be16edd2e7858e015faf0d32ff8fb87fd`;
- runtime merge `6e6e69eac108e3a4497425d5c53b757760185ccc`;
- exact-head CI matrix green;
- production migrations applied/read back;
- existing PHONE data smoke PASS;
- Railway exact merge SUCCESS;
- fresh REST/Auth/provider/BSUID LIVE canary blocked externally by HTTP 402.

## WA-7A.1 — Identity Resolution — ACTIVE

**Goal:** connect WhatsApp channel aliases to canonical ASCENDA identity without unsafe merges or a parallel customer master.

Required:

- discover and reuse current REV/F5 canonical resolution contracts;
- define a governed handoff from channel alias evidence to canonical person/contact identity;
- keep business/portfolio scope explicit;
- distinguish channel alias from canonical identity and acquisition touchpoint;
- model conflicts/review states explicitly;
- preserve evidence source, confidence and timestamps;
- PHONE+BSUID continuity must not duplicate a person merely because phone visibility changes;
- no auto-merge from username similarity;
- no assumption that BSUID is universal across portfolios;
- no phone-only attribution side effects.

Exit gates:

- same governed person is not duplicated solely because WhatsApp moves PHONE↔BSUID visibility;
- conflict scenarios fail closed to review/explicit resolution;
- canonical identity mutation, if any, uses existing governed REV/F5 contracts only;
- full audit trail exists for alias-to-canonical resolution;
- exact-head Zero-Cost DB/runtime contracts green;
- production apply/readback only when safe;
- LIVE provider-dependent validation remains a separate post-402 gate when required.

## WA-7A.2 — Identity Verification & Continuity

Preserve old→new BSUID lineage, consume identifier-update/provider-equivalent events, govern contact-info disclosure and distinguish `VERIFIED / CLAIMED / UNKNOWN / CONFLICT` contact facts. No destructive overwrite.

## WA-7A.3 — Attribution Ingress

Persist immutable first-inbound provenance when supplied: CTWA/referral/source/ad/lead/campaign evidence, sanitized referral, immutable touchpoint id, provider/replay identifiers and timestamps. No attribution from phone/username alone. No broad Ads sync.

## WA-7A.4 — Marketing Eligibility Foundation

Model WhatsApp recipient identity, reachability, consent/eligibility, preference/suppression and last observation. Reachable does not mean marketing-authorized. No bulk campaign engine yet.

## Later roadmap

- `WA-4A` Knowledge Fabric;
- `WA-4B` Sales Playbook Engine;
- `WA-4C` AI Sales Copilot Canary, human approval first;
- `WA-5` multimedia/audio/media library;
- `WA-6` governed business tools: Agenda/follow-up/Call Center/Customer 360;
- `WA-7B` Meta Ads Sync;
- `WA-7C` Campaign Flow Router + WhatsApp Flows;
- `WA-7D` Revenue Stitching;
- `WA-8` Production/SLO/Security/FinOps;
- `WA-9..14` supervisor intelligence, omnichannel, lifecycle, controlled autonomy, revenue optimization and reusable platform core.

## Standard phase loop

`REVALIDATE CURRENT → DISCOVER → PLAN → BUILD ISOLATED → CONTRACT TESTS → EXACT-HEAD CI → ANTI-DRIFT → PROD APPLY WHEN SAFE → READBACK → MERGE EXPECTED HEAD → RAILWAY EXACT DEPLOY → LIVE CANARY WHEN AVAILABLE → CERTIFY OR FAIL-CLOSED → GitHub CURRENT → Notion LAST → NEXT LOCK`.
