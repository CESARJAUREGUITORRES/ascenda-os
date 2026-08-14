# Phase 11 PR Review Notes

Review focus:
1. `aos_siguiente_lead` and `aos_siguiente_lead_v2` are not modified.
2. Global V3 kill switch defaults OFF; fallback V2 is mandatory.
3. `calls-v2.html` blob is identical to pre-F11 `calls.html` blob `010c73e0bb55c0169470e5a259c912681afbccc9`.
4. `calls.html` is a minimal wrapper loading CI-checkable `calls-loader-v3.js` + `calls-routing-v3.js` before legacy runtime.
5. V3 consumes only F9 ownership and revalidates F8 for new ASSIGNED work.
6. Existing IN_PROGRESS ownership is resumed from F9 and not reinterpreted by F8.
7. Call writes remain legacy-first; lease completion is a post-write synchronization.
8. No operational table indexes/triggers/schema changes.
9. Migrations are aligned to the Supabase ledger.
10. Validation Report remains VALIDATING until staging smoke/closure.
