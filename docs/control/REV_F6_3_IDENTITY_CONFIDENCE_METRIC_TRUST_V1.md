# REV-F6.3 — Identity Confidence + Metric Trust V1

## Entry boundary

- CURRENT entry: `main@a0929aa029ed9c804ddd76d3c1b27dd644a3837b`.
- Mutable lock: `REV-F6-CLOSEOUT`.
- F6.0 fp: `02ba53adb9dabfcd0a4557061be53c2f`.
- F6.1 fp: `cd313998c5b5b38d5cb9e2f08882b826`.
- F6.2 fp: `d977b9669b9e741e8785cd863caaf9c2`.
- F6.3 is read/intelligence only: no patient merge, no sales/F3/F4 write and no inferred historical revenue.

## Identity Confidence

`canonical_patient_id` remains the authority. F6.3 does not create another patient truth layer.

Deterministic bands:

- `HIGH`: governed F5 reviewed MATCH plus non-conflicting alias evidence.
- `MEDIUM`: active canonical patient with non-conflicting/current evidence but without reviewed historical MATCH evidence.
- `LOW`: canonical subject exists but one or more strong aliases are conflict keys. Automatic cross-source attribution is forbidden.
- `UNRESOLVED`: canonical target is missing/fused; no automatic attribution.

Only `HIGH` is eligible for the explicit flag `safe_for_automatic_cross_source_attribution=true`. This flag is conservative and does not change the canonical subject.

Frozen guards: name alone is not identity; phone alone is not absolute authority; phone-nearness is never authority; conflict never auto-resolves; `FUSIONADO` is not an active subject.

## Metric Trust

Every relevant metric envelope carries at least:

- `value`
- `coverage {numerator, denominator, pct, semantic, band}`
- `confidence {level, reasons}`
- `freshness {status, source_updated_at, generated_at, as_of}`
- `sample_size`
- `source_status`
- `source_period`
- `limitations`
- `data_quality_flags`
- `provenance`
- `trust_level`

Trust precedence is auditable and non-probabilistic:

`SOURCE_AVAILABILITY → FRESHNESS → COVERAGE → CONFIDENCE`.

No opaque numeric confidence score is introduced.

Freshness states: `CURRENT`, `STALE`, `UNKNOWN`. A source newer than its generated model is `STALE`.

Coverage remains domain-specific. Low coverage is not transformed into a business outcome.

## Frozen baseline semantics

- Identity safe linkage: `296/8,716 = 3.40%` — `SAFE_IDENTITY_LINKAGE`.
- Sales safe linkage: `208/1,299 = 16.01%`.
- F3 product resolution: `397/406 = 97.78%`.
- F4 financial evidence: `123/1,299 = 9.47%` — absence is not non-payment.
- Historical transaction source availability: `1/3 = 33.33%` — source availability, not revenue.
- Transactional sales 2024: `NO_CERTIFIED_SOURCE`, value `null`, never zero.
- Transactional sales 2025: `NO_CERTIFIED_SOURCE`, value `null`, never zero.
- Lifecycle classified evidence consumes F6.2 and keeps insufficient evidence explicit.

## Security

Identity-confidence view/functions, Metric Trust baseline and aggregate contract are service-only. The existing Patient Commercial 360 browser RPC remains the only governed gateway and continues to rely on the certified F6.2/F6.1 Auth V3 + `PASSWORD_2FA` chain. F6.3 adds trust metadata only; it does not expose raw aliases or new PHI.

## Exit gate

F6.3 may close only after exact-head FAST + isolated DB/security/semantic + replay + recovery, upstream regression, anti-drift LIVE readback, migration Triple-Proof, deterministic terminal fingerprint x2, certificate/snapshot, exact-head final CI, merge with `expected_head_sha`, post-merge LIVE fingerprint, `aos_memory`, Notion and GitHub CURRENT consistency.
