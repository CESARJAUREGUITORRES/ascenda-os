# WA-7A.2 — Identity Verification & Continuity — Necessity Gate & Evidence

**Captured:** 2026-08-25 America/Lima  
**Baseline:** `main@0521484257ccc7f027e865d44e79c33ff7884ea9`  
**Scope:** WhatsApp identity verification/continuity only.  
**Non-goals:** no new customer/person master, no attribution, no Ads sync, no canonical patient mutation.

## Current provider contract revalidation

The 2026 rollout is still moving. Revalidation on 2026-08-25 found an important correction to the July documentation:

- Meta does **not** expose a subscribable `user_id_update` webhook field.
- BSUID rotation arrives on the already-subscribed `messages` field as a WhatsApp **system message**.
- Current system types are:
  - `user_changed_number`: phone changed and the new phone may be supplied in `system.wa_id`;
  - `user_changed_user_id`: BSUID changed and no phone number is supplied; old/new BSUID lineage is provided through `previous_user_id` → `user_id` and optional parent equivalents.
- Provider/BSP documentation written before Meta's 2026-08-11 correction may still describe `user_id_update`; ASCENDA does not add a Meta subscription for it.

Current provider references checked:

- Meta documentation/changelog via current references documented by Botsense (retrieved 2026-08-25): `https://botsense.io/blog/whatsapp-bsuid-webhook-user-id-update/`
- Twilio WhatsApp username/BSUID concepts: `https://www.twilio.com/docs/whatsapp/key-concepts`
- Twilio username rollout: `https://www.twilio.com/en-us/changelog/whatsapp-usernames`
- YCloud BSUID/contact-request payload guide: `https://docs.ycloud.com/reference/webhook-updates-bsuid`
- Chatwoot issue #15537 for real integration gaps around `origin` and `recipient_user_id`: `https://github.com/chatwoot/chatwoot/issues/15537`

Provider-specific wrappers may rename fields, but ASCENDA's direct Meta gateway treats `messages[].system` as the canonical current Cloud API path.

## Discovery matrix

| Capability | Existing authority | Gap | WA-7A.2 decision |
|---|---|---|---|
| canonical patient identity | REV/F5/F6 + `aos_pacientes` | none | reuse; never mutate here |
| channel continuity PHONE/BSUID/PARENT_BSUID | `aos_wa_channel_aliases_v1` | no explicit supersession/verification metadata | extend existing ledger |
| idempotent provider evidence | `aos_wa_events_v1.event_key UNIQUE` | identity event types not interpreted | reuse existing event ledger |
| signed Meta ingress | WA-1 gateway | system/contact identity semantics dropped | extend parser only |
| PHONE+BSUID signed pair | WA-7A.0 stores both | no trust/source state | emit `identity.meta_pair` |
| BSUID rotation | none | system events ignored | emit/apply `identity.system_change` |
| REQUEST_CONTACT_INFO response | normal contacts message can be stored | `origin` and disclosed phone ignored | emit/apply `identity.contact_disclosure` |
| forwarded contact card | message can arrive | risk of false phone binding | CLAIMED evidence only; no alias mutation |
| `recipient_user_id` status evidence | parser preserves it in status event | not connected to alias verification | emit/apply delivered/read binding |
| Contact Book | Meta/provider-side | no local canonical authority needed | do not mirror; consume explicit webhook evidence only |
| username | display metadata | unsafe identity signal | never authority |
| new customer/person master | none needed | would duplicate REV | forbidden |

## Necessity gate

**Build is necessary, but only at the existing boundaries.**

No new customer/person/identity-master table is required. No new generic event table is required.

WA-7A.2 adds only:

1. lineage + verification metadata to `aos_wa_channel_aliases_v1`;
2. a service-only identity-event trigger on the existing `aos_wa_events_v1` ledger;
3. parser support in `app/wa-gateway.js` for current system messages, contact disclosure origin, signed pair evidence and delivered/read `recipient_user_id` evidence;
4. native `request_contact_info` outbound payload support through the existing governed send path;
5. Zero-Cost behavioral/concurrency/rollback tests.

## Verification semantics

`VERIFIED` means the **WhatsApp channel fact** is attested by provider evidence. It does not mean a canonical patient merge has occurred.

Automatic trusted sources in this slice:

- `META_SIGNED_MESSAGE_PAIR` — signed inbound carried PHONE + BSUID together;
- `META_SYSTEM_CHANGE` — current Meta system identity transition;
- `META_CONTACT_REQUEST` — `contacts[].origin=contact_request` native response;
- `META_STATUS_RECIPIENT_USER_ID` — delivered/read status binds recipient BSUID to an already-bound outbound destination.

Non-attested evidence:

- `origin=other` contact cards remain `CLAIMED` evidence only and do **not** become routing aliases;
- typed/manual phone text is not parsed into identity authority and therefore can never become VERIFIED automatically;
- Contact Book is not queried or mirrored as a CRM.

Valid states:

`VERIFIED / CLAIMED / UNKNOWN / CONFLICT`.

## Continuity rules

- A system transition resolves its conversation from previously known scoped BSUID/parent-BSUID lineage, never username.
- Old BSUID is retained and marked inactive with `valid_to`, `superseded_by`, `supersession_reason`.
- New BSUID becomes the active channel alias for the same conversation.
- If Meta supplies a new phone, the old active phone is retired and the new one is verified.
- If the BSUID rotates and no new phone may be supplied, one known old active phone is retired rather than remaining as stale canonical evidence.
- Multiple active prior PHONE aliases are an explicit `CONFLICT`; no blind selection occurs.
- A native contact request may supersede one prior active phone because WhatsApp attests the disclosed phone as the user's own current contact information; multiple prior phones remain conflict/fail-closed.
- A phone already owned by another conversation cannot be stolen by new evidence.
- A competing old→new BSUID transition is serialized; lineage may not fork.

## WA-7A.1 interaction

WA-7A.1 reads **active PHONE aliases only**. Therefore retiring a stale phone after a BSUID-only phone-number change deliberately causes the canonical projection to become `UNRESOLVED` until new governed PHONE evidence is available. This is safer than silently carrying a stale patient match forward.

No WA-7A.2 event writes to REV/F5/F6 or `aos_pacientes`.

## Idempotency and conflict behavior

Identity evidence is persisted in existing `aos_wa_events_v1` with deterministic `event_key` values.

- replay uses the existing unique event key / `ON CONFLICT` behavior;
- a conflicting event is persisted with `status=CONFLICT` and does not mutate aliases;
- provider webhook processing can therefore acknowledge a durable conflict instead of retrying forever;
- advisory locks serialize alias transitions and prevent concurrent lineage forks.

## Rollback

Rollback is allowed only before WA-7A.2 identity evidence/lineage exists. Once evidence exists, the rollback fails closed because dropping lineage columns would be destructive history loss.

## LIVE boundary

As of this capture, Supabase REST/Auth continues HTTP 402. Management SQL remains available.

Therefore WA-7A.2 may certify code, Zero-Cost, exact-head CI, production schema/readback and Railway runtime deployment if those gates pass. It must **not** claim fresh browser/Auth/Meta/REQUEST_CONTACT_INFO/BSUID system-event LIVE certification until the normal REST/Auth/provider path recovers.
