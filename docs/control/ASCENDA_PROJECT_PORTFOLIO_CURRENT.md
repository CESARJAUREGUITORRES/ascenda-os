# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Status:** CURRENT / portfolio source of continuity  
**Captured/refreshed:** 2026-08-17 20:03 America/Lima + S15.3 sync  
**GitHub baseline:** `main@ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**Release:** S15.3 — F17 buffered HTTP framing fix  
**Railway:** SUCCESS  
**Supabase:** `ituyqwstonmhnfshnaqz` · 783 migrations · latest `20260818003159`

## Purpose

ASCENDA has several programs in one repository. Sharing GitHub, Railway, Supabase and runners does **not** make them one project. This file is the portfolio-level map future chats/agents use before opening a project checkpoint.

Precedence:

`main/runtime live → Supabase live → project CURRENT control → reproducible CI → aos_memory → Notion`.

## Runtime CURRENT

Railway outer command:

`env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js`

Effective chain:

`Phase S F17 wrapper → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core runtime`

S15.3 preserves this chain and fixes buffered HTTP framing for signed WhatsApp/webhook traffic through F17.

`app/server.js` remains a lower/core API surface; it is not the Railway outer entrypoint.

## Portfolio map

| Program | Roadmap | Closed | Remaining | Status after realignment |
|---|---|---|---|---|
| Sentinel | SEN-F1..F13 | F1–F13 = 100_COMPLETE | only deferred non-blocking F9-T Telegram + queued maintenance findings | **FROZEN / REGRESSION-ONLY** |
| Commercial Intelligence & Audience OS V3 | CIA-F0..F18 | F0–F16 = 100_COMPLETE | CIA-F17 = 4/6 live; CIA-F18 pending | **NEXT ACTIVE** |
| Revenue Data & Intelligence | REV-F1..F7 | F1–F4 = 100% | REV-F5 recovery; F6/F7 pending | **PAUSED_BY_PORTFOLIO_LOCK** |
| WhatsApp Revenue Hub | WA-0..WA-8 | WA0, WA2, WA3 = 100% | WA1=98%; WA4=70%; WA5–WA8 pending | **PAUSED; INTERNAL PHASE STATE MUST BE SERIALIZED** |
| KronIA V2 | K0..K8 | K0 closed | K1–K8 remaining | **PAUSED; K1 MUST REBUILD FROM CURRENT** |
| Migration governance | PARITY #238 / BASELINE #250 | safe owner slices already closed | owner-specific parity + reproducible pre-history baseline | **MAINTENANCE, NOT FEATURE WORKSTREAM** |

## Live state after S15.3

### CIA-F17

- F16 input: `READY_F17_EMAIL_CERTIFIED`, `ready_for_f17=true`.
- F17 status: `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`.
- `ready_for_f18=false`.
- true: contracts, WhatsApp bridge, outbound policy, rollback.
- false: `webhook_replay_validated`, `canary_passed`.
- illegal send states: 0.
- browser direct governed-table access: false.
- governed WhatsApp send requests: 0.
- governed send events: 0.
- governed inbound facts: **1**.
- WA message facts: **12**.

S15.2 inserted F17 into production runtime; S15.3 fixed buffered request framing. The new inbound fact is useful evidence that traffic can now reach the governed boundary, but it does **not** prove signed replay/idempotency or canary. Do not set readiness flags by inference.

PR #261 predates #265/S15.3; it is not a merge candidate as-is. Remaining F17 work must restart/reconcile from CURRENT and retain only unresolved history/replay/canary/readiness scope.

### REV-F5

Live:

- `1000 / 15498` source rows staged;
- `3950` provisional clusters;
- `0` members;
- `0` link previews;
- `7675` canonical patients;
- canonical mutation remains forbidden before provenance + preview + human review.

Old `15498/15498` checkpoints are superseded by live evidence.

### WhatsApp Revenue Hub

The tracker previously had WA1 and WA4 simultaneously `En curso`. This is a scheduling defect.

Preserve delivered work while paused:

- no AI auto-reply activation;
- no new WA5+ implementation;
- no Meta canary outside the selected project lock;
- when WhatsApp resumes, revalidate/close WA1 first, then rebaseline WA4 against CURRENT before continuing.

### KronIA

- K0 closed.
- K1 remains first implementation phase.
- PR #94 and PR #175 have been closed as superseded/evidence-only.
- CIA-F15 Tool Registry + Agent Registry SHADOW + Policy Gate are canonical reusable inputs; do not create a second incompatible registry.
- fresh K1 begins from then-CURRENT after upstream portfolio work is stable.

### Sentinel

SEN-F1..F13 is 100_COMPLETE. Other projects may run Sentinel regression checks, but this does not reopen Sentinel unless a real Sentinel contract regresses. PR #271 is paused maintenance evidence under the portfolio lock.

## Sequential closeout queue

1. `CONTROL-REALIGNMENT` — active until this control PR is current/merged.
2. `CIA-F17/F18-CLOSEOUT` — first feature lock after control.
3. `REV-F5/F7-CLOSEOUT`.
4. `WA-1/WA-8-CLOSEOUT`.
5. `BASELINE-#250` once feature schemas are stable.
6. `K1/K8-CLOSEOUT`.
7. `FINAL-CROSS-PROGRAM-CERTIFICATION`.

#238 is resolved owner-by-owner only when required by the selected project. It must not become a parallel schema-history rewrite workstream.

## Project handoff gate

Before releasing a project lock:

1. exact `main` SHA/runtime captured;
2. live Supabase phase state reconciled;
3. PRs classified `MERGE_CANDIDATE / PAUSED / SUPERSEDED / EVIDENCE_ONLY`;
4. CI/canary/rollback state recorded;
5. current GitHub docs updated;
6. `aos_memory` updated;
7. Notion updated last;
8. next project receives an explicit input contract.
