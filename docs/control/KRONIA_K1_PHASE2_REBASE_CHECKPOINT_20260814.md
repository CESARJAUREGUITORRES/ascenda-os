# KRONIA K1 — PHASE 2 REBASE CHECKPOINT

**Date:** 2026-08-14  
**Risk:** **CRITICAL**  
**Canonical candidate:** PR #94 — `security: K1 KronIA rebased on Phase 2 Auth V3`  
**Branch:** `security/kronia-k1-phase2-rebase-20260814`  
**Production mutation from K1:** **NONE**  
**Release state:** **BLOCKED BEFORE CANARY**

## 1. CURRENT governance — Zero-Cost CI V2
ASCENDA Zero-Cost CI V2 is mandatory.

Runner contract:
`runs-on: [self-hosted, Linux, X64, ascenda-zero-cost-v2]`

Runner expected: `ASCENDA-ZERO-COST-V2`.

Rules:
- GitHub Actions additional paid usage target = US$0;
- no hosted fallback;
- one runner means sequential execution;
- queued/pending is not a functional failure;
- do not run `config.sh` for normal recovery;
- CI uses synthetic fixtures only, with no PII/PHI or production secrets.

Infrastructure PR #97 remains the integration gate for CI V2. Its branch was synchronized with current Auth V3 `main` through a non-force two-parent merge and its Hardening/Final Release workflows now include the `20260814195300_fix_auth_v3_btrim.sql` P0 at the end of the synthetic release chain.

### Runner state CURRENT
At the latest checks GitHub reported **0 workflows in progress** while self-hosted V2 jobs for PR #97, PR #105 and PR #94 remained queued/pending. Classification: runner offline/not listening, not a test failure.

Recovery per CURRENT handoff:
1. start Docker;
2. use the existing `ascenda-runner` user;
3. `cd ~/actions-runner/actions-runner`;
4. `./run.sh`;
5. expected: `Connected to GitHub` / `Listening for Jobs`.

Do **not** re-register the runner and do not use hosted fallback.

## 2. Canonical K1 architecture
Phase 2 Auth V3 remains the single identity/session authority:

`aos_login_v3 → aos_verificar_2fa_v3 → aos_app_sessions_v3 → aos_app_actor_v3`

KronIA consumes the canonical `app_token`. K1 does not create another username/password/session authority.

Runtime target:
`client → server-k1.js → server-phase2.js → server.js → Supabase`

PR #81 is superseded and must not be deployed.

## 3. K1 implementation
### K1-A — private credentials / Auth V3
- private service-only `aos_auth_credentials`;
- bcrypt only;
- preserve existing bcrypt and migrate legacy credential material once without logging values;
- adapt Auth V3 before clearing RRHH credential material;
- preserve Team `tiene_password` and branded 2FA;
- privileged ADMIN = canonical role + hierarchy 1/2 + 2FA + email.

### K1-B — app-token control plane
- `aos_kronia_identity_v3` derives identity from `aos_app_actor_v3`;
- `aos_kronia_tool_v3` is the browser gateway;
- raw KronIA/business RPCs become service-only implementations;
- logs/audit/conversations become server-owned with sanitized ADMIN feeds;
- identity/config/integration administration is owner ADMIN + 2FA gated;
- global 2FA cannot be disabled.

### Consumer compatibility
- Team fields are explicitly allowlisted and RRHH projection synchronized;
- generic Team updates cannot forge Sales Intelligence;
- owner self-demotion/deactivation/delete blocked;
- authority changes revoke prior sessions;
- Brain audit Realtime replaced by sanitized polling;
- Chrome uses Auth V3 + canonical app-token and does not persist password;
- `/api/send-email`, `/api/studio/*` and agent APIs are server-authorized;
- CORS/rate/body controls apply;
- password-labelled email transport is denied.

## 4. Exact K1 migrations
1. `20260814170000_kronia_k1_private_credentials_auth_v3.sql`
2. `20260814171000_kronia_k1_app_token_control_plane.sql`
3. `20260814171500_kronia_k1_identity_sync.sql`
4. `20260814171600_kronia_k1_feed_schema_alignment.sql`
5. `20260814171800_kronia_k1_auth_v3_branded_alignment.sql`
6. `20260814172000_kronia_k1_team_profile_alignment.sql`
7. `20260814172100_kronia_k1_authority_session_revocation.sql`

They remain preproduction artifacts.

## 5. Production drift — read-only verified
Supabase production project: `ituyqwstonmhnfshnaqz`.

Verified:
- Auth V3 and `aos_app_actor_v3` live;
- global 2FA = true;
- app sessions and 2FA sessions active;
- auth proof stores are not anon-readable;
- K1 private credential table does not exist yet;
- 13 RRHH rows contain credential material; 4 were bcrypt-like at latest snapshot; values never read/exposed;
- raw `aos_kronia_explorar(...)` and raw sale editor remain browser-executable, so K1 closure is still necessary;
- CIA F14/F15 migrations through `20260814184500` are live in Supabase.

