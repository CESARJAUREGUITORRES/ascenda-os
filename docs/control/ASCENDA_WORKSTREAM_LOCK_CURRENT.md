# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 PAUSED RECOVERABLY / MKT-INTEGRITY-HOTFIX-V3 ACTIVE  
**Owner assignment:** 2026-08-18 Lima — Marketing Integrity & Call Center Semantics V3  
**Loop-5R entry main:** `19c326a7f3193ec88dc3ec7755aa29391b091dfd`  
**Loop-5 functional merge:** PR #296 → `bec9da0d8f114e41632a99cf7732e3949237f760`  
**Previous lock:** `REV-F5-CLOSEOUT` — `PAUSED_RECOVERABLY`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` only after MKT Integrity production certification and handback.

## Roadmap execution state

- LOOP 1 — Control / freeze / BEFORE package: **PASS**.
- LOOP 2 — Marketing V3 Shadow: **PASS**.
- LOOP 3 — Acquisition V2↔V3 parity: **PASS**.
- LOOP 4 — Deterministic late-lead backfill: **PASS**.
- LOOP 5 — Mireya repair / inbound-manual semantics: **PASS**.
- LOOP 6 — Semántica Call Center + modal paciente existente: **NOT STARTED**.

Loop 5 was unblocked by the narrowly scoped prerequisite `LOOP 5R — cleanup semantics + historical inferred reconciliation`. Do not begin Loop 6 automatically.

## REV-F5 recoverable pause

Canonical checkpoint: `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_MKT_INTEGRITY_V3.md`.

Current frozen state remains:

- 6 source batches / **15,498** expected rows;
- **7,064** source rows;
- **8,434** remaining;
- **3,950** identity clusters;
- members **0**;
- preview **0**;
- apply events **0**.

Canonical Loop-1 recovery hashes remain:

- batches `807f03e96e5786203d867938c3938154`
- source rows `62b8fbedaa5da450a38c2471dd23b6b9`
- clusters `2d39d9ac990fee61a7ecb6ffa52efb64`

## Marketing acquisition/revenue invariants

- Acquisition V2 = **54**.
- Acquisition V3 = **55**.
- V3-only = exactly `973438607 → lead 2135`.
- deterministic V3 hash = `3223caf0ec5d1b264c4494775c6f7d58`.
- duplicate acquisitions = **0**.
- post-sale lead attribution = **0**.

Attribution remains shadow-only and unchanged:

- V2 = **126 ops / S/45,158.70**.
- V3 = **173 ops / S/66,644.10**.

The +47 ops / +S/21,485.40 V3 delta remains reserved for Loop 9; no cutover occurred.

## Loop 4 state preserved

Loop 4 remains PASS with 24 deterministic call links + 6 Agenda direct links. No Loop-4 repair was reverted by Loop 5R.

## Loop 5R — cleanup semantic prerequisite

Canonical artifacts:

- `docs/control/MKT_INTEGRITY_V3_LOOP5R_IMPACT_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP5R_EXECUTION_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP5R_ROLLBACK_20260818.sql`
- `docs/control/MKT_INTEGRITY_V3_LOOP5R_POLICY_NOTE_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP5_FINAL_READBACK_20260818_V2.md`
- `supabase/migrations/20260819033000_mkt_integrity_v3_loop5r_cleanup_semantics.sql`
- `supabase/backfills/20260818_mkt_integrity_v3_loop5r_historical_and_mireya.sql`

Applied migration:

`mkt_integrity_v3_loop5r_cleanup_semantics`

Current cleanup function hash:

`a6f918f64ac56f587a75ed0aebde0e09`

The cleanup continues deleting generic legacy `LLAMADA` side-effect calls but preserves explicitly semantic calls:

- `LLAMADA_MANUAL_COMERCIAL`
- `CALLBACK_INBOUND`
- `INFERIDA_HISTORICA`

Canary with all triggers enabled:

- generic `LLAMADA` surviving rows = **0**;
- `LLAMADA_MANUAL_COMERCIAL` = **1**;
- `CALLBACK_INBOUND` = **1**;
- `INFERIDA_HISTORICA` = **1**.

No trigger was disabled.

## Loop 5 — Mireya restoration completed

Restored observed calls:

- `37108` → `991144656` → lead `5664` → MIREYA → `LLAMADA_MANUAL_COMERCIAL`.
- `37110` → `980547287` → lead `5599` → MIREYA → `LLAMADA_MANUAL_COMERCIAL`.

Existing Agenda links:

- `6b1c4962-a597-45d8-8b72-d721d71c20f4` → lead 5664 / call 37108.
- `d80a4d17-5f2e-4169-8814-c5d5c50eac5c` → lead 5599 / call 37110.

Prior failed calls remain unchanged:

- `36912` WILMER / SIN CONTACTO / hash `b76540d9a065e6e21c99a8575d813469`.
- `37062` MIREYA / SIN CONTACTO / hash `d0c795e583e1890d61236ef822c04d2e`.

Mireya business-date KPI 2026-08-18:

- before: **51 calls / 4 citas**;
- after: **53 calls / 6 citas**;
- exact targeted delta: **+2 / +2**.

Agenda total remained **3,126**.

## Historical inferred reconciliation approved and applied

Historical imported Agenda/venta alone does not prove an observed call. A synthetic call is only allowed when a Marketing lead predates first conversion and there is no call through that conversion. Such rows are explicitly marked `INFERIDA_HISTORICA`, use `lead_fecha` as a proxy date and `00:00:00` as a sentinel/proxy time, and document that the real call time is unknown.

Exactly four strict live cases qualified:

- call `37199` / `954848810` / lead 51 / WILMER.
- call `37200` / `960381839` / lead 571 / MIREYA.
- call `37201` / `964633863` / lead 667 / MIREYA.
- call `37202` / `930260184` / lead 661 / WILMER.

Each corresponding historical attended/effective Agenda is now directly linked to the inferred call and lead. No Agenda row was created.

## Idempotency

Post-apply dry-run predicates:

- Mireya calls still needing insert = **0**.
- inferred historical calls still needing insert = **0**.
- Agenda rows still needing link = **0**.

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. `MKT-INTEGRITY-HOTFIX-V3` continues to own the global mutable lock. REV-F5 and all other HIGH/CRITICAL workstreams remain read/audit/documentation or regression-only.

## Next sequential loop

`LOOP 6 — Semántica Call Center + modal paciente existente`

Loop 6 is **NOT STARTED** and requires explicit invocation.

## Exit / handback

The global lock remains `MKT-INTEGRITY-HOTFIX-V3`. No handback to REV-F5 occurred.
