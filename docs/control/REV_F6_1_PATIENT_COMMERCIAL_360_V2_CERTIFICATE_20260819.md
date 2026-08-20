# REV-F6.1 — Patient Commercial 360 V2 — Production Certification

**Date:** 2026-08-19 America/Lima  
**Status:** LIVE TERMINAL GATES PASS / FINAL EXACT-HEAD CI + MERGE + POST-MERGE CONTROL READBACK REQUIRED  
**Entry baseline:** `main@2b636acef991f51ce5e3c71a5ddbde7f3c58e23c`  
**PR:** #310  
**Pre-certificate validated head:** `7ca6ebd29708d4b91bdca18d7cbc26cded7db562`  
**F6.0 input fingerprint:** `02ba53adb9dabfcd0a4557061be53c2f`  
**REV-F6.1 terminal fingerprint:** `cd313998c5b5b38d5cb9e2f08882b826`

## Scope

REV-F6.1 evolves the existing Patient 360 into a canonical `canonical_patient_id`-based commercial read model. It does not create a second patient master, does not merge patients, and does not mutate canonical sales, product truth, financial truth or F5 identity decisions.

The phase materializes a private Identity Bridge V2 from current canonical patient identifiers plus F5-reviewed MATCH aliases, exposes governed Auth V3 + `PASSWORD_2FA` search/360 gateways, preserves conflict states, and consumes F5/F3/F4/F6.0 truth layers.

## Pre-LIVE exact-head validation

PR #310 at `7ca6ebd29708d4b91bdca18d7cbc26cded7db562` passed:

- REV-F6.1 workflow run `32326821500` / run #18 = **SUCCESS**;
- deterministic service-worker cutover = **PASS / no-change**;
- FAST/UI contracts = **PASS**;
- isolated DB/security/semantic contracts = **PASS**;
- full idempotent replay = **PASS**;
- fail-closed recovery = **PASS**;
- REV-F6.0 upstream regression = **PASS**;
- Ascenda CI run #2613 = **SUCCESS**;
- F4, WA S12/S13/S14/S15 and Sentinel regressions = **SUCCESS**.

The sole Cartera red on the initial transversal run failed in `actions/checkout` before any database/test execution. The isolated-security job was rerun as job `96301352394` and then passed checkout, isolated Supabase, lint, all pgTAP/security contracts, runtime smoke and emergency recovery = **SUCCESS**. No F6.1 code change was required for that infrastructure failure.

## Anti-drift before hotfix

Immediately before the normalization hotfix:

- GitHub `main` = `2b636acef991f51ce5e3c71a5ddbde7f3c58e23c`;
- PR #310 head = `7ca6ebd29708d4b91bdca18d7cbc26cded7db562`;
- F6.0 LIVE fp = `02ba53adb9dabfcd0a4557061be53c2f`;
- patients = 7,688 / `eee5a57717937a4f77049b3aebd8c525`;
- sales = 1,299 / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = 406 / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = 162 / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 bridge fp = `5af139243f6aed37020048af292587fe`.

Anti-drift = **PASS**.

## LIVE migrations

Supabase LIVE migration ledger:

- `20260820030050` — `rev_f6_1_patient_commercial_360_v2`;
- `20260820031515` — `rev_f6_1_alias_normalization_fix`.

The second migration is the normalization hotfix only. It normalizes F5-reviewed PHONE/DOCUMENT/EMAIL aliases with the exact same resolver contract used at lookup time. The base F6.1 migration was not needlessly replayed in production.

## Identity Bridge V2 LIVE proof

After normalization:

- CANONICAL_ID keys = 7,262; resolved = 7,262; conflicts = 0;
- PHONE keys = 7,136; resolved = 7,099; conflicts = 37;
- DOCUMENT keys = 2,605; resolved = 2,459; conflicts = 146;
- EMAIL keys = 1,633; resolved = 1,555; conflicts = 78.

The pre-hotfix PHONE key count of 7,139 became 7,136 because three formatting/country-code variants collapsed into the same normalized identifiers. This is expected normalization, not patient deletion or merge.

Independent invariants:

