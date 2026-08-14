# ASCENDA OS — FASE 12 VALIDATION REPORT

**Fase:** Advisor Work Views  
**Estado:** `100_COMPLETE`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline inicial staging:** `69deed08965fbe52058c590dc71110e9db6cd435`  
**Staging concurrente sincronizado:** `4454f4c5da1e5cf080f6dff58357d7516d0dd1f1`  
**PR funcional:** #89  
**Ascenda CI funcional:** #903 `SUCCESS`  
**Merge funcional staging:** `dedbc80de9967a70c4cd7a1195a534496b245a2d`

---

## 1. Resultado ejecutivo

F12 queda certificada como un **Work View personal gobernado** derivado exclusivamente del ownership F9 y de la evidencia de routing F11.

Contrato certificado:

`F9 assignment lease + F11 routing evidence → F12 personal work universe/preferences → F13 governed request context`

Regla estructural:

**Work View ≠ Assignment.**

F12 puede ordenar, fijar o posponer visualmente un work-item, pero no puede:
- crear ownership;
- mover `advisor_user_id`;
- editar planes/targets/runs;
- cambiar assignment state;
- autoasignar contactos;
- alterar routing de Call Center.

---

## 2. Handshake F11 → F12

Al inicio y post-merge:
- `aos_cia_call_routing_f12_readiness_v1().ready_for_f12=true`;
- status `READY_NO_LIVE_V3`;
- global V3 OFF;
- 0 V3 advisors persistentes;
- 0 routing events persistentes;
- F10 status `READY_NO_ACTIVE_OWNERSHIP`;
- 6 asesores activos.

F12 consume F9 ownership + F11 routing state/events y **no infiere ownership desde raw calls**.

PASS.

---

## 3. Persistencia no propietaria

Nueva tabla:
`aos_cia_advisor_work_preferences`

Campos de negocio:
- `advisor_user_id`;
- `assignment_id`;
- `pinned`;
- `snoozed_until`;
- `priority_override = HIGH|NORMAL|LOW`;
- `updated_at`.

Guard DB:
- advisor/assignment identity inmutable;
- assignment debe pertenecer al mismo advisor UUID;
- snooze máximo 30 días.

La tabla no contiene un nuevo owner ni reescribe `contact_key`, plan, activation o assignment.

---

## 4. Priority semantics V1

Prioridad determinística:
1. `IN_PROGRESS`;
2. `OVERDUE_TO_START`;
3. `EXPIRING_SOON` ≤60m;
4. `FOLLOWUP_OVERDUE`;
5. `FOLLOWUP_PENDING`;
6. Value Tier `DIAMANTE/GOLD/PREMIUM`;
7. resto de ownership activo.

Preferencias personales:
- pin eleva visualmente;
- snooze oculta temporalmente de NOW;
- HIGH/NORMAL/LOW reordena visualmente.

Ninguna preferencia cambia ownership.

---

## 5. Contracts

### Privado
`aos_cia_advisor_work_universe_v1(advisor_uuid, include_terminal, include_snoozed)`

### Advisor/browser
- `aos_cia_advisor_work_summary_v1(...)`;
- `aos_cia_advisor_work_list_v1(...)`;
- `aos_cia_advisor_work_detail_v1(...)`;
- `aos_cia_advisor_work_preference_v1(...)`.

LIST:
- NOW / PINNED / SNOOZED / HISTORY / ALL;
- limit server-side ≤100.

DETAIL:
- exige que el assignment pertenezca al advisor;
- la última llamada se obtiene con un lookup indexado de un solo contacto, no como enrichment masivo.

---

## 6. QA rollback-only

Cadena sintética válida F7→F9→F11:
- Audience/version;
- Activation CALL ACTIVE;
- F9 plan ONE/GLOBAL;
- 5 assignments propiedad de MIREYA;
- 1 IN_PROGRESS + 4 ASSIGNED;
- 1 CLAIM F11;
- PIN, SNOOZE y PRIORITY HIGH en items distintos.

PASS:
- ownership unchanged;
- cross-advisor preference → `WORK_ITEM_NOT_OWNED`;
- NOW = 4 después del snooze;
- SNOOZED = 1;
- pinned item primero;
- F11 claim visible;
- requestable = 5;
- preferences creadas solo dentro de QA;
- F13 readiness true;
- zero residue.

El primer harness fue rechazado por un guard F7 porque una Activation ACTIVE no tenía `started_at`; se corrigió el **test**, no producto.

---

## 7. Security / ACL

`aos_cia_advisor_work_preferences`:
- RLS enabled;
- 0 policies;
- anon SELECT=false;
- authenticated SELECT=false.

Advisor RPCs públicos:
- SECURITY DEFINER;
- `search_path=public`;
- resuelven advisor UUID con el mismo contrato F11 `nombre + codigo_asesor`;
- sirven/modifican exclusivamente assignments del UUID resuelto.

Privados:
- `work_universe`: anon/auth no EXECUTE;
- `f13_readiness`: anon/auth no EXECUTE.

Todas las escrituras F12 son preferencias no propietarias.

F12 no rediseña la autenticación heredada del advisor y no amplía sus privilegios sobre dominios operativos.

---

## 8. Performance

Prueba read-only equivalente a 1,000 work-items.

Iteraciones rechazadas:
- global `aos_cia_call_facts_v1`: ~1,628.5ms;
- 1,000 lateral last-call lookups: ~1,891.8ms.

Contrato final:
- LIST/SUMMARY no calculan última llamada por cada fila;
- DETAIL realiza un solo lookup indexado.

