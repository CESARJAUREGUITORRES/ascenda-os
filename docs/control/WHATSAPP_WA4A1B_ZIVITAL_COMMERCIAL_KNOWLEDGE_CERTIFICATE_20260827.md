# WA-4A.1B — Zi Vital Commercial Knowledge Graph — CERTIFICATE

**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Workstream:** `WA-4A.1B`  
**Certified exact head:** `23ceb7bc8b5b0afb9b077773bd781c079223ef14`  
**Merged to main:** `03efd22cdacc61a8c2f1de351afc6315926e4263`  
**PR:** #383  
**Date:** 2026-08-28 America/Lima

## Certified result

`WA-4A.1B = TEST CERTIFIED / PROD-READY GRAPH / BUSINESS-CONTENT DML READBACK VERIFIED`

`SERVICE + PRODUCT COMMERCIAL KNOWLEDGE GRAPH = COMPLETE` at CURRENT catalog shape:

- 167/167 active services mapped to governed Zi Vital semantics;
- 50/50 active products mapped to governed Zi Vital semantics;
- Domain / Approach / Commercial Phase / Clinical Lifecycle / Zi Vital function are explicit;
- 6 commercial principles, role-aware language, quotation/no-discount/payment/topping/upsell/continuity rules, KPI/OKR knowledge are governed;
- third source `ZV_COMMERCIAL_ARCH_2026` registered;
- Skin Quality / Harmony Face / Bioregeneración normalized as aliases, not duplicate approaches;
- exceptions such as hiperhidrosis and cannula operational rows are not forced into false branded approaches.

## Catalog readback

PROD business-content DML is verified:

- services = 167 active;
- 167/167 commercial description;
- 167/167 indications;
- 167/167 FAQ coverage;
- service FAQs = 6,926;
- products = 50 active;
- 50/50 commercial description;
- 50/50 indications;
- 50/50 FAQ coverage;
- product FAQs = 480.

Vitaminas/Detox enrichment:
- 41/41 target services enriched;
- 39 Vitaminas formula blocks remain explicitly `CATEGORY_TEMPLATE_REVIEW` rather than being falsely treated as per-SKU verified formulas.

Composition evidence debt is explicit:
- 17 service gaps = `NOT_APPLICABLE_*`;
- 26 service gaps = `REAL_MISSING_REVIEW`;
- no false formula completion claim is made.

## Exact-head gates

- `ASCENDA WA-4A.1B Zi Vital Commercial Knowledge` run `33137921448` = SUCCESS.
- `Ascenda CI` run `33137921445` = SUCCESS.
- DB lint = SUCCESS.
- 217/217 entity graph certification = SUCCESS.
- WA-4A/WA-4A.1 regressions = SUCCESS.
- rollback preserving WA-4A.1 = SUCCESS.
- Zero-Cost policy = SUCCESS.

## Production boundary

Feature graph migrations remain unapplied to PROD under the current TEST-first hold:

- `aos_knowledge_entity_map_v1` absent in PROD;
- `aos_wa4a_entity_context_v1(uuid,text)` absent in PROD;
- Copilot remains SAFE-OFF;
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- no patient/lead/sales/REV mutation;
- no price mutation from document examples.

Runtime catalog remains the authority for current prices.

## Not certified

`EXACT CLINICAL FORMULA CONTENT = 100%` is NOT certified. 26 exact service formulas and 39 per-SKU Vitaminas formulas still require authoritative protocol/product evidence.

## Next gate

`WA-4A.1C — Treatment & Pricing Architecture` is the next sole mutable subphase. `WA-4B — Sales Playbook Engine` remains blocked until WA-4A.1C is certified.

Evidence: `docs/control/WHATSAPP_WA4A1B_ZIVITAL_COMMERCIAL_KNOWLEDGE_EVIDENCE.md`.
