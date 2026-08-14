# ASCENDA OS — Railway staging cause note

Date: 2026-08-13

Root cause confirmed: `app/railway.json` base `deploy.startCommand` pointed to `node server.js`. Railway Config as Code overrides dashboard service settings, so the staging service launched the production runtime even when the dashboard showed `node staging-server.js`.

Correction on branch `feat/sales-intelligence-v2-phase1-canary`:
- production/base remains `node server.js`;
- environment `staging-sales-intelligence` explicitly overrides to `node staging-server.js`;
- staging healthcheck is `/health`;
- staging runtime remains static-only and fixture-only.

Expected verification after Railway redeploy:
- `/health` => JSON containing `mode: staging-fixture`;
- `/` => Sales Intelligence fixture, not ASCENDA login.
