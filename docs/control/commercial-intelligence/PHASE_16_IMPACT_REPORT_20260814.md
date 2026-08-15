# ASCENDA OS — CIA V3 FASE 16 IMPACT REPORT

**Fase:** F16 — Email Integration  
**Estado:** `IN_PROGRESS / BASELINE + CRITICAL SECURITY PREFLIGHT`  
**Fecha:** 2026-08-14 (America/Lima)  
**Branch:** `feature/cia-phase16-email-integration-20260814`  
**Baseline GitHub staging:** `f0a087bd957dc19a81b5f8a0144b0bbc6a901549`  
**Supabase producción:** `ituyqwstonmhnfshnaqz`  
**Riesgo:** **CRITICAL** — delivery externo + secretos/provider + autorización + PII + ACL/RLS + webhook + legacy automation.  
**CI obligatorio:** ASCENDA Zero-Cost CI V2 (`self-hosted`, `Linux`, `X64`, `ascenda-zero-cost-v2`).

---

## 1. Objetivo

Integrar Email como primer **channel adapter gobernado** sobre Audience/Activation central, sin crear un Audience Engine paralelo, sin enviar desde F15 preview y sin romper el email legacy durante la transición.

Contrato objetivo:

`Audience/Activation → Email Eligibility/Preview → immutable Send Request → Queue/Dispatch → Provider Adapter → Delivery Outcome → Attribution/Audit`

Separaciones obligatorias:

- Audience ≠ Email eligibility.
- Email eligibility ≠ consent.
- Preview ≠ send permission.
- Send request ≠ provider delivery.
- Provider accepted ≠ delivered.
- Recommendation/Agent interpretation ≠ authority.
- Transactional/Auth email ≠ marketing email.

---

## 2. Bootstrap / recovery verificado

Antes de escribir se verificó:

- `AGENTS.md` CURRENT desde `infra/zero-cost-ci-v2`;
- `SECURITY.md` CURRENT desde `infra/zero-cost-ci-v2`;
- `docs/control/ASCENDA_CONTROL_MASTER.md`;
- `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md` CURRENT/V2;
- `docs/control/ASCENDA_ZERO_COST_CI_V2_HANDOFF.md` CURRENT;
- CIA `CIA_AGENT_BOOTSTRAP_CURRENT.md`, `CIA_MASTER_ALIGNMENT_CURRENT.md`, `ROADMAP_STATUS.md` desde `staging`;
- `staging` live = `f0a087bd957dc19a81b5f8a0144b0bbc6a901549`;
- F15→F16 Supabase live = `READY_GOVERNED_ORCHESTRATION`, `ready_for_f16=true`;
- PR infra #97 continúa OPEN sobre SHA `5b38155cf116b3de512b78f0059ba73b0dd17f93`, con jobs Zero-Cost queued/pending y sin fallback facturable.

**Regla:** no mover el HEAD de PR #97 desde este workstream. F16 puede desarrollar en branch aislada, pero su gate final de GitHub deberá ejecutarse con Zero-Cost CI V2 y SHA exacto antes de release.

---

## 3. Runtime productivo Email identificado

### Frontend

`app/public/admin-email.html`

Estado observado:

- panel operativo de Email Marketing;
- dashboard, bandeja, flujos, plantillas y campaña;
- consulta Supabase desde browser mediante clave pública/anon;
- usa RPC legacy `aos_email_buscar_paciente`, `aos_email_historial_paciente`, `aos_email_dashboard`;
- lectura directa de tablas Email desde browser;
- envío manual mediante `/api/send-email`.

### Backend

`app/server.js`

Superficies Email encontradas:

- `/api/send-email`;
- `/api/send-template`;
- `/api/send-2fa`;
- `/api/resend-webhook`;
- endpoints/stats Resend;
- motor CARTERO / agentes para recordatorio, recibo, seguimiento, reactivación, cumpleaños, saldos, no-asistencia, reposición, predicciones y flujos multi-paso;
- retry de fallidos;
- provider Resend;
- persistencia en tablas `aos_email_*` / `aos_emails_*`.

