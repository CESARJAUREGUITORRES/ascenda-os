# WA-4C — Conversational Sales & Patient Identity Hardening

**Date:** 2026-08-29 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Scope:** pre-production hardening inside `WA-4C — AI Sales Copilot Canary`  
**Baseline main:** `6a4a5ff1623412315dbc8aa4318bed4a2e6b5a88`  
**Status:** `APPROVED DESIGN / IMPLEMENTATION REQUIRED BEFORE WA-4C PRODUCTION CERTIFIED`

## Why this hardening exists

WA-4B already provides governed commercial stages, evidence-only business facts, price fail-closed behavior, clinical escalation, HUMAN_ONLY send authority and SAFE-OFF production controls. WA-4C BETA LOCAL already proves the current Copilot can generate INFO/PRICE/PAYMENT/OBJECTION/CONTINUITY/CLINICAL_ESCALATION suggestions and interactive drafts.

The remaining product gap is not basic intent classification. It is longitudinal sales behavior: how ASCENDA should greet, ask, remember, educate, present price, use media, identify an existing patient, recognize booking intent, close naturally, and stop selling when the correct next action is booking or human escalation.

This document freezes that behavior before LIVE certification.

## North-star behavior

ASCENDA must behave as an assisted commercial advisor, not as a generic question-answer bot.

`UNDERSTAND CONTEXT → ANSWER THE EXPLICIT NEED → ADD SMALL USEFUL VALUE → ASK ONE STRATEGIC NEXT QUESTION → UPDATE MEMORY → CHOOSE NEXT BEST ACTION → BOOK WHEN READY → HUMAN WHEN REQUIRED`

The objective is not to maximize message count. The objective is to minimize the number of high-quality outbound turns required to reach the correct business outcome while preserving trust, safety, privacy and current-source authority.

## D1 — Message Economy & WhatsApp-native copy

Default policy:

- `1 customer turn → 1 ASCENDA outbound message`.
- A second outbound message is an exception, not the default.
- Prefer one compact WhatsApp bubble with short internal paragraphs/line breaks rather than 3–4 separate bubbles.
- Prefer one interactive message containing its explanatory body + buttons/list when Meta supports that shape.
- Do not send `TEXT + TEXT + TEXT + BUTTONS` when one interactive message can carry the same decision.
- Keep responses concise enough to scan on mobile.
- Emojis are functional and low-density, never decorative spam.

Recommended emoji semantics:

- `👋` greeting
- `😊` warmth
- `✨` aesthetic/result framing
- `📍` location
- `📅` booking
- `🕐` schedule
- `💳` payment
- `📸` approved image/result media
- `🎥` approved video
- `✅` confirmation

`AUTO_SEND` remains false. Message economy does not change HUMAN_ONLY authority.

## D2 — Consultative Sales Dialogue Policy

ASCENDA must select a deterministic question mode before the LLM writes natural language.

Allowed modes:

- `OPEN_DISCOVERY` — understand goal/context.
- `GUIDED_CHOICE` — reduce ambiguity with 2–4 meaningful options.
- `ALTERNATIVE_CLOSE` — both options advance toward a chosen next step; use only with sufficient buying intent.
- `DIRECT_CONFIRMATION` — confirm an already selected action/slot/detail.
- `NONE` — answer without forcing another question when no question is needed.

Rules:

1. Do not interrogate. Prefer one useful question per outbound turn.
2. `VALUE_BEFORE_NEXT_QUESTION`: when possible acknowledge or add useful information before asking the next thing.
3. Do not ask for information already known from campaign provenance, conversation memory or trusted customer context.
4. Discovery questions can be open/semi-open. Closing questions can use guided alternatives.
5. Do not use an alternative close before the customer has enough context.
6. Do not end every message with `¿Deseas agendar?`.
7. Once booking intent is high, stop over-educating and reduce the path to a real slot.

Examples:

- Discovery: `¿Qué zona es la que más te gustaría mejorar?`
- Guided choice: `¿Te interesa principalmente frente y entrecejo o también patitas de gallo?`
- Alternative close: `¿Te acomoda mejor entre semana o fin de semana?`
- Booking progression: `¿Prefieres San Isidro o Pueblo Libre?`

## D3 — Entry Context

Before asking discovery questions, ASCENDA must consume available entry context:

- WhatsApp sender identity/reachability evidence;
- campaign/source/referral/ad context when present;
- previous conversation state;
- existing canonical patient resolution when allowed;
- declared treatment/service from the inbound message.

Example: if the customer entered from a toxin campaign and writes `precio`, ASCENDA must not ask `¿sobre qué tratamiento deseas información?`.

## D4 — Conversation Memory / Slots

Maintain a governed commercial state per conversation. At minimum:

