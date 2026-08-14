# KronIA K1 — Real Staging & Release Gate — 2026-08-14

**Phase:** K1 — Identity, Session & Secrets Hardening  
**Risk:** CRITICAL  
**Branch:** `security/kronia-k1-hardening-20260814`  
**PR:** #81 (draft until all gates below are complete)  
**Production authorization:** NOT GRANTED

## 1. Purpose

This document defines the evidence required to promote K1 from isolated-CI certification to real staging certification and, only after explicit owner authorization, production release.

Isolated CI is necessary but not sufficient for a CRITICAL identity/security change. The staging runtime, database, secret boundary and consumer flows must reproduce the deployable architecture.

## 2. Environment topology

### Database
Create a Supabase development/staging branch from production only after:
1. owner selects the Supabase organization;
2. current branch cost is obtained;
3. owner explicitly approves that cost;
4. the returned cost confirmation token is used to create the branch.

No production SQL is applied to obtain staging evidence.

### Runtime
Deploy the K1 GitHub branch to a non-production Railway environment/service. The runtime contract is:

```text
Railway Root Directory: app/
build: python3 k1_materialize_runtime.py && npm install
start: node server.js
```

The build must emit `k1-runtime-manifest.json`. The manifest SHA-256 values must match the manifest produced by the K1 GitHub security certificate for the same commit.

## 3. Required server-side environment variables

Values MUST be provisioned in the staging environment/secret manager. Values MUST NOT be pasted into GitHub, Notion, logs, CI artifacts or ChatGPT.

Required K1 boundary variables:
- `SUPABASE_SERVICE_ROLE_KEY`
- `GROQ_API_KEY`
- `GEMINI_API_KEY`
- `RESEND_API_KEY`
- `ASCENDA_VERIFY_TOKEN`
- `TURNSTILE_SECRET_KEY`

Any additional provider variable already used by the deployed runtime remains environment-owned and must follow the same rule.

Before production release, credentials historically present in source or browser-readable integration storage must be rotated and prior values proven invalid.

## 4. Database staging sequence

Apply in order:
1. `20260814051500_kronia_k1_identity_session_hardening.sql`
2. `20260814051600_kronia_k1_extension_claim.sql`
3. `20260814051700_kronia_k1_integration_admin_gateway.sql`
4. `20260814051800_kronia_k1_canonical_closure.sql`

Then verify:
- K1 functions compile;
- raw auth primitives are not executable by `anon`/`authenticated`;
- raw KronIA mutation/search RPCs in K1 scope are not browser-executable;
- `aos_kronia_tokens` cannot be read/mutated by browser roles;
- integration secret columns cannot be read by browser roles;
- identity source cannot be mutated by browser roles;
- authoritative KronIA action/security audit cannot be rewritten by browser roles;
- active session role is re-derived after role change;
- deactivation invalidates an existing session;
- replay of consumed 2FA is rejected.

## 5. Required staging smoke / E2E matrix

### A. Web login / 2FA
- valid user without 2FA obtains opaque session;
- valid 2FA user receives code through server delivery, not browser payload;
- wrong password denied;
- wrong/expired/replayed code denied;
- no raw code, credential hash or integration secret appears in browser/network response;
- session token is present only in expected client storage and stored as digest in DB.

### B. Main ASCENDA chat
- text message succeeds with Bearer session;
- request without Bearer returns 401;
- forged `usuario`, `rol` or `sede` in body cannot change effective identity;
- authorized read/query returns expected business result.

### C. Brain / Brime
- shared KroniaCore restores the same session model;
- text continuity works;
- current non-realtime voice path transcribes with Bearer auth;
- no legacy identity headers are accepted as authority.

### D. Chrome extension
- username + password challenge succeeds;
- password is never persisted in `chrome.storage`;
- 2FA flow succeeds once and rejects replay;
- extension chat uses opaque Bearer session;
- logout revokes/clears session.

### E. Native Sales editor
- authorized edit reaches `aos_kronia_tool` → `aos_editar_venta`;
- browser cannot execute raw `aos_editar_venta` directly;
- effective actor/role match server-derived identity;
- unauthorized role/action denied;
- audit row records the operation.

### F. Integrations admin
- metadata list loads without secret fields;
- secret/config/webhook credential columns remain inaccessible;
- advisor cannot disable an integration;
- ADMIN can execute the narrow disable gateway;
- action is audited;
- use a disposable/non-production staging integration fixture only.

### G. Agent control API
For `/api/agents/run`, `/api/agents/tick`, `/api/agents/status`, `/api/agents/chat`, `/api/agents/costs` as applicable:
- no token → denied;
- invalid token → denied;
- advisor token → denied for admin control;
- valid ADMIN token → permitted only within the endpoint's existing business contract.

### H. Secret regression
- no provider API secret returned to browser;
- no known provider/API secret printed in staging logs;
- no hardcoded fallback accepted by the materialized runtime;
- environment variable absence fails closed for privileged/provider paths.

## 6. Reconciliation evidence

Record:
- Git commit SHA;
- PR number;
- Supabase staging branch/project reference;
- applied migration versions;
- runtime manifest SHA-256 map;
- test identities/fixtures used (never credentials);
- smoke/E2E pass/fail matrix;
- negative-auth evidence;
- audit rows generated by test operations;
- error/log review;
- secret-rotation verification status.

## 7. Rollback staging test

Execute `supabase/rollbacks/20260814_kronia_k1_rollback.sql` on staging only and verify:
- K1-only gateways removed;
- K1 sessions invalidated;
- legacy auth/RPC compatibility restored according to the pre-K1 baseline;
- application can return to the pre-K1 deployment commit;
- re-login is required after rollback;
- no data corruption occurs in business tables.

After successful rollback test, rebuild the staging branch or re-apply K1 and repeat a reduced smoke to prove forward recovery.

## 8. Final security review gate

Before production authorization:
- review final PR diff/materializer/deploy contract;
- confirm no HIGH/CRITICAL finding remains open in K1 scope;
- confirm `PUBLIC` privilege paths, RLS, SECURITY DEFINER search paths and server endpoints;
- confirm secrets are rotated and no historical value remains valid;
- confirm production environment has required variables before DB privilege revocation could affect live consumers.

## 9. Production release gate

K1 may move from `En curso` to `Ready for release` only when all sections above have evidence.

Production steps require explicit owner authorization and must be ordered to avoid lockout:
1. snapshot/backup and rollback readiness;
2. confirm runtime environment variables;
3. deploy compatible server/runtime if required by the release sequence;
4. apply DB migrations in the approved order;
5. immediate negative-auth + compatibility smoke;
6. reconcile audit/session state;
7. observe errors/latency;
8. merge/finalize only after production verification.

If a blocking regression is detected, execute the documented rollback rather than manually reopening individual privileges.

## 10. Current status

- Isolated K1 security certificate: GREEN on run `31775262556`.
- Exact Railway materializer equivalence: being re-certified on the current K1 head.
- Real Supabase staging: NOT CREATED; organization/cost approval required first.
- Production: UNCHANGED.
