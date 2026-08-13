# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 1 — IDENTITY RESOLVER

**Estado:** VALIDATING  
**Fecha:** 2026-08-13  
**Base de trabajo:** cierre Fase 0 `d6bd37edc57c177e81b074322de04639c9e83da8`  
**Rama:** `feature/commercial-intelligence-phase1-identity-20260813`  
**Supabase:** `ituyqwstonmhnfshnaqz`  
**Riesgo:** MEDIUM en código/migration propuesta; sin despliegue productivo durante este cierre.

---

# 1. OBJETIVO

Construir el contrato canónico de identidad V1 para que las fases posteriores trabajen contra un contacto lógico único sin reescribir datos fuente.

La fase debe resolver:

- normalización determinista de teléfono;
- universo de contactos válido por clave telefónica;
- selección segura de paciente canónico;
- detección explícita de conflictos;
- detección de filas `FUSIONADO`;
- flags de procedencia por fuente;
- carril de registros no resolubles;
- contrato preparado para futura evolución a `contact_id + aliases`.

Esta fase NO:

- cambia `numero_limpio`;
- fusiona pacientes;
- corrige filas históricas;
- reasigna teléfonos;
- usa email como llave automática de merge;
- cambia Call Center;
- expone nuevas escrituras al browser.

---

# 2. GATES

| Gate | Criterio | Estado |
|---|---|---|
| P1-G01 | Impact Report + invariantes | PASS |
| P1-G02 | Normalización `contact_key` definida | PASS |
| P1-G03 | Selección de paciente canónico definida | PASS |
| P1-G04 | Conflictos/FUSIONADO/UNKNOWN definidos | PASS |
| P1-G05 | Source flags y universo transversal definidos | PASS |
| P1-G06 | Migration backward-compatible versionada en Git | PASS |
| P1-G07 | Test SQL reproducible versionado | PASS |
| P1-G08 | Invariantes validados contra Supabase vivo | PASS |
| P1-G09 | Performance baseline del resolver | PASS |
| P1-G10 | Seguridad/privilegios nuevos cerrados por defecto | PASS |
| P1-G11 | Continuidad GitHub + `aos_memory` | PENDING FINAL CHECKPOINT |

La fase pasa a `100_COMPLETE` únicamente al persistir P1-G11.

---

# 3. CONTRATO DE NORMALIZACIÓN

Función propuesta: `aos_cia_normalize_contact_key_v1(text)`.

Reglas V1:

1. conservar únicamente dígitos;
2. 9 dígitos → clave válida;
3. 11 dígitos iniciando en `51` → usar los últimos 9;
4. cualquier otro formato → `NULL`;
5. nunca actualizar el valor fuente.

Ejemplos:

- `999 888 777` → `999888777`;
- `+51 999 888 777` → `999888777`;
- `12345` → `NULL`.

El `contact_key` V1 sigue siendo un puente técnico, NO la afirmación de que teléfono = persona para siempre.

---

# 4. UNIVERSO V1

Fuentes core:

- `aos_pacientes`;
- `aos_leads`;
- `aos_llamadas`;
- `aos_agenda_citas`;
- `aos_ventas`.

Snapshot live al validar la fase:

- contactos válidos normalizados: **11,473**;
- con paciente: **7,074**;
- con lead: **5,076**;
- con llamada: **5,885**;
- con cita: **1,157**;
- con venta: **296**;
- sin paciente: **4,399**.

El universo raw anterior era mayor porque contenía formatos no normalizables. Ningún registro inválido se borra; se conserva mediante auditoría `UNRESOLVED`.

---

# 5. PACIENTE CANÓNICO

Por cada `contact_key` se calculan:

- `patient_rows`;
- `non_fused_count`;
- `fused_count`.

Estados de identidad:

### `RESOLVED`
Existe exactamente un paciente no `FUSIONADO`.

- `canonical_patient_id` = ese paciente;
- nombre/email/demografía pueden consumirse como atributos del perfil.

### `CONFLICT`
Existen 2 o más pacientes no `FUSIONADO` con la misma clave.

- `identity_conflict = true`;
- `canonical_patient_id = NULL`;
- NO usar nombre/DNI/email para personalización automática;
- se conserva un `audit_selected_patient_id` determinista solo para inspección técnica.

### `FUSED_ONLY`
Solo existen filas de paciente `FUSIONADO`.

- `canonical_patient_id = NULL`;
- no resucitar el perfil absorbido.

### `NO_PATIENT_PROFILE`
El número existe en leads/llamadas/citas/ventas pero no hay paciente.

