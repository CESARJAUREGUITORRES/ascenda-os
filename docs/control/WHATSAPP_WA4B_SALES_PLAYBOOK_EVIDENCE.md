# WA-4B — Sales Playbook Engine — Evidence

**Date:** 2026-08-28 America/Lima  
**Baseline main:** `95b77e2630cc67fb407276ead48caa42865befd7`  
**Parent:** `WA-4A.1C = TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`

## Objective
Build the minimum advisor-assistive orchestration layer that converts governed ASCENDA knowledge + conversation intent + certified process/price context into a structured commercial playbook and a grounded Copilot draft.

WA-4B is not a new business-fact store, CRM, treatment-plan engine, price engine or autonomous sender.

## Necessity gate

`BUILD = YES`  
`NEW COMMERCIAL KNOWLEDGE MASTER = NO`  
`NEW PRODUCT/SERVICE MASTER = NO`  
`NEW PRICE MASTER = NO`  
`NEW QUOTE/PAYMENT MASTER = NO`  
`NEW PATIENT PLAN MASTER = NO`  
`NEW PERSISTENCE LAYER = NO`  
`MINIMAL NODE ORCHESTRATION ENGINE = YES`

Reason: certified upstream already provides the needed authorities.

### WA-4A / WA-4A.1
- governed knowledge retrieval;
- PUBLIC_CLIENT / ADVISOR_INTERNAL audience isolation;
- provenance/evidence refs;
- freshness/conflict/retrieval states;
- generic LLM knowledge is non-authority.

### WA-4A.1B
Existing governed commercial rule nodes:
- `RULE_MEDICAL_PLAN_TO_COMMERCIAL`;
- `RULE_QUOTE_PROCESS`;
- `RULE_RECALCULATE_PROCESS`;
- `RULE_PAYMENT_SCENARIOS`;
- `RULE_TOPPINGS_BENEFITS`;
- `RULE_ETHICAL_UPSELL`;
- `RULE_PRODUCTS_AS_EXTENSION`;
- `POLICY_REFUND_ALIGNMENT`.

### WA-4A.1C
Existing certified TEST contracts provide:
- structural process roles/templates;
- live price authority projection;
- stale/anomaly fail-closed state;
- commercial phase context;
- topping candidate semantics;
- read-only quote preview.

Therefore WA-4B only needs orchestration.

## Discovery finding: old Copilot governance gap
Before WA-4B, `app/wa4-copilot.js` read these operational tables directly:
- `/rest/v1/aos_catalogo_servicios`;
- `/rest/v1/aos_promociones`.

That path bypassed the Knowledge Fabric retrieval contract and could not enforce WA-4A provenance/freshness/conflict semantics or WA-4A.1C price readiness.

WA-4B removes those direct reads from Copilot.

## WA-4B architecture

### `app/wa4-playbook.js`
Pure deterministic engine. It does not call providers or databases and does not persist state.

It classifies conversation stage into:
- `DISCOVERY`;
- `INFO`;
- `PRICE_QUOTE`;
- `PAYMENT`;
- `PROMOTION`;
- `OBJECTION`;
- `CONTINUITY`;
- `BOOKING`;
- `CLINICAL_ESCALATION`.

It maps stages to governed rule codes, verifies that required rule evidence is present and returns a machine-checkable advisor playbook with:
- `status`;
- `commercial_stage`;
- `objective`;
- `recommended_next_action`;
- `advisor_talking_points`;
- `public_safe_knowledge_ids`;
- `objection_strategy`;
- `quote_or_payment_context`;
- `continuity_candidates`;
- `clinical_escalation`;
- `policy_escalation`;
- `evidence_refs`;
- `freshness_state`;
- `send_authority = HUMAN_ONLY`;
- `auto_send = false`.

### Governed retrieval
Copilot now retrieves facts through private `aos_wa4a_knowledge_search_v2`:
- `PUBLIC_CLIENT` bundle for patient-facing facts;
- `ADVISOR_INTERNAL` bundle for playbook policy/rules.

Stage-required commercial rules are retrieved deterministically from `CLINIC_KNOWLEDGE`; missing rule evidence fails closed to `HUMAN_COMMERCIAL`.

