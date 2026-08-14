# KronIA K1 — Execution Checkpoint — 2026-08-14

**Phase:** K1 — Identity, Session & Secrets Hardening  
**Risk:** CRITICAL  
**Branch:** `security/kronia-k1-hardening-20260814`  
**Draft PR:** `#81`  
**Production changes:** none  
**Validation policy:** `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`

## Objective

Close the legacy KronIA trust boundary without breaking current consumers: identity and role must be authoritative server-side, privileged RPCs must not be directly browser-callable, session material and integration secrets must not be browser-readable, agent control routes must be authenticated, and the security audit boundary must be trustworthy.

## Consumer matrix

- `app/public/kronia-core.js`: shared web/Brain client; authority moves to opaque Bearer session.
- `app/public/app.html`: embedded chat/Whisper consumer; K1 removes browser authority claims and legacy identity headers.
- `chrome-extension/`: uses server-side login/2FA + opaque Bearer; password remains transient and is not persisted.
- `app/public/admin-sales.html`: native editor migrates from raw `aos_editar_venta` to token-bound `aos_kronia_tool`.
- `app/public/admin-config.html`: browser receives integration metadata only; ADMIN deactivation uses narrow gateway.
- `app/server.js`: identity/session is server-authoritative; provider secrets become environment-owned; `/api/agents/*` requires authoritative ADMIN identity.

## Findings discovered during K1

### K1-F13 — Browser-visible 2FA material
Legacy login exposed generated 2FA material to the browser before delivery.

**Resolution:** raw login/2FA primitives become server-only; server sends the code and returns sanitized state + opaque session.

### K1-F14 — Chrome auth contract drift
Chrome used an obsolete auth contract inconsistent with live `aos_login_v2(text,text)`.

**Resolution:** Chrome now shares the same server auth/session boundary as web.

### K1-F15 — Staging terminology/cost ambiguity
Supabase project inventory contains only production `main`; prior ASCENDA workstreams have primarily used GitHub `staging` + Zero-Cost Staging, not paid Supabase development branches.

**Resolution:** ASCENDA adopted `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`. Supabase Cloud Development Branch is exceptional, not mandatory.

### K1-F16 — Main chat bypassed shared KronIA transport
`app/public/app.html` used its own body/header identity transport.

**Resolution:** same opaque Bearer boundary as KroniaCore; compatibility gate covers it explicitly.

### K1-F17 — Zero-Cost fixture auth return-type drift
The generic/K1 fixture modeled `aos_login_v2` / `aos_verificar_2fa` as `jsonb`; live production returns `json`, causing the generic Zero-Cost workflow to fail when compiling the historical 2FA canary migration.

**Resolution:** fixture signatures now mirror live production exactly (`json`). This removed the false red without modifying release migrations.

## K1 implementation artifacts

### Database
- `supabase/migrations/20260814051500_kronia_k1_identity_session_hardening.sql`
- `supabase/migrations/20260814051600_kronia_k1_extension_claim.sql`
- `supabase/migrations/20260814051700_kronia_k1_integration_admin_gateway.sql`
- `supabase/migrations/20260814051800_kronia_k1_canonical_closure.sql`
- `supabase/rollbacks/20260814_kronia_k1_rollback.sql`

### Runtime/deploy
- `app/k1_runtime_base.py`
- `app/k1_materialize_runtime.py`
- `app/railway.json`
- `app/nixpacks.toml`
- versioned Chrome K1 auth files.

### Tests/evidence
- `ci/kronia-k1/schema_contract.sql`
- `ci/kronia-k1/auth_primitives.sql`
- `ci/kronia-k1/test_k1.sql`
- `ci/kronia-k1/test_k1_extended.sql`
- `ci/kronia-k1/test_rollback.sql`
- `ci/kronia-k1/check_runtime_contract.py`
- `ci/kronia-k1/check_compat_contract.py`
- `.github/workflows/kronia-k1-security.yml`
- generic `.github/workflows/zero-cost-staging.yml` compatibility remains green.

## Current Zero-Cost certification — GREEN

Certified head: `a6e5762063b0774f2cc0c384c3fbcf4e05b1c57c`

