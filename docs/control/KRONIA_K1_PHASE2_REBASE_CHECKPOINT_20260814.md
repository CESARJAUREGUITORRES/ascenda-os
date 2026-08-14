# KRONIA K1 — PHASE 2 REBASE CHECKPOINT

Date: 2026-08-14  
Risk: **CRITICAL**  
Canonical candidate: **PR #94 — `security: K1 KronIA rebased on Phase 2 Auth V3`**  
Branch: `security/kronia-k1-phase2-rebase-20260814`  
Production mutation from K1: **NONE**  
Release state: **BLOCKED BEFORE CANARY**

## 1. Canonical architecture decision

Phase 2 Auth V3 is the single identity/session authority:

`aos_login_v3 → aos_verificar_2fa_v3 → aos_app_sessions_v3 → aos_app_actor_v3`

KronIA MUST consume the canonical Phase 2 `app_token`. K1 MUST NOT create a second username/password/session authority.

Runtime target:

`client → server-k1.js → server-phase2.js → server.js → Supabase`

The old PR #81 architecture is superseded because it predates the production Auth V3 cutover.

## 2. Why PR #81 was rejected as release candidate

Deep preproduction review found three CRITICAL incompatibilities:

1. it could clear `aos_rrhh.password_hash` without adapting production `aos_login_v3`;
2. it created a competing KronIA session/token system instead of consuming `aos_app_sessions_v3`;
3. it could regress the Phase 2 Railway runtime back toward legacy `server.js` startup semantics.

PR #81 MUST NOT be merged or deployed. It is retained only as historical evidence and must point to PR #94.

## 3. K1 rebased implementation

### K1-A — private credentials / Auth V3

- private service-only `aos_auth_credentials`;
- bcrypt only;
- preserves already-bcrypt credentials;
- converts legacy credential material once without logging values;
- adapts Auth V3 before clearing the RRHH compatibility column;
- adapts user create/reset/change-password flows;
- preserves Team `tiene_password` without exposing a hash;
- Sales Intelligence uses the same canonical Auth V3 token after 2FA;
- current branded 2FA template is preserved;
- ADMIN authority is canonical role + level 1/2 + 2FA + email.

### K1-B — app-token control plane

- `aos_kronia_identity_v3` derives current identity from `aos_app_actor_v3`;
- `aos_kronia_tool_v3` is the browser execution gateway;
- raw KronIA/business RPCs are internal/service-only implementations;
- conversations, security/audit logs and agent logs become server-owned;
- sanitized ADMIN feeds replace direct browser reads;
- identity/configuration/integration-secret mutations are owner ADMIN + 2FA gated;
- global 2FA cannot be disabled;
- legacy KronIA token store is not an authority source.

### Consumer compatibility

- RRHH identity projection is synchronized server-side;
- Team full profile fields are allowlisted explicitly;
- generic Team writes cannot forge Sales Intelligence access;
- owner cannot self-demote/deactivate/delete;
- authority changes revoke prior app/admin sessions;
- ordinary profile changes do not unnecessarily force logout;
- Brain direct audit Realtime is removed; sanitized incremental polling remains;
- Chrome uses Auth V3 and canonical `app_token`, never a parallel KronIA token;
- password is not persisted by Chrome;
- `/api/send-email` and `/api/studio/*` require ADMIN + 2FA at K1 proxy;
- administrative APIs have CORS/rate/body gates;
- password-labelled email transport is denied;
- Team legacy email templates are scrubbed before transport.

## 4. Rebased K1 migrations

Current K1 rebase requires exactly seven migrations in order:

1. `20260814170000_kronia_k1_private_credentials_auth_v3.sql`
2. `20260814171000_kronia_k1_app_token_control_plane.sql`
3. `20260814171500_kronia_k1_identity_sync.sql`
4. `20260814171600_kronia_k1_feed_schema_alignment.sql`
5. `20260814171800_kronia_k1_auth_v3_branded_alignment.sql`
6. `20260814172000_kronia_k1_team_profile_alignment.sql`
7. `20260814172100_kronia_k1_authority_session_revocation.sql`

These are preproduction artifacts only. They are not applied to production.

