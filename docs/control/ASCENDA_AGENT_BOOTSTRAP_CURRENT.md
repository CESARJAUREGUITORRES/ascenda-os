# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Captured from baseline:** `main@93fcc9a5171703ee6750f67c3c17373a323dc2ab`  
**Runtime:** S15.3 + S15.4 Push recovery closeout  
**ACTIVE WORKSTREAM:** `WA-NOTIFICATIONS-CLOSEOUT`

## Mandatory bootstrap

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/MEMORY_CURRENT.md`
6. WhatsApp Revenue Hub Control Maestro + S15.3/S15.4 closeout evidence
7. exact `main`, Railway runtime/deploy and live Supabase WA/Push state
8. relevant WA branch/PR/checks only

Do not resume CIA, Revenue, KronIA, migration-governance mutation or Sentinel maintenance as a competing workstream while WA owns the lock.

## Runtime

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

S15.3 fixed invalid Phase S → F17 buffered HTTP framing. Do not bypass F17 or downstream WA wrappers.

## WA closeout entry contract

Verified production evidence:

- real inbound after S15.3 persists again;
- `PRUEBA 6 S15.3` produced canonical `message.received` and updated `zi vital`;
- conversation remains `HUMAN_ACTIVE`, owner CESAR;
- Push dispatch executed and returned provider 410;
- retired PWA endpoint is inactive with one recorded failure;
- S15.4 production DB recovery migration is live and service-role-only;
- old legacy notification RPC ACL remains intentionally uncut.

## Next actions

1. freeze exact CURRENT before each merge;
2. integrate S15.4 client recovery from exact CURRENT;
3. pass S14/S15/Ascenda CI on the exact candidate;
4. verify exact Railway deploy;
5. reopen installed PWA and require a new active Push subscription while stale endpoint stays inactive;
6. close PWA completely and run a new real inbound canary;
7. require WA persistence + Push `DELIVERED` + Windows notification + deep-link;
8. verify no visible-app duplicate storm;
9. execute final legacy notification ACL cutover only after the physical Push gate;
10. repair Meta outbound token separately with a long-lived System User token in Railway, then controlled outbound canary;
11. revalidate WA1/WA2/WA3/WA4/Phase S/S13/S14/S15 before any 100_COMPLETE claim;
12. update GitHub current docs, `aos_memory`, then Notion and wait for explicit next owner lock.

## Certification rule

No percentage, runtime merge, sibling PASS, queued/skipped job or historical green CI certifies WA/Notifications. Require exact-head evidence, live state, security boundary, rollback/recovery, real physical canaries and final cross-source reconciliation.