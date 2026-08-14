# KronIA K1 — Execution Checkpoint — 2026-08-14

**Phase:** K1 — Identity, Session & Secrets Hardening  
**Risk:** CRITICAL  
**Branch:** `security/kronia-k1-hardening-20260814`  
**Production baseline:** `0747d8c26ef0c467f9667ac6240df09457e75a6c`  
**Draft PR:** `#81`  
**Production changes:** none

## Objective

Close the legacy KronIA trust boundary without breaking current consumers: identity and role must be authoritative server-side, privileged RPCs must not be directly browser-callable, session material and integration secrets must not be browser-readable, agent control routes must be authenticated, and the security audit boundary must be trustworthy.

## Consumer matrix decisions

- `app/public/kronia-core.js`: shared web/Brain client. K1 moves authority to an opaque Bearer token; browser user/role/sede remain UI context only.
- `app/public/app.html`: discovered during K1 as an independent embedded KronIA transport. K1 compatibility requires Bearer-only text and Whisper and rejects browser identity/role claims.
- `chrome-extension/`: legacy auth contract is incompatible with the live `aos_login_v2(text,text)` signature. K1 repairs it through server-side login/2FA; password is transient and not persisted.
- `app/public/admin-sales.html`: consumes `aos_editar_venta`; the native editor therefore moves to the same token-bound gateway before the raw RPC is revoked.
- `app/public/admin-config.html`: after K1 receives integration metadata only; administrative deactivation uses a narrow token-bound ADMIN gateway.
- `app/server.js`: K1 deploy materialization replaces the legacy body-authority/provider-secret boundary with server-authoritative Bearer/session/env behavior before Node starts.
- `/api/agents/*`: control endpoints require authoritative ADMIN identity in K1.

## New findings discovered during execution

### K1-F13 — Browser-visible 2FA material
The legacy web login calls `aos_login_v2` directly and receives generated 2FA material in the browser before delivery.

**K1 target:** raw login/2FA primitives server-only; server delivers the code and returns sanitized state plus an opaque session.

### K1-F14 — Chrome extension login contract drift
The extension called a historical authentication contract inconsistent with the live `aos_login_v2(text,text)` signature.

**K1 target:** Chrome uses the same server-side authentication contract and opaque session model as web; password remains transient.

### K1-F15 — No real Supabase staging branch currently available
Supabase exposes only the default production branch in the current project inventory.

**K1 target:** create a real development/staging branch after organization selection and cost authorization, then run migrations/smoke/rollback there.

### K1-F16 — Embedded main chat bypassed shared KronIA transport
`app/public/app.html` maintained an independent chat/Whisper transport using browser identity/role claims and legacy headers.

**K1 target:** same opaque Bearer boundary as shared KroniaCore; compatibility contract explicitly covers this consumer.

## K1 implementation artifacts

### Database
- `supabase/migrations/20260814051500_kronia_k1_identity_session_hardening.sql`
- `supabase/migrations/20260814051600_kronia_k1_extension_claim.sql`
- `supabase/migrations/20260814051700_kronia_k1_integration_admin_gateway.sql`
- `supabase/migrations/20260814051800_kronia_k1_canonical_closure.sql`
- `supabase/rollbacks/20260814_kronia_k1_rollback.sql`

### Runtime / deploy
- `app/k1_runtime_base.py` — vendored blob of the certified K1 transformation base.
- `app/k1_materialize_runtime.py` — app-local materializer executed by CI and Railway.
- `app/railway.json` — build runs `python3 k1_materialize_runtime.py` before `node server.js`.
- `app/nixpacks.toml` — explicitly includes Python provider and normal npm install phase.
- Chrome K1 auth files are versioned directly in `chrome-extension/`.

### Tests / evidence
- `ci/kronia-k1/schema_contract.sql`
- `ci/kronia-k1/auth_primitives.sql`
- `ci/kronia-k1/test_k1.sql`
- `ci/kronia-k1/test_k1_extended.sql`
- `ci/kronia-k1/test_rollback.sql`
- `ci/kronia-k1/check_runtime_contract.py`
- `ci/kronia-k1/check_compat_contract.py`
- `.github/workflows/kronia-k1-security.yml`

