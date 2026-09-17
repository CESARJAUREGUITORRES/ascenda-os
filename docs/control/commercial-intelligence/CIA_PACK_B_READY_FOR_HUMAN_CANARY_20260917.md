# CIA-PANEL · PACK-B — READY FOR HUMAN CANARY #1

**Captured:** 2026-09-17 America/Lima  
**Product:** ASCENDA CLINIC / ASCENDA OS  
**Workstream:** Commercial Intelligence & Audience OS V3  
**State:** `TECHNICAL READY · STOP BEFORE HUMAN CANARY #1`

## Completed prerequisites

- P1 Segment freshness: PASS — 13,238/13,238 cache coverage; 0 missing; 0 orphan; 0 semantic divergences after governed refresh.
- P2 Queue governance: PASS — Auth V3 + ADMIN + 2FA + `admin-calls` gateway deployed; direct browser table policy removed; anon/authenticated direct table access revoked; four legacy advisors remain `global`.
- P3 Resolver UX/performance: PASS at product boundary — current benchmark remains deliberate-action latency (~3.36s count / ~2.41s preview-25), so the Control Center uses explicit Apply/Preview, 25-row pages, cancellation/single-flight and no polling/count-on-keystroke. No timeout inflation.

## Audience Control Center

- Reuses the existing 73-filter resolver and 10 governed presets.
- Reuses existing Audience Library persistence; no duplicate audience engine.
- Supports explicit count, preview, save and reopen/select from library.
- Uses the current Auth V3 strong app session through `aos_cia_control_center_app_v2`.
- Advisor selector is restricted to active advisors with `advisor-calls` access.
- Human Canary activation uses a two-step inline confirmation; no native browser `confirm()` dialog.

## Controlled assignment and Call Center

- Human Canary action is hard-bounded in DB to one saved Audience → one advisor → one CALL/BATCH activation → ONE assignment strategy → exactly `source_limit=1`.
- Only one PACK-B canary may be open at a time; start is blocked unless routing is at the V2 baseline.
- The selected advisor is armed as `V3_CANARY` while global routing is still OFF; only after that succeeds can the global V3 router be enabled.
- `aos_siguiente_lead_v3` is the advisor selector authority at the compatibility wrapper.
- Any advisor without explicit V3 mode remains `V2_ONLY` even while the global router is ON.
- V3 routing remains fail-closed: unavailable V3 falls back to certified V2.
- Global Logic remains a compatibility fallback.

## Reversible canary guard

- Control Center exposes `Verificar readback técnico` after activation.
- Control Center exposes `Revertir Canary · volver a V2`.
- Rollback sequence is fail-closed: global router OFF first → selected advisor route cleared → active plan cancelled/released → activation cancelled.
- `STOP_CANARY_ASSIGNMENT` validates that the supplied plan is a PACK-B canary and belongs to the selected advisor before cleanup.

## Production safety readback before human canary

- `aos_cola_config` policies visible to browser roles: 0.
- anon SELECT: false.
- authenticated UPDATE: false.
- legacy queue advisors still in `global`: 4.
- `aos_cia_call_routing_control.global_enabled`: false.
- no advisor-specific routing rows were present before canary hardening.
- `aos_cia_control_center_app_v2`: deployed additively; V1 remains available as compatibility authority for non-canary actions.
- invalid app token: UNAUTHORIZED.
- Human Canary #1 has NOT been executed by the assistant.

## Human Canary #1

Owner flow after final deploy:
1. Admin → Panel de Llamadas → `🎯 Audiencias`.
2. Select one governed preset; run Apply/Count and Preview 25.
3. Save the audience; reopen/select it from Library.
4. Select exactly one Call Center-enabled advisor.
5. Click `Preparar Canary con 1 contacto`; review the audience/advisor, then click `Confirmar Canary · 1 contacto` within 15 seconds.
6. Open the advisor Call Center and request next lead.
7. Return to Audience Control Center and run `Verificar readback técnico`.
8. After evidence is captured, use `Revertir Canary · volver a V2` unless the next explicitly authorized gate requires the canary to remain active.
9. Confirm routing global OFF and no residual active PACK-B plan/assignment before closing PACK-B.

**PACK-B is not CLOSED until this human canary passes. PACK-C remains blocked.**
