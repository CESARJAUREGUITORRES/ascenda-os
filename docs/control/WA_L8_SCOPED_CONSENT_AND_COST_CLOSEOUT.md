# WA-L8 — Scoped Consent & WhatsApp Cost Closeout

Status: implementation contract; certification requires exact-head CI + PROD readback.
Safety invariant: `AUTO_OFF`, kill switch engaged, auto-reply/send/routing disabled, human-send enabled. This document does not authorize CANARY.

## 1. One consent authority

WA-7A.4 `aos_wa_marketing_eligibility_events_v1` is the sole append-only consent/suppression authority. The early L8-local consent table is inert compatibility structure only and must remain empty/non-writable.

Scopes are independent:

- `UTILITY`: confirmations, reprogramming and appointment reminders.
- `MARKETING`: offers, commercial follow-up and reactivation.
- `AUTHENTICATION`: future authentication templates.
- `GLOBAL`: explicit cross-category grant/denial only when evidence supports it.

Utility consent never grants Marketing consent.

## 2. No bad consent UX

L8 does **not** require a first chatbot message asking the customer to type “I authorize messages”.

Inside the 24-hour customer-service window, the customer may converse normally. Outside 24 hours, free-form is blocked and an approved template is required.

For appointment flows, the existing explicit booking confirmation can also serve as the Utility opt-in action only when the confirmation prompt already displayed a clear, versioned disclosure such as:

> Al confirmar tu cita, Zivital te enviará por este WhatsApp confirmaciones, cambios y recordatorios relacionados con tu cita. Puedes pedir que dejemos de enviarlos en cualquier momento.

The disclosure version is `WA_L8_BOOKING_UTILITY_V1`. The same customer affirmative used by L5 to confirm the booking is therefore sufficient operational evidence; there is no second consent question.

`aos_wa_l8_record_booking_utility_optin_v1(...)` refuses to record consent unless all of these are true:

1. an inbound customer message exists in the same conversation;
2. L5 recorded that exact provider message as `CONFIRMED`;
3. the WhatsApp BOOK/REBOOK was actually `COMMITTED`;
4. a versioned Utility disclosure was declared;
5. an evidence reference is present.

Merely having an appointment never creates consent.

## 3. STOP / opt-out

A customer STOP/BAJA/no-more-messages signal is persistent. A later ordinary inbound message does not erase it.

The STOP lookup uses a partial conversation index and `LIMIT 1`; no global scan or synchronous analytical view is introduced. This preserves P0 #432.

Only explicit reconsent after the STOP can reopen a scope. Scope isolation remains strict: a later Marketing reconsent does not reopen Utility, and vice versa. A GLOBAL reconsent is only valid when evidence explicitly supports that breadth.

## 4. Template scope

A provider-verified appointment template in `aos_agenda_delivery_template_registry_v3` is classified as `UTILITY`. Unknown future templates fail conservatively to `MARKETING` for the L8 eligibility check; L4 still independently requires provider verification before any autonomous template send.

Final path:

`L8 scope/STOP/24h eligibility -> L4 AUTO_OFF/CANARY/PROD + kill switch + safety + identity + provider template verification + allowlist/limits -> provider send`

L8 PASS is never sufficient by itself to send.

## 5. WhatsApp API cost intelligence

Cost accounting is preserved as a first-class L8 closeout gate:

- Meta status `pricing.type` is retained as sanitized provider evidence.
- recipient market is resolved conservatively (`PE` only when deterministic; otherwise unresolved).
- provider `billable=false` is `KNOWN 0`.
- a billable message is `KNOWN` only with an evidence-backed VERIFIED effective rate for the exact market/category/model/currency.
- no USD/PEN FX or WABA billing currency is fabricated.
- `aos_wa_l8_meta_monthly_usage_v1` reconciles monthly outbound count, billable/non-billable count, completeness and known cost by business phone number, market, category, pricing model and pricing type.

The announced October 2026 service-message/free-tier rules must not be inserted as VERIFIED PROD authority until the clinic WABA billing/rate-card evidence is captured. Message counts remain observable even when monetary cost is UNKNOWN.

## 6. Security / privacy

- no browser direct writes to consent, preflight, message or booking authority;
- no new hot-path trigger;
- preflight is append-only/idempotent;
- AI audit stays metadata-only;
- destructive `service_role` privileges remain removed where runtime does not require them;
- no new raw phone/BSUID copy is created by the scoped consent authority;
- recovery fails closed once L8 preflight or L8-scoped consent history exists.

## 7. Exit gate

WA-L8 may close only after:

1. exact-head static + real local DB CI passes;
2. WA-7A.4 regression passes;
3. Utility vs Marketing scope isolation passes;
4. persistent STOP after later inbound passes;
5. WhatsApp cost event + monthly aggregation passes;
6. cross-module read-only regression passes;
7. anti-drift confirms frozen `main`;
8. PR merges with `expected_head_sha`;
9. Railway reports SUCCESS;
10. WA-7A.4 prerequisite + exact L8 migrations are applied to Supabase PROD;
11. LIVE SAFE-OFF, privileges, zero autonomous outbound and cost/eligibility readbacks pass;
12. issue/Notion closeout releases the sole HIGH/CRITICAL lock.

Only after that is WA-L9 eligible to start. L8 closure does not authorize CANARY.
