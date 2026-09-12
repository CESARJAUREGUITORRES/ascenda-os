# ASCENDA OS — Google Integration V1 Impact Report

**Date:** 2026-09-12  
**Program:** INT-GOOGLE-001  
**Risk:** CRITICAL  
**Owner authorization:** proceed with full implementation until human canary  
**Production flags at implementation start:** all Google sync flags SAFE-OFF

## Scope

Finish the existing Google Calendar + Contacts integration card using server-side OAuth. ASCENDA remains authoritative; Google is a replaceable projection.

## Product surfaces

- Configuración > Integraciones > Google Calendar + Contacts.
- Agenda, Mis Citas, Call Center and Attendance appointment email calls.
- Existing Resend confirmation/reprogram templates receive a signed Calendar action.
- No replacement of Resend, Agenda, Patients or booking authority.

## Data changes

Additive migration only:
- aos_google_connections_v1;
- aos_google_oauth_states_v1;
- aos_google_calendar_links_v1;
- aos_google_contact_links_v1;
- aos_google_sync_outbox_v1;
- service-role-only claim RPC;
- authenticated server enqueue for legacy/human appointment writers;
- governed internal enqueue hooks on `aos_booking_operations_v2` and `aos_wa4_booking_actions_v1`.

There are deliberately **no Google triggers on `aos_agenda_citas` or `aos_pacientes`**. Legacy/human product surfaces enqueue only after their canonical write succeeds and only through the authenticated ASCENDA backend. Booking Core and governed WhatsApp flows may enqueue from their browser-write-closed ledgers. None of these hooks perform network I/O; they only create idempotent outbox work when the connected account has the corresponding sync feature enabled.

## Security boundaries

- Google OAuth client secret remains Railway-only.
- Refresh tokens are AES-256-GCM encrypted before database persistence.
- Google tables use forced RLS and revoke anon/authenticated access.
- Admin routes and legacy/human appointment enqueue routes require a verified current ASCENDA application session.
- OAuth state is random, stored hashed, expires, and is single-use.
- Google account passwords are never collected by ASCENDA.
- Browser cannot read/write OAuth token material.

## Availability / failure semantics

Booking does not wait on Google. Google failures remain in the sync outbox and never roll back a confirmed ASCENDA appointment. The Google worker owns no additional polling interval; immediate work is kicked after authenticated enqueue and retries reuse the existing guarded `server.js` scheduler.

Legacy rebook writers that create a new appointment row are bridged safely: the old REAGENDADA event is superseded/deleted and the new row becomes the new event. Governed rebook paths that keep the same appointment ID patch the same Google event.

## Rollout

1. merge exact gated SHA;
2. production read-only preflight;
3. apply exact migration;
4. deploy runtime with all sync flags false;
5. set only GOOGLE_INTEGRATION_ENABLED=true;
6. owner connects the test Google account;
7. select calendar;
8. Calendar and Contacts canaries;
9. only after proof, enable specific sync flag(s) and per-connection toggles;
10. one real appointment canary;
11. dry-run future-appointment backfill;
12. explicit live batch activation.

## Rollback

Immediate fail-safe: set GOOGLE_INTEGRATION_ENABLED=false, GOOGLE_CALENDAR_SYNC_ENABLED=false and GOOGLE_CONTACT_SYNC_ENABLED=false. This stops OAuth start and worker processing without touching canonical data.

Code rollback: revert the Google V1 merge and redeploy the preceding exact SHA.

Database emergency rollback exists at supabase/rollback/20260912220000_google_integration_v1_rollback.sql.

That rollback removes Google-only tables and link/token metadata and is therefore destructive to integration metadata; production use requires an export/backup and explicit owner approval. Canonical appointments/patients remain untouched.
