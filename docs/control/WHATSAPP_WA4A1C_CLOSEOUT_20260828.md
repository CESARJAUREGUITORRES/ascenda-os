# WA-4A.1C — Treatment & Pricing Architecture — Closeout

**Date:** 2026-08-28 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Phase:** `WA-4A.1C — Treatment & Pricing Architecture`

## Result

`WA-4A.1C = TEST CERTIFIED / PROD-READY / PROD-PROMOTION PENDING`

The phase is closed at the demonstrated TEST-first boundary. No production feature DDL was applied and no Node/browser runtime was changed.

## Exact-head chain

- baseline `main`: `510d66bd4b63b1c26b457c0d80e2ca5b960465c7`;
- PR: `#385`;
- certified exact head: `8354b65c5eaab022f7e4991e15ee48111205c799`;
- dedicated Zero-Cost / DB / lint / rollback run: `33140086173` = `SUCCESS`;
- Ascenda CI run: `33140086255` = `SUCCESS`;
- expected-head merge: `99a2413a7fb13e5e18ec8f4b5e3ed0b49d159880`.

## Contract correction included before certification

The final head reconciles WA-4A.1C with the certified WA-4A.1B schema:

- consumes `mapping_confidence` rather than nonexistent `confidence`;
- preserves WA-4A.1B internal entity semantics `SERVICE|PRODUCT`;
- exposes canonical catalog `SERVICIO|PRODUCTO` where pricing/role validation needs runtime catalog type;
- does not mutate WA-4A.1B schema or source data.

## Exact-head certification gates

The dedicated run completed:

1. Zero-Cost/static governance = SUCCESS;
2. WA knowledge regressions = SUCCESS;
3. isolated Supabase bootstrap = SUCCESS;
4. certified WA knowledge baseline build = SUCCESS;
5. WA-4A.1C fixture + migration = SUCCESS;
6. DB lint = SUCCESS;
7. treatment/pricing contract tests = SUCCESS;
8. rollback = SUCCESS;
9. canonical catalog/toppings preserved after rollback = SUCCESS;
10. WA-4A.1B preserved after rollback = SUCCESS.

## Certified architecture

- `aos_wa4_process_role_policy_v1`: 8 explicit roles; no role auto-assignable;
- `aos_wa4_process_templates_v1`: 8 approved structural templates, all `STRUCTURAL_NOT_PRESCRIPTIVE`;
- `aos_wa4_price_authority_v1`: read-only current catalog price model;
- `aos_wa4_topping_authority_v1`: paid add-on vs zero-price-benefit semantics;
- `aos_wa4_process_entity_context_v1`: joins certified WA-4A.1B mapping with catalog runtime type and current-price state;
- `aos_wa4_price_fingerprint_v1()`: price evidence fingerprint;
- `aos_wa4_quote_preview_v1(...)`: private read-only quote preview.

The isolated TEST contract proves 217/217 active catalog entities are covered by process/pricing context.

## Safety properties proved

- no patient/lead/sales/REV mutation;
- no catalog/topping price mutation;
- no quote/payment/patient-plan mutation;
- no second price/quote/payment/patient-plan master;
- no document/example price promoted to runtime authority;
- anomalous/stale prices fail closed;
- COMPLETE vs PROGRESSIVE payment presentation preserves canonical total/scope;
- toppings are candidates only and are never silently added;
- required-plan roles require authorized-plan evidence;
- end-user roles do not receive direct access to private 1C price/process objects;
- no Copilot send, AI send, auto-reply or auto-routing activation.

## Post-merge production readback

After merge `99a2413a...`, production remained intentionally unchanged:

- active services = `167`;
- active products = `50`;
- active toppings = `20`;
- rows with `precio_oferta > precio_base` = `7`;
- price fingerprint = `4f2bdff1a36dc1c621c237a8da655155`;
- `aos_wa4_process_templates_v1` = absent;
- `aos_wa4_process_role_policy_v1` = absent;
- `aos_wa4_price_authority_v1` = absent;
- `aos_wa4_topping_authority_v1` = absent;
- `aos_wa4_process_entity_context_v1` = absent;
- `aos_wa4_quote_preview_v1(...)` = absent;
- `aos_wa4_price_fingerprint_v1()` = absent.

This proves merge did not silently promote feature DDL.

## Railway applicability

No Railway runtime certification is required for this phase closeout because PR #385 changes only migration/rollback, CI fixture/tests/workflow and control documentation. It does not alter Node/browser runtime files.

## Remaining production debt

WA-4A.1C DDL is queued as PROD-ready and must only be promoted under the later controlled PROD promotion/recovery loop. Promotion requires revalidation of CURRENT main, schema drift, price fingerprint, ACL, readback and rollback plan before applying.

The seven current offer-above-base rows remain explicit business-data review debt; WA-4A.1C does not rewrite them.

## Handoff

The sole mutable HIGH/CRITICAL lock advances to:

`WA-4B — SALES PLAYBOOK ENGINE`

WA-4B must reuse Knowledge Fabric, WA-4A.1B commercial semantics and WA-4A.1C process/pricing contracts. It must not create a second commercial-knowledge, price, quote, patient-plan or customer master.

The playbook engine is advisor-assistive: recommendation/draft/orchestration only. `send_authority = HUMAN_ONLY`; `ai_send=false`, `auto_reply=false`, `auto_routing=false` remain invariants.
