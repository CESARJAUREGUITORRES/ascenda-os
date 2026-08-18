# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / TEMPORARY HOTFIX-2  
**Owner assignment:** 2026-08-18 Lima — correct Wilmer scheduling semantics + late Marketing attribution  
**Previous lock:** `REV-F5-CLOSEOUT` — RECOVERABLE PAUSE  
**ACTIVE LOCK:** `HOTFIX-WILMER-AGENDA-MARKETING-2-20260818`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` immediately after production certification.

## Owner authorization

The owner explicitly requested correction of Wilmer's 2026-08-18 calls/citas so Agenda remains intact while non-commercial scheduling stops inflating Calls/Home, and requested strengthening `Agenda manual first → Marketing lead later → no call` attribution. This authorizes the temporary recoverable pause required by the one-mutable-workstream rule.

## REV-F5 frozen checkpoint

Canonical checkpoint: `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_WILMER_AGENDA_HOTFIX2.md`.

Production Supabase immediately before handoff:

- source manifests: **6**;
- expected rows: **15,498**;
- source rows persisted: **7,064**;
- identity clusters: **3,950**;
- members: **0**;
- preview: **0**;
- apply events: **0**;
- patients: **7,679**;
- temporary F5 transport rows: **0**.

## Hotfix isolation

This hotfix may mutate only Calls / Agenda / Marketing classification, attribution, KPI semantics, and audit evidence. It must not mutate F5 source rows, clusters/members, preview/apply tables, patient canonical data, or historical source files.

## Required hotfix gates

1. Verify all Wilmer 2026-08-18 `CITA CONFIRMADA` rows against Agenda and patient/lead history.
2. Preserve valid Agenda rows.
3. Mark/exclude non-commercial scheduling/reagenda events from Calls/Home commercial KPIs without destroying auditability.
4. Protect future patient-continuation/reagenda scheduling from commercial KPI inflation.
5. Reconcile manual Agenda created before a same-day Marketing lead, with no registered call, by attaching direct lead attribution to Agenda only; never fabricate a call.
6. Validate Marketing, Calls, Home and Agenda read-backs.
7. Verify REV-F5 counts unchanged.
8. Restore `ACTIVE LOCK: REV-F5-CLOSEOUT` immediately.

## Global rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. CIA, WA, SEN, K1, PARITY and REV-F5 remain read-only while this hotfix owns the lock.
