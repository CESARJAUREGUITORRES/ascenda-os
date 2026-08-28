# WA-4A.1B — Zi Vital Commercial Knowledge Graph — Evidence

Date: 2026-08-28 (America/Lima)
Workstream: WHATSAPP-REVENUE-HUB-V2 / WA-4A.1B
Parent: WA-4A.1 Zi Vital Governed Clinic Knowledge

## Purpose
Transform `ARQUITECTURA_COMERCIAL_ZI_VITAL_.pdf` (114 pages, version 2026) into governed, role-aware commercial knowledge and map the CURRENT catalog to Zi Vital semantics without turning document examples into price or clinical authority.

## Third master source
- code: `ZV_COMMERCIAL_ARCH_2026`
- kind: INTERNAL_PDF
- title: Arquitectura Comercial Zi Vital · Versión 2026
- authority: AUTHORITATIVE_INTERNAL for commercial philosophy, language, quotation logic, continuity, training and audit criteria.
- NOT authority for current prices. Runtime catalog remains price authority.
- clinical claims are review-gated; the graph may preserve the commercial intent without promoting unverified physiology as autonomous advice.

## Normalized taxonomies
Two source taxonomies coexist and are explicitly disambiguated:
1. `COMMERCIAL_PHASE`: F1 Preparation/Activation; F2 Personalized Intervention; F3 Accompaniment/Maintenance/Continuity.
2. `CLINICAL_LIFECYCLE`: PREPARE; ACTIVATE; REGENERATE; MAINTAIN.
They are related but are not synonyms.

Approach aliases are preserved without duplicate concepts:
- Skin Signature <- `Skin Quality`
- Harmony Design <- `Harmony Face`
- BioRegen Face <- `Bioregeneración`
- existing aliases Hair Revival / Hair Guard / Contour Sculpt / Volume & Firm remain governed by WA-4A.1.

## Governed commercial knowledge added
- 6 immutable commercial principles.
- public-vs-internal language dictionary.
- medical-plan to commercial-architecture rule.
- quote-the-process rule; current prices remain runtime facts.
- recalculate process / do not subtract pieces rule.
- complete vs progressive payment framing.
- topping/benefit timing and function rule.
- ethical upsell eligibility + emotional sequence.
- products-as-extension-of-treatment rule.
- refund-policy node explicitly marked as requiring legal/T&C alignment before public authority.
- 4 KPI layers and 3 strategic OKRs as OWNER_ADMIN document targets.

## Entity graph
`aos_knowledge_entity_map_v1` maps every active entity to:
- entity type / canonical id / name / category
- domain code(s)
- approach code(s)
- commercial phase code(s)
- clinical lifecycle
- Zi Vital function
- public/advisor positioning
- mapping state + confidence
- composition evidence state
- source/evidence locator.

CURRENT exact-shape test fixture: 167 services + 50 products.

Explicit exceptions prevent false ontology:
- Hiperhidrosis -> `CROSS_DOMAIN_FUNCTIONAL` (functional clinical service; not forced into a branded aesthetic approach).
- Cannula catalog rows -> `CROSS_DOMAIN_OPERATIONAL` (operational/charge rows; non-recommendable).
- Peptonas -> closest BioRegen semantic with source/review boundary.

## Composition evidence classification
The 43 pre-existing empty SERVICE composition fields are not treated uniformly:
- 17 `NOT_APPLICABLE_*`: HIFU 3, Criolipolysis 3, RF Fractional 4, Apparatus 3, Consultation/operational 4.
- 26 `REAL_MISSING_REVIEW`: Mesotherapy 8, Enzymes 6, Exosomes 4, Peelings 4, Gluteal 3, Peptones 1.

Separately, 39 Vitaminas rows contain a shared category-level composition template. They are explicitly classified `CATEGORY_TEMPLATE_REVIEW`, not as verified per-SKU formulas.

This preserves commercial/semantic completeness while refusing false clinical-formulation completeness.

