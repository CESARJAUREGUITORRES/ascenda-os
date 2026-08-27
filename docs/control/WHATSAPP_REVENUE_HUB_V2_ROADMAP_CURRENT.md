# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-27 America/Lima  
**WA-7A.0:** CLOSED  
**WA-7A.1:** CLOSED  
**WA-7A.2:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE NEXT:** `WA-7A.3 — ATTRIBUTION INGRESS`  
**LIVE recovery debt:** Supabase REST/Auth HTTP 402 + fresh provider identity canaries

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

`WA-V2-0 ✅ → WA-3 ✅ OFFLINE → WA-3.5 ✅ OFFLINE → WA-7A.0 ✅ → WA-7A.1 ✅ → WA-7A.2 ✅ → WA-7A.3 ACTIVE → WA-7A.4 → WA-4A → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

## WA-7A.0 — Identity Compatibility — CLOSED

PHONE/BSUID/PARENT_BSUID transport compatibility, generic recipient semantics, alias continuity, conflict fail-closed behavior and PHONE backward compatibility are preserved.

## WA-7A.1 — Identity Resolution — CLOSED

No new identity engine or customer master was necessary. Existing REV/F5/F6 authority is reused through a minimal read-only WA conversation→canonical identity bridge. BSUID alone never identifies a canonical patient; username never resolves identity; conflicts remain fail-closed.

## WA-7A.2 — Identity Verification & Continuity — CLOSED

**Decision:** build was necessary only at existing WA alias/event boundaries.

PR #376 exact head `8106f0ba6d644c062168fe84dc52dd83e50edb69` merged to `a943dca94534e9016de158177131e88bbcb72b73`.

Delivered:

- verification/source/evidence on the existing alias ledger;
- `VERIFIED / CLAIMED / UNKNOWN / CONFLICT`;
- non-destructive old→new BSUID and parent-BSUID lineage;
- current Meta system identity-change handling;
- signed PHONE+BSUID evidence;
- native `REQUEST_CONTACT_INFO` response verification;
- forwarded/manual contact remains non-attested/CLAIMED only;
- delivered/read `recipient_user_id` binding;
- replay/idempotency and concurrency fork prevention;
- rollback fails closed once real lineage/evidence exists.

Exact-head CI matrix = SUCCESS across WA-7A.2, WA-7A.0, WA-1, Phase S, Ascenda CI and performance gates. Production schema is applied; Railway exact merge = SUCCESS.

Production readback on 2026-08-27 correctly preserves 21 messages, 2 conversations and 2 legacy PHONE aliases as `UNKNOWN / LEGACY_OBSERVED`, with 0 real identity events and 0 fabricated supersessions/evidence.

Supabase REST remains HTTP 402 on current traffic, so fresh physical provider semantics remain a post-recovery recertification gate. WA-7A.2 is closed at its demonstrated CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY boundary, not fresh LIVE provider end-to-end.

## WA-7A.3 — Attribution Ingress — ACTIVE

**Goal:** persist explicit acquisition provenance at first inbound as immutable touchpoint evidence while preserving separation from channel/person identity.

Discover first:

- current Meta Click-to-WhatsApp referral payload;
- `ctwa_clid` or provider-equivalent click id;
- source/referral id/type and safe supplied source URL;
- explicit `ad_id`, `lead_id`, `campaign_source` fields already available in ASCENDA/provider payloads;
- headline/body/raw referral retention limits;
- provider message/event/replay identifiers and timestamps;
- existing marketing attribution/touchpoint structures that can be reused rather than duplicated.

Required behavior:

- signed webhook → replay/idempotency → identity-safe envelope → provenance parser → immutable touchpoint → canonical conversation → existing identity resolver;
- one person/conversation may have multiple touchpoints;
- `BSUID != touchpoint`;
- phone/username/BSUID alone never infer attribution;
- missing referral evidence produces no fabricated attribution;
- provenance remains immutable/auditable once accepted;
- conflicts or malformed evidence fail closed;
- no broad Meta Ads Sync in this slice.

Exit gates:

- explicit first-inbound provenance is persisted idempotently without duplicating identity/customer authority;
- repeated provider delivery cannot create duplicate touchpoints;
- attribution evidence cannot mutate canonical identity;
- exact-head Zero-Cost/CI green;
- production apply/readback only when safe;
- provider-dependent LIVE remains separately gated by current REST/Auth/provider availability.

## WA-7A.4 — Marketing Eligibility Foundation

After WA-7A.3, separate recipient identity, reachability and marketing consent/eligibility/preferences/suppression. No bulk sender yet.

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
