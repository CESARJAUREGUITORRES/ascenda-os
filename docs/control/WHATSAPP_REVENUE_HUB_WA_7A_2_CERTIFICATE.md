# WA-7A.2 — Identity Verification & Continuity — Certificate

**Status:** CLOSED AT DEMONSTRATED BOUNDARY  
**Captured:** 2026-08-27 America/Lima  
**Exact implementation head:** `8106f0ba6d644c062168fe84dc52dd83e50edb69`  
**Merge / runtime:** `a943dca94534e9016de158177131e88bbcb72b73`  
**PR:** `#376`  
**NEXT LOCK:** `WA-7A.3 — Attribution Ingress`

## Necessity result

WA-7A.2 did not need a new customer/person master or a new generic event ledger. It reuses:

- `aos_wa_channel_aliases_v1` for scoped PHONE / BSUID / PARENT_BSUID continuity;
- `aos_wa_events_v1` for idempotent provider evidence;
- WA-7A.1 + REV/F5/F6 for canonical patient resolution;
- the signed WA-1 gateway and existing governed outbound path.

The minimum addition is verification/source/evidence plus non-destructive alias supersession lineage, provider identity-event interpretation, native contact-info disclosure handling and recipient-user binding.

## Provider contract used

Current 2026 contract discovery showed that direct Meta identity rotation is consumed on the existing `messages` webhook as system messages rather than through a separate subscribable `user_id_update` field.

Supported identity evidence in this slice:

- `user_changed_number`;
- `user_changed_user_id`;
- signed PHONE + BSUID pairs;
- native `contacts[].origin=contact_request` disclosure;
- delivered/read `recipient_user_id` binding;
- optional parent-BSUID evidence.

Username remains display-only. Contact Book is not copied into ASCENDA as a CRM authority.

## Verification semantics

Channel facts may be `VERIFIED / CLAIMED / UNKNOWN / CONFLICT`.

Automatic VERIFIED sources are limited to explicit provider evidence:

- `META_SIGNED_MESSAGE_PAIR`;
- `META_SYSTEM_CHANGE`;
- `META_CONTACT_REQUEST`;
- `META_STATUS_RECIPIENT_USER_ID`.

Forwarded/manual contact cards remain CLAIMED evidence only and do not create routing aliases. Typed/manual phone text is never auto-VERIFIED.

## Continuity semantics

- old BSUID is retained, made inactive and linked through `superseded_by`;
- new BSUID remains on the same conversation;
- new provider-attested phone may supersede one prior phone;
- BSUID-only rotation retires stale PHONE evidence instead of silently carrying a stale canonical patient match;
- phone/BSUID already owned by another conversation cannot be stolen;
- multiple competing aliases fail closed;
- advisory locks prevent concurrent lineage forks;
- deterministic event keys preserve replay/idempotency;
- rollback refuses to delete real lineage/evidence once it exists.

No WA-7A.2 path writes `aos_pacientes` or REV canonical identity.

## Exact-head CI

At `8106f0ba6d644c062168fe84dc52dd83e50edb69` all relevant workflows completed SUCCESS:

- `ASCENDA WA-7A.2 Identity Verification & Continuity` — run `32911787992`;
- `ASCENDA WA-7A.0 Identity Compatibility` — run `32911788228`;
- `ASCENDA WA-1 Secure WhatsApp Gateway` — run `32911788014`;
- `ASCENDA PHASE S WA3 Stabilization` — run `32911787931`;
- `Ascenda CI` — run `32911788025`;
- `ASCENDA Performance Guard CI` — run `32911787970`;
- `ASCENDA ASC-PERF Audit 360` — run `32911788017`.

Behavioral coverage includes system rotation, PHONE+BSUID pair, BSUID-only continuity, REQUEST_CONTACT_INFO, forwarded/manual contact non-verification, recipient_user_id, conflict/no-theft, stale-phone retirement, replay/idempotency, concurrent fork prevention, WA-7A.0/7A.1 regressions and rollback guard/reapply.

## Production / Railway readback

Production contains migration `wa7a2_identity_verification_continuity_v1` (management migration version `20260825234845`).

Readback on 2026-08-27:

- verification columns exist;
- `aos_wa7a2_apply_identity_event_v1()` exists;
- identity trigger exists;
- messages = `21` preserved;
- conversations = `2` preserved;
- aliases total = `2`, both active PHONE;
- both legacy aliases remain `UNKNOWN / LEGACY_OBSERVED`;
- real WA-7A.2 identity events = `0`;
- superseded aliases = `0`;
- aliases with evidence = `0`;
- conflict aliases = `0`.

This is the correct no-fabrication result: historical PHONE observations were not retroactively promoted to VERIFIED and no synthetic lineage was inserted.

Railway external status for exact merge `a943dca94534e9016de158177131e88bbcb72b73` = SUCCESS.

Safety readback:

- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` remains the pre-existing governed canary state.

## LIVE boundary

Supabase REST remains HTTP 402 on real ASCENDA traffic as of 2026-08-27. Therefore fresh Auth/browser/provider/physical REQUEST_CONTACT_INFO and real BSUID-rotation canaries remain externally blocked.

No Auth bypass, service-role substitution or historical provider evidence is used to manufacture LIVE certification.

**WA-7A.2 CODE / CI / ZERO-COST / PROD-SCHEMA / PROD-READBACK / RAILWAY = CLOSED AT DEMONSTRATED BOUNDARY.**  
**WA-7A.2 FRESH LIVE PROVIDER END-TO-END 100% = NO while the 402 hold remains.**
