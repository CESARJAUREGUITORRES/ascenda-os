# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Status:** CURRENT / portfolio source of continuity  
**Captured:** 2026-08-17 20:03 America/Lima  
**GitHub baseline:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Railway status at capture:** SUCCESS  
**Supabase project:** `ituyqwstonmhnfshnaqz`  
**Supabase ledger at capture:** 783 migrations · latest `20260818003159`  

## Purpose

ASCENDA contains several programs in one repository. They share runtime, Supabase and CI infrastructure, but they are **not the same project**. This document prevents chats, agents, PRs and runners from mixing scopes.

The precedence is:

`main/runtime live → Supabase live → project CURRENT control → reproducible CI → aos_memory → Notion`.

Historical documents remain useful evidence but cannot override CURRENT.

## CURRENT production runtime

Railway executes:

`NODE_OPTIONS=--require ./sentinel-sentry-init.cjs node server-phase-s-f17.js`

Effective chain:

`Phase S F17 wrapper → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core runtime`

`app/server.js` remains a lower/core server and API surface; it is **not the Railway outer entrypoint**.

## Portfolio status

| Program | Canonical roadmap | Closed | Open / remaining | Portfolio status |
|---|---|---|---|---|
| Sentinel | F1–F13 | F1–F13 = 100% | none in baseline V1; Telegram F9-T deferred/non-blocking | **FROZEN / REGRESSION-ONLY** |
| Commercial Intelligence & Audience OS V3 | F0–F18 | F0–F16 = 100% | F17 = 4/6 live gates; F18 not started | **NEXT ACTIVE after control lock** |
| Revenue Data & Intelligence | F1–F7 | F1–F4 = 100% | F5 = recovery/provenance; F6/F7 pending | **QUEUED / NO CONCURRENT WRITES** |
| WhatsApp Revenue Hub | WA0–WA8 | WA0, WA2, WA3 = 100% | WA1 = 98%; WA4 = 70%; WA5–WA8 pending | **QUEUED / INTERNAL STATUS NEEDS RECONCILIATION** |
| KronIA V2 | K0–K8 | K0 = closed | K1 current hardening must be rebuilt from CURRENT; K2–K8 pending | **QUEUED / STALE BRANCHES MUST NOT MERGE** |
| Cross-program migration control | #238 / #250 | F16 + Sentinel F13 parity slices closed | remaining owner-specific parity; reproducible pre-history baseline | **MAINTENANCE LANE, NOT A FEATURE PROJECT** |

## Live checkpoints

### CIA F17

Production readiness at capture:

- `contracts_active=true`
- `whatsapp_bridge_validated=true`
- `outbound_policy_validated=true`
- `rollback_verified=true`
- `webhook_replay_validated=false`
- `canary_passed=false`
- `ready_for_f18=false`
- `illegal_send_states=0`
- browser direct table access: false for `anon` and `authenticated`

S15.2 / PR #265 has already activated F17 in the Railway production chain. Runtime activation does **not** equal F17 certification.

The older draft PR #261 was created before the S15.2 merge and must not be merged as-is. Any remaining F17 history work must restart from CURRENT and remain scoped to #238/F17.

### Revenue F5

Read-only live state at capture:

- source rows staged: `1000 / 15498`
- provisional clusters: `3950`
- members: `0`
- link previews: `0`
- canonical patients: `7675`
- canonical mutation by F5 remains forbidden before provenance + preview + human review

Old checkpoints claiming `15498/15498` are superseded by live evidence.

### WhatsApp Revenue Hub

Notion currently carries two unfinished phases (`WA1 98%` and `WA4 70%`). This violates the project-control rule that only one phase may be active at a time. Until the WhatsApp project is selected by the portfolio lock:

- preserve existing runtime and data;
- no new AI auto-reply activation;
- no new WA5–WA8 implementation;
- revalidate WA1 real signed Meta canary first when this program becomes active;
- then reconcile whether WA4 resumes or is rebaselined after CIA F17.

At capture, `aos_wa_messages_v1` contains 11 rows, while CIA F17 send/event/inbound ledgers are still zero. This is evidence that transport traffic and F17 governed evidence are distinct contracts.

### KronIA V2

- K0 audit is closed.
- K1 remains the first implementation phase.
- historical/stale K1 branches and PRs are evidence only, not merge candidates.
- CIA F15 Tool Registry + Agent Registry SHADOW + Policy Gate are reusable canonical inputs; KronIA must not build a second incompatible registry.
- fresh K1 work must begin from the then-current `main` after upstream runtime work is stable.

### Sentinel

Sentinel F1–F13 is 100_COMPLETE. It remains a transversal regression/sensor layer only. Do not reopen Sentinel merely because another program changes runtime unless a real Sentinel regression is demonstrated.

## Sequential closeout order

The portfolio uses **one HIGH/CRITICAL workstream at a time**.

1. `CONTROL_REALIGNMENT` — this document, lock policy, agents/memory/Notion cleanup.
2. `CIA_F17_F18_CLOSEOUT` — finish F17 6/6, then F18 and close CIA V3.
3. `REVENUE_F5_F7_CLOSEOUT` — F5 provenance/preview/human apply; F6 intelligence; F7 governed automation.
4. `WHATSAPP_WA1_WA8_CLOSEOUT` — reconcile WA1 first, then WA4 and WA5–WA8 without parallel phase states.
5. `BASELINE_REPRODUCIBILITY_250` — schema-only sanitized baseline and blank-DB rebuild once feature schemas are stable.
6. `KRONIA_K1_K8_CLOSEOUT` — fresh K1 from CURRENT, then K2–K8 sequentially.
7. `FINAL_ASCENDA_CROSS_PROGRAM_CERTIFICATION` — exact main SHA, migration parity, runtime chain, regression suites and Notion/aos_memory reconciliation.

#238 remains owner-scoped and may be resolved only as required by the selected active program. It must not become a parallel migration rewrite project.

## Definition of portfolio lock

A workstream is ACTIVE only when `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md` names it.

While another HIGH/CRITICAL workstream is ACTIVE:

- other projects are read-only / documentation-only;
- no DB migration/materializer/canary/deploy is launched for them;
- no competing Zero-Cost DB job is intentionally started;
- FAST runners may run only regression checks that do not mutate shared state;
- queued/pending jobs from another workstream are treated as contamination and are not used as certification evidence;
- a project resumes by creating/revalidating a fresh branch from CURRENT, not by assuming an old branch is still valid.

## Required handoff for every project

Before releasing the portfolio lock:

1. exact `main` SHA and production runtime recorded;
2. phase status reconciled with Supabase live;
3. open PRs classified: merge / superseded / paused;
4. CI and rollback evidence recorded;
5. `aos_memory` current key updated;
6. project phase row and Control Maestro in Notion updated;
7. next project receives an explicit input contract.