## 5. Zero-Cost certificate contract

Workflow:

`.github/workflows/kronia-k1-phase2-security.yml`

Required same-SHA evidence:

- latest Phase 1 + Phase 2 synthetic baseline;
- P0 auth/audit `search_path` fix;
- latest branded 2FA baseline;
- Cartera 96 assertions before K1;
- seven K1 migrations compile exactly;
- 50 K1 Auth V3/control-plane gates;
- Cartera 96 assertions after K1;
- Supabase DB lint;
- exact Railway materialization and SHA manifest;
- runtime syntax contracts;
- Brain sanitized-polling contract;
- Team compatibility/password-policy contract;
- Chrome Auth V3 contract;
- dynamic proxy smoke: 401 / 403 / 204 / 413 / 429;
- unauthenticated email/Studio relay denial;
- security-preserving recovery certificate;
- immutable evidence-root SHA-256.

A green result from an earlier #81 SHA is NOT valid evidence for PR #94.

## 6. External CI blocker — GitHub Actions

GitHub-hosted Actions currently does not provision a runner. Jobs end before step 1 with `runner_id=0`.

GitHub's own check annotation reports that recent account payments failed or the spending limit must be increased. A controlled rerun reproduced the same condition.

Classification: **external infrastructure blocker, not a K1 test failure**.

Rule: DO NOT mark K1 Zero-Cost certified until a real runner executes the entire PR #94 certificate on one SHA.

Do not purchase/increase paid infrastructure automatically. ASCENDA Zero-Cost policy remains authoritative.

## 7. Security release blocker — historical source secrets

The K1 materializer removes provider-secret fallbacks from the deploy artifact and fails closed when required runtime secrets are absent.

However, inherited canonical `app/server.js` still contains historical source literals for:

- a Resend API-key fallback;
- a webhook verification token.

Do not print, copy or log these values.

A deploy-time transformation is not sufficient to claim `0 HIGH/CRITICAL` because historical provider credentials may still be valid. Before production canary:

1. remove/neutralize source fallback paths;
2. rotate/invalidate the exposed provider credential(s) through the provider-approved secret-management process;
3. update runtime secret manager references without exposing values;
4. verify old values are invalid without logging them;
5. repeat the final secret scan and same-SHA certificate.

No provider rotation is authorized as an implicit preproduction action because it changes production credentials and may require a third-party integration/access path.

## 8. Production compatibility evidence gathered read-only

Live production was queried only for metadata/aggregates, never secret values.

Verified:

- Auth V3 is deployed and authoritative;
- current Railway contract uses Phase 2 runtime semantics;
- 13 RRHH credential records are populated: 1 bcrypt-like, 12 legacy-like; values were never read;
- `aos_auth_codes`, app sessions and login challenges are not browser-readable;
- KronIA raw RPCs remain browser-executable in the pre-K1 baseline and therefore K1 closure is still needed;
- trigger writers for audit/agent logs that must survive ACL closure are `SECURITY DEFINER`;
- the current global 2FA setting is enabled.

## 9. Final release gates still pending

K1 MUST remain `DRAFT / NO PRODUCTION RELEASE` until ALL are true:

1. GitHub runner blocker resolved without violating Zero-Cost governance;
2. PR #94 same-SHA CI + Zero-Cost + K1 certificate green;
3. evidence SHA-256 captured and linked;
4. historical source/provider secret blocker resolved and credential rotated/inactivated;
5. final scoped security review = **0 HIGH / 0 CRITICAL**;
6. production preflight confirms no drift;
7. owner receives and explicitly authorizes a separate CRITICAL canary/cutover gate.

Only after step 7 may any K1 migration/runtime deployment/canary change production.

## 10. Resume protocol

On any future ASCENDA/KronIA chat:

1. read `AGENTS.md`;
2. read `SECURITY.md`;
3. read `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`;
4. read this checkpoint;
5. inspect current `main` and PR #94;
6. ignore PR #81 as a release candidate;
7. verify GitHub Actions runner status;
8. resolve secret rotation blocker before production;
9. execute only from the latest verified PR #94 checkpoint.
