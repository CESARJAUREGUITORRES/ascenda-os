# Sentinel F8 — Terminal Checkpoint

**Fecha:** 2026-08-16/17 (America/Lima)  
**Estado técnico:** `F8 COMPLETE CANDIDATE — TERMINAL REPO SYNC PENDING`  
**PR:** `#208 DRAFT`  
**Producción:** `F8 PERSISTENCE APPLIED + CANARY CERTIFIED`  
**Functional certified head:** `d9f84652b1818a6a61e9d9e8dbfbdb85a4ede041`  
**Production migration:** `20260817000919 sentinel_f8_incident_engine`  
**Production canary:** `SEN-2026-0001 / RESOLVED`  

## Completed before F8

- F1–F7: `100_COMPLETE` and authoritative in `main`.
- F7 authoritative pre-F8 baseline: `01958565af1a5ffe426ffb0ac9e0588c77341175`.

## F8 core and persistence

Certified:

- stable `SEN-YYYY-NNNN` IDs;
- event replay idempotency;
- explicit signal vs incident fingerprints;
- seven signal classes;
- P0/P1/P2/P3 severity escalation;
- OPEN/ACK/INVESTIGATING/MITIGATED/RESOLVED lifecycle;
- 60-minute same-ID reopen;
- explicit multi-signal convergence;
- no implicit same-module merge;
- typed evidence references only;
- F7 correlation metadata without assumed causality;
- transactional PostgreSQL persistence;
- RLS on all persistence tables;
- `service_role`-only protected RPC boundary;
- fixed SECURITY DEFINER search path;
- no raw payload columns;
- advisory transaction locks for event and incident fingerprints;
- event ledger primary key;
- active fingerprint partial unique index;
- transactional yearly `SEN-*` counter;
- versioned rollback artifact.

## G12 — Zero-Cost DB

`PASS` on exact functional head `d9f84652b1818a6a61e9d9e8dbfbdb85a4ede041`.

Canonical F8 workflow run: `31980704736`.

- Windows incident core: PASS;
- Linux incident core: PASS;
- isolated PostgreSQL persistence: PASS;
- migration: PASS;
- RLS/ACL: PASS;
- lifecycle: PASS;
- replay: PASS;
- concurrent same-event: PASS;
- concurrent same-fingerprint: PASS;
- severity escalation: PASS;
- reopen: PASS;
- DB lint/search_path: PASS;
- rollback: PASS;
- reapply + fixture: PASS.

Ascenda CI run `31980704753`: PASS.

## G13 — Production Persistence

Owner authorization received and executed.

Production read-only preflight:

- required roles present;
- no F8 table/function collisions;
- project healthy.

Production apply:

- migration applied once through Supabase migration tooling;
- migration history version `20260817000919`;
- no unrelated production object changed by F8.

Post-DDL security verification:

- 4/4 Sentinel tables present;
- RLS enabled on all 4;
- no direct policies;
- 3 operational RPCs SECURITY DEFINER;
- fixed search path;
- `anon/authenticated` cannot execute operational Sentinel RPCs;
- `service_role` can execute them;
- no sensitive PHI/PII/secret-like columns.

## Production synthetic canary

`SEN-2026-0001` is intentionally retained as sanitized audit evidence.

Final state:

- `RESOLVED`;
- P2;
- signal_count=3;
- persisted signal rows=3;
- distinct event IDs=3;
- reopened_count=1;
- one severity escalation;
- one reopen;
- two successful resolve transitions;
- read RPC works;
- consistency checks PASS.

The canary proved exact replay, multi-signal convergence, severity escalation, lifecycle and same-ID reopen in production without PHI/PII.

## Advisor review

Post-DDL security/performance advisors were reviewed.

- No Sentinel-specific security advisory was introduced.
- No Sentinel unindexed-FK or multiple-policy warning was introduced.
- Fresh Sentinel indexes may be reported as unused immediately after creation; retain until sufficient operational evidence exists.
- Existing non-Sentinel database advisories are separate backlog items and are not modified under F8 scope.

## Current terminal gate

`F8-G14 — Repository / Control Synchronization`

Remaining before authoritative `CERRADA / 100_COMPLETE`:

1. commit final certificate + roadmap/control state;
2. exact-head F8 workflow PASS;
3. exact-head Ascenda CI/regressions PASS;
4. mark PR #208 ready;
5. merge exact green head to `main`;
6. post-merge verification on `main`;
7. update Notion last;
8. promote F9 as the sole active next phase.

## Hard boundary

Do not execute rollback in production unless a verified production defect requires contingency. Rollback→reapply is already certified in isolated G12.
