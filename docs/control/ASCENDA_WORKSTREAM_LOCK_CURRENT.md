# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-27 America/Lima  
**WA-7A.3 exact head:** `be4132223118f6009d5bba23116da5adbd2463f8`  
**WA-7A.3 runtime merge:** `5aab7b408882811d1c6cd00c6fb939f2f8de432e`  
**WA-7A.3:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE LOCK:** `WA-7A.4 — MARKETING ELIGIBILITY FOUNDATION`

## Owner directive

Continue WhatsApp Revenue Hub with at most one HIGH/CRITICAL mutable workstream at a time.

**Only WA-7A.4 is mutable now.** All other HIGH/CRITICAL workstreams remain read-only/regression-only unless WA-7A.4 proves a strict dependency.

## Preserved portfolio state

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- Notifications S13–S15.5 = CLOSED / regression-only.
- CIA, Sentinel, KronIA and unrelated product/data work = read-only/regression-only unless strict dependency.

## WA-7A.0 / 1 / 2 / 3 preserved

WA-7A.0 owns channel identifier compatibility. WA-7A.1 reuses REV/F5/F6 as the only canonical patient identity authority. WA-7A.2 owns verification/evidence and non-destructive channel-identifier lineage. WA-7A.3 owns explicit acquisition provenance at ingress on the existing immutable WA event ledger.

No parallel customer/person master exists. No channel alias is a marketing-consent record.

## WA-7A.3 closeout

PR #377 exact head `be4132223118f6009d5bba23116da5adbd2463f8` merged with expected head to runtime `5aab7b408882811d1c6cd00c6fb939f2f8de432e`.

Exact-head gates = 8/8 SUCCESS. Production migration `wa7a3_attribution_ingress_v1` applied/read back successfully. Railway exact runtime = SUCCESS.

Delivered at existing boundaries:

- explicit referral/CTWA provenance parsing;
- deterministic replay/idempotency;
- immutable `attribution.touchpoint` events on `aos_wa_events_v1`;
- service_role event-ledger least privilege = SELECT+INSERT only;
- private `aos_wa_attribution_touchpoints_v1` projection;
- touchpoint → message → conversation → optional WA-7A.1 canonical identity;
- no PHONE/BSUID/username-only attribution;
- no new customer/person/touchpoint master;
- no write to `aos_pacientes`, `aos_leads`, REV canonical identity or Marketing Attribution V2;
- no Ads Sync, AI/campaign activation, auto-reply or auto-routing.

Production readback preserves `7702` patients, `6061` leads, `21` messages, `2` conversations, `39` events and `0` fabricated real touchpoints. Marketing Attribution V2 hash remains `66b3d38378ca0610aa5de037d5be8292`. Safety remains `auto_routing=false`, `ai_send=false`, `copilot=false`, `auto_reply=false`, `human_send=true` unchanged.

Supabase REST/Auth still reports HTTP 402 after Railway deployment, therefore the fresh physical CTWA attribution canary remains external recovery debt. No bypass or synthetic replacement is allowed. WA-7A.3 is closed at CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY demonstrated boundary.

## WA-7A.4 — allowed mutations

Goal: establish governed marketing eligibility without conflating identity, reachability, attribution or consent.

Allowed discovery/build only when necessity is proven:

- existing consent / opt-in / opt-out data and functions;
- suppression lists and recipient-control structures;
- channel-specific preference records;
- evidence/source/timestamp of marketing permission or suppression;
- deterministic eligibility state and reason codes;
- WA-specific eligibility evidence if existing cross-channel structures cannot safely represent it;
- read-only adapters that reuse existing CIA/email/marketing controls;
- audit events required to make eligibility transitions explainable and replay-safe.

Required semantic ordering:

`canonical/channel identity → reachability → explicit consent/preferences/suppression evidence → channel eligibility decision`.

Attribution provenance from WA-7A.3 may inform origin/audit, but **never grants marketing permission by itself**.

Must not:

- treat phone/BSUID/username existence as consent;
- treat message receipt or CTWA click as blanket marketing opt-in;
- erase or override suppression to increase reach;
- build bulk sender or autonomous campaign execution;
- build Meta Ads Sync before WA-7B;
- activate Campaign Flow Router before WA-7C;
- mutate REV/F5 canonical identity to satisfy eligibility;
- widen clinical/customer data exposure.

## Mandatory invariants

- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`;
- `ATTRIBUTION EVIDENCE != CONSENT`;
- suppression wins over ambiguous eligibility;
- missing required consent fails closed;
- opt-out transitions are auditable and cannot be silently reversed;
- channel preferences remain channel-scoped;
- one person may be eligible on one governed channel and ineligible on another.

## Safety state

Preserve signed Meta gateway, replay/idempotency, Auth V3/2FA, exact-owner/assignment authority, queue privacy, 24h customer window and canary allowlist.

- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` remains the existing governed canary state and is not widened by WA-7A.4.

## External LIVE hold

Supabase SQL management works while REST/Auth remains HTTP 402. No auth bypass, service-role substitution for user/session canaries, blind provider retries or historical-evidence substitution is allowed.

## Lock transition rule

WA-7A.4 is now the sole mutable HIGH/CRITICAL lane. It remains locked until its scoped closeout is certified and GitHub CURRENT + Notion LAST are updated. No later WA functional phase may become mutable before that closeout.
