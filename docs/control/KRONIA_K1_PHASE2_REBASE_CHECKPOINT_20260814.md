# KRONIA K1 — PHASE 2 REBASE CHECKPOINT

**Date:** 2026-08-14  
**Risk:** **CRITICAL**  
**Canonical candidate:** PR #94 — `security: K1 KronIA rebased on Phase 2 Auth V3`  
**Branch:** `security/kronia-k1-phase2-rebase-20260814`  
**Production mutation from K1:** **NONE**  
**Release state:** **BLOCKED BEFORE CANARY**

## 1. CURRENT governance / Zero-Cost CI V2

ASCENDA Zero-Cost CI V2 is mandatory for this workstream.

Current infrastructure source while PR #97 remains open:
- PR #97: `Infra: ASCENDA Zero-Cost CI V2 + self-hosted runner`;
- branch: `infra/zero-cost-ci-v2`;
- observed PR #97 head during this checkpoint: `5b38155cf116b3de512b78f0059ba73b0dd17f93`;
- `main` observed during this checkpoint: `fdc6edb69c3d525b0c2b1c9eac8eef3636ff013d`;
- PR #97 is **OPEN / NOT MERGED**.

Mandatory runner contract:

`runs-on: [self-hosted, Linux, X64, ascenda-zero-cost-v2]`

Runner display name expected: `ASCENDA-ZERO-COST-V2`.

Rules:
- GitHub Actions additional paid usage target = **US$0**;
- no `ubuntu-latest`, `windows-latest` or `macos-*` fallback;
- one runner means jobs execute sequentially;
- `queued/pending` is not a failure by itself;
- do not re-run `config.sh` or re-register the runner as routine recovery;
- fixtures synthetic only; no PII/PHI or production secrets in CI.

K1 workflow was migrated to CI V2 on commit:

`6ee3fcbd333291692db5cd3b55f7841f26a5416d`

K1 self-hosted run observed:
- run `31834739184`;
- job `94878389025`;
- status at checkpoint: `queued`;
- labels: `self-hosted`, `Linux`, `X64`, `ascenda-zero-cost-v2`.

The same K1 SHA also triggered inherited workflows from `main` that still request `ubuntu-latest` because PR #97 is not yet merged. Those jobs may fail before step 1 due the old hosted-runner path. **Do not treat those inherited pre-V2 failures as K1 functional test failures and do not duplicate/merge PR #97 into K1 merely to bypass its own gate.**

Required sequence:
1. PR #97 must finish its own V2 checks and merge according to its governance;
2. then synchronize PR #94 with the new `main` without force-push/history rewriting;
3. only the post-sync same SHA may be used for final `Ascenda CI + Zero-Cost + K1 Security` evidence.

## 2. Canonical K1 architecture

Phase 2 Auth V3 remains the single identity/session authority:

`aos_login_v3 → aos_verificar_2fa_v3 → aos_app_sessions_v3 → aos_app_actor_v3`

KronIA MUST consume the canonical Phase 2 `app_token`. K1 MUST NOT create a second username/password/session authority.

Runtime target:

`client → server-k1.js → server-phase2.js → server.js → Supabase`

PR #81 is superseded and MUST NOT be merged/deployed.

## 3. K1 rebased implementation

### K1-A — private credentials / Auth V3
- private service-only `aos_auth_credentials`;
- bcrypt only;
- preserves already-bcrypt credentials;
- converts legacy credential material once without logging values;
- adapts Auth V3 before clearing the RRHH compatibility column;
- adapts create/reset/change-password flows;
- preserves Team `tiene_password` without exposing hashes;
- current branded 2FA contract preserved;
- privileged ADMIN = canonical role + hierarchy 1/2 + 2FA + email.

### K1-B — app-token control plane
- `aos_kronia_identity_v3` derives identity from `aos_app_actor_v3`;
- `aos_kronia_tool_v3` is the token-bound browser gateway;
- raw KronIA/business RPCs become internal/service implementations;
- conversations/logs/audit become server-owned with sanitized ADMIN feeds;
- identity/config/integration-secret administration is owner ADMIN + 2FA gated;
- global 2FA cannot be disabled;
- legacy KronIA token storage is not an authority source.

### Consumer compatibility
- RRHH projection synchronized server-side;
- Team full profile allowlist;
- generic Team writes cannot forge Sales Intelligence;
- owner self-demotion/deactivation/delete blocked;
- authority changes revoke prior sessions;
- ordinary profile changes do not unnecessarily force logout;
- Brain direct audit Realtime removed in K1 artifact; sanitized incremental polling retained;
- Chrome uses Auth V3 + canonical `app_token`; password is not persisted;
- `/api/send-email` and `/api/studio/*` require ADMIN + 2FA;
- CORS/rate/body gates;
- password-labelled email transport denied.

## 4. Exact K1 migrations

Current K1 release contains exactly seven migrations:

1. `20260814170000_kronia_k1_private_credentials_auth_v3.sql`
2. `20260814171000_kronia_k1_app_token_control_plane.sql`
3. `20260814171500_kronia_k1_identity_sync.sql`
4. `20260814171600_kronia_k1_feed_schema_alignment.sql`
5. `20260814171800_kronia_k1_auth_v3_branded_alignment.sql`
6. `20260814172000_kronia_k1_team_profile_alignment.sql`
7. `20260814172100_kronia_k1_authority_session_revocation.sql`

