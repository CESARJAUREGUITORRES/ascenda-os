# KronIA K1 — Zero-Cost Canary & Production Release Gate — 2026-08-14

**Phase:** K1 — Identity, Session & Secrets Hardening  
**Risk:** CRITICAL  
**Branch:** `security/kronia-k1-hardening-20260814`  
**PR:** #81  
**Production authorization:** NOT GRANTED  
**Validation policy:** `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`

## 1. Purpose

Define the remaining evidence required to promote K1 from **ZERO-COST CERTIFIED** to **CANARY CERTIFIED** and finally **PRODUCTION CERTIFIED** without creating unnecessary paid staging infrastructure.

A Supabase Cloud Development Branch is not required for K1 because the release migrations, authorization contracts, rollback and deploy artifact can be exercised reproducibly in ephemeral Zero-Cost Staging. A paid remote branch remains an exceptional fallback only if a future dependency cannot be reproduced safely by this circuit.

## 2. Certified preproduction topology

```text
feature/security branch
  → Ascenda CI
  → ASCENDA Zero-Cost Staging
      → Supabase/Postgres ephemeral
      → production-shaped synthetic contracts
      → exact migrations
      → pgTAP / auth-negative tests / lint / performance
      → rollback
      → destroy environment
  → K1 Security Certificate
      → exact Railway materializer
      → runtime syntax/compatibility
      → secret regression
  → production read-only preflight
  → owner-authorized canary/cutover
```

No production credentials or patient PII/PHI belong in Zero-Cost fixtures.

## 3. Current certified evidence

Certified K1 functional head before documentation-only checkpoint commits: `a6e5762063b0774f2cc0c384c3fbcf4e05b1c57c`.

- Ascenda CI #731 / run `31806139117`: **SUCCESS**
- ASCENDA Zero-Cost Staging #82 / run `31806139089`: **SUCCESS**
- KronIA K1 Security Certificate #44 / run `31806139104`: **SUCCESS**

K1-specific certificate includes exact Railway artifact materialization, consumer compatibility, four migrations, negative authorization, lint, rollback, runtime gates and secret-source regression.

## 4. Production preflight facts

Read-only verification on 2026-08-14 confirmed:
- K1 migrations applied: `0`;
- live auth primitives return `json`;
- pre-K1 browser execution remains open on login/2FA and scoped mutation RPCs;
- `aos_kronia_tokens` still lacks effective browser isolation;
- broad browser table privileges remain on scoped identity/audit/integration surfaces;
- 3/49 integration rows contain non-empty `api_key` values; values were not read;
- exactly 1 active ADMIN identity is eligible for canary and has 2FA/email/credential available.

These facts are evidence of the current pre-K1 baseline, not release completion.

## 5. Required environment gate

Before any production mutation, confirm server-side variables exist in the Railway/secret-manager environment. Values MUST NOT be pasted into GitHub, Notion, logs or ChatGPT.

Required/expected K1 boundary variables include:
- `SUPABASE_SERVICE_ROLE_KEY`
- `GROQ_API_KEY`
- `GEMINI_API_KEY`
- `RESEND_API_KEY`
- `ASCENDA_VERIFY_TOKEN`
- `TURNSTILE_SECRET_KEY`

Missing provider secrets must fail closed. Do not restore hardcoded fallbacks.

## 6. Secret rotation gate

Before final production certification:
1. inventory provider credentials by name/location only, never value;
2. provision replacement values in server environment/secret manager;
3. rotate/revoke historical credentials that were present in source or browser-readable DB fields;
4. prove prior credentials invalid through provider-side status or controlled failure evidence;
5. remove browser access to credential columns through K1 permissions;
6. do not delete configuration metadata needed for the UI.

## 7. Additive canary sequence

K1 is CRITICAL. Prefer a compatibility-first rollout so the clinic is not locked out.

### Phase A — Runtime ready
- deploy the K1-compatible runtime/materializer;
- confirm health endpoint/runtime startup;
- confirm required environment variables are present by boolean/config status only;
- do not print secret values;
- retain rollback to prior runtime commit.

