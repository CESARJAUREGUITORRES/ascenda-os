# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-16 America/Lima  
**ACTIVE PRODUCT LANE:** `AGENDA-UX-V1 — DESIGN MAY START ON STABLE BOOKING CORE`  
**BOOKING CLOSEOUT STATUS:** `BOOKING-V3.9 / COORD-CITAS-V1.1 — TECHNICAL PASS · HUMAN CLOSEOUT PARTIAL`  
**OWNER AUTHORIZATION:** `validar baseline y comenzar diseño nuevo de Agenda sin alterar el core`  
**PAUSED HIGH/CRITICAL LANE:** `CONV-L4 #508 — preserved; resume only by explicit owner reprioritization`  
**Production safety:** Conversations autonomy remains `SAFE-OFF`.

## Stable functional baseline

- Canonical appointment ledger: `public.aos_agenda_citas`. No parallel agenda/backend.
- Public booking confirmation: complete Zi Vital data contract + branding from `aos_configuracion`.
- Owner visually approved the refreshed booking confirmation email on 2026-09-16: **HUMAN PASS**.
- Patient 360 canonical selection/fusion handling is deployed; owner confirmed patient records can be opened again: **HUMAN PASS**.
- Governed `Mi link web` center is deployed; owner confirmed the new panel is visible and acceptable: **HUMAN PASS**.
- Production readback: **10 active users / 10 active permanent advisor links**.
- Admin monitor exposes `Web`; current readback remains **3 organic WEB bookings / 0 personal-link bookings** before personal-link canary.
- Coordination Comercial receives appointment reports from the canonical appointment ledger.
- First live automatic report (RUVILA / reactivated appointment) was written with `report_status=SENT`, no error, and owner approved the visual structure: **HUMAN PASS**.
- Comercial canonical group membership: CESAR, SRA CARMEN, MIREYA, RODRIGO, RUVILA, WILMER.
- Automatic report human template V1.1:
  classification → patient → DNI/CE → phone → email → sede → date → time → treatment → attention/professional → observations → advisor/origin.
  Internal appointment ID/channel/campaign remain auditable in DB but are omitted from the visible card.

## Coordination composer

- Both advisor and admin coordination surfaces were patched against DOM replacement while typing.
- Admin coordination redundant overlapping 15s poll was removed; 8s channel refresh remains authoritative.
- Draft/focus/cursor preservation and typing guards are deployed.
- Latest production deployment containing these changes reached **SUCCESS**.
- **Human micro-canary still required:** type continuously for >10 seconds in Coordination and confirm the text no longer clears before send.

## Advisor personal-link attribution

- Governed dashboard RPC: `aos_booking_advisor_link_dashboard_v38(p_token)`.
- User identity derives from canonical app session; callers cannot select another advisor.
- Invalid app token returns `UNAUTHORIZED`.
- UI exposes one personal permanent tokenized link per user.
- **Human personal-link canary still required:** the owner must create one booking from the copied `Mi link web` URL containing `?t=...`.
- Expected evidence: `source_channel=ADVISOR_LINK` + owner user ID + non-null `source_link_token`.
- Only after this owner canary should every advisor create one controlled booking from their own link.

## COORD-CITAS automatic trigger

- Trigger: `trg_zzz_aos_coord_appointment_report_v1` on INSERT of canonical `aos_agenda_citas`.
- Covers Agenda, Call Center, direct Agenda, organic WEB, advisor links, EMAIL and future governed booking surfaces because it observes the canonical ledger rather than individual UIs.
- Reporting failures are isolated and never block booking persistence.
- Idempotency/audit ledger: `aos_coord_appointment_reports`.
- Current production evidence: **1 report / 1 SENT / 0 ERROR**.

## Production runtime

- Current Railway production deployment `719a621f-442e-499a-87fc-367e92a8301f`
- Commit: `395ef1dd90e6d3a51e9f41d5d9d3a3bcfa1ae14f`
- Status: **SUCCESS**.

## Agenda redesign authorization

The Agenda visual redesign may begin now because the booking core, patient identity, email, Google integration, link authority, source attribution and coordination reporting are separated from presentation.

Design rules:
1. Do not create a second appointment ledger or booking API.
2. Preserve `aos_agenda_citas` as authority.
3. Preserve booking classification/attribution contracts.
4. Preserve notification, Zi Vital email and Google Calendar/Contacts flows.
5. UI/theme changes may alter layout, colors, typography, hierarchy and interaction design only through governed existing contracts.
6. The future ASCENDA CLINIC website/theme remains presentation-only and consumes the same core.

