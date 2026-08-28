# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Captured:** 2026-08-28 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**WA-4A.1B exact head:** `23ceb7bc8b5b0afb9b077773bd781c079223ef14`  
**WA-4A.1B merge:** `03efd22cdacc61a8c2f1de351afc6315926e4263`  
**WA-4A.1B:** `TEST CERTIFIED / PROD-READY GRAPH / BUSINESS-CONTENT DML READBACK VERIFIED`  
**ACTIVE MUTABLE SUBPHASE:** `WA-4A.1C — Treatment & Pricing Architecture`  
**NEXT BLOCKED:** `WA-4B — Sales Playbook Engine`  
**PROD hold:** Supabase REST/Auth recovery debt + owner-directed TEST-first promotion queue

## Current phase state

- `WA-V2-0 — Baseline & Governance` = CLOSED.
- `WA-3 — Human Operations Multiagent` = OFFLINE CERTIFIED / LIVE recovery debt.
- `WA-3.5 — Revenue Inbox UX` = OFFLINE CERTIFIED 100% / LIVE recovery debt.
- `WA-7A.0` = CLOSED.
- `WA-7A.1` = CLOSED.
- `WA-7A.2` = CLOSED at demonstrated PROD technical boundary.
- `WA-7A.3` = CLOSED at demonstrated PROD technical/runtime boundary.
- `WA-7A.4` = TEST CERTIFIED / PROD-READY / PROD promotion queued.
- `WA-4A` = ACTIVE parent Knowledge Fabric workstream.
- `WA-4A.1` = governed Zi Vital clinic knowledge merged / TEST-first / PROD-ready.
- `WA-4A.1B` = CERTIFIED at stated boundary.
- `WA-4A.1C` = ACTIVE MUTABLE SUBPHASE.
- `WA-4B`, `WA-4C`, `WA-5`, `WA-6`, `WA-7B/C/D`, `WA-8`, `WA-9..14` remain later roadmap.

## Canonical architecture

`channel alias != canonical patient identity != acquisition touchpoint != marketing eligibility != knowledge evidence`.

Canonical patient identity remains REV/F5/F6. WA consumes certified upstream truth; it does not recreate patient, revenue, catalog or acquisition masters.

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.

`ATTRIBUTION EVIDENCE != CONSENT`.

Knowledge authority remains:

`governed source facts + evidence refs > approved derived knowledge > generic LLM knowledge`.

## WA-4A.1B closeout

Purpose: transform the complete 114-page `ARQUITECTURA_COMERCIAL_ZI_VITAL_.pdf` into governed commercial knowledge and map the CURRENT catalog to Zi Vital semantics.

Delivered:

- third authoritative internal source `ZV_COMMERCIAL_ARCH_2026`;
- commercial phases separated from clinical lifecycle;
- approach aliases normalized without duplicate concepts;
- 6 commercial principles;
- client vs internal language dictionary;
- quotation/no-discount/payment/topping/ethical-upsell/continuity rules;
- OWNER_ADMIN KPI/OKR knowledge;
- exact-shape graph for 167 services + 50 products;
- explicit functional/operational exceptions;
- 43 service composition gaps classified as 17 NOT_APPLICABLE + 26 REAL_MISSING_REVIEW;
- 39 Vitaminas formula blocks marked CATEGORY_TEMPLATE_REVIEW;
- 41 Vitaminas/Detox services enriched in PROD business content;
- residual internal-product gaps closed and Prunex claims hardened.

Exact-head gates:

- specialized run `33137921448` = SUCCESS;
- Ascenda CI `33137921445` = SUCCESS;
- graph certification = SUCCESS;
- DB lint = SUCCESS;
- rollback preserving WA-4A.1 = SUCCESS.

PR #383 merged with expected head `23ceb7bc8b5b0afb9b077773bd781c079223ef14` to `03efd22cdacc61a8c2f1de351afc6315926e4263`.

Post-merge PROD readback:

- 167 active services; 167/167 description; 167/167 indications; 167/167 FAQ coverage; 6,926 service FAQs;
- 50 active products; 50/50 description; 50/50 indications; 50/50 FAQ coverage; 480 product FAQs;
- feature graph table/RPC remain absent in PROD under TEST-first hold.

Certification:

`SERVICE + PRODUCT COMMERCIAL KNOWLEDGE GRAPH = COMPLETE` at CURRENT 167 + 50 shape.

Not falsely certified:

`EXACT CLINICAL FORMULA CONTENT = 100%` remains open evidence debt for 26 exact service formulas + 39 per-SKU Vitaminas formulas.

## WA-4A.1C — Treatment & Pricing Architecture — ACTIVE

Goal: turn certified Zi Vital semantics + live catalog pricing into a governed architecture for treatment processes and quotation scenarios without creating rigid packages or duplicating price authority.

Core rules:

- `aos_catalogo_servicios` remains current price authority;
- PDF/example prices never become runtime authority;
- process != package;
- domain/approach/phase/function guide quotation context;
- clinical selection/dose/material/session count remain professional authority;
- no autonomous discounting;
- toppings/benefits must preserve margin and clinical coherence;
- progressive-payment scenarios must not silently alter medical scope;
- products can support continuity but must not be forced as universal add-ons.

Required deliverables:

1. price/source inventory and drift contract;
2. treatment-process component model;
3. F1/F2/F3 quotation architecture;
4. mandatory/optional/alternative/dependent component semantics;
5. session/unit/control/maintenance semantics;
6. topping/benefit eligibility and internal cost boundary;
7. complete-vs-progressive payment scenarios;
8. treatment templates by Zi Vital Domain/Approach without fixed combo lock-in;
9. safety rules for clinical authority and margin/no-discount governance;
10. TEST fixtures, regressions, exact-head CI and PROD-ready package.

`WA-4B — Sales Playbook Engine` remains blocked until WA-4A.1C is certified.

Certificate: `docs/control/WHATSAPP_WA4A1B_ZIVITAL_COMMERCIAL_KNOWLEDGE_CERTIFICATE_20260827.md`.  
Evidence: `docs/control/WHATSAPP_WA4A1B_ZIVITAL_COMMERCIAL_KNOWLEDGE_EVIDENCE.md`.  
Roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.  
Lock: `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.
