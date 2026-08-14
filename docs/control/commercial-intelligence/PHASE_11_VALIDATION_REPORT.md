# ASCENDA OS — FASE 11 VALIDATION REPORT

**Fase:** Call Center Integration V3  
**Estado:** VALIDATING — funcionalmente completa, pendiente PR/CI/staging/closure  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `76e5b3b609cb52f4b9a0b8c2289dea4a1fca2c64`

---

## 1. Resultado ejecutivo

F11 implementa una ruta V3 paralela y reversible sin modificar las RPC legacy madre.

Contrato:

`F8 available_now → F9 assignment lease → F10 readiness → F11 dispatcher/claim/consume → F12 Work Views`

Live al pre-PR:
- kill switch global = OFF;
- 0 asesores con flag V3 persistente;
- 0 eventos F11 persistentes;
- 0 assignments persistentes;
- 0 residuos QA;
- `aos_siguiente_lead` y `aos_siguiente_lead_v2` hashes idénticos al baseline.

---

## 2. Routing legacy preservado

Hashes antes/después:
- `aos_siguiente_lead` = `76412bac81e20ec6cfdc4f8c0db89e8c`
- `aos_siguiente_lead_v2` = `cb69781d1457ed73de8f8d52f0f83a00`

No se modificó:
- `aos_cola_config`;
- esquema/índices/triggers de `aos_llamadas`;
- esquema/índices/triggers de `aos_leads_en_curso`;
- lógica madre V2.

Con kill switch OFF, `aos_siguiente_lead_v3` delega directamente a V2. Paridad rollback-only verificada sobre MIREYA: mismo contacto y mismo resultado funcional.

---

## 3. Rollout / rollback

Persistencia F11 privada:
- `aos_cia_call_routing_control`;
- `aos_cia_call_routing_advisors`;
- `aos_cia_call_routing_events`.

Modos por `aos_usuarios.id`:
- `V2_ONLY`;
- `V3_CANARY`;
- `V3_PREFERRED`.

F11 no permite modo sin fallback.

Rollback inmediato:
1. `global_enabled=false` → todos vuelven a V2;
2. por asesor `V2_ONLY` → solo ese asesor vuelve a V2;
3. rollback frontend → restaurar blob original `calls-v2.html` como `calls.html`.

La copia `calls-v2.html` usa exactamente el blob legacy `010c73e0bb55c0169470e5a259c912681afbccc9`.

---

## 4. V3 claim semantics

El dispatcher:
- resuelve `codigo_asesor + nombre` a `aos_usuarios.id` UUID activo/ASESOR;
- exige F10 readiness sano;
- sirve solo plan ACTIVE + Activation ACTIVE + policy CALL ACTIVE;
- sirve únicamente ownership del asesor;
- `ASSIGNED` requiere disponibilidad F8 actual;
- al claim: `ASSIGNED → IN_PROGRESS` mediante motor F9;
- crea claim compatible en `aos_leads_en_curso`;
- respeta claims legacy de otro asesor;
- usa lock de fila + advisory lock por `contact_key`;
- si no puede usar V3 → fallback V2.

### Corrección encontrada en QA

La primera versión revalidaba F8 también al reabrir un lease `IN_PROGRESS`. Eso provocaba fallback V2 en el segundo request del mismo asesor.

Corrección:
- **antes del claim:** F8 availability es autoritativa;
- **después del claim:** F9 `IN_PROGRESS` es ownership autoritativo hasta COMPLETE/RELEASE/EXPIRE.

Re-QA PASS: segundo request reanuda exactamente el mismo assignment.

---

## 5. Consume / completion

`aos_cia_call_routing_consume_v1`:
- no escribe llamadas;
- se invoca después de escritura legacy exitosa;
- valida advisor UUID dueño del assignment;
- ASSIGNED tardío → START → COMPLETE;
- IN_PROGRESS → COMPLETE;
- COMPLETED → idempotent PASS;
- RELEASED/EXPIRED → terminal noop;
- limpia claim propio de `aos_leads_en_curso`;
- audita CONSUME.

Frontend adapter:
- intercepta la llamada legacy ya existente a `aos_llamadas`;
- si el contacto proviene de V3 y el write devuelve HTTP OK, sincroniza el lease;
- si el consume falla, **no borra la llamada** y el siguiente route reanuda el mismo IN_PROGRESS;
- manual/follow-up sobre otro número no consume un assignment ajeno.

---

## 6. QA E2E rollback-only

Cadena real creada dentro de rollback:

Audience `LEADS_UNWORKED` → DYNAMIC Activation CALL_GENERAL → F9 plan ONE/GLOBAL → MIREYA → 1 lease → F11.

Asserts PASS:
- allocation created;
- F10 readiness true;
- foreign legacy claim → fallback V2;
- first claim → V3 y assignment esperado;
- claim → IN_PROGRESS;
- compatibility claim created;
- repeat request → mismo IN_PROGRESS;
- consume → COMPLETED;
- consume clears legacy claim;
- second consume idempotent;
- no work after completion → fallback V2;
- advisor sin flag → V2_ONLY;
- F10 readiness bloqueado → fallback V2.

El harness final trata NULL como FAIL.

Resultado: todos los asserts TRUE, transaction ROLLBACK, residuos = 0.

---

## 7. Seguridad

