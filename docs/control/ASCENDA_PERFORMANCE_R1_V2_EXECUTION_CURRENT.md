# ASCENDA OS — ASC-PERF R1 V2 EXECUTION CURRENT

**Status:** EXECUTING  
**Exact main:** `70e94da5e9b598e60081b50839ff980afb30dff5`  
**Branch:** `perf/asc-perf-r1-execution-v2-20260824`

## Entry conditions

- Studio production runtime contract: HARD-OFF in `main`.
- Linux runner connectivity: CONFIRMED (`ASCENDA-ZERO-COST-V2`).
- Zero-Cost policy on runner: PASS.
- Prior R1 failure: infrastructure-only, `node: command not found`.
- Node bootstrap: corrected in current `main` via explicit `actions/setup-node@v4`, Node 20.

## R1-A required result

`Setup Node → Zero-Cost → Studio HARD-OFF contract → Runtime census → Census integrity`

No production remediation is introduced by this execution marker.
