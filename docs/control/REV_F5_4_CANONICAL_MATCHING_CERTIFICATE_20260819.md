# REV-F5.4 — CANONICAL MATCHING / MATCH-REVIEW-NEW CERTIFICATE

**Captured:** 2026-08-19 America/Lima  
**Workstream:** `REV-F5-CLOSEOUT`  
**Entry baseline:** `main@7d96eb9d39bb7bb2c6b23bb82e9a225f29843d17`  
**Scope:** classification only. No Review/Apply, physical merge, canonical enrichment or patient creation.

## Rebaseline

REV-F5.1/F5.2/F5.3 source and identity invariants remained intact:

- source rows = **15,498**;
- identity members = **15,498** distinct source rows;
- clusters = previews = **8,716**;
- Apply events = **0**;
- preview applied rows = **0**.

`aos_pacientes` moved externally from the F5.3 observational count 7,686 to **7,687** before F5.4. Because F5 Apply remained zero, F5.4 rebuilt the preview against the new CURRENT canonical universe before classification. The classification baseline fingerprint is `619f20596f6f9181f96332997ee3d953`.

## Safety finding and correction

The F5.3 internal preview initially contained 408 `AUTO_CANDIDATE`. F5.4 detected that automatic acceptance was too permissive for the approved identity contract: some candidates had a contradiction against a populated canonical DNI/email/date-of-birth/sex field and/or multiple historical clusters targeted the same canonical patient.

A dedicated, private, lightweight table `aos_f5_canonical_classification_v1` and service-role-only RPC `aos_f5_classify_canonical_matches_v1()` were introduced. The F5.3 preview is preserved; F5.4 stores an explicit operational classification per cluster.

## Certified classification

| Classification | Clusters |
|---|---:|
| MATCH | **296** |
| REVIEW | **6,984** |
| NEW | **1,436** |
| **TOTAL** | **8,716** |

The classifier conservatively downgraded **112 / 408** original AUTO candidates to REVIEW. Of those, 110 carried at least one canonical strong-field conflict and 6 participated in a canonical-target collision; categories may overlap.

## REVIEW reason distribution

- canonical strong-field conflict: **3,067**;
- ambiguous / insufficient evidence: **2,908**;
- canonical target collision: **872**;
- source strong-identifier conflict: **111**;
- candidate tie: **26**.

Total REVIEW = **6,984**.

All **111** source strong-conflict clusters are REVIEW.

## MATCH evidence rules

All **296 MATCH** rows satisfy the approved conservative contract:

- valid canonical target exists;
- no canonical DNI/email/DOB/sex contradiction;
- no source strong-identifier conflict;
- no candidate tie;
- no target collision;
- no name-only authority;
- no phone-only authority.

Observed MATCH methods are combinations containing `DNI_NAME`, or `EMAIL` accompanied by `PHONE_NAME` and/or `NAME_DOB`. No `PHONE_NAME`-only MATCH exists.

## Collision audit

The source preview contains **870 canonical targets** referenced by more than one historical cluster (**1,740 classification rows**, maximum 2 clusters per target). These cases are not silently merged. Any automatic candidate involved in such collision is downgraded to REVIEW.

## Exhaustiveness / integrity gates

PASS:

- classifications = **8,716 / 8,716 clusters**;
- distinct classified cluster IDs = **8,716**;
- unclassified clusters = **0**;
- classification orphans = **0**;
- source memberships = **15,498 / 15,498**;
- source rows represented = **15,498 / 15,498**;
- MATCH without canonical target = **0**;
- NEW with canonical target = **0**;
- unsafe MATCH carrying conflict/collision = **0**;
- source strong-conflict not REVIEW = **0**;
- previews outside human gate = **0**;
- preview applied rows = **0**;
- canonical Apply events = **0**.

## Privacy / execution boundary

- classifier EXECUTE: `anon=false`, `authenticated=false`, `service_role=true`;
- classification table SELECT: `anon=false`, `authenticated=false`;
- no PII committed to GitHub;
- no canonical patient writes performed.

## Determinism proof

The complete F5.4 classification was executed twice against unchanged CURRENT source/identity/canonical state.

Both receipts were identical:

- MATCH = 296;
- REVIEW = 6,984;
- NEW = 1,436;
- unsafe AUTO reclassified = 112;
- canonical rows = 7,687;
- canonical mutation = false;
- Apply events = 0.

Semantic classification fingerprint run 1: `7a2c36e1e7a3ff6fb12196cbf7bacdfd`.  
Semantic classification fingerprint run 2: `7a2c36e1e7a3ff6fb12196cbf7bacdfd`.

Canonical fingerprint before/after and both runs: `619f20596f6f9181f96332997ee3d953`.

Result: **DETERMINISTIC PASS**.

## Gate result

- `REV-F5.4 — CANONICAL MATCHING — PASS`
- `REV-F5.5 — ENRICHMENT PREVIEW — UNBLOCKED / NOT STARTED`
- `REV-F5.6 — REVIEW & APPLY — BLOCKED`
- overall `REV-F5 — EN CURSO / NOT YET PRODUCTION CERTIFIED`

No REV-F5.5 or Apply action is authorized by this certificate.
