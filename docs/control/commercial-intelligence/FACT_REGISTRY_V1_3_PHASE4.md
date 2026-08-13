# ASCENDA OS — COMMERCIAL INTELLIGENCE FACT REGISTRY V1.3
## Phase 4 — Audience Resolver additions/overrides

**Estado:** CURRENT PHASE 4 CONTRACT  
**Fecha:** 2026-08-13  
**Base:** V1 + V1.1 + V1.2.  
**Regla:** este documento agrega/precisa facts necesarios para Audience Resolver; las claves no mencionadas conservan su definición previa.

---

# 1. PROFILE / DEMOGRAPHIC FACTS

| key | type | semantics | null |
|---|---|---|---|
| `contact.email_valid` | boolean3 | email canónico ausente=UNKNOWN; formato válido=TRUE; presente inválido=FALSE | UNKNOWN |
| `contact.exists_as_patient` | boolean | existe paciente canónico RESOLVED | FALSE |
| `contact.exists_as_lead` | boolean | lead_count > 0 | FALSE |
| `crm.patient_state` | text | estado de paciente canónico | UNKNOWN |
| `crm.base_label` | text | etiqueta canónica/operativa disponible | UNKNOWN |
| `crm.base_campaign` | text | campaña de `aos_base_etiquetas` cuando existe | UNKNOWN |
| `crm.branch` | text | sede: paciente → última venta → próxima cita → última cita | UNKNOWN |
| `crm.department` | text | departamento canónico | UNKNOWN |
| `crm.city` | text | ciudad canónica | UNKNOWN |
| `crm.district` | text | distrito canónico | UNKNOWN |
| `crm.sex` | text | sexo raw normalizado uppercase | UNKNOWN |
| `crm.age_years` | integer | edad derivada solo si DOB parseable y plausible 0–120 | UNKNOWN |
| `crm.age_band` | enum | UNDER_18 / 18_24 / 25_34 / 35_44 / 45_54 / 55_64 / 65_PLUS | UNKNOWN |

Profile Facts V1 no incluye historia clínica, diagnósticos, fotos, evoluciones ni notas médicas.

---

# 2. PURCHASE DETAIL FACTS

La definición anterior de `sales.products` queda precisada:

| key | type | semantics | null |
|---|---|---|---|
| `sales.products` | set | productos canónicos reconciliados desde `aos_ventas.descripcion` contra catálogo/aliases high-confidence | vacío |
| `sales.product_categories` | set | categorías de catálogo de productos reconciliados | vacío |
| `sales.product_unresolved_count` | integer | filas PRODUCTO sin reconciliación segura | 0 |
| `sales.services` | set | familias de servicio observadas en `aos_ventas.tratamiento` | vacío |
| `sales.service_categories` | set | categorías de servicio con taxonomía explícita high-confidence | vacío |
| `sales.service_category_unresolved_count` | integer | ventas servicio sin categoría segura | 0 |

`aos_ventas.tipo` continúa siendo verdad PRODUCTO/SERVICIO.

Para producto específico, `tratamiento='COMPRA DE PRODUCTO'` NO es identidad de producto; se usa `descripcion` reconciliada.

---

# 3. RECONCILIATION CONFIDENCE

Producto:

- `CATALOG_EXACT`: clave normalizada coincide unívocamente con `nombre`/`nombre_corto` de catálogo;
- `EXPLICIT_ALIAS`: alias legacy aprobado apunta a un único `nombre_corto` existente;
- `UNKNOWN`: evidencia no suficiente o ambigua.

Nunca se hace fuzzy mapping automático para resolver UNKNOWN.

Baseline:

- 404 filas PRODUCTO;
- 258 mapped (63.9%);
- 146 unresolved;
- 77 contactos tienen al menos una compra unresolved.

Servicio categoría:

- 871 filas;
- 773 mapped (88.7%);
- 98 unresolved.

---

# 4. SAFE NEGATIVE MEMBERSHIP

Nuevo operador para sets con evidencia potencialmente incompleta:

## `never_contains`

Semántica:

- si el target está presente → MISS;
- si target ausente y unresolved count = 0 → MATCH;
- si target ausente y unresolved count > 0 → UNKNOWN.

Esto es distinto de `not_contains`, que solo expresa ausencia dentro del set observado y no prueba ausencia histórica total.

Aplicación V1.3:

- `sales.products`;
- `sales.product_categories`;
- `sales.services` cuando existan filas de servicio sin familia;
- `sales.service_categories`.

Ejemplos live:

- Beauty Maker: 26 known bought / 11,385 never-safe / 62 UNKNOWN;
- ISDIN category: 11 known bought / 11,392 never-safe / 70 UNKNOWN;
- ENZIMAS service category: 21 known bought / 11,404 never-safe / 48 UNKNOWN.

---

# 5. AUDIENCE DSL V1

Formato:

```json
{"version":1,"root":{"op":"AND","rules":[]}}
```

Restricciones:

- máximo 2 niveles de **grupos** AND/OR;
- hojas no aumentan group depth;
- máximo 25 reglas hoja;
- unknown field = invalid;
- operator fuera de allowlist = invalid;
- enums contra valores permitidos;
- numeric operators requieren valores numéricos;
- between requiere 2 valores;
- fechas absolutas requieren ISO `YYYY-MM-DD...`;
- frontend/IA nunca envían SQL.

---

# 6. EVALUATION STATE

Cada rule/group expone:

- `MATCH`;
- `MISS`;
- `UNKNOWN`.

Membership ordinaria = solo MATCH.

BOOLEAN3 puede consultarse explícitamente mediante:

- `is_true`;
- `is_false`;
- `is_unknown`.

El trace explica UNKNOWN sin convertirlo a FALSE.

---

# 7. RESOLVER OBSERVABILITY

`count`, `preview` y `explain` deben devolver como mínimo:

- registry version;
- source version;
- observed timestamp;
- validation errors cuando existan.

Preview:

- limit mínimo 1;
- limit máximo 100;
- offset >=0;
- datos suficientes para administración, no dump de fuentes completas.

---

# 8. PRESET CONTRACT

Los presets oficiales son DSL versionado, system-owned y deben pasar el mismo validator que cualquier filtro externo.

Un preset NO es todavía una audiencia persistida por usuario.

---

# 9. SECURITY CONTRACT

Registry metadata nunca se usa para interpolar SQL. Los values se evalúan mediante mappings/funcciones fijas. `anon`/`authenticated` no reciben acceso directo V1.

La futura UI de Fase 5 consumirá contratos controlados; no tendrá lectura arbitraria de los views internos.
