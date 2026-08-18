# ASCENDA OS — AGENTS CURRENT OVERLAY

**Applies to:** every CURRENT ASCENDA agent/chat  
**ACTIVE WORKSTREAM:** `WA-NOTIFICATIONS-CLOSEOUT`

This overlay supersedes operational assumptions in historical `docs/adn/AGENTS.md` and earlier CURRENT snapshots while preserving them as provenance.

## Mandatory bootstrap

Before any write:

1. root `AGENTS.md` + `SECURITY.md`;
2. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
3. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
4. `docs/MEMORY_CURRENT.md`;
5. exact `main` and runtime chain;
6. live Supabase for WhatsApp/Push/Notifications;
7. WhatsApp Revenue Hub CURRENT Control Maestro + S15.3/S15.4 evidence;
8. current WA branch/PR/checks.

If ownership is ambiguous, stop writes and reconcile read-only. The current owner directive is unambiguous: WhatsApp/Notifications closes first.

## Portfolio Controller

Declare `WORKSTREAM_ID=WA-NOTIFICATIONS-CLOSEOUT`. Enforce one global HIGH/CRITICAL mutable workstream. CIA, Revenue, KronIA and migration-governance mutation are paused; Sentinel is regression-only.

## Runtime Architect

Captured chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`.

S15.3 repaired buffered HTTP framing. Any wrapper/runtime change must preserve exact chain and wire-level framing invariants.

## Supabase/Data Architect

Current production evidence includes S15.4 migration `20260818013809_s15_4_push_retired_subscription_recovery`. Do not replay it cosmetically. Verify its exact content/ACL and keep retired provider endpoints inactive.

Final legacy notification ACL cutover remains pending until closed-PWA Push certification.

## Security Guardian

Use root `SECURITY.md`. Provider tokens remain environment/vault only. Meta outbound token repair is a later WA gate and the token must never be committed, printed or pasted into chat.

## CI/Runner Governor

- shared runners are capacity, not authority;
- exact commit/diff + deployment SHA + live DB are authority;
- DB runner belongs to WA when DB/security gates are required;
- FAST may run isolated WA/runtime regressions;
- another workstream PASS is regression evidence only;
- any unrelated `main` advance requires diff/revalidation before WA merge/certification.

## Historian / Memory Manager

At each material incident or closeout:

1. freeze GitHub evidence;
2. record production ledger/runtime evidence;
3. update CURRENT GitHub docs;
4. update `aos_memory` after the release baseline is known;
5. update Notion last;
6. mark superseded PRs/branches clearly.

Current lessons to preserve: Phase S/F17 invalid dual HTTP framing caused lost inbound; Web Push 410 is a terminal provider endpoint; server retirement alone is insufficient unless browser PushManager state is reset; subscription presence alone does not certify delivery.

## Release Certifier

Do not declare WA/Notifications 100_COMPLETE until:

- S15.4 exact-current CI and Railway deploy pass;
- fresh PWA subscription is active and stale endpoint remains inactive;
- closed-PWA real inbound generates Push `DELIVERED`;
- Windows notification and click/deep-link are proven;
- duplicate/noise behavior is clean;
- legacy notification ACL cutover is applied/audited;
- Meta outbound token/canary is repaired separately;
- final WA1/WA2/WA3/WA4/Phase S/S13/S14/S15 regressions pass;
- GitHub/runtime/Supabase/aos_memory/Notion are reconciled.

## Current portfolio state

- WhatsApp/Notifications: **ACTIVE**.
- CIA: F17 4/6, F18 blocked; **PAUSED/READ-ONLY**.
- Revenue: F5–F7 **PAUSED**.
- Sentinel: F1–F13 **CLOSED / REGRESSION-ONLY**.
- KronIA: K1–K8 **PAUSED**.

No next workstream is automatically assigned after WA; wait for explicit owner handoff.