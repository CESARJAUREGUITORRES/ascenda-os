# WA-7A.0 — Identity Compatibility — Production Schema Certificate

**Captured:** 2026-08-25 America/Lima  
**Status:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**PR:** `#374 — MERGED`  
**Certified exact head:** `8d081b9be16edd2e7858e015faf0d32ff8fb87fd`  
**Runtime merge:** `6e6e69eac108e3a4497425d5c53b757760185ccc`

## Certification matrix

- CODE = **CERTIFIED 100%**.
- EXACT-HEAD CI / ZERO-COST = **CERTIFIED 100%**.
- Production additive schema apply = **PASS**.
- Production DB readback = **PASS**.
- Existing PHONE compatibility = **PASS, non-destructive readback**.
- Railway exact merge deployment = **SUCCESS**.
- Supabase REST/Auth = **BLOCKED / HTTP 402** at closeout.
- Fresh Meta/provider canary = **NOT CERTIFIED** because the governed runtime path depends on REST/Auth recovery.
- Fresh BSUID LIVE inbound/outbound = **NOT CERTIFIED**; production currently contains zero BSUID message rows.

This certificate deliberately does not claim `WA-7A.0 LIVE/PRODUCTION CERTIFIED 100%`.

## Exact-head gates

At `8d081b9be16edd2e7858e015faf0d32ff8fb87fd`, SUCCESS:

- `ASCENDA WA-7A.0 Identity Compatibility` run `32891990086`;
- `Ascenda CI` run `32891990110`;
- `ASCENDA PHASE S WA3 Stabilization` run `32891990219`;
- `ASCENDA WA-1 Secure WhatsApp Gateway` run `32891990111`;
- `ASCENDA Performance Guard CI` run `32891990136`;
- `ASCENDA ASC-PERF Audit 360` run `32891990065`.

The dedicated push run `32891986818` also completed SUCCESS after the rollback-harness authentication fix.

## Production migrations applied

Supabase project: `ituyqwstonmhnfshnaqz`.

Applied and recorded:

- `20260825195757 — wa7a0_identity_compatibility_v1`;
- `20260825195810 — wa7a0_direct_insert_compat_v1`;
- `20260825195821 — wa7a0_phone_key_compat_v1`.

## Production readback

After apply:

- messages preserved: `21`;
- conversations: `2`;
- PHONE conversations: `2`;
- BSUID conversations: `0`;
- invalid/null address contracts: `0`;
- PHONE address mismatches: `0`;
- typed `:PHONE:` keys remaining: `0`;
- aliases: `2`, both PHONE;
- alias ledger RLS = ON;
- alias ledger FORCE RLS = ON;
- anon SELECT = denied;
- authenticated SELECT = denied;
- service_role SELECT = allowed;
- WA-7A.0 functions and triggers = present.

Existing-message smoke:

- `21/21` messages remain bound to a conversation;
- `14` inbound PHONE messages;
- `7` outbound PHONE messages;
- `21/21` messages resolve to PHONE conversations with PHONE alias evidence;
- BSUID message rows = `0`.

Safety readback:

- `auto_routing=false`;
- `ai_send=false`;
- `human_send=true` preserved from the pre-existing governed canary state;
- no WA-7A.0 action enabled Copilot or auto-reply.

## Railway

Commit status for exact runtime merge `6e6e69eac108e3a4497425d5c53b757760185ccc`:

- context: `ASCENDA-OS - ascenda-os`;
- state: `success`.

Production health path remains `/health` per `app/railway.json`.

## LIVE boundary / external blocker

Fresh Supabase API logs at closeout still show HTTP `402` for:

- `/rest-admin/v1/ready`;
- `/auth/v1/health`;
- real `/rest/v1/*` calls made by ASCENDA.

Therefore SQL management access being available does **not** mean REST/Auth recovered.

Provider evidence exists historically (`21` rows with provider_message_id; latest provider timestamp 2026-08-22), but historical evidence cannot substitute a fresh provider/BSUID canary.

Do not bypass Auth/2FA, owner, assignment, canary allowlist or idempotency to manufacture a LIVE result.

## Post-recovery recertification debt

When `402 → 200`:

1. Railway `/health` fresh probe;
2. Auth V3 + 2FA;
3. REST read path;
4. current Meta/provider health;
5. signed inbound PHONE regression;
6. real BSUID-only or PHONE+BSUID inbound when provider supplies it;
7. governed allowlisted human outbound;
8. provider delivery-state readback;
9. ownership/handoff isolation;
10. visual Revenue Inbox smoke.

## Lock handoff

`WA-7A.0` is closed at the demonstrated CODE/CI/PROD-SCHEMA/PHONE-COMPAT boundary.

**NEXT MUTABLE LOCK: `WA-7A.1 — Identity Resolution`.**

WA-7A remains the sole HIGH/CRITICAL mutable program. Other HIGH/CRITICAL workstreams remain read-only unless a strict WA dependency is proven.
