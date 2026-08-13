# ASCENDA OS — FASE 6: AUDIENCE LIBRARY PERSISTENCE

**Estado inicial:** IN_PROGRESS  
**Fecha:** 2026-08-13  
**Baseline staging:** `c5c3e8e669fbc5ee258bc89943bfa4885091d209`  
**Supabase:** `ituyqwstonmhnfshnaqz`  
**Rama:** `feature/cia-phase6-audience-library`

---

## 1. OBJETIVO

Convertir una definición de audiencia ya validada por el Audience Resolver V2 en un objeto universal, persistente, versionado, auditable y reutilizable de ASCENDA.

Fase 6 implementa **biblioteca de definiciones**. No implementa snapshots de miembros, activaciones, asignaciones, ownership de asesores ni cambios en Call Center.

---

## 2. BASELINE LIVE / COMPATIBILIDAD

- No existe `aos_audiencias` universal en producción.
- Existen `aos_audience_filter_registry` y `aos_audience_presets` como contratos del resolver.
- Existe `aos_email_audiencias`, legacy y específica de Email; contiene 0 filas.
- `aos_email_campanias.audiencia_id` mantiene FK a `aos_email_audiencias.id`; `aos_email_campanias` contiene 0 filas.
- Fase 6 **no renombra, borra ni altera** esas tablas/FK legacy. La convergencia Email ↔ audiencia universal queda para la fase de integración de Email.
- `aos_siguiente_lead`, `aos_cola_config`, `aos_llamadas`, `calls.js` y fuentes operativas quedan fuera de scope.

---

## 3. MODELO CERRADO PARA FASE 6

### `aos_audiencias`

- `id uuid PK`
- `nombre text NOT NULL`
- `descripcion text`
- `tipo text NOT NULL DEFAULT 'DYNAMIC'`
- `estado text NOT NULL DEFAULT 'ACTIVE'`
- `schema_version integer NOT NULL DEFAULT 1`
- `current_version integer NOT NULL DEFAULT 1`
- `created_by_user_id uuid NOT NULL FK aos_usuarios(id)`
- `updated_by_user_id uuid NOT NULL FK aos_usuarios(id)`
- `created_at timestamptz`
- `updated_at timestamptz`
- `archived_at timestamptz`
- `archived_by_user_id uuid FK aos_usuarios(id)`

Reglas:
- Fase 6 solo crea definiciones `DYNAMIC`.
- No hard-delete.
- Nombre activo único case-insensitive.
- longitud nombre 3–120; descripción <= 1000.

### `aos_audiencia_versiones`

- `id uuid PK`
- `audiencia_id uuid FK aos_audiencias(id)`
- `version integer`
- `filter_dsl jsonb NOT NULL`
- `reason text`
- `count_cache integer`
- `resolved_at timestamptz`
- `created_by_user_id uuid FK aos_usuarios(id)`
- `created_at timestamptz`
- UNIQUE (`audiencia_id`,`version`)

Reglas:
- versión 1 al crear.
- editar crea nueva fila; nunca reescribe la versión anterior.
- trigger de inmutabilidad bloquea UPDATE/DELETE.
- DSL debe pasar `aos_cia_audience_validate_v1` antes de persistir.
- `count_cache` representa **conteo al guardar**, no membresía congelada ni conteo eternamente actual.

### `aos_audiencia_audit`

- `id bigserial PK`
- `audiencia_id uuid`
- `audiencia_version_id uuid nullable`
- `action text`
- `actor_user_id uuid`
- `before_state jsonb`
- `after_state jsonb`
- `created_at timestamptz`

Acciones V1: `CREATE`, `VERSION_CREATE`, `DUPLICATE`, `ARCHIVE`, `RESTORE`.

---

## 4. CONTRATOS DE MUTACIÓN

Todas las mutaciones se ejecutan server-side detrás del gateway CIA ADMIN.

### Create
- valida ADMIN activo;
- valida nombre y DSL;
- resuelve count live;
- crea audiencia + versión 1 en una transacción;
- audita.

### Update / New version
- exige `expected_version`;
- hace lock de la audiencia;
- si `expected_version != current_version` devuelve `VERSION_CONFLICT`;
- crea versión `current+1`;
- actualiza metadata y puntero `current_version`;
- no modifica versiones previas.

### Duplicate
- copia la versión actual a audiencia nueva versión 1;
- exige nombre nuevo;
- deja trazabilidad en audit.

### Archive / Restore
- cambia estado del contenedor, no las versiones;
- archived no aparece en listado normal;
- restore respeta unicidad de nombre activo.

No existe DELETE en Fase 6.

---

## 5. GATEWAY CIA — ACCIONES NUEVAS

