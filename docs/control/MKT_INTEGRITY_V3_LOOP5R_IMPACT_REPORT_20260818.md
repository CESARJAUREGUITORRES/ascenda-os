# MKT-INTEGRITY-HOTFIX-V3 — LOOP 5R Impact Report

**Purpose:** unblock Loop 5 without bypassing guards, and formalize minimal historical-inferred call semantics approved on 2026-08-18 Lima.

**Entry main:** `19c326a7f3193ec88dc3ec7755aa29391b091dfd`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**REV-F5:** paused recoverably 7,064 / 15,498; 3,950 clusters; 0 members/preview/apply.  
**Status:** PRE-DDL / PRE-DML.

## Business rule approved

Do not equate “record exists” with “old patient”. Historical imported Agenda/ventas can exist without a preserved call.

For historical conversion reconciliation:

1. If a person has sale + attended/effective Agenda but **no Marketing lead prior to first conversion**, treat as `PACIENTE_HISTORICO/LEGACY`; do not synthesize a Marketing call.
2. If a person has a **Marketing lead prior to first conversion**, no call recorded through that conversion, and no conversion before the selected lead, the acquisition can be traced to the nearest valid prior lead.
3. To close historical operational counts without adding a new schema column, create one explicitly marked call row using existing fields:
   - `tipo_gestion = INFERIDA_HISTORICA`
   - `fecha = lead_fecha` as documented proxy date
   - `hora_llamada = 00:00:00` as documented sentinel/proxy; real call time is unknown
   - `estado = CITA CONFIRMADA`
   - `origen = MARKETING`
   - direct `lead_id_origen`
   - `observacion` must explicitly state that the call is inferred and that the date/time are proxies.
4. This row counts as one historical call/cita for funnel reconciliation but remains distinguishable from an observed real call.
5. Never apply this rule when a real call/audit event exists; observed evidence wins.

## Current `tipo_gestion` compatibility

Live audit before this patch:

- all 35,309 current `aos_llamadas` rows use `tipo_gestion = LLAMADA`;
- `aos_panel_asesor` does not filter on `tipo_gestion`;
- `aos_monitoreo_equipo` does not filter on `tipo_gestion`.

Therefore introducing explicit semantic values is additive and does not require a schema change.

## Strict historical candidate derivation

Criteria:

- at least one `aos_ventas` row;
- at least one Agenda `ASISTIO/ASISTIÓ/EFECTIVA` row;
- no call on or before the first conversion date;
- at least one Marketing lead dated on/before first conversion;
- no sale or attended/effective Agenda before the selected lead;
- choose nearest prior lead;
- attribution to the advisor recorded on the conversion Agenda.

Exactly **4** live cases currently pass:

| Phone | Lead | Lead date | First attended | First sale | Agenda advisor | Lead treatment |
|---|---:|---|---|---|---|---|
| 954848810 | 51 | 2026-01-14 | 2026-01-15 | 2026-01-15 | WILMER | CAPILAR |
| 960381839 | 571 | 2026-01-22 | 2026-01-23 | 2026-01-23 | MIREYA | ENZIMAS FACIALES |
| 964633863 | 667 | 2026-01-26 | 2026-01-28 | 2026-01-28 | MIREYA | CRIOLIPOLISIS |
| 930260184 | 661 | 2026-01-26 | 2026-02-10 | 2026-02-13 | WILMER | CRIOLIPOLISIS |

All four are already Acquisition customers in both V2 and V3. Three already have Attribution V2 operations; `930260184` has V2 Attribution 0 while V3 currently recognizes 2 ops / S/394.

This patch must **not create a fifth acquisition** or alter the certified V3-only customer `973438607 → lead 2135`.

## Loop 5 blocker to remove

Current function `aos_hotfix_manual_agenda_cleanup_v1()` deletes any same-phone/same-advisor `CITA CONFIRMADA` call within ±10 seconds of a `CITA_MANUAL` Agenda. Transaction simulation proved this deletes real historical calls `37108` and `37110`.

Loop 5 contract prohibited bypassing/disabling the trigger. The safe prerequisite is therefore a semantic exception inside the cleanup itself.

## Minimal cleanup change

Preserve calls whose `tipo_gestion` is explicitly one of:

- `LLAMADA_MANUAL_COMERCIAL`
- `CALLBACK_INBOUND`
- `INFERIDA_HISTORICA`

All existing/productive generic rows remain `LLAMADA`, so current frontend behavior is unchanged until Loop 6 explicitly emits a commercial manual/inbound type.

Both trigger directions must honor the exception:

- Agenda inserted second must not delete an explicitly semantic call;
- call inserted second must return without cleanup when its explicit semantic type is protected.

No trigger is disabled. No table/schema change is required.

## Required canaries after DDL

1. Generic `LLAMADA` + `CITA_MANUAL` ±10s → legacy cleanup still deletes the technical side-effect call.
2. `LLAMADA_MANUAL_COMERCIAL` + `CITA_MANUAL` ±10s → call survives.
3. `CALLBACK_INBOUND` + `CITA_MANUAL` ±10s → call survives.
4. `INFERIDA_HISTORICA` remains protected from cleanup.
5. Transactional restoration of `37108/37110` with `LLAMADA_MANUAL_COMERCIAL` → 2/2 survive; no trigger bypass.
6. Synthetic four-case historical batch → exactly 4 inferred calls and 4 direct Agenda links in simulation.
7. Acquisition V2/V3 remains 54/55; V3-only remains `973438607→2135`; deterministic hash remains `3223caf0ec5d1b264c4494775c6f7d58`.
8. Any Attribution change must be fully localized to the four historical candidates and/or the two Mireya targets.
9. REV-F5 remains unchanged.

## Stop conditions

STOP if the legacy generic cleanup ceases working, a protected semantic call is still deleted, Acquisition changes, V3 hash changes, unrelated Attribution changes, or REV-F5 moves.