### Phase B — Single ADMIN canary
Using only the one eligible ADMIN:
- valid web login;
- 2FA delivered server-side;
- browser response contains no raw OTP/credential/integration secret;
- opaque KronIA session issued;
- Brain/shared KroniaCore restores session;
- main chat text succeeds;
- current voice/Whisper path succeeds with Bearer;
- Chrome login + 2FA + chat succeeds;
- password is not persisted in Chrome storage;
- Sales editor succeeds through token-bound gateway;
- integrations page returns metadata only;
- agent admin endpoints require ADMIN Bearer.

Do not widen canary to additional users until these pass.

## 8. Cutover database sequence

After additive canary/runtime readiness and explicit owner authorization, apply in order:
1. `20260814051500_kronia_k1_identity_session_hardening.sql`
2. `20260814051600_kronia_k1_extension_claim.sql`
3. `20260814051700_kronia_k1_integration_admin_gateway.sql`
4. `20260814051800_kronia_k1_canonical_closure.sql`

Immediately verify:
- raw auth primitives denied to `anon` / `authenticated`;
- raw scoped mutation RPCs denied to browser roles;
- `aos_kronia_tokens` browser read/write denied;
- integration secret columns inaccessible;
- `aos_usuarios` browser writes denied;
- authoritative action/audit surfaces cannot be rewritten by browser roles;
- active token role re-derives from current identity;
- user deactivation/role change affects existing session authorization;
- 2FA replay is rejected.

## 9. Mandatory post-cutover smoke matrix

### Web Auth/2FA
- valid canary login PASS;
- wrong password DENY;
- wrong/expired/replayed 2FA DENY;
- raw auth RPC browser call DENY;
- token stored client-side only in expected session storage and server-side only as digest.

### KronIA / main chat / Brain
- valid Bearer text PASS;
- no Bearer 401;
- forged `usuario`/`rol`/`sede` cannot alter effective identity;
- voice requires Bearer;
- legacy identity headers provide no authority.

### Chrome
- password never persisted;
- 2FA single-use;
- opaque session used;
- logout clears/revokes expected session state.

### Sales editor
- authorized edit uses `aos_kronia_tool` → allowed RPC;
- raw `aos_editar_venta` browser execution DENY;
- actor/role is server-derived;
- unauthorized action DENY;
- audit row produced.

### Integrations
- metadata list works;
- credential/config fields inaccessible to browser;
- advisor cannot perform ADMIN action;
- ADMIN narrow gateway works and audits.

### Agents
For control endpoints as applicable:
- no token DENY;
- invalid token DENY;
- advisor token DENY for ADMIN control;
- valid ADMIN Bearer allowed only under existing business contract.

## 10. Rollback/recovery

Rollback SQL: `supabase/rollbacks/20260814_kronia_k1_rollback.sql`.

Already proven in Zero-Cost Staging. If production rollback becomes necessary:
- revert compatible runtime to prior release commit;
- execute documented compensating SQL in approved order;
- K1 sessions are invalidated and users re-login;
- do not attempt to reverse SHA-256 token digests;
- verify legacy compatibility only to the documented pre-K1 baseline;
- repeat login/smoke and data/audit reconciliation.

Do not reopen individual grants manually as an improvised rollback.

## 11. Final security review

Before declaring K1 `100_COMPLETE`:
- final PR/runtime diff reviewed;
- `PUBLIC`, `anon`, `authenticated` effective privileges reviewed;
- `SECURITY DEFINER` search paths reviewed;
- secrets rotated and old values invalidated;
- browser responses/logs checked for sensitive leakage;
- no HIGH/CRITICAL finding open in K1 scope;
- post-cutover smoke and negative-auth matrix complete.

## 12. Certification states

- `ZERO-COST CERTIFIED` — all local/CI contracts and rollback passed. **CURRENT: YES**.
- `CANARY CERTIFIED` — single eligible ADMIN passes real integration flows. **CURRENT: NO**.
- `PRODUCTION CERTIFIED` — cutover authorized/applied, post-smoke/security reconciliation passed. **CURRENT: NO**.
- `K1 100_COMPLETE` — only after PRODUCTION CERTIFIED + documentation/checkpoint closure.

## 13. Explicit authorization boundary

The user's authorization to use Zero-Cost Staging authorizes the preproduction validation methodology and documentation. It **does not by itself authorize production mutation**.

The next irreversible/operational boundary is the production additive canary/cutover. That requires explicit owner authorization after environment/secret readiness is confirmed.
