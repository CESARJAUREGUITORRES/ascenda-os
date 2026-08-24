# ASCENDA OS — ASC-PERF R1 EXACT HEAD CURRENT

**Status:** RUNNER GATE R1 / EXECUTING  
**Captured:** 2026-08-24 America/Lima  
**Exact main:** `a6443b9c29336781264d5871d9b5ab60c93f4444`  
**Branch:** `perf/asc-perf-r1-studio-off-20260824`  
**PR:** `#355` DRAFT

## Drift reconciliation

`main` advanced from the prior ASC-PERF baseline through merged PR #354, `WA-3 hardening — coalesce duplicate reads and hidden-tab load`.

R1 is therefore being rerun from the new exact `main` instead of certifying the stale PR #353 head.

## Studio directive

ASCENDA Studio is not an active workstream. It must produce no background operational calls while hibernated.

Runtime contract for this gate:

- Railway start command forces `AOS_STUDIO_BACKGROUND_ENABLED=false`;
- current `server.js` defaults the Studio scheduler to OFF;
- no Studio data/table/assets are deleted;
- manual Studio code remains preserved for a future explicit reactivation gate;
- no Studio background scheduler may register in production while the forced runtime value remains false.

## R1 objective

Run `ASCENDA ASC-PERF Audit 360` on the self-hosted Linux Zero-Cost runner and capture a complete static runtime census against the exact post-PR-354 codebase.

No PERF-3 remediation is certified from estimates alone.
