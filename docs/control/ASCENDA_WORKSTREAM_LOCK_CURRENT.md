# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 PRODUCTION CERTIFIED — 100%  
**Captured:** 2026-08-19 America/Lima  
**Final-cert entry baseline:** `main@4c81992934afdd187628c48b6ee8132b4d248a79`  
**REV-F5.10 terminal state fingerprint:** `2f0a365fae4caaa7be9d204e0f76679b`  
**REV-F5-CLOSEOUT lock:** `RELEASED upon merge of the exact-head F5.10 certification PR`  
**NEXT WORKSTREAM:** `REV-F6 — UNBLOCKED / NEXT / NOT STARTED`

This file is the CURRENT execution pointer. Detailed phase evidence is preserved in the REV-F5 certificates and regression contracts under `docs/control/` and `ci/rev-f5-*`.

## Certified REV-F5 sequence

- REV-F5.1 exact source ingestion — **PASS**;
- REV-F5.2 staging/manifests/replay — **PASS**;
- REV-F5.3 identity memberships/preview — **PASS**;
- REV-F5.4 canonical MATCH/REVIEW/NEW — **PASS**;
- REV-F5.5 fill-only enrichment preview — **PASS**;
- REV-F5.6 governed Review & Apply — **PASS**;
- REV-F5.7 Historical JOIN patient → sale → F3 → F4 — **PASS**;
- REV-F5.8 historical transaction-source boundary — **PASS**;
- REV-F5.9 Coverage & Data Quality Report — **PASS**;
- REV-F5.10 independent final certification — **PASS / CERTIFIED**.

## Final LIVE checkpoint

### Source / provenance

- sources = **6 / 6 `MATCHED`**;
- expected/persisted source rows = **15,498 / 15,498**;
- identity memberships = **15,498 / 15,498**;
- identity clusters = **8,716**;
- source-key duplicates = **0**;
- missing/orphan/multiple memberships = **0 / 0 / 0**;
- provenance gaps = **0**.

### Identity

- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- source strong conflicts = **111**;
- target collisions = **1,740**;
- unsafe MATCH = **0**;
- Identity Coverage = **3.40%**.

### Governed enrichment / Apply

- previews = **455 across 202 patients**;
- APPLY_ALLOWED / POLICY_BLOCKED = **229 / 226**;
- applied = **229 / 229 allowed**;
- active events = **229**;
- exact rolled-back mandatory canary = **1 / 1**;
- governance/policy violations = **0**;
- active events outside allowlist = **0**.

### Protected domains

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 facts = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 reconciliation = **162** / `5524a2280442224ec4e9a7cfdfffa008`.

### Historical JOIN / F3 / F4

- bridge = **1,299 / 1,299 sales**;
- sale identity MATCH / REVIEW / UNRESOLVED = **208 / 940 / 151**;
- Historical JOIN semantic fp = `5af139243f6aed37020048af292587fe`;
- F3 RESOLVED / REVIEW_REQUIRED / EXCLUDED / MISSING / NOT_APPLICABLE = **397 / 3 / 6 / 0 / 893**;
- F3 Product Coverage = **97.78%**;
- F4 linked / no reconciliation evidence = **123 / 1,176**;
- F4 Financial Evidence Coverage = **9.47%**;
- payment evidence rows surfaced through bridge = **0**;
- confirmed balance evidence rows surfaced through bridge = **0**.

F4's low coverage is a **HIGH coverage gap**, not proof of non-payment.

### Historical transaction boundary

- patient history 2024 / 2025 / 2026 = **AVAILABLE / AVAILABLE / AVAILABLE**;
- transactional sales 2024 = **NO CERTIFIED SOURCE**;
- transactional sales 2025 = **NO CERTIFIED SOURCE**;
- transactional sales 2026 = **AVAILABLE only for 2026-01-05 → 2026-08-15**;
- F5.8 evidence fp = `4ce1695532a57655179558ed2b5f78aa`;
- F5.9 Coverage & DQ fp = `5070c701d216eb839572bd70f530c2e6`;
- F5.10 final state fp = `2f0a365fae4caaa7be9d204e0f76679b`.

**NO CERTIFIED SOURCE ≠ zero sales/revenue.** Unsupported 2024↔2025↔2026 YoY/revenue remains prohibited.

## Safety invariants carried into REV-F6

- no patient merge by name alone;
- phone alone does not authorize identity;
- strong identity contradiction or collision blocks MATCH;
- no overwrite of populated canonical fields outside explicit governed contracts;
- identity anchors and blocked/clinical/free-text fields stay outside automatic commercial enrichment;
- `Último presupuesto` is evidence only, never sale/payment/debt truth;
- `ADELANTO` is payment evidence only, never automatic balance/debt;
- F3 owns product truth;
- F4 owns payment/revenue/cartera truth;
- F5 owns patient identity/provenance;
- missing coverage is represented explicitly, never converted to zero;
- every future CURRENT rebaseline must compare persisted LIVE state, not execution narratives.

## Workstream handoff

`REV-F5-CLOSEOUT` is released only when the F5.10 certification PR has exact-head CI SUCCESS, merges without drift, and post-merge GitHub + LIVE + Notion readback all pass.

After that exact condition is met:

- `REV-F5 = PRODUCTION CERTIFIED — 100%`;
- `REV-F6 = UNBLOCKED / NEXT / NOT STARTED`;
- a new HIGH/CRITICAL mutable workstream may be assigned under the one-lock-at-a-time rule.
