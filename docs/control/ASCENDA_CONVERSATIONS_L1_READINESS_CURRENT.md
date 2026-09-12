# ASCENDA CONVERSATIONS — CONV-L1 READINESS CURRENT

**Program:** CONV-001 #502  
**Loop:** CONV-L1 #505  
**State:** IMPLEMENTED · CI CERTIFICATION IN PROGRESS  
**Owner mode:** RUN UNTIL BLOCKED + REAL META TEST limitado a `zi vital`  
**Starting main:** `eefd26d6e2395545cfb944d48260d84602240075`  
**Legacy autonomy:** SAFE-OFF

## Goal

Create one native Meta Cloud provider boundary without introducing Chatwoot/Evolution/n8n or another runtime dependency.

## Implemented slice

### MetaCloudAdapter
`app/meta-cloud-adapter.js`

Owns:
- Meta Graph HTTPS transport for WhatsApp;
- webhook signature verification via current WA gateway contract;
- webhook normalization;
- normalized provider errors;
- text;
- image/audio/video/document media;
- templates;
- interactive messages;
- typing/read marker;
- provider health;
- approved-template read model.

### F4 canonical provider boundary

`server-f4.js` now:
- instantiates MetaCloudAdapter with server-only Meta configuration;
- uses adapter for webhook verification/normalization;
- uses adapter for provider sends and typing;
- exposes server-only internal health/dispatch/template compatibility routes;
- performs a sanitized provider-health read on startup;
- keeps lower/core child free of WhatsApp provider secrets.

### WA3 compatibility

`server-wa3.js` now:
- no longer reads `WHATSAPP_ACCESS_TOKEN` or owns Graph version;
- no longer calls `graph.facebook.com`;
- preserves human-send authorization/idempotency/persistence;
- sends through the internal F4 MetaCloudAdapter boundary;
- proxies provider-health and approved-template reads through that boundary.

This is an extraction step. L2 will later consolidate conversation/ownership/read models; L1 does not rewrite them.

## Provider-boundary invariants

- exactly one WhatsApp Graph HTTPS implementation: `MetaCloudAdapter`;
- no direct Meta provider call from WA3;
- no direct Meta provider call from F4 outside the adapter;
- legacy WA4/L10 still cannot call Meta directly;
- provider errors exposed upstream are sanitized code/category/status only;
- ambiguous provider failures are never declared retry-safe;
- real provider send remains subject to existing human/L4 authority boundaries;
- autonomous authority remains AUTO_OFF during L1.

## CI contracts

Dedicated workflow:
`.github/workflows/conv-l1-meta-gateway.yml`

Required:
- JS syntax;
- MetaCloudAdapter unit suite;
- WA1 secure-gateway regression;
- L1 static architecture contract;
- legacy L10 bridge safety regression;
- Ascenda CI;
- P0-485 stability;
- relevant WA1/WA3/L4 compatibility gates.

## Real-provider gate

Owner has already authorized a bounded real Meta test limited to the existing `zi vital` test scope.

Before any real send:
1. exact L1 merge/deploy SHA must be healthy;
2. startup provider-health must report fresh credential/asset readiness;
3. production autonomy remains AUTO_OFF;
4. exact test conversation/recipient must be resolved server-side; no raw recipient is written to docs/chat;
5. template used must be Meta-approved if template send is tested;
6. no ambiguous prior outbound may be retried without reconciliation.

Test matrix:
- fresh provider health;
- inbound webhook;
- one outbound text;
- one image/media;
- one approved template;
- interactive if current Meta account/template context supports it;
- sent/delivered/read reconciliation;
- idempotency duplicate-negative;
- safe provider-error/invalid-request negative test without generating duplicate traffic.

## Exit

L1 is technically closed only when:
- code/CI exact-head PASS;
- deployed exact SHA PASS;
- fresh provider health PASS;
- bounded real Meta test PASS;
- no duplicate provider sender exists in active WA path;
- production autonomous state remains SAFE-OFF;
- provider/local status reconciles;
- protected ASCENDA DB/runtime health has no material regression.

Then L2 becomes NEXT ELIGIBLE / NOT AUTHORIZED.
