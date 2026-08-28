# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-28 America/Lima  
**WA-7A.0:** CLOSED  
**WA-7A.1:** CLOSED  
**WA-7A.2:** CLOSED AT DEMONSTRATED BOUNDARY  
**WA-7A.3:** CLOSED AT DEMONSTRATED BOUNDARY  
**WA-7A.4:** `TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`  
**WA-4A.1B:** `TEST CERTIFIED / PROD-READY GRAPH / BUSINESS-CONTENT DML READBACK VERIFIED`  
**ACTIVE NEXT:** `WA-4A.1C — TREATMENT & PRICING ARCHITECTURE`  
**BLOCKED NEXT:** `WA-4B — SALES PLAYBOOK ENGINE`  
**PROD recovery debt:** queued TEST-certified promotions remain separated from business-content DML

## North Star

`Meta Ads / Business Username / Organic / QR / Web → WhatsApp → explicit provenance + channel identity → canonical identity → conversation → governed eligibility → knowledge → process/pricing context → human/AI sales playbook → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a governed conversation/channel product, not a CRM replacement.
- Canonical patient identity remains governed by REV/F5/F6.
- Acquisition touchpoints remain separate from channel/person identity.
- Marketing eligibility remains separate from identity/reachability/attribution.
- Knowledge references governed source authority instead of duplicating canonical truth.
- Current price authority remains the runtime catalog, never document examples or generic model knowledge.
- Treatment process architecture must preserve clinical authority and must not create rigid clinical prescriptions.
- `BSUID != ctwa_clid/touchpoint`.
- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.
- `ATTRIBUTION EVIDENCE != CONSENT`.
- TEST certification and PROD promotion remain separate gates under the current hold.

## Phase graph

`WA-V2-0 ✅ → WA-3 ✅ OFFLINE → WA-3.5 ✅ OFFLINE → WA-7A.0 ✅ → WA-7A.1 ✅ → WA-7A.2 ✅ → WA-7A.3 ✅ → WA-7A.4 ✅ TEST/PROD-READY → WA-4A → WA-4A.1 ✅ → WA-4A.1B ✅ → WA-4A.1C ACTIVE → WA-4B BLOCKED → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

## WA-4A.1B — Zi Vital Commercial Knowledge Graph — CERTIFIED

Certified exact head `23ceb7bc8b5b0afb9b077773bd781c079223ef14` merged via PR #383 to `03efd22cdacc61a8c2f1de351afc6315926e4263`.

Certified scope:

- 114-page commercial architecture transformed into governed knowledge;
- third source `ZV_COMMERCIAL_ARCH_2026`;
- commercial phases normalized separately from clinical lifecycle;
- approach aliases normalized;
- commercial principles, dictionary, quotation/no-discount/payment/topping/upsell/continuity rules;
- OWNER_ADMIN KPI/OKR knowledge;
- exact-shape graph for 167 services + 50 products;
- explicit exception semantics;
- 17 composition N/A vs 26 real missing review;
- 39 Vitaminas formula templates explicitly review-gated;
- 41 Vitaminas/Detox services enriched in canonical PROD business content;
- internal product residual gaps closed; Prunex public claims hardened.

Final exact-head gates:

- specialized Zero-Cost run `33137921448` = SUCCESS;
- Ascenda CI run `33137921445` = SUCCESS;
- DB lint, graph certification, WA regressions and rollback = SUCCESS.

Post-merge PROD business-content readback:

- 167/167 active services with description + indications + FAQ coverage; 6,926 service FAQs;
- 50/50 active products with description + indications + FAQ coverage; 480 product FAQs;
- graph feature DDL remains unapplied to PROD under TEST-first hold.

Certification boundary:

`SERVICE + PRODUCT COMMERCIAL KNOWLEDGE GRAPH = COMPLETE` at CURRENT 167 + 50 shape.

Open evidence debt is explicit, not silent:

- 26 exact service formulas;
- 39 per-SKU Vitaminas formulas.

## WA-4A.1C — Treatment & Pricing Architecture — ACTIVE

**Goal:** create a governed treatment-process and quotation architecture that combines live price authority with Zi Vital Domain/Approach/Phase/Function semantics, without turning processes into rigid packages or allowing autonomous clinical/pricing decisions.

