# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / MKT-INTEGRITY-HOTFIX-V3 ACTIVE — LOOP 6 GATE 0 RELEASED  
**Captured:** 2026-08-21 16:54 America/Lima  
**Reconciled from main:** `b48d46ed3d69370326e5a5a094322c6f04ffa527`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**CURRENT GATE:** `LOOP 6 — Call Center Semantics + Existing-Patient Decision Layer + Atomic Call↔Agenda Persistence`  
**NEXT FUNCTIONAL BRANCH:** `feat/mkt-integrity-v3-loop6-call-semantics-atomic`  

## Portfolio lock reconciliation — 2026-08-21

`REV-RUNTIME-BRIDGE-HOTFIX` is **CLOSED / RELEASED**.

Closure evidence:

- the runtime compatibility fixes for Patient 360 and Sales Import are present in `main`;
- subsequent Patient 360/runtime fixes were deployed successfully to Railway;
- owner smoke on 2026-08-21 America/Lima is **PASS** for both originally reported flows:
  - Patient 360: search/select opens the patient record successfully; no `No encontrado` regression;
  - Importar Ventas: owner confirms the import panel/flow is working correctly;
- owner supplied visual evidence of a real Patient 360 record open with purchases, appointments and calls visible.

The REV runtime hotfix therefore no longer owns the single HIGH/CRITICAL mutable lane.

## Revenue status preserved

- **REV-F5:** `PRODUCTION CERTIFIED — 100%`
- **REV-F6.0–F6.7:** `PASS / CERTIFIED — 100%`
- **REV-F6 global:** `PRODUCTION CERTIFIED — 100%`
- **REV-F7:** `NEXT / UNBLOCKED`, but paused while `MKT-INTEGRITY-HOTFIX-V3` owns the single mutable HIGH/CRITICAL lane.

No REV-F5/F6 data contract is reopened by this handback.

## Active Marketing / Call Center lane

`MKT-INTEGRITY-HOTFIX-V3` acquires the single mutable HIGH/CRITICAL lane for **Loop 6**.

Loop 6 objective:

Call Center → explicit management semantics → F6 identity/patient-state → lead/origin resolution → atomic Call + Agenda persistence → direct links → idempotency → correct KPI/Marketing behavior.

Gate 0 read-only preflight already established:

- current `calls.js` still writes Call + Agenda in independent browser operations;
- current patient autocomplete does not prove converted-patient state;
- F6 Identity/Lifecycle must be reused, not duplicated;
- F6 private/service-role-only boundaries must remain closed to the browser;
- `aos_llamadas.tipo_gestion`, `lead_id_origen`, Agenda `lead_id_origen` and `llamada_id_origen` are reusable;
- durable retry safety requires an action-level idempotency key/ledger; call `sync_key` alone is insufficient;
- `aos_siguiente_lead` (CC-Q1 Contact Debt) exists but frontend still consumes `aos_siguiente_lead_v2` and must not be cut over before F6 patient-state gating.

Control evidence:
- `docs/control/MKT_INTEGRITY_V3_LOOP6_GATE0_PREFLIGHT_20260821.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP6_REENTRY_DATA_REPAIR_20260821.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP6_EXECUTION_PROMPT_REBASED_20260821.md`

## Protected repair baseline

The 2026-08-21 repaired calls must remain intact throughout Loop 6:

- `36701` Alan Valencia
- `37185` Marco Antonio Salcedo Soto
- `37813` Julia Vera Condezo
- `38012` Carlos Eduardo Hernández Franchi
- `38168` Alberto Miguel Machuca Bonilla
- `38186` Lidia Edith Fernandez Salguero

Repaired direct links must remain intact. Removed duplicate Agenda rows for Alberto and Alan must not reappear.

## Single-lane rule

While this CURRENT is active:

- mutate only `MKT-INTEGRITY-HOTFIX-V3` as the HIGH/CRITICAL lane;
- REV-F7, CIA, WA, Sentinel hardening and other HIGH/CRITICAL functional work remain paused unless purely read-only/control;
- any incompatible `main` advance requires exact-head revalidation before the next functional mutation.

## Loop 6 handoff

After this control reconciliation merges:

1. re-read exact `main` HEAD;
2. create `feat/mkt-integrity-v3-loop6-call-semantics-atomic` from that exact HEAD;
3. create Impact Report before functional mutation;
4. implement governed atomic contract + frontend semantics;
5. execute the prompt-defined canaries and regression gates;
6. use shadow → controlled canary → readback → expansion;
7. require minimum five real post-cutover operations before PASS;
8. do **not** start Loop 7 automatically.
