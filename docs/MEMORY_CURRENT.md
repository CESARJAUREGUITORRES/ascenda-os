# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-08-25 America/Lima  
**ACTIVE PROGRAM:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT GATE:** `WA-7A.1 — IDENTITY RESOLUTION`  
**RUNTIME MERGE:** `6e6e69eac108e3a4497425d5c53b757760185ccc`  
**WA-7A.0 CERT HEAD:** `8d081b9be16edd2e7858e015faf0d32ff8fb87fd`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_WA_7A_0_CERTIFICATE.md`;
8. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
9. exact GitHub runtime + Railway + Supabase evidence;
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
- `WA-7A.0` = CLOSED at demonstrated CODE/CI/ZERO-COST/PROD-SCHEMA/PHONE-COMPAT boundary.
- `WA-7A.1` = ACTIVE MUTABLE LOCK.
- `WA-7A.2/3/4` = blocked behind WA-7A.1 closeout.
- WA-4 existing infrastructure remains SAFE-OFF and does not certify WA-4A/B/C.

## WA-7A.0 closeout facts

PR #374 merged with exact head `8d081b9be16edd2e7858e015faf0d32ff8fb87fd`.

Runtime merge: `6e6e69eac108e3a4497425d5c53b757760185ccc`.

Exact-head CI matrix = SUCCESS:

- WA-7A.0 Identity Compatibility;
- WA-1 Secure Gateway;
- WA-3 Stabilization;
- Ascenda CI;
- Performance Guard;
- ASC-PERF Audit 360.

Production Supabase migrations applied:

- `wa7a0_identity_compatibility_v1`;
- `wa7a0_direct_insert_compat_v1`;
- `wa7a0_phone_key_compat_v1`.

Production readback:

- messages = 21 preserved;
- conversations = 2 PHONE;
- aliases = 2 PHONE;
- invalid/null channel addresses = 0;
- PHONE address mismatch = 0;
- typed `:PHONE:` key regressions = 0;
- BSUID production rows = 0;
- all 21 existing messages remain bound to PHONE conversations with PHONE alias evidence;
- alias RLS/FORCE RLS enabled and direct anon/authenticated reads denied.

Railway exact runtime merge status = SUCCESS.

## Production hold

Supabase SQL management access works, but fresh API logs still return HTTP 402 on `/rest-admin/v1/ready`, `/auth/v1/health` and real `/rest/v1/*` requests.

Therefore:

- `WA-7A.0 LIVE/PROVIDER/BSUID CERTIFIED 100% = NO`;
- no authenticated UI canary is currently valid;
- no current Meta/provider canary may be manufactured via service-role/auth bypass;
- historical provider evidence remains historical only.

Safety remains:

- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` preserved as pre-existing governed canary state.

## WA-7A.1 next execution

Goal: connect WhatsApp channel aliases to canonical ASCENDA identity using governed REV/F5 boundaries without a parallel customer master.

First loop:

1. revalidate exact `main` and current lock;
2. discover REV/F5 canonical identity owners/functions/tables and existing WA alias contracts;
3. build evidence matrix `existing / missing / unsafe / duplicate / canonical owner`;
4. freeze WA-7A.1 DoD before mutation;
5. design additive fail-closed alias→canonical resolution;
6. add conflict/review semantics and audit evidence;
7. local/Zero-Cost DB tests including PHONE+BSUID continuity and conflict cases;
8. exact-head CI;
9. anti-drift;
10. production apply/readback only when safe;
11. merge expected head;
12. Railway if runtime changes;
13. GitHub CURRENT;
14. Notion LAST;
15. advance only after WA-7A.1 closeout.

Hard rules: no username merge authority, no universal-BSUID assumption, no phone-only attribution, no broad Ads sync, no AI/auto-routing activation.
