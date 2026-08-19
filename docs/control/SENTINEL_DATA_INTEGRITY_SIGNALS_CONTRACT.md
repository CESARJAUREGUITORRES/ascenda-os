# SENTINEL — DATA INTEGRITY SIGNALS CONTRACT

**Status:** DESIGN REGISTERED / NO RUNTIME MUTATION IN THIS PR  
**Current Sentinel baseline:** SEN-F1..F13 certified/regression-only  
**Purpose:** extend Sentinel from application/runtime errors into aggregate business-data integrity without exposing PHI/PII.

Sentinel F2 already permits later phases to add `signal_contracts` without redefining domain identity. This contract uses that extension point.

## Principles

1. Sentinel observes; it never becomes business truth.
2. Signals contain counts, states, timestamps, contract IDs and safe internal references only.
3. Never send names, phones, emails, documents, clinical notes, message bodies, payment references or source-row payloads into Sentry/Telegram/general logs.
4. A signal must identify exact violated invariant and owning workstream.
5. A failed signal does not auto-repair production unless a separately governed recovery action is explicitly authorized.

## Signal registry

### `SEN-DQ-F5-001 SOURCE_BATCH_MISMATCH`
Trigger when a batch has `staging_complete=true` but persisted row count != manifest expected rows, or when expected range continuity fails.

Severity: HIGH.  
Payload: batch safe ID/hash prefix, expected count, actual count, missing/extra counts.

### `SEN-DQ-F5-002 IDENTITY_MEMBERSHIP_MISMATCH`
After F5 identity rebuild/certification, trigger when `members != source_rows`, orphan member count >0, or source row has invalid membership multiplicity.

Severity: CRITICAL after F5 certification; HIGH during controlled rebuild.

### `SEN-DQ-F5-003 IDENTITY_BRIDGE_COLLISION`
Trigger when one reviewed/active identifier resolves to >1 canonical patient or one supposedly resolved subject has a hard conflict.

Severity: CRITICAL for verified identifiers; HIGH for unresolved/review candidates.

No raw identifier value in signal payload.

### `SEN-DQ-F5-004 APPLY_WITHOUT_GOVERNANCE`
Trigger when a canonical F5 apply/merge event lacks required preview/review/admin authorization/audit relationship, or protected apply invariants diverge.

Severity: CRITICAL.

### `SEN-DQ-F5-005 DUPLICATE_PROFILE_DRIFT`
Track aggregate duplicate-candidate distribution by class (`AUTO_ELIGIBLE_EXACT`, `REVIEW_STRONG`, `BLOCK_CONFLICT`, `NO_MERGE`). Alert only on abnormal regression thresholds, not merely because review candidates exist.

Severity: MEDIUM/HIGH depending on drift.

### `SEN-DQ-REV-001 PRODUCT_SALE_ORPHAN`
Trigger when a current product sale fact references no canonical sale or a resolved sale product loses its required canonical product relation outside an approved lifecycle state.

Severity: HIGH.

### `SEN-DQ-REV-002 RECONCILIATION_ORPHAN`
Trigger when active revenue/cartera reconciliation references missing sale/payment/cotization evidence or impossible relation multiplicity.

Severity: HIGH/CRITICAL according to financial effect.

### `SEN-DQ-F6-001 READMODEL_STALE`
Trigger when a certified F6 read model exceeds its declared freshness SLA or version no longer matches source contract version.

Severity: MEDIUM; HIGH for executive/operational decision surfaces.

### `SEN-DQ-F6-002 COVERAGE_REGRESSION`
Trigger when a certified metric's coverage falls materially below its baseline/contract without an expected source-window change.

Severity: MEDIUM/HIGH.

### `SEN-DQ-360-001 PATIENT360_IDENTITY_RESOLUTION_REGRESSION`
Trigger when Patient 360 canonical resolution error/unresolved rate materially increases after Identity Bridge V2 deployment, or when alias lookup unexpectedly maps to conflict.

Severity: HIGH.

## Health semantics

Suggested states:

- `OK` — invariant satisfied;
- `DEGRADED` — non-destructive coverage/freshness issue;
- `REVIEW_REQUIRED` — ambiguity requires human resolution;
- `BROKEN` — integrity invariant violated;
- `UNKNOWN` — sensor cannot prove health.

Never return green from missing telemetry.

## Collection model

Preferred pattern:

- read-only aggregate SQL/RPC sensor;
- deterministic zero-PII result envelope;
- Sentinel evaluates contract;
- deduplicate alerts by `signal_id + affected_contract + state_digest`;
- recovery notification includes owning workstream and safe diagnostic counts.

Do not query/transport raw patient records merely to produce health signals.

## Frequency

- structural F5/F6 post-write checks: immediately at gate completion + scheduled regression;
- stable data-integrity health: hourly is sufficient unless an active migration/rebuild needs faster gate-local checks;
- freshness checks: according to declared read-model SLA.

## UI integration target

Sentinel panel/map should be able to show:

`Revenue → F5 Identity → Membership mismatch`  
`Revenue → F4 Reconciliation → orphan evidence`  
`Revenue → F6 Intelligence → stale read model`

with severity, first/last seen, current aggregate values and runbook link — never raw PHI/PII.

## Implementation boundary

This document registers the contract now. Runtime/DB implementation must respect the global mutable workstream lock. During REV-F5, only F5-local validation queries required for its certification may mutate/rebuild F5; Sentinel itself remains observation/regression-only unless explicitly handed a maintenance lock.

After REV-F5/REV-F6 define stable contracts, add these signals to Sentinel registry/telemetry using the established machine-readable registry and zero-PII boundary.

## Acceptance

- synthetic negative tests trigger each signal;
- green requires actual evidence, not absence of errors;
- no PHI/PII appears in payload/log/notification;
- state dedup prevents alert storms;
- runbook points to exact owning workstream;
- F5 false-certification class of error would have produced a HIGH/CRITICAL alert from source/membership mismatch.
