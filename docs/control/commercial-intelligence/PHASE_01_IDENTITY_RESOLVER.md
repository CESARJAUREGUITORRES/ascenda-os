# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 1 — IDENTITY RESOLVER

**Estado:** `100_COMPLETE`  
**Progreso:** 100%  
**Fecha de cierre:** 2026-08-13  
**Feature branch:** `feature/commercial-intelligence-phase1-identity-20260813`  
**Merge staging:** `e7746797c9b8fa407eb25c7b81afcb7179f62e6a`  
**PR de integración:** #50  
**CI:** Ascenda CI run 274 = SUCCESS  
**Producción:** SIN CAMBIOS; `main` y Supabase live no recibieron objetos `aos_cia_*`.

---

# 1. OBJETIVO CERRADO

Fase 1 establece el contrato canónico de identidad V1 para que Commercial Facts, Audience Engine y fases posteriores trabajen contra una sola definición de contacto lógico.

No se reescribió `numero_limpio`, no se fusionaron pacientes y no se modificó Call Center.

---

# 2. GATES FINALES

| Gate | Criterio | Estado |
|---|---|---|
| P1-G01 | Impact Report + invariantes | PASS |
| P1-G02 | Normalización `contact_key` | PASS |
| P1-G03 | Paciente canónico | PASS |
| P1-G04 | Conflictos/FUSIONADO/UNKNOWN | PASS |
| P1-G05 | Source flags/universo | PASS |
| P1-G06 | Migration versionada | PASS |
| P1-G07 | Tests SQL reproducibles | PASS |
| P1-G08 | Validación contra Supabase vivo | PASS |
| P1-G09 | Performance baseline | PASS |
| P1-G10 | Nuevos privilegios cerrados por defecto | PASS |
| P1-G11 | Integración staging + continuidad | PASS |

**Resultado: 11/11 gates PASS.**

---

# 3. CONTRATO `contact_key` V1

Función versionada:

`aos_cia_normalize_contact_key_v1(text)`

Reglas:

1. remover caracteres no numéricos;
2. 9 dígitos → clave válida;
3. `51` + 9 dígitos → últimos 9 dígitos;
4. otros formatos → `NULL`;
5. jamás modificar el valor fuente.

`contact_key` es un puente V1. La arquitectura sigue preparada para `contact_id + aliases`.

---

# 4. UNIVERSO VALIDADO

Sobre las cinco fuentes core:

- `aos_pacientes`;
- `aos_leads`;
- `aos_llamadas`;
- `aos_agenda_citas`;
- `aos_ventas`.

Resultado live normalizado:

- **11,473** contactos válidos únicos;
- **7,074** con fuente paciente;
- **5,076** con lead;
- **5,885** con llamada;
- **1,157** con cita;
- **296** con venta;
- **4,399** sin perfil paciente.

---

# 5. ESTADOS DE IDENTIDAD

| Estado | Contactos | Canonical patient |
|---|---:|---:|
| `RESOLVED` | 7,041 | 7,041 |
| `CONFLICT` | 23 | 0 |
| `FUSED_ONLY` | 10 | 0 |
| `NO_PATIENT_PROFILE` | 4,399 | 0 |
| **TOTAL** | **11,473** | **7,041** |

Reglas:

- `RESOLVED`: exactamente un paciente no `FUSIONADO` → perfil canónico seguro.
- `CONFLICT`: más de un no fusionado → `canonical_patient_id = NULL`.
- `FUSED_ONLY`: no resucitar perfiles absorbidos.
- `NO_PATIENT_PROFILE`: contacto válido operativo aunque no exista en pacientes.

El resolver conserva `audit_selected_patient_id` únicamente para inspección técnica; no debe usarse para personalización cuando existe conflicto.

---

# 6. EMAIL Y ALIASES

Auditoría:

- 1,730 filas paciente con email de formato utilizable;
- 1,641 emails distintos;
- 69 emails repetidos;
- 49 emails asociados a más de un teléfono válido;
- 28 pacientes con email utilizable pero sin teléfono V1 válido;
- 115 sin teléfono V1 válido ni email utilizable.

**Decisión:** email no es llave automática de merge V1. Es atributo/alias candidato para una futura reconciliación explícita.

---

# 7. OBJETOS VERSIONADOS

Migration:

`supabase/migrations/20260813061200_cia_identity_resolver_v1.sql`

Objetos nuevos previstos al promover la migration:

- `aos_cia_normalize_contact_key_v1`;
- `aos_cia_contact_identity_v1`;
- `aos_cia_identity_unresolved_v1`.

Scripts:

- `scripts/audit_cia_identity_resolver_phase1_readonly.sql`;
- `scripts/test_cia_identity_resolver_phase1.sql`.

---

# 8. SEGURIDAD

La migration:

- crea únicamente objetos de lectura;
- usa view `security_invoker`;
- no crea `SECURITY DEFINER`;
- no modifica RLS de tablas existentes;
- revoca acceso de `PUBLIC`, `anon`, `authenticated` sobre los nuevos objetos;
- reserva acceso técnico inicial a `service_role`;
- no contiene UPDATE/DELETE/INSERT sobre datos operativos.

PostgreSQL live verificado: 17.6. Roles `anon`, `authenticated` y `service_role` existen.

---

# 9. INVARIANTES LIVE

Todos PASS:

- claves únicas;
- todas las claves válidas tienen 9 dígitos;
- `RESOLVED` siempre tiene canonical patient;
- estados no resueltos nunca reciben canonical patient;
- canonical patient nunca es `FUSIONADO`;
- `CONFLICT` implica múltiples pacientes no fusionados;
- prefijo `51` normaliza correctamente;
- formato 9 dígitos normaliza correctamente.

---

# 10. PERFORMANCE

Simulación read-only del resolver completo sobre la base viva:

- 11,473 filas de salida;
- ejecución observada aproximada: **148 ms**;
- no se justificó índice/materialización adicional en esta fase.

---

# 11. INTEGRACIÓN Y ROLLBACK

La feature se sincronizó con staging antes de integración.

- staging divergía inicialmente por una corrección independiente de Comisiones;
- PR #49 sincronizó staging → feature;
- CI del feature: SUCCESS;
- PR #50 integró feature → staging;
- merge staging: `e7746797c9b8fa407eb25c7b81afcb7179f62e6a`;
- producción fue verificada después del merge y continúa sin objetos `aos_cia_*`.

Rollback si la migration futura se despliega: eliminar exclusivamente las dos views y la función V1. No requiere restauración de datos porque no existe mutación de fuentes.

---

# 12. CONTRATO PARA FASE 2

**FASE 2 — COMMERCIAL FACTS = READY.**

Commercial Facts debe consumir Identity Resolver V1 como única semántica de identidad y no implementar deduplicación paralela.

Prioridades de Fase 2:

- Call facts;
- Agenda facts;
- Sales/Product/Service facts;
- Follow-up facts;
- Lead facts;
- Email facts con identidad parcial/UNKNOWN;
- freshness y provenance;
- benchmarks y agregaciones 1:1 por `contact_key`.
