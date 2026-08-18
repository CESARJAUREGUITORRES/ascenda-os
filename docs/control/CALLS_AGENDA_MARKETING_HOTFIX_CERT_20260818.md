# ASCENDA OS — Calls / Agenda / Marketing Hotfix — Production Certification

**Certification date:** 2026-08-18 America/Lima  
**Hotfix lock:** `HOTFIX-CALLS-AGENDA-MARKETING-20260818`  
**Supabase project:** `ituyqwstonmhnfshnaqz`  
**Git source baseline:** `main@957bf7b4fbd7da9b2049346b74ac5e73ea260053`

## Result

**PRODUCTION CERTIFIED for the scoped hotfix.**

### Mireya operational result

- Call Center today: **4** confirmed conversions / **4** unique numbers.
- Paid Marketing: **3**.
- Organic: **1**.
- All three paid cases resolve through `DIRECT_LEAD_ID` with confidence **100**.
- The validated Organic appointment is tagged `ORGANICO`, remains clinically `CRIOLIPOLISIS`, and is linked to its real call without a paid lead ID.

### Marketing activity list

For the 2026-08-18 activity window:

- activity rows: **49**;
- rows with appointment: **4**;
- Organic acquisition rows: **1**;
- the previously omitted prior-day paid lead converted today is included as current-period activity;
- true Organic acquisition is visible as `ORGANICO` with treatment detail;
- paid cohort analytics remain separate from the operational activity list.

### Duplicate / manual-agenda controls

- **8** proven technical/fabricated `CITA CONFIRMADA` rows were backed up in `aos_log_auditoria` before deletion.
- Two known rows from the validated recreation incident are absent after cleanup.
- Server-side transaction tests proved:
  - `CITA_MANUAL` → **0** Call Center calls when Agenda arrives first;
  - artificial call → `CITA_MANUAL` → **0** Call Center calls when the call arrives first;
  - genuine `CALL_CENTER` call+appointment → **1** call preserved;
  - duplicate identical Agenda insert within the guard window → **1** appointment retained.
- Five hotfix triggers are installed: conversion guard, Agenda dedupe, late-lead reconciliation, and the two-sided legacy manual-agenda cleanup.

### Historical late-load reconciliation

- Deterministic same-day late-loaded Marketing conversions were linked explicitly where the evidence was a unique late lead plus co-temporal appointment.
- Ambiguous history was not force-attributed.
- Total calls carrying an explicit `lead_id_origen` after the scoped backfill: **26**.

### Revenue / REV-F5 isolation

Post-hotfix live state remains exactly:

- F5 source rows: **7,064**;
- F5 provisional clusters: **3,950**;
- F5 cluster members: **0**;
- F5 link preview: **0**;
- F5 canonical apply events: **0**;
- patients: **7,679**.

Therefore the hotfix did not mutate the paused REV-F5-owned state or patient population.

## Applied migrations

- `calls_agenda_marketing_hotfix_20260818`
- `calls_agenda_marketing_direct_trace_links_20260818`

Both are present in the production migration ledger.

## Handoff

After merging the Git branch, the global mutable lock must return immediately to `REV-F5-CLOSEOUT`, per the owner directive. REV-F5 resumes from the recoverable checkpoint in `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_CALLS_AGENDA_MKT.md`, reconciling persisted state before the next write.
