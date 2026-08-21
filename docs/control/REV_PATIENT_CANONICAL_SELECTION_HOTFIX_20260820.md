# REV Patient Canonical Selection Hotfix — 2026-08-20

## Incident
After PR #320 restored the Patient V2 runtime bridge, a current canonical patient could still display `UNRESOLVED` on selection when the patient also had an unrelated historical F5 cluster pending human review.

Observed owner case:
- canonical patient: `P-5549`
- current phone alias: `986293339`
- current document alias: `22892747`
- all three current aliases resolve uniquely to `P-5549`
- one 2024 historical cluster remains `AUTO_CANDIDATE / requires_human=true`
- identity confidence remains `MEDIUM` because historical linkage is not reviewed

## Root cause
The UI exposed `REVIEW_REQUIRED` without distinguishing current canonical identity from historical linkage review. In addition, the browser selection path could return `UNRESOLVED` for the canonical-id lookup even though the underlying Identity Bridge resolver returns `MATCH` for `P-5549`.

## Hotfix
- Preserve explicit canonical selection as the first attempt.
- If that browser call returns no patient, retry only through governed Identity Bridge V2 using current identifiers already present on the selected card:
  1. `CANONICAL_ID`
  2. `PHONE`
  3. `DOCUMENT`
- Each attempt remains fail-closed and must independently resolve to exactly one canonical patient.
- No auto-merge, F5 review decision, historical attribution, or source mutation is introduced.
- UI separates `ACTUAL RESOLVED` from `HISTÓRICO REVIEW` so historical review cannot be mistaken for an unresolved current patient.

## Safety
- No SQL/DDL in this hotfix.
- No production data mutation.
- Existing Auth V3 + PASSWORD_2FA gate remains authoritative.
- `IDENTITY_CONFLICT` remains visible and cannot be auto-assigned.

## Acceptance
- Jacquelina / `P-5549` opens the current Patient 360.
- Historical 2024 linkage remains review-required and is not silently attributed.
- Existing F6.1/F6.7 and cross-workstream CI remain green.
