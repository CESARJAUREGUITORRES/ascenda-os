# ASCENDA OS — Sales Intelligence Phase 1 / Railway Staging

Date: 2026-08-13
Branch: `feat/sales-intelligence-v2-phase1-canary`

## Purpose
Visual validation of the real Sales Intelligence V2 UI using certified fixture data, without connecting the Railway staging runtime to Supabase production.

## Required Railway configuration
- Environment: `staging-sales-intelligence`
- Environment type: Empty Environment
- Repository: `CESARJAUREGUITORRES/ascenda-os`
- Branch: `feat/sales-intelligence-v2-phase1-canary`
- Root directory: `/app`
- Config as Code file: `/app/railway.staging.json`
- Custom Start Command effective value: `node staging-server.js`
- Healthcheck: `/health`
- Application variables: none required
- Public domain: enabled for the staging service

## Why the explicit staging config is mandatory
The repository already contains `app/railway.json` for the production service and that file starts `node server.js`. Railway Config as Code overrides matching dashboard values, so staging must explicitly use `/app/railway.staging.json` to prevent production runtime configuration from winning over the staging dashboard settings.

## Safety invariant
The staging service must run `app/staging-server.js`, never `app/server.js`.

The staging server is static-only and contains no Supabase URL/key, database calls, agents, background jobs or webhooks. It only accepts GET/HEAD and rejects write methods with HTTP 405. `/health` must return `mode: staging-fixture`, and responses include `X-ASCENDA-ENV: staging-fixture`.

If `/health` only returns `{\"status\":\"ok\"}`, staging is still running the production runtime and the gate FAILS.

## Expected certified values
- Facturado YTD: S/555,373.27
- Meta YTD: S/800,000.00
- Cumplimiento YTD: 69.42%
- Ticket YTD: S/435.59
- MTD 01–12 Aug: S/56,948.80
- Comparable 01–12 Jul: S/32,839.05
- Comparable MTD: +73.42%
- Projection: S/147,117.73
- Required daily pace: S/2,265.85

## Visual gate
Desktop and mobile must render the KPI cards, annual chart, projection and monthly table without overlap or error messages. The fixture page must not show `RPC V2 aún no desplegado en este entorno`.

After visual acceptance, Phase 1 may continue to the production read-only RPC canary. The production preflight/post-check checksum remains mandatory.