### Incidente legacy ya corregido y preservado

`EMAIL_FLOW_NULL_LEAK_20260812.md` documenta el bug histórico donde PATCH se ejecutaba como POST y se perdía el query string. El runtime actual filtra `flujo_id=not.is.null`; Supabase live confirma:

- active null flow = 0;
- active valid flow = 337;
- historial cancelado/null conservado = 13,617.

F16 no debe reintroducir ese bug ni borrar evidencia histórica.

---

## 4. Baseline Supabase Email — read-only

Objetos legacy identificados: **11 tablas**.

| Objeto | Filas live | RLS |
|---|---:|---|
| `aos_email_alertas` | 2,356 | OFF |
| `aos_email_audiencias` | 0 | OFF |
| `aos_email_cadencia` | 1,809 | OFF |
| `aos_email_campanias` | 0 | OFF |
| `aos_email_envios` | 19 | OFF |
| `aos_email_eventos` | 1,023 | OFF |
| `aos_email_flujo_ejecuciones` | 13,954 | OFF |
| `aos_email_flujos` | 5 | OFF |
| `aos_email_plantillas` | 29 | OFF |
| `aos_emails_empresa` | 1 | OFF |
| `aos_emails_enviados` | 1,953 | OFF |

Estados observados:

- `aos_email_envios`: 17 `enviado`, 2 `error`;
- `aos_email_flujo_ejecuciones`: 337 `activo`, 13,617 `cancelado`.

No se extrajo ni persistió PII/PHI en documentación o CI.

CIA ya posee contratos previos relevantes:

- `aos_cia_email_adapter_v2`;
- `aos_cia_email_facts_v1`;
- `aos_cia_email_runtime_cache_v2` (RLS ON, ~11.5k rows);
- Audience/Profile adapters con `email_valid` y bounce facts.

F16 debe consumir estos contratos en vez de duplicarlos.

---

## 5. Hallazgos CRITICAL / HIGH de preflight

### F16-C01 — ACL legacy Email excesivamente abierta — CRITICAL

Las 11 tablas Email legacy tienen RLS OFF y `anon` + `authenticated` conservan privilegios amplios de tabla, incluyendo SELECT/INSERT/UPDATE/DELETE y privilegios adicionales.

Impacto:

- browser/cliente no confiable puede alcanzar superficie Email directamente según grants actuales;
- contiene destinatarios, historial de envíos, templates, flujos y eventos;
- cerrar grants sin migration progresiva rompería el panel y workers legacy que todavía consumen ese contrato.

**Tratamiento:** migration progresiva, gateway/RPC server-authoritative, consumer matrix y canary antes de REVOKE final. No hacer big-bang.

### F16-C02 — Endpoints de envío no demuestran autorización server-side — CRITICAL

Los endpoints de envío Email observados aceptan POST y configuran CORS permisivo. En el bloque observado no existe un gate de sesión/rol previo equivalente al CIA ADMIN gateway.

**Tratamiento:** separar endpoint público/browser de provider dispatch; exigir identidad/sesión server-authoritative y scope ADMIN/servicio interno. Negative auth obligatorio en Zero-Cost Staging.

### F16-C03 — Provider credential con fallback hardcodeado en runtime — CRITICAL

`app/server.js` contiene fallback literal para credencial del provider cuando falta la variable de entorno. El valor NO se reproduce en este documento.

Consecuencias:

- remover el literal del HEAD no basta si el secreto fue válido/expuesto en historial;
- requiere rotación controlada del secreto del provider;
- afecta también rutas transaccionales/Auth que comparten provider, por lo que no se cambia de forma aislada ni se rompe 2FA.

**Tratamiento:** secret rotation + environment-only + smoke Auth/2FA + Email. La rotación/cutover productivo requiere autorización explícita.

### F16-C04 — Webhook provider sin evidencia de verificación criptográfica — CRITICAL

El handler `/api/resend-webhook` procesa payload del provider; en el baseline no se encontró integración de firma tipo Svix/webhook secret.

**Tratamiento:** firma obligatoria + replay window/idempotency + rejection de payload forged en Zero-Cost tests antes de confiar eventos de delivered/open/click/bounce.

