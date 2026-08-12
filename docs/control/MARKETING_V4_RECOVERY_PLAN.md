# Marketing V4 Recovery Plan — 2026-08-12

## Incident
After the Marketing V3.1 production promotion, the dashboard can render legacy KPIs while V3 blocks remain empty/loading (`Trazabilidad`, `Histórico`, `LTV`, `Atribución`). `Intención → Compra` may still render because it is driven by a separate late patch.

## Root cause
The production frontend accumulated multiple runtime wrappers over the same global functions (`mkL`, `rHist`, `rLTV`, etc.) and persistent `window` guards. This is unsafe in ASCENDA's SPA lifecycle because the Marketing view can be mounted more than once without a full browser reload. The V3.1 patch also overrides `window.rHist` and `window.rLTV` with no-op callbacks, creating a second race between legacy and V3 rendering.

## Recovery strategy
- Replace the stacked adapter/patch file with one idempotent V4 controller.
- On each mount, destroy the previous V4 instance and cancel pending requests/timers.
- Use deterministic public read-only gateways for Summary, History, LTV, Attribution, Intent, Ads and Campaigns.
- Render History and LTV directly from annual V3 sources; month selection only changes focus/highlight.
- Keep legacy renderer only for blocks not owned by V4 (sales lists, management strip and existing modal workflows).
- Every V4-owned block must have loading, success, empty and error states.
- No business data mutation and no database DDL in this recovery.

## Risk
MEDIUM — frontend functional/reporting only. No INSERT/UPDATE/DELETE and no auth/RLS/grant changes.

## Validation
1. JS syntax + existing Ascenda CI.
2. Fresh load on August 2026: Trace, History, LTV, Attribution and Intent all render.
3. Switch August → March: History remains Jan–Aug; March is highlighted; M0 = S/965; LTV total = S/18,842.
4. Switch back March → August repeatedly.
5. Leave Marketing and open it again: V4 remounts and all blocks render again.
6. Year mode: month-only blocks hide or adapt without leaving stale content.

## Rollback
Revert the single frontend commit that replaces `app/public/admin-marketing-v2.js`. Database is untouched by this recovery.
