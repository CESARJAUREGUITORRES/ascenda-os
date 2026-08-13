# ASCENDA OS — FASE 6 VALIDATION REPORT

**Fase:** Audience Library Persistence  
**Estado:** VALIDATING  
**Fecha:** 2026-08-13  
**Baseline staging:** `c5c3e8e669fbc5ee258bc89943bfa4885091d209`

---

## Resultado ejecutivo

La Biblioteca Universal de Audiencias está implementada en modo aditivo y separada de snapshots, activaciones y asignaciones.

No se modificaron Call Center, `aos_siguiente_lead`, `aos_cola_config`, fuentes CRM/Agenda/Ventas ni la arquitectura legacy de Email.

---

## Evidencia de persistencia

Objetos nuevos:

- `aos_audiencias`
- `aos_audiencia_versiones`
- `aos_audiencia_audit`

Contratos:

- definición `DYNAMIC`;
- nombre activo único case-insensitive;
- versiones inmutables;
- audit append-only;
- `current_version` protegido por FK diferible hacia la versión real;
- optimistic concurrency con `expected_version`;
- archive/restore; sin DELETE funcional;
- count-at-save + `resolved_at`, sin pretender snapshot de miembros.

---

## QA transaccional sin residuos

El QA live ejecutó las mutaciones dentro de una subtransacción revertida al final.

PASS:

- CREATE crea versión 1;
- DSL inválido devuelve `DSL_INVALID`;
- nombre activo duplicado devuelve `NAME_CONFLICT`;
- UPDATE crea versión 2 y conserva versión 1;
- stale `expected_version` devuelve `VERSION_CONFLICT`;
- DUPLICATE crea identidad independiente versión 1;
- ARCHIVE cambia a `ARCHIVED`;
- RESTORE vuelve a `ACTIVE`;
- restore con nombre activo ocupado devuelve `NAME_CONFLICT`;
- UPDATE directo de versión es rechazado por inmutabilidad.

Post-QA live:

- audiencias: 0;
- versiones: 0;
- audit rows: 0;
- residuos `__P6_QA*`: 0.

La biblioteca queda limpia para uso real.

---

## Seguridad

PASS:

- RLS habilitado en las tres tablas;
- `anon` y `authenticated` sin privilegios directos de tabla;
- RPC internos de biblioteca sin EXECUTE para `anon/authenticated`;
- RPC internos disponibles a `postgres/service_role`;
- después del hardening, `service_role` tiene solo SELECT directo sobre las tres tablas;
- mutaciones se realizan por RPC `SECURITY DEFINER`;
- gateway público requiere sesión CIA ADMIN válida;
- token inválido en `LIST_AUDIENCES` devuelve `UNAUTHORIZED`;
- payload limitado por gateway;
- list limit forzado a máximo 100;
- audit protegido contra UPDATE/DELETE;
- FK `(id,current_version) → (audiencia_id,version)` es DEFERRABLE INITIALLY DEFERRED.

---

## Frontend

Implementado:

- pestaña `Audiencias`;
- biblioteca activas/archivadas;
- creación desde Constructor;
- carga de audiencia al Constructor;
- nueva versión en vez de overwrite;
- historial de versiones;
- duplicado;
- archive/restore mediante modal ASCENDA;
- feedback de `VERSION_CONFLICT`;
- conteo etiquetado explícitamente como `Conteo al guardar`;
- módulos futuros bloqueados según roadmap.

Arquitectura frontend:

- `admin-audiencias.html` conserva shell/estética ASCENDA;
- lógica separada en `admin-audiencias.js` para mantenibilidad y validación CI;
- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- 0 lecturas directas `/rest/v1/aos_*` de tablas comerciales;
- biblioteca consumida exclusivamente mediante `aos_cia_admin_gateway_v1`.

Audiencias archivadas no ofrecen entrada de edición; se consultan por historial y pueden restaurarse o duplicarse.

---

## Performance

Medición live:

- `LIST_AUDIENCES` vacío: ~58 ms;
- `LEADS_UNWORKED` COUNT cold: ~1.238 s;
- `LEADS_UNWORKED` COUNT warm: ~142 ms.

PASS contra objetivo normal <1.5 s.

No se añadieron índices/triggers a tablas operativas para conseguir estos tiempos.

---

## Compatibilidad

### Call Center

Durante Fase 6 se observan 60 llamadas guardadas el 13-08-2026 y una escritura posterior al despliegue de las migrations de Fase 6.

No existe archivo de Call Center dentro del diff de Fase 6.

### Email legacy

- `aos_email_audiencias`: 0 filas;
- `aos_email_campanias`: 0 filas;
- FK `aos_email_campanias.audiencia_id` continúa apuntando a `aos_email_audiencias.id`.

No se realizó convergencia anticipada con la biblioteca universal.

---

## Scope del diff

Esperado:

- panel Bases & Audiencias;
- JS dedicado del panel;
- Product/Impact document;
- Validation Report;
- migrations de biblioteca/gateway/hardening.

No esperado y no presente:

- `calls.js`;
- `admin-calls.html`;
- `aos_siguiente_lead`;
- Email campaign schema legacy;
- ventas/agenda/pacientes/leads operational writes.

---

## Gates

- P6-G01 baseline: PASS
- P6-G02 Impact Report pre-DDL: PASS
- P6-G03 schema/constraints: PASS
- P6-G04 RLS/GRANT: PASS
- P6-G05 immutable versions/audit: PASS
- P6-G06 CREATE + invalid DSL: PASS
- P6-G07 version creation/history: PASS
- P6-G08 optimistic concurrency: PASS
- P6-G09 duplicate: PASS
- P6-G10 archive/restore/name conflict: PASS
- P6-G11 list/get pagination/limit: PASS
- P6-G12 gateway authorization: PASS
- P6-G13 frontend contract: PASS
- P6-G14 resolver/performance: PASS
- P6-G15 Call Center/Email compatibility: PASS
- P6-G16 replayability + CI + PR: PENDING
- P6-G17 staging post-merge: PENDING
- P6-G18 roadmap + memory checkpoint: PENDING

Fase 6 no debe declararse `100_COMPLETE` hasta cerrar P6-G16…P6-G18.
