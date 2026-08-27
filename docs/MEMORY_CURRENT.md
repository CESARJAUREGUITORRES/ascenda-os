# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-08-27 America/Lima  
**ACTIVE PROGRAM:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT GATE:** `WA-7A.3 — ATTRIBUTION INGRESS`  
**WA-7A.2 EXACT HEAD:** `8106f0ba6d644c062168fe84dc52dd83e50edb69`  
**WA-7A.2 MERGE:** `a943dca94534e9016de158177131e88bbcb72b73`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_WA_7A_2_CERTIFICATE.md`;
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
- `WA-7A.2` = CLOSED at CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY demonstrated boundary.
- `WA-7A.3` = ACTIVE MUTABLE LOCK.
- `WA-7A.4` = blocked behind WA-7A.3.
- WA-4 existing infrastructure remains SAFE-OFF and does not certify WA-4A/B/C.

## Identity foundation through WA-7A.2

Canonical person identity remains REV/F5/F6. WhatsApp uses the existing scoped alias ledger and does not create another customer/person master.

- WA-7A.0: PHONE / BSUID / PARENT_BSUID transport and conversation continuity.
- WA-7A.1: read-only WA conversation → REV canonical identity projection.
- WA-7A.2: verification/source/evidence and non-destructive identifier supersession lineage.

Hard separation:

`channel alias != canonical patient identity != acquisition touchpoint`.

Username is display-only. BSUID is scoped channel identity, not universal person identity.

## WA-7A.2 certification evidence

PR #376 exact head `8106f0ba6d644c062168fe84dc52dd83e50edb69` merged to `a943dca94534e9016de158177131e88bbcb72b73`.

Exact-head SUCCESS:

- WA-7A.2 Identity Verification & Continuity `32911787992`;
- WA-7A.0 Identity Compatibility `32911788228`;
- WA-1 Secure Gateway `32911788014`;
- Phase S WA3 Stabilization `32911787931`;
- Ascenda CI `32911788025`;
- Performance Guard `32911787970`;
- ASC-PERF Audit 360 `32911788017`.

Delivered:

- `VERIFIED / CLAIMED / UNKNOWN / CONFLICT` channel-fact states;
- verification sources/evidence timestamps;
- old→new BSUID/PARENT_BSUID lineage using inactive history + `superseded_by`;
- current Meta system identity-change parsing (`user_changed_number`, `user_changed_user_id`);
- signed PHONE+BSUID pair evidence;
- native `contact_request` verification;
- forwarded/manual contact is CLAIMED only;
- delivered/read `recipient_user_id` binding;
- governed `request_contact_info` outbound payload;
- replay/idempotency, conflict/no-theft, concurrent fork prevention and destructive rollback guard.

No new person/customer/event master. No `aos_pacientes`/REV canonical mutation. No Attribution, Ads Sync or AI/campaign automation.

## Production readback

Production migration `wa7a2_identity_verification_continuity_v1` is recorded as management version `20260825234845`.

As of 2026-08-27:

- WA-7A.2 schema/function/trigger exist;
- messages = 21;
- conversations = 2;
- aliases = 2 active PHONE;
- both legacy aliases remain `UNKNOWN / LEGACY_OBSERVED`;
- real identity events = 0;
- superseded aliases = 0;
- aliases with evidence = 0;
- conflict aliases = 0.

This no-op-on-history result is intentional: existing observations were not retroactively promoted to VERIFIED and no synthetic lineage was created.

Railway external status for merge `a943dca94534e9016de158177131e88bbcb72b73` = SUCCESS.

Safety remains:

- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` preserved as pre-existing governed canary state.

## Production hold

Current Supabase API logs on 2026-08-27 still return HTTP 402 on real `/rest/v1/*` ASCENDA traffic. SQL management works, but fresh Auth/browser/provider/REQUEST_CONTACT_INFO/BSUID-rotation canaries cannot be certified through the governed path.

No auth/service-role bypass is allowed. Therefore WA-7A.2 is CLOSED only at the demonstrated technical/product-schema boundary, not fresh provider LIVE 100%.

## WA-7A.3 next execution

Goal: preserve explicit acquisition provenance as immutable first-inbound touchpoint evidence without confusing attribution with identity.

First loop:

1. revalidate exact CURRENT and exclusive lock;
2. discover current Meta CTWA/referral payload and provider equivalents;
3. audit existing ASCENDA marketing attribution/touchpoint structures before adding schema;
4. build evidence matrix / necessity gate;
5. preserve only explicitly supplied `ctwa_clid`, referral/source, ad/lead/campaign and safe referral evidence;
6. create/reuse immutable touchpoint identity with deterministic replay/idempotency;
7. link touchpoint → canonical WA conversation → optional canonical patient via existing WA-7A.1 resolution only;
8. test missing/malformed/referral replay/conflict/multi-touchpoint cases;
9. exact-head Zero-Cost CI and anti-drift;
10. production apply/readback only when safe;
11. Railway only if runtime changes;
12. certify only demonstrated boundary;
13. GitHub CURRENT;
14. Notion LAST;
15. advance to WA-7A.4 only after closeout.

Hard rules: `BSUID != touchpoint`; no phone/username/BSUID-only attribution; no broad Ads Sync before WA-7B; no canonical identity mutation; no AI/auto-routing/campaign activation.