- contacto válido;
- atributos de paciente permanecen `NULL`.

---

# 6. RESULTADO LIVE VALIDADO

Distribución observada:

| Estado | Contactos | Paciente canónico |
|---|---:|---:|
| `RESOLVED` | 7,041 | 7,041 |
| `CONFLICT` | 23 | 0 |
| `FUSED_ONLY` | 10 | 0 |
| `NO_PATIENT_PROFILE` | 4,399 | 0 |
| **TOTAL** | **11,473** | **7,041** |

Conflictos `CONFLICT` observados: **23**.

Los 23 tienen actividad comercial; por ello ocultarlos o elegir silenciosamente un paciente sería un error de negocio.

---

# 7. EMAIL / ALIASES

Auditoría de `aos_pacientes`:

- 1,730 filas con email de formato utilizable;
- 1,641 emails distintos;
- 69 emails repetidos;
- 49 emails vinculan más de un teléfono válido;
- 28 pacientes tienen email utilizable pero no teléfono V1 válido;
- 115 no tienen ni teléfono V1 válido ni email utilizable.

Conclusión:

**email NO se usa como llave automática de fusión V1.**

Se considera atributo/alias candidato. Una futura capa `contact_id + aliases` podrá incorporar reglas de evidencia y reconciliación explícitas.

---

# 8. SOURCE FLAGS

Cada contacto expone:

- `has_patient_source`;
- `has_lead`;
- `has_call`;
- `has_appointment`;
- `has_sale`;
- `source_flags JSONB`.

Esto permite a Commercial Facts distinguir existencia en una fuente sin volver a reconstruir el universo.

---

# 9. UNRESOLVED LANE

La migration propuesta incluye una vista de auditoría con registros core que no pueden producir `contact_key` V1.

Campos mínimos:

- `source_type`;
- `source_record_id`;
- `raw_contact_value`;
- `digits_only`;
- `resolution_status` = `MISSING` o `INVALID_FORMAT`.

Esta vista existe para calidad de datos y futura reconciliación. No forma parte de las audiencias V1.

---

# 10. SEGURIDAD

Los nuevos objetos propuestos son únicamente de lectura.

Reglas de migration:

- `SECURITY INVOKER` para la view cuando sea soportado por el PostgreSQL del proyecto;
- revocar acceso de `PUBLIC`, `anon` y `authenticated` a los nuevos objetos V1;
- permitir acceso técnico controlado a `service_role`;
- no crear `SECURITY DEFINER`;
- no cambiar policies/RLS de tablas fuente;
- no exponer escritura.

La habilitación futura al browser se hará mediante RPC/endpoint autorizado de fases posteriores.

---

# 11. PERFORMANCE

Simulación completa del resolver sobre Supabase vivo:

- resultado: 11,473 contactos;
- `EXPLAIN (ANALYZE, BUFFERS)` observado: aproximadamente **148 ms** en ejecución medida;
- ranking de pacientes usa sort en memoria para ~7.5k filas válidas;
- unión de fuentes usa índices existentes donde aplica.

No se justifica materialización ni índice nuevo en Fase 1.

---

# 12. INVARIANTES VALIDADOS

Todos PASS:

- `unique_contact_key`;
- `all_keys_9_digits`;
- `resolved_has_canonical`;
- `nonresolved_has_no_canonical`;
- `canonical_never_fused`;
- `conflict_exactly_multi_nonfused`;
- normalización 9 dígitos;
- normalización prefijo `51`.

---

# 13. IMPACT REPORT

## Objetos fuente leídos

- `aos_pacientes`;
- `aos_leads`;
- `aos_llamadas`;
- `aos_agenda_citas`;
- `aos_ventas`.

## Objetos nuevos propuestos

- función `aos_cia_normalize_contact_key_v1`;
- view `aos_cia_contact_identity_v1`;
- view `aos_cia_identity_unresolved_v1`.

## Mutaciones de datos

Ninguna.

## Contratos productivos existentes modificados

Ninguno.

## Blast radius si se despliega

Lectura adicional únicamente. No se conecta todavía a frontend ni Call Center.

## Rollback

Migration reversa: drop de las dos views y función V1. Ninguna restauración de datos necesaria.

---

# 14. SALIDA DE FASE

Al completar P1-G11:

- Fase 1 → `100_COMPLETE`;
- Fase 2 → `READY`;
- siguiente fase: **Commercial Facts Engine**;
- Commercial Facts deberá consumir el contrato de identidad V1, no volver a deduplicar independientemente.
