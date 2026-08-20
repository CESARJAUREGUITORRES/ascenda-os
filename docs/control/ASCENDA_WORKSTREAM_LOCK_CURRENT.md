# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-19 America/Lima  
**Entry baseline:** `main@2b636acef991f51ce5e3c71a5ddbde7f3c58e23c`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED`  
**REV-F6.0 fingerprint:** `02ba53adb9dabfcd0a4557061be53c2f`  
**CURRENT GATE:** `REV-F6.1 — LIVE PASS / FINAL EXACT-HEAD CI + MERGE + POST-MERGE READBACK PENDING`  
**REV-F6.1 terminal fingerprint:** `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `BLOCKED until REV-F6.1 terminal closeout`  
**REV-F7:** `BLOCKED until REV-F6 certification`

This is the single mutable Revenue execution pointer. GitHub CURRENT + Supabase LIVE remain authoritative over historical checkpoints.

## One-lock rule

At most one HIGH/CRITICAL mutable workstream may alter shared Revenue/current-state contracts. `REV-F6-CLOSEOUT` owns the lane until F6.7 or explicit handoff.

## Certified upstream truth boundary

- F3 = canonical product truth;
- F4 = payment/revenue/cartera truth;
- F5 = patient identity + provenance truth;
- `aos_ventas` = canonical persisted sales ledger;
- F6 = derived intelligence/read models only.

Protected truth after REV-F6.1 LIVE hotfix:

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 fp = `5af139243f6aed37020048af292587fe`;
- F5.10 terminal fp = `2f0a365fae4caaa7be9d204e0f76679b`;
- F6.0 fp = `02ba53adb9dabfcd0a4557061be53c2f`.

No REV-F6.1 merge or read-model hotfix mutated those truth domains.

## REV-F6.1 Patient Commercial 360 V2 — LIVE PASS

PR #310 evolves the existing Patient 360; it does not create a second panel, patient master or identity authority.

Pre-certificate exact-head `7ca6ebd29708d4b91bdca18d7cbc26cded7db562` passed:

- REV-F6.1 workflow run `32326821500` / #18 = **SUCCESS**;
- deterministic service-worker cutover = **PASS / stable**;
- FAST/UI = **PASS**;
- isolated DB/security/semantic = **PASS**;
- idempotent replay = **PASS**;
- recovery fail-closed = **PASS**;
- REV-F6.0 upstream = **PASS**;
- Ascenda CI #2613 = **SUCCESS**;
- F4 + WA S12/S13/S14/S15 + Sentinel = **SUCCESS**.

The only Cartera red failed at `actions/checkout` before tests. Rerun job `96301352394` passed checkout, isolated Supabase, database lint, all pgTAP/security boundaries, runtime smoke and emergency recovery = **SUCCESS**. It required no F6.1 code change.

## LIVE migrations

- `20260820030050` — `rev_f6_1_patient_commercial_360_v2`;
- `20260820031515` — `rev_f6_1_alias_normalization_fix`.

The normalization hotfix was applied alone after anti-drift; the base production migration was not needlessly replayed.

## Identity Bridge V2 terminal state

After symmetric normalization:

- CANONICAL_ID = **7,262 keys / 7,262 resolved / 0 conflict**;
- PHONE = **7,136 / 7,099 / 37**;
- DOCUMENT = **2,605 / 2,459 / 146**;
- EMAIL = **1,633 / 1,555 / 78**;
- resolved aliases with `candidate_count <> 1` = **0**;
- orphan canonical targets = **0**;
- F5 memberships = **15,498**;
- classifications = **8,716**;
- MATCH clusters = **296**.

### Real old/current phone proof

A real patient with distinct current and F5-reviewed historical phone aliases was tested without persisting PII:

- current phone → **MATCH**;
- historical phone → **MATCH**;
- both → **same canonical_patient_id**;
- distinct aliases = **true**.

### Collision fail-closed proof

All **37** PHONE conflict keys were passed through the resolver:

- `IDENTITY_CONFLICT` + null canonical target = **37 / 37**;
- violations = **0**.

Identity resolver remains exact-key only: no fuzzy matching, name authority, phone-nearness authority or automatic merge.

## Security boundary — LIVE PASS

- private alias view → anon/authenticated SELECT **false / false**;
- internal resolver → anon/authenticated EXECUTE **false / false**;
- token-gated search/360 browser gateways remain available;
- both gateways enforce Auth V3 + `PASSWORD_2FA` patient permissions;
- legacy `aos_paciente_360(text)` → anon/authenticated EXECUTE **false / false**;
- clinical arrays default empty and are populated only under the admin gate;
- isolated semantic tests prove advisor has no clinical notes/documents and admin+2FA receives role-gated clinical history.

## Historical semantics

- patient history 2024/2025/2026 remains available;
- transactional sales 2024/2025 remain `NO_CERTIFIED_SOURCE`;
- `NO_CERTIFIED_SOURCE != zero revenue`;
- unsupported historical factual YoY remains prohibited.

## REV-F6.1 deterministic terminal fingerprint

Contract:

`REV-F6.1_PATIENT_COMMERCIAL_360_V2_FINAL_V1`

Fingerprint:

`cd313998c5b5b38d5cb9e2f08882b826`

It was reproduced in **two independent Supabase LIVE calls** after the normalization hotfix.

Certificate:

`docs/control/REV_F6_1_PATIENT_COMMERCIAL_360_V2_CERTIFICATE_20260819.md`

Snapshot:

`docs/control/REV_F6_1_PATIENT_COMMERCIAL_360_V2_SNAPSHOT_20260819.json`

## REV-F6.1 terminal transition rule

LIVE is PASS, but formal certification remains fail-closed until all of these are true:

1. the final PR #310 head containing certificate + snapshot + this CURRENT pointer passes exact-head REV-F6.1 CI and affected regressions;
2. `main` is revalidated unchanged before merge;
3. PR #310 is merged with `expected_head_sha` equal to that exact final head;
4. post-merge GitHub readback confirms certificate + CURRENT in `main`;
5. post-merge Supabase reproduces `cd313998c5b5b38d5cb9e2f08882b826`, old/current convergence, 37/37 conflict fail-closed and all protected hashes;
6. `aos_memory` CURRENT is persisted/read back;
7. Notion CURRENT is reconciled/read back.

**When and only when all seven conditions pass:**

- `REV-F6.1 = PASS / CERTIFIED — 100%`;
- `REV-F6.2 — Customer Lifecycle = NEXT / UNBLOCKED`;
- `REV-F6-CLOSEOUT` remains active;
- `REV-F7` remains blocked.

## REV-F6 roadmap

1. F6.0 Data Contract — **PASS / CERTIFIED**.
2. F6.1 Patient Commercial 360 V2 — **LIVE PASS / terminal closeout pending**.
3. F6.2 Customer Lifecycle — blocked until F6.1 closeout.
4. F6.3 Identity Confidence + Metric Trust.
5. F6.4 Sales Intelligence 3.0.
6. F6.5 Historical-sales plug-in, only for certified sources.
7. F6.6 Sentinel Data Integrity handoff.
8. F6.7 Final certification.
