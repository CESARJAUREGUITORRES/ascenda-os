# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-16 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `BOOKING-V3.5 — TECHNICAL PASS / HUMAN MULTI-USER E2E CANARY AUTHORIZED`  
**OWNER AUTHORIZATION:** `PROCEDE con el loop correspondiente y todo lo necesario; prueba César + asesores`  
**PAUSED HIGH/CRITICAL LANE:** `CONV-L4 #508 — checkpoint preserved; resumes only after BOOKING closeout or explicit owner reprioritization`  
**Production safety:** Conversations autonomy remains `SAFE-OFF`.

## BOOKING-V3.5 current checkpoint

- V3.4 governed patient confirmation boundary remains active at `/api/booking/public-confirmation-v33` and is preloaded in the certified Phase-S runtime.
- V3.5 migration `20260916161000_booking_v35_attribution_channels_and_monitor.sql` is applied to canonical Supabase project `ituyqwstonmhnfshnaqz`.
- GitHub implementation SHA `028c1078a3e6fabd403c79868136581ff2c2b636` added canonical WEB/EMAIL channel attribution and monitoring fields.
- Railway production deployment `7571de23-0129-4af3-8302-bbc77c153388`: **SUCCESS** on exact implementation SHA; `/health` succeeded and runtime started healthy.
- Production readback: **10 active users / 10 active personal links / exactly 1 active permanent link per owner**.
- Personal links resolve to `ADVISOR_LINK` + exact owner identity. Website channel resolves to `WEB / ORGANICO / ASCENDA_CLINIC_WEB`.
- `aos_monitoreo_equipo(current_date)` is live with `citas_web` and `link_personal`; current production readback successfully separates WEB activity.
- Existing booking persistence remains canonical in `aos_agenda_citas`; no second agenda/backend was introduced.
- Existing Google Calendar/Contacts, push/in-app and transactional email authorities are reused.
- Human canary matrix is frozen in `docs/control/BOOKING_V35_HUMAN_CANARY_MATRIX_20260916.md`.

## HUMAN MULTI-USER CANARY — current gate

Run controlled bookings from:
1. CESAR permanent personal link;
2. advisor personal links, one booking per tester;
3. canonical WEBSITE link as a separate organic-web test.

Required E2E path:
`assigned link → Agenda de Citas → professional/treatment/date/slot → booking success → exact source/owner attribution → internal Agenda → push + in-app → patient transactional confirmation email → Google Calendar invitation/event`.

Technical readback after each booking must verify `source_channel`, `source_campaign`, `source_link_token`, `asesor`, `id_asesor`, appointment uniqueness and Google sync/event evidence.

**Closeout rule:** do not close BOOKING-V3.5 from technical preflight alone. At least César's canary and representative advisor canaries must include real human evidence of the transactional email and Google Calendar event. Any failed leg remains FAIL until isolated and corrected.

## Return rule

After BOOKING-V3.5 human canary PASS, update this file. The preserved formal return lane is `CONV-L4 #508`, unless the owner explicitly reprioritizes the next HIGH/CRITICAL lock to the ASCENDA CLINIC website/agenda integration lane.