## Remaining human closeout while Agenda UX work proceeds

1. Coordination composer >10-second typing micro-canary.
2. César personal-link booking → verify `ADVISOR_LINK`.
3. After owner PASS, one personal-link booking per advisor.

These checks do **not** block starting `AGENDA-UX-V1`; they block only final BOOKING-V3.9 certification.


## COORD-V7 — Chat lock + conversation search · 16/09/2026

- Admin Coordination now has per-chat **Buscar** and **Bloquear/Desbloquear** controls.
- Lock is enforced server-side, not only visually:
  - human text/messages are rejected while locked,
  - direct message inserts/edits/deletes are guarded,
  - attachments are disabled in the UI and guarded by the message lock,
  - `CITA_AUTO` remains explicitly allowed so operational appointment reports continue entering the channel.
- Lock audit fields live on `aos_canales`: `bloqueado`, `bloqueado_por`, `bloqueado_at`.
- Lock mutation is governed by `aos_coord_set_channel_lock_v1` and requires a valid Auth V3 app session with ADMIN role.
- Invalid-token tests for lock/search both return `UNAUTHORIZED`.
- Search uses governed `aos_coord_search_messages_v1` and can match sender or message content in the active channel (patient name, DNI, phone, treatment, observations, etc.), up to 100 results.
- Advisor Coordination receives the same conversation-search capability and lock-state UI, but no unlock/lock authority.
- `aos_mis_mensajes` now returns lock state to advisor surfaces.
- UI runtime asset: `app/public/coord-lock-search-v1.js`; app-session injection handled in `phase2-service-worker.js`.
- JavaScript syntax checks passed for the new runtime asset, clinic shell loader and service worker.
- Railway deployment `b96dea33-ab91-4878-9e04-42e30442605f` / commit `b33a6c219ff489b7d4628756c6e2ad74bec1fd76`: **SUCCESS**.
- Comercial is **not auto-locked**; owner can decide per chat. This preserves current operation while enabling a report-only mode when desired.
- Human micro-canary: open Comercial → search `Danilo` or DNI `08325370` → lock chat → verify composer disappears/blocks messages → confirm automatic appointment reports still arrive → unlock if desired.


## COORD-V7.2 — HUMAN CANARY PASS · 16/09/2026

Owner confirmed in production:
- Chat lock works from Superadmin.
- Locked state is visible to advisor users.
- Unlock works and propagates.
- Conversation search works for appointment data.
- Left chat drawer visual behavior accepted.
- Right information drawer visual defect fixed and accepted.
- Comercial can operate as report-only while still receiving automatic appointment reports.

**Status:** COORD-V7.2 = HUMAN PASS / CLOSED.  
**Next lane:** AGENDA-UX-V1 — owner will provide visual references and desired booking-flow redesign. Preserve all certified booking, attribution, notification, email, Google and Coordination contracts.


## AGENDA-UX-V1 — SHADOW FRONTEND READY · 16/09/2026

**Status:** `SHADOW READY / HUMAN VISUAL CANARY`

A new public booking surface was added at `app/public/agendar-v3.html` without changing the certified V2 entrypoint or personal-link generator.

### V3 UX implemented
- Service-first entry: **Facial / Corporal / Capilar**.
- Premium responsive cards, layered shadows, depth/3D effects and mobile-first layout.
- Treatment discovery by domain, category chips and search.
- Routing uses the existing Team > Services authority:
  - treatment only on doctor profiles → exact-provider medical route;
  - treatment only on nursing profiles → clinical-team pool route;
  - treatment configured for both → patient sees a neutral choice between `Consulta con especialista` and `Equipo clínico especializado`.
- Doctor route displays only professionals assigned to that treatment and with future **SAN ISIDRO** shifts.
- Current production readback for September 2026:
  - Dra. Carolina: future San Isidro shift dates present;
  - Dra. Pamela: no San Isidro dates;
  - Dra. Yessica: no San Isidro dates.
  Therefore the current doctor flow resolves visually to Carolina when applicable.
- Nursing route never asks the patient to choose an individual nurse. It uses the existing `SITE_POOL` availability authority.
- Public site is fixed to **SAN ISIDRO**; no site selector is shown.
- Calendar has **7-day** and **month** views.
- Slot validation still uses `aos_booking_availability_v2`.
- Booking write still uses `aos_agendar_publica_v2`.
- Confirmation email remains `/api/booking/public-confirmation-v33`.
- Booking tokens and attribution are preserved: WEB/ADVISOR_LINK continue through the existing `p_token` contract.
- Existing notification, Google Calendar/Contacts and Coordination report flows remain downstream of the same canonical appointment write.

