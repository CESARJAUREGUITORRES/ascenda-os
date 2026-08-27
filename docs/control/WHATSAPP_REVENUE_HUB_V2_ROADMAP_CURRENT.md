# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-27 America/Lima  
**WA-7A.0:** CLOSED  
**WA-7A.1:** CLOSED  
**WA-7A.2:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**WA-7A.3:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE NEXT:** `WA-7A.4 — MARKETING ELIGIBILITY FOUNDATION`  
**LIVE recovery debt:** Supabase REST/Auth HTTP 402 + fresh provider identity/CTWA attribution canaries

## North Star

`Meta Ads / Business Username / Organic / QR / Web → WhatsApp → explicit provenance + channel identity → canonical identity → conversation → handling state + sales stage → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a governed conversation/channel product, not a CRM replacement.
- Phone is a contact point, not a mandatory WhatsApp primary key.
- BSUID is a scoped WhatsApp channel alias, not canonical person identity.
- Username is display/search metadata only.
- Canonical patient identity remains governed by REV/F5/F6.
- Acquisition touchpoints remain separate from channel/person identity.
- `BSUID != ctwa_clid/touchpoint`.
- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.
- CODE/CI/DB/Railway certification is distinct from fresh provider LIVE certification.

## Phase graph

`WA-V2-0 ✅ → WA-3 ✅ OFFLINE → WA-3.5 ✅ OFFLINE → WA-7A.0 ✅ → WA-7A.1 ✅ → WA-7A.2 ✅ → WA-7A.3 ✅ → WA-7A.4 ACTIVE → WA-4A → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

## WA-7A.0 — Identity Compatibility — CLOSED

PHONE/BSUID/PARENT_BSUID transport compatibility, generic recipient semantics, alias continuity, conflict fail-closed behavior and PHONE backward compatibility are preserved.

## WA-7A.1 — Identity Resolution — CLOSED

No new identity engine or customer master was necessary. Existing REV/F5/F6 authority is reused through a minimal read-only WA conversation→canonical identity bridge. BSUID alone never identifies a canonical patient; username never resolves identity; conflicts remain fail-closed.

## WA-7A.2 — Identity Verification & Continuity — CLOSED

Verification/source/evidence and non-destructive identifier lineage are implemented at existing WA alias/event boundaries. Typed/manual/forwarded phone never auto-verifies; username remains outside identity authority. Fresh provider semantics remain separately recovery-gated by Supabase REST/Auth 402.

## WA-7A.3 — Attribution Ingress — CLOSED AT DEMONSTRATED BOUNDARY

**Necessity:** `BUILD YES / NEW PHYSICAL TOUCHPOINT TABLE NO`.

PR #377 exact head `be4132223118f6009d5bba23116da5adbd2463f8` merged with expected head to runtime `5aab7b408882811d1c6cd00c6fb939f2f8de432e`.

Delivered:

- explicit `messages[].referral` provenance parser;
- deterministic `attribution.touchpoint` event keys from provider message identity;
- `ctwa_clid`, source/referral, ad/provider-lead/campaign fields only when explicitly supplied;
- safe HTTPS source URL handling;
- immutable provenance on existing `aos_wa_events_v1`;
- runtime event-ledger least privilege restored to service_role SELECT+INSERT;
- private read-only `aos_wa_attribution_touchpoints_v1` adapter;
- touchpoint → message → conversation → optional WA-7A.1 canonical identity linkage;
- no PHONE/BSUID/username-only attribution;
- no write to `aos_leads`, `aos_pacientes`, REV canonical identity or Marketing Attribution V2;
- no Meta Ads Sync, AI send, auto-reply, auto-routing or campaign activation;
- replay/idempotency, security, rollback and WA-7A.0/1/2 regression contracts.

Exact-head matrix = **8/8 SUCCESS** across WA-7A.3, WA-7A.2, WA-7A.0, WA-1, Phase S, Ascenda CI and both performance gates.

Production migration `wa7a3_attribution_ingress_v1` = SUCCESS. Readback preserved `7702` patients, `6061` leads, `21` WA messages, `2` conversations, `39` events and `0` fabricated attribution touchpoints. Marketing Attribution V2 hash remains `66b3d38378ca0610aa5de037d5be8292`. Safety remains `auto_routing=false`, `ai_send=false`, `copilot=false`, `auto_reply=false`, with pre-existing governed `human_send=true` unchanged.

Railway exact runtime `5aab7b408882811d1c6cd00c6fb939f2f8de432e` = **SUCCESS** and passed the configured `/health` check.

Supabase production REST/Auth still returns HTTP 402 after deployment, including `/rest-admin/v1/ready` and `/auth/v1/health` at 2026-08-27 18:07 UTC. Fresh physical CTWA attribution canary therefore remains recovery debt and was not replaced by synthetic evidence. WA-7A.3 is closed at its demonstrated CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY boundary, not fresh provider LIVE end-to-end.

Certificate: `docs/control/WHATSAPP_WA_7A_3_ATTRIBUTION_INGRESS_CERTIFICATE_20260827.md`.

## WA-7A.4 — Marketing Eligibility Foundation — ACTIVE

**Goal:** separate recipient identity, reachability and marketing consent/eligibility/preferences/suppression before any outbound campaign layer.

First loop:

- inventory existing consent, opt-in/out, suppression, recipient-control and channel-preference structures;
- define lawful/operational eligibility semantics without treating identity or reachability as consent;
- reuse existing CIA/marketing/email suppression authority where safe instead of duplicating it;
- support WA-specific eligibility evidence only when necessary;
- preserve immutable provenance from WA-7A.3 as evidence, not permission;
- define deterministic eligibility/read models and explicit reason codes;
- fail closed on missing/ambiguous consent where required;
- contract-test opt-in, opt-out, suppression, channel preference, identity conflict and replay behavior;
- no bulk sender, Meta Ads Sync, campaign router or autonomous outbound activation in WA-7A.4.

Hard invariant: `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.

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
