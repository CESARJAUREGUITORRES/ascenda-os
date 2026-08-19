# MKT-INTEGRITY-HOTFIX-V3 — LOOP 1 BEFORE / Rollback Manifest

**Snapshot window:** 2026-08-18 20:30–20:33 Lima  
**Source main:** `6ffdd18542d9636704e5b107e0692beb29405af9`  
**Supabase:** `ituyqwstonmhnfshnaqz`  
**Functional mutations performed by this Loop:** **0**

This manifest is the immutable BEFORE reference for later loops. Live operational tables may continue receiving ordinary clinic/call-center traffic after this timestamp; later gates must compare targeted deltas and stored hashes rather than assume live totals remain fixed.

## 1. Core table snapshot

| Table | Rows | High-water mark | Snapshot hash |
|---|---:|---|---|
| `aos_llamadas` | 35,291 | id 37,179 / created `2026-08-19T01:30:23.024Z` | `19b245f2ce5ec0b74fdfb342ca8727c0` |
| `aos_agenda_citas` | 3,125 | created `2026-08-19T01:27:27.462Z` | `43615c7e574412ef9c029c6536093dad` |
| `aos_leads` | 5,669 | id 5,677 / created `2026-08-18T20:56:01.892862Z` | `d83ce41d8e2330012860455089e99e97` |
| `aos_ventas` | 1,299 | id 2,360 / created `2026-08-15T22:34:30.648078Z` | `6f4f870906bded56cc909f881974b995` |

## 2. Marketing V2 BEFORE

- Acquisition V2: **54 customers**, hash `d24f202651fc38db76c58d8de8254e26`.
- Attribution V2: **126 operations / S/45,158.70**, hash `06857a37f7efb476922ce5bbb0150c93`.
- LTV 2026 hash: `c325a02972fd27d01ce45bcb6c7f097a`.
- Histórico 2026 hash: `458a81d8a09f2f43007a02c4da7cdd9d`.
- Modal summary 2026-01-01..2026-08-18: **5,669 total / 5,460 llamados / 746 con cita / 56 vendidos / 207 sin contacto / S/101,959.85**.
- Modal summary August 1..18: **658 total / 612 llamados / 44 con cita / 5 vendidos / 44 sin contacto / S/2,402**.

### LTV acquisition BEFORE by cohort

Jan 9 · Feb 5 · Mar 9 · Apr 3 · May 8 · Jun 8 · Jul 8 · Aug 4 = **54**.

Approved future fallback may add exactly one acquisition (`973438607` → lead `2135`), but **Loop 1 does not apply it**.

## 3. Marketing/HOME function definition hashes

- `aos_hotfix_call_guard_v1`: `d05de50205e7c716cc048c4a5e6923a2`
- `aos_hotfix_manual_agenda_cleanup_v1`: `85398da8c4bf74366d10020abade08b4`
- `aos_marketing_acquisition_customers_v2`: `7851ca8c9163625bda8fcf987a1def87`
- `aos_marketing_attribution_v2_preview`: `630c46e0425e6941283f1b200d3a5ce2`
- `aos_marketing_call_lead_match_v2`: `bcdfc95ac762bfc10dfa0a60c5a9a354`
- `aos_marketing_cohortes_ltv_v2_preview`: `b6d2035a3420c6956e3b0248d56e86f6`
- `aos_marketing_historico_v2_preview`: `8147cc91935da68ab550435cf7016556`
- `aos_marketing_leads_detalle_v2`: `f25d7c4f052f70e3a3aa901b0afdcf18`
- `aos_marketing_leads_detalle_v2_paged`: `9b1d34f0230f4a4870bfba7185a73402`
- `aos_marketing_leads_detalle_v2_summary`: `cbd625a744f312bb6e44b28d3b586da4`
- `aos_marketing_period_summary_v2`: `eef10aee61e44898864e355f6197bc1f`
- `aos_panel_asesor`: `3dc5f2275c84af5efbaf19b337174ea9`
- `aos_monitoreo_equipo`: `a961d4a99dd35435fe1cf681d7ca8ee9`

## 4. Explicit Lima-date Home/Monitoreo snapshot

Captured with business date parameters `2026-08-18` / month start `2026-08-01`, avoiding the known UTC reset defect.

| Asesor | Calls today | Citas today | Calls Aug | Citas Aug | Asist Aug | Ventas Aug | Fact Aug |
|---|---:|---:|---:|---:|---:|---:|---:|
| MIREYA | 38 | 4 | 1,574 | 52 | 13 | 23 | S/9,655 |
| RUVILA | 21 | 2 | 313 | 13 | 6 | 17 | S/8,304 |
| WILMER | 182 | 6 | 1,506 | 103 | 25 | 33 | S/8,471 |

These totals are operational snapshots and can grow after capture. The restoration gate for Mireya must be a targeted **+2 calls / +2 citas delta** relative to the live baseline at execution, not a hard-coded final total.