### F16-H01 — Browser consulta datos Email/PII directamente — HIGH

`admin-email.html` usa acceso Supabase desde browser para RPC y lectura directa. El panel debe migrar progresivamente a un gateway ADMIN gobernado.

### F16-H02 — Consent/suppression marketing no tiene fuente autoritativa explícita — HIGH

Se observan facts de `email_valid` y bounce, pero no se detectó una fuente canónica de opt-in marketing/unsubscribe/suppression en el dominio Email. `consentimiento_general` clínico no debe reinterpretarse automáticamente como consentimiento comercial.

**Regla fail-closed:** ausencia de consentimiento comercial autoritativo = `UNKNOWN`, nunca TRUE.

### F16-H03 — Delivery está acoplado a múltiples caminos legacy — HIGH

Manual send, templates, CARTERO, flows y retries pueden enviar. F16 debe evitar múltiples productores de envío sin idempotency global.

---

## 6. Scope F16

### Dentro de F16

1. contrato canónico Email sobre Audience/Activation;
2. propósito de mensaje `TRANSACTIONAL | AUTH | MARKETING | OPERATIONAL` separado;
3. eligibility/preview/freshness;
4. template/campaign versioning;
5. send request inmutable + idempotency key;
6. queue/dispatch separada de provider outcome;
7. provider adapter Resend desacoplado del Audience Engine;
8. webhook verification + event idempotency;
9. bounce/suppression/unsubscribe semantics;
10. ADMIN gateway server-authoritative;
11. migration progresiva de ACL legacy;
12. audit end-to-end;
13. legacy fallback/canary;
14. output reusable F17.

### Fuera de scope / coordinado

- no rediseñar toda Auth/2FA dentro de F16;
- no cerrar KronIA V2 K0–K8;
- no migrar todos los providers futuros;
- no usar clinical history/photos/diagnoses/notes como features comerciales;
- no crear una nueva Audience DB paralela;
- no borrar historial Email legacy;
- no rotar secretos productivos sin gate/autorización.

---

## 7. Arquitectura objetivo incremental

### Plane A — Read/Preview

`Audience/Activation + CIA Email facts → aos_cia_email_eligibility_v1 → Preview`

Output mínimo:

- contact identity estable;
- email normalizado;
- email_valid;
- bounced/suppressed status;
- consent status `ALLOWED | BLOCKED | UNKNOWN` por propósito;
- reason codes;
- freshness;
- audience/activation provenance;
- `send_allowed=false` en preview.

### Plane B — Send Request

Nueva persistencia privada F16 con:

- request_id UUID;
- activation/audience provenance;
- purpose;
- recipient identity;
- template_id + immutable template_version/digest;
- idempotency_key UNIQUE;
- state machine;
- requested_by + authorization provenance;
- scheduled_at;
- created_at.

No guardar secretos.

### Plane C — Dispatch / Provider

Solo backend autorizado puede pasar `QUEUED → DISPATCHING` y llamar provider.

- retry controlado;
- no duplicar send si provider accepted/idempotency ya existe;
- provider response separada del estado final de delivery;
- rate/error boundaries.

### Plane D — Outcomes

Webhook verificado produce eventos append-only e idempotentes:

`ACCEPTED | DELIVERED | BOUNCED | COMPLAINED | OPENED | CLICKED | FAILED` según señal real disponible.

No tratar OPEN/CLICK como autoridad comercial; son observaciones.

---

## 8. Consumer matrix inicial

| Consumidor | Estado | Acción F16 |
|---|---|---|
| `admin-email.html` | legacy productivo | adapter/gateway gradual |
| `/api/send-email` | productivo | auth + request boundary |
| `/api/send-template` | productivo | auth/purpose + request boundary |
| `/api/send-2fa` | productivo/Auth | preservar; coordinar security/secret rotation |
| `/api/resend-webhook` | productivo | firma + idempotency |
| CARTERO agentes | productivo | adapter progresivo + idempotency |
| multi-step flows | productivo | mantener 337 activos; adapter gradual |
| retries | productivo | dedup/idempotency central |
| CIA F15 preview | governed shadow | continúa non-sending |
| F17 | futuro | consume contract reusable |

