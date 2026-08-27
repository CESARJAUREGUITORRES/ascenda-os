# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-08-27 America/Lima  
**ACTIVE PROGRAM:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT GATE / MUTABLE LOCK:** `WA-7A.4 — MARKETING ELIGIBILITY FOUNDATION`  
**WA-7A.3 CERT HEAD:** `be4132223118f6009d5bba23116da5adbd2463f8`  
**WA-7A.3 RUNTIME MERGE:** `5aab7b408882811d1c6cd00c6fb939f2f8de432e`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
7. `docs/control/WHATSAPP_WA_7A_3_ATTRIBUTION_INGRESS_CERTIFICATE_20260827.md`;
8. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
9. exact GitHub + Supabase + Railway/runtime evidence;
10. Notion executive continuity.

Historical chat/doc snapshots never override exact CURRENT + runtime evidence.

## Portfolio state

- REV-F5 — PRODUCTION CERTIFIED 100%.
- REV-F6 — PRODUCTION CERTIFIED 100%.
- REV-F7 — paused while WA owns the mutable lane.
- WhatsApp Revenue Hub V2 — ACTIVE.
- Notifications S13–S15.5 — CLOSED / regression-only.
- CIA, Sentinel, KronIA and unrelated HIGH/CRITICAL work — read-only/regression-only unless strict WA dependency.

## WhatsApp V2 current

- `WA-V2-0` = CLOSED.
- `WA-3` = OFFLINE CERTIFIED / LIVE recovery debt.
- `WA-3.5` = OFFLINE CERTIFIED 100% / LIVE recovery debt.
- `WA-7A.0` = CLOSED at demonstrated identity-compatibility boundary.
- `WA-7A.1` = CLOSED at demonstrated identity-resolution boundary.
- `WA-7A.2` = CLOSED at demonstrated CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY boundary.
- `WA-7A.3` = CLOSED at demonstrated CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY boundary.
- `WA-7A.4` = ACTIVE MUTABLE LOCK.
- WA-4 existing infrastructure remains SAFE-OFF and does not certify WA-4A/B/C.

## Identity + attribution foundation through WA-7A.3

Canonical person identity remains REV/F5/F6. WhatsApp uses scoped channel aliases and does not create another customer/person master.

- WA-7A.0: PHONE / BSUID / PARENT_BSUID transport and conversation continuity.
- WA-7A.1: read-only WA conversation → REV canonical identity projection.
- WA-7A.2: verification/source/evidence and non-destructive identifier supersession lineage.
- WA-7A.3: explicit provider attribution provenance as immutable `attribution.touchpoint` events on the existing WA event ledger.

Hard separation:

`channel alias != canonical patient identity != acquisition touchpoint != marketing eligibility`.

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.

Username is display-only. BSUID is scoped channel identity. Neither phone, BSUID nor username can fabricate attribution.

## WA-7A.3 certification evidence

PR #377 exact head `be4132223118f6009d5bba23116da5adbd2463f8` merged with `expected_head_sha` to runtime `5aab7b408882811d1c6cd00c6fb939f2f8de432e`.

Exact-head CI = 8/8 SUCCESS:

- WA-7A.3 Attribution Ingress `33100445915`;
- WA-7A.2 Identity Verification & Continuity `33100445907`;
- WA-7A.0 Identity Compatibility `33100445890`;
- WA-1 Secure Gateway `33100445849`;
- Phase S WA3 Stabilization `33100445962`;
- Ascenda CI `33100446005`;
- Performance Guard `33100445942`;
- ASC-PERF Audit 360 `33100445826`.

Delivered:

- explicit `messages[].referral` parser;
- deterministic provider-message replay identity;
- explicit `ctwa_clid`/source/ad/provider-lead/campaign provenance only;
- safe source URL normalization;
- immutable `attribution.touchpoint` events;
- private `aos_wa_attribution_touchpoints_v1` projection to conversation + optional WA-7A.1 canonical identity;
- append-only runtime ACL on `aos_wa_events_v1`;
- destructive rollback guard;
- no phone/BSUID/username-only attribution;
- no new customer/person/touchpoint master;
- no `aos_pacientes`, `aos_leads`, REV or Marketing Attribution V2 mutation;
- no Ads Sync, AI send, auto-reply, auto-routing or campaign activation.

## Production readback

Migration `wa7a3_attribution_ingress_v1` is applied and recorded.

Readback:

- adapter view + immutable trigger exist;
- service_role ledger privileges = SELECT+INSERT only;
- adapter service_role SELECT=true, anon/authenticated=false;
- patients = `7702`;
- leads = `6061`;
- WA messages = `21`;
- conversations = `2`;
- events = `39`;
- real touchpoints = `0`;
- Marketing function `aos_marketing_touchpoints_v2(date,date)` MD5 = `66b3d38378ca0610aa5de037d5be8292`, unchanged;
- `auto_routing=false`, `ai_send=false`, `copilot=false`, `auto_reply=false`, `human_send=true` unchanged.

Railway exact runtime `5aab7b408882811d1c6cd00c6fb939f2f8de432e` = SUCCESS and passed configured `/health`.

## Production LIVE hold

Current Supabase production telemetry after Railway deployment still shows HTTP 402 on `/rest-admin/v1/ready`, `/auth/v1/health` and actual `/rest/v1/*` application traffic through 2026-08-27 18:07 UTC.

No Auth bypass, service-role substitution or fabricated CTWA webhook is allowed. Therefore fresh physical provider attribution remains pending external recovery and does not block closing WA-7A.3 at its demonstrated technical/runtime boundary.

## WA-7A.4 active execution

Goal: build the minimum governed Marketing Eligibility Foundation while preserving the separation among identity, reachability, attribution evidence and permission to market.

First loop:

1. revalidate exact CURRENT and exclusive WA-7A.4 lock;
2. inventory existing consent, opt-in/out, suppression, recipient-control and channel-preference data/functions;
3. necessity gate before new schema;
4. define eligibility states and explicit reason/evidence codes;
5. reuse existing CIA/email/marketing suppression authority when compatible;
6. add WA-specific evidence only when strictly necessary;
7. ensure attribution provenance is evidence, never implicit consent;
8. fail closed on missing/ambiguous marketing permission where required;
9. contract-test opt-in, opt-out, suppression, channel preference, conflict, replay and historical compatibility;
10. exact-head Zero-Cost CI + anti-drift;
11. production apply/readback only when safe;
12. no bulk sender, Ads Sync, campaign router or autonomous outbound activation in this slice;
13. certify only demonstrated boundary;
14. GitHub CURRENT + Notion LAST before advancing.

Hard rule: `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.
