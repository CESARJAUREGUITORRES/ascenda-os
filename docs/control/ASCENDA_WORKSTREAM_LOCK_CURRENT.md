# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-16 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `BOOKING-V3.2 — PUBLIC BOOKING ALIGNMENT + E2E CANARY`  
**OWNER AUTHORIZATION:** `PROCEDE · implementar todo de manera ordenada hasta dejar el siguiente canary listo`  
**PAUSED HIGH/CRITICAL LANE:** `CONV-L4 #508 — checkpoint preserved; no competing mutations until BOOKING-V3.2 releases lock`  
**Legacy WA-L10 #456:** `FROZEN · SAFE-OFF EVIDENCE ONLY · NO NEW FEATURE PATCHING`  
**P0 #485:** `CLOSED / COMPLETED — PROD RECURRENCE+LOAD PASS`  
**Production safety:** Conversations autonomy remains `SAFE-OFF`; this handoff does not authorize autonomous messaging.

## Purpose of this handoff

The owner explicitly authorized an orderly temporary handoff so the already-deployed BOOKING-V3 public experience can be aligned with the clinic's canonical agenda/treatment authorities and certified end-to-end without running competing HIGH/CRITICAL database/runtime work.

CONV-L4 is **PAUSED, not superseded**. Its GitHub issue, evidence and architecture remain authoritative for Conversations. After BOOKING-V3.2 closes or reaches a hard external blocker, the mutable lane returns to CONV-L4 and continues L4 → L5 → L6 → L7 from CURRENT evidence.

## BOOKING-V3.2 scope lock

Allowed mutations are limited to:

1. public booking link UX and advisor permanent-link presentation;
2. public professional visibility derived from real future availability;
3. public treatment selection aligned to the canonical treatment taxonomy already used by Agenda/Call Center;
4. additive BOOKING-V3.1 attribution schema/functions already merged in GitHub but not yet present in production, after exact live preflight;
5. compatibility wiring needed to keep `aos_agendar_publica_v2` / canonical `aos_agenda_citas` as the booking write authority;
6. targeted booking notification / email / Google Calendar / advisor attribution verification;
7. dedicated tests, rollback evidence, exact-SHA deployment and one human canary handoff.

Explicitly out of scope:

- redesigning the approved BOOKING-V3 visual composition;
- creating a second agenda, treatment, patient, notification or Calendar authority;
- changing Conversations autonomy or legacy WA safe-off state;
- unrelated Revenue/CIA/Sentinel migrations;
- destructive cleanup of appointments, patients, links or clinical/financial data.

## Canonical booking invariants

- Public booking is an adapter over existing clinic authorities, not a parallel scheduling product.
- `aos_agenda_citas` remains canonical appointment persistence.
- Availability must be validated by the current agenda/turn authority before a slot is offered and again by the booking write authority.
- Public choices use treatment categories understood by clinic operations; product/SKU names are not the patient-facing scheduling taxonomy.
- Professionals with no future bookable availability in the configured booking horizon are not offered as selectable choices.
- Advisor/campaign/source attribution is additive metadata and must never change appointment ownership or clinical truth.
- Existing email, notification and Google Calendar flows are reused; no duplicate sender/integration is introduced.
- No real patient fixture is created by automated CI. Human canary occurs only after technical gates pass.

## Required evidence before production certification

1. Exact `main` and branch diff reviewed.
2. Read-only Supabase preflight of affected functions/tables/triggers/grants and migration drift.
3. Dedicated frontend/contract regression tests PASS.
4. Migration compatibility/rollback evidence for any DB change.
5. Production migration execution receipt + direct live readback + independent invariant query.
6. Railway exact-SHA deployment SUCCESS and no new booking/auth/runtime timeout regression.
7. Synthetic/non-PII booking authority checks where safe.
8. Human canary: advisor permanent link → public booking → canonical agenda → source/advisor attribution → admin/advisor notification → patient email → Google Calendar behavior.

## Release / return rule

When BOOKING-V3.2 reaches `TECHNICAL PASS / READY HUMAN CANARY`, do not silently reactivate another HIGH/CRITICAL lane during the human test. After the canary is recorded PASS (or BOOKING is explicitly paused due to an external blocker), update this file and return the lock to `CONV-L4 #508` before resuming Conversations implementation.

## Current immediate gate

`BOOKING-V3.2` owns the sole mutable lane. Perform live preflight first, then implement the smallest compatible patch, certify technical gates, deploy exact SHA, and stop only at the human-canary boundary or a real external blocker.
