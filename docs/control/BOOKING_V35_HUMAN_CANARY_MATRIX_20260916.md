# BOOKING-V3.5 — HUMAN CANARY MATRIX

Captured: 2026-09-16 America/Lima
Status: READY FOR HUMAN E2E CANARY
Production: https://ascenda-os-production.up.railway.app

## Gate already passed
- Supabase canonical project: `ituyqwstonmhnfshnaqz`.
- 10 active users / 10 active permanent personal links / exactly 1 active link per owner.
- Personal links resolve as `source_channel=ADVISOR_LINK` + exact `id_asesor`.
- Canonical website link resolves as `source_channel=WEB`, `advisor_code=ORGANICO`, campaign `ASCENDA_CLINIC_WEB`.
- `aos_monitoreo_equipo` exposes `citas_web` and `link_personal`.
- Railway production deployment `7571de23-0129-4af3-8302-bbc77c153388` SUCCESS on SHA `028c1078a3e6fabd403c79868136581ff2c2b636`; `/health` succeeded.
- `aos_agenda_citas` remains the only appointment persistence authority.

## Canary links
Base path: `https://ascenda-os-production.up.railway.app/agendar-v2.html?t=`

| Owner | Role | Token | Expected source |
|---|---|---|---|
| CESAR | admin | `020d9179` | ADVISOR_LINK / CESAR |
| DRA CAROLINA | admin | `0db673d4` | ADVISOR_LINK / DRA CAROLINA |
| JHORDANO | asesor | `f147499e` | ADVISOR_LINK / JHORDANO |
| JOSELO | admin | `a2284e46` | ADVISOR_LINK / JOSELO |
| MIREYA | asesor | `cd6dc8fc` | ADVISOR_LINK / MIREYA |
| PAMELA | doctora | `c1065946` | ADVISOR_LINK / PAMELA |
| RODRIGO | asesor | `98290466` | ADVISOR_LINK / RODRIGO |
| RUVILA | asesor | `f3b5d657` | ADVISOR_LINK / RUVILA |
| WILMER | asesor | `67e04a3f` | ADVISOR_LINK / WILMER |
| YESSICA | doctora | `1e7d97dd` | ADVISOR_LINK / YESSICA |
| WEBSITE | organic | `e187c443` | WEB / ORGANICO / ASCENDA_CLINIC_WEB |

## Human procedure
Each tester opens only their assigned link in an incognito/private browser or a Google account distinct from the staff account. Use a real reachable email. Select professional, treatment, future date and available slot; submit exactly one booking.

Required human evidence per booking:
1. Success screen in Agenda de Citas.
2. Appointment visible in internal Agenda.
3. Push/in-app appointment notification received by the governed internal recipient(s).
4. Patient transactional confirmation email received.
5. Google Calendar invitation/event received/created.

## Technical readback after each booking
Verify in `aos_agenda_citas`: `id`, `fecha_cita`, `hora_cita`, `asesor`, `id_asesor`, `source_channel`, `source_campaign`, `source_link_token`, `gcal_event_id`, `ts_creado`.

PASS rules:
- personal link: `source_channel=ADVISOR_LINK`, `id_asesor` equals link owner, `source_link_token` equals assigned token;
- website link: `source_channel=WEB`, no personal owner, campaign resolves to website authority where persisted;
- no duplicate appointment rows;
- governed confirmation endpoint succeeds;
- Google sync/event evidence exists;
- real recipient observes transactional email.

Do not close BOOKING-V3.5 from DB-only evidence. Human inbox + Google event evidence is mandatory.