### 1C.0 — Revalidate & inventory

- revalidate exact `main`;
- inventory active service/product pricing fields and presentation/session semantics;
- identify current quote/payment/package/topping tables, RPCs and UI;
- identify current discounts/promotions and any duplicate price truth;
- fingerprint current catalog price state.

### 1C.1 — Price authority contract

- `aos_catalogo_servicios` = current service/product price authority unless an already-governed source proves otherwise;
- document examples never override runtime price;
- stale/missing/conflicting prices fail closed;
- no hardcoded price inside playbook knowledge.

### 1C.2 — Process component model

Model components as:

- `REQUIRED_BY_PLAN` — medically/operationally required only when explicitly selected by authorized plan;
- `OPTIONAL_SUPPORT` — useful support, not mandatory;
- `ALTERNATIVE` — mutually substitutable under authorized choice;
- `DEPENDENT` — valid only if another component exists;
- `CONTROL` — follow-up/control;
- `MAINTENANCE` — continuity;
- `PRODUCT_SUPPORT` — approved home/support product;
- `TOPPING_ELIGIBLE` — commercial benefit candidate subject to rules.

The model must never infer clinical necessity from category alone.

### 1C.3 — F1/F2/F3 quotation architecture

- F1 preparation/activation;
- F2 personalized intervention;
- F3 accompaniment/maintenance/continuity;
- support complete-payment and progressive-payment views;
- progressive payment cannot silently remove clinical scope or create hidden debt semantics.

### 1C.4 — Unit/session/control semantics

- distinguish row / session / unit / vial / ml / zone / control / package count;
- no assumption that one catalog row equals one treatment unit;
- price math must use explicit semantics.

### 1C.5 — Toppings / no-discount / margin boundary

- benefit increases value; it does not rewrite canonical base price;
- no autonomous discounting;
- topping eligibility requires commercial + clinical coherence;
- internal cost/margin evidence is private OWNER_ADMIN data;
- no public exposure of cost/margin fields.

### 1C.6 — Process templates

Governed templates by Domain/Approach, not fixed combos:

- Facial / Skin Signature;
- Facial / Harmony Design;
- Facial / BioRegen Face;
- Corporal / Body Reset;
- Corporal / Sculpt Body;
- Corporal / Sculpt Booty;
- Capilar / Activación & Regeneración;
- Capilar / Mantenimiento & Prevención;
- cross-domain support/evaluation where appropriate.

Templates define allowed structure and explanatory logic, not patient-specific medical prescriptions.

### 1C.7 — Safety / evidence / CI

- service-role/private owner boundaries;
- no patient mutation;
- no REV mutation;
- no price mutation during architecture certification;
- no AI send/auto-reply/auto-routing activation;
- exact-head Zero-Cost tests;
- anti-drift + expected-head merge;
- PROD unchanged for feature DDL unless separately promoted.

### 1C exit gate

Only after 1C exact-head certification may the lock move to:

`WA-4B — Sales Playbook Engine`.

## WA-4B — Sales Playbook Engine — BLOCKED CONTRACT

WA-4B will consume, not recreate:

- WA identity/reachability/eligibility;
- governed Knowledge Fabric;
- Zi Vital Domains/Approaches;
- WA-4A.1B commercial principles/language;
- WA-4A.1C treatment/process/pricing context.

Target behaviors after unblock:

- concise client-facing explanations;
- richer advisor/owner copilot explanations;
- intent/objective detection;
- objection handling;
- process explanation before price fragmentation;
- safe quotation scenario support;
- continuity and ethical upsell suggestions;
- human approval first;
- evidence-required business facts;
- clinical escalation where required.

WA-4B does not activate autonomous send; WA-4C remains the later AI Sales Copilot canary.

## Standard TEST-first phase loop

`REVALIDATE CURRENT → DISCOVER → NECESSITY GATE → BUILD MINIMUM IN ISOLATED TEST → CONTRACT/SECURITY/REGRESSION TESTS → EXACT-HEAD ZERO-COST CI → ANTI-DRIFT → MERGE EXPECTED HEAD → VERIFY PROD BOUNDARY → TEST CERTIFICATE / PROD-READY PACKAGE → GitHub CURRENT → Notion LAST → NEXT LOCK`.