### 1C process/price bridge
Catalog candidates are reconciled against `aos_wa4_process_entity_context_v1`.

Price facts are removed from the model-visible PUBLIC_CLIENT bundle by default. Catalog money is re-exposed only when:
1. stage is `PRICE_QUOTE` or `PAYMENT`;
2. matching WA-4A.1C entity context exists;
3. `ready_for_quote=true`;
4. `price_state='READY'`;
5. freshness is not `STALE_REVIEW`.

This prevents an INFO/OBJECTION/other response from accidentally citing a raw catalog price and prevents PRICE intent from falling back to a stale/anomalous/raw price.

### Promotions
Promotion intent requires a READY governed `PROMOTION` knowledge item. If no current promotion evidence is returned, the playbook fails closed; it does not infer a discount or synthesize a campaign.

### Continuity
Products may appear only as `PRODUCT_SUPPORT_CANDIDATE` when 1C context marks them as PRODUCTO, F3 continuity and price-ready. `auto_add=false` is invariant.

### Clinical boundary
Personalized clinical/adverse-event risk is deterministic and returns `HUMAN_CLINICAL` without needing an LLM or commercial evidence. The playbook does not diagnose, prescribe, determine suitability, choose dose/ml/vial or create a patient plan.

## Copilot integration
`app/wa4-copilot.js` now:
- has no direct reads to canonical catalog/promotions;
- builds PUBLIC_CLIENT and ADVISOR_INTERNAL governed bundles;
- builds the deterministic playbook before model invocation;
- does not invoke the model when the playbook is fail-closed/human-required;
- passes only the PUBLIC_CLIENT governed bundle as factual authority to the model;
- passes playbook output as internal strategy;
- validates response citations with `cited_knowledge_ids`;
- validates money/hours against the sanitized public evidence bundle;
- runs the safety model after grounding validation;
- returns the structured playbook alongside any Copilot draft;
- keeps `auto_send=false`.

If Knowledge Fabric is unavailable, the Copilot returns `WA4B_GOVERNED_KNOWLEDGE_UNAVAILABLE` and does not fall back to raw tables or generic model knowledge.

## Runtime boundary
`app/server-wa4.js` only adds the already-existing private `serviceRpc` dependency to Copilot. WA-3 remains conversation ownership/human-send authority. No Meta send path, WhatsApp token, campaign or auto-routing path is added.

## TEST contract coverage
Dedicated tests cover:
- stage classification;
- deterministic clinical escalation;
- governed rule requirement;
- ready 1C price context;
- price anomaly fail-closed;
- promotion evidence required;
- continuity candidate semantics;
- `HUMAN_ONLY` send authority;
- non-price money stripping;
- price-stage money only from 1C-ready context;
- missing 1C context does not fall back to raw catalog;
- static proof that Copilot no longer reads `/aos_catalogo_servicios` or `/aos_promociones` directly.

Existing regressions rerun:
- WA-4A Knowledge Fabric adapter tests;
- WA-4A.1 audience-isolation tests;
- WA-4 AI router tests;
- existing WA-4 full workflow is also triggered by the Copilot/server changes.

## Production and activation boundary
WA-4A/4A.1/4A.1B/4A.1C feature contracts are still not promoted to PROD. Therefore WA-4B runtime must remain fail-closed in production until the controlled upstream promotion loop is executed.

WA-4B does **not** authorize applying those migrations now and does **not** activate Copilot.

Preserved:
- `ai_send=false`;
- `auto_reply=false`;
- `auto_routing=false`;
- `human_send=true`;
- Copilot remains SAFE-OFF unless separately enabled under a later certified activation boundary.

## Certification target
This phase can be certified only as:

`WA-4B = TEST CERTIFIED / PROD-READY CODE / PROD ACTIVATION BLOCKED BY UPSTREAM KNOWLEDGE+1C PROMOTION`

It must not be labeled PROD/LIVE until upstream governed contracts are promoted, runtime deployment is verified, authenticated advisor canaries pass and human-send-only behavior is proven in production.
