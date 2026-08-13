# ASCENDA OS — FASE 6 VALIDATION REPORT

**Fase:** Audience Library Persistence  
**Estado:** `100_COMPLETE`  
**Fecha:** 2026-08-13  
**Baseline de entrada:** `c5c3e8e669fbc5ee258bc89943bfa4885091d209`  
**Merge funcional staging:** `78da0bf4561f53100df17717051d2ab3db621040`

---

## Resultado ejecutivo

La Biblioteca Universal de Audiencias quedó implementada y validada de forma aditiva. Una definición de audiencia certificada por el Resolver V2 puede guardarse, versionarse, duplicarse, archivarse, restaurarse y reutilizarse sin convertirla todavía en snapshot, activación o asignación.

No se modificaron Call Center, `aos_siguiente_lead`, `aos_cola_config`, fuentes CRM/Agenda/Ventas ni la arquitectura legacy de Email.

---

## Persistencia certificada

Objetos nuevos:

- `aos_audiencias`;
- `aos_audiencia_versiones`;
- `aos_audiencia_audit`.

Contratos finales:

- definición `DYNAMIC`;
- nombre activo único case-insensitive;
- versiones inmutables;
- audit append-only;
- `current_version` protegido por FK diferible hacia la versión real;
- optimistic concurrency con `expected_version`;
- archive/restore, sin hard delete funcional;
- count-at-save + `resolved_at`, sin pretender snapshot de miembros.

No existe `aos_audiencia_miembros` en Fase 6. La congelación de miembros pertenece a Fase 7.

---

## QA transaccional sin residuos

QA live ejecutado dentro de subtransacción revertida al final.

PASS:

- CREATE crea versión 1;
- DSL inválido → `DSL_INVALID`;
- nombre activo duplicado → `NAME_CONFLICT`;
- UPDATE crea versión 2 y conserva versión 1;
- stale `expected_version` → `VERSION_CONFLICT`;
- DUPLICATE crea identidad independiente versión 1;
- ARCHIVE → `ARCHIVED`;
- RESTORE → `ACTIVE`;
- restore con nombre activo ocupado → `NAME_CONFLICT`;
- UPDATE directo de versión rechazado por inmutabilidad.

Post-QA y post-merge:

- audiencias de prueba: 0;
- versiones de prueba: 0;
- audit rows de prueba: 0;
- residuos `__P6_QA*`: 0.

La biblioteca se entrega limpia para datos reales.

---

## Seguridad

PASS:

- RLS habilitado en las tres tablas;
- `anon` y `authenticated` sin privilegios directos de tabla;
- RPC internos de biblioteca sin EXECUTE para `anon/authenticated`;
- gateway requiere sesión CIA ADMIN válida;
- token inválido en `LIST_AUDIENCES` → `UNAUTHORIZED`;
- payload limitado por gateway;
- listado limitado server-side a máximo 100;
- `service_role` reducido a SELECT directo sobre las tres tablas;
- mutaciones únicamente por RPC internos `SECURITY DEFINER` detrás del gateway;
- audit protegido contra UPDATE/DELETE;
- FK `(id,current_version) → (audiencia_id,version)` `DEFERRABLE INITIALLY DEFERRED`;
- versiones históricas no se reescriben.

---

## Frontend

Implementado en `app/public/`:

- pestaña `Audiencias`;
- activas / archivadas;
- creación desde Constructor;
- carga de audiencia al Constructor;
- nueva versión en vez de overwrite;
- historial de versiones;
- duplicado;
- archive/restore con modal ASCENDA;
- feedback de `VERSION_CONFLICT`;
- conteo rotulado explícitamente `Conteo al guardar`;
- módulos futuros bloqueados según roadmap.

Arquitectura:

- `admin-audiencias.html` conserva shell/estética ASCENDA;
- `admin-audiencias.js` separa lógica para mantenibilidad y CI;
- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- 0 lecturas directas `/rest/v1/aos_*` de tablas comerciales;
- biblioteca consumida exclusivamente mediante `aos_cia_admin_gateway_v1`.

Las audiencias archivadas no ofrecen entrada de edición; se consultan por historial y pueden restaurarse o duplicarse.

---

## Performance

Medición live:

- `LIST_AUDIENCES`: ~58 ms;
- `LEADS_UNWORKED` COUNT cold: ~1.238 s;
- `LEADS_UNWORKED` COUNT warm: ~142 ms.

PASS contra objetivo normal `<1.5 s`.

No se añadieron índices ni triggers a tablas operativas para lograr estos tiempos.

---

## Compatibilidad

### Call Center

Post-merge de Fase 6:

- 63 llamadas guardadas el 13-08-2026 al último smoke;
- escritura observada después del despliegue de las migrations de Fase 6;
- 0 archivos de Call Center dentro del diff;
- sin cambios a `aos_siguiente_lead` ni colas.

### Email legacy

- `aos_email_audiencias`: 0 filas;
- `aos_email_campanias`: 0 filas;
- FK `aos_email_campanias.audiencia_id` sigue apuntando a `aos_email_audiencias.id`.

No se realizó convergencia prematura. La futura integración consumirá la biblioteca universal de forma controlada.

---

## Replayability / migraciones

Las migrations Git fueron alineadas con las versiones registradas realmente por Supabase:

- `20260813190851_cia_audience_library_schema_v1.sql`;
- `20260813190951_cia_audience_library_rpcs_v1.sql`;
- `20260813191028_cia_admin_gateway_phase6_v1.sql`;
- `20260813192800_cia_audience_library_hardening_v1.sql`.

No existe drift de timestamps entre Git y `supabase_migrations.schema_migrations` para Fase 6.

---

## Integración

- PR funcional: **#65**;
- head auditado: `1c939652f2ee03eb5a17f67e23193385387393fd`;
- Ascenda CI run **#418: SUCCESS**;
- PR mergeable y sin conflictos;
- merge a staging: `78da0bf4561f53100df17717051d2ab3db621040`;
- post-merge compare: 0 archivos pendientes entre feature y staging;
- `admin-audiencias.js` verificado físicamente en staging.

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
- P6-G16 replayability + CI + PR: PASS
- P6-G17 staging post-merge: PASS
- P6-G18 roadmap + `aos_memory` checkpoint: PASS al completar el cierre formal de esta rama.

**Certificación:** Fase 6 cumple sus contratos y queda habilitada para cierre `100_COMPLETE`. Siguiente fase: **Fase 7 — Snapshots & Activation**.
