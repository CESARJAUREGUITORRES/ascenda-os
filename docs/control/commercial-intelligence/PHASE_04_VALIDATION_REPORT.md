# ASCENDA OS — CIA PHASE 4 VALIDATION REPORT
## Audience Resolver V1

**Fecha de cierre:** 2026-08-13  
**Feature:** `feature/commercial-intelligence-phase4-audience-resolver-20260813`  
**PR feature → staging:** #59  
**CI:** Ascenda CI run 342 = SUCCESS  
**Merge funcional staging:** `26971547d22eccd496aa5fea67a61f109bec21ee`

---

# 1. RESULTADO

Fase 4 implementa en Git/staging el contrato de resolución universal de audiencias sobre Identity V1 + Commercial Facts V1 + Segmentation V1.

La fase decide pertenencia a audiencias. No persiste audiencias de usuario, no asigna asesores, no activa canales y no modifica Call Center.

Contratos principales versionados:

- `aos_cia_profile_facts_v1`;
- `aos_cia_audience_source_v1` / `v1_1`;
- `aos_audience_filter_registry`;
- `aos_audience_presets`;
- DSL validator/evaluator;
- `aos_cia_audience_count_v1`;
- `aos_cia_audience_preview_v1`;
- `aos_cia_audience_explain_v1`;
- Product/Service purchase reconciliation;
- MATCH/MISS/UNKNOWN explain traces.

No existe SQL libre generado por frontend/IA.

---

# 2. DSL / FILTER REGISTRY

DSL version: 1.

Restricciones:

- root AND/OR;
- máximo 2 niveles de grupos;
- máximo 25 reglas hoja;
- campos/operator allowlist;
- enum validation;
- numeric/date validation;
- unknown field/operator = invalid;
- preview clamp = 100.

Filter Registry V1 incorpora 73 fields declarados entre CONTACT, CRM/DEMOGRAPHIC, LEAD, CALL, APPOINTMENT, SALE, FOLLOWUP, EMAIL y SEGMENT.

`source_column` es metadata y nunca se concatena/interpola como SQL.

---

# 3. PROFILE FACTS

Se añadió una capa CRM/demográfica read-only para evitar queries directas de Audience Resolver a `aos_pacientes`.

Baseline canónico:

- universo Identity V1: 11,473;
- canonical patient: 7,041;
- canonical sex conocido: 6,476;
- edad canónica parseable/plausible: 1,142;
- sede explícita en canonical patient: 197.

El join normalizado con `aos_base_etiquetas` fue auditado: 0 contact_keys válidos duplicados.

Se añadieron facts numéricos de ventana futura:

- `appointments.days_until_next`;
- `followups.days_until_next`.

Baseline cita futura: 54 contactos; 34 dentro de 0–7 días.

---

# 4. PRODUCT / SERVICE RECONCILIATION

Hallazgo crítico: en ventas PRODUCTO, `tratamiento` es mayoritariamente genérico (`COMPRA DE PRODUCTO`), por lo que producto específico debe derivarse de `aos_ventas.descripcion`.

Se implementó reconciliación segura contra `aos_catalogo_servicios` + aliases explícitos.

## Producto

Fuente completa actual:

- 404 filas PRODUCTO;
- 270 mapped high-confidence;
- 134 UNKNOWN;
- cobertura full = 66.8%.

Sobre filas con contact_key Identity V1 válido:

- 403 filas;
- 269 mapped;
- 134 UNKNOWN;
- cobertura = 66.7%.

Contactos compradores PRODUCTO: 146.  
Contactos con al menos una compra producto unresolved: 75.

Todos los canonical targets de aliases existen en catálogo. No se usa fuzzy matching agresivo.

## Servicio

- 871 filas SERVICIO fuente;
- 773 categorizadas mediante family taxonomy confirmada;
- 98 category UNKNOWN;
- cobertura = 88.7%.

Casos sin equivalencia suficientemente inequívoca permanecen UNKNOWN.

---

# 5. SAFE NEGATIVE SEMANTICS

Se introdujo `never_contains` para responder correctamente “nunca compró X”.

Estados:

- target conocido presente → MISS;
- target ausente y unresolved=0 → MATCH;
- target ausente y unresolved>0 → UNKNOWN.

Baselines finales:

- BEAUTY MAKER: 26 bought / 11,387 never-safe / 60 UNKNOWN;
- categoría ISDIN: 20 bought / 11,392 never-safe / 61 UNKNOWN;
- categoría servicio ENZIMAS: 21 bought / 11,404 never-safe / 48 UNKNOWN.

Esto evita confundir ausencia del set conocido con evidencia de ausencia histórica total.

---

# 6. BOOLEAN3 / EXPLAIN

`aos_cia_audience_trace_node_v1` expone:

- observed;
- expected;
- MATCH/MISS/UNKNOWN;
- reason_code;
- unresolved evidence para negativos seguros.

AND aplica lógica three-state: MISS domina, luego UNKNOWN.  
OR aplica: MATCH domina, luego UNKNOWN.

Membership ordinaria incluye solo MATCH; facts UNKNOWN pueden consultarse explícitamente con `is_unknown`.

---

# 7. PRESETS

Presets system-owned versionados como DSL, sujetos al mismo validator:

- Leads sin trabajar;
- Leads sin trabajar 7d;
- No-show sin cita futura;
- Seguimientos vencidos;
- Clientes inactivos;
- Gold/Diamante cooling/inactive;
- compradores producto/servicio;
- Never emailed conocido;
- prospectos activos.

Baseline live:

- Leads sin trabajar: 1,287;
- Leads sin trabajar 7d: 115;
- No-show sin cita futura: 826;
- Seguimientos vencidos: 442.

---

# 8. TESTS / INVARIANTES

Versionados:

- `scripts/test_cia_audience_phase4_core.sql`;
- `scripts/test_cia_audience_phase4_edges.sql`;
- `scripts/test_cia_audience_phase4_time.sql`;
- `scripts/audit_cia_audience_phase4_readonly.sql`.

Los contract tests cubren:

- source 1:1;
- registry type mapping;
- todos los presets validables;
- reject unknown field/operator;
- nesting permitido/rechazado;
- max 25 rules;
- purchase totals reconciliation;
- aliases catalog-valid/unique;
- never_contains MATCH/MISS/UNKNOWN;
- BOOLEAN3 UNKNOWN;
- count/preview equivalence;
- preview <=100;
- direct evaluator equivalence;
- no dynamic SQL primitives;
- no browser-role direct grants;
- future-window facts.

Como las migrations no están desplegadas físicamente en producción, estos tests están versionados para ejecutarse en el gate de DB deployment. La semántica equivalente fue auditada read-only contra producción.

---

# 9. PERFORMANCE

Benchmarks equivalentes sobre datos vivos:

- product reconciliation representativa: ~204.35 ms;
- audiencia compleja Enzimas + opportunity unworked + no future appointment + no sale: ~345.85 ms.

Budget de producto: P95 normal <1.5 s.

Resultado semántico: PASS.

No se justifican materialización, cache ni índices nuevos en Phase 4.

Limitación explícita: no se afirma benchmark del overhead exacto PL/pgSQL hasta ejecutar migrations en un entorno DB desplegable.

---

# 10. SECURITY / BLAST RADIUS

Objetos persistentes nuevos usan RLS y quedan private-by-default.

- PUBLIC/anon/authenticated revocados;
- service_role inicial;
- views `security_invoker=true`;
- no SECURITY DEFINER;
- no dynamic SQL;
- no writes a pacientes/leads/llamadas/agenda/ventas/seguimientos;
- no runtime `app/` modificado;
- no Call Center modificado.

Después del merge #59, Supabase productivo fue verificado:

- tablas Phase 4 físicas: 0;
- vistas Phase 4 físicas: 0.

Producción permanece intacta.

---

# 11. CERTIFICATION SCOPE

La certificación Phase 4 significa:

1. contratos SQL versionados;
2. semántica auditada mediante equivalentes read-only sobre datos vivos;
3. product/service uncertainty explícitamente modelada;
4. test suites versionadas;
5. repository CI SUCCESS;
6. feature integrada a staging;
7. producción sin DDL Phase 4.

No significa que las migrations ya fueron ejecutadas físicamente en Supabase productivo ni que el frontend ya consuma el resolver.

---

# 12. DECISIÓN

Audience Resolver V1 queda aprobado como dependencia de Phase 5 — Panel Central Skeleton.

Phase 5 debe consumir estos contratos y no recrear filtros en JavaScript ni consultar tablas fuente directamente.