F15 explicitly does not close broader KronIA K1 debt. PR #94 does not modify `aos_execute_agent_query` or `aos_cia_kronia_*`; CI contains a non-overlap gate.

## 6. Phase 2 P0 discovered by Zero-Cost — PR #105
Zero-Cost lint exposed a real preexisting bug in `aos_secure_write_v2`: it references nonexistent PostgreSQL `jsonb_object_length(jsonb)`.

Dedicated fix:
- PR #105 — `P0: fix secure_write JSONB match validation`;
- branch `fix/phase2-secure-write-jsonb-20260814`;
- migration `20260814201500_fix_secure_write_v2_jsonb_match_count.sql`;
- dedicated V2 tests and fail-closed recovery;
- no production data mutation in the PR.

Static review also caught and corrected an over-qualification error before CI: `COALESCE` remains SQL syntax and is not invoked as `pg_catalog.coalesce`.

Required order:
1. dedicated #105 Zero-Cost V2 certificate green;
2. merge #105 to main;
3. synchronize #97 with that main and include the secure-write P0 in its exact chains;
4. close #97 V2 gate and merge;
5. synchronize #94 to that CURRENT main.

## 7. K1 Zero-Cost certificate contract
Workflow: `.github/workflows/kronia-k1-phase2-security.yml`.

Required same-SHA evidence:
- current Phase 1/Phase 2 synthetic baseline including Auth `btrim` and secure-write P0 once merged;
- Cartera 96 assertions before K1;
- exactly seven K1 migrations;
- 50 K1 DB gates;
- Cartera 96 assertions after K1;
- DB lint;
- exact Railway materialization + manifest;
- Brain/Team/Chrome/runtime contracts;
- 401/403/204/413/429 proxy smoke;
- email/Studio unauthenticated denial;
- security-preserving recovery;
- F15 non-overlap gate;
- immutable evidence-root SHA-256.

## 8. Source-secret gate and Resend rotation
K1 now has a deterministic source sanitizer for inherited hardcoded provider fallbacks and the materializer is idempotent after cleanup.

Permanent runtime contract now reads `git show HEAD:app/server.js`; therefore final K1 certification cannot pass merely because build-time materialization hid a secret. The **committed source SHA itself** must be free of the fallback paths.

### Resend production credential — verified without exposing value
Read-only digest comparison established:
- exactly one active Resend integration is present;
- its current non-empty API key matches the historically exposed source credential by SHA-256 digest;
- the value was never printed/copied in project documentation or responses.

A server-side Resend API preflight returned `restricted_api_key`: the current key is sending-only and cannot create/list/delete API keys. Therefore provider-side rotation requires a new key created from the authorized Resend account/dashboard or another full-access provider credential. The current key must not be deleted before the replacement is deployed and verified.

Required rotation sequence:
1. create a new Resend sending key in the authorized provider account;
2. do not paste the secret in chat/issue/commit/log;
3. update the protected production secret location;
4. smoke email/2FA-dependent flows;
5. revoke/delete the historical key in Resend;
6. verify the old credential is invalid without logging it;
7. repeat source/secret review.

This remains the last known HIGH provider-secret blocker before K1 can reach 0 HIGH/CRITICAL.

## 9. Final gates pending
K1 remains `DRAFT / NO PRODUCTION RELEASE` until all are true:
1. self-hosted runner listening and queued V2 jobs actually execute;
2. PR #105 Zero-Cost certificate green and fix integrated;
3. PR #97 V2 infrastructure gate green and merged;
4. PR #94 synchronized with CURRENT main;
5. committed source secret fallback removed;
6. one exact #94 SHA gets required Ascenda CI + Zero-Cost + K1 greens;
7. evidence SHA-256 captured;
8. Resend exposed credential rotated/inactivated;
9. final scoped security review = 0 HIGH / 0 CRITICAL;
10. production read-only preflight confirms Auth V3 + F14/F15 + K1 compatibility and no unexpected drift;
11. CRITICAL canary/cutover authorization is applied;
12. controlled canary → smoke/negative auth → cutover if eligible → recovery verification → final certification.

Do not use `100%`, `100_COMPLETE` or `PRODUCTION CERTIFIED` while any gate remains open.

## 10. Resume protocol
Any future ASCENDA/KronIA chat must read CURRENT `AGENTS.md`, `SECURITY.md`, Control Master, Zero-Cost V2 Standard/Handoff and this checkpoint; verify GitHub + Supabase live; then continue from PR #105 → #97 → #94 in that order unless live state proves those gates already closed.
