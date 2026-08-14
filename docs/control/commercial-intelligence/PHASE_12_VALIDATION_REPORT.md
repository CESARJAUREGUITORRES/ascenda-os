# ASCENDA OS — FASE 12 VALIDATION REPORT

**Fase:** Advisor Work Views  
**Estado:** `VALIDATING`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline inicial staging:** `69deed08965fbe52058c590dc71110e9db6cd435`  
**Staging concurrente sincronizado:** `4454f4c5da1e5cf080f6dff58357d7516d0dd1f1`

---

## 1. Resultado técnico pre-PR

F12 implementa un **Work View personal** derivado exclusivamente del ownership F9 y enriquecido con evidencia F11/facts, sin crear ni mover ownership.

Contrato:

`F9 assignment lease + F11 routing evidence → F12 personal work universe/preferences → F13 governed request context`

F12 no modifica:
- Assignment Plans/Targets/Runs;
- `advisor_user_id` de ningún lease;
- `aos_siguiente_lead`;
- dispatcher/consume F11;
- `aos_llamadas`, leads, agenda, ventas o seguimientos;
- Call Center UI/routing.

---

## 2. Input handshake F11 → F12

Live:
- `aos_cia_call_routing_f12_readiness_v1().ready_for_f12=true`;
- status `READY_NO_LIVE_V3`;
- global V3 OFF;
- F10 status `READY_NO_ACTIVE_OWNERSHIP`;
- 6 asesores activos;
- 0 F9 assignments persistentes al baseline;
- 0 F11 routing events/advisors persistentes.

PASS.

---

## 3. Persistencia F12

Nueva tabla:
- `aos_cia_advisor_work_preferences`.

Solo almacena:
- `pinned`;
- `snoozed_until`;
- `priority_override = HIGH|NORMAL|LOW`;
- timestamp.

PK:
`(advisor_user_id, assignment_id)`.

Guard DB:
- advisor/assignment identity inmutable;
- assignment debe pertenecer al mismo advisor UUID;
- snooze máximo 30 días.

No contiene `contact_key`, nuevo owner ni payload de Assignment.

Work View ≠ Assignment.

---

## 4. Priority semantics V1

Base determinística:
1. `IN_PROGRESS`;
2. `OVERDUE_TO_START`;
3. `EXPIRING_SOON` ≤60m;
4. `FOLLOWUP_OVERDUE`;
5. `FOLLOWUP_PENDING`;
6. `DIAMANTE/GOLD/PREMIUM`;
7. resto de ownership activo.

Personal:
- pin eleva visualmente;
- snooze oculta temporalmente de NOW;
- HIGH/NORMAL/LOW reordena visualmente.

Ninguno cambia ownership.

---

## 5. Contracts

### Interno
`aos_cia_advisor_work_universe_v1(advisor_uuid, include_terminal, include_snoozed)`

### Browser/advisor
- `aos_cia_advisor_work_summary_v1(...)`;
- `aos_cia_advisor_work_list_v1(...)`;
- `aos_cia_advisor_work_detail_v1(...)`;
- `aos_cia_advisor_work_preference_v1(...)`.

LIST:
- NOW / PINNED / SNOOZED / HISTORY / ALL;
- limit server-side ≤100.

DETAIL:
- solo work item del advisor;
- última llamada se resuelve solo al abrir detalle, no para toda la lista.

### F12 → F13
`aos_cia_advisor_work_f13_readiness_v1()`

Entrega:
- owner validity;
- preference/owner consistency;
- requestable item count;
- F11 readiness;
- `ready_for_f13`.

Post-QA sin ownership live:
- `ready_for_f13=true`;
- status `READY_NO_REQUESTABLE_WORK`;
- violations = 0.

---

## 6. QA rollback-only

Se creó una cadena sintética válida F7→F9→F11 dentro de subtransacción y se revirtió completamente.

5 assignments de MIREYA:
- 1 IN_PROGRESS;
- 4 ASSIGNED;
- 1 con F11 CLAIM;
- PIN en otro item;
- SNOOZE en item expiring;
- PRIORITY HIGH en otro item.

Asserts PASS:
- ownership unchanged;
- cross-advisor preference rejected (`WORK_ITEM_NOT_OWNED`);
- NOW = 4 después de snooze;
- SNOOZED = 1;
- pinned item queda primero;
- F11 claim visible;
- requestable = 5;
- preferences = 3 durante QA;
- F13 readiness = true;
- zero residue = true.

Primer harness fue rechazado correctamente por guard F7 porque una Activation ACTIVE no tenía `started_at`; se corrigió el test, no producto.

---

## 7. Security / ACL

`aos_cia_advisor_work_preferences`:
- RLS enabled;
- 0 policies;
- anon SELECT = false;
- authenticated SELECT = false.

