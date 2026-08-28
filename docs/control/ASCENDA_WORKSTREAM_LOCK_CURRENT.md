# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-28 America/Lima  
**WA-4A.1B exact head:** `23ceb7bc8b5b0afb9b077773bd781c079223ef14`  
**WA-4A.1B merge:** `03efd22cdacc61a8c2f1de351afc6315926e4263`  
**WA-4A.1B:** `TEST CERTIFIED / PROD-READY GRAPH / BUSINESS-CONTENT DML READBACK VERIFIED`  
**ACTIVE LOCK:** `WA-4A.1C — TREATMENT & PRICING ARCHITECTURE`

## Execution rule
Only one HIGH/CRITICAL mutable workstream at a time. `WA-4A.1C` is the only mutable lane. `WA-4B — Sales Playbook Engine` is BLOCKED until WA-4A.1C closeout, GitHub CURRENT and Notion LAST are complete.

Preserved: REV-F5/F6 production-certified; REV-F7 paused; CIA/Sentinel/KronIA/unrelated work read-only/regression-only unless strict dependency.

## Preserved WA authority
- WA-7A.0: channel continuity.
- WA-7A.1: REV/F5/F6 canonical identity reuse.
- WA-7A.2: channel verification/identifier lineage.
- WA-7A.3: acquisition provenance.
- WA-7A.4: TEST-certified marketing eligibility.
- WA-4A: governed Knowledge Fabric.
- WA-4A.1: role-aware Zi Vital clinic knowledge.
- WA-4A.1B: certified commercial semantics across 167 services + 50 products.

No parallel patient/product/revenue/pricing/customer master may be created.

Mandatory separations:
`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`
`ATTRIBUTION EVIDENCE != CONSENT`
`LIVE PRICE AUTHORITY != DOCUMENT EXAMPLE PRICE`
`COMMERCIAL PHASE != CLINICAL LIFECYCLE`
`PROCESS TEMPLATE != PATIENT-SPECIFIC PRESCRIPTION`

## WA-4A.1B certified boundary
PR #383 exact head `23ceb7bc8b5b0afb9b077773bd781c079223ef14` merged with expected head to `03efd22cdacc61a8c2f1de351afc6315926e4263`.

Gates:
- specialized Zero-Cost `33137921448` = SUCCESS;
- Ascenda CI `33137921445` = SUCCESS;
- DB lint = SUCCESS;
- 217/217 graph certification = SUCCESS;
- WA regressions = SUCCESS;
- rollback preserving WA-4A.1 = SUCCESS.

Certified: `SERVICE + PRODUCT COMMERCIAL KNOWLEDGE GRAPH = COMPLETE` at CURRENT 167 + 50 shape.

PROD business-content readback: 167/167 service descriptions + indications + FAQ coverage (6,926 FAQs); 50/50 product descriptions + indications + FAQ coverage (480 FAQs). Feature graph DDL remains absent in PROD under TEST-first hold.

Explicit clinical evidence debt remains: 26 exact service formulas `REAL_MISSING_REVIEW` + 39 per-SKU Vitaminas formulas `CATEGORY_TEMPLATE_REVIEW`.

## WA-4A.1C allowed scope
Goal: build a governed treatment-process + pricing architecture using live catalog price authority and WA-4A.1B semantic authority.

Allowed:
- inventory live price/session/unit/duration/control/package semantics;
- inventory quote/payment/promotion/topping tables, RPCs and UI;
- read-only price fingerprints/adapters;
- process component roles: REQUIRED_BY_PLAN / OPTIONAL_SUPPORT / ALTERNATIVE / DEPENDENT / CONTROL / MAINTENANCE / PRODUCT_SUPPORT / TOPPING_ELIGIBLE;
- F1/F2/F3 quotation structure;
- complete vs progressive payment scenarios;
- process templates by Domain/Approach without fixed prescriptions;
- private OWNER_ADMIN cost/margin semantics only when evidence exists;
- TEST-only quote math, CI, security, regressions and rollback.

Must not:
- create another live price master;
- copy PDF/example prices into runtime authority;
- mutate prices to satisfy architecture tests;
- infer medical necessity, dose, ml, vial, sessions or intervals without authoritative evidence;
- expose costs/margins to PUBLIC_CLIENT;
- autonomously discount;
- silently remove required scope to fit budget;
- activate AI send, auto-reply, auto-routing, campaigns or bulk send;
- mutate canonical identity or REV.

## WA-4A.1C invariants
- runtime catalog remains price authority;
- missing/stale/conflicting price fails closed;
- process templates are structural, not prescriptions;
- payment scenario is not clinical-scope authority;
- canonical price != commercial benefit;
- topping eligibility requires evidence/coherence/permission;
- products are support candidates, not universal mandatory add-ons;
- one catalog row is not assumed to equal one clinical unit/session;
- TEST-first remains active for feature DDL/runtime changes.

## Lock transition
Only after WA-4A.1C exact-head certification, expected-head merge, GitHub CURRENT and Notion LAST may the mutable lock move to `WA-4B — Sales Playbook Engine`.