- `treatment_or_interest`
- `goal`
- `areas_or_zones`
- `brand_if_explicit`
- `variant_if_explicit`
- `price_requested`
- `price_already_presented`
- `payment_question`
- `objection`
- `preferred_site`
- `schedule_preference`
- `media_requested_or_sent`
- `booking_intent`
- `customer_identity_state`
- `customer_type = EXISTING | NEW | UNKNOWN`
- `last_next_best_action`

Do not repeat a question when the value is already known with sufficient confidence.

Commercial memory is not clinical history. Do not store or expose unnecessary PHI in the sales state.

## D5 — Booking Readiness & Next Best Action

Booking readiness is deterministic and explainable:

- `LOW` — exploring; educate/discover.
- `MEDIUM` — meaningful commercial interest; use micro-commitment, price/media/info as appropriate.
- `HIGH` — concrete buying/booking signals; offer real booking progression.

Examples of HIGH signals:

- asks availability/horario;
- asks how to reserve/separate;
- asks whether Saturday/weekend is available;
- asks location after discussing treatment;
- accepts or acknowledges price positively;
- asks deposit/payment needed to reserve;
- says `quiero hacerlo`, `quiero ir`, `puedo ir mañana`, etc.

Possible `NEXT_BEST_ACTION` values:

- `ANSWER_INFO`
- `CLARIFY_GOAL`
- `CLARIFY_ZONE`
- `CLARIFY_VARIANT`
- `SHOW_PRICE`
- `SHOW_PAYMENT`
- `OFFER_APPROVED_MEDIA`
- `RESOLVE_OBJECTION`
- `OFFER_BOOKING`
- `SELECT_SITE`
- `SELECT_SCHEDULE_WINDOW`
- `SELECT_REAL_SLOT`
- `CONFIRM_BOOKING`
- `HUMAN_COMMERCIAL`
- `HUMAN_CLINICAL`

## D6 — Price behavior

The LLM never becomes price authority.

- Price comes from governed WA-4A.1C/current catalog context only.
- Missing/stale/conflicting price fails closed.
- Do not force brand discovery if the customer does not know brands and brand is not needed yet.
- Explain treatment/category in customer language; do not pedantically correct colloquial use of brand terms.
- Ask only the minimum discovery required to choose a valid current-price context.
- After presenting price, choose a next question based on booking readiness rather than using a fixed close.

## D7 — Existing patient vs new lead

### Principle

WhatsApp must reuse ASCENDA canonical patient identity and agenda authority. It must not create a parallel CRM or use name-only identity matching.

### Current ASCENDA authorities confirmed on 2026-08-29

`aos_pacientes` already contains, among others:

- `ID_PACIENTE`
- `Nombres`
- `Apellidos`
- `Teléfono`
- `Email`
- `N° documento`
- `numero_limpio`
- commercial/visit counters and canonical business fields.

`aos_agenda_citas` already contains:

- `nombre`, `apellido`, `numero`, `dni`, `correo`
- `tratamiento`, `tipo_cita`, `sede`
- `fecha_cita`, `hora_cita`, `estado_cita`
- professional/advisor/origin lineage fields.

Existing governed identity/Customer 360 functions include:

- `aos_patient_search_v2(p_token,p_query,p_limit)`
- `aos_patient_360_current_v3(p_token,p_canonical_patient_id)`
- `aos_patient_commercial_360_v2(...)`
- `aos_rev_resolve_patient_identity_v2(p_lookup_type,p_lookup_value)`
- `aos_rev_normalize_patient_identifier_v2(...)`
- `aos_rev_customer_agenda_identity_v1`.

The public booking RPC `aos_agendar_publica(...)` currently accepts name, surname and phone and has DNI/email as optional defaults. It still resolves by normalized phone internally and may create a prospect when no patient is found. That legacy behavior must not become the sole identity authority of WhatsApp; WA should resolve canonical identity first and use a governed booking adapter before WA-6 finalization.

### Identity states

Use explicit states such as:

- `CHANNEL_RESOLVED` — sender channel uniquely maps to a patient with acceptable confidence for low-risk personalization.
- `VERIFIED` — sufficient additional verification for sensitive customer-specific details.
- `UNRESOLVED` — no unique patient.
- `CONFLICT` — multiple/contradictory candidates; never auto-bind.
- `NEW_LEAD` — customer states first visit or no patient is resolved after reasonable lookup.

### Entry behavior

1. First attempt passive canonical resolution from the signed WhatsApp sender identifiers/phone and existing identity services.
2. If uniquely resolved, do not unnecessarily ask `¿eres cliente?`.
3. Low-risk personalization may use the customer's first name when policy permits.
4. Do not reveal sensitive appointment/clinical details merely because a phone number matched.
5. If unresolved, offer a compact guided choice when useful:
   - `Soy paciente`
   - `Es mi primera vez`
