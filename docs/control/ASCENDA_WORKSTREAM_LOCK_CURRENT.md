# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-28 America/Lima  
**WA-4B exact head:** `d5d63515c9ee94bb2458a70f825fabdfd0804697`  
**WA-4B functional merge:** `e8180b99ba3a77716969f9ea4a7bbf604cb20d6d`  
**WA-4B:** `TEST CERTIFIED / RUNTIME DEPLOYED SAFE-OFF / LIVE COPILOT CANARY PENDING`  
**ACTIVE LOCK:** `WA-4C — AI SALES COPILOT CANARY`

## Execution rule
Only one HIGH/CRITICAL mutable workstream at a time. `WA-4C` is the only mutable lane. All other HIGH/CRITICAL workstreams remain read-only/regression-only unless WA-4C has a narrowly documented dependency.

Preserved: REV-F5/F6 production-certified; REV-F7 paused; CIA/Sentinel/KronIA/unrelated work read-only/regression-only unless strict dependency.

## Preserved WA authority
- WA-7A.0: channel continuity.
- WA-7A.1: REV/F5/F6 canonical identity reuse.
- WA-7A.2: channel verification/identifier lineage.
- WA-7A.3: acquisition provenance.
- WA-7A.4: TEST-certified marketing eligibility; PROD promotion pending.
- WA-4A: governed Knowledge Fabric.
- WA-4A.1: role-aware Zi Vital clinic knowledge; PROD promotion pending.
- WA-4A.1B: certified commercial semantics across 167 services + 50 products; feature graph PROD promotion pending.
- WA-4A.1C: certified treatment/process/current-price architecture; feature DDL PROD promotion pending.
- WA-4B: certified advisor-only sales playbook orchestration; runtime deployed SAFE-OFF.

No parallel patient/product/revenue/pricing/customer/clinical/commercial master may be created.

Mandatory separations:
`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`
`ATTRIBUTION EVIDENCE != CONSENT`
`LIVE PRICE AUTHORITY != DOCUMENT EXAMPLE PRICE`
`COMMERCIAL PHASE != CLINICAL LIFECYCLE`
`PROCESS TEMPLATE != PATIENT-SPECIFIC PRESCRIPTION`
`ADVISOR RECOMMENDATION != AUTONOMOUS SEND`
`PLAYBOOK LOGIC != BUSINESS FACT AUTHORITY`
`TEST CERTIFICATION != LIVE CANARY CERTIFICATION`

## WA-4B certified boundary
PR #387 exact head `d5d63515c9ee94bb2458a70f825fabdfd0804697` passed all required exact-head gates before merge.

Exact-head SUCCESS:
- WA-4B dedicated `33188177283`;
- WA-4 AI Sales Router `33188177180`;
- Ascenda CI `33188177163`;
- WA-3 V2 Multiagent FAST `33188177241`;
- WA-3 Boxes Routing Handoff `33188177177`;
- ASC-PERF Audit 360 `33188177183`;
- Performance Guard CI `33188177665`;
- Phase S WA3 Stabilization `33188177230`.

Anti-drift before merge:
- `main = 95b77e2630cc67fb407276ead48caa42865befd7`;
- PR #387 head remained `d5d63515c9ee94bb2458a70f825fabdfd0804697`;
- no base/head drift.

PR #387 merged with `expected_head_sha` to `e8180b99ba3a77716969f9ea4a7bbf604cb20d6d`.

## Certified WA-4B behavior
- deterministic commercial-stage/playbook orchestration;
- Copilot no longer reads `aos_catalogo_servicios` / `aos_promociones` directly as business authority;
- Knowledge Fabric retrieval separates `PUBLIC_CLIENT` from `ADVISOR_INTERNAL`;
- governed commercial rules are required by stage and missing rule evidence fails closed;
- catalog money is stripped from model context unless the stage is PRICE/PAYMENT and WA-4A.1C marks the entity `ready_for_quote` with READY/FRESH price context;
- stale/anomalous/missing price fails closed;
- promotions require READY governed promotion evidence;
- continuity products are candidates only and never auto-added;
- personalized clinical risk deterministically escalates `HUMAN_CLINICAL`;
- playbook output remains advisor-facing with evidence refs;
- `send_authority=HUMAN_ONLY`; `auto_send=false`.

## Post-merge runtime and PROD safety
Railway status for exact merge `e8180b99...` = SUCCESS on `ascenda-os-production.up.railway.app`. `app/railway.json` configures `/health` as deployment healthcheck, so the successful Railway deployment passed the configured runtime deployment gate.

Merge-commit checks:
- Runtime baseline = SUCCESS;
- Performance architecture guard = SUCCESS.

PROD readback after merge:
- active services = 167;
- active products = 50;
- active toppings = 20;
- offer-above-base review rows = 7;
- price fingerprint = `4f2bdff1a36dc1c621c237a8da655155`;
- WA-4A.1 / WA-4A.1B / WA-4A.1C feature objects remain absent in PROD;
- `copilot_enabled=false`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`;
- WA messages = 21; conversations = 2; events = 39.

Therefore the production runtime is SAFE-OFF and no autonomous behavior was activated by WA-4B.

## Certification
`WA-4B — Sales Playbook Engine = TEST CERTIFIED / RUNTIME DEPLOYED SAFE-OFF / LIVE COPILOT CANARY NOT YET CERTIFIED`.

The remaining LIVE boundary is not a code-quality failure: the upstream Knowledge Fabric / commercial graph / process-pricing contracts are still intentionally absent in PROD, and Copilot remains disabled. No bypass is allowed.

## WA-4C — AI Sales Copilot Canary — active lock
Purpose: prove the certified WA-4B playbook through the real authenticated advisor Copilot path under controlled canary conditions.

WA-4C starts discover/recovery-first. The LIVE canary is BLOCKED until its upstream dependencies are deliberately promoted/revalidated in the certified order.

Allowed:
- inventory exact queued WA-4A/4A.1/4A.1B/4A.1C PROD dependencies and promotion order;
- revalidate PROD Auth/REST and provider/model readiness;
- promote only already-certified dependencies through their own migration/readback gates;
- verify least-privilege retrieval and advisor-only audience separation;
- enable a narrowly scoped Copilot canary only after dependencies and controls are proven;
- execute authenticated advisor canaries for INFO, PRICE, PAYMENT, OBJECTION, CONTINUITY and CLINICAL_ESCALATION;
- prove evidence refs, fail-closed behavior, cost/audit logging and HUMAN_ONLY send authority;
- immediately roll SAFE-OFF on any evidence, identity, pricing, clinical or authorization failure.

Must not:
- enable autonomous WhatsApp sending;
- enable auto-reply or auto-routing;
- bypass marketing eligibility/consent;
- fabricate missing knowledge/prices/promotions;
- promote unreviewed migrations out of certified order;
- mutate patient/REV/canonical identity to satisfy canaries;
- call WA-4C LIVE-certified until authenticated real runtime evidence passes.

Next phase after WA-4C remains `WA-5` per roadmap; it stays BLOCKED until WA-4C closeout.
