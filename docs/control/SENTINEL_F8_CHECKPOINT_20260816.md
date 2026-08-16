# Sentinel F8 — Current Checkpoint

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `F8 EN CURSO`  
**PR:** `#208 DRAFT`  
**Producción:** `DDL NOT AUTHORIZED / NOT APPLIED`  

## Completed before F8

- F1–F7: `100_COMPLETE`.
- F7 authoritative main baseline: `01958565af1a5ffe426ffb0ac9e0588c77341175`.

## F8 core

Implemented and cross-platform certified:

- stable `SEN-YYYY-NNNN` IDs;
- event replay idempotency;
- signal vs incident fingerprints;
- 7 signal classes;
- P0/P1/P2/P3 severity;
- OPEN/ACK/INVESTIGATING/MITIGATED/RESOLVED lifecycle;
- severity escalation timeline;
- 60-minute reopen same-ID policy;
- outside-window new-ID policy;
- explicit multi-signal convergence;
- no implicit same-module merge;
- typed evidence references only;
- F7 correlation metadata only, no causality assertion;
- in-memory repository adapter for deterministic core certification.

## F8 persistence branch artifacts

Created but not applied to production:

- `supabase/migrations/20260816233500_sentinel_f8_incident_engine.sql`
- `supabase/rollbacks/20260816233500_sentinel_f8_incident_engine_rollback.sql`
- `ci/sentinel/phase8_persistence_zero_cost.sql`
- `ci/sentinel/phase8_persistence_zero_cost.sh`
- `sentinel/incidents/persistence-design-v1.json`

Persistence properties:

- 4 new Sentinel-only tables;
- 5 Sentinel-only functions;
- RLS enabled;
- no direct anon/authenticated access;
- service-role-only protected RPC boundary;
- fixed SECURITY DEFINER search_path;
- no raw payload column;
- advisory transaction locks for concurrent event/fingerprint ingest;
- event ledger PK;
- active fingerprint unique constraint;
- yearly transactional SEN counter.

## Production read-only preflight

`PASS` on 2026-08-16:

- required Supabase roles exist;
- no proposed F8 table collision;
- no proposed F8 function collision;
- no production DDL executed.

## Current active gate

`F8-G12 — Zero-Cost DB`

The local certificate must prove:

1. migration compiles in isolated local Supabase;
2. RLS/ACL/grants;
3. service-role-only RPC;
4. lifecycle/reopen;
5. exact replay idempotency;
6. concurrent same-event replay;
7. concurrent same-fingerprint convergence;
8. severity escalation;
9. DB lint/security-definer search_path;
10. rollback removes all F8 objects;
11. reapply + fixtures pass again.

## Hard blocker

`F8-G13 Production Persistence = BLOCKED`

Do not:

- apply migration to production;
- merge PR #208;
- expose new F8 RPCs in ASCENDA runtime;
- enable alerts/remediation.

G13 requires:

1. G12 Zero-Cost PASS;
2. `SENTINEL_F8_PRODUCTION_PERSISTENCE_IMPACT_20260816.md`;
3. explicit owner authorization for this exact migration/canary/conditional rollback.
