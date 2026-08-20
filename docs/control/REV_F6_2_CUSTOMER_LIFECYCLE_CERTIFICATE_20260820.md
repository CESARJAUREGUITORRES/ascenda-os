# REV-F6.2 — Customer Lifecycle — Production Certification

**Date:** 2026-08-20 America/Lima  
**Status candidate:** `PASS / CERTIFIED — 100%` after final exact-head CI + certification-PR merge + post-merge control readback  
**Implementation PR:** #311  
**Implementation merge main:** `1532cb20e087a5f2025b29bf86d4d828b7445f68`  
**Implementation expected head:** `3eb30e39c8184d4acd2cf7dcc7548d35f65c5fa3`  
**F6.0 input fp:** `02ba53adb9dabfcd0a4557061be53c2f`  
**F6.1 input fp:** `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2 terminal fp:** `d977b9669b9e741e8785cd863caaf9c2`

## Scope

REV-F6.2 implements deterministic Customer Lifecycle as a derived/read-only commercial model over certified F5 identity/provenance, F6.1 Identity Bridge V2, safely resolved Agenda activity and canonical matched sales. It does not create a second patient master, does not change canonical identity, does not mutate sales/product/financial truth and does not manufacture 2024/2025 revenue.

Lifecycle contract:

- `UNRESOLVED_IDENTITY`
- `HISTORICAL_REACTIVATED`
- `NEW_PATIENT`
- `ACTIVE_REPEAT`
- `RETURNING_PATIENT`
- `DORMANT`

A known canonical patient with no qualifying activity is deliberately not force-labelled: `lifecycle_state = null` with `INSUFFICIENT_ACTIVITY_EVIDENCE`.

Thresholds are explicit: recent/active <=90 days, dormant/reactivation gap >=180 days, reactivation window 30 days.

## Exact-head pre-LIVE validation

Implementation head `3eb30e39c8184d4acd2cf7dcc7548d35f65c5fa3` passed the complete isolated loop:

- REV-F6.2 workflow run `32329958387` = SUCCESS;
- F6.2 FAST = PASS;
- F6.2 DB/security/semantic = PASS;
- six-state deterministic fixtures = PASS;
- insufficient-evidence fail-closed = PASS;
- Lima business-date fixture = PASS;
- `FUSIONADO` exclusion fixture = PASS;
- full idempotent replay = PASS;
- F6.1 recovery boundary = PASS;
- REV-F6.0 workflow run `32329958435` = SUCCESS;
- REV-F6.1 workflow run `32329958478` = SUCCESS;
- Ascenda CI run `32329958393` = SUCCESS.

## LIVE migrations

Supabase LIVE contains:

- `rev_f6_2_customer_lifecycle_v1`;
- `rev_f6_2_lima_date_active_subject_fix`.

The hotfix was applied separately after the base release. It makes business date explicitly `America/Lima` and excludes `FUSIONADO` canonical subjects from Agenda identity and lifecycle event read-models.

## LIVE terminal state — 2026-08-20 America/Lima

Business-date function equals `(now() at time zone 'America/Lima')::date` = **PASS**.

Lifecycle summary:

- canonical/non-fused population = **7,262**;
- classified = **543**;
- insufficient activity evidence = **6,719**;
- qualifying event rows = **1,089**;
- `HISTORICAL_REACTIVATED` = **1**;
- `NEW_PATIENT` = **129**;
- `ACTIVE_REPEAT` = **90**;
- `RETURNING_PATIENT` = **137**;
- `DORMANT` = **186**.

These are observed-state counts at the declared `as_of`. They are not complete historical revenue cohorts.

### FUSIONADO boundary

- lifecycle events pointing to `FUSIONADO` = **0**;
- Agenda identity rows resolving to `FUSIONADO` = **0**.

### Agenda identity read-model

- rows = **3,132**;
- resolved = **2,754**;
- identity conflict = **90**;
- unresolved = **288**;
- RESOLVED rows with `candidate_count <> 1` = **0**.

### Real lifecycle canaries

PII was not persisted or committed. Subjects are retained only as one-way hashes in execution evidence.

- `ACTIVE_REPEAT`: expected = actual, recency 61 days;
- `DORMANT`: expected = actual, recency 199 days;
- `HISTORICAL_REACTIVATED`: expected = actual, reactivation gap **372 days**, recency 19 days, claim strength HIGH.

There are currently **0 eligible canonical subjects with a future `CITA CONFIRMADA` after the business date**, therefore a real LIVE future-appointment canary is N/A today. The `future appointment prevents false DORMANT` case remains covered by exact-head isolated semantic fixtures and recovery/replay tests; no synthetic production case was created.

## Identity conflict fail-closed

PHONE conflict keys remain **37**.

All **37/37** were independently passed through the F6.2 lifecycle lookup:

- `UNRESOLVED_IDENTITY` + `IDENTITY_CONFLICT` + null canonical target = **37**;
- violations = **0**.

## Security / ACL readback

PASS:

- business-date helper browser closed;
- Agenda identity view browser closed;
- lifecycle event view browser closed;
- direct lifecycle resolver browser closed;
- direct canonical-patient lifecycle function browser closed;
- private F6.1 base browser closed;
- governed `aos_patient_commercial_360_v2` browser executable;
- legacy `aos_paciente_360(text)` remains browser closed.

No lifecycle signal itself authorizes outreach, campaign delivery, patient merge or clinical disclosure.

## F6.1 upstream non-regression

Identity Bridge V2 still matches the certified F6.1 snapshot exactly:

- CANONICAL_ID: 7,262 keys / 7,262 resolved / 0 conflict / max candidates 1;
- PHONE: 7,136 / 7,099 / 37 / max 4;
- DOCUMENT: 2,605 / 2,459 / 146 / max 7;
- EMAIL: 1,633 / 1,555 / 78 / max 7;
- F5 memberships = 15,498;
- classifications = 8,716;
- MATCH clusters = 296;
- distinct old/current phone convergence subjects currently observable = 4;
- PHONE conflict fail-closed violations = 0.

## Protected truth — unchanged

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 = `5af139243f6aed37020048af292587fe`;
- F6.0 = `02ba53adb9dabfcd0a4557061be53c2f`;
- F6.1 certified input = `cd313998c5b5b38d5cb9e2f08882b826`.

REV-F6.2 business-truth mutation = **0**.

## Historical semantics

- 2024 patient history = AVAILABLE;
- 2025 patient history = AVAILABLE;
- 2026 patient history = AVAILABLE;
- 2024 transactional sales = `NO_CERTIFIED_SOURCE`;
- 2025 transactional sales = `NO_CERTIFIED_SOURCE`;
- unsupported 2024→2026 YoY = prohibited;
- `NO_CERTIFIED_SOURCE != zero revenue` remains mandatory.

Historical appointment evidence may support lifecycle recency/reactivation. It never becomes a historical sale/payment/debt fact.

## Deterministic terminal fingerprint

Contract: `REV-F6.2_CUSTOMER_LIFECYCLE_FINAL_V1`

Terminal fingerprint: `d977b9669b9e741e8785cd863caaf9c2`

The fingerprint was recomputed in **two independent LIVE calls** after the Lima/FUSIONADO hotfix and was identical both times. The hashed state contains only aggregate/non-PII evidence: migration presence, explicit business date, lifecycle summary, Agenda identity counts, FUSIONADO invariants, F6.1 Identity Bridge cardinalities, 37/37 conflict fail-closed proof, ACL boundaries, protected F3/F4/F5/F6.0 inputs and historical-source semantics.

## Control-sequencing note

PR #311 was merged with the correct `expected_head_sha=3eb30e39c8184d4acd2cf7dcc7548d35f65c5fa3`, producing `main@1532cb20e087a5f2025b29bf86d4d828b7445f68`, before the final certificate artifact was committed. The merge commit title is an execution-control artifact and does not change the merged tree; its parents prove the exact certified implementation head was merged. This certificate therefore closes via a separate certification PR and requires final exact-head CI plus post-merge GitHub/Supabase/`aos_memory`/Notion readbacks.

## Final closeout gate

After this certificate/snapshot/current-lock exact head passes CI and its certification PR is merged with `expected_head_sha`, require:

1. GitHub `main` readback contains this certificate and CURRENT pointer;
2. Supabase LIVE reproduces terminal fp `d977b9669b9e741e8785cd863caaf9c2`;
3. protected truth remains exact;
4. `aos_memory` is updated and read back;
5. Notion F6 CURRENT is reconciled and read back.

Only then declare:

- `REV-F6.2 = PASS / CERTIFIED — 100%`;
- `REV-F6.3 — Identity Confidence / Metric Trust = NEXT / UNBLOCKED`;
- `REV-F6-CLOSEOUT` remains the single mutable Revenue lock;
- `REV-F7` remains blocked until REV-F6 final certification.
