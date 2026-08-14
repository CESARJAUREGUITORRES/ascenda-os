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
- `app/public/admin-sales.html`: consumes `aos_editar_venta`; therefore the raw RPC cannot be revoked until the editor is migrated to the same token-bound gateway.
- `app/public/admin-config.html`: consumes `aos_integraciones`; after K1 it may receive metadata only, never credentials/config secret material; administrative deactivation uses a narrow token-bound ADMIN gateway.
- `app/server.js`: legacy boundary trusts body role after weak validation and reads provider credentials from integration storage. K1 materializes a server-authoritative runtime boundary before execution.
- `/api/agents/*`: control endpoints require authoritative ADMIN identity in K1.

## New findings discovered during execution

### K1-F13 — Browser-visible 2FA material
The legacy web login calls `aos_login_v2` directly and receives the generated 2FA code and real destination email in the browser before asking Node to send it. The live `aos_login_v2(text,text)` and `aos_verificar_2fa(text,text)` functions are `SECURITY DEFINER` and executable by browser roles in the baseline.

**Resolution target:** make both primitives server-only; server sends the 2FA code and returns only sanitized state plus an opaque KronIA session after verification.

### K1-F14 — Chrome extension login contract drift
The extension calls a legacy login signature that does not exist in the live database. This is compatibility drift, not a behavior that should be preserved.

**Resolution target:** extension uses the same server-side authentication contract as web and receives the same opaque session model.

### K1-F15 — No real Supabase staging branch currently available
Supabase project branching currently exposes only the default `main` branch. The branch record reports a migration failure state while the production project itself is healthy.

**Resolution target:** isolated GitHub/Supabase CI is the current preproduction database gate. A real staging/preview database or an explicitly approved equivalent is mandatory before CRITICAL production release.

### K1-F16 — Embedded main chat bypassed shared KronIA transport
`app/public/app.html` maintained an independent `/api/kronia/chat`/Whisper transport using browser `usuario/rol/sede` and legacy identity headers.

**Resolution target:** same opaque Bearer boundary as shared KroniaCore; compatibility contract now covers this consumer explicitly.

## K1 implementation artifacts

- `supabase/migrations/20260814051500_kronia_k1_identity_session_hardening.sql`
- `supabase/migrations/20260814051600_kronia_k1_extension_claim.sql`
- `supabase/migrations/20260814051700_kronia_k1_integration_admin_gateway.sql`
- `supabase/rollbacks/20260814_kronia_k1_rollback.sql`
- `ci/kronia-k1/schema_contract.sql`
- `ci/kronia-k1/auth_primitives.sql`
- `ci/kronia-k1/test_k1.sql`
- `ci/kronia-k1/test_k1_extended.sql`
- `ci/kronia-k1/test_rollback.sql`
- `ci/kronia-k1/check_runtime_contract.py`
- `ci/kronia-k1/check_compat_contract.py`
- `ci/kronia-k1/apply_runtime_patch.py`
- `ci/kronia-k1/apply_runtime_patch_v2.py`
- `ci/kronia-k1/apply_runtime_patch_v3.py`
- `.github/workflows/kronia-k1-security.yml`

## Isolated security certificate — GREEN

Workflow: `KronIA K1 Security Certificate`  
Run: `31775262556`  
Conclusion: **SUCCESS**

Passed gates:
1. deterministic K1 runtime materialization;
2. runtime syntax preflight;
3. consumer compatibility preflight;
4. isolated production-shaped Supabase startup;
5. K1 migration compilation;
6. 36 main positive/negative authorization assertions;
7. extended auth/integration authorization assertions;
8. database lint;
9. executable rollback and rollback certificate;
10. runtime syntax gate;
11. static no-legacy-authority contract;
12. secret-source regression gate.

Observed corrections during the red→green loop:
1. `pgcrypto` is installed under the `extensions` schema in the live project; K1 explicitly uses `extensions.digest` / `extensions.gen_random_bytes` with empty function `search_path` where materialized.
2. Staging fixtures model the live auth function signatures so revocation is tested rather than skipped.
3. Chrome compatibility claim explicitly revokes `PUBLIC`, `anon` and `authenticated`; only `service_role` retains execution.
4. Studio provider-key transformation was narrowed after syntax preflight detected an over-broad replacement.
5. Chrome popup contract was aligned to its real DOM rather than the historical prototype.
6. Main `app.html` text/voice consumer was added to compatibility gates after late discovery.

## Release blockers still open

- **Canonical deploy artifact:** large changes to `app/server.js`, `app/public/app.html`, `login.html`, `admin-sales.html` and `admin-config.html` are currently materialized deterministically in CI rather than present as canonical source diffs. The runtime certified by CI must become exactly the runtime Railway will execute before release.
- **Real staging:** no development/staging Supabase branch exists yet; creation may have cost and requires owner confirmation.
- **Environment boundary:** required server-side secrets/session keys must exist in staging/release environment without values being placed in GitHub/chat.
- **Secret rotation:** credentials historically present in source or browser-readable integration storage must be rotated and previous values proven invalid.
- **Real compatibility smoke/E2E:** web login, Brain, main chat text/voice, Chrome, Sales editor, integration metadata/admin and agent negative-auth.
- **Final security review:** no HIGH/CRITICAL findings open in K1 scope.
- **Explicit production authorization:** mandatory after staging + smoke + rollback evidence.

## Current release position

K1 is **isolated-CI certified, not production certified**. PR #81 remains draft. No migration, merge or production deploy is authorized by this checkpoint.

## Next exact action

Resolve the real Supabase staging gate and canonical deployment-artifact equivalence. Then deploy K1 to staging with required environment variables, execute compatibility/security smoke tests and rollback, perform final security review, and only then request explicit production release authorization.