### Ascenda CI
- Run `31806139117` / #731
- **SUCCESS**

### ASCENDA Zero-Cost Staging
- Run `31806139089` / #82
- **SUCCESS**
- historical 2FA canary migration compiles after production-shaped fixture correction;
- Sales Intelligence chain, lint, fixtures, pgTAP and performance remain green;
- ephemeral Supabase is destroyed after run.

### KronIA K1 Security Certificate
- Run `31806139104` / #44
- **SUCCESS**

Passed K1 gates:
1. exact Railway runtime materialization;
2. runtime syntax preflight;
3. consumer compatibility preflight;
4. Railway/Nixpacks deployment contract;
5. isolated production-shaped Supabase startup;
6. exact compilation of all four K1 migrations;
7. positive/negative authorization tests;
8. extended auth/integration authorization tests;
9. database lint;
10. executable rollback + rollback certificate;
11. runtime syntax gate;
12. static no-legacy-authority/compatibility gates;
13. secret-source regression gate;
14. evidence artifact upload;
15. compatibility with the global ASCENDA Zero-Cost workflow.

## Production read-only preflight — 2026-08-14

No production mutation was performed.

Verified:
- K1 migration versions applied in production: **0**;
- live `aos_login_v2(text,text)` result: `json`;
- live `aos_verificar_2fa(text,text)` result: `json`;
- raw login/2FA remain executable by `anon` / `authenticated` in the pre-K1 baseline;
- raw KronIA mutation RPCs in K1 scope remain executable by browser roles in the pre-K1 baseline;
- `aos_kronia_tokens` still has RLS disabled and browser table privileges in the pre-K1 baseline;
- `aos_integraciones`, `aos_kronia_acciones`, `aos_kronia_conversaciones` and `aos_usuarios` retain broad browser table privileges in the pre-K1 baseline;
- integration rows with non-empty `api_key`: **3 of 49** (values were NOT read);
- eligible ADMIN canary identities: **1**; that identity has 2FA, email and credential available.

Conclusion: production has not drifted past K1; the exact risks being remediated remain present and the rollout can use a single-admin canary.

## Closed blockers

- Paid Supabase development branch: **NOT REQUIRED** under the canonical Zero-Cost standard.
- K1 isolated database certification: **CLOSED**.
- Generic Zero-Cost compatibility: **CLOSED**.
- CI ↔ Railway runtime equivalence: **CLOSED**.
- Production baseline read-only verification: **CLOSED**.
- Canary eligibility: **CLOSED**.

## Remaining gates before PRODUCTION CERTIFIED

1. **Server environment readiness** — required provider/service secrets must exist in the production secret manager/environment before cutover; values must never enter GitHub/chat.
2. **Secret rotation** — historically exposed/provider credentials must be rotated and previous values invalidated. Current inventory confirms 3 integration rows still contain an `api_key` value; values were not read.
3. **Additive/canary rollout** — deploy compatible runtime and exercise the single eligible ADMIN before closing legacy browser privileges.
4. **Real compatibility smoke** — web login/2FA, Brain, main chat text/voice, Chrome, Sales editor, integration metadata/admin and agent negative-auth.
5. **Cutover** — apply DB privilege hardening only after canary passes and runtime environment is ready.
6. **Post-cutover security smoke** — forged role/body identity, raw RPC, missing/invalid/expired/replayed session/2FA paths must fail as designed.
7. **Final security review** — 0 HIGH/CRITICAL findings open within K1 scope.
8. **Explicit production authorization** — mandatory before the first production mutation.

## Certification state

- **ZERO-COST CERTIFIED:** YES ✅
- **CANARY CERTIFIED:** NO — production canary not executed.
- **PRODUCTION CERTIFIED:** NO — production unchanged.
- **K1 100_COMPLETE:** NO until canary/cutover/post-smoke/final security review close.

## Next exact action

Prepare the zero-cost-certified additive/canary release sequence and environment/secret checklist. Do not mutate production until the owner explicitly authorizes the CRITICAL production canary/cutover. After authorization: execute additive runtime → single-ADMIN canary → K1 DB cutover → immediate positive/negative smoke → reconciliation/security review → production certification or rollback.
