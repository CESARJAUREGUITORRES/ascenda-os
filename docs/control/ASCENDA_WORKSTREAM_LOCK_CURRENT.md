# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-28 America/Lima  
**WA-4A.1C exact head:** `8354b65c5eaab022f7e4991e15ee48111205c799`  
**WA-4A.1C merge:** `99a2413a7fb13e5e18ec8f4b5e3ed0b49d159880`  
**WA-4A.1C:** `TEST CERTIFIED / PROD-READY / PROD FEATURE DDL UNAPPLIED`  
**ACTIVE LOCK:** `WA-4B — SALES PLAYBOOK ENGINE`

## Execution rule
Only one HIGH/CRITICAL mutable workstream at a time. `WA-4B` is now the only mutable lane. All other HIGH/CRITICAL workstreams remain read-only/regression-only unless WA-4B has a narrowly documented dependency.

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
- WA-4A.1C: certified structural treatment/process + current-price read architecture.

No parallel patient/product/revenue/pricing/customer/clinical master may be created.

Mandatory separations:
`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`
`ATTRIBUTION EVIDENCE != CONSENT`
`LIVE PRICE AUTHORITY != DOCUMENT EXAMPLE PRICE`
`COMMERCIAL PHASE != CLINICAL LIFECYCLE`
`PROCESS TEMPLATE != PATIENT-SPECIFIC PRESCRIPTION`
`ADVISOR RECOMMENDATION != AUTONOMOUS SEND`
`PLAYBOOK LOGIC != BUSINESS FACT AUTHORITY`

## WA-4A.1C certified boundary
PR #385 exact head `8354b65c5eaab022f7e4991e15ee48111205c799` merged with `expected_head_sha` to `99a2413a7fb13e5e18ec8f4b5e3ed0b49d159880`.

Exact-head gates:
- dedicated WA-4A.1C Zero-Cost / DB / lint / rollback run `33140086173` = SUCCESS;
- Ascenda CI run `33140086255` = SUCCESS;
- WA knowledge regressions = SUCCESS;
- isolated Supabase baseline + 1C migration = SUCCESS;
- DB lint = SUCCESS;
- quote-preview contract tests = SUCCESS;
- rollback preserving canonical catalog/toppings and WA-4A.1B = SUCCESS.

Certified architecture:
- 8 structural process templates, all `STRUCTURAL_NOT_PRESCRIPTIVE`;
- 8 explicit component roles with `can_auto_assign=false`;
- 217/217 active catalog entities covered by the 1C TEST context;
- live catalog remains price authority;
- toppings distinguish `PAID_ADDON` vs `ZERO_PRICE_BENEFIT_CANDIDATE`;
- COMPLETE vs PROGRESSIVE preserves canonical scope/total;
- stale/anomalous price fails closed;
- quote preview is private/read-only and does not create quote/payment/plan state.

Post-merge PROD readback is unchanged:
- active services = 167;
- active products = 50;
- active toppings = 20;
- offer-above-base review rows = 7;
- price fingerprint = `4f2bdff1a36dc1c621c237a8da655155`;
- all WA-4A.1C feature tables/views/functions remain absent in PROD.

Therefore `WA-4A.1C = TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`. No Railway runtime certification is required for this closeout because #385 changes migration/CI/control artifacts only and does not alter the Node/browser runtime.

## WA-4B necessity gate
Discovery completed before mutation.

Existing governed authorities already contain the commercial rules that a sales playbook needs:
- `RULE_MEDICAL_PLAN_TO_COMMERCIAL`;
- `RULE_QUOTE_PROCESS`;
- `RULE_RECALCULATE_PROCESS`;
- `RULE_PAYMENT_SCENARIOS`;
- `RULE_TOPPINGS_BENEFITS`;
- `RULE_ETHICAL_UPSELL`;
- `RULE_PRODUCTS_AS_EXTENSION`;
- `POLICY_REFUND_ALIGNMENT`;
- governed public/advisor language and Domain / Approach / Commercial Phase semantics;
- WA-4A.1C structural process roles + price/quote-preview contracts.

Decision:
`BUILD = YES`
`NEW COMMERCIAL KNOWLEDGE MASTER = NO`
`NEW PRICE/QUOTE/PATIENT-PLAN MASTER = NO`
`MINIMAL PLAYBOOK ORCHESTRATION ENGINE = YES`

## WA-4B allowed scope
Goal: convert governed facts + commercial rules + conversation context into an evidence-backed **advisor recommendation**, while keeping human send and professional clinical authority intact.

Allowed:
- inventory current WA4 Copilot/router/advisor surfaces and conversation context contracts;
- define deterministic commercial conversation states/stages without creating customer truth;
- resolve applicable governed rule nodes and 1C process context;
- produce structured advisor-only recommendations such as objective, next best action, approved talking points, objection handling, safe CTA, quote/payment framing, continuity opportunity and escalation reason;
- return evidence/source references and confidence/freshness state with every governed recommendation;
- distinguish public-safe text from advisor-only guidance and clinical-restricted content;
- use current catalog price authority only through governed 1C contracts when price context is required;
- add TEST fixtures for discovery, objection, quote, payment scenario, topping, product-continuity, follow-up and clinical-escalation paths;
- keep Copilot as assistive/draft/recommendation mode only;
- CI, least-privilege, hallucination, stale/conflict, role-boundary and rollback tests.

Must not:
- create a second product/service/business-rule/price master;
- copy prices or clinical facts into prompt constants as authority;
- infer diagnosis, medical necessity, dose, ml, vial, treatment selection, contraindication clearance or patient-specific plan;
- mark a component `REQUIRED_BY_PLAN` without authorized plan evidence;
- automatically add toppings/products or manufacture discounts;
- mutate quote/payment/patient-plan/revenue/identity truth merely to make a recommendation;
- expose OWNER_ADMIN/internal economics to PUBLIC_CLIENT;
- send WhatsApp messages autonomously;
- activate `ai_send`, `auto_reply`, `auto_routing`, campaigns or bulk send;
- bypass marketing-eligibility/consent or clinical escalation gates.

## WA-4B output contract direction
A playbook result should be evidence-first and machine-checkable, with fields equivalent to:
- `commercial_stage`;
- `objective`;
- `recommended_next_action`;
- `advisor_talking_points`;
- `public_safe_facts`;
- `objection_strategy`;
- `quote_or_payment_context` when applicable;
- `continuity_candidates` when governed and contextually eligible;
- `clinical_escalation` / `policy_escalation`;
- `evidence_refs`;
- `freshness/conflict state`;
- `send_authority = HUMAN_ONLY`.

This is a contract direction, not permission to invent missing facts or a mandate for a new table. Necessity must be proven for each persistence layer.

## WA-4B invariants
- governed source facts > approved derived knowledge > generic LLM knowledge;
- missing/conflicting/stale business evidence fails closed or escalates;
- commercial playbook may organize a conversation but does not prescribe treatment;
- clinical-restricted content is not converted into patient-facing claims;
- price uses current governed authority, not examples or historical snapshots;
- payment scenario cannot alter clinical scope;
- benefits/toppings are context candidates, never hidden discounts;
- products are continuity candidates, not universal add-ons;
- advisor recommendation is not autonomous send authority;
- Copilot/AI send/auto-reply/auto-routing remain SAFE-OFF throughout WA-4B unless a later separately certified phase explicitly changes that policy.

## Next transition
`WA-4B` may close only after exact-head TEST certification, regressions/security/rollback, expected-head merge, PROD-unchanged readback where applicable, GitHub CURRENT and Notion LAST. The next lock after WA-4B must be taken from the roadmap at closeout; do not infer or start it early.