6. If `Soy paciente`, request the minimum verification field required by policy, e.g. document number when appropriate. Do not echo the full document back in chat/logs.
7. If document lookup is unresolved, continue service; do not trap the person in identity verification. Treat as unresolved/new as appropriate and ask only the data needed for the requested action.
8. If the person supplies a name only, do not bind automatically by name.
9. `CONFLICT` always goes to governed/manual resolution.

### Privacy boundary

Before sufficient verification, public/business-safe information remains available, but patient-specific sensitive details are restricted.

Examples:

- Public price/location/hours: allowed without patient identity.
- Use of existing profile internally to accelerate a low-risk booking: allowed only through governed identity/role checks.
- Reveal an upcoming appointment, clinical history, treatment history or sensitive notes: require stronger verification/authorized human path as defined by the eventual privacy matrix.
- Clinical details remain outside Sales Copilot authority.

## D8 — Booking data collection

Do not collect the entire patient record in WhatsApp before booking.

For new leads, collect only the data actually required by the booking contract. Current `aos_agendar_publica` demonstrates that DNI and email are optional at the legacy RPC boundary; therefore WhatsApp must not block a legitimate booking solely because the user does not have an email available unless a later governed booking policy explicitly requires it.

Preferred behavior:

- reuse WhatsApp phone instead of asking for phone again when trusted;
- request name/surname when needed for a new lead;
- request document/email progressively only if necessary or useful;
- if optional data is declined/unavailable, continue without repeated pressure;
- collect clinical/intake data after booking through the appropriate governed intake flow, not during sales discovery.

## D9 — Existing patient acceleration

For a verified/resolved existing patient, the booking journey should be shorter:

`IDENTITY → CURRENT REQUEST → SITE/SCHEDULE IF NEEDED → REAL AVAILABILITY → BOOK/RESCHEDULE → CONFIRMATION`

Do not ask again for fields ASCENDA already knows unless confirmation is necessary for correctness.

If an existing patient asks a public question such as price, answer it using governed current-price authority exactly as for any other customer, while leveraging context only when it improves relevance and remains within privacy boundaries.

## D10 — Upcoming appointment behavior

ASCENDA may eventually surface an upcoming appointment only when identity/privacy policy allows it. This is a customer-specific health-service fact and must not be exposed to an unverified sender.

Allowed future pattern after sufficient verification:

`Hola, Jacqueline 😊 Ya pude ubicar tu ficha. Veo que tienes una próxima cita registrada. ¿Quieres consultar esa cita o deseas agendar algo adicional?`

The actual appointment date/time should only be returned through the governed appointment read model and the corresponding verification level.

## D11 — Commercial Media Library

Create governed media references rather than allowing the model to invent or search arbitrary assets.

Possible media types:

- approved before/after image;
- approved educational/result video;
- procedure explainer;
- location/map asset;
- payment/reservation instruction asset.

Each asset should have at least:

- canonical id;
- treatment/category tags;
- audience/purpose;
- approval/consent state;
- active/inactive state;
- source/provenance;
- optional expiration/review date.

The Copilot suggests media; HUMAN_ONLY remains the send authority during WA-4C.

## D12 — Multimodal inbound

### Audio

`WhatsApp audio → secure media fetch → transcription → normalized conversation content → state extraction → playbook → suggestion`.

The system must respond to all material intents in the audio, not only the last sentence.

### Image

Use image understanding descriptively to understand what the customer is referring to. Do not diagnose, prescribe, determine candidacy, infer disease or choose a treatment plan from the image.

If the image creates a personalized clinical decision, route `HUMAN_CLINICAL`.

## D13 — Booking engine handoff

When booking readiness becomes HIGH, reduce conversation length.

Target progression:

`OFFER_BOOKING → SITE/WINDOW → REAL AVAILABILITY → SLOT → DEPOSIT/POLICY IF APPLICABLE → CONFIRM → REMINDER/RESCHEDULE/CANCEL`

Do not invent availability. Real slots belong to governed agenda/WA-6 authority.

Do not continue selling after the customer has selected a valid booking path unless a blocking question must be answered.

## D14 — Cost-aware operation

Track both platform and AI economics where evidence is available:

- inbound/outbound message counts;
- Meta pricing category/model/billable status already captured by WA gateway status events;
- model tokens/cost;
- outbound messages per conversation;
- outbound messages per confirmed booking;
- cost per booking;
- conversion to appointment/attendance/sale/revenue.

Message-count optimization must never remove a necessary safety, consent, verification or clinical-escalation step.

## D15 — Conversation evaluation suite

WA-4C cannot be production certified using only isolated single-message tests. Add full multi-turn scenarios.

Minimum families:

### Campaign / toxin