### Additive read helpers
- `aos_booking_pool_days_v3(role,year,month,site)`: future pool shift days.
- `aos_booking_provider_days_v3(provider,year,month,site)`: future provider days scoped to San Isidro.
- `aos_booking_patient_lookup_v3(identity)`: exact-match DNI/phone lookup for public booking; excludes fused patient rows and does not provide broad patient search.

### Safety / rollout
- `agendar-v2.html` remains the current certified public authority UI.
- `agendar.html` redirect remains on V2.
- `booking-link-center-v37.js` continues generating V2 links.
- V3 is **shadow only** until owner visual + functional canary PASS.
- No replacement of the canonical ledger `aos_agenda_citas`.
- No parallel booking backend or duplicated Google/email/notification logic.

### Validation
- V3 embedded JavaScript syntax: PASS.
- Exact patient lookup by owner DNI and phone: PASS.
- Nursing San Isidro future-days helper: PASS.
- San Isidro provider-day helper: PASS.
- Railway deployment `79eb84fa-bc3b-4000-ac09-e6a61372cf51` / commit `f1920e96164aee6d59692cfbe33ba0aec83a5026`: **SUCCESS**.

### Human canary sequence
1. Open V3 shadow without token and inspect desktop/mobile UX.
2. Facial → a doctor-only treatment (e.g. route derived from Team services) → Carolina → 7-day/month calendar → real slot.
3. Choose a team-only treatment → clinical-team card → pool calendar/slots.
4. Test exact DNI/phone autofill.
5. Run one WEB booking; verify Agenda, attribution, push/in-app, approved Zi Vital email, Google Calendar and Comercial report.
6. Run one advisor-token V3 booking and verify `ADVISOR_LINK`.
7. Only after PASS may V2 links/redirect be migrated to V3.


## AGENDA-UX-V1.2 — APPROACH TAXONOMY + 4:5 VISUAL PASS · 16/09/2026

Owner feedback applied to the V3 shadow surface without changing certified booking contracts.

### Visual changes
- Domain cards keep the approved look but their hero artwork now uses a **4:5 portrait ratio**.
- On mobile, domain cards become a horizontal snap carousel to preserve portrait artwork without compressing the layout.
- Doctor / clinical context image also uses **4:5 portrait ratio** and is larger on desktop; mobile keeps a centered portrait card.
- Final success check is now green.

### Treatment architecture
The flat capability list was removed. Step 2 now renders only curated **parent booking categories**, grouped by governed Zi Vital approaches:
- Facial:
  - Skin Signature
  - Harmony Design
  - BioRegen Face
- Corporal (current canonical knowledge authority):
  - Body Reset
  - Sculpt Body
  - Sculpt Booty
- Capilar (current canonical knowledge authority):
  - Activación & Regeneración / Hair Revival
  - Mantenimiento & Prevención / Hair Guard

The UI intentionally excludes noisy child capabilities and generic `CONSULTA MEDICA` from the public treatment picker.

Representative parent labels include:
- Ácido hialurónico
- Bioestimuladores
- HIFU · Zi Frozen
- Toxina
- Mesoterapia
- Biorevitalización
- Radiofrecuencia fraccionada
- Hidrofacial
- Peelings
- Exosomas / PRP
- curated corporal/capilar parents backed by the existing booking catalog.

Every public parent option is mapped to an existing `aos_booking_public_catalog_v2` capability; automated readback confirmed **25/25 configured capabilities are present**. Laser is not exposed because no matching active public booking capability currently exists; fail-closed behavior is intentional.

### Preserved contracts
- `aos_booking_availability_v2`
- `aos_agendar_publica_v2`
- patient lookup V3
- WEB / ADVISOR_LINK attribution
- Zi Vital confirmation email
- Google Calendar / Contacts
- push / in-app notifications
- Comercial automatic report

### Validation
- Embedded V3 JavaScript syntax = PASS.
- Parent taxonomy checks = PASS.
- Flat category chips removed.
- 4:5 domain + specialist image CSS checks = PASS.
- Green success state = PASS.
- Railway deployment `acc5233a-8140-42b7-b147-f2aaa641fec3` / commit `f25de4002fbe5c847ffff0f185c6070a4d2dc3a7` = **SUCCESS**.

**Next gate:** HUMAN VISUAL CANARY V1.2 on desktop + mobile, then one doctor-route booking and one team-route booking before any V2→V3 cutover.
