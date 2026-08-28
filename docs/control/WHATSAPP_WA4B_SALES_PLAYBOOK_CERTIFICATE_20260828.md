# WA-4B — Sales Playbook Engine — Certification

**Date:** 2026-08-28 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Phase:** `WA-4B — Sales Playbook Engine`  
**Exact certified head:** `d5d63515c9ee94bb2458a70f825fabdfd0804697`  
**PR:** `#387`  
**Functional merge:** `e8180b99ba3a77716969f9ea4a7bbf604cb20d6d`

## Certification result

`WA-4B = TEST CERTIFIED / RUNTIME DEPLOYED SAFE-OFF / LIVE COPILOT CANARY PENDING`.

This certificate does **not** claim autonomous AI sales, real advisor canary completion, or production promotion of the Knowledge Fabric/process-pricing feature DDL.

## Necessity gate

`BUILD = YES`  
`NEW COMMERCIAL KNOWLEDGE MASTER = NO`  
`NEW PRICE MASTER = NO`  
`NEW QUOTE MASTER = NO`  
`NEW PATIENT PLAN MASTER = NO`  
`MINIMAL GOVERNED PLAYBOOK ORCHESTRATOR = YES`

WA-4B consumes previously governed authority instead of recreating it:
- WA identity/reachability/eligibility;
- WA-4A Knowledge Fabric;
- WA-4A.1 Zi Vital governed clinic knowledge;
- WA-4A.1B commercial rules/semantics;
- WA-4A.1C structural process + current-price contracts.

## Exact-head gates
All required PR-head workflows completed SUCCESS on `d5d63515...`:

- `33188177283` — ASCENDA WA-4B Sales Playbook Engine;
- `33188177180` — ASCENDA WA-4 AI Sales Router;
- `33188177163` — Ascenda CI;
- `33188177241` — ASCENDA WA-3 V2 Multiagent FAST;
- `33188177177` — ASCENDA WA-3 Boxes Routing Handoff;
- `33188177183` — ASCENDA ASC-PERF Audit 360;
- `33188177665` — ASCENDA Performance Guard CI;
- `33188177230` — ASCENDA PHASE S WA3 Stabilization.

Dedicated WA-4B gate covered:
- Zero-Cost + syntax;
- WA-4B contracts;
- Knowledge/router regressions;
- authority + SAFE-OFF invariants;
- certified upstream contract references.

## Anti-drift and merge
Immediately before merge:
- `main = 95b77e2630cc67fb407276ead48caa42865befd7`;
- PR head = `d5d63515c9ee94bb2458a70f825fabdfd0804697`;
- no base/head drift detected.

PR #387 was merged using `expected_head_sha=d5d63515...`.

Merge result:
`e8180b99ba3a77716969f9ea4a7bbf604cb20d6d`.

## Certified implementation boundary
WA-4B certifies the following design/behavior:

1. **Governed retrieval only**
   - Copilot direct business-authority reads from `aos_catalogo_servicios` / `aos_promociones` were removed from the playbook path.
   - Retrieval uses governed Knowledge Fabric contracts.
   - PUBLIC_CLIENT and ADVISOR_INTERNAL knowledge are separated.

2. **Deterministic sales-stage orchestration**
   - discovery/info/price/payment/promotion/objection/continuity/booking/clinical escalation are handled by explicit playbook logic.
   - required commercial rules are stage-specific.
   - missing governed rule evidence fails closed.

3. **Price authority**
   - money is removed from model-visible catalog context unless the stage is PRICE/PAYMENT;
   - price requires WA-4A.1C `ready_for_quote=true`, `price_state=READY`, non-stale context;
   - missing/stale/anomalous price fails closed;
   - no document/example price becomes authority.

4. **Commercial safety**
   - promotion requires READY promotion evidence;
   - no autonomous discounts;
   - continuity products are candidates only and never auto-added;
   - toppings/products are not universal add-ons;
   - payment framing does not alter clinical scope.

5. **Clinical safety**
   - personalized clinical/adverse-event risk deterministically escalates to `HUMAN_CLINICAL`;
   - playbook does not diagnose, prescribe, clear contraindications, choose dose/ml/vial/session count, or create patient-specific treatment plans.

6. **Send authority**
   - `send_authority=HUMAN_ONLY`;
   - `auto_send=false`;
   - WA-4B does not activate AI send, auto reply or auto routing.

## Railway/runtime verification
Exact merge `e8180b99...` received Railway status:

`SUCCESS — ascenda-os-production.up.railway.app`.

The committed Railway production configuration declares:
- start runtime through Phase S outer chain;
- `healthcheckPath = /health`;
- `healthcheckTimeout = 300`.

Therefore Railway SUCCESS is accepted as the configured deployment health gate for this closeout.

Merge-commit GitHub checks also passed:
- `Runtime baseline = SUCCESS`;
- `Performance architecture guard = SUCCESS`.

## PROD readback / safety after merge
Read-only production verification on Supabase project `ituyqwstonmhnfshnaqz`:

- active services = `167`;
- active products = `50`;
- active toppings = `20`;
- offer-above-base review rows = `7`;
- price fingerprint = `4f2bdff1a36dc1c621c237a8da655155` — unchanged;
- WA-4A.1 knowledge nodes absent in PROD;
- WA-4A.1B entity map absent in PROD;
- WA-4A.1C templates/roles/price authority/process context/quote preview absent in PROD.

WA safety controls:
- `copilot_enabled=false`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`.

Preserved runtime evidence:
- WA messages = `21`;
- WA conversations = `2`;
- WA events = `39`.

No business-data or canonical-identity mutation is attributed to WA-4B.

## Explicit non-certified boundary
The following is **not** certified by WA-4B:

`LIVE authenticated advisor Copilot business canary = NO`.

Reason: the upstream Knowledge Fabric / commercial graph / treatment-pricing contracts remain deliberately unpromoted in PROD and Copilot remains SAFE-OFF. A real Copilot canary without those authorities would either fail closed or require an invalid bypass; no bypass is allowed.

## Handoff
The sole mutable lock advances to:

`WA-4C — AI Sales Copilot Canary`.

WA-4C must reconcile/promote certified upstream dependencies in order, prove Auth/REST/provider/model readiness, and run real advisor canaries while preserving HUMAN_ONLY send authority. `WA-5` remains blocked until WA-4C is formally closed.
