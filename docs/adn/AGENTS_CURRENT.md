# ASCENDA OS — AGENTS CURRENT OVERLAY

**Captured:** 2026-08-17 20:03 America/Lima  
**Applies to:** every CURRENT ASCENDA agent/chat.

This overlay supersedes operational assumptions in historical `docs/adn/AGENTS.md` while preserving that file as provenance/domain knowledge.

## Mandatory bootstrap

Before any write:

1. root `AGENTS.md` + `SECURITY.md`;
2. `ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
3. `ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
4. exact `main` and runtime chain;
5. live Supabase for the selected project;
6. one selected project's Control Maestro/active checkpoint;
7. old PR/branch classification.

If workstream ownership is ambiguous, stop writes and reconcile read-only.

## A-01 Portfolio Controller

Declares `WORKSTREAM_ID`, enforces one global HIGH/CRITICAL mutable workstream, and owns handoff. It prevents project/phase-name collisions such as bare `F17`.

## A-02 Runtime Architect

Reads `app/railway.json`, `app/package.json` and actual wrappers before modifying runtime.

Captured CURRENT chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`.

Never assumes `server.js` is the outer entrypoint from historical docs.

## A-03 Supabase/Data Architect

Owns migration/RPC/RLS/ACL impact. Keeps #238 parity separate from #250 pre-history baseline. Never rewrites history or replays production DDL merely to satisfy CI. Preserves F5 provenance/human review.

## A-04 Security Guardian

Uses root `SECURITY.md`. HIGH/CRITICAL requires exact-current security/negative-auth/rollback evidence; secrets stay environment/vault only.

## A-05 CI/Runner Governor

- Zero-Cost DB runner belongs to the ACTIVE workstream during DB gates.
- No unrelated materializers compete for shared workspace/ports.
- `queued/pending` is capacity wait, not product failure.
- FAST may run isolated same-workstream syntax/UI/regressions, never replace DB/security gates.
- Certification names workstream + phase + exact SHA.

## A-06 Project Historian / Memory Manager

At each pause/closure:

1. update GitHub CURRENT docs;
2. update `aos_memory` current keys;
3. update project phase/Control Maestro in Notion;
4. mark superseded evidence explicitly;
5. record the next input contract.

Never treats `aos_codigo_fuente` as CURRENT production authority.

## A-07 Release Certifier

Distinguishes `ZERO-COST CERTIFIED`, `CANARY CERTIFIED`, `PRODUCTION CERTIFIED`, and `100_COMPLETE`. A sibling project's PASS is only input evidence.

## Current state

- Sentinel: closed/regression-only.
- CIA: F17/F18 remaining; first feature workstream after realignment.
- Revenue: F5–F7 paused.
- WhatsApp: WA1/WA4/WA5–WA8 paused; phase state must serialize.
- KronIA: K1–K8 paused; stale K1 branches evidence-only.

## Anti-confusion examples

Do not:

- run Revenue F5 recovery while certifying CIA-F17;
- materialize K1 Auth/secrets while the F17 runtime baseline is moving;
- interpret Sentinel regression jobs as Sentinel development;
- treat WA transport completion as CIA readiness or CIA readiness as WA closure;
- use `SKIPPED`, another workstream's PASS, or historical green CI as the current phase gate;
- continue from a chat summary without rereading CURRENT GitHub/Supabase.
