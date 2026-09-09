# WA-L10 R7 readiness revalidation — 2026-09-09

Scope: read-only production audit and isolated synthetic regression. No production mutation or autonomous activation. This checkpoint does not certify L10 or L11.

## Evidence / transfer comparison

| Surface | Classification | Observed state |
| --- | --- | --- |
| GitHub main | CURRENT | d072686ed7e1cee6d01b76a1fe8fc701eeadcb4d; PR #482 merged; no later main commit observed |
| R7 exact PR CI | CURRENT | All 10 returned relevant PR-head workflows completed/success on aaad163265a50f0b9bafb4e664e90017d79368cd |
| Railway | CURRENT | deployment 1991b9ce-193f-4b50-8d89-89d5770e1080 SUCCESS, same d072686 commit, created 2026-09-09T21:32:23Z |
| Notion deployment snapshot | STALE | Still cites 97c53c36-f029-45ad-ab21-7478ec86dbbf, now REMOVED |
| Runtime | CURRENT | Startup foregroundPriorityMode=true; WA4 loaded; L10 EVENT_DRIVEN_NO_POLL; F4 authority AUTO_OFF-by-default |
| Provider | CHANGED | Fresh post-deploy GET /api/wa3/provider-health HTTP 200 at 2026-09-09T21:39:49.837255039Z, 1542ms. Exact app/server-wa3.js returns 200 only after token + phone checks succeed, diagnosis READY. This is HTTP-log + source-contract evidence, not a new response-body probe |
| Panel | PARTIAL | Health, WA presence and bootstrap HTTP 200 in observed production traffic. Full human take/release/composer/role interaction not certified by this audit |
| L4 | CURRENT | AUTO_OFF, kill=true, copilot=true, auto_reply=false, ai_send=false, auto_routing=false, human_send=true, active_allowlist=0 |
| L4 budgets | CURRENT | 12/day; 6 turns/conversation; 3/min global; 1/min conversation; cooldown 10s; duplicate window 120s |
| L8 bounded safety | CURRENT | Browser message write=false; browser booking write=false; historical autonomous_outbound=1 is an all-time EXISTS indicator |
| Current-deployment autonomous outbound | CURRENT | 0 persisted AUTO OUTBOUND rows since 2026-09-09T21:32:23Z |
| L10 | CURRENT | Latest recorded real run is R5: jobs=2, attempts=2, sent=1, handoff=1; active_exact_scope=0; effective_autonomous_send=false. No real R7 run |
| Exact conversation | CHANGED | HUMAN_REQUESTED; last inbound 2026-09-05T22:33:47Z; within_24h=false on 2026-09-09T23:09:41Z |
| DB pressure | CURRENT, bounded | 0 other active queries >2 seconds at 2026-09-09T23:06:29Z. A point-in-time observation, not a load test |
| P0 #467 | CURRENT | CLOSED/completed 2026-09-05T16:57:49Z; closeout includes actual Auth login/2FA success |
| GitHub CURRENT docs | STALE | Lock still says P0 #467 ACTIVE; WA CURRENT says WA-4C; MEMORY says L10 not started. Do not treat these stale snapshots as a new active incident or as current phase certification |
| Railway staged configuration | UNKNOWN scope | 26 pending environment changes, 22 variable changes on ascenda-os. Values not exposed or applied. Effective startup confirmed from deployed logs and app/railway.json; generic service config alone is not runtime evidence |

No source-code drift after the transfer was observed. Deployment replacement and stale documentation are distinct from code changes.

## Isolated validation performed

Fetched exact-commit source files through GitHub into a disposable local audit tree. No production credentials or patient fixtures.

Command: node --test ci/wa4-ai-sales-router/ai-router.test.js app/wa-l10-autonomous-bridge.test.js

Final result: **65 tests passed, 0 failed** (56 canonical WA4 + 9 L10 bridge).
Coverage includes R7 persona/style, grounded prices, no-promo continuity, carried treatment context, booking progression, clinical fail-closed, typing ordering/best effort, single sender, no retry loop and provider failure handoff.

First run: 64/65; the only failure was ENOENT for a migration not yet copied into the local audit tree. Retrieved exact supabase/migrations/20260905203000_wa4a_retrieval_relevance_v2.sql and reran the same suite successfully. No product code changed to obtain PASS.

These mocked/pure tests are not end-to-end Meta delivery or latency evidence.

## Minimum remaining closeout

1. Reconcile stale CURRENT governance files through scoped documentation PR and protected review; retain historical evidence. Do not silently acquire a HIGH/CRITICAL lock through this audit report.
2. Inspect pending Railway changes before any deployment; do not accept the entire staged patch as part of a canary.
3. Complete authenticated human-panel interaction checks and full A–L conversation replay coverage where existing suites do not prove them.
4. Obtain fresh explicit owner authorization for one exact-conversation R7 CANARY; broad continuation language is not activation permission.
5. Receive fresh real inbound while SAFE-OFF to refresh the service window, then revalidate exact current SHA/deploy, provider, live governed pricing, L8 consent/service eligibility and DB pressure before arming.
6. Arm only the canonical governed scope using current RPC signatures; preserve existing limits and rollback path.
7. Real sequence: greeting → price → promotion → booking; inspect typing, context, price provenance, delivery reconciliation, duplicates, human takeover and actual end-to-end timing. Abort to AUTO_OFF/kill=true/allowlist=0 on any declared stop condition.
8. Close L10 only on real PASS; L11/general production remains separately gated.

## Source references

- https://github.com/CESARJAUREGUITORRES/ascenda-os/issues/456
- https://github.com/CESARJAUREGUITORRES/ascenda-os/pull/482
- https://github.com/CESARJAUREGUITORRES/ascenda-os/issues/467
- https://github.com/CESARJAUREGUITORRES/ascenda-os/blob/d072686ed7e1cee6d01b76a1fe8fc701eeadcb4d/app/server-wa3.js
- https://www.notion.so/3bf0e4fe8414810793f5c19da8be0c78

Risk: LOW documentation/audit. Rollback: revert this documentation-only commit. Production runtime, database and autonomous authority unchanged.

## Authenticated panel follow-up

Secure user-assisted Auth V3 credentials and 2FA succeeded in the audit browser. Navigated via the visible WhatsApp Hub menu. Inbox, exact conversation, Details, Customer 360, Campaign and Activity rendered. UI reports Meta API READY, RUNTIME READY, AI SEND OFF, BOT OFF, 24H closed, no owner. Manual composer is disabled with the explicit ownership requirement. Customer 360 returns no resolved canonical patient; Campaign returns no explicit ad provenance; neither invents identity/attribution. Historical R5 formatting defects remain visible in old messages and are not new R7 outputs.

No human message, assignment, release, autonomous activation or new model suggestion was executed. This proves authenticated panel reading and fail-closed composer presentation, not the unexecuted human-send/takeover workflow. Fresh owner CANARY authorization is still absent.