- resolved aliases with `candidate_count <> 1` = **0**;
- canonical alias targets missing from `aos_pacientes` = **0**;
- F5 memberships = **15,498**;
- F5 classifications = **8,716**;
- F5 MATCH clusters = **296**.

### Real old/current phone proof

A real canonical patient with distinct current and F5-reviewed historical phone aliases was selected without persisting or publishing PII.

- current phone resolver status = **MATCH**;
- historical phone resolver status = **MATCH**;
- aliases are distinct = **true**;
- both resolve to the exact same `canonical_patient_id` = **true**.

The patient identifier is retained only as a one-way evidence hash in execution output; no PII is committed to GitHub.

### Conflict fail-closed proof

All 37 distinct PHONE conflict keys were independently passed through the resolver:

- conflict keys = **37**;
- `IDENTITY_CONFLICT` + null canonical target = **37**;
- violations = **0**.

No fuzzy matching or phone-nearness authority exists in the internal resolver; lookup is exact on normalized `(identifier_type, identifier_key)`.

## Security / PHI boundary

LIVE ACL readback:

- alias view SELECT by anon/authenticated = **false / false**;
- internal resolver EXECUTE by anon/authenticated = **false / false**;
- token-gated search gateway browser executable = **true**;
- token-gated commercial 360 gateway browser executable = **true**;
- legacy `aos_paciente_360(text)` EXECUTE by anon/authenticated = **false / false**.

LIVE function-definition readback proves:

- search gateway calls `aos_app_actor_v3` for advisor/admin patient permissions with 2FA required;
- commercial 360 calls `aos_app_actor_v3` and requires the same 2FA boundary;
- clinical arrays default to empty and are populated only inside the `v_is_admin` gate;
- resolver uses exact normalized key equality;
- no similarity/Levenshtein/Soundex/Metaphone path;
- no phone-nearness logic.

The isolated semantic test additionally proved advisor receives no clinical notes/documents while admin+2FA receives the role-gated clinical arrays.

## Protected truth — unchanged after LIVE hotfix

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 = `5af139243f6aed37020048af292587fe`;
- F6.0 = `02ba53adb9dabfcd0a4557061be53c2f`.

Business/identity truth mutation caused by REV-F6.1 read-model closeout = **0**.

## Historical semantics

- canonical transactional sales rows in 2024–2025 = **0 in the current certified ledger**;
- semantic remains **`NO_CERTIFIED_SOURCE != zero revenue`**;
- unsupported historical YoY remains prohibited.

## Deterministic terminal fingerprint

Contract:

`REV-F6.1_PATIENT_COMMERCIAL_360_V2_FINAL_V1`

Terminal fingerprint:

`cd313998c5b5b38d5cb9e2f08882b826`

The fingerprint was recomputed in **two independent LIVE calls** after the hotfix and was identical both times.

The state hashed by the contract includes migration presence, per-identifier alias/collision metrics, real old/current-phone convergence, all PHONE conflict fail-closed counts, ACL/security semantics, protected domain hashes, F5/F6.0 upstream hashes, and historical-source semantics. It deliberately excludes timestamps and PII.

## Terminal closeout rule

This certificate becomes the authoritative **REV-F6.1 PASS / CERTIFIED — 100%** closeout only when all remaining controls are satisfied on the post-certificate exact head:

1. PR #310 final head passes REV-F6.1 exact-head CI and affected upstream/transversal regressions;
2. `main` is revalidated unchanged before merge;
3. PR #310 is merged using `expected_head_sha` equal to that final head;
4. post-merge GitHub readback confirms this certificate and CURRENT lock in `main`;
5. post-merge Supabase readback reproduces `cd313998c5b5b38d5cb9e2f08882b826`, old/current convergence, 37/37 conflict fail-closed and all protected fingerprints;
6. `aos_memory` CURRENT is persisted and read back;
7. Notion CURRENT is reconciled and read back.

Only then:

- `REV-F6.1 = PASS / CERTIFIED — 100%`;
- `REV-F6.2 — Customer Lifecycle = NEXT / UNBLOCKED`;
- `REV-F6-CLOSEOUT` remains the mutable Revenue lock;
- `REV-F7` remains blocked until REV-F6 final certification.
