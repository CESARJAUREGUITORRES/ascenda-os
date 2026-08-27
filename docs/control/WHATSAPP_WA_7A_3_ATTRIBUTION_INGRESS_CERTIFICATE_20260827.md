# WA-7A.3 — Attribution Ingress — Final Certificate

**Date:** 2026-08-27 America/Lima  
**Status:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**Certified exact head:** `be4132223118f6009d5bba23116da5adbd2463f8`  
**PR:** `#377`  
**Runtime merge:** `5aab7b408882811d1c6cd00c6fb939f2f8de432e`

## Decision

Necessity gate = `BUILD YES / NEW PHYSICAL TOUCHPOINT TABLE NO`.

WA-7A.3 reuses `aos_wa_events_v1` as immutable provenance storage and projects explicit acquisition evidence through the private read-only view `aos_wa_attribution_touchpoints_v1`. It does not create a parallel customer/person/touchpoint master and does not write `aos_leads`, `aos_pacientes`, REV canonical identity or Marketing Attribution V2.

## Delivered contract

- parses explicit Meta/WhatsApp `messages[].referral` evidence;
- preserves provider-supplied `ctwa_clid`, source id/type/url, `ad_id`, provider lead id, campaign source, headline/body/media evidence and provider timestamps;
- emits deterministic `attribution.touchpoint` events keyed by provider message id;
- replay cannot create duplicate touchpoints;
- PHONE, BSUID, username or canonical patient identity alone never infer attribution;
- missing referral evidence produces no fabricated attribution;
- touchpoint → provider message → conversation → optional WA-7A.1 canonical identity is read-only;
- `service_role` retains only SELECT+INSERT on the WA event ledger; UPDATE/DELETE/TRUNCATE are denied;
- accepted `attribution.touchpoint` evidence is protected by an immutable trigger;
- adapter is SELECT-only for `service_role` and unavailable to `anon`/`authenticated`;
- rollback fails closed once accepted provenance exists.

## Exact-head CI / Zero-Cost

All exact-head gates on `be4132223118f6009d5bba23116da5adbd2463f8` completed `SUCCESS`:

1. Ascenda CI;
2. WA-1 Secure WhatsApp Gateway;
3. WA-7A.0 Identity Compatibility;
4. WA-7A.2 Identity Verification & Continuity;
5. WA-7A.3 Attribution Ingress;
6. Phase S WA3 Stabilization;
7. Performance Guard CI;
8. ASC-PERF Audit 360.

The dedicated WA-7A.3 job passed parser contracts, scope invariants, isolated Supabase bootstrap, DB lint, persistence/security behavior, destructive rollback guard, rollback/reapply, WA-7A.2 regression and WA-7A.0/1 regressions.

## Production apply / readback

Migration `wa7a3_attribution_ingress_v1` applied successfully to production.

Readback after apply:

- migration present = true;
- adapter view present = true;
- immutable trigger present = true;
- `service_role`: SELECT=true, INSERT=true, UPDATE=false, DELETE=false, TRUNCATE=false;
- adapter SELECT: service_role=true, anon=false, authenticated=false.

Business/runtime fingerprints remained unchanged:

- `aos_pacientes = 7702`;
- `aos_leads = 6061`;
- WA messages = `21`;
- WA conversations = `2`;
- WA events = `39`;
- real attribution touchpoints = `0`;
- `aos_marketing_touchpoints_v2(date,date)` MD5 = `66b3d38378ca0610aa5de037d5be8292` before/after;
- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` preserved as the pre-existing governed state.

## Merge / Railway

PR #377 merged with `expected_head_sha=be4132223118f6009d5bba23116da5adbd2463f8`.

Runtime merge: `5aab7b408882811d1c6cd00c6fb939f2f8de432e`.

Railway status for that exact merge = `SUCCESS` for `ascenda-os-production.up.railway.app`. Production `railway.json` requires `/health`, therefore the deployed runtime passed the configured Railway healthcheck.

## LIVE boundary

Fresh physical CTWA attribution E2E was **not** executed because the external Supabase REST/Auth hold remains active after deployment. Current production API telemetry still reports HTTP 402 on `/rest-admin/v1/ready`, `/auth/v1/health` and real `/rest/v1/*` traffic through 2026-08-27 18:07 UTC.

No Auth bypass, service-role substitution, fabricated webhook or historical evidence is accepted as a replacement for a real provider canary.

Therefore:

- `WA-7A.3 CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY = CERTIFIED`;
- `WA-7A.3 FRESH PROVIDER LIVE E2E = PENDING EXTERNAL 402 RECOVERY`;
- `WA-7A.3 = CLOSED AT DEMONSTRATED BOUNDARY`.

## Handoff

**NEXT / ACTIVE MUTABLE LOCK:** `WA-7A.4 — Marketing Eligibility Foundation`.

WA-7A.4 must preserve `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`, reuse existing consent/suppression structures where possible, and must not introduce a bulk sender or campaign activation in this slice.
