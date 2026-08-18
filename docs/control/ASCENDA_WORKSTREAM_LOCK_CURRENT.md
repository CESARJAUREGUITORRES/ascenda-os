# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / explicit owner override  
**Captured from baseline:** `main@93fcc9a5171703ee6750f67c3c17373a323dc2ab`  
**Runtime inherited:** S15.3 / `ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**ACTIVE LOCK:** `WA-NOTIFICATIONS-CLOSEOUT`  
**NEXT LOCK:** `UNASSIGNED` until WA closeout is certified.

## Owner directive

The owner explicitly ordered ASCENDA to stop parallel HIGH/CRITICAL project execution and finish the WhatsApp/Notifications workstream first: identify the regression, repair it, revalidate the complete WhatsApp + notification chain, preserve the learning, and certify it before moving to another project.

This directive supersedes the earlier portfolio order that assigned the active lock to `CIA-F17/F18-CLOSEOUT`.

## Global rule

At most **one HIGH/CRITICAL feature/data workstream may mutate ASCENDA at a time**.

Canonical namespaces remain: `CIA-F*`, `REV-F*`, `WA-*`, `SEN-F*`, `K*`, `PARITY-*`, `BASELINE-*`, `CONTROL-*`.

While `WA-NOTIFICATIONS-CLOSEOUT` owns the lock:

- WhatsApp Revenue Hub plus S13/S14/S15.x notification transport may mutate only within the scoped recovery/certification plan;
- CIA, Revenue, KronIA and migration-governance feature work are read-only/documentation-only;
- Sentinel remains closed/regression-only unless a demonstrated Sentinel regression is caused by this release;
- no competing migrations, materializers, canaries or deploys are intentionally started;
- FAST runners may execute isolated WA/runtime regressions required by this workstream;
- `ASCENDA-ZERO-COST-V2` is reserved for WA/notification DB/security/release gates when needed;
- any unrelated advance of `main` invalidates a pending exact-head WA certificate until the diff is revalidated.

## Runtime CURRENT

Railway chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`

S15.3 repaired invalid buffered HTTP framing between Phase S and F17 while preserving the chain.

## Live WA / Notifications checkpoint

Physical canary `PRUEBA 6 S15.3` proved:

- signed WhatsApp inbound traverses the runtime again;
- canonical message/event persistence succeeds;
- conversation `zi vital` remains `HUMAN_ACTIVE` with owner CESAR;
- WA2/WA3 state and counters update correctly;
- Web Push dispatch executed but provider returned HTTP `410 Gone`.

The retired CESAR PWA endpoint is intentionally inactive with `failure_count=1`.

Production Supabase already contains:

`20260818013809_s15_4_push_retired_subscription_recovery`

Its contract refuses to resurrect a provider-terminal endpoint with the same endpoint+keys and returns `reset_required=true`. Execute privilege remains service-role-only.

## Active closeout sequence

1. Integrate S15.4 client self-healing on exact CURRENT.
2. Require exact-head S14/S15/Ascenda CI PASS.
3. Require Railway SUCCESS on the exact merge commit.
4. Reopen the installed ASCENDA PWA and verify the retired endpoint stays inactive while a new active subscription is created.
5. Fully close ASCENDA and send a new real inbound WhatsApp canary.
6. Require canonical WA message/event persistence and Push dispatch `DELIVERED`.
7. Require native Windows notification and successful click/deep-link into ASCENDA/WhatsApp.
8. Verify no duplicate notification storm when ASCENDA is visible.
9. Only then execute the pending legacy notification ACL cutover and verify service-role-only legacy access.
10. Resolve the separate Meta outbound `TOKEN_INVALID_OR_EXPIRED` blocker with an approved long-lived System User token in Railway; never put the token in GitHub/chat.
11. Run the controlled outbound canary and revalidate WA1/WA2/WA3/WA4/Phase S/S13/S14/S15.
12. Only after all declared WA/notification gates close may the owner assign the next global workstream lock.

## Paused project state

### CIA
CIA-F0..F16 closed; CIA-F17 remains 4/6 and CIA-F18 blocked. No CIA closeout mutation while WA owns the lock. Existing CIA evidence remains valid input but does not authorize parallel execution.

### Revenue
REV-F1..F4 closed; REV-F5/F6/F7 paused. No historical ingest/rebuild/apply or canonical patient mutation.

### KronIA
K0 closed; K1–K8 paused. Historical K1 branches remain evidence-only.

### Sentinel
SEN-F1..F13 remains closed/regression-only.

## Runner policy

- shared runners are execution capacity, never source of truth;
- source of truth is exact Git commit/diff + production deployment SHA + live Supabase evidence;
- unique DB/container/project names per run;
- cleanup on success/failure;
- no production secrets or PHI/PII as CI fixtures;
- queued/pending means capacity wait, not product failure;
- a PASS from another workstream is only regression evidence, never WA certification.

## Handoff rule

Do not move the lock automatically. A future handoff requires exact main/runtime, live Supabase state, PR classification, CI/canary/rollback evidence, final GitHub CURRENT docs, `aos_memory`, Notion-last reconciliation and an explicit owner-approved next workstream.