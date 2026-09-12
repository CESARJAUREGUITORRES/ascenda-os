# ASCENDA OS — GOOGLE CALENDAR + CONTACTS INTEGRATION V1 — CURRENT

**Captured:** 2026-09-12 America/Lima  
**Program:** `INT-GOOGLE-001 — GOOGLE CALENDAR + CONTACTS`  
**Active gate:** `GC-0/GC-1 — OAuth + secure connection foundation`  
**Owner authorization:** `PROCEDE · implementar todo en el sistema · run until blocked hasta canary humano`  
**Risk:** CRITICAL (OAuth, secrets, external side-effects, Agenda)  
**Production sync flags:** SAFE-OFF

## Objective

Complete the existing `Google Calendar + Contacts` connector in ASCENDA so a client such as ZIVITAL can connect, change or disconnect an authorized Google account from Configuración without hardcoding Gmail accounts in source.

ASCENDA remains the source of truth. Google Calendar and Google Contacts are synchronized projections.

## Preserved authorities

- `public.aos_agenda_citas` remains the canonical appointment ledger.
- Existing governed booking/rebook/status authorities remain unchanged.
- Existing Resend email templates remain the communication authority; Google adds Calendar UX, not a replacement email system.
- Patient identity remains in ASCENDA. Google Contacts receives only the minimum operational contact data.
- No Google failure may roll back or corrupt an already-confirmed ASCENDA appointment.

## Google platform configuration already completed

- Google Cloud project: `ASCENDA OS`.
- Calendar API enabled.
- People API enabled.
- OAuth web client created.
- Redirect URI: `https://ascenda-os-production.up.railway.app/api/google/oauth/callback`.
- Test user configured.
- Railway production variables present:
  - `GOOGLE_CLIENT_ID`
  - `GOOGLE_CLIENT_SECRET`
  - `GOOGLE_REDIRECT_URI`
  - `GOOGLE_INTEGRATION_ENABLED=false`
  - `GOOGLE_CALENDAR_SYNC_ENABLED=false`
  - `GOOGLE_CONTACT_SYNC_ENABLED=false`

Secrets remain environment-only and must never be committed or surfaced to the browser.

## Target flow

`Booking authority -> canonical appointment -> transactional/event side-effect intent -> Google worker -> Calendar/People`.

OAuth flow:
`Configuración > Integraciones > Google Calendar + Contacts -> Conectar Google -> Google consent -> callback -> encrypted refresh-token storage -> calendar selection`.

Calendar:
- create one deterministic event per appointment;
- store/use `gcal_event_id`;
- patient email is attendee when valid;
- rebook patches the same event;
- cancel removes/cancels the same event;
- private extended properties carry ASCENDA appointment/revision identifiers;
- timezone `America/Lima`.

Contacts:
- one Google person link per canonical patient/account;
- dedupe priority: existing local link/resourceName -> ASCENDA external ID -> exact normalized phone/email -> review on conflict;
- never dedupe by name alone;
- mutations serialized per Google account;
- naming rule for ZIVITAL is configurable, initial form: `{nombre} {apellido} - {tag} - {mes}{yy}`.

## Rollout gates

1. GC-0 security/contract and exact-current preflight.
2. GC-1 OAuth connect/change/disconnect and encrypted token storage.
3. GC-2 Calendar create with flags SAFE-OFF until canary.
4. GC-3 rebook/cancel same-event behavior.
5. GC-4 existing Resend template gains Calendar action/link.
6. GC-5 Contacts reconcile/upsert without duplicates.
7. GC-6 unified outbox/retry/reconciliation path.
8. GC-7 bounded human canary with owner/test account.
9. GC-8 future-appointment backfill after canary evidence.

## Safety

- No plaintext Google refresh token in browser, logs, GitHub, docs or generic integration tables.
- No synchronous Google HTTP call inside PostgreSQL triggers or the canonical booking transaction.
- No mass backfill before canary.
- Production feature flags remain false until the exact SHA is validated and the owner authorizes the live canary.
- CONV-001 is paused for HIGH/CRITICAL mutations during this lock transfer; its production AI autonomy remains SAFE-OFF.
