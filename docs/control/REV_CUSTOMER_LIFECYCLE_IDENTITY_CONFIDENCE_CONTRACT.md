# REV — CUSTOMER LIFECYCLE & IDENTITY CONFIDENCE CONTRACT

**Owner:** REV-F6 analytics/read models  
**Dependency:** REV-F5 certified canonical identity + declared transaction/activity coverage  
**Purpose:** deterministic lifecycle classification and visible metric trust.

## 1. Customer Lifecycle Contract

Lifecycle is derived from canonical patient identity plus observed events. It is not a manual marketing label and it must expose the evidence window used.

### Required states

#### `UNRESOLVED_IDENTITY`
Use when the event/contact cannot be confidently resolved to one canonical patient. No patient-level lifetime/repeat claim is allowed.

#### `NEW_PATIENT`
Canonical patient whose first qualifying observed patient event is recent and who has no qualifying prior event inside the certified historical coverage.

Qualifying event priority: completed/attended clinical appointment and/or canonical sale, according to the metric being computed. The model must state which event definition it used.

#### `HISTORICAL_REACTIVATED`
Canonical patient with a prior qualifying patient event, an inactivity gap of at least 180 days, and a new qualifying event inside the current reactivation window. Default reactivation window: first 30 days after return.

#### `ACTIVE_REPEAT`
Canonical patient with at least two qualifying observed events/purchases and recent activity (default <=90 days), excluding the short `HISTORICAL_REACTIVATED` window.

#### `RETURNING_PATIENT`
Canonical patient with prior history who returned/repeated but does not currently meet the stricter `ACTIVE_REPEAT` or `HISTORICAL_REACTIVATED` definition.

#### `DORMANT`
Canonical patient with prior qualifying history, no qualifying activity for >180 days and no known future confirmed appointment. The inactivity threshold is configurable but must be visible with the metric.

## 2. State precedence

To keep states mutually exclusive for a current-state field:

1. `UNRESOLVED_IDENTITY`
2. `HISTORICAL_REACTIVATED`
3. `NEW_PATIENT`
4. `ACTIVE_REPEAT`
5. `RETURNING_PATIENT`
6. `DORMANT`

If evidence cannot distinguish states because history is incomplete, return the most conservative state plus reduced coverage/confidence; never invent a prior/no-prior claim.

## 3. Event-specific flags

Lifecycle current state may coexist with analytical flags such as:

- `is_first_observed_sale`;
- `is_repeat_sale`;
- `reactivation_gap_days`;
- `has_future_appointment`;
- `observed_purchase_count`;
- `observed_active_months`.

These flags preserve nuance without multiplying lifecycle states.

## 4. Identity Confidence Contract

Every identity resolution should expose:

- `identity_status`: `RESOLVED`, `REVIEW_REQUIRED`, `CONFLICT`, `UNRESOLVED`;
- `confidence_band`: `VERIFIED`, `HIGH`, `MEDIUM`, `LOW`, `UNRESOLVED`;
- `confidence_score`: optional 0–100 explainable score;
- `match_method`;
- `strong_signal_count`;
- `conflict_count`;
- `reviewed`: boolean;
- provenance reference(s).

### Recommended bands

- `VERIFIED`: explicitly reviewed/approved or certified exact multi-strong-signal identity with zero conflicts;
- `HIGH`: strong multi-signal evidence, no contradiction, not yet manually verified where policy permits automatic resolution;
- `MEDIUM`: useful candidate evidence but requires review for merge-sensitive decisions;
- `LOW`: weak/fallback evidence only; never authorizes physical merge;
- `UNRESOLVED`: no safe canonical assignment.

A numeric score never overrides a hard conflict.

## 5. Metric Trust Contract

Every inferred/aggregate F6 insight must carry:

### `coverage`
What fraction of the relevant universe is represented. Include numerator/denominator where possible and the covered date range.

Examples:

- identity coverage = resolved canonical subjects / eligible subjects;
- historical sales coverage = certified transaction rows / expected transaction rows when denominator exists;
- demographic coverage = patients with field / canonical patients in metric cohort.

### `confidence`
Trust band for the derivation, separate from business performance. It may combine identity confidence, source quality and reconciliation quality.

### `freshness`
`as_of` timestamp/date and source age. A dashboard must not silently show stale read models as current.

### `sample_size`
Actual denominator behind patterns such as cross-sell, cohort retention, advisor comparison or demographic segmentation.

## 6. Coverage-period rule

A metric must distinguish:

- `observed_lifetime_value` from true lifetime value;
- `observed_first_sale` from absolute first sale when earlier transaction coverage is absent;
- `2026-only` facts from multi-year facts;
- patient-history coverage from transaction-ledger coverage.

Until 2024/2025 sales ledgers are certified, no F6 metric may claim complete 2024/2025 revenue or YoY.

## 7. Patient 360 presentation

Direct canonical facts may display normally. Derived intelligence should expose compact trust metadata, for example:

`LTV observado S/ X · cobertura 2026 · HIGH · n=4 compras · actualizado hoy`

Do not overwhelm normal users with raw technical metadata; allow expanded details for admin/audit.

## 8. CIA / WA handoff

Lifecycle and confidence are read-only commercial signals. They do not themselves authorize campaign delivery or autonomous outreach.

CIA/WA may consume:

- lifecycle state;
- commercial recency/frequency;
- identity status/confidence;
- recommended analytical segment/signals;

subject to their own policy/consent/channel governance.

## 9. Certification tests

- mutually exclusive current lifecycle state;
- deterministic results for same as-of date/input facts;
- unresolved identity never appears as known patient;
- hard identity conflicts never become high confidence by score accumulation;
- 180/90/30-day defaults are explicit/configurable;
- historical coverage gaps reduce claim strength;
- every aggregate insight carries coverage, confidence, freshness and sample_size;
- no unsupported YoY/lifetime wording.
