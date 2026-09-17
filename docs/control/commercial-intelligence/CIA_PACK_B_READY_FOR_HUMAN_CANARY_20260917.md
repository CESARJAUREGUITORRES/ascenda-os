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
- Uses the current Auth V3 strong app session through `aos_cia_control_center_app_v1`.

## Controlled assignment and Call Center

- Human Canary action is bounded to one saved Audience → one advisor → one CALL/BATCH activation → ONE assignment strategy → source_limit=1 by UI default.
- `aos_siguiente_lead_v3` is now the advisor selector authority at the compatibility wrapper.
- V3 routing remains fail-closed/reversible: while global routing is OFF or advisor mode is V2_ONLY, certified V2 remains the result; V3 canary uses exact assigned work; unavailable V3 falls back to V2.
- Global Logic remains a compatibility fallback.

## Production safety readback before human canary

- `aos_cola_config` policies visible to browser roles: 0.
- anon SELECT: false.
- authenticated UPDATE: false.
- legacy queue advisors still in `global`: 4.
- `aos_cia_call_routing_control.global_enabled`: false.
- `aos_cia_control_center_app_v1`: present.
- invalid app token: UNAUTHORIZED.
- Human Canary #1 has NOT been executed by the assistant.

## Human Canary #1

Owner flow after final deploy:
1. Admin → Panel de Llamadas → `🎯 Audiencias`.
2. Select one governed preset; run Apply/Count and Preview 25.
3. Save the audience; reopen/select it from Library.
4. Select exactly one advisor.
5. `Iniciar Canary con 1 contacto`.
6. Open the advisor Call Center and request next lead.
7. Read back plan/assignment/advisor work and verify no duplication; confirm Global/V2 fallback remains for other/default workload.

**PACK-B is not CLOSED until this human canary passes. PACK-C remains blocked.**
