# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-16 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `BOOKING-V3.2 — TECHNICAL PASS / READY HUMAN E2E CANARY`  
**OWNER AUTHORIZATION:** `PROCEDE · implementar todo de manera ordenada hasta dejar el siguiente canary listo`  
**PAUSED HIGH/CRITICAL LANE:** `CONV-L4 #508 — checkpoint preserved; resumes only after BOOKING-V3.2 canary closeout`  
**Legacy WA-L10 #456:** `FROZEN · SAFE-OFF EVIDENCE ONLY · NO NEW FEATURE PATCHING`  
**P0 #485:** `CLOSED / COMPLETED — PROD RECURRENCE+LOAD PASS`  
**Production safety:** Conversations autonomy remains `SAFE-OFF`.

## BOOKING-V3.2 certified technical checkpoint

- PR `#601` merged to `main`.
- Exact main SHA: `b95f05a03e53db2f5d4bda8d44c76d49de89e7aa`.
- Dedicated hosted gate `35067214061`: **PASS** — V3.1 contract + V3.2 contract + inline public-booking JavaScript syntax.
- Railway deployment `e3da44fe-6f99-4654-be38-b675f2d07878`: **SUCCESS**, exact SHA `b95f05a...`.
- Runtime startup: VAPID ready, branding/template/doctor caches loaded, F5 recovery healthy; no recurrence of the earlier Supabase timeout cascade in startup evidence.
- Supabase production: BOOKING-V3.1 attribution columns/functions live; source-aware appointment notification relabel uses live `contenido` column.
- Public booking catalog is now an adapter over canonical `aos_cat_tratamientos`, while preserving V2 public RPC signatures.
- `aos_agenda_citas` remains the only appointment persistence authority.
- HIFU + Carolina + San Isidro + 2026-09-18 live readback: `REAL_SLOTS_READY`, 10 slots.
- Advisor permanent-link authority live readback: `ok=true`, `source_channel=ADVISOR_LINK`, `link_type=asesor_permanente`.
- Public UI filters professionals to those with future scheduled days in a rolling three-month horizon.
- Advisor modal automatically resolves/reuses the advisor's stable long-lived booking URL and presents it ready to copy.

## Scope invariants

- No second agenda, patient, treatment, notification or Calendar authority was introduced.
- Public treatment choices are clinic operational treatment categories, not product/SKU names.
- Availability is validated against current schedules and revalidated under advisory lock immediately before booking insert.
- Advisor/campaign/source attribution is additive metadata only.
- Existing email, push/notification and Google Calendar flows remain reused.
- No automated real-patient booking fixture was created.

## HUMAN CANARY — current gate

Run one real controlled booking from the advisor permanent link and verify this chain:

`advisor link → only future-available professional → canonical treatment → real date/slot → patient form → booking success → aos_agenda_citas → ADVISOR_LINK/advisor attribution → admin/advisor notification + push → patient confirmation email → Google Calendar event/invite`.

Record PASS only after the complete chain is observed. During this human canary, BOOKING-V3.2 retains the sole HIGH/CRITICAL mutable lane.

## Return rule

After human canary PASS (or an explicit BOOKING pause due to an external blocker), update this file and return the mutable HIGH/CRITICAL lock to `CONV-L4 #508`, then continue L4 → L5 → L6 → L7 from its preserved CURRENT evidence. Do not run competing HIGH/CRITICAL mutations before that handoff.
