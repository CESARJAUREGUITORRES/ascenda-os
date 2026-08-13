# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 4 — AUDIENCE RESOLVER

**Estado:** IN_PROGRESS  
**Fecha:** 2026-08-13  
**Rama:** `feature/commercial-intelligence-phase4-audience-resolver-20260813`  
**Base inicial staging:** `af7fbf93567a44b99d88327ceb359a1404346333`  
**Dependencias:** Identity V1 + Commercial Facts V1 + Segmentation V1.

---

# 1. OBJETIVO

Convertir las capas semánticas de ASCENDA en un motor universal y determinista de pertenencia a audiencias mediante un DSL declarativo, sin SQL libre desde frontend, IA o agentes.

Fase 4 decide **quién pertenece** a una audiencia. No persiste audiencias de usuario, no asigna asesores, no activa campañas y no decide elegibilidad/disponibilidad de canal.

Contratos mínimos:

- Filter Registry whitelisted;
- DSL `version=1`;
- AND/OR con máximo 2 niveles de grupos;
- máximo 25 reglas hoja;
- `count`;
- `preview` paginado, máximo 100;
- `explain` MATCH/MISS/UNKNOWN;
- presets oficiales;
- BOOLEAN3;
- Product/Service con reconciliación segura;
- Profile Facts demográficos/CRM;
- acceso inicial exclusivo `service_role`.

---

# 2. GATES

- P4-G01 Scope + Impact Report
- P4-G02 Profile Facts V1
- P4-G03 Filter Registry whitelist
- P4-G04 DSL validation/depth/rules
- P4-G05 Deterministic evaluator, no dynamic SQL
- P4-G06 BOOLEAN3 + three-state explain
- P4-G07 Product/Service reconciliation + safe negative semantics
- P4-G08 Official presets
- P4-G09 Count/Preview/Explain contracts
- P4-G10 1:1 invariants + live equivalence
- P4-G11 Security / private-by-default
- P4-G12 Performance budget
- P4-G13 Test/audit artifacts
- P4-G14 CI + feature integration to staging
- P4-G15 Production unchanged
- P4-G16 GitHub + `aos_memory` checkpoint / Phase 5 READY

Fase 4 solo pasa a `100_COMPLETE` cuando P4-G01…P4-G16 estén en PASS.

---

# 3. PROFILE FACTS V1

`aos_cia_profile_facts_v1` evita que Audience Resolver consulte `aos_pacientes` directamente.

Expone exclusivamente información CRM/demográfica comercial permitida:

- canonical name/email;
- patient state;
- base label/campaign;
- sede derivada;
- departamento/ciudad/distrito;
- sexo;
- edad derivada cuando DOB legacy es parseable;
- age band;
- patient/lead existence;
- identity conflict/status.

No incluye información clínica.

Baseline canonical:

- universe: 11,473;
- canonical patient: 7,041;
- sex known: 6,476;
- age parseable: 1,142;
- raw canonical patient branch: 197.

Sede puede usar fallback comercial de venta/cita; el origen físico no se reescribe.

---

# 4. FILTER REGISTRY

`aos_audience_filter_registry` es el allowlist de fields/operators.

La UI y KronIA solo pueden enviar claves registradas. Metadata `source_column` es informativa: **nunca se interpola como SQL**.

Categorías V1:

- CONTACT
- CRM / DEMOGRAPHIC
- LEAD
- CALL
- APPOINTMENT
- SALE / PRODUCT / SERVICE
- FOLLOWUP
- EMAIL
- SEGMENT

Cambiar semántica o añadir fields exige Fact Registry/migration/test.

---

# 5. DSL V1

Ejemplo:

```json
{
  "version": 1,
  "root": {
    "op": "AND",
    "rules": [
      {"field":"lead.unworked_since_latest_entry","operator":"is_true"},
      {"op":"OR","rules":[
        {"field":"segment.value_tier","operator":"in","value":["GOLD","DIAMANTE"]},
        {"field":"segment.engagement","operator":"eq","value":"HIGH"}
      ]}
    ]
  }
}
```

Límites:

- root debe ser AND/OR;
- máximo 2 niveles de grupos visuales;
- máximo 25 reglas hoja;
- campos y operadores whitelisted;
- enums validados;
- números tipados;
- fechas ISO para operadores absolutos;
- ninguna instrucción SQL.

---

# 6. BOOLEAN3 / EXPLAIN

Los facts con evidencia incompleta conservan TRUE/FALSE/UNKNOWN.

