# WEB BOOKING CONNECT V1 — CURRENT

Captured: 2026-09-16 America/Lima
Owner authorization: RUN UNTIL FIRST HUMAN CANARY
Repository: `CESARJAUREGUITORRES/ascenda-os`
Branch: `web-booking-connect-v1`

## Purpose

Expose the already-certified ASCENDA booking authority to the native Zi Vital WordPress booking UI without moving, replacing or modifying the existing public Agenda V3/B3 experience or advisor-link workflow.

The website is a new presentation surface only. ASCENDA remains the operational authority.

## Frozen no-regression baseline

The following existing surfaces are protected and must remain behaviorally unchanged:

- `app/public/agendar-v3.html`;
- current `agendar-v2.html` compatibility surface;
- `agendar.html` redirects / current public entry behavior unless a later explicit cutover is approved;
- advisor personal-link generation and `ADVISOR_LINK` attribution;
- `aos_agenda_citas` as the only appointment ledger;
- `aos_booking_public_catalog_v2` as public booking catalog authority;
- `aos_booking_availability_v2` as live slot authority;
- `aos_agendar_publica_v2` as governed public booking write;
- patient lookup authority already used by V3;
- Zi Vital confirmation email;
- push / in-app notifications;
- Google Calendar / Contacts;
- Coordination > Comercial automatic appointment report;
- WEB / ORGÁNICO and ADVISOR_LINK attribution semantics.

No existing booking URL, personal link or Agenda UI is migrated as part of this workstream.

## Architecture

```text
Agenda Ascenda current / advisor links
                 └──────────────┐
                                v
Zi Vital WordPress UI -> Ascenda Connect -> certified booking core
                                |
                                v
                        aos_agenda_citas
                                |
                    downstream side effects
```

WordPress must never call Supabase tables directly.

## Risk classification

- Connector read endpoints: MEDIUM/HIGH because they expose booking state.
- Patient lookup and booking write endpoints: HIGH.
- Runtime preload wiring: HIGH; must remain additive and pass-through for all non-connector routes.
- No DDL, RLS, GRANT/REVOKE, secrets, destructive migration or alternate booking ledger is allowed in this phase.

## Impact map

`Zi Vital theme -> WordPress same-origin proxy -> /api/ascenda-connect/booking/v1/* -> existing booking RPC/table authority -> canonical appointment write -> existing downstream side effects`

The connector may normalize and minimize payloads, but it must not invent clinical eligibility, capacity, schedules or booking truth.

## Loop index

0. Freeze + no-regression map.
1. Ascenda Connect contract.
2. Read-only connector: bootstrap/catalog/taxonomy/route/provider/date/availability reads.
3. Zi Vital context router: generic/domain/approach/treatment entry.
4. Native Zi Vital booking UI shell.
5. Doctor / nursing route + live availability.
6. Governed patient identity lookup.
7. Governed appointment write + existing confirmation path.
8. WEB contextual attribution.
9. Wire Home/domain/approach/treatment CTAs.
10. Automated checks then stop at first human canary.
11. Public cutover only after owner PASS; rollback remains current Ascenda booking surface.

## Connector contract V1

Base path:

`/api/ascenda-connect/booking/v1`

Allowed operations:

- `GET /health` — connector health and version only.
- `GET /bootstrap` — safe public hierarchy + currently bookable canonical treatment references + public providers; no patient data.
- `POST /availability` — validate canonical treatment/date/provider and proxy the existing availability authority.
- `POST /patient-lookup` — exact governed lookup with minimum safe public result.
- `POST /book` — proxy the governed public booking authority using the existing token/attribution contract; slot is revalidated by ASCENDA.
- `POST /confirmation` — reuse the current Zi Vital public booking confirmation delivery path for a created appointment.

The connector returns only fields required by the public web UI.

## Context contract

Canonical web hierarchy:

`domain -> approach -> treatment -> clinical route -> availability -> patient -> confirmation`

Known context skips prior UI steps:

- generic CTA: start at domain;
- domain page: start at approach;
- approach page: start at treatment;
- treatment landing: validate canonical treatment and continue to route/availability.

Human-readable slugs are presentation only. Booking operations use canonical treatment IDs returned by ASCENDA.

## Clinical route rule

The web never asks the patient to arbitrarily choose Doctor vs Nursing.

- doctor/exact-provider path: only eligible public providers returned by ASCENDA;
- nursing/site-pool path: no individual nurse selection;
- WordPress never calculates provider eligibility or pool capacity.

## Security boundary

- no service-role key, Supabase key, password or privileged token may be returned to WordPress/browser;
- connector reads secrets only from Railway environment;
- strict operation allowlist;
- body size limits;
- request method enforcement;
- basic abuse/rate protection;
- no broad patient search; lookup remains exact/minimized;
- booking write preserves existing RPC validation and attribution;
- every non-connector request must pass through untouched.

## Rollback

If connector deployment causes any regression:

1. remove the connector route hook / revert connector commit;
2. current Agenda V3/B3 and advisor links remain the public fallback;
3. WordPress CTA can point back to the certified Ascenda booking URL;
4. no database rollback is required because V1 introduces no schema changes.

## Automated gate before human canary

Required before asking the owner to review:

- JS syntax checks for connector/runtime hook;
- contract tests proving existing booking route remains present;
- pass-through test for unrelated URLs;
- connector rejects unsupported method/path;
- bootstrap returns only allowlisted public fields;
- availability proxies canonical RPC;
- patient lookup remains exact/minimized;
- booking write uses `aos_agendar_publica_v2` and WEB/ADVISOR_LINK token semantics;
- theme connector never contains Supabase/service credentials;
- WordPress can render the booking shell from general, domain, approach and treatment context;
- no human booking is created automatically by CI.

## Human canary stop

Automation stops immediately before the first real user booking. Owner reviews the native Zi Vital booking surface and performs the first controlled booking manually.
