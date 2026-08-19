# REV — PATIENT IDENTITY BRIDGE V2 CONTRACT

**Owner:** REV-F5 identity/provenance  
**Consumers:** REV-F6, CIA, WA, Agenda/Calls, imports, Patient 360  
**Status:** DESIGN FROZEN / IMPLEMENT AFTER F5 SOURCE+IDENTITY GATES  
**Compatibility input:** `aos_cia_contact_identity_v1` remains useful but phone-centric.

## Problem

`numero_limpio` is currently a transversal bridge, but a patient can change phone, share a family phone, be imported with formatting drift, or have historical rows under several numbers. Phone is therefore a lookup identifier, not canonical identity.

## Canonical key

The stable cross-domain subject is `canonical_patient_id`, referencing the surviving canonical patient profile. Consumers must not derive a new patient identity independently.

## Identifier model

One canonical patient may own zero or many governed identifiers:

- `PHONE` — current or historical alias;
- `DOCUMENT` — normalized document, where valid;
- `EMAIL` — normalized email;
- `SOURCE_PATIENT_ID` — always scoped by source batch/system;
- `HC` — always scoped unless a global uniqueness contract is proven;
- `CONTACT_KEY_V1` — compatibility bridge from CIA V1.

Each association needs at least:

- `canonical_patient_id`;
- `identifier_type`;
- restricted normalized identifier value or protected key;
- `source_scope` / provenance;
- `status` (`ACTIVE`, `HISTORICAL_ALIAS`, `CONFLICT`, `RETIRED`, `UNRESOLVED`);
- `confidence_band`;
- `evidence_method`;
- `valid_from` / `valid_to` where known;
- `review_state` / reviewer audit;
- timestamps.

Do not put raw PII into GitHub, logs, Sentinel events or broad analytics views.

## Resolution order

1. explicit canonical IDs / reviewed bridge relation;
2. exact strong identifier with compatible evidence;
3. multi-signal candidate to governed review;
4. weak/fuzzy evidence remains unresolved.

`numero_limpio` can locate candidate identity evidence but cannot alone authorize a merge.

## Duplicate classification contract

### AUTO_ELIGIBLE_EXACT

All must hold:

- exact normalized names;
- exact normalized surnames;
- exact normalized phone;
- exact normalized valid document;
- no conflicting DOB/sex/strong email/person evidence;
- no dependency/invariant blocker;
- dry-run and rollback contract available.

This means eligible for governed progressive apply, not silent background merging.

### REVIEW_STRONG

Examples:

- same valid document + compatible name but changed phone;
- name+surname+phone where document is missing on one side and there is no contradiction;
- historical source cluster provides multiple compatible strong signals.

Requires human approval.

### BLOCK_CONFLICT

Examples:

- same name+phone but different valid documents;
- same document with incompatible person evidence;
- DOB/sex contradiction not explained by obvious data-quality error;
- one identifier already reviewed to another canonical patient.

Must not merge automatically.

### NO_MERGE

- name-only;
- phone-only;
- approximate phone;
- numeric phone proximity;
- fuzzy spelling without strong evidence.

## Explicit deprecation

The legacy heuristic that treats 9-digit phone values within a numeric distance such as `ABS(phoneA-phoneB) <= 3` as duplicate evidence is **prohibited for identity decisions**.

The legacy physical merge RPC `aos_fusionar_pacientes` must not be used as the new F5 batch authority until it is dependency-audited and wrapped/versioned with:

- admin+2FA authorization;
- deterministic candidate ID, not phone pair as sole authority;
- dry-run impact counts;
- field conflict report;
- immutable merge/apply event;
- rollback/recovery path;
- preservation of absorbed identifiers as aliases;
- post-merge reference/orphan checks.

## Merge semantics

Canonical consolidation means:

- choose one canonical profile by evidence/governance, not simply newest record;
- move/repoint permitted business references safely;
- preserve historical source rows unchanged;
- preserve old phone/email/document aliases with provenance;
- mark absorbed profile non-canonical/fused rather than erasing its audit history;
- recompute derived totals from canonical facts, never sum cached totals blindly;
- do not collapse clinical records without clinical-domain dependency checks.

## Import compatibility

Existing Excel/import flows may continue to present `numero_limpio`. Import resolution becomes:

`raw phone → normalized phone alias → candidate canonical_patient_id → corroborating evidence → resolved/review/unresolved`.

If a patient changed phone, both old and new phone aliases may resolve to the same canonical patient after governed identity review.

## CIA compatibility

`aos_cia_contact_identity_v1` should remain a V1 phone/contact view for existing CIA consumers. Identity Bridge V2 becomes the richer governed source; CIA can receive a compatibility view that still exposes `contact_key → canonical_patient_id` where unambiguous.

Do not let CIA own a separate patient merge algorithm.

## Certification

Identity Bridge V2 is certified only when:

- every resolved alias maps to exactly one canonical patient;
- conflicts remain explicit, not coerced;
- no forbidden phone-proximity heuristic is used;
- absorbed aliases still resolve historically;
- Patient 360, WA/CIA compatibility and imports pass known-current regression;
- no unauthorized PII exposure is introduced;
- rollback/recovery is proven for physical consolidations.
