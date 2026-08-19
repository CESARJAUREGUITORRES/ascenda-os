# MKT-INTEGRITY-HOTFIX-V3 — LOOP 5 Final Readback

**Loop:** Reparación Mireya y llamadas inbound/manuales  
**Business date:** 2026-08-18 Lima  
**Control PR:** #294  
**Merged main before this closeout:** `69abaa48f8691feb6adc43d9f53af7d590f96b6c`  
**Result:** `BLOCKED / STOPPED_PRE_PRODUCT`  
**Productive Supabase DML:** 0  
**Loop 6:** NOT STARTED

## Post-merge readback

Captured at **2026-08-18 22:09:21 Lima** after PR #294 merged.

### Target calls

- `37108`: absent.
- `37110`: absent.
- transaction-test audit rows persisted: 0.

This is expected because the mandatory simulation was rolled back and no productive apply was authorized.

### Target Agenda

`6b1c4962-a597-45d8-8b72-d721d71c20f4`:

- `lead_id_origen = NULL`;
- `llamada_id_origen = NULL`;
- row hash `94283cb5aa386ae270579da7436d2dbe`.

`d80a4d17-5f2e-4169-8814-c5d5c50eac5c`:

- `lead_id_origen = NULL`;
- `llamada_id_origen = NULL`;
- row hash `2f79f71ca0d8764c1d77007bff75eae4`.

Both hashes are unchanged from the pre-simulation baseline.

### Preserved prior calls

- `36912`: WILMER / SIN CONTACTO / hash `b76540d9a065e6e21c99a8575d813469`.
- `37062`: MIREYA / SIN CONTACTO / hash `d0c795e583e1890d61236ef822c04d2e`.

Both remain intact.

## Mireya KPI

Business date 2026-08-18:

- calls: **51**;
- CITA CONFIRMADA: **4**;
- Agenda total: **3,126**.

The productive Loop-5 delta is **0 calls / 0 citas**, because product DML was correctly stopped. The +2/+2 PASS gate was not reached.

## Marketing invariants

Unchanged:

- Acquisition V2 = **54**;
- Acquisition V3 = **55**;
- deterministic Acquisition V3 hash = `3223caf0ec5d1b264c4494775c6f7d58`;
- duplicate acquisitions = **0**;
- post-sale lead attribution = **0**;
- Attribution V2 = **126 ops / S/45,158.70**;
- Attribution V3 = **173 ops / S/66,644.10**.

## REV-F5

Unchanged:

- 6 batches;
- 15,498 expected;
- 7,064 source rows;
- 3,950 clusters;
- 0 members;
- 0 preview;
- 0 apply.

High-water timestamps remain:

- batch/source `2026-08-18T20:13:13.549661Z`;
- clusters `2026-08-15T22:23:56.291622Z`.

## Function integrity

Definition hashes remain unchanged:

- call guard `d05de50205e7c716cc048c4a5e6923a2`;
- manual Agenda cleanup `85398da8c4bf74366d10020abade08b4`;
- Acquisition V2 `7851ca8c9163625bda8fcf987a1def87`;
- Acquisition V3 `07762236ceb159ec29c34cc2eb1c5b3a`;
- Agenda matcher V3 `49c13d3f034b059871b2dc7aa0c7c981`;
- Call matcher V3 `8d9ff10aaee45542e6bb527142cea178`;
- Attribution V2 `630c46e0425e6941283f1b200d3a5ce2`;
- Attribution V3 `ef613afdbf9175c27ebc34bb0763961e`.

No frontend or production function was changed.

## Certified blocker

The transaction-only simulation proved the current active cleanup deletes the two reconstructed historical commercial calls after insert:

`trg_aos_hotfix_manual_agenda_cleanup_call_v1`
→ `aos_hotfix_manual_agenda_cleanup_v1()`.

The call↔Agenda timing deltas are:

- 37108: **0.933s**;
- 37110: **0.821s**.

Both lie inside the active ±10-second `CITA_MANUAL` cleanup window.

The Loop-5 contract forbids bypassing or changing this guard inside Loop 5. Therefore:

**LOOP 5 = BLOCKED / STOPPED_PRE_PRODUCT.**

No restoration is certified. No Loop-5 product DML occurred.

The blocker is assigned to **Loop 7 — Guards, cleanup e idempotencia**.

**LOOP 6 = NOT STARTED.**