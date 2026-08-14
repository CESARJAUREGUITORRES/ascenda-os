# ASCENDA OS — FASE 14 PRE-MERGE VALIDATION

**Fase:** Commercial Intelligence Shadow  
**Branch:** `feature/commercial-intelligence-phase14-shadow-20260814`  
**Baseline:** `b621332ec69142858588172b10ed14cc9d3ec271`  
**Fecha:** 2026-08-14 (America/Lima)

## Preflight
- F13→F14 `READY_NO_REQUESTS`, `ready_for_f14=true`.
- F11 sigue `READY_NO_LIVE_V3`; global routing V3 OFF.
- F9 assignments = 0; F13 requests = 0 al baseline.

## Source and performance decision
- commercial facts = 11,546; segments = 11,546; purchase-detail facts = 11,546.
- Diseño ingenuo facts+segments live rechazado: ~44,416.9 ms.
- Segment runtime cache refrescado y coverage exacta probada: 11,546/11,546.
- F14 persiste SHADOW snapshot; las listas online leen la persistencia, no recomputan las mega-vistas.

## Runtime F14
Primer run real SHADOW:
- run `56785a72-d99f-4688-804a-c06a001119f4`;
- 451 recomendaciones;
- batch ~4,205.7 ms;
- 253 HIGH_VALUE_ATTENTION;
- 104 FOLLOWUP_RECOVERY;
- 22 REACTIVATION;
- 72 REPURCHASE_SIGNAL;
- 0 UNWORKED_LEAD;
- confidence: 291 HIGH / 156 MEDIUM / 4 LOW;
- freshness: 111 FRESH / 45 AGING / 295 STALE / 0 UNKNOWN.

La antigüedad no se oculta: se etiqueta como freshness. STALE no se transforma en evidencia fresca ni se usa como permiso de acción.

## Security / governance
- 3 tablas F14: RLS=true, 0 policies, anon/authenticated direct table access=false.
- refresh/readiness/link-request internos: anon/auth EXECUTE=false.
- ADMIN gateway y advisor-list son las únicas superficies browser F14 y aplican auth/ownership respectivamente.
- invalid ADMIN token → UNAUTHORIZED.
- advisor inexistente → ADVISOR_NOT_FOUND.
- link inválido → RECOMMENDATION_NOT_FOUND.
- RELEASE_ASSIGNMENT proposal → REQUIRE_APPROVAL, auto_execute=false.
- AUTO_ASSIGN proposal → BLOCK.
- F14 recommendation state violations=0; auto_execute violations=0; missing GENERATED events=0.

El Security Advisor global conserva deuda histórica fuera de F14. `rls_enabled_no_policy` sobre la tabla privada F14 es consistente con el diseño fail-closed: RLS está activo, no existen policies y los grants directos están revocados; el browser usa RPC gobernada.

## Performance
- latest-run list, top 100: ~66.9 ms execution.
- F14→F15 readiness: ~54.1 ms execution.
- SHADOW batch: ~4.21 s para recalcular la capa derivada sobre 11,546 contactos; no es un request interactivo de lista.
- target interactivo <1.5 s: PASS.

## Replayability
Supabase live:
- `20260814181106_cia_phase14_intelligence_shadow_schema_v1.sql`
- `20260814181136_cia_phase14_intelligence_shadow_engine_v1.sql`
- `20260814181209_cia_phase14_intelligence_contracts_v1.sql`

Git filenames fueron reconciliados exactamente con `schema_migrations` live.

## F14 → F15
`aos_cia_intelligence_f15_readiness_v1()`:
- `ok=true`;
- `ready_for_f15=true`;
- `status=READY_SHADOW_ACTIVE`;
- 451 recommendations;
- browser direct table access false;
- REQUIRE_APPROVAL / BLOCK policy guards intactos.

Functional code is ready for PR/CI/staging smoke. Final certification waits for integration evidence and closure checkpoint.