## 5. Mireya callback/inbound BEFORE evidence

### `991144656`
- Marketing lead `5664`, CAPILAR, ad `CAPILAR- INJERTO REEL4`.
- Existing call `37062`: MIREYA, `SIN CONTACTO`, duration 635 sec.
- Agenda `6b1c4962-a597-45d8-8b72-d721d71c20f4`: PENDIENTE, 2026-08-20 15:00, `CITA_MANUAL`, CAPILAR; no direct lead/call IDs yet.
- Audit log IDs `51949` INSERT and `51948` DELETE prove call `37108` was inserted as `CITA CONFIRMADA`, MIREYA, `MARKETING`, ad `CAPILAR- INJERTO REEL4`, then deleted in the same operation window.

### `980547287`
- Marketing lead `5599`, CAPILAR, ad `CAPILAR- INJERTO REEL4`.
- Existing failed call `36912`: WILMER, `SIN CONTACTO`, duration 51 sec.
- Agenda `d80a4d17-5f2e-4169-8814-c5d5c50eac5c`: PENDIENTE, 2026-08-22 16:00, `CITA_MANUAL`, CAPILAR; no direct lead/call IDs yet.
- Audit log IDs `51954` INSERT and `51953` DELETE prove call `37110` was inserted as `CITA CONFIRMADA`, MIREYA, `MARKETING`, ad `CAPILAR- INJERTO REEL4`, then deleted.

`aos_gestiones_no_comerciales` currently contains no archive rows for 37108/37110, so later restoration must use audit evidence + lead + agenda; do not assume an archived full payload exists.

## 6. Buyer gaps / acquisition reference cases

- `992829013`: call `29445` (MIREYA, HIFU, CITA CONFIRMADA) before late-created lead `3963`; Agenda `7d8fbb56...` ASISTIO; 5 sales totaling **S/2,467**. Already an Acquisition V2 customer; operations remain a targeted Attribution V3 gap.
- `998564399`: call `30320` (WILMER, EXOSOMAS CAPILARES, CITA CONFIRMADA) before lead `4045`; initial Agenda `33dc643c...`; 4 later sales totaling **S/1,567**. Already an Acquisition V2 customer; later CONTINUIDAD agendas must not become new acquisition events.
- `973438607`: prior HIFU leads `1150` (05/02) and `2135` (11/03); first commercial conversion/sale 12/03 (TOXINA S/399 + product S/189). Approved nearest-prior fallback target is lead **2135**. Loop 1 does not mutate it.

## 7. Late-lead reconciliation correction discovered in Loop 1

The earlier planning shorthand **“19 strong / 17 compatible / 2 mismatches” is not canonical**. A live re-derivation exposed classifier drift.

- `961780427` must **not** be treated as a true CAPILAR↔BIO late-lead mismatch: CAPILAR lead `4650` existed ~1 hour **before** call `32014` and its CAPILAR Agenda; later BIO lead `4653` is a separate touchpoint. Loop 4 must test prior-lead matching first.
- `957549186` remains REVIEW: call `35976` and Agenda are CAPILAR while the identified later lead `5420` is BIO ESTIMULADOR and no equivalent compatible prior lead was established in this Loop.

A conservative re-derivation of null-direct-link, call+Agenda co-temporal cases identified at least these compatible candidates for later review/backfill: calls `14828,15076,15468,15750,19391,20704,20733,30320,33358,35858,36025`; `35976` remains mismatch REVIEW. This list is an analysis candidate set, **not an authorization to mutate**.

## 8. Existing call-lead matcher distribution BEFORE

2026 through 2026-08-18:
- DIRECT_LEAD_ID 100%: 22
- UNIQUE_PRIOR_LEAD 90%: 523
- UNIQUE_PRIOR_BY_TREATMENT 85%: 1
- AMBIGUOUS_PRIOR_LEAD 40%: 3
- NO_PRIOR_MARKETING_LEAD: 260

## 9. Concurrency / portfolio observations

Open PRs exist (#271 Sentinel maintenance, #277 CIA-F17, and legacy #126/#122). None is the current global mutable lock owner. They must remain isolated while this hotfix owns the lock.

## 10. Rollback contract

Before any later functional change:
1. exact-head revalidation is mandatory;
2. re-query the target rows immediately before mutation;
3. store affected row IDs and BEFORE JSON in the migration/execution report or existing audit mechanism;
4. preserve Agenda rows unless the specific loop explicitly proves a duplicate;
5. do not duplicate Acquisition/LTV customers when repairing operation-level attribution;
6. on rollback, restore target rows/links to this BEFORE state and compare the V2 function hashes and aggregate hashes above;
7. REV-F5 recovery is governed by `REV_F5_PAUSE_CHECKPOINT_20260818_MKT_INTEGRITY_V3.md`.

**Manifest status:** `BEFORE_CAPTURED / NO_FUNCTIONAL_MUTATION`.