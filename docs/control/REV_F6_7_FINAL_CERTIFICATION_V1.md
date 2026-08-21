# REV-F6.7 — Final Certification / UI / Performance / Acceptance

**Status:** IN PROGRESS  
**Entry main:** `6a240e82b886e372581d59df4d287af52ef2aaec`  
**Owning workstream:** `REV-F6-CLOSEOUT`  
**Risk:** HIGH (final governed UI/read-path cutover)  
**Business truth mutation:** NONE

## Objective

Close REV-F6 against the already-certified F6.0–F6.6 analytical truth by proving the product surface, read path, security, reconciliation and performance are production-safe. REV-F6.7 does not create another revenue/patient/product truth layer and does not start REV-F7.

## Gap found at entry

The certified backend already exposes `REV-F6.4_SALES_INTELLIGENCE_3_V1` with `metric_trust` containing coverage, confidence, freshness and sample size, but `app/public/admin-sales-intelligence.html` still presented the older V2 surface and did not visibly expose those trust fields. F6.7 must close that presentation gap before final certification.

## Cutover contract

- Keep `/api/f4/sales-intelligence-read` as the sole same-origin browser read path.
- Preserve existing admin + 2FA + explicit panel authorization.
- Preserve the legacy `aos_sales_intelligence_gateway` RPC name for the server proxy.
- Move the certified legacy gateway implementation to a browser-closed compatibility/auth base.
- Return a merged V3 + legacy-compatible payload from the governed gateway so existing cards/workflows do not break.
- Keep raw `aos_rev_sales_intelligence_v3` browser-closed.
- Never add a second browser request or direct `.supabase.co` PostgREST read.

## UI acceptance contract

The existing Sales Intelligence product surface is upgraded in place to **Sales Intelligence V3** and must preserve known filters/cards/table while adding truthful display of:

- coverage;
- confidence;
- freshness;
- sample size;
- source status;
- historical source availability.

Required states:

- loading;
- empty/no certified data;
- authorization denied;
- upstream/error;
- responsive desktop/mobile layout.

The UI must explicitly preserve these semantic guards:

- billed revenue is not confirmed collected cash;
- low coverage weakens the claim;
- `NO_CERTIFIED_SOURCE` is not zero;
- acquisition without defendable lineage is not zero conversion.

## Final acceptance gates

1. F6.7 FAST UI/privacy/compatibility test PASS.
2. Existing Sales Intelligence UI contract PASS.
3. Existing Patient Commercial 360 V2 UI contract PASS.
4. Isolated DB compiles F6.0–F6.4 + F6.7 exact migration.
5. Unauthorized gateway request fails closed.
6. Authorized synthetic gateway request preserves legacy response and returns V3 trust metadata.
7. Independent SQL reconciles executive billed amount and transaction count against `aos_ventas`.
8. Monthly aggregation reconciles to the same direct billed total.
9. Five governed gateway calls remain <1000 ms each.
10. Legacy compatibility base is browser-closed; raw V3 remains browser-closed.
11. Idempotent replay PASS.
12. Recovery restores certified F6.4 gateway topology.
13. Exact-head upstream F6.0–F6.6 + Ascenda CI PASS.
14. LIVE preflight proves F3/F4/F5/F6 non-regression before deployment.
15. LIVE F6.7 migration and independent reconciliation PASS.
16. LIVE latency/ACL/privacy/historical-null semantics PASS.
17. No patient/sale/F3/F4/F5 business mutation attributable to F6.7.
18. Final certificate/snapshot + exact-head terminal CI PASS.
19. Merge with `expected_head_sha`, post-merge LIVE reconciliation, then continuity writes last.

Only after every gate passes may REV-F6 be declared:

`REV-F6 — PRODUCTION CERTIFIED — 100%`

Then REV-F7 becomes `NEXT / UNBLOCKED`, but it is not automatically started.
