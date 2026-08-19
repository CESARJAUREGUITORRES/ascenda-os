# PROMPT — REV-F5 DEFINITIVE CLOSEOUT LOOP

Use this prompt to resume and finish REV-F5. It grants continuous execution across REV-F5 only, subject to the safety/lock gates below.

---

**EXECUTE `REV-F5-CLOSEOUT` FROM LIVE TRUTH UNTIL F5.10 IS ACTUALLY CERTIFIED.**

You are working on `CESARJAUREGUITORRES/ascenda-os`. The active namespace is `REV-F5`; never use bare F5 when crossing workstreams.

## OWNER AUTHORIZATION

I authorize the complete REV-F5 closeout loop, including its necessary GitHub branches/PRs, safe Supabase data operations through audited/versioned routes, exact-current CI, controlled canaries, governed admin+2FA Review/Apply, rollback proof, documentation and final certification. This authorization does **not** authorize bypassing 2FA/admin/security, exposing PII/PHI/secrets, inventing data, destructive broad cleanup, or mutating another HIGH/CRITICAL workstream.

Do not ask me to approve each file/year/chunk. Continue automatically inside REV-F5 while every gate passes. Stop only on a genuine external owner action/security blocker or a hard contradiction that cannot be safely resolved from existing evidence.

## 0 — MANDATORY BOOTSTRAP / AUTHORITY

Read fresh before any write:

1. `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/MEMORY_CURRENT.md`
6. `docs/control/REV_F5_LEARNING_INTERCONNECTION_CURRENT_20260819.md`
7. `docs/control/REV_F5_F6_IMPLEMENTATION_ROADMAP_CURRENT_20260819.md`
8. `docs/control/REV_PATIENT_IDENTITY_BRIDGE_V2_CONTRACT.md`
9. `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`
10. exact GitHub `main`, PR/checks/deploy and Supabase LIVE.

Production/live state outranks old chats, Notion and expected results.

Require `REV-F5-CLOSEOUT` as the sole mutable HIGH/CRITICAL lock. If `main` advanced, inspect/revalidate the diff before new writes.

## 1 — PERSISTENCE TRIPLE-PROOF

Never certify data from tool output alone. Every mutable checkpoint requires:

1. execution receipt;
2. direct live persisted readback;
3. independently constructed invariant query.

Every source batch closure additionally requires full idempotent replay of the exact SHA-bound source with zero new inserts/conflicts.

On timeout/block/ambiguous response:

`OBSERVE LIVE → IDENTIFY EXACT GAP → MUTATE ONLY GAP → READ BACK → VERIFY → CONTINUE`.

Never skip ahead because a local loop said COMPLETE.

## 2 — REBASELINE REV-F5.0

Freshly derive, do not assume, all six manifests, expected/staged rows, exact missing ranges, SHA, duplicate structural keys, orphans, F5 members/previews/apply events, active ingest and protected canonical counts.

Known prior checkpoint for comparison only: expected 15,498 and a previously observed 8,264 staged. Treat the fresh query as truth.

Confirm all six original XLSX sources by exact SHA before ingest. Do not ask owner to re-upload if they are recoverable from the current file/library/runtime context. No GitHub PII, no new bucket/transport/uploader while the existing compact-ingest route is usable.

## 3 — REV-F5.1 SOURCE INGEST

Use the existing audited private/idempotent compact ingest path. Resume only exact missing rows. Complete one source safely, certify it, then advance automatically to the next incomplete source.

For each chunk:

- source SHA exact;
- request row numbers exact;
- require RPC success semantics;
- immediately read LIVE persisted count/range;
- verify inserted+existing=requested;
- on raw conflict isolate exact row/range and compare against source; never overwrite blindly;
- no canonical patient mutation.

When a source reaches expected count:

- continuity min/max/range exact;
- zero missing/extra/multiplicity anomalies;
- zero duplicate structural keys/orphans;
- `staging_complete=true` only if count/range really match;
- full-source replay: all rows existing, zero new inserts/conflicts.

Continue until **15,498/15,498 and 6/6 complete**.

## 4 — REV-F5.2 SOURCE CERTIFICATION

Run two independent global structural audits. Require:

- 15,498 distinct source rows;
- six exact manifests/SHA;
- exact ranges per source;
- no missing/out-of-range/multiplicity error;
- no F5 canonical apply before identity/review gate;
- audit/replay consistency.

If any check fails, repair only the failing source/range and repeat.

## 5 — REV-F5.3 IDENTITY REBUILD

Only after F5.2 PASS, run the existing F5 identity rebuild. Require:

- 15,498 memberships for 15,498 source rows;
- one valid membership per source row according to contract;
- zero orphan memberships;
- auditable cluster evidence;
- no silent canonical-patient mutation.

## 6 — REV-F5.4 MATCH / REVIEW / NEW + DUPLICATE RESOLUTION

Classify historical clusters conservatively and also audit current `aos_pacientes` duplicate profiles.

### Patient duplicate rules

Use fresh aggregates; do not assume old counts.

`AUTO_ELIGIBLE_EXACT` requires exact normalized name + surname + phone + valid document, with no conflict in DOB/sex/strong email/person evidence and no dependency blocker.

`REVIEW_STRONG`: strong multi-signal evidence such as same valid document + compatible person evidence with changed phone, or other non-conflicting strong combinations.

