# WA-L10 R8 — bounded conversation shortcuts

## Impact Report
**Project / phase:** WA-L10 #456; isolated candidate only.
**Risk:** HIGH conversation orchestration. No production mutation or CANARY authorization.
**Base:** 9592ee3a56e0ef26af2d455f80d5c191e2465bd6 (revalidated after concurrent PRs #484, #486 and #487).

## Problem and change
Returning greetings unnecessarily fell through to campaign/identity/knowledge/model processing. Clinical escalation also waited for enrichment, which could fail before the safe answer was returned. The runtime detected intents across inbound bursts but Copilot used only the final fragment for clinical screening and downstream evidence queries.

The candidate keeps returning greetings deterministic, moves clinical handoff ahead of enrichment and evaluates the complete bounded semantic burst. Auth/context checks still precede every shortcut. Clinical output has explicit needs_human=true and auto_send=false. Existing L4/L8 and the single provider sender are unchanged. Audit submission is attempted without holding the clinical response open, matching the existing first-contact/price fast lanes; this is not a guarantee of audit persistence under a failed audit sink.

## Comparison source
Read-only ROO7 reference: web/app/api/os/ai/route.ts in CESARJAUREGUITORRES/roosiete. Its staff endpoint authenticates the session, accepts the last 12 messages and makes one Groq completion call. That shows a smaller orchestration path, not measured performance equivalence or a safe drop-in replacement for customer-facing clinical WhatsApp. No ROO7 code, data, prompts or credentials were copied or changed.

## Tests
Full handler tests inject offline enrichment/model services and a pending audit sink. They prove returning-greeting response, clinical handoff, first-fragment clinical screening and authorization denial. Canonical WA4, L10 bridge and conversation-runtime suites: 70/70 Node test entries PASS locally. No real provider or production-data fixtures. No E2E latency claim.

## Historical notification evidence — superseded by PR #484
On September 9, hola and HOLA PRUEBA 2 were persisted once each at 23:17:23Z and 23:19:12Z. L4 remained AUTO_OFF; no autonomous response was expected. S14 WA push failed with F17_RPC_UNAVAILABLE at 23:17:31Z and 23:19:13Z. Live target-resolution readback for the latter message returned HUMAN_OWNER_REQUIRED. The conversation was HUMAN_REQUESTED, unowned; client sound and server push eligibility both require HUMAN_ACTIVE + current owner. No WhatsApp push dispatch or notification row was created in the observed interval. An active admin push subscription exists, so missing registration is not established as the cause.

PR #484 subsequently added the bounded V2 runtime VAPID path and one-recipient queue supervisor fallback while preserving the generic foreground shield. This candidate preserves that repair. PR #486 added Auth/WA availability classification and bounded coalescing/backoff; PR #487 records its production validation and restores the WA-L10 gate. The earlier notification diagnosis above describes the screenshot timestamp, not an assertion that current production still has that defect.

## Remaining gates / rollback
Current lock at 9592ee3 restores WA-L10 after P0 #485 closure. This remains an isolated SAFE-OFF conversation candidate, not a replacement for the R7 activation gate. Run relevant exact-head CI and protected merge before release. Inspect Railway staged changes before any deployment; do not apply unrelated pending variables. Verify production readback, full conversation replay and human takeover; obtain fresh exact-conversation CANARY authorization before activation. This candidate does not claim a full real conversation PASS; the deployed R7 flow still requires the explicitly authorized one-conversation canary. Notification remediation belongs to PR #484.

Rollback: revert the candidate code commit, redeploy the previous certified source through the governed pipeline. No schema, price, patient, appointment, delivery authority or model configuration changes.

## Exact-head CI follow-up
The first candidate CI exposed a cross-turn retrieval regression: using the entire burst for commercial retrieval could select an earlier PEN product when the latest request asked for a different USD product. Clinical screening now uses the combined burst while commercial retrieval retains the latest text and existing runtime-carried state. The full-local USD assertion is preserved and must pass on the revised head.

The WA4 Python topology contract also still required the old two-argument WA3 V2 proxy call after P0 #485 introduced a third boolean. The assertion now accepts only the original call or the explicit true/false argument, while retaining the canonical child/wrapper checks.

Owner authorized the one-conversation canary on 2026-09-10 in this chat. Activation is not yet executed: current Railway/main match at 9592ee3 and DB pressure is clear, but the remote browser provider-health request was blocked by the client (ERR_BLOCKED_BY_CLIENT). Fresh provider verification remains required. No authority flags or allowlist were changed.