---

## 9. Plan Zero-Cost CI V2

Fixtures **100% sintéticos**:

- contactos ficticios;
- emails `example.test` / dominios reservados;
- provider stub local; nunca provider real;
- fake webhook signatures/fixtures de test;
- sin service-role/prod secrets;
- sin pacientes, teléfonos, DNI, emails reales o PHI.

Gates mínimos:

1. migration replay exacta;
2. DB lint;
3. positive/negative ACL/RLS;
4. invalid/forged session blocked;
5. send request idempotency;
6. retry does not duplicate;
7. UNKNOWN consent fails closed for MARKETING;
8. AUTH/transactional policy separada;
9. webhook valid signature accepted;
10. forged/replayed webhook rejected;
11. provider stub timeout/error/retry;
12. legacy fallback contract;
13. rollback/recovery;
14. zero residue;
15. no secret scan findings in changed scope;
16. exact SHA certified on `ASCENDA-ZERO-COST-V2`.

No `ubuntu-latest`, `windows-latest` ni `macos-*` como fallback.

---

## 10. Production read-only preflight obligatorio

Antes del primer cutover:

- revalidar RLS/grants live;
- checksums de funciones/endpoints/migrations;
- counts y states sin leer PII;
- confirmar 337 flujos activos o nuevo valor live;
- identificar runtime commit efectivamente desplegado;
- comprobar provider config por presencia, nunca imprimir secreto;
- verificar 2FA/Auth health sin mutación;
- verificar F15→F16 readiness;
- asegurar que el legacy path sigue disponible para rollback/canary.

---

## 11. Canary / cutover propuesto

Orden de menor blast radius:

1. shadow preview únicamente;
2. ADMIN gateway read-only;
3. un envío sintético/controlado del adapter fuera de pacientes reales si el provider permite sandbox/test;
4. canary ADMIN de una operación Email explícitamente autorizada;
5. mover un único path legacy al new dispatch adapter;
6. observar outcomes/retry/idempotency;
7. expandir por path, no big-bang;
8. solo después revocar acceso directo legacy correspondiente.

Cualquier envío productivo real o rotación de secreto requiere autorización explícita del propietario después del preflight.

---

## 12. Rollback / recovery

- features/gate de F16 deben poder quedar OFF sin afectar legacy;
- migrations iniciales serán additive/backward-compatible;
- no DROP/TRUNCATE/DELETE de Email legacy;
- no REVOKE final antes de gateway/canary;
- adapter nuevo puede deshabilitarse y devolver tráfico al legacy durante transición;
- webhook nuevo puede quedar shadow-log-only antes de authoritative processing;
- secret rotation tendrá plan de rollback de configuración sin reintroducir secreto hardcodeado.

---

## 13. Gates de cierre F16

F16 NO se declarará `100_COMPLETE` mientras alguno permanezca abierto:

- [x] Recovery CURRENT + live state.
- [x] F15→F16 readiness PASS.
- [x] Baseline Email runtime + DB inventory.
- [x] Impact Report CRITICAL.
- [x] Branch aislada.
- [ ] Contratos/migrations F16 implementados.
- [ ] Consumer compatibility tests.
- [ ] Zero-Cost Staging PASS en SHA final.
- [ ] Security negatives PASS.
- [ ] Secret/provider hardening coordinado.
- [ ] Production read-only preflight final PASS.
- [ ] Autorización explícita de cutover productivo.
- [ ] Canary PASS.
- [ ] Post-deploy smoke/reconciliation PASS.
- [ ] Rollback/recovery verificado.
- [ ] Output F17 readiness PASS.
- [ ] GitHub / `aos_memory` / Notion reconciliados.

---

## 14. Próxima acción segura

Implementar primero en esta branch el **read/preview + private send-request contracts** y los tests sintéticos/negative-auth correspondientes, sin activar delivery real ni cambiar ACL productiva. Mantener PR #97 congelado y permitir que su único runner procese la cola secuencialmente.
