# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-27 America/Lima  
**WA-7A.2 exact head:** `8106f0ba6d644c062168fe84dc52dd83e50edb69`  
**WA-7A.2 merge:** `a943dca94534e9016de158177131e88bbcb72b73`  
**WA-7A.2:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE LOCK:** `WA-7A.3 — ATTRIBUTION INGRESS`

## Owner directive

Continue WhatsApp Revenue Hub with at most one HIGH/CRITICAL mutable workstream at a time.

**Only WA-7A.3 is mutable now.** All other HIGH/CRITICAL workstreams remain read-only/regression-only unless WA-7A.3 proves a strict dependency.

## Preserved portfolio state

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- Notifications S13–S15.5 = CLOSED / regression-only.
- CIA, Sentinel, KronIA and unrelated product/data work = read-only/regression-only unless strict dependency.

## WA-7A.0 / WA-7A.1 preserved

WA-7A.0 owns PHONE/BSUID/PARENT_BSUID transport compatibility and channel alias continuity. WA-7A.1 reuses REV/F5/F6 as the only canonical patient identity authority and provides the read-only WA→REV identity bridge. No parallel customer/person master exists.

## WA-7A.2 closeout

PR #376 exact head `8106f0ba6d644c062168fe84dc52dd83e50edb69` merged to `a943dca94534e9016de158177131e88bbcb72b73`.

Delivered at the existing boundaries only:

- `VERIFIED / CLAIMED / UNKNOWN / CONFLICT` channel-fact semantics;
- verification source/evidence timestamps;
- old→new BSUID/PARENT_BSUID supersession lineage;
- Meta system identity-change parsing;
- signed PHONE+BSUID pair evidence;
- native `REQUEST_CONTACT_INFO` / `contact_request` handling;
- delivered/read `recipient_user_id` binding;
- replay/idempotency and concurrent fork prevention;
- destructive rollback guard.

Hard invariants preserved:

- username never resolves identity;
- BSUID remains scoped channel identity, not canonical person id;
- typed/manual/forwarded phone never becomes VERIFIED automatically;
- Contact Book is not a CRM/customer master;
- no write to `aos_pacientes` or REV canonical identity;
- no attribution, Ads Sync, AI send, auto-reply or auto-routing in WA-7A.2.

Production readback keeps 21 messages, 2 conversations and 2 legacy PHONE aliases. Both aliases correctly remain `UNKNOWN / LEGACY_OBSERVED`; there are 0 real WA-7A.2 identity events, 0 synthetic supersessions and 0 fabricated verification evidence. Railway exact merge = SUCCESS.

Supabase REST remains HTTP 402 on current traffic, therefore fresh Auth/browser/provider/REQUEST_CONTACT_INFO/BSUID-rotation LIVE canaries remain external debt. WA-7A.2 is closed only at the demonstrated CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY boundary.

## WA-7A.3 — allowed mutations

Goal: preserve explicit acquisition provenance at ingress as immutable touchpoint evidence, without confusing channel identity with attribution.

Allowed discovery/build when necessary:

- current Meta CTWA/referral payload contracts;
- `ctwa_clid` or provider-equivalent click id;
- referral/source id and source type;
- source URL only when supplied and safe;
- `ad_id`, `lead_id`, `campaign_source` when explicitly supplied;
- permitted headline/body and sanitized raw referral evidence;
- immutable touchpoint/event id;
- provider message/replay ids and timestamps;
- linkage from touchpoint → canonical WA conversation → optional resolved canonical patient through existing WA-7A.1 authority.

Required ordering:

`signed webhook → replay/idempotency → identity-safe envelope → provenance parser → immutable touchpoint → canonical conversation → existing identity resolver`.

Must not:

- infer attribution from PHONE, BSUID, username or canonical patient identity alone;
- use BSUID as touchpoint id;
- merge identity because two touchpoints resemble each other;
- build broad Meta Ads sync before WA-7B;
- activate campaigns, AI send, auto-reply or auto-routing;
- mutate REV/F5 canonical identity to make attribution resolve;
- widen clinical/customer data exposure.

## Mandatory invariants

- `BSUID != ctwa_clid/touchpoint`;
- one governed identity may have multiple touchpoints;
- missing referral evidence degrades safely to no explicit attribution;
- first-inbound provenance must remain auditable/immutable once accepted;
- identity and acquisition provenance remain separate concepts;
- no phone-only or username-only attribution.

## Safety state

Preserve signed Meta gateway, replay/idempotency, Auth V3/2FA, exact-owner/assignment authority, queue privacy, 24h window and canary allowlist.

- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` remains the existing governed canary state and is not widened by WA-7A.3.

## External LIVE hold

Supabase SQL management works while REST/Auth remains HTTP 402. No auth bypass, service-role substitution for user/session canaries, blind provider retries or historical-evidence substitution is allowed.

## Lock transition rule

WA-7A.3 remains the sole mutable HIGH/CRITICAL lane until its scoped closeout is certified. Only then may the lock advance to `WA-7A.4 — Marketing Eligibility Foundation`.
