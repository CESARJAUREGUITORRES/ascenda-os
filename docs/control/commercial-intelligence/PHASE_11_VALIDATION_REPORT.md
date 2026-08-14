# ASCENDA OS — FASE 11 VALIDATION REPORT

**Fase:** Call Center Integration V3  
**Estado:** `100_COMPLETE`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `76e5b3b609cb52f4b9a0b8c2289dea4a1fca2c64`  
**Merge funcional staging:** `f439f8d33cad841dd6745b07462aec7a264ea6b2`  
**PR funcional:** #84  
**Ascenda CI:** #743 `SUCCESS`

---

## 1. Resultado ejecutivo

Fase 11 queda certificada al 100% con una ruta Call Center V3 **paralela, canary por asesor, reversible y con fallback V2 obligatorio**.

Contrato certificado:

`F8 available_now → F9 assignment lease → F10 readiness → F11 dispatcher/claim/consume → F12 Work Views`

Estado live al cierre:
- `global_enabled=false`;
- 0 advisors V3 persistentes;
- 0 routing events persistentes;
- 0 assignment rows persistentes;
- 0 QA residues;
- `ready_for_f12=true`;
- F12 readiness status `READY_NO_LIVE_V3`.

F11 queda funcionalmente disponible, pero **no activa V3 productivo por defecto**. La activación futura se hace desde el control ADMIN y siempre conserva fallback V2 durante esta arquitectura.

---

## 2. Legacy preservado

Hashes inicial/final:
- `aos_siguiente_lead` = `76412bac81e20ec6cfdc4f8c0db89e8c`
- `aos_siguiente_lead_v2` = `cb69781d1457ed73de8f8d52f0f83a00`

Ambos permanecen idénticos.

No se modificó:
- `aos_cola_config`;
- lógica madre V2;
- esquema/índices/triggers de `aos_llamadas`;
- esquema/índices/triggers de `aos_leads_en_curso`.

Con kill switch OFF, `aos_siguiente_lead_v3` delega directamente a V2.

---

## 3. Rollout / rollback

Persistencia privada:
- `aos_cia_call_routing_control`;
- `aos_cia_call_routing_advisors`;
- `aos_cia_call_routing_events`.

Modes:
- `V2_ONLY`;
- `V3_CANARY`;
- `V3_PREFERRED`.

No existe `V3_NO_FALLBACK` en F11.

Rollback operativo:
1. global OFF → todos los advisors a V2;
2. advisor V2_ONLY → solo ese advisor a V2;
3. frontend rollback → restaurar blob legacy `calls-v2.html` como `calls.html`.

`calls-v2.html` es byte-idéntico al pre-F11 `calls.html`, blob:
`010c73e0bb55c0169470e5a259c912681afbccc9`.

---

## 4. Routing V3

`aos_siguiente_lead_v3(...)`:
- resuelve `nombre + codigo_asesor` contra `aos_usuarios.id` UUID activo;
- respeta global kill switch;
- usa F10 readiness antes de V3;
- consume exclusivamente F9 ownership;
- exige plan ACTIVE + Activation ACTIVE + policy CALL ACTIVE;
- respeta claims legacy de otros advisors;
- usa row lock + advisory lock por contact key;
- `ASSIGNED` requiere F8 availability y pasa `ASSIGNED → IN_PROGRESS`;
- `IN_PROGRESS` propio se reanuda desde F9 ownership;
- no work / invalid / blocked → fallback V2;
- usa clinic-day `America/Lima`.

### Defecto encontrado y corregido

La primera implementación revalidaba F8 al reabrir un lease ya `IN_PROGRESS`; luego de START, F8 podía dejar de considerarlo assignable y causar fallback V2 al refrescar.

Contrato final:
- F8 gobierna **antes del claim**;
- F9 ownership gobierna **IN_PROGRESS** hasta COMPLETE/RELEASE/EXPIRE.

Re-QA confirmó que el segundo request sirve el mismo assignment.

---

## 5. Consume lifecycle

`aos_cia_call_routing_consume_v1(...)`:
- se ejecuta después del write legacy;
- no crea/reescribe llamadas;
- valida advisor dueño del assignment;
- ASSIGNED tardío → START → COMPLETE;
- IN_PROGRESS → COMPLETE;
- COMPLETED → idempotent PASS;
- RELEASED/EXPIRED → terminal noop;
- limpia claim propio de `aos_leads_en_curso`;
- registra CONSUME.

Frontend adapter:
- routing RPC legacy → dispatcher V3;
- POST existente de `aos_llamadas` se conserva;
- si el contacto es V3, tras HTTP OK sincroniza el assignment;
- si consume falla, la llamada queda guardada y el lease sigue IN_PROGRESS, por lo que se reanuda el mismo contacto en lugar de saltar a otro.

---

## 6. QA E2E rollback-only

Cadena real:

`LEADS_UNWORKED → Audience → DYNAMIC Activation CALL_GENERAL → F9 ONE/GLOBAL plan → MIREYA → F11`

PASS:
- allocation created;
- F10 readiness true;
- foreign legacy claim → V2 fallback;
- first V3 claim → expected assignment;
- assignment → IN_PROGRESS;
- compatibility claim created;
- repeat request → same IN_PROGRESS assignment;
- consume → COMPLETED;
- consume clears legacy claim;
- second consume idempotent;
- post-complete → V2 fallback;
- unflagged advisor → V2_ONLY;
- F10 blocked → V2 fallback.

Harness final trata NULL como FAIL.

Resultado: todos los asserts TRUE y rollback completo.

---

## 7. Security