They remain preproduction artifacts and are not applied to production.

The K1 CI gate now requires exactly **7**, not 5.

## 5. Live production drift verified read-only

Supabase production project: `ituyqwstonmhnfshnaqz`.

Read-only snapshot at this checkpoint verified:
- Auth V3 login exists;
- `aos_app_actor_v3` exists;
- global `seg_2fa_habilitado = true`;
- active app sessions observed: 4;
- active `PASSWORD_2FA` sessions observed: 2;
- `aos_auth_codes` is not readable by `anon`;
- `aos_app_sessions_v3` is not readable by `anon`;
- K1 private credential table `aos_auth_credentials` does **not** exist yet;
- 13 RRHH rows contain credential material; 4 are bcrypt-like at this snapshot; values were never read or exposed;
- raw `aos_kronia_explorar(...)` remains executable by `anon`;
- raw `aos_editar_venta(...)` remains executable by `anon`.

Therefore K1 remains required.

### CIA F14/F15 drift

Production migration ledger advanced beyond the original K1 checkpoint:
- F14: `20260814181106`, `20260814181136`, `20260814181209`;
- F15: `20260814184100` through `20260814184500`.

GitHub evidence:
- PR #98 F14 merged to `staging`;
- PR #100 F15 merged to `staging`;
- observed `staging` SHA: `f0a087bd957dc19a81b5f8a0144b0bbc6a901549`;
- these migrations are live in Supabase although not represented by current `main` at this checkpoint.

F15 explicitly does **not** claim to close KronIA V2 K1 debt. It hardens its own governed SHADOW namespace and legacy `aos_execute_agent_query` compatibility boundary.

PR #94 diff was checked and does not touch:
- `aos_execute_agent_query`;
- `aos_cia_kronia_*`.

K1 CI now contains a workstream-boundary gate that fails if K1 migrations begin modifying those F15 objects unintentionally. F14/F15 remain required lateral checks in the final production read-only preflight/smoke.

## 6. Zero-Cost K1 certificate contract

Workflow:

`.github/workflows/kronia-k1-phase2-security.yml`

Required same-SHA evidence:
- synthetic Phase 1 + Phase 2 baseline;
- P0 auth/audit `search_path` fix;
- branded 2FA baseline;
- Cartera 96 assertions before K1;
- exactly seven K1 migrations;
- 50 K1 Auth V3/control-plane gates;
- Cartera 96 assertions after K1;
- DB lint;
- exact Railway materialization + SHA manifest;
- Brain/Team/Chrome/runtime contracts;
- dynamic proxy negatives and limits;
- unauthenticated email/Studio denial;
- security-preserving recovery;
- F15 workstream non-overlap gate;
- immutable evidence-root SHA-256.

A green result from PR #81 or from any pre-CI-V2 SHA is not valid final evidence.

## 7. Security release blocker — historical source secrets

The K1 materialized deploy artifact removes provider-secret fallbacks and fails closed when runtime secrets are absent.

However inherited canonical source still contains historical credential/token literals. Do not print, copy or log them.

Removing a literal from HEAD is not sufficient if the credential may remain valid. Before production canary:
1. remove/neutralize source fallback paths;
2. rotate/invalidate exposed provider credential(s) through the provider-approved secret process;
3. update runtime secret manager references without exposing values;
4. verify old values are invalid without logging them;
5. repeat secret scan and same-SHA certification.

This remains a **HIGH release blocker** until actually rotated/invalidated.

## 8. Final gates pending

K1 remains `DRAFT / NO PRODUCTION RELEASE` until ALL are true:

1. PR #97 Zero-Cost CI V2 gate resolved and infrastructure state synchronized into `main`;
2. PR #94 synchronized to that CURRENT `main`;
3. one exact PR #94 SHA obtains required Ascenda CI + Zero-Cost + K1 Security green under CI V2;
4. evidence SHA-256 captured and linked;
5. historical source/provider secret blocker resolved and credential rotated/inactivated;
6. final scoped security review = **0 HIGH / 0 CRITICAL**;
7. production read-only preflight confirms current Auth V3 + F14/F15 + K1 compatibility and no unexpected drift;
8. owner receives the separate CRITICAL canary/cutover gate;
9. only after authorization: controlled canary → smoke/negative auth → cutover if eligible → recovery verification → certification.

Do not use `100%`, `100_COMPLETE` or `PRODUCTION CERTIFIED` while any gate above remains open.

## 9. Resume protocol

For any future ASCENDA/KronIA chat:
1. read CURRENT `AGENTS.md`;
2. read CURRENT `SECURITY.md`;
3. read CURRENT `ASCENDA_CONTROL_MASTER.md`;
4. read CURRENT `ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`;
5. read CURRENT `ASCENDA_ZERO_COST_CI_V2_HANDOFF.md`;
6. read `KRONIA_V2_MASTER_INDEX_20260813.md` for architecture/history;
7. read this checkpoint as the CURRENT K1 execution state;
8. verify PR #97/main/staging/PR #94/checks/SHA live;
9. verify Supabase live before DB assumptions;
10. never reconfigure the runner or fall back to paid CI to accelerate the queue.
