# REV Patient 360 V3 — Browser Token Bridge Fix

## Incident
Owner UI reached canonical patient `P-5549` but `aos_patient_360_current_v3` returned no usable record.

## Root cause
`patients-f6-v2.js` calls `aos_patient_360_current_v3` from the browser. The canonical Auth V3 token used by governed runtime flows lives in the Phase 2 service-worker cache (`aos-phase2-auth`). The service worker injected/overrode that token for `aos_patient_search_v2` and `aos_patient_commercial_360_v2`, but the new `aos_patient_360_current_v3` RPC was omitted from the governed bridge. Therefore search could succeed with the current 2FA token while selection reached V3 with the browser/sessionStorage token instead of the canonical worker token.

## Fix
Route `aos_patient_360_current_v3` through the same governed patient RPC bridge and always overwrite `p_token` with `getToken()` from the controlled service-worker cache.

## Security invariant
Browser-provided token values are not trusted as authority. The service worker owns token injection for governed patient RPCs.