F11 tables:
- RLS enabled;
- 0 policies;
- anon/authenticated sin SELECT directo.

Browser surface:
- `aos_siguiente_lead_v3`;
- `aos_cia_call_routing_consume_v1`;
- `aos_cia_call_routing_admin_v1` con CIA ADMIN token.

Internal/private:
- advisor resolver;
- effective-mode resolver;
- V3 core;
- F12 readiness.

`SECURITY DEFINER` usa `search_path=public`.

Admin:
- invalid token → `UNAUTHORIZED`;
- `SET_GLOBAL=true` se rechaza si F10 readiness está blocked.

---

## 8. Timezone

F11 usa explícitamente:

`(clock_timestamp() AT TIME ZONE 'America/Lima')::date`

para clinic-day.

`p_hoy` se conserva como input compatible/audit, no como autoridad temporal.

Esto resuelve para V3 la deuda UTC/Lima detectada en F8 sin alterar V2.

---

## 9. Performance

Mediciones físicas:
- V2 warm rollback-only: ~393 ms;
- V3 dispatcher kill OFF: ~249 ms observado;
- V3 core sin ownership: ~98 ms;
- fallback conservador V3-core + V2: ~491 ms.

Todo bajo target normal <1.5 s.

No se añadieron índices sobre write-path operacional.

Nota de aprendizaje:
`EXPLAIN ANALYZE` sobre RPC mutante debe ejecutarse dentro de rollback. Un benchmark V2 sin rollback creó temporalmente un claim; se identificó y eliminó únicamente ese registro exacto antes de continuar. Las mediciones posteriores se ejecutaron rollback-only.

---

## 10. Frontend / source-of-truth correction

Durante F11 se confirmó que el runtime real del Call Center no era el sibling `calls.js`: `app.html` carga `/calls.html`, que contenía su propio JS inline.

Para no editar el monolito:
- `calls-v2.html` preserva el panel legacy byte-idéntico;
- `calls.html` es wrapper mínimo;
- `calls-loader-v3.js` carga el adapter antes del legacy;
- `calls-routing-v3.js` intercepta únicamente routing RPC y call-write ACK relevante;
- ambos JS nuevos pasan CI syntax check.

Admin:
- sexta pestaña `Routing V3`;
- kill switch;
- rollout por advisor;
- readiness F10→F11 y F11→F12;
- eventos recientes;
- sesión CIA canónica `aos_cia_admin_token`;
- modales custom.

---

## 11. Write-path safety

Antes y después del merge:
- INSERT `aos_llamadas` como rol `anon` dentro de transaction rollback-only = PASS;
- 0 QA call rows después;
- 0 claims residuales;
- 0 routing config/events residuales.

Esto demuestra que F11 no repite el incidente de índices funcionales ocurrido en F5.

---

## 12. Replayability

Git filenames = Supabase `schema_migrations`:
- `20260814131129_cia_phase11_routing_schema_v1.sql`
- `20260814131238_cia_phase11_routing_control_v1.sql`
- `20260814131507_cia_phase11_router_core_v1.sql`
- `20260814131621_cia_phase11_public_router_v1.sql`
- `20260814132233_cia_phase11_inprogress_resume_fix_v1.sql`
- `20260814132450_cia_phase11_f12_readiness_v1.sql`
- `20260814133119_cia_phase11_admin_readiness_guard_v1.sql`

PASS.

---

## 13. F11 → F12 output contract

`aos_cia_call_routing_f12_readiness_v1()` entrega:
- rollout;
- V3 claims / consumes / fallbacks / errors;
- CALL ASSIGNED / IN_PROGRESS;
- expired IN_PROGRESS;
- IN_PROGRESS sin claim audit;
- F10 readiness;
- `ready_for_f12` + status.

Post-merge:
- `ready_for_f12=true`;
- `status=READY_NO_LIVE_V3`;
- global OFF;
- 0 advisors V3;
- 0 persisted routing events;
- 0 CALL ownership.

F12 debe consumir F9 ownership + F11 routing state/events. No inferir ownership desde raw calls.

---

## 14. Integration evidence

- Functional PR #84 — MERGED
- Ascenda CI #743 — SUCCESS
- Functional staging merge — `f439f8d33cad841dd6745b07462aec7a264ea6b2`
- Post-merge smoke — PASS
- legacy blob preservation — PASS
- legacy hashes — PASS
- kill switch remains OFF — PASS
- post-merge anon write-path rollback — PASS
- F12 readiness — PASS

---

## 15. Gates

P11-G01..P11-G22 = **PASS**.

- G01 recovery/F10 handshake PASS
- G02 legacy baseline/hashes PASS
- G03 Impact/scope/rollback PASS
- G04 rollout config/kill switch PASS
- G05 RLS/ACL/admin auth PASS
- G06 V3 candidate from F8/F9 PASS
- G07 advisor UUID mapping PASS
- G08 legacy claim compatibility PASS
- G09 START lifecycle PASS
- G10 consume/COMPLETE/idempotency PASS
- G11 readiness fallback PASS
- G12 V2_ONLY/no ownership fallback PASS
- G13 concurrency/anti-double-claim PASS
- G14 America/Lima PASS
- G15 performance PASS
- G16 frontend dispatcher/ack PASS
- G17 admin rollout control PASS
- G18 write-path safety PASS
- G19 replayability PASS
- G20 PR/CI/staging smoke PASS
- G21 closure docs/memory/Notion PASS upon closure checkpoint
- G22 F11→F12 handshake PASS

**FASE 11 = `100_COMPLETE`.**

**FASE 12 — Advisor Work Views = `READY`.**
