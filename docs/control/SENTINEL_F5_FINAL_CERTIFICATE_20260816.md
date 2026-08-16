# Sentinel F5 — Final Certificate

**Phase:** F5 — Availability Layer / Uptime Kuma  
**Status:** `100_COMPLETE`  
**Date:** 2026-08-16 (America/Lima)  
**Architecture:** `hybrid-cloud-plus-local`  
**Incremental cloud cost:** `USD 0/month`  

## Scope certified

F5 establishes an availability layer independent from the ASCENDA application error sensor. The baseline combines:

- UptimeRobot Free as the continuous cloud observer for `https://ascenda-os-production.up.railway.app/health`;
- Uptime Kuma on CREACTIVE as an intermittent local observer with persistent state and automatic Docker restart;
- a local Sentinel observer agent that records only privacy-safe health fields and coverage gaps;
- a deterministic availability state machine with `UP`, `DEGRADED`, `DOWN`, and `UNKNOWN`;
- explicit coverage states `CLOUD_AND_LOCAL`, `CLOUD_ONLY`, `LOCAL_ONLY`, and `UNKNOWN`;
- anti-flapping thresholds of 3 failures before DOWN and 2 successes before recovery to UP.

## Gates

| Gate | Result | Evidence |
|---|---|---|
| F5-G01 contract | PASS | `sentinel/availability/f5-contract.json` v1.4 |
| F5-G02 privacy boundary | PASS | Zero PHI/PII, no auth headers/tokens/request bodies |
| F5-G03 safe `/health` target | PASS | public read-only health endpoint; expected HTTP 200 and semantic JSON |
| F5-G04 local persistent observer design | PASS | Docker-native Uptime Kuma + local observer |
| F5-G05 localhost-only admin UI | PASS | `127.0.0.1:3001` |
| F5-G06 persistent local state | PASS | Docker volume + resume report |
| F5-G07 coverage gaps | PASS | stale observer → `UNKNOWN`; no retroactive green claims |
| F5-G08 anti-flapping | PASS | 3 failures / 2 successes |
| F5-G09 local CREACTIVE deployment | PASS | persistent local observer gate already certified |
| F5-G10 continuous cloud observer | PASS | UptimeRobot UI verified `UP`, 100% uptime, 0 incidents, 5-minute checks |
| F5-G11 outage/recovery state machine | PASS | exact-head synthetic sequence `UNKNOWN → UP → DEGRADED → DOWN → DEGRADED → UP` |
| F5-G12 terminal certification | PASS | exact-head Sentinel F5 workflow + Ascenda CI |

## Exact-head validation

Terminal pre-certificate head before this document update:

`0ec5230fe1267b02bae64a608c516e33b19b1e02`

Verified workflow results:

- `Sentinel F5 Availability Foundation Certificate` run `31976415163`: **SUCCESS**.
  - `uptime-kuma-container-smoke`: SUCCESS on `ASCENDA-ZERO-COST-V2`.
  - `contract-fast`: SUCCESS on `ASCENDA-FAST-02`.
  - `F5 hybrid availability contract`: SUCCESS.
  - `F5 synthetic outage and recovery`: SUCCESS.
- `Ascenda CI` run `31976415169`: **SUCCESS**.

A final exact-head rerun is required after this certificate/terminal gate commit and must remain green before merge.

## Cloud evidence

User-side provider verification on 2026-08-16 showed:

- monitor target: `https://ascenda-os-production.up.railway.app/health`;
- current provider state: `UP`;
- uptime shown: `100%`;
- incidents shown: `0`;
- free-plan check interval: `5 minutes`;
- Railway service active and health traffic observed.

Sentry Uptime was not used for the cloud availability baseline because the provider UI rejected the shared `*.railway.app` domain after its shared 1000-monitor-alert limit. This is documented as provider-specific fallback history, not as a Sentinel dependency.

## Recovery semantics

The certified state machine prevents false green and loss of incident context:

1. stale/no observer evidence → `UNKNOWN`;
2. sufficient successful samples → `UP`;
3. first/second consecutive failure → `DEGRADED`;
4. third consecutive failure → `DOWN`;
5. first successful sample after `DOWN` → `DEGRADED`;
6. second consecutive successful sample → `UP`.

This specifically prevents the undesirable transition `DOWN → UNKNOWN` during active recovery.

## Local observer semantics

CREACTIVE may be powered off. When the machine is off:

- the local observer is unavailable;
- Sentinel must classify local coverage as absent/stale, not as ASCENDA down;
- UptimeRobot continues the continuous cloud baseline;
- after CREACTIVE restarts, Docker `unless-stopped` restores Uptime Kuma and the local agent;
- a coverage gap is recorded and represented as `UNKNOWN` for the unobserved interval;
- retrospective claims that ASCENDA was healthy while the local observer was offline are forbidden.

## Cost and privacy

- UptimeRobot baseline: Free.
- Uptime Kuma: open-source/local on existing CREACTIVE resources.
- No automatic paid hosting.
- No pay-as-you-go activation.
- No provider secrets in the monitor contract.
- No patient identifiers, WhatsApp/email content, request bodies, authorization headers, tokens, cookies, or clinical data.

## Production impact

This F5 closeout does **not** mutate:

- ASCENDA application business logic;
- Supabase schema/data;
- Railway environment variables;
- authentication/2FA;
- WhatsApp/Email flows;
- production write paths.

The only production-facing action already in effect is the external read-only polling of the public `/health` endpoint.

## Final decision

**F5 = `100_COMPLETE`**, subject only to the final exact-head CI rerun for this closeout commit remaining green before PR merge.

After merge, **F6 — Business Health & Silent Failure Invariants** becomes the only active Sentinel phase.
