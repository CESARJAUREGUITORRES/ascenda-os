# MKT-INTEGRITY-HOTFIX-V3 — Loop 6 V2.3 Impact Addendum

Date: 2026-08-21 America/Lima
Base main: `5e364a626256a2146cf42b8270999cacafadd49f`
Active lane: `MKT-INTEGRITY-HOTFIX-V3`
Loop 7: NOT STARTED

## Objective
Close the remaining production usability gap in Loop 6 by separating queue-confirmation from manual scheduling semantics.

### Queue / Call Center happy path
A lead already delivered by Call Center and tipified as `CITA CONFIRMADA` must not ask the advisor to choose commercial semantics. The server already has lead, advisor, phone, source, treatment and identity context and must decide automatically. Only exceptions may interrupt with a modal.

### Agenda Manual
Retain the three explicit choices because the server cannot infer why the advisor manually entered the number:
- commercial call;
- follow-up/callback/inbound;
- agenda only.
Server policy remains authoritative and may BLOCK/DOWNGRADE.

## Confirmed incidents in scope
### Ruben — regression canary only
`997883711`, lead 5884, repair Call 38384 + linked Agenda `2c581c52-89e9-465f-89be-0e3818eda309`, repair journal COMPLETE. Must remain unchanged.

### Carlos Alonso Aguilar Uceda — deterministic repair required
`941764266`, lead 5894 CAPILAR, advisor MIREYA. Existing Call 38396 = SIN CONTACTO / `SE ENVIA AUDIO`. No Agenda, no journal, no CITA CONFIRMADA. Evidence shows no prior conversion. Repair must preserve Call 38396 and add exactly one governed commercial conversion + linked Agenda for 2026-08-22 14:30 San Isidro. Repair must be idempotent and excluded from the future 5-genuine-operation gate.

### Wilmer legacy rows — review only
- `928017492`: >=15d reactivation eligibility, but no contemporaneous registered commercial call proven yet.
- `995558890`: >=15d reactivation eligibility, but no contemporaneous registered commercial call proven yet.
- `980749071`: <15d, not eligible for commercial reactivation.
No blind retroactive KPI credit.

## Proposed V2.3 architecture
1. Add a dedicated governed queue-confirmation contract (`aos_callcenter_confirm_queue_appointment_v1` or equivalent) that does not accept a browser-selected commercial action type.
2. Reuse the existing V2.2 prepare/policy/core path internally.
3. Validate that the supplied lead belongs to the phone and is a valid prior/current lead before committing.
4. For a normal unconverted lead, derive the action automatically:
   - FOLLOWUP source / followup_id -> `CALLBACK_INBOUND_APPOINTMENT` routed as `FOLLOWUP_CONVERSION` by the existing core;
   - otherwise queue lead -> `COMMERCIAL_CALL_APPOINTMENT`.
5. Converted patient / active appointment / NO ASISTIO / identity conflict remain server-authoritative exception paths.
6. Preserve V2.2 idempotency precheck and legacy fail-closed triggers.
7. Frontend build marker -> `v2.3`; one loader only; remove `cc6-contact-mode` from `#cc-m-cita`; keep one `cc6-manual-mode` in `#cc-m-cita-manual`.
8. After a successful normal queue commit, show a green confirmation modal only after Call + Agenda + direct links + journal exist, then let the advisor explicitly continue to the next lead.

## Blast radius
Expected functional changes only in:
- governed Call Center RPC/migration;
- `app/public/calls-loop6.js` and loader cache key;
- CI assertions / control documentation;
- deterministic Carlos repair and rollback.

No change to REV-F5/F6 source truth, Marketing acquisition rules, sales tables or unrelated workstreams.

## Protected invariants
- REV-F5 = 6 / 15,498 / 8,716 / 15,498 / 8,716 / 230.
- F6 Identity/Lifecycle service-role-only.
- Protected calls 36701/37185/37813/38012/38168/38186 unchanged.
- Removed Alan/Alberto duplicate Agenda rows remain absent.
- Ruben repair remains exact.
- Acquisition V2/V3 baseline 56/57 with V2-only 0.

## Rollback requirements
Before any LIVE functional mutation version:
- queue RPC rollback;
- frontend revert path;
- Carlos exact repair rollback.
All synthetic canaries must run inside rollback and leave zero residue.

## STOP
Stop on incompatible main advance, active competing HIGH/CRITICAL lane, Carlos unexpected new commercial Call/Agenda, Ruben regression, F5/F6 drift, unexplained Acquisition delta, legacy bypass persistence, CI failure or Railway non-success.