`BLOCK_CONFLICT`: strong contradictions such as same name+phone but different valid documents, incompatible DOB/sex, or identifier already resolved to another canonical patient.

`NO_MERGE`: name-only, phone-only, fuzzy name only, approximate phone.

**Never use numeric phone proximity (for example ±3) as duplicate evidence.**

Do not use the legacy `aos_fusionar_pacientes` as batch authority without first auditing/versioning/hardening it for F5. Physical consolidation is CRITICAL and must preserve provenance and absorbed identifier aliases.

Preferred result: stable `canonical_patient_id`; absorbed/old phones remain historical aliases so imports and prior facts still resolve to the same person.

## 7 — IDENTITY BRIDGE V2

Implement/version the governed bridge defined in `REV_PATIENT_IDENTITY_BRIDGE_V2_CONTRACT.md` only after identity evidence is ready.

Do not create a competing CIA/customer identity. Reuse `aos_cia_contact_identity_v1` as compatibility input/view where useful.

Required behavior:

`identifier (phone/document/email/source-scoped ID/HC) → governed evidence → canonical_patient_id or REVIEW/CONFLICT/UNRESOLVED`.

Phone remains accepted for existing Excel imports and lookups but is no longer canonical identity authority.

For any physical duplicate consolidation:

- admin+2FA;
- dry-run impact/dependency counts;
- immutable merge/apply audit event;
- 1-row canary;
- rollback/recovery proof;
- post-merge orphan/reference checks;
- preserve old identifiers as aliases;
- progressive safe apply only to eligible cases.

## 8 — REV-F5.5 ENRICHMENT PREVIEW

Generate fill-only proposed patches from certified provenance. Never silently overwrite conflicting non-empty canonical fields. Clinical notes/allergies stay outside commercial auto-apply. Budget/payment semantics remain separated.

Require exhaustive preview classification and protected-field checks.

## 9 — REV-F5.6 GOVERNED REVIEW & APPLY

Use existing or safely versioned admin+2FA review/apply/rollback mechanisms. Prove:

`Review → DRY_RUN → APPLY → live verify → ROLLBACK → live verify → re-APPLY`.

Then scale progressively (1 → 10 → 50 → 100 → safe remainder), isolating conflicts rather than forcing them.

For duplicate patient consolidation, use the same governed/canary/rollback discipline and do not delete source provenance.

## 10 — REV-F5.7 PATIENT→REVENUE LINKAGE

Certify linkage using explicit IDs first:

`canonical patient → sale → REV-F3 canonical product → REV-F4 payment/revenue/cartera`.

Use Identity Bridge evidence only where explicit business IDs are unavailable. Quantify resolved/review/unresolved coverage; no name-only or phone-only revenue ownership claim.

## 11 — REV-F5.8 HISTORICAL TRANSACTION COVERAGE

Audit whether detailed 2024/2025 sales ledgers are actually present. If absent, explicitly state that Patient History 2024–2026 exists but complete 2024/2025 revenue does not yet exist. Do not fabricate YoY.

The future files must enter through `REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md` and reuse F3/F4/F5.

## 12 — REV-F5.9 COVERAGE & DATA QUALITY

Emit numeric report with numerator/denominator and period for at least:

- source/staging;
- canonical identity resolution;
- REVIEW/CONFLICT/UNRESOLVED;
- DNI/phone/email/DOB/sex/geography coverage;
- duplicate consolidation coverage;
- sales→patient linkage;
- product resolution;
- payment/cartera linkage;
- transaction years actually covered.

Persist only safe aggregate/audit evidence; no PII in GitHub/Sentinel/logs.

## 13 — SENTINEL CONTRACT HANDOFF

Do not reopen Sentinel as a competing mutable project. Register/validate the aggregate zero-PII invariants from `SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md` as F5 runbook/contract evidence. The final F5 state must be monitorable for source mismatch, membership mismatch, identity collision and apply-without-governance.

## 14 — REV-F5.10 FINAL INDEPENDENT CERTIFICATION

Before claiming completion:

- re-read exact `main` and lock;
- require relevant exact-head CI/deploy green;
- independently query all F5 terminal invariants from scratch;
- prove no active ingest/temporary residue;
- verify merge/apply audit and rollback consistency;
- verify Identity Bridge uniqueness/conflicts are explicit;
- verify no forbidden auto-merge heuristic;
- verify current Patient 360/import compatibility is not broken by identity changes;
- reconcile GitHub CURRENT docs + `aos_memory` + Notion last.

Only then declare exactly:

`REV-F5 — PRODUCTION CERTIFIED — 100%`

and release/unassign the REV-F5 lock according to governance.

## 15 — REQUIRED TERMINAL OUTPUT: HAND ME REV-F6 PROMPT

Immediately after real F5.10 PASS, do **not** start REV-F6 automatically unless the owner explicitly asks execution in that same turn.

Instead:

1. fetch `docs/control/prompts/REV_F6_EXECUTION_PROMPT_TEMPLATE.md`;
2. replace template placeholders with the exact final F5-certified `main` SHA, live F5 terminal counts, identity/duplicate coverage and historical-sales coverage;
3. save/reconcile the rebound prompt in GitHub if the template contract requires it;
4. return the complete copy/paste-ready REV-F6 prompt to me.

Your final response must distinguish:

- what was actually persisted/certified;
- unresolved human-review/conflict inventory (aggregate only);
- what 2024/2025 transaction coverage still lacks;
- exact next prompt for REV-F6.

---
