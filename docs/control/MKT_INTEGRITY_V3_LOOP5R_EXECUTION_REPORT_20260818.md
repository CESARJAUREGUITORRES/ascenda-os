# MKT-INTEGRITY-HOTFIX-V3 — LOOP 5R Execution Report

**Purpose:** unblock and complete Loop 5 after explicit historical-conversion semantics were approved.  
**Entry main:** `19c326a7f3193ec88dc3ec7755aa29391b091dfd`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**Result:** `PASS_PENDING_GITHUB_MERGE_READBACK`

## 1. Cleanup prerequisite

Applied migration:

`mkt_integrity_v3_loop5r_cleanup_semantics`

New cleanup function hash:

`a6f918f64ac56f587a75ed0aebde0e09`

The function now preserves only explicitly semantic calls:

- `LLAMADA_MANUAL_COMERCIAL`
- `CALLBACK_INBOUND`
- `INFERIDA_HISTORICA`

All existing rows before this change used `tipo_gestion=LLAMADA`; therefore the current productive generic flow retained its previous cleanup behavior.

### Canary

Transaction-only canary with all triggers enabled:

- generic `LLAMADA` at the same CITA_MANUAL timestamp → surviving rows **0**;
- `LLAMADA_MANUAL_COMERCIAL` → **1**;
- `CALLBACK_INBOUND` → **1**;
- `INFERIDA_HISTORICA` → **1**.

PASS. No trigger was disabled.

## 2. Historical inferred rule

Strict live derivation found exactly four cases with:

- sale + ASISTIO/EFECTIVA Agenda;
- no call through first conversion;
- prior Marketing lead;
- no conversion before selected lead;
- nearest prior lead selected;
- advisor taken from the conversion Agenda.

Rows created:

| Call ID | Phone | Lead | Proxy date | Advisor | Type |
|---:|---|---:|---|---|---|
| 37199 | 954848810 | 51 | 2026-01-14 | WILMER | INFERIDA_HISTORICA |
| 37200 | 960381839 | 571 | 2026-01-22 | MIREYA | INFERIDA_HISTORICA |
| 37201 | 964633863 | 667 | 2026-01-26 | MIREYA | INFERIDA_HISTORICA |
| 37202 | 930260184 | 661 | 2026-01-26 | WILMER | INFERIDA_HISTORICA |

Each row explicitly documents in `observacion` that the call is inferred, that `fecha` is a lead-date proxy, and that real call time is unavailable. `00:00:00` is a sentinel/proxy, not an observed time.

Four existing historical conversion Agenda rows were direct-linked to those calls/leads. No Agenda row was created.

## 3. Mireya restoration / Loop 5 closure

Restored observed historical calls:

- `37108` → phone `991144656` → lead `5664` → MIREYA → `LLAMADA_MANUAL_COMERCIAL`.
- `37110` → phone `980547287` → lead `5599` → MIREYA → `LLAMADA_MANUAL_COMERCIAL`.

Both survived all active triggers after the semantic cleanup fix.

Existing Agenda direct links:

- `6b1c4962-a597-45d8-8b72-d721d71c20f4` → lead 5664 / call 37108.
- `d80a4d17-5f2e-4169-8814-c5d5c50eac5c` → lead 5599 / call 37110.

Prior failed attempts remain unchanged:

- call 36912 = WILMER / SIN CONTACTO / hash `b76540d9a065e6e21c99a8575d813469`.
- call 37062 = MIREYA / SIN CONTACTO / hash `d0c795e583e1890d61236ef822c04d2e`.

## 4. KPI delta

Immediate pre-apply Mireya baseline for business date 2026-08-18:

- calls = **51**
- CITA CONFIRMADA = **4**

Post-apply:

- calls = **53**
- CITA CONFIRMADA = **6**

Targeted delta:

- calls **+2**
- citas **+2**

Agenda total remained **3,126**, so no new Agenda was fabricated.

Historical inferred rows add exactly:

- MIREYA: +2 historical proxy calls/citas in January;
- WILMER: +2 historical proxy calls/citas in January.

## 5. Marketing invariants

Unchanged after simulation and productive apply:

- Acquisition V2 = **54**;
- Acquisition V3 = **55**;
- deterministic V3 hash = `3223caf0ec5d1b264c4494775c6f7d58`;
- V3-only remains exactly `973438607 → lead 2135`;
- duplicate acquisitions = **0**;
- post-sale lead attribution = **0**.

Attribution also remained unchanged:

- V2 = **126 ops / S/45,158.70**;
- V3 = **173 ops / S/66,644.10**.

No revenue cutover was performed.

## 6. REV-F5

Unchanged:

- batches 6;
- expected 15,498;
- source rows 7,064;
- clusters 3,950;
- members 0;
- preview 0;
- apply 0.

## 7. Idempotency

Second dry-run predicates after apply:

- Mireya calls still needing insert = **0**;
- inferred historical calls still needing insert = **0**;
- Agenda rows still needing link = **0**.

PASS.

## 8. Rollback

Canonical rollback:

`docs/control/MKT_INTEGRITY_V3_LOOP5R_ROLLBACK_20260818.sql`

It clears only exact repaired Agenda links, deletes the four inferred rows by unique sync_key/type/business semantics, deletes 37108/37110 only if exact AFTER semantics still match, and can restore the prior cleanup function definition.

## Certification

Functional/data gates for Loop 5R and the previously blocked Loop 5 now pass.

`LOOP 5 = PASS_PENDING_GITHUB_MERGE_READBACK`

`LOOP 6 = NOT STARTED`
