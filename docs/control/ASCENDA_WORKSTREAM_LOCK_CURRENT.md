# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-16 America/Lima  
**ACTIVE PRODUCT LANE:** `CIA-PANEL · PACK-A CLOSED · PACK-B NOT STARTED`  
**BOOKING CLOSEOUT STATUS:** `AGENDA V3 — HUMAN CANARY PASS · CORE FROZEN · THEME HANDOFF READY`  
**OWNER AUTHORIZATION:** `finish CIA PACK-A Foundation & Live Reconciliation; freeze PACK-B delta; stop before PACK-B implementation`  
**PARALLEL/PAUSED CONVERSATIONS STATE:** `CONV-001 #502 preserved; CONV-L4 #508 closed; legacy WA-L10 #456 remains SAFE-OFF / separately gated`  
**Production safety:** Conversations autonomy remains `SAFE-OFF`.

## CIA-PANEL execution lock · 16/09/2026

- Agenda V3 remains a frozen certified dependency; do not reopen its core while CIA-PANEL work is active unless a regression is proven.
- Current CIA execution authority: `docs/control/commercial-intelligence/CIA_EXECUTION_PACKS_CURRENT.md`.
- PACK-A authoritative closeout: `docs/control/commercial-intelligence/CIA_PACK_A_CLOSEOUT_20260916.md`.
- PACK-A = `CLOSED · PASS WITH EXPLICIT PACK-B PREREQUISITES`.
- The previous automatic PACK-A → PACK-B continuation is superseded by the current owner scope.
- PACK-B is **NOT STARTED** and requires an explicit owner start.
- When PACK-B is started, prerequisite order is `P1 segment freshness → P2 governed queue-config gateway/RLS migration → P3 resolver UX/performance → Audience Builder/Library → controlled assignment`.
- First human stop inside PACK-B remains Human Canary #1 for one saved Audience → one advisor → exact assigned work/readback.
- No PACK-C channel activation is authorized by this lock.

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

- Current Railway production deployment `b40cb55e-cc4d-4502-b0f2-0b466ad868da`
- Commit: `ed20fab28ddebf917a9de660dacb2cbf14daaedb`
- Status: **SUCCESS**.
- CIA PACK-A made no production runtime/database mutation; its branch is control/docs-only.

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


## BOOKING-V3.12 / COORD-CITAS-V1.2 — FRIENDLY ATTRIBUTION LABELS · 16/09/2026

Human-facing attribution formatting is now normalized before the final canary.

- Push / in-app appointment labels never expose advisor UUIDs, booking tokens or full URLs.
- Personal advisor links render as `Link Cesar`, `Link Ruvila`, etc., resolved from `aos_usuarios`.
- Organic/company web traffic renders as `Web orgánico`.
- Coordination > Comercial automatic cards render:
  - personal link: `🔗 CITA WEB · LINK CESAR` + `Asesor / origen: CESAR`;
  - company/organic web: `🌐 CITA WEB · ORGÁNICO` + `Asesor / origen: LINK WEB`.
- Automatic internal-chat push sender is therefore human-readable (`Chat · CESAR` / `Chat · LINK WEB`) instead of UUID.
- Canonical appointment attribution fields remain unchanged; this is a presentation/notification layer only.
- Existing notification records were relabeled from canonical appointment data. Historical locked Comercial messages were intentionally not rewritten because the channel lock guard blocks retroactive mutation; all new automatic reports use the new labels.
- Supabase migration `booking_v312_friendly_source_labels` = PASS.
- GitHub migration file: `20260916210000_booking_v312_friendly_source_labels.sql`.
- Railway deployment `06933cc5-5d74-43f7-a8f9-5be1219619eb` / commit `ec6246183d4513bfcb4a2c5e8c70595d91d1ea50` = SUCCESS.
- Readback on the prior personal-link canary resolves `AD4FC2AC-...` → `CESAR`; admin notification now reads `Nueva cita · Link Cesar`.

**Next gate:** one complete human V3 flow and confirm Agenda + push/in-app + Comercial + patient email + Google Calendar.


## CIA-PANEL · PACK-A CLOSEOUT · 16/09/2026

- Reconciled exact base: `main@ed20fab28ddebf917a9de660dacb2cbf14daaedb`.
- Railway production on that base: `b40cb55e-cc4d-4502-b0f2-0b466ad868da` = **SUCCESS**.
- Canonical CIA contact population: **13,238**.
- Governed Audience filter registry: **73/73 PASS**; 10 existing presets validate/resolve.
- PACK-A discovered material segmentation-cache drift: **1,692 missing contacts + 2,454 lifecycle mismatches** versus current live calculation. Freshness claim must fail closed until P1 repair/readback.
- Current Audience resolver is functionally valid but not safe for naive keystroke-driven counts: observed ~2.91 s count and ~1.66 s preview on `LEADS_UNWORKED_7D`; PACK-B must use bounded interactive semantics and optimize rather than inflate timeouts.
- Current Call Center still relies on legacy `tipo_cola`/Global Logic compatibility; production retains four advisors in `global` mode.
- `admin-calls.html` still mutates `aos_cola_config` directly from browser under broad compatibility RLS. PACK-B must introduce gateway → migrate UI → smoke → harden RLS, never revoke first.
- CIA WhatsApp bridge evidence remains insufficient as a reusable audience identity base; transport/conversation authority stays separate and autonomous WhatsApp remains SAFE-OFF.
- PACK-A changed **no runtime/database/business data**. Closeout is control/docs only.
- Full evidence and frozen implementation delta: `docs/control/commercial-intelligence/CIA_PACK_A_CLOSEOUT_20260916.md`.

**LOCK RESULT:** `PACK-A CLOSED · PACK-B NOT STARTED`. No automatic pack transition is authorized by this file.