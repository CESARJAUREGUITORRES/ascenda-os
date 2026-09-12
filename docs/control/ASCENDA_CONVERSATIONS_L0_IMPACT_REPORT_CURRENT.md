# CONV-L0 — IMPACT REPORT CURRENT

**Project / phase:** CONV-001 / CONV-L0 #504  
**Objective:** audit current WhatsApp runtime/UI/DB architecture and freeze extraction/target contracts before replacement implementation.  
**Risk classification:** HIGH program boundary; this L0 change set is documentation/CI/read-only production discovery only.

## Code/runtime

No production runtime behavior is changed by CONV-L0.

The branch adds/updates architecture/control artifacts only. It does not:
- change Railway start command;
- change WhatsApp routes;
- enable AI/autonomous sends;
- modify provider credentials;
- alter browser runtime;
- introduce a new package/runtime dependency.

## Data / RPC / triggers

Production DB interaction during L0 is read-only:
- catalog relation/function inventory;
- `pg_stat_statements` aggregation;
- trigger/index introspection;
- function dependency/volatility inspection;
- read-only `EXPLAIN (ANALYZE, BUFFERS)` for stable functions;
- protected-module count fingerprints;
- safety-state readback.

No DDL/DML migration is introduced in L0.

## Consumers / dependencies

Protected consumers explicitly mapped:
- Agenda/booking;
- Patients/identity;
- Sales/Revenue/Commissions;
- Call Center;
- Marketing/attribution;
- Auth/2FA;
- notification/background infrastructure;
- current ASCENDA shell/panel.

The extraction plan prohibits deleting or bypassing these systems merely to simplify WhatsApp.

## Security / roles / sensitive data

- No credentials copied or logged.
- No raw phone/customer identifiers are included in L0 docs.
- Auth V3/2FA remains authoritative.
- SECURITY DEFINER surface is inventoried but not mutated.
- No service-role capability is moved to browser.
- Legacy autonomous production remains SAFE-OFF.

## Tests / certification

Required for this L0 branch:
- syntax/diff hygiene through existing Ascenda CI;
- P0-485 stability invariant;
- WA-CLOSEOUT / WA-3.5 documentation/runtime contracts where triggered;
- WA-L4 / WA-L10 SAFE-OFF contracts where triggered;
- anti-drift against exact current `main` before merge.

L0 completion additionally requires all audit deliverables and frozen benchmark/contracts.

## Rollback

L0 has no production runtime/data mutation.

Rollback is:
- close/supersede the L0 PR;
- revert documentation commits if merged.

No database rollback or Railway redeploy is required for L0 itself.

## Portfolio-lock impact

CONV-L0 is the sole HIGH/CRITICAL lane.
All other programs remain read-only/regression-only except tests needed to prove the active architecture pivot did not violate preserved contracts.
