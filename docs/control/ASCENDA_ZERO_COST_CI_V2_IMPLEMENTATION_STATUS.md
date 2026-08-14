# ASCENDA OS — ZERO-COST CI V2 IMPLEMENTATION STATUS

**Estado:** IMPLEMENTED IN BRANCH / RUNNER REGISTRATION PENDING  
**Fecha:** 2026-08-14

## Repo-side complete

- Canonical V2 policy written.
- Self-hosted runner runbook written.
- Registration + healthcheck helpers added.
- Policy guard added to reject GitHub-hosted runners.
- All active workflows moved to `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`.
- Hourly legacy Supabase sync disabled; manual confirmation required.
- Path-aware routing and concurrency maintained/expanded.
- Phase 2 Final Release extended through Auth P0 fix + branded 2FA restore.

## External/manual gate

GitHub self-hosted runner registration requires a short-lived registration token generated in the repository Settings UI and commands executed on the authorized Windows/WSL PC. That token must remain local and must not be shared in chat.

Until the runner is online, self-hosted workflows intentionally remain queued. There is no automatic paid fallback.
