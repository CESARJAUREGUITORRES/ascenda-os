# Sentinel F5 — G10/G11 Checkpoint

**Fecha:** 2026-08-16  
**Fase:** F5 — Availability Layer  
**Scope:** cloud availability verification + synthetic outage/recovery  

## G10 — Cloud coverage

**Estado:** PASS

Evidencia humana verificada en UptimeRobot:

- monitor target: `https://ascenda-os-production.up.railway.app/health`
- provider: UptimeRobot Free
- current status: `UP`
- uptime visible: `100%`
- incidents visible: `0`
- interval: `5 min`
- endpoint remains public/read-only
- no authentication, request body, patient data or provider secrets required

Evidencia de ASCENDA/Railway disponible durante la misma sesión:

- `/health` responds HTTP 200
- ASCENDA service remains Online
- CREACTIVE local observer remains independent from Railway

The Railway screenshot used `Network Flow`, therefore `@clientUa:UptimeRobot` was not treated as required HTTP User-Agent evidence. Provider-side `UP` is the canonical G10 cloud heartbeat evidence.

## G11 — Synthetic outage/recovery

Production outage simulation is forbidden. G11 is therefore deterministic and synthetic against the versioned Sentinel availability state machine.

Required sequence:

1. Initial/no evidence -> `UNKNOWN`
2. Recovery threshold met -> `UP`
3. 1 failed sample -> `DEGRADED`
4. 2 failed samples -> `DEGRADED`
5. 3 failed samples -> `DOWN`
6. first success after DOWN -> `DEGRADED`
7. second consecutive success -> `UP`

Coverage matrix required:

- cloud fresh + local fresh -> `CLOUD_AND_LOCAL`
- cloud fresh + local stale -> `CLOUD_ONLY`
- cloud stale + local fresh -> `LOCAL_ONLY`
- both stale -> `UNKNOWN`

False-green rule:

- stale observer can never produce `UP`
- first isolated success after a known outage cannot produce `UP`

The executable certificate is `ci/sentinel/phase5_recovery_synthetic.js` and is required by `.github/workflows/sentinel-phase5-availability.yml`.

## Cost / privacy

- incremental monthly cost target: USD 0
- no paid host required for baseline
- no PHI/PII
- no auth headers
- no tokens
- no clinical endpoint probes
- no production mutation

## Remaining F5 boundary

After G11 CI passes on the exact PR head:

1. mark outage/recovery gate PASS;
2. generate terminal F5 certificate;
3. update roadmap + Notion;
4. close F5 at 100%;
5. set F6 — Business Health & Silent Failure Invariants as the only active phase.
