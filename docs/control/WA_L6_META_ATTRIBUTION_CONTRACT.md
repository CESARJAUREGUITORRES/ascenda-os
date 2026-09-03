# ASCENDA OS — WA-L6 Meta Campaign Context & Attribution Contract

Status: IMPLEMENTATION / SAFE-OFF  
Authority: GitHub issue #447  
Entry main: `e790153523c4cc0d842b57cd57544dadc1a0c85a`

## Objective

Build an evidence-driven chain:

`Meta/CTWA referral evidence → WhatsApp conversation → governed campaign context → AGV2 BOOK/REBOOK → same appointment → attendance → explicit sale link → revenue`.

WA-L6 is attribution infrastructure. It does not activate autonomous WhatsApp and it does not manufacture campaign, customer, lead, booking or sales data.

## Provider evidence boundary

The signed WhatsApp webhook remains the first-mile authority. Standard Click-to-WhatsApp referral evidence is preserved exactly as supplied by Meta. Optional provider-extension `ad_id`, `campaign_id` and `adset_id` are accepted only when they are explicit fields in the provider referral object.

Rules:

- `source_id + source_type=ad` may establish `ad_id`, matching the existing WA-7A.3 contract;
- an explicit provider `ad_id` overrides that fallback because it is stronger direct evidence;
- `campaign_id` and `adset_id` are never parsed from a headline, URL, campaign name, phone, username, BSUID or free text;
- no referral object means no attribution touchpoint;
- acquisition evidence remains separate from patient identity.

## Acquisition classes

`aos_wa_attribution_touchpoints_v1` now appends:

- `provider_campaign_id`;
- `provider_adset_id`;
- `acquisition_class`.

Classification is deterministic:

- `META_CTWA_PAID`: explicit `ctwa_clid` or provider `source_type=ad`;
- `META_POST_REFERRAL`: provider `source_type=post`;
- `PROVIDER_REFERRAL_OTHER`: another explicit referral type;
- conversations without any provider touchpoint appear in the L6 conversation view as `NO_PROVIDER_ATTRIBUTION`.

`NO_PROVIDER_ATTRIBUTION` is intentionally not renamed to “organic”. Absence of a provider referral cannot prove whether traffic came from QR, direct contact, web, saved number or another untracked source.

## Governed campaign context

The pre-existing `aos_wa4_campaign_context_map_v1` remains the only treatment/promotion/booking-goal map and remains fail-closed when empty.

L6 adds `aos_wa_l6_campaign_context_upsert_v1(token,payload)`:

- 2FA + `admin-marketing` or `admin-whatsapp` required;
- explicit `ad_id` required;
- exact active SERVICE `treatment_entity_id` UUID required;
- non-empty `evidence_ref` required;
- optional explicit `campaign_id`, `promotion_id`, safe-token `booking_goal`, `media_strategy`, `active`;
- no treatment-by-name inference;
- browser/runtime direct table writes remain denied;
- every CREATE/UPDATE is written to append-only `aos_wa_l6_campaign_context_audit_v1` with before/after snapshots.

## Campaign resolution

`aos_wa_l6_conversation_acquisition_v1` keeps provider evidence and governed mapping distinguishable.

- provider campaign ID + same governed campaign ID → provider evidence wins as the direct source;
- provider campaign ID only → `PROVIDER_EVIDENCE`;
- governed mapping only → `GOVERNED_AD_MAPPING`;
- neither → `UNRESOLVED`;
- provider and governed IDs disagree → `CONFLICT_FAIL_CLOSED`, effective campaign ID becomes NULL.

No campaign name heuristics are allowed.

## Booking, attendance and revenue stitch

`aos_wa_l6_attribution_journey_v1` is service-role-only and read-only. Its join keys are explicitly limited to:

1. touchpoint provider message → `aos_wa_messages_v1.conversation_id`;
2. conversation → `aos_booking_operations_v2.conversation_id`;
3. booking operation → exact `appointment_id`;
4. appointment → `aos_agenda_citas.id`;
5. appointment → exact `venta_id_match`;
6. sale → exact `aos_ventas.venta_id`.

Forbidden joins/fallbacks:

- phone;
- patient/customer name;
- username;
- BSUID;
- canonical patient ID by itself;
- closest timestamp;
- treatment text similarity.

Attendance is derived only from the appointment status. `ASISTIO` and `EFECTIVA` are attended; `NO ASISTIO` and `CANCELADA` are non-attended; other states remain unresolved/pending rather than guessed.

## Multi-touch behavior

Multiple provider touchpoints for one conversation are legitimate evidence. L6 does not silently select first-touch or last-touch. The journey exposes every touchpoint and returns `MULTIPLE_TOUCHPOINTS_REVIEW` until an explicit future attribution policy is authorized.

## Attribution chain statuses

- `NO_PROVIDER_ATTRIBUTION`
- `TOUCHPOINT_ONLY`
- `MULTIPLE_TOUCHPOINTS_REVIEW`
- `CAMPAIGN_ID_CONFLICT`
- `BOOKING_AD_MISMATCH`
- `APPOINTMENT_MISSING`
- `APPOINTMENT_NO_EXPLICIT_SALE_LINK`
- `SALE_LINK_UNRESOLVED`
- `EXPLICIT_CHAIN_COMPLETE`

Only `EXPLICIT_CHAIN_COMPLETE` demonstrates a single unambiguous provider touchpoint connected through strong IDs to an explicitly linked sale.

## Production safety

Certification MUST NOT:

- create a synthetic production CTWA touchpoint;
- populate campaign mappings with invented Meta IDs;
- create leads or patients;
- create/rebook a real appointment;
- edit attendance;
- create/edit a sale;
- populate `venta_id_match` merely to make the chain green;
- enable AUTO_OFF→CANARY or autonomous provider sends.

A fresh real Meta CTWA click remains `LIVE_PENDING` until real provider evidence naturally arrives. Code/DB production certification can close while that external business canary remains pending, provided the absence is stated explicitly.

## Recovery

Pre-history recovery may remove only L6-owned views/function/audit table and restore the WA-7A.3 touchpoint view. The pre-existing campaign map is never dropped. Once L6 campaign audit history exists, recovery fails closed with `WA_L6_RECOVERY_BLOCKED_HISTORY`.
