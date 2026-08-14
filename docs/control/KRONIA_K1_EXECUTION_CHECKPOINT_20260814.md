# KronIA K1 — Execution Checkpoint — 2026-08-14

**Phase:** K1 — Identity, Session & Secrets Hardening  
**Risk:** CRITICAL  
**Branch:** `security/kronia-k1-hardening-20260814`  
**Production baseline:** `0747d8c26ef0c467f9667ac6240df09457e75a6c`  
**Production changes:** none

## Objective

Close the legacy KronIA trust boundary without breaking current consumers: identity and role must be authoritative server-side, privileged RPCs must not be directly browser-callable, session material and integration secrets must not be browser-readable, agent control routes must be authenticated, and the security audit boundary must be trustworthy.

## Consumer matrix decisions

- `app/public/kronia-core.js`: shared web/Brain client. K1 moves authority to an opaque Bearer token; browser user/role/sede remain UI context only.
- `chrome-extension/`: legacy auth contract is incompatible with the live `aos_login_v2(text,text)` signature. K1 repairs it through server-side login/2FA; password is not persisted.
- `app/public/admin-sales.html`: consumes `aos_editar_venta`; therefore the raw RPC cannot be revoked until the editor is migrated to the same token-bound gateway.
- `app/public/admin-config.html`: consumes `aos_integraciones`; after K1 it may receive metadata only, never credentials/config secret material.
- `app/server.js`: current legacy boundary trusts body role after weak validation and reads provider credentials from integration storage. K1 materializes a server-authoritative runtime boundary before execution.
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

## K1 implementation artifacts

- `supabase/migrations/20260814051500_kronia_k1_identity_session_hardening.sql`
- `supabase/migrations/20260814051600_kronia_k1_extension_claim.sql`
- `ci/kronia-k1/schema_contract.sql`
- `ci/kronia-k1/auth_primitives.sql`
- `ci/kronia-k1/test_k1.sql`
- `ci/kronia-k1/check_runtime_contract.py`
- `ci/kronia-k1/apply_runtime_patch.py`
- `ci/kronia-k1/apply_runtime_patch_v2.py`
- `.github/workflows/kronia-k1-security.yml`

## Security certificate

The isolated certificate deliberately starts red and is iterated only by correcting implementation/fixtures. Current gates include 36 positive/negative authorization assertions plus database lint, runtime syntax, static trust-boundary checks, and secret-source regression checks.

Observed corrections so far:
1. `pgcrypto` is installed under the `extensions` schema in the live project; K1 uses explicitly qualified `extensions.digest` / `extensions.gen_random_bytes` with empty function `search_path`.
2. Staging fixtures now model the live auth function signatures so revocation is tested rather than skipped.

## Release blockers still open

- K1 security certificate must be fully green.
- Generated runtime diff must pass compatibility checks for web login, Brain, Chrome extension, Sales editor and integration metadata UI.
- Rollback must be executable and tested.
- Server-side secret/session environment requirements must be present in staging/release environment without exposing values.
- A real staging/preview deployment gate must be resolved.
- No production migration or merge is authorized by this checkpoint.

## Next exact action

Run the K1 certificate against the corrected production-shaped auth fixtures; resolve the next real failure, then produce the rollback migration and draft PR once all isolated gates are green.