## Isolated security certificate — GREEN

### Initial full certificate
Workflow: `KronIA K1 Security Certificate`  
Run: `31775262556`  
Conclusion: **SUCCESS**

### Exact Railway artifact certificate
Workflow: `KronIA K1 Security Certificate`  
Run: `31775893376`  
Conclusion: **SUCCESS**

This second certificate uses the exact app-local materializer configured for Railway and compiles all four canonical K1 migrations.

Evidence artifact:
- artifact id: `9209862703`
- artifact digest: `sha256:0edabc72789ea905b95886242791b824045c1a4f3d4e9004ba6a1d95fb56ba5d`
- contains K1 security certificate + generated runtime manifest.

Passed gates:
1. exact Railway K1 runtime materialization;
2. runtime syntax preflight;
3. consumer compatibility preflight;
4. Railway deployment contract including explicit Python provider;
5. isolated production-shaped Supabase startup;
6. exact compilation of all four K1 migrations;
7. main positive/negative authorization assertions;
8. extended auth/integration authorization assertions;
9. database lint;
10. executable rollback and rollback certificate;
11. runtime syntax gate;
12. static no-legacy-authority/compatibility contracts;
13. secret-source regression gate;
14. evidence artifact upload.

## Red → green corrections that remain part of the evidence

1. `pgcrypto` namespace was resolved safely without reopening `public` search path.
2. production auth signatures were modeled in isolated staging rather than skipping revocation tests.
3. Chrome compatibility claim explicitly revokes `PUBLIC`, `anon` and `authenticated`.
4. Studio provider transformation was narrowed after syntax preflight detected an over-broad replacement.
5. Chrome popup was aligned to its real DOM/contract.
6. main `app.html` text/voice transport was added to compatibility gates after late discovery.
7. CI and Railway now execute the same app-local materializer; deployment-artifact divergence is closed.
8. Nixpacks explicitly provisions Python for the materializer and avoids duplicate `npm install`.

## Closed release blocker

### Exact deploy artifact equivalence — CLOSED IN ISOLATED CI
The exact materializer Railway is configured to run is the materializer certified in run `31775893376`. It generates a SHA-256 runtime manifest during build. This resolves the previous CI-only-runtime divergence.

This does not claim that a real Railway staging deployment has already occurred.

## Release blockers still open

1. **Real Supabase staging:** no development/staging branch exists yet. Organization selection + branch cost authorization are required before creation.
2. **Real runtime staging:** deploy the K1 branch in a non-production Railway environment against the staging DB and compare its emitted runtime manifest with CI evidence.
3. **Environment boundary:** provision required server-side environment variables in staging/release without placing values in GitHub/chat.
4. **Secret rotation:** rotate credentials historically present in source or browser-readable integration storage and prove previous values invalid.
5. **Real compatibility smoke/E2E:** web login/2FA, Brain, main chat text/voice, Chrome, Sales editor, integration metadata/admin and agent negative-auth.
6. **Staging rollback:** execute and verify the documented rollback against the real staging branch, then prove forward recovery.
7. **Final security review:** no HIGH/CRITICAL finding open in K1 scope.
8. **Explicit production authorization:** mandatory after all evidence above.

See `docs/control/KRONIA_K1_STAGING_RELEASE_GATE_20260814.md` for the exact real-staging matrix.

## Current release position

K1 is **isolated-CI + exact-deploy-contract certified, not real-staging or production certified**. PR #81 remains draft. Production is unchanged.

## Next exact action

Obtain explicit owner selection of the Supabase organization. Then obtain the current branch cost estimate and, only after explicit cost approval, create the K1 staging branch. Apply all four migrations there, provision staging runtime environment, deploy K1 staging, execute the documented smoke/E2E/rollback matrix, perform final security review, and only then request production release authorization.