Benchmark final:
- 1,000 work-items / page 100: **~874.8ms execution**.

PASS <1.5s.

No se agregaron índices/triggers sobre tablas operativas.

---

## 9. Frontend

Nuevos:
- `app/public/advisor-work.html`;
- `app/public/advisor-work.css`;
- `app/public/advisor-work.js`.

Integración:
- usa la zona izquierda 2/3 previamente reservada en `advisor-home.html`;
- Home conserva embudo/calendario/comisiones/atenciones;
- no modifica `app.html`;
- no modifica Call Center router;
- Work View se carga como módulo aislado.

UI:
- KPIs de ownership;
- NOW/PINNED/SNOOZED/HISTORY;
- reasons/buckets;
- deadline/expiry;
- routing evidence F11;
- pin/snooze/prioridad visual;
- detail;
- badge `F13 · solicitable`, sin implementar Requests.

Audit:
- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- 0 `/rest/v1/aos_*` directo.

Ascenda CI #903 confirmó sintaxis del JavaScript público y archivos críticos.

---

## 10. Concurrent staging handling

Durante F12, `staging` avanzó con Marketing Attribution V2:
`20260814104500_marketing_attribution_v2_safe_origin_resolution.sql`.

Ese cambio posterior a F11 reemplazó legítimamente `aos_siguiente_lead_v2` para mantener `lead_id_origen` solo con evidencia única/unánime.

Hashes:
- `aos_siguiente_lead` sigue `76412bac81e20ec6cfdc4f8c0db89e8c`;
- F11 historical `aos_siguiente_lead_v2` = `cb69781d1457ed73de8f8d52f0f83a00`;
- live posterior a Marketing = `2b5b5707450df3bc648636936c02a0d4`.

F12 no modificó ninguna de esas funciones.

La feature fue sincronizada con `staging=4454f4c5...` mediante merge commit de dos padres; PR #89 abrió con `behind=0`.

---

## 11. Replayability

Git = Supabase live:
- `20260814153444_cia_phase12_work_preferences_v1.sql`;
- `20260814153657_cia_phase12_work_universe_v1.sql`;
- `20260814153814_cia_phase12_work_contracts_v1.sql`;
- `20260814154524_cia_phase12_work_universe_call_lookup_v2.sql`;
- `20260814155611_cia_phase12_list_detail_split_v2.sql`.

Audit script:
`scripts/audit_cia_advisor_work_phase12_readonly.sql`

PASS.

---

## 12. Post-merge smoke

Functional merge:
`dedbc80de9967a70c4cd7a1195a534496b245a2d`

Post-merge:
- `advisor-work.js` presente en staging;
- summary MIREYA: ok=true, active=0;
- list NOW: ok=true, total=0, items=[];
- F11 readiness: `READY_NO_LIVE_V3`, ready_for_f12=true;
- F13 readiness: `READY_NO_REQUESTABLE_WORK`, ready_for_f13=true;
- invalid active owners=0;
- preference owner mismatch=0;
- preferences=0;
- plans/targets/runs/assignments/events=0;
- routing events=0;
- QA12 audiences=0.

Call Center observacional:
- 346 llamadas en ventana 24h durante el pre-merge smoke;
- F12 no añadió DDL al write-path de llamadas.

PASS.

---

## 13. F12 → F13 output contract

F13 puede consumir:
- `advisor_user_id` UUID;
- `assignment_id` como referencia estable de ownership/work-item;
- plan/activation IDs;
- assignment state;
- deadlines/expiry;
- work bucket / priority reasons;
- preference state;
- F11 routing evidence;
- `requestable=true` únicamente si el assignment continúa propio, ASSIGNED/IN_PROGRESS y no expiró;
- `aos_cia_advisor_work_f13_readiness_v1()`.

F13 **no** debe:
- usar `contact_key` crudo como autoridad de ownership;
- autoasignar contactos;
- ejecutar un request si ownership cambió o expiró;
- permitir doble aprobación;
- introducir IA como aprobación automática.

Output F12 deja a F13 listo para construir un Approval Gate transaccional y revalidado.

---

## 14. Integration evidence

- Functional PR #89 — MERGED
- Ascenda CI #903 — SUCCESS
- Functional staging merge — `dedbc80de9967a70c4cd7a1195a534496b245a2d`
- Post-merge smoke — PASS
- zero residue — PASS
- F11→F12 handshake — PASS
- F12→F13 handshake — PASS

---

## 15. Gates

P12-G01..P12-G18 = **PASS** al completar el closure checkpoint.

- G01 Recovery/F11 handshake — PASS
- G02 Baseline ownership/advisors/UI — PASS
- G03 Impact/scope/rollback — PASS
- G04 Preference schema/RLS — PASS
- G05 Work Universe ownership purity — PASS
- G06 Priority semantics — PASS
- G07 F11 routing evidence — PASS
- G08 Preference mutation without ownership change — PASS
- G09 Summary/list/detail contracts — PASS
- G10 F12→F13 readiness — PASS
- G11 Security/ACL — PASS
- G12 Performance — PASS
- G13 QA rollback-only / zero residue — PASS
- G14 Frontend advisor work view — PASS
- G15 Legacy/write-path no-regression — PASS
- G16 Replayability Git↔Supabase — PASS
- G17 PR/CI/staging smoke — PASS
- G18 Validation/Memory/Notion closure — PASS upon closure merge + checkpoint synchronization

**FASE 12 = `100_COMPLETE`.**

**FASE 13 — Requests & Approval Engine = `READY`.**
