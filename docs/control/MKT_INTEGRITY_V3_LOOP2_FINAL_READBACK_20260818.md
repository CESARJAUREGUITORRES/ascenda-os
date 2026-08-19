# MKT-INTEGRITY-HOTFIX-V3 — LOOP 2 Final Readback

**Loop-2 functional merge:** PR #288  
**Merged main:** `63e7cefe4c0845aa87f0da59419aea0cee5afe0b`  
**Live migration:** `20260819015951_mkt_integrity_v3_shadow_loop2_20260818`  
**Business date:** 2026-08-18 Lima  
**Loop 3:** NOT STARTED

## Post-merge certification

Supabase final readback after PR #288:

- Acquisition V2: **54**.
- Acquisition V3 shadow: **55**.
- V3-only acquisition: exactly `973438607 → lead 2135`, first sale 2026-03-12, `NEAREST_PRIOR_FIRST_SALE`, confidence 55.
- Attribution V2: **126 ops / S/45,158.70**.
- Attribution V3 shadow: **173 ops / S/66,644.10**.
- Calls `37108` and `37110`: still absent; restoration not performed.

## V2 integrity

All certified V2 definition hashes remain identical to the Loop-1 BEFORE manifest after the Loop-2 migration and GitHub merge. No V2 object was replaced.

## V3 ACL/read-path

All eight exact Loop-2 V3 objects remain executable only by `postgres` and `service_role`. No anon/authenticated/public execute grant exists.

## Business-data no-write gate

Counts immediately before persistent DDL and at final post-merge readback are identical:

- `aos_llamadas`: **35,296**
- `aos_agenda_citas`: **3,125**
- `aos_leads`: **5,669**
- `aos_ventas`: **1,299**

Therefore Loop 2 caused **0 business-data writes**. There were no backfills and no Mireya restoration.

## REV-F5 final gate

Still:

- batches 6;
- expected 15,498;
- persisted source rows 7,064;
- clusters 3,950;
- members 0;
- preview 0;
- apply 0.

Maximum F5 write timestamps remain older than the Loop-1 freeze. Loop 2 caused no REV-F5 mutation.

Canonical Loop-1 recovery hashes remain:

- batches `807f03e96e5786203d867938c3938154`
- source rows `62b8fbedaa5da450a38c2471dd23b6b9`
- clusters `2d39d9ac990fee61a7ecb6ffa52efb64`

The exact SQL serialization used to generate those three hashes was not persisted in Loop 1; any differently serialized ad-hoc hash is not evidence of drift. Counts + write timestamps demonstrate no F5 write.

## Frontend gate

PR #288 changed no `app/**` file. Productive Marketing modal remains on its existing RPC path and V3 remains service-role shadow only.

## Final result

`LOOP 2 = PASS`

Next sequential loop, only when explicitly invoked:

`LOOP 3 — PARITY ACQUISITION V2 ↔ V3`

Do not start automatically.