`aos_cia_audience_trace_node_v1` devuelve por regla:

- field/operator;
- expected;
- observed;
- `evaluation_state = MATCH | MISS | UNKNOWN`;
- reason code determinista;
- unresolved evidence cuando aplique.

AND:
- cualquier MISS → MISS;
- sin MISS y algún UNKNOWN → UNKNOWN;
- resto → MATCH.

OR:
- cualquier MATCH → MATCH;
- sin MATCH y algún UNKNOWN → UNKNOWN;
- resto → MISS.

Solo MATCH pertenece a la audiencia, salvo que el filtro solicite explícitamente `is_unknown`.

---

# 7. PRODUCT / SERVICE — CORRECCIÓN DE SESGO

`aos_ventas.tipo` distingue PRODUCTO/SERVICIO correctamente, pero para PRODUCTO `tratamiento` es casi siempre genérico. El detalle real está en `aos_ventas.descripcion`.

Se añade:

- `aos_cia_product_catalog_alias_v1`;
- `aos_cia_product_sale_reconciliation_v1`;
- `aos_cia_purchase_detail_facts_v1`;
- aliases explícitos high-confidence;
- service family taxonomy explícita.

Producto actual:

- 404 filas PRODUCTO fuente;
- 258 reconciliadas a catálogo con alta confianza = 63.9%;
- 146 filas quedan UNKNOWN;
- 146 contactos compradores producto;
- 77 contactos tienen al menos una compra producto unresolved.

Servicios tras extensión confirmada:

- 871 filas;
- 773 categorizadas = 88.7%;
- 98 categorías unresolved.

No se usa fuzzy matching agresivo.

## `never_contains`

`not_contains` ordinario NO es suficiente para responder “nunca compró X”.

Para `sales.products`, `sales.product_categories` y categorías de servicio se usa `never_contains`:

- target conocido presente → MISS;
- target ausente + unresolved=0 → MATCH;
- target ausente + unresolved>0 → UNKNOWN/no membership.

Ejemplos live:

- BEAUTY MAKER: 26 bought / 11,385 never-safe / 62 unknown;
- categoría ISDIN: 11 bought / 11,392 never-safe / 70 unknown;
- servicio ENZIMAS: 21 bought / 11,404 never-safe / 48 unknown.

---

# 8. PRESETS OFICIALES

`aos_audience_presets` contiene definiciones system-owned reutilizables, no audiencias guardadas por usuarios.

V1 incluye al menos:

- Leads sin trabajar;
- Leads sin trabajar 7d;
- No-show sin cita futura;
- Seguimientos vencidos;
- Clientes inactivos;
- Gold/Diamante cooling/inactive;
- Compradores producto;
- Compradores servicio;
- Nunca emailed con evidencia segura;
- Prospectos activos.

Baseline live destacado:

- Leads sin trabajar: 1,287;
- Leads sin trabajar 7d: 115;
- No-show sin cita futura: 826;
- Seguimientos vencidos: 442.

---

# 9. RESOLVER CONTRACTS

- `aos_cia_audience_validate_v1(filter)`
- `aos_cia_audience_count_v1(filter)`
- `aos_cia_audience_preview_v1(filter,limit,offset)`
- `aos_cia_audience_explain_v1(filter,contact_key)`

`preview` limita `limit` a 100.

Audience Source V1.1 conserva exactamente una fila por contact_key y agrega profile + commercial + segment + purchase-detail facts.

---

# 10. SECURITY / IMPACT REPORT

**Riesgo de migration:** MEDIUM/HIGH por superficie SQL nueva, pero impacto productivo cero mientras no se despliegue.

Añade únicamente objetos CIA aditivos. No modifica fuentes, Call Center, Email, RLS existente ni runtime.

Controles:

- no dynamic SQL (`EXECUTE`, `format` o interpolación de source_column);
- RLS en registries/taxonomies persistentes;
- revocado PUBLIC/anon/authenticated;
- acceso inicial service_role;
- views `security_invoker=true`;
- no SECURITY DEFINER;
- invalid field/operator → reject before evaluation.

Rollback: drop de funciones/views/tablas CIA de Fase 4 en orden inverso. No requiere restaurar filas operativas.

---

# 11. CRITERIO DE CIERRE

Antes de 100% deben pasar tests de registry/mapping, nesting, max rules, invalid field/operator, BOOLEAN3, product UNKNOWN, presets, 1:1, count/preview equivalence, explain state, performance, security, CI/staging, production unchanged y checkpoint de continuidad.