Tablas F11:
- RLS enabled;
- 0 policies;
- anon/authenticated sin SELECT directo.

Superficie browser permitida:
- `aos_siguiente_lead_v3`;
- `aos_cia_call_routing_consume_v1`;
- `aos_cia_call_routing_admin_v1` con CIA ADMIN token.

Privadas:
- advisor resolver;
- effective-mode resolver;
- V3 core;
- F12 readiness.

`SECURITY DEFINER` usa `search_path=public`.

Admin gateway:
- invalid token → `UNAUTHORIZED`;
- SET_GLOBAL=true se bloquea si F10 readiness no está sano.

Rol real `anon`:
- puede invocar dispatcher V3 con global OFF → V2 válido;
- consume NULL → noop válido;
- INSERT rollback-only en `aos_llamadas` PASS.

---

## 8. America/Lima

F11 usa:
`(clock_timestamp() AT TIME ZONE 'America/Lima')::date`

para clinic-day y no usa `CURRENT_DATE` server como autoridad del routing V3.

`p_hoy` se conserva solo como input compatible/audit metadata.

Esto corrige la deuda detectada en F8 respecto al límite UTC vs Lima sin modificar V2 legacy.

---

## 9. Performance

Mediciones físicas:
- V2 warm rollback-only: ~393 ms;
- V3 dispatcher con kill switch OFF: ~249 ms en corrida warm observada;
- V3 core sin ownership: ~98 ms.

Límite conservador core-no-work + V2 fallback: ~491 ms, bajo target normal <1.5 s.

No se añadieron índices sobre write-path operacional.

---

## 10. Frontend / rollback safety

El runtime real del asesor fue auditado: `app.html` carga `/calls.html`, cuyo legacy contenía JS inline y divergía de `calls.js`.

F11 evita editar el monolito:
- `calls-v2.html` = copia byte-idéntica del legacy;
- `calls.html` = wrapper declarativo mínimo;
- `calls-loader-v3.js` carga adapter antes del legacy;
- `calls-routing-v3.js` intercepta solo:
  - RPC legacy de siguiente lead → dispatcher V3;
  - POST legacy a `aos_llamadas` → consume ACK si corresponde.

El resto de UI/save logic legacy queda byte-idéntico.

Admin:
- sexta pestaña `Routing V3`;
- kill switch;
- per-advisor V2/CANARY/PREFERRED;
- readiness F10→F11 y F11→F12;
- eventos recientes;
- CIA admin session canónica `aos_cia_admin_token`;
- modales custom, sin nuevos `alert/confirm/prompt`.

---

## 11. Replayability

Git filenames reconciliados 1:1 con Supabase `schema_migrations`:
- `20260814131129_cia_phase11_routing_schema_v1.sql`
- `20260814131238_cia_phase11_routing_control_v1.sql`
- `20260814131507_cia_phase11_router_core_v1.sql`
- `20260814131621_cia_phase11_public_router_v1.sql`
- `20260814132233_cia_phase11_inprogress_resume_fix_v1.sql`
- `20260814132450_cia_phase11_f12_readiness_v1.sql`
- `20260814133119_cia_phase11_admin_readiness_guard_v1.sql`

---

## 12. F11 → F12 contract

`aos_cia_call_routing_f12_readiness_v1()` devuelve:
- rollout live/configurado;
- V3 claims/consumes/fallbacks/errors;
- CALL ownership ASSIGNED/IN_PROGRESS;
- expired IN_PROGRESS;
- IN_PROGRESS sin claim event;
- F10 readiness;
- `ready_for_f12` y status determinístico.

Estado pre-rollout live:
- `ready_for_f12=true`;
- `status=READY_NO_LIVE_V3`;
- global OFF;
- 0 V3 advisors;
- 0 routing events;
- 0 CALL ownership persistente.

F12 debe consumir ownership F9 + estado/audit F11. No inferir ownership desde `aos_llamadas`.

---

## 13. Gates

- P11-G01 Recovery + F10 handshake — PASS
- P11-G02 Legacy baseline/hashes — PASS
- P11-G03 Impact/scope/rollback — PASS
- P11-G04 Rollout config/kill switch — PASS
- P11-G05 RLS/ACL/admin auth — PASS
- P11-G06 V3 candidate from F8/F9 — PASS
- P11-G07 advisor UUID mapping — PASS
- P11-G08 legacy claim compatibility — PASS
- P11-G09 START lifecycle — PASS
- P11-G10 consume/COMPLETE/idempotency — PASS
- P11-G11 readiness block/fallback — PASS
- P11-G12 V2_ONLY/no ownership fallback — PASS
- P11-G13 concurrency/anti-double-claim — PASS (row lock + advisory lock + F9 GLOBAL invariant + QA repeated/foreign claim)
- P11-G14 America/Lima semantics — PASS
- P11-G15 performance — PASS
- P11-G16 frontend dispatcher/ack — PASS pre-CI
- P11-G17 admin rollout control — PASS pre-CI
- P11-G18 write-path safety — PASS rollback-only; real post-merge smoke pending
- P11-G19 replayability — PASS
- P11-G20 PR/CI/staging smoke — PENDING
- P11-G21 closure docs/memory/Notion — PENDING
- P11-G22 F11→F12 handshake — PASS

**No marcar 100_COMPLETE hasta G20/G21 y post-merge G18.**