Public advisor RPCs:
- SECURITY DEFINER;
- `search_path=public`;
- resuelven advisor UUID usando el mismo contrato F11 `nombre + codigo_asesor`;
- solo sirven/modifican assignments cuyo `advisor_user_id` coincide.

Private:
- `work_universe` anon/auth = no EXECUTE;
- `f13_readiness` anon/auth = no EXECUTE.

`preference_v1` sobre assignment ajeno/inexistente → `WORK_ITEM_NOT_OWNED`.

F12 no rediseña la autenticación heredada del advisor; no aumenta privilegios operativos y sus únicas escrituras son preferencias no propietarias.

---

## 8. Performance

Prueba read-only equivalente a 1,000 work-items.

### Iteración rechazada
Work list con `aos_cia_call_facts_v1` global:
- ~1,628.5 ms.

No aceptado.

### Iteración lateral call lookup
Con 1,000 lookups de última llamada:
- ~1,891.8 ms.

No aceptado.

### Contrato final
LIST/SUMMARY no resuelven última llamada por item; DETAIL resuelve una sola llamada indexada.

Benchmark equivalente 1,000 work-items / page 100:
- **~874.8 ms execution**.

PASS <1.5s.

No se añadieron índices/triggers a tablas operativas.

---

## 9. Frontend

Nuevos:
- `advisor-work.html`;
- `advisor-work.css`;
- `advisor-work.js`.

Integración:
- usa la zona izquierda 2/3 que `advisor-home.html` ya tenía reservada;
- no modifica `app.html`;
- no modifica Call Center router;
- si Work View falla, calendario/comisiones/embudo del Home siguen independientes.

UI:
- KPIs;
- NOW/PINNED/SNOOZED/HISTORY;
- prioridad/razones;
- deadlines;
- F11 routing evidence;
- pin/snooze/prioridad visual;
- detalle;
- badge F13 `solicitable`, sin Requests aún.

Audit controller:
- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- 0 `/rest/v1/aos_*` directo.

---

## 10. Concurrent change handling

Durante F12, `staging` avanzó con Marketing Attribution V2:
`20260814104500_marketing_attribution_v2_safe_origin_resolution.sql`.

Ese cambio reemplazó legítimamente `aos_siguiente_lead_v2` para propagar `lead_id_origen` solo con evidencia única/unánime.

Por tanto:
- hash F11 histórico de V2: `cb69781d1457ed73de8f8d52f0f83a00`;
- hash live posterior a Marketing: `2b5b5707450df3bc648636936c02a0d4`;
- `aos_siguiente_lead` sigue `76412bac81e20ec6cfdc4f8c0db89e8c`.

F12 no modificó ninguno.

La feature fue sincronizada con `staging=4454f4c5...` mediante merge de dos padres antes del PR.

---

## 11. Replayability

Supabase live = Git Phase12:
- `20260814153444_cia_phase12_work_preferences_v1.sql`;
- `20260814153657_cia_phase12_work_universe_v1.sql`;
- `20260814153814_cia_phase12_work_contracts_v1.sql`;
- `20260814154524_cia_phase12_work_universe_call_lookup_v2.sql`;
- `20260814155611_cia_phase12_list_detail_split_v2.sql`.

PASS pre-PR.

---

## 12. Zero residue / operations

Al último smoke pre-PR:
- work_preferences = 0;
- plans = 0;
- targets = 0;
- runs = 0;
- assignments = 0;
- assignment events = 0;
- routing events = 0;
- QA12 audiences = 0.

Call Center:
- 346 llamadas observadas en últimas 24h;
- F11 readiness sigue PASS;
- global V3 sigue OFF.

F12 no añadió DDL al write-path de llamadas.

---

## 13. Gate status pre-PR

- P12-G01 Recovery/F11 handshake — PASS
- P12-G02 Baseline ownership/advisors/UI — PASS
- P12-G03 Impact/scope/rollback — PASS
- P12-G04 Preference schema/RLS — PASS
- P12-G05 Work Universe ownership purity — PASS
- P12-G06 Priority semantics — PASS
- P12-G07 F11 routing evidence — PASS
- P12-G08 Preference mutation no ownership change — PASS
- P12-G09 Summary/list/detail — PASS
- P12-G10 F12→F13 readiness — PASS
- P12-G11 Security/ACL — PASS
- P12-G12 Performance — PASS
- P12-G13 QA rollback-only / zero residue — PASS
- P12-G14 Frontend advisor work view — PASS pending CI syntax
- P12-G15 Legacy/write-path no-regression — PASS
- P12-G16 Replayability Git↔Supabase — PASS
- P12-G17 PR/CI/staging smoke — PENDING
- P12-G18 Validation/Memory/Notion closure — PENDING

**Estado pre-PR: READY_FOR_INTEGRATION.**
