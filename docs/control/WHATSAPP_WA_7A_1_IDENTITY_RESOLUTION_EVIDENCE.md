# WA-7A.1 — Identity Resolution — Necessity Gate & Evidence

**Captured:** 2026-08-25 America/Lima  
**Baseline:** `main@4abfdddbd8c80c88d40699fb8e1ffb6e2c60af0e`  
**Scope:** WhatsApp channel alias → existing ASCENDA canonical patient identity.  
**Non-goal:** no new CRM/person/customer master and no patient merge.

## Discovery result

ASCENDA already owns canonical identity through REV/F5/F6:

- `aos_pacientes.ID_PACIENTE` is the canonical patient subject;
- `aos_rev_patient_identity_alias_v2` already maps governed `PHONE / DOCUMENT / EMAIL / CANONICAL_ID` aliases to `canonical_patient_id` with candidate count, status, confidence and evidence;
- `aos_rev_resolve_patient_identity_v2` already returns `MATCH / UNRESOLVED / IDENTITY_CONFLICT` and does not use fuzzy/phone-proximity identity;
- F5 reviewed matches feed the REV alias bridge and remain auditable;
- Patient 360 consumes canonical patient identity and already keeps conflicts visible;
- `aos_cia_contact_identity_v1` remains a compatibility/contact projection and is not allowed to become a second patient merge authority.

WA-7A.0 already owns channel continuity:

- `aos_wa_channel_aliases_v1` binds `PHONE / BSUID / PARENT_BSUID` to a WhatsApp conversation;
- BSUID and PHONE can converge on the same conversation;
- conflicting channel aliases fail closed;
- username is not an alias key.

## Production observation before implementation

At discovery time:

- active WhatsApp PHONE aliases: `2`;
- those two aliases currently have `0` exact REV patient matches;
- they also have `0` current lead/CIA patient links under the same governed phone normalization;
- therefore the correct current result for those conversations is `UNRESOLVED`, not creation of a new patient/person record.

This is expected evidence that identity resolution must be able to represent `UNRESOLVED` safely.

## Necessity gate

| Capability | Existing authority | Gap | Decision |
|---|---|---|---|
| canonical patient subject | REV / `aos_pacientes` | none | reuse |
| governed PHONE resolution | `aos_rev_patient_identity_alias_v2` | none | reuse |
| conflict/candidate handling | REV | none | reuse |
| PHONE↔BSUID conversation continuity | WA-7A.0 alias ledger | none | reuse |
| BSUID itself as patient identity | none by design | must not be invented | keep non-authoritative |
| conversation → canonical patient projection | none | minimal missing bridge | build derived view/RPC |
| new CRM/customer master | not needed | would duplicate authority | forbidden |

## Minimal architecture

`WA PHONE/BSUID aliases → WA conversation → active PHONE evidence → REV Patient Identity Bridge V2 → canonical_patient_id | UNRESOLVED | IDENTITY_CONFLICT`

Important semantics:

- a BSUID never maps directly to `canonical_patient_id` merely because it exists;
- a BSUID-only message can retain canonical continuity when its conversation already has governed PHONE evidence from an earlier observation;
- a genuinely BSUID-only conversation with no corroborating canonical evidence remains `UNRESOLVED`;
- if REV marks a PHONE alias conflicting, WA returns `IDENTITY_CONFLICT`;
- if multiple active PHONE aliases on one conversation resolve to different canonical patients, WA returns `IDENTITY_CONFLICT`;
- no canonical patient row, F5 classification or REV alias is mutated by WA-7A.1.

## Implementation boundary

WA-7A.1 adds only:

- private derived view `aos_wa_identity_resolution_v1`;
- permissioned read RPC `aos_wa7a1_resolve_conversation_identity_v1`;
- Zero-Cost behavioral and rollback tests.

The bridge intentionally exposes no raw phone, BSUID, username or REV identifier key.

## LIVE boundary

Supabase management SQL can be read/written, but REST/Auth remains HTTP 402. Therefore WA-7A.1 may certify code, CI, Zero-Cost and production schema/readback while fresh browser/Auth/Meta canaries remain blocked. No Auth/2FA or provider bypass is allowed.
