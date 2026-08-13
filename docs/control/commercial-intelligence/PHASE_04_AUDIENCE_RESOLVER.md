# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 4 — AUDIENCE RESOLVER

**Estado:** `100_COMPLETE`  
**Fecha de cierre:** 2026-08-13  
**Feature:** `feature/commercial-intelligence-phase4-audience-resolver-20260813`  
**PR feature → staging:** #59  
**CI:** Ascenda CI run 342 = SUCCESS  
**Merge funcional staging:** `26971547d22eccd496aa5fea67a61f109bec21ee`  
**Certificación detallada:** `PHASE_04_VALIDATION_REPORT.md`.

---

# 1. OBJETIVO CERRADO

Fase 4 establece el motor determinista que decide **quién pertenece a una audiencia** a partir de Identity V1 + Commercial Facts V1 + Segmentation V1 + Profile/Purchase Detail Facts.

No persiste audiencias de usuario, no asigna asesores, no activa campañas y no determina elegibilidad/disponibilidad por canal.

---

# 2. GATES

P4-G01…P4-G16 = PASS al persistir checkpoint final en `aos_memory`.

- P4-G01 Scope + Impact Report: PASS
- P4-G02 Profile Facts V1: PASS
- P4-G03 Filter Registry whitelist: PASS
- P4-G04 DSL validation/depth/rules: PASS
- P4-G05 deterministic evaluator/no dynamic SQL: PASS
- P4-G06 BOOLEAN3 + MATCH/MISS/UNKNOWN: PASS
- P4-G07 Product/Service reconciliation + safe negatives: PASS
- P4-G08 official presets: PASS
- P4-G09 count/preview/explain: PASS
- P4-G10 1:1 + live equivalence: PASS
- P4-G11 private-by-default security: PASS
- P4-G12 performance semantic budget: PASS
- P4-G13 tests/auditor versioned: PASS
- P4-G14 CI + staging integration: PASS
- P4-G15 production unchanged: PASS
- P4-G16 continuity: PASS al checkpoint final

---

# 3. CONTRATOS PRINCIPALES

- `aos_cia_profile_facts_v1`
- `aos_cia_audience_source_v1`
- `aos_cia_audience_source_v1_1`
- `aos_audience_filter_registry`
- `aos_audience_presets`
- `aos_cia_audience_validate_v1`
- `aos_cia_audience_count_v1`
- `aos_cia_audience_preview_v1`
- `aos_cia_audience_explain_v1`
- `aos_cia_purchase_detail_facts_v1`
- product catalog/alias reconciliation
- service family taxonomy

DSL V1:

- AND/OR;
- max 2 niveles de grupos;
- max 25 reglas;
- fields/operators whitelisted;
- preview max 100;
- SQL libre prohibido.

---

# 4. PROFILE / FUTURE FACTS

Baseline canónico:

- universe 11,473;
- canonical patients 7,041;
- sex known 6,476;
- age parseable 1,142.

Nuevos facts de ventana futura:

- `appointments.days_until_next`;
- `followups.days_until_next`.

54 contactos tienen cita futura; 34 están dentro de los próximos 7 días en el baseline de cierre.

---

# 5. PRODUCT / SERVICE FINAL

Producto full:

- 404 filas;
- 270 mapped high-confidence;
- 134 UNKNOWN;
- cobertura 66.8%.

Producto con contact_key válido:

- 403 filas;
- 269 mapped;
- 134 UNKNOWN;
- cobertura 66.7%.

146 contactos compradores producto; 75 con alguna evidencia producto unresolved.

Servicios:

- 871 filas;
- 773 categorizadas;
- 98 UNKNOWN;
- cobertura 88.7%.

No se usa fuzzy mapping agresivo.

`never_contains` conserva incertidumbre:

- target presente → MISS;
- ausente + unresolved=0 → MATCH;
- ausente + unresolved>0 → UNKNOWN.

Baseline:

- BEAUTY MAKER: 26 bought / 11,387 never-safe / 60 UNKNOWN;
- ISDIN: 20 bought / 11,392 never-safe / 61 UNKNOWN;
- ENZIMAS service category: 21 bought / 11,404 never-safe / 48 UNKNOWN.

---

# 6. PRESETS / PERFORMANCE

Presets principales:

- Leads sin trabajar: 1,287;
- Leads sin trabajar 7d: 115;
- No-show sin cita futura: 826;
- Seguimientos vencidos: 442;
- además: clientes inactivos, high-value cooling, product/service buyers, never-email-known y active prospects.

Benchmarks equivalentes live:

- product reconciliation ~204 ms;
- audiencia compleja Enzimas + unworked + no future appointment + no sale ~346 ms.

PASS contra budget P95 normal <1.5 s. No materialización/cache/indexes nuevos.

---

# 7. SEGURIDAD / CERTIFICATION SCOPE

- additive only;
- no `app/` runtime changes;
- no writes source;
- RLS en registries/taxonomies;
- PUBLIC/anon/authenticated revocados;
- service_role inicial;
- views security_invoker;
- sin SECURITY DEFINER;
- sin dynamic SQL.

Después del merge #59, producción continúa con 0 tablas/vistas Phase 4 físicas.

La semántica se validó read-only contra producción; migrations/tests están versionados e integrados a staging. No se afirma despliegue físico de DDL Phase 4 en Supabase productivo ni benchmark exacto del evaluator PL/pgSQL hasta ese gate.

---

# 8. SIGUIENTE FASE

## FASE 5 — PANEL CENTRAL SKELETON = READY

Debe crear el shell ADMIN read-only de **Bases & Audiencias**, consumir contratos controlados del Audience Resolver, respetar el Frontend Contract de ASCENDA y no recrear filtros en JavaScript ni acceder directamente a tablas fuente.
