# ASCENDA OS — COMMERCIAL INTELLIGENCE FACT REGISTRY V1.2
## Phase 3 — Segmentation Facts

**Estado:** PROPOSED / VALIDATING  
**Fecha:** 2026-08-13  
**Dependencia:** Fact Registry V1.1 + Commercial Facts V1.

---

# 1. SEGMENTATION FACTS

| key | type | semantics | null |
|---|---|---|---|
| `segment.policy_key` | text | policy family used to classify | never null while policy resolves |
| `segment.policy_version` | integer | exact version used | never null |
| `segment.policy_status` | enum | SHADOW/ACTIVE | never null |
| `segment.value_tier` | enum | STANDARD/PREMIUM/GOLD/DIAMANTE | never null |
| `segment.value_score` | integer | 0–9 RFM-like commercial value score | never null |
| `segment.value_revenue_points` | integer | revenue component 0–4 | never null |
| `segment.value_frequency_points` | integer | purchase frequency component 0–3 | never null |
| `segment.value_recency_points` | integer | purchase recency component 0–2 | never null |
| `segment.lifecycle` | enum | current commercial lifecycle state | never null |
| `segment.customer_last_activity_at` | date | max(last sale,last attended) for buyers | null for non-buyers |
| `segment.engagement` | enum | HIGH/MEDIUM/LOW recent interaction intensity | never null |
| `segment.engagement_score` | integer | deterministic engagement points | never null |
| `segment.traits` | set | non-exclusive commercial traits | empty set allowed |
| `segment.calculated_at` | timestamp | evaluation timestamp | never null |
| `segment.explanation` | jsonb | why the classifications were produced | never null |

---

# 2. VALUE TIER V1

Value score is additive:

`revenue_points + frequency_points + recency_points`

Revenue bands: 500 / 1,800 / 5,000 / 8,000.  
Frequency bands: 2 / 5 / 9 purchases.  
Recency: <=30 / <=90 days.

Tier rules:

- DIAMANTE: score >=8, revenue >=5,000, purchases >=5;
- GOLD: score >=6;
- PREMIUM: score >=3;
- STANDARD: otherwise.

No purchase => STANDARD, never NULL.

---

# 3. LIFECYCLE V1

Allowed values:

- NEW_CUSTOMER;
- ACTIVE_CUSTOMER;
- COOLING_CUSTOMER;
- INACTIVE_CUSTOMER;
- APPOINTMENT_READY_PROSPECT;
- DISQUALIFIED_PROSPECT;
- ACTIVE_PROSPECT;
- WARM_PROSPECT;
- COLD_PROSPECT;
- PROFILE_ONLY.

`REACTIVATED` is intentionally absent until Commercial Facts exposes sufficient historical gap evidence.

---

# 4. ENGAGEMENT V1

Allowed values: HIGH / MEDIUM / LOW.

The score may use only deterministic positive interaction evidence documented in the active policy. Value/revenue is not an engagement input.

---

# 5. TRAITS V1

Allowed initial traits:

- HAS_LEAD
- UNWORKED_LEAD
- NEVER_CALLED
- PRODUCT_BUYER
- SERVICE_BUYER
- PRODUCT_AND_SERVICE_BUYER
- REPEAT_BUYER
- FREQUENT_BUYER
- HIGH_VALUE_BUYER
- RECENT_BUYER
- LAPSED_BUYER
- FUTURE_APPOINTMENT
- NO_SHOW_HISTORY
- REPEAT_NO_SHOW
- FOLLOWUP_PENDING
- FOLLOWUP_OVERDUE

Traits are independent flags and may coexist.

---

# 6. AUDIENCE DSL OPERATORS

Segmentation facts become valid inputs for Phase 4 Audience Resolver.

Enums/text:
- eq
- neq
- in
- not_in
- exists

Scores:
- eq
- gt/gte
- lt/lte
- between

Traits:
- contains
- contains_any
- contains_all
- not_contains

The frontend/AI must never translate these into arbitrary SQL. Phase 4 maps keys to whitelisted predicates.

---

# 7. EXPLAINABILITY CONTRACT

Every segment row exposes explanation JSON with at least:

- observed revenue/frequency/recency and component points;
- lifecycle evidence dates/statuses;
- engagement score/evidence;
- traits array;
- policy id/key/version/status.

The explanation is diagnostic/audit metadata and is not a free-form AI explanation.
