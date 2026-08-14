# CIA V3 — SENTRY FOUNDATION VALIDATION CHECKLIST

Sentry is not considered operational for ASCENDA until all items below are PASS.

- [ ] Sentry project for ASCENDA identified/created.
- [ ] DSN configured only through secret/environment management.
- [ ] Server SDK installed/configured in staging.
- [ ] Browser SDK installed/configured if required.
- [ ] `environment=staging` visible in received events.
- [ ] Release identifies Git commit/deploy.
- [ ] PII scrubbing reviewed; no clinical notes, photos, auth tokens or secrets.
- [ ] Controlled staging exception received in Sentry.
- [ ] Source maps/release artifacts verified when applicable.
- [ ] Trace/performance sampling policy documented.
- [ ] Alert routing documented.
- [ ] Disable/rollback path documented.
- [ ] ChatGPT Sentry read-only tool smoke verified from a session where the Sentry tool is exposed.
- [ ] Notion Hallazgo, GitHub docs and `aos_memory` synchronized.

Until these pass, status remains `CONNECTED_EXTERNAL / RUNTIME_NOT_INSTRUMENTED`.
