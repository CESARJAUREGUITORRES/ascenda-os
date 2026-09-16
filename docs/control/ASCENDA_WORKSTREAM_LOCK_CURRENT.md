# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-16 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `BOOKING-V3.4 — TECHNICAL PASS / READY FINAL HUMAN E2E CANARY`  
**OWNER AUTHORIZATION:** `PROCEDE · corregir canary completo y dejar siguiente prueba lista`  
**PAUSED HIGH/CRITICAL LANE:** `CONV-L4 #508 — checkpoint preserved; resumes only after BOOKING closeout`  
**Production safety:** Conversations autonomy remains `SAFE-OFF`.

## BOOKING-V3.4 current checkpoint

- Human V3.2/V3.3 evidence: public booking persisted correctly, Agenda showed the appointment, push + in-app notification arrived, and Google Calendar invitation arrived.
- Defect isolated from that canary: legacy unauthenticated `/api/send-template` call returned HTTP 401, so the patient confirmation email was missing while booking and Google sync succeeded.
- PR `#603` merged to `main`.
- Exact main SHA: `0e57fb6b895cdecef52d528a60a274674b4372cf`.
- Railway deployment `5a4cd140-c321-4124-be78-24459b8d3a90`: **SUCCESS**, exact SHA `0e57fb6...`; healthcheck succeeded and VAPID/runtime caches started healthy.
- Public booking now calls the governed same-origin `/api/booking/public-confirmation-v33` boundary by canonical `appointment_id`; that boundary reloads the appointment server-side before sending the transactional confirmation.
- The boundary is installed through the Railway `NODE_OPTIONS` preload without changing the certified Phase-S runtime topology.
- Public header is now `Agenda de Citas`; the redundant `ASCENDA · ZI VITAL` micro-brand row is removed.
- Permanent booking attribution is expanded to every active `aos_usuarios` account, not only ASESOR/ADMIN.
- Production readback: **10 active users / 10 active users with permanent booking link / 0 duplicate active-owner groups**.
- Existing source/campaign metadata remains canonical: `ADVISOR_LINK` for personal user links; campaign/source fields remain available for Email Marketing and future governed channels.
- `aos_agenda_citas` remains the only appointment persistence authority; Google Calendar/Contacts authority is unchanged.

## FINAL HUMAN CANARY — current gate

Run one controlled booking from a personal permanent link and verify:

`personal link → Agenda de Citas → professional/treatment/date/slot → booking success → correct user attribution → admin/user push + in-app → patient transactional confirmation email → Google Calendar invitation/event`.

For the final evidence, verify the resulting appointment source/advisor fields directly in Supabase and the corresponding Google sync/outbox state. Do not close BOOKING until the email is observed on the real recipient inbox.

## Return rule

After final human canary PASS, update this file and return the mutable HIGH/CRITICAL lock to `CONV-L4 #508`; then continue L4 → L5 → L6 → L7 from its preserved CURRENT evidence.