## Governed PROD business-content DML already applied
No DDL/feature migration was applied to PROD. The management-plane business-content patch intentionally updated only canonical catalog content.

### Vitaminas + Detox
Pre-write:
- 41 targeted active services
- 41 missing commercial description
- 41 missing indications
- fingerprint: `875714ee7ef38d4dae02a3d4b6109882`

Post-write:
- 41/41 enriched
- 0 missing commercial description
- 0 missing indications
- 39 Vitaminas explicitly tagged `CATEGORY_TEMPLATE_REVIEW`
- fingerprint: `70a86d8a7203d1d3629031f685334afb`

The patch does NOT rewrite composition or price.

### Internal products
Closed residual commercial gaps for:
- `APLICADOR MULTIZONA CAPILAR`: physical accessory; formula `NOT_APPLICABLE_OPERATIONAL`.
- `LIP BALM ALOE VERA`: aloe vera is only the active explicitly evidenced by the commercial name; full INCI remains pending label/provider evidence.
- `PRUNEX STICK x1/x3`: added indications and hardened public claims to digestive/transit support; systemic “detox/colon cleaning” language is not authoritative.

Post-write catalog content coverage:
- Services: 167/167 commercial description, benefits, indications, contraindications, patient profile and FAQ coverage.
- Service FAQ total: 6,926.
- Products: 50/50 commercial description, benefits, composition/explicit N/A-or-partial evidence, indications and FAQ coverage.
- Product FAQ total: 480.

## Feature / runtime boundary
The WA-4A.1B graph migrations remain TEST-first / PROD-ready only while the current PROD REST/Auth recovery debt exists.
- No `aos_knowledge_entity_map_v1` in PROD yet.
- No `aos_wa4a_entity_context_v1(uuid,text)` in PROD yet.
- No Copilot wiring in this phase.
- no `auto_reply`, `ai_send`, `auto_routing` activation.
- no patient, lead, sale or REV mutation.

## Exact-head certification
Certified PR: #383.
Certified exact head: `23ceb7bc8b5b0afb9b077773bd781c079223ef14`.
Merge SHA: `03efd22cdacc61a8c2f1de351afc6315926e4263`.

Final gates on the certified head:
- `ASCENDA WA-4A.1B Zi Vital Commercial Knowledge` run `33137921448` = SUCCESS.
- `Ascenda CI` run `33137921445` = SUCCESS.
- graph certification = SUCCESS.
- DB lint = SUCCESS.
- rollback-preserves-WA-4A.1 = SUCCESS.
- WA-4A/WA-4A.1 regressions = SUCCESS.

The REDUFAST failure seen on earlier attempts was a stale assertion expecting `CORPORAL`; the governed graph had already normalized domains to `DOMAIN_CORPORAL`. Final test asserts the canonical code and passes.

Post-merge PROD readback:
- active services = 167; 167/167 description; 167/167 indications; 167/167 FAQ coverage; 6,926 FAQs.
- active products = 50; 50/50 description; 50/50 indications; 50/50 FAQ coverage; 480 FAQs.
- PROD graph table = absent.
- PROD graph RPC = absent.

## Certification result
`WA-4A.1B = TEST CERTIFIED / PROD-READY GRAPH / BUSINESS-CONTENT DML READBACK VERIFIED`.

`SERVICE + PRODUCT COMMERCIAL KNOWLEDGE GRAPH = COMPLETE` at the CURRENT 167 + 50 catalog shape.

`PUBLIC/ADVISOR/OWNER semantic structure = COMPLETE` for the scope implemented.

Not certified as complete:
- `EXACT CLINICAL FORMULA CONTENT = 100%` remains false while 26 exact service formulas and 39 per-SKU Vitaminas formulas lack authoritative product/protocol evidence.
- Those are explicit review debt, not silent blanks.

## Next lock
`WA-4A.1C — Treatment & Pricing Architecture` becomes the sole mutable subphase under WA-4A. `WA-4B — Sales Playbook Engine` remains blocked until WA-4A.1C is certified.
