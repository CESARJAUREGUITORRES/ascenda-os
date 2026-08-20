# REV-F5.10 — FINAL CERTIFICATION

**Captured:** 2026-08-19 America/Lima  
**Entry baseline:** `main@4c81992934afdd187628c48b6ee8132b4d248a79`  
**Workstream:** `REV-F5-CLOSEOUT`  
**Contract:** `REV-F5.10_FINAL_CERT_V1`  
**Final LIVE state fingerprint:** `2f0a365fae4caaa7be9d204e0f76679b`  
**Mode:** independent read-only final certification; no new patient/sale/F3/F4/identity/financial mutation.

## Certification rule

This certificate becomes the authoritative REV-F5 production closeout only after its pull request passes exact-head CI, merges without base/head drift, the merged `main` is read back, LIVE invariants still match, and the F5 Notion control page is updated and re-read.

No individual historical certificate, CI transcript, report score, or job log can substitute for this final chain.

## 1. Exact-head + LIVE entry revalidation

GitHub entry baseline was re-read immediately before certification and matched exactly:

`main@4c81992934afdd187628c48b6ee8132b4d248a79`

Supabase LIVE was independently queried. All protected domains matched their certified state:

| Domain | Rows | Fingerprint / semantic fingerprint | Result |
|---|---:|---|---|
| `aos_pacientes` | 7,688 | `eee5a57717937a4f77049b3aebd8c525` | PASS |
| `aos_ventas` | 1,299 | `20104fd91fbf427e39566e7b84d7ec4f` | PASS |
| F3 current product facts | 406 | `e3c8499026d13401c4a733b4da16b6c8` | PASS |
| F4 reconciliation | 162 | `5524a2280442224ec4e9a7cfdfffa008` | PASS |
| F5.7 Historical JOIN | 1,299 / 1,299 sales | `5af139243f6aed37020048af292587fe` | PASS |
| F5.8 historical transaction evidence | — | `4ce1695532a57655179558ed2b5f78aa` | PASS |
| F5.9 Coverage & DQ report | — | `5070c701d216eb839572bd70f530c2e6` | PASS / prior deterministic report contract preserved |

## 2. REV-F5.1 → REV-F5.9 closeout state

### F5.1–F5.2 Source ingestion / staging

- historical source files = **6 / 6**;
- production batch state = **6 / 6 `MATCHED`**;
- source rows expected = **15,498**;
- source rows persisted = **15,498**;
- source-key duplicates = **0**;
- provenance gaps = **0**;
- identity memberships = **15,498 / 15,498**;
- membership orphans = **0**;
- invalid membership multiplicity = **0**.

### F5.3–F5.4 Identity / canonical classification

- identity clusters = **8,716**;
- MATCH = **296**;
- REVIEW = **6,984**;
- NEW = **1,436**;
- source strong conflicts = **111**;
- target collisions = **1,740**;
- unsafe MATCH = **0**.

Safety semantics remain unchanged:

- name alone never authorizes identity;
- phone alone never authorizes identity;
- strong canonical/source contradiction blocks MATCH;
- collision blocks MATCH;
- false-negative / human review is preferred to false-positive merge.

### F5.5–F5.6 Enrichment / governed Apply

- enrichment previews = **455**;
- MATCH patients with preview = **202**;
- APPLY_ALLOWED = **229**;
- POLICY_BLOCKED = **226**;
- policy undefined = **0**;
- applied previews = **229 / 229 allowed**;
- active Apply events = **229**;
- rolled-back events = **1**;
- exact mandatory canary rollback = **1 / 1**;
- active events outside allowlist = **0**;
- applied policy/review/event violations = **0**.

The allowlist remains only `Sexo`, `distrito`, `departamento`, `ciudad`. Identity anchors, DOB, address/occupation and unresolved semantic mappings remain governed/blocked according to the certified policy.

### F5.7 Historical JOIN

- bridge rows = **1,299 / 1,299 sales**;
- distinct bridge sales = **1,299**;
- sale identity MATCH = **208**;
- REVIEW = **940**;
- UNRESOLVED = **151**;
- unsafe sale MATCH = **0**;
- historical-linked sales = **102**;
- F5.7 semantic fingerprint = `5af139243f6aed37020048af292587fe`.

F3 is consumed as product truth and F4 as financial/cartera evidence; F5 does not create parallel truth.

### F5.8 Historical transaction-source boundary

Certified patient-history coverage exists for 2024, 2025 and 2026, but certified transactional sales coverage currently exists only inside the 2026 operational range.

- 2024 transactional sales = **NO CERTIFIED SOURCE**;
- 2025 transactional sales = **NO CERTIFIED SOURCE**;
- 2026 transactional sales = **AVAILABLE 2026-01-05 → 2026-08-15**;
- 2024–2025 canonical sales rows persisted = **0**;
- 2024–2025 reconciled months = **0**;
- F5 patient-history rows 2024–2025 = **13,501 across 4 batches**;
- F5.8 evidence fingerprint = `4ce1695532a57655179558ed2b5f78aa`.

