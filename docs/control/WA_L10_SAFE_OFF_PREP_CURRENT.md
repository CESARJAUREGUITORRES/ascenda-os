# WA-L10 — SAFE-OFF Preparation CURRENT

**Issue:** #456  
**Parent:** #410  
**Exact entry main:** `c3f2e9f8b28e05fae531451c9b9467ea292c91cf`  
**Fresh lock commit:** `e27bfd5ce2368185f537423e3aebc22b836ead10`  
**Branch:** `wa-l10-safe-off-revalidation-20260903`  
**Activation boundary:** `AUTO_OFF → CANARY` **NOT AUTHORIZED**

## A0 — exact-main / PRE / safety

Fresh atomic PROD checkpoint captured at `2026-09-04T01:40:06.936610Z` after the #462 governance merge:

| Surface | PRE |
|---|---:|
| Agenda | 3210 |
| Llamadas | 37236 |
| Leads | 6694 |
| Ventas | 1393 |
| Pacientes | 7761 |
| WA events | 39 |
| WA messages | 21 |
| WA outbound requests | 15 |
| WA auto decisions | 0 |
| WA L5 booking events | 0 |
| WA L6 journeys | 2 |
| WA L7 Meta cost events | 7 |
| WA L7 AI cost events | 0 |
| WA L9 demo runs | 0 |
| WA L9 provider dispatch | 0 |
| WA AUTO outbound | 0 |
| active L4 allowlist | 0 |

Bounded L8/L9 PROD readbacks at the same checkpoint:

- `mode=AUTO_OFF`;
- kill switch engaged;
- auto reply/send/routing = false;
- human send = true;
- autonomous outbound = 0;
- L9 provider dispatch runs = 0;
- browser message/booking writes = false.

Normal clinic activity may increase business-ledger counts while L10-A is certified. Therefore this checkpoint is a business PRE reference, not a requirement that live totals remain frozen. Deployment impact will use a separate immediate pre-apply/post-apply parity window.

## A1 — provider / policy / billing / template / consent readiness

### Policy — `VERIFIED_CURRENT`

Official WhatsApp sources were re-read on 2026-09-03 Lima. WhatsApp/Meta state that WhatsApp Business terms are being separated/updated with changes effective **2026-09-23**. The current Business Terms make the company responsible for determining legal/regulatory compliance and for obtaining required notices, rights, consents and permissions. They explicitly caution that the service is not represented as satisfying organizations subject to heightened confidentiality requirements such as healthcare.

Evidence:
- `https://www.whatsapp.com/legal/meta-terms-whatsapp-business`
- `https://www.whatsapp.com/legal/business-terms?lang=es`
- `https://faq.whatsapp.com/1017485114093363`

### Provider runtime — `STALE_EVIDENCE`

Historical PROD evidence proves Meta/WhatsApp transport has worked: current local message ledger contains inbound provider events and HUMAN outbound delivered/sent statuses, with latest demonstrated provider activity in the historical window around 2026-08-22. This does **not** prove current credential/payment/template readiness for a new autonomous canary. Runtime secrets remain outside GitHub/Notion and are not copied into L10 evidence.

### Template — `UNKNOWN`

The existing governed L4 path already fails closed unless an exact template is provider-verified. A current approved provider template for the proposed real canary has not yet been independently demonstrated from the provider authority. L10 does not create a second template registry.

### Billing / pricing — `UNKNOWN`

No current `META` row is promoted in `aos_wa_l7_pricing_authority_v1`. Historical L8 provider pricing evidence exists, but it is not a substitute for current official WABA/Billing Hub evidence. Meta's official terms bind fees/payment to the applicable official cost card and allow pricing changes over time. No third-party corroborated Peru rate will be promoted as `VERIFIED` by L10-A.

### Consent / recipient eligibility — `BLOCKED`

Current scoped eligibility is fail-closed: AUTHENTICATION, CALL, MARKETING and UTILITY scopes are `consent_status=UNKNOWN`, `suppression_status=UNKNOWN`, `eligibility_status=UNKNOWN`, `send_allowed=false`; the dedicated L8 consent-event ledger currently has no consent evidence rows. Therefore no real autonomous recipient is eligible today.

## A2 — necessity / discovery result

L4-L9 already contain the canonical mechanisms needed for a real governed canary:

- L4: sole autonomous mode/kill/allowlist/budget/rate/max-turn/cooldown/duplicate/idempotency/audit authority;
- L5: governed BOOK/REBOOK authority;
- L6: strong-key attribution;
- L7: Meta/AI cost and pricing authority;
- L8: consent/STOP/preflight/security/policy gates;
- L9: exact-authority rollback-only shadow evidence with no provider dispatch/raw content;
- `aos_wa_messages_v1`: provider message identity plus sent/delivered/read/failed status lineage;
- `aos_wa_auto_decisions_v1`: decision/idempotency/conversation/hash/reason/limit evidence.

**Proven missing gap:** no immutable run/session object existed to bind one future L10 canary's PRE/readiness evidence, candidate cohort and bounded run-scoped outcomes together.

No second sender, activation authority, pricing system, identity system, booking authority, delivery ledger, polling loop or analytical hot path is justified.

## A3 — minimum dormant implementation

Candidate adds only:

1. `aos_wa_l10_canary_runs_v1` — immutable preparation/readiness + PRE evidence;
2. `aos_wa_l10_canary_scope_v1` — immutable candidate `conversation_id + recipient_hash` scope; no raw phone/content;
3. `aos_wa_l10_prepare_run_v1(...)` — level-1, SAFE-OFF-only, active-allowlist-empty preparation;
4. `aos_wa_l10_attach_scope_v1(...)` — level-1, hash-only candidate scope; does not touch L4 allowlist;
5. `aos_wa_l10_status_v1(run_key)` — service-role-only `RUN_SCOPED_BOUNDED_V1` readback over existing L4 authority + scoped L4/message evidence.

Binding properties:
- append-only evidence;
- RLS + FORCE RLS;
- no browser access;
- no provider dispatch code;
- no L4 control/allowlist mutation;
- no protected business-ledger mutation;
- no materialized view/cache/retry/polling/timeout inflation;
- rollback succeeds before audit history but fails closed once immutable evidence exists;
- every preparation/scope response returns `activation_authorized=false`.

## A4 — certification gate

Pending exact-head PR certification. Required before merge:

- Ascenda CI;
- dedicated L10 SAFE-OFF static + DB contract;
- L4 authority regressions;
- current L5-L9 authority/booking/consent/cost regression;
- WA4 conversation + secure-gateway regressions;
- cross-module workflows triggered by the canonical lock change;
- exact-head anti-drift.

After protected merge: Railway exact-SHA SUCCESS → merged-lineage Supabase migration → immediate PRE/POST deployment parity → live empty L10 ledgers + service-role-only privilege readback → L8/L9 SAFE-OFF readback → logs/performance check.

Then **STOP**. Present owner go/no-go evidence. Do not create active allowlist or call L4 `AUTO_OFF → CANARY` without a separate explicit authorization.
