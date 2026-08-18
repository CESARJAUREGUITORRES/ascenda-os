# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / temporary owner-authorized hotfix  
**Owner assignment:** 2026-08-18 Lima — execute and certify Calls–Agenda–Marketing correction, then immediately resume REV-F5  
**Baseline before handoff:** `main@1e9709ecd778ec7fa926cda81d82a19f07705884`  
**Previous lock:** `REV-F5-CLOSEOUT` — PAUSED / RECOVERABLE at `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_CALLS_AGENDA_MKT.md`  
**ACTIVE LOCK:** `HOTFIX-CALLS-AGENDA-MARKETING-20260818`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` immediately after hotfix production certification.

## Owner authorization

The owner explicitly directed: pause REV-F5 at a recoverable checkpoint, transfer the global mutable lock to this Calls–Agenda–Marketing hotfix, execute the correction, and reactivate REV-F5 immediately afterwards so the Revenue closeout is not interrupted beyond the hotfix window.

## Global rule

At most **one HIGH/CRITICAL feature/data workstream may mutate ASCENDA at a time**.

Canonical namespaces remain `CIA-F*`, `REV-F*`, `WA-*`, `SEN-F*`, `K*`, `PARITY-*`, `BASELINE-*`, `CONTROL-*`.

While `HOTFIX-CALLS-AGENDA-MARKETING-20260818` owns the lock:

- REV-F5 is paused at the explicit checkpoint and must not ingest/rebuild/apply concurrently;
- CIA, WhatsApp, Sentinel, KronIA and other HIGH/CRITICAL workstreams remain read-only/regression-only;
- shared runners are execution capacity, never source of truth;
- any unrelated `main` advance must be inspected before the next write/merge gate.

## Hotfix business invariants

1. **Agenda-only activity is not a Call Center call.** Creating/recreating/continuing an appointment from Agenda must never fabricate a row in `aos_llamadas` and must not inflate Call Center calls, conversions or productivity.
2. **Real Call Center conversions remain real.** A genuine phone call that creates an appointment may create one `CITA CONFIRMADA` call event and one agenda row.
3. **Organic acquisition is explicit.** A real Call Center conversion with no Marketing lead is classified `ORGANICO`, retains the actual treatment as its detail, is visible in the Marketing acquisition list, and is excluded from paid-campaign CPL/CAC/ROAS cohorts.
4. **No double-submit duplicates.** Appointment save actions must be idempotent/guarded against repeated clicks/retries.
5. **Late-loaded Marketing leads preserve attribution when evidence is strong.** Explicit traceability may be backfilled only where phone/time/appointment evidence is high-confidence; ambiguous historical cases remain unresolved.
6. **Paid cohort analytics remain cohort analytics.** Do not redefine CPL/ROAS cohorts as daily operational activity. Daily Marketing conversions are a distinct operational metric.
7. **REV-F5 isolation.** This hotfix must not intentionally mutate `aos_f5_*` state or historical Revenue source files.

## Hotfix scope

Allowed mutations are limited to:

- `app/public/calls.js` and strictly necessary Call Center UI behavior;
- `app/public/agenda.js` only if needed for explicit organic/source labeling while preserving agenda-only semantics;
- `app/public/admin-marketing.html` / `admin-marketing-v2.js` only for acquisition-list and operational-conversion presentation;
- Marketing/Call Center RPCs required for correct read semantics;
- traceability/backfill fields on `aos_llamadas` / `aos_agenda_citas` for validated cases;
- surgical cleanup of proven duplicate/fabricated Call Center rows;
- migration/control documentation for the hotfix.

## Mandatory hotfix gates

1. exact-current `main` revalidation;
2. before-state snapshot for Mireya and Marketing KPIs;
3. code patch with syntax/static validation;
4. production DB migration/backfill with rollback-safe/idempotent SQL;
5. verify Mireya: 3 Marketing conversions + 1 Organic conversion, with no duplicated Call Center event for `957535568`;
6. verify Agenda-only create path does not create `aos_llamadas`;
7. verify Organic appears in Marketing acquisition list without entering paid CPL/CAC/ROAS cohorts;
8. verify late-loaded high-confidence Marketing conversions are explicitly linked and ambiguous cases remain unresolved;
9. regression-check Call Center, Agenda and Marketing RPCs;
10. verify REV-F5 checkpoint invariants;
11. merge/deploy/read-back;
12. restore `ACTIVE LOCK: REV-F5-CLOSEOUT` with the post-hotfix `main` SHA and resume from the 7,064-row-or-newer reconciled persisted state.

## REV-F5 recovery pointer

Canonical temporary pause checkpoint: `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_CALLS_AGENDA_MKT.md`.

At pause capture, production had 6 manifests / 15,498 expected source rows, 7,064 persisted F5 source rows, 3,950 provisional clusters, 0 cluster members, 0 link preview, 0 canonical apply events and 7,679 patients. These numbers are a recovery checkpoint, not a completion claim.

## Handoff rule

This lock returns to `REV-F5-CLOSEOUT` only after the hotfix is validated from exact GitHub + live Supabase evidence and F5-owned state is confirmed intact. The owner has already authorized that return; no additional authorization is required unless hotfix validation detects unexpected F5 mutation or a new competing HIGH/CRITICAL write.