- `precio`
- `precio de botox`
- `quiero frente`
- `frente y patitas`
- explicit brand + 1/3 zones
- `qué marca usan`
- `qué diferencia hay`
- `está caro`
- `tienen promoción`
- `tienen resultados`
- `mándame fotos`
- `dónde quedan`
- `atienden sábado`
- `quiero agendar`

### Existing patient

- phone uniquely resolves; public question
- resolved patient wants booking
- patient selects `Soy paciente`
- document resolves uniquely
- name-only claim must not auto-bind
- identity conflict must fail closed
- unresolved document continues as lead/new flow
- optional email missing must not create a conversational dead-end
- upcoming appointment request before verification must not leak details
- upcoming appointment request after sufficient verification uses governed data

### New patient

- `Es mi primera vez`
- collect minimum booking data
- do not repeatedly request optional email/document
- create/hand off booking only through governed adapter

### Multimodal

- audio with multiple intents
- image + commercial question
- image requiring clinical escalation

### Safety

- pregnancy/contraindication question
- adverse reaction
- request for diagnosis from photo
- attempt to expose another person's appointment/data

## D16 — Runtime contract evolution

Current WA-4C V1 suggestion shape is centered on one free-form `reply`. V2 should remain one-outbound-first while adding structured decision metadata.

Conceptual output:

```json
{
  "version": "WA4C-TURN-V2",
  "message": {
    "text": "...",
    "preferred_outbound_count": 1,
    "emoji_density": "LOW"
  },
  "intent": "PRICE",
  "question_mode": "GUIDED_CHOICE",
  "booking_readiness": "MEDIUM",
  "next_best_action": "CLARIFY_ZONE",
  "state_updates": {},
  "identity": {
    "customer_type": "UNKNOWN",
    "state": "UNRESOLVED"
  },
  "interactive": null,
  "media_suggestion": null,
  "needs_human": false,
  "send_authority": "HUMAN_ONLY",
  "auto_send": false
}
```

The LLM writes language. Deterministic/governed policy owns send authority, privacy boundaries, price authority, question mode eligibility, identity conflict handling and clinical escalation.

## D17 — Implementation gates before WA-4C LIVE certification

1. Exact current-main anti-drift.
2. Implement machine-readable Turn V2 policy/contract.
3. Implement state/slot memory with bounded commercial fields.
4. Implement question-mode/booking-readiness/next-best-action policy.
5. Implement canonical existing/new patient identity adapter and privacy matrix.
6. Implement UI rendering/approval for one-outbound-first suggestions and interactive body+actions.
7. Add governed media hooks; media library can remain feature-gated until its source is populated.
8. Add audio/image ingestion boundaries or explicit fail-closed feature gates if not yet promoted.
9. Add multi-turn conversation tests including identity/privacy negatives.
10. Exact-head CI/regressions/security/performance.
11. Merge with expected-head discipline.
12. Railway exact SHA SUCCESS.
13. Supabase Auth/REST 2xx.
14. Legitimate 2FA.
15. LIVE canaries on the V2 contract.
16. Verify audit/cost/no autonomous send.
17. Only then `WA-4C = PRODUCTION CERTIFIED`.
18. Only then move the active lock to WA-5.

## Frozen safety invariants

- `copilot_enabled` can be enabled only for the controlled advisor canary boundary.
- `ai_send_enabled=false`.
- `auto_reply_enabled=false`.
- `auto_routing_enabled=false`.
- `human_send_enabled=true`.
- no name-only identity binding;
- no clinical diagnosis/prescription/candidacy decision;
- no unsupported price/promotion/discount;
- no patient-specific sensitive disclosure without sufficient identity/authorization;
- no parallel patient/agenda master;
- no autonomous booking against invented availability.

## Research principles incorporated

The design incorporates the recurring principles identified in current sales/booking research reviewed during WA-4C design: consultative discovery, questions that follow customer context, guided/alternative closes only at the appropriate buying stage, explicit next steps, minimal-friction booking, real availability, reminders/rebooking, lead-to-booking conversion tracking, and avoiding unnecessary interrogation. These principles were compared against current practices described by HubSpot, Gong, JustBook, SimplyBook, Fresha, Zenoti and PatientNow; ASCENDA adopts the principles but keeps its own governed architecture and clinical/privacy boundaries.

## Certification boundary

This document changes the WA-4C exit gate.

`Supabase 402 → 2xx` is no longer sufficient by itself to continue directly to final certification. If recovery occurs before this hardening is merged/certified, the LIVE loop must stop at:

`SUPABASE RECOVERED → CONVERSATIONAL HARDENING PENDING`

Only the certified V2 conversational boundary may proceed to final LIVE canaries and `WA-4C PRODUCTION CERTIFIED`.