- `LIST_AUDIENCES`
- `GET_AUDIENCE`
- `CREATE_AUDIENCE`
- `UPDATE_AUDIENCE`
- `DUPLICATE_AUDIENCE`
- `ARCHIVE_AUDIENCE`
- `RESTORE_AUDIENCE`

Los RPC internos quedan sin EXECUTE para `anon/authenticated`; el browser usa únicamente `aos_cia_admin_gateway_v1` con sesión CIA válida.

---

## 6. FRONTEND

`app/public/admin-audiencias.html` agrega pestaña **Audiencias**.

Debe permitir:
- listar activas / archivadas;
- cargar una audiencia al Constructor;
- guardar una nueva audiencia desde el Constructor;
- editar metadata/reglas generando nueva versión;
- ver historial de versiones;
- duplicar;
- archivar / restaurar;
- mostrar `conteo al guardar` + fecha de resolución para no confundirlo con conteo live.

Prohibido:
- `alert/confirm/prompt` nativos;
- SQL o lectura directa de tablas de biblioteca desde browser;
- acciones de Assignment/Activation;
- botones falsamente funcionales.

---

## 7. IMPACT REPORT

### Blast radius

Bajo/medio y aditivo:
- 3 tablas nuevas;
- RPC internos nuevos;
- extensión controlada del gateway CIA;
- modificación de un único panel frontend;
- sin triggers sobre tablas operativas;
- sin cambios en fuentes CRM/Call/Agenda/Ventas/Email legacy.

### Riesgos y mitigaciones

1. **Segunda fuente de verdad junto a Email legacy**  
   Mitigación: mantener legacy intacto y declarar `aos_audiencias` como biblioteca universal para nuevos usos; integración Email se hará explícitamente en su fase.

2. **Audience = snapshot por error**  
   Mitigación: Fase 6 no crea `aos_audiencia_miembros`; `count_cache` se etiqueta como conteo al guardar.

3. **Lost update entre dos administradores**  
   Mitigación: `expected_version` + row lock + `VERSION_CONFLICT`.

4. **Historial mutable**  
   Mitigación: trigger de inmutabilidad en versiones.

5. **Borrado accidental**  
   Mitigación: no DELETE; solo ARCHIVE/RESTORE.

6. **Nombre duplicado/ambiguo**  
   Mitigación: índice único parcial sobre `lower(btrim(nombre))` para ACTIVE.

7. **DSL inválido o fuera del registry**  
   Mitigación: validación determinista antes de INSERT + guard trigger.

8. **Conteo desactualizado malinterpretado**  
   Mitigación: almacenar `resolved_at` y UI explícita; al usar audiencia el Resolver vuelve a calcular live.

9. **Escalada por RPC directa**  
   Mitigación: RLS habilitado, sin políticas browser, REVOKE público y RPC internos service-role/postgres only; gateway verifica sesión CIA ADMIN.

10. **Acoplamiento con Call Center**  
    Mitigación: 0 cambios a `aos_siguiente_lead`, colas o writes operativos.

---

## 8. ROLLBACK

Mientras no existan dependencias de Fase 7+:
1. deshabilitar UI de biblioteca;
2. restaurar gateway anterior;
3. revocar/retirar RPC internos;
4. conservar tablas y datos como evidencia antes de cualquier DROP.

No se ejecutará DROP destructivo automático durante el rollout de Fase 6.

---

## 9. GATES DE CERTIFICACIÓN

- P6-G01 baseline Git/Supabase confirmado.
- P6-G02 Impact Report aprobado/documentado antes de DDL.
- P6-G03 tablas y constraints aditivos creados.
- P6-G04 RLS/GRANT seguros.
- P6-G05 versiones inmutables.
- P6-G06 CREATE válido y DSL inválido rechazado.
- P6-G07 UPDATE crea versión y preserva anterior.
- P6-G08 optimistic concurrency rechaza stale update.
- P6-G09 duplicate funciona sin compartir identidad/version rows.
- P6-G10 archive/restore + name conflict correctos.
- P6-G11 LIST/GET paginados y deterministas.
- P6-G12 gateway rechaza sesión inválida y expone solo acciones aprobadas.
- P6-G13 frontend sin diálogos nativos/lectura directa y UX ASCENDA.
- P6-G14 resolver live sigue correcto y Performance dentro de gate.
- P6-G15 Call Center / Email legacy sin regresión.
- P6-G16 migration replayable + CI SUCCESS + PR limpio/mergeable.
- P6-G17 staging post-merge validado.
- P6-G18 roadmap + `aos_memory` checkpoint final.

Solo con P6-G01…P6-G18 PASS: **FASE 6 = 100_COMPLETE** y Fase 7 = READY.
