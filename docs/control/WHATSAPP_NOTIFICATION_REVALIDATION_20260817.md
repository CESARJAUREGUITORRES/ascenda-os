# ASCENDA OS — WhatsApp + Notifications Revalidation — 2026-08-17

**Scope:** WhatsApp Revenue Hub WA-1..WA-4 + Phase S + notification stack S13/S14/S15/S15.1/S15.2/S15.3  
**Environment:** production `ituyqwstonmhnfshnaqz` + Railway ASCENDA OS  
**Purpose:** freeze evidence, isolate cross-workstream risk, repair the inbound regression and recertify end-to-end behavior before continuing the WhatsApp roadmap.

## 1. Frozen production evidence

Observed user sequence:

1. `PRUEBA 4` was sent while ASCENDA was closed and later appeared in the WhatsApp inbox.
2. No Windows Push notification was observed for `PRUEBA 4`.
3. After ASCENDA was reopened, `prueba 5` was sent twice and did not appear in ASCENDA.

Database evidence:

- `PRUEBA 4` exists in `aos_wa_messages_v1` as a real Meta inbound event at `2026-08-17 22:04:11+00`.
- The device Push subscription for CESAR was created later at `2026-08-18 01:07:46+00`.
- Therefore `PRUEBA 4` predates the active Push subscription and cannot certify closed-app Web Push.
- No `prueba 5` row and no corresponding `aos_wa_events_v1` event exist. The failure is before canonical persistence, not a UI refresh defect.

Current WhatsApp control state:

- conversation `zi vital` is `HUMAN_ACTIVE`;
- owner is CESAR;
- active assignment exists;
- `human_send_enabled=true`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- the current Push target resolver returns `eligible=true` with an active CESAR device subscription.

## 2. Root cause — S15.2 F17 buffered proxy framing regression

The S15.2 production insertion created this runtime path:

`Railway -> Phase S -> F17 -> F5 -> WA4 -> WA3 -> WA2 -> F4 -> Phase2 -> server.js`

Phase S streams POST bodies to its child after deleting `content-length`. Node therefore uses chunked transfer encoding.

F17 buffers governed `/webhook` and `/api/wa/send` requests and previously rebuilt the downstream request by adding a new `Content-Length` while copying all original headers. This preserved `Transfer-Encoding: chunked` and produced an invalid HTTP/1.1 request containing both framing mechanisms.

Node rejects that request before WA-1 can validate the Meta signature or persist the envelope. The defect was reproduced with `HPE_INVALID_CONTENT_LENGTH: Content-Length can't be present with Transfer-Encoding`.

This explains the production symptom precisely:

`Meta -> Phase S -> F17 [invalid downstream framing] -X-> WA1/F4 -> Supabase`

## 3. Remediation — S15.3

F17 now canonicalizes buffered downstream headers before replaying the exact raw body:

- remove `Transfer-Encoding`;
- remove `Connection` and connection-nominated hop-by-hop headers;
- remove standard hop-by-hop headers (`Keep-Alive`, `TE`, `Trailer`, `Upgrade`, proxy auth headers);
- set exactly one byte-accurate `Content-Length`;
- preserve end-to-end headers including `x-hub-signature-256` and content type;
- preserve exact raw body bytes so WA-1 Meta HMAC verification remains valid.

The same fix protects governed outbound `/api/wa/send`, which shares the buffered proxy path.

A permanent S15 production-chain contract now asserts the framing invariant and Meta signature preservation so future wrapper/runners cannot silently reintroduce this class of regression.

## 4. Parallel-workstream / runner isolation check

`main` advanced after the S15.2 merge through a CIA V3 merge. A commit-level comparison from S15.2 checkpoint `644cb0d...` to current main showed only Commercial Intelligence documentation additions and no runtime, WhatsApp, notification, migration or workflow changes.

Conclusion for this incident:

- shared runners were **not** the root cause;
- no CIA runtime contamination was found;
- the regression is deterministic code in the S15.2 F17 proxy boundary.

Operational rule going forward: every ASCENDA workstream must use a dedicated branch/PR, path-scoped CI and a named production checkpoint. Shared runners may execute jobs, but they must never be treated as the source of truth; Git commit/diff + deployment SHA is the source of truth.

## 5. Revalidation matrix

| Layer | Current evidence | Status before final physical canary |
|---|---|---|
| WA-1 secure gateway | signed webhook/persistence code intact; historical real inbound | REVALIDATING after S15.3 deploy |
| WA-2 inbox/store | canonical conversation/message reads healthy | PASS server-side |
| WA-3 ownership/handoff | HUMAN_ACTIVE + CESAR active assignment | PASS server-side |
| WA-4 AI router | deployed, fail-closed/off | PASS safety state |
| Phase S | process/bootstrap reads healthy | PASS |
| S13 open-app alerts | historical behavior exists | REVALIDATE physical |
| S14 Web Push backend | VAPID configured; CESAR subscription active; target eligible | PASS backend / physical pending |
| S15 event pump | live claims observed every ~4s | PASS backend |
| S15.1 auth boundary stage 1 | actor-bound APIs live; legacy ACL cutover withheld | PASS staged |
| S15.2 F17 runtime | live but framing defect found | SUPERSEDED by S15.3 |
| S15.3 framing hotfix | code + regression contract | PENDING CI/deploy/canary |

## 6. Certification gates

Do not declare 100% until all gates pass:

1. S15.3 CI green on exact PR head.
2. Railway deploy status green on exact merge commit.
3. With ASCENDA open, a new inbound test persists immediately and appears live in the Hub.
4. With ASCENDA fully closed, a second new inbound test persists and creates a Web Push dispatch to CESAR.
5. Windows shows the WhatsApp-specific notification and clicking it opens ASCENDA/WhatsApp Hub.
6. No duplicate notification storm when the app is visible.
7. Only after gates 1–6: execute the pending legacy notification ACL cutover and verify service-role-only legacy access.
8. Re-run WA-1/WA-2/WA-3/Phase S/S13/S14/S15 security and topology contracts.

## 7. Separate known blocker

The UI currently reports Meta API `TOKEN_INVALID_OR_EXPIRED`. This is the outbound Meta credential issue and is independent from the inbound framing regression. After inbound + Push certification, replace `WHATSAPP_ACCESS_TOKEN` in Railway with the approved long-lived System User token, redeploy, verify provider health and run a controlled outbound canary. Never place the token in GitHub, documentation or chat.

## 8. Reusable lesson

A wrapper chain is not certified by syntax/topology alone. Any boundary that buffers and replays HTTP bodies must have wire-level framing invariants. Specifically, a request must never be forwarded with both `Transfer-Encoding` and `Content-Length`, and signed webhook raw bytes must remain unchanged across every proxy boundary.
