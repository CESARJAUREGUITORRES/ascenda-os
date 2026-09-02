# P0 #436 — Patient 360 hot-path / enrichment split

## Production evidence
Owner smoke after PR #438 reproduced the Patient 360 failure. LIVE Supabase API logs show canonical search HTTP 200 followed by two `aos_patient_360_current_v3` HTTP 500 responses. Matching PostgreSQL events are `canceling statement due to statement timeout`.

Browser PostgREST uses role `anon`, whose LIVE `statement_timeout` is 3 seconds. The canonical patient exists and the private legacy Patient 360 core resolves correctly; this is not data loss or an identity-target miss.

## Component profile on the production failing case
- canonical patient row: ~6.6 ms
- legacy Patient 360 core: ~1316.5 ms
- F5 classification: ~130.7 ms
- identity confidence: ~832.4 ms
- lifecycle: ~1869.7 ms
- patient-value SI: ~12.6 ms

The previous V3 executed these serially before returning, which cannot safely fit the 3-second browser budget.

## Architecture correction
`aos_patient_360_current_v3` is now the operational hot path only. Identity-confidence and lifecycle return `DEFERRED` and are fetched through governed `aos_patient_360_enrichment_v1`, one section per call. UI renders the operational record before starting enrichment and then loads `IDENTITY_CONFIDENCE` → `LIFECYCLE` serially. Late callbacks are selection-generation guarded. No concurrent fan-out and no heavy V3 retry.

## LIVE read-only budget canary before merge
With `statement_timeout='3s'`, a single statement executing the proposed hot-path workload — legacy Patient 360 core + targeted F5 counts + patient-value SI — completed successfully on the production failing case. Identity-confidence and lifecycle also completed independently inside the same 3-second budget when executed as separate statements.

## Invariants
- no timeout inflation
- no patient/sales/identity mutation
- no phone/document fallback or auto-merge
- service-worker token remains authoritative
- operational Patient 360 stays visible even if analytical enrichment is unavailable
- WA-L4 remains blocked until owner production smoke passes