**`NO CERTIFIED SOURCE` is a coverage state, not a statement that business sales were zero.**

`Último presupuesto`, appointments, calls, patient history or `ADELANTO` cannot be promoted to unsupported sales/payment/debt facts.

### F5.9 Coverage & Data Quality

Independent dimensional scores remain:

- Identity Coverage = **3.40%**;
- Canonical Patient DQ completeness index = **51.48%**;
- Sales Linkage Coverage = **16.01%**;
- F3 Product Coverage = **97.78%**;
- F4 Financial Evidence Coverage = **9.47%**;
- Historical Transaction Availability = **33.33%**.

These dimensions must remain separate. No global average may hide critical/financial coverage gaps.

F4 remains a **HIGH coverage gap**, not evidence that unlinked sales are unpaid.

## 3. F3 / F4 final boundary

### F3

- applicable product-sale facts = **406**;
- RESOLVED = **397**;
- REVIEW_REQUIRED = **3**;
- EXCLUDED = **6**;
- MISSING_F3_FACT = **0**;
- NOT_APPLICABLE = **893** over total sales universe;
- duplicate F3 sale facts = **0**;
- F3 orphans = **0**.

### F4

- reconciliation rows = **162**;
- distinct linked sales = **123**;
- sales with F4 evidence = **123 / 1,299 = 9.47%**;
- sales without F4 reconciliation evidence = **1,176**;
- payment evidence rows surfaced through F5.7 = **0**;
- confirmed balance evidence rows surfaced through F5.7 = **0**;
- invalid multi-row sales = **0**;
- F4 orphans = **0**.

No debt/payment inference is permitted from absence of F4 evidence.

## 4. Independent final invariants

A final fail-closed invariant battery, separate from the F5.9 report builder, returned `PASS` and checked:

- exact 6/6 source parity;
- exact 15,498 source rows and memberships;
- zero missing/orphan/multiple memberships;
- exact 8,716 classifications;
- zero unsafe cluster MATCH;
- zero unauthorized Apply;
- Apply event ↔ preview consistency;
- active canonical field equals recorded `after_patch`;
- exact canary rollback retained;
- exact 1,299/1,299 bridge coverage;
- zero bridge orphan and unsafe sale MATCH;
- zero missing applicable F3 facts;
- F3/F4 structural integrity;
- protected-domain row counts and fingerprints;
- F5.7 semantic fingerprint;
- 2024/2025 transaction-coverage boundary.

## 5. Final deterministic fingerprint

The independent terminal state builder `REV-F5.10_FINAL_CERT_V1` includes source/staging, identity, Apply, protected-domain hashes, Historical JOIN, coverage dimensions and historical semantics.

Execution #1:

`2f0a365fae4caaa7be9d204e0f76679b`

Replay #2:

`2f0a365fae4caaa7be9d204e0f76679b`

Result: **DETERMINISTIC FINAL STATE PASS**.

## 6. Production mutation proof

REV-F5.10 performed **zero business-data mutation**. It is a read-only certification phase. Patient, sale, F3 and F4 fingerprints remained unchanged throughout the final loop.

## 7. Final limitations carried forward

REV-F5 production certification means the F5 contracts, provenance, identity safety, enrichment governance, linkage and explicit coverage boundaries are production-certified. It does **not** mean every source record is auto-resolved or that every commercial/financial field is complete.

Certified limitations that F6 must preserve:

1. only **296 / 8,716** historical identity clusters are safe MATCH;
2. only **208 / 1,299** current sales have canonical patient MATCH;
3. F4 financial evidence covers **123 / 1,299 sales**;
4. 2024 and 2025 have **no certified transactional sales source**;
5. unsupported YoY/revenue, budget-as-sale and `ADELANTO`-as-debt inference remain prohibited;
6. blocked identity/clinical/free-text fields remain outside automatic commercial enrichment.

These are explicit coverage constraints, not certification failures.

## 8. Exit gate

When this certificate's PR satisfies exact-head CI, merge, post-merge GitHub readback, post-merge LIVE invariant/fingerprint readback and Notion persistence/readback, the authoritative state becomes:

- **REV-F5.10 — PASS / CERTIFIED**;
- **REV-F5 — PRODUCTION CERTIFIED — 100%**;
- **REV-F5-CLOSEOUT lock — RELEASED**;
- **REV-F6 — UNBLOCKED / NEXT / NOT STARTED**.

F6 must consume the certified F5 facts and coverage states; it must not reinterpret `NO CERTIFIED SOURCE` as zero or create a parallel patient/product/payment truth layer.
