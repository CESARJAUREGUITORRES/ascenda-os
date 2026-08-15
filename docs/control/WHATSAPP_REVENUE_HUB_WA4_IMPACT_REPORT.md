# ASCENDA Conversations — WA-4 AI Sales Agent & Multi-Model Router

**Risk:** HIGH  
**Mode:** additive, copilot-first, fail-closed  
**Precondition:** WA-3 100% PRODUCTION CERTIFIED after owner visual canary on 2026-08-15 (Lima).

## Objective

Add a governed AI sales copilot to the WhatsApp Revenue Hub without allowing autonomous WhatsApp outbound. The AI may read an owned conversation plus approved commercial facts, produce a structured suggestion, and surface human/clinical escalation. WA-3 remains the only human-send/ownership boundary.

## Model refresh

Groq announced shutdown on 2026-08-16 for developer/free usage of `llama-3.1-8b-instant` and `llama-3.3-70b-versatile`. WA-4 therefore standardizes:

- FAST / routine sales conversation: `openai/gpt-oss-20b`.
- REASONING / comparison and complex commercial reasoning: `openai/gpt-oss-120b`.
- SAFETY policy classifier for copilot canary: `openai/gpt-oss-safeguard-20b`.
- `qwen/qwen3.6-27b` remains an evaluation candidate for future multimodal WA-5, not a WA-4 production dependency.

Sources of truth are Groq Model Deprecation, Supported Models and model cards, checked 2026-08-15. The runtime also checks the account-specific `/openai/v1/models` list before enabling compatibility or copilot.

## Architecture

`server-wa4.js -> server-wa3.js -> server-wa2.js -> server-f4.js -> server-phase2.js -> server.js`

WA-4 owns no Meta sender. It exposes only:

- `GET /api/wa4/health` — non-secret provider/model readiness.
- `GET /api/wa4/bootstrap` — 2FA/panel protected control state.
- `POST /api/wa4/control` — admin-only copilot/budget control.
- `POST /api/wa4/conversations/:id/suggest` — exact-owner AI suggestion.

## Data changes

### `aos_wa_ai_control_v1`

- provider/model IDs;
- `copilot_enabled=false` by default;
- `auto_reply_enabled=false` with a CHECK that makes `true` impossible in WA-4;
- daily USD budget;
- context/catalog caps;
- FORCE RLS and service-role direct access only.

### `aos_wa_ai_runs_v1`

Append-only audit metadata:

- conversation/actor/task/provider/model;
- outcome;
- token counts;
- estimated cost;
- latency;
- safety action/category/error.

It does **not** persist raw prompts or raw model responses.

## P0 integration-secret boundary discovered during WA-4

The preflight found that the legacy `aos_integraciones` catalog had an anon RLS policy that allowed non-Resend provider rows to be read/written, while Groq and Gemini credentials were stored in `api_key`. WA-4 therefore includes a mandatory P0 remediation before AI can be enabled:

- copy existing integration credentials into `aos_integration_secrets_v1`;
- FORCE RLS and grant that vault only to `service_role`;
- clear `api_key` / `api_secret` from the browser-readable catalog;
- replace permissive anon/auth policies with sanitized metadata policies that require secret fields to remain blank;
- inject provider keys server-to-server into the historical runtime through the narrow WA-4 compatibility hook;
- never restore secrets to `aos_integraciones` during rollback.

This remediation is coupled to WA-4 because the Groq model migration must not increase dependency on an exposed credential path.

## Security and governance

1. Existing Auth V3 + 2FA/panel boundary is reused through WA-3.
2. AI suggestion requires exact current WA-3 owner; admin status alone does not bypass ownership.
3. Conversation must remain `HUMAN_ACTIVE` or `AI_COPILOT` with an active assignment.
4. Daily budget is checked server-side and fails closed.
5. Contact text sent to the model is minimized/redacted for email, long phone and document-like identifiers.
6. Personalized contraindication/eligibility/adverse-event questions deterministically escalate to a human/clinical path rather than being answered by the sales model.
7. Catalog citations and numeric prices are validated against approved facts; invented prices/citations are rejected.
8. A separate safety classification runs before a suggestion is returned.
9. `auto_reply` is impossible in this phase. WA-4 cannot call the Meta sender.
10. Groq secret stays server-side. Startup only exposes model availability booleans.

## Legacy Groq compatibility

The large historical `server.js` still contains retired Llama IDs. WA-4 uses a narrow Node require hook that transforms only the exact legacy `server.js` source in memory and only when the Groq models-list preflight proves GPT-OSS 20B + 120B are enabled for this account. No historical business logic is rewritten.

A separate data migration updates `aos_agentes.modelo` for the seven affected agents. Its recovery never restores retired model IDs; it degrades reasoning agents to GPT-OSS 20B if needed.

## Safe defaults

- Copilot: OFF.
- Automatic AI reply: structurally OFF.
- WA-3 auto-routing: unchanged/OFF unless separately enabled.
- WA-3 human send: unchanged/OFF unless separately canaried.
- Daily AI budget: USD 0.50.
- No boxes/users/permissions are auto-created by WA-4.

## Zero-Cost certification

Dedicated workflow must validate on exact SHA:

- Node syntax and router unit tests;
- WA-2/WA-3/F4/Cartera runtime chain compatibility;
- source secret and no-auto-send invariants;
- isolated exact WA-1 -> WA-4 migrations;
- DB lint;
- pgTAP ownership/RLS/budget/audit/no-auto-reply contracts;
- model refresh from legacy IDs;
- fail-closed recovery preserving WA-3 and WA-4 audit evidence.

## Rollback

Runtime rollback: restore Railway start command to `node server-wa3.js`.

Database recovery:

- force `copilot_enabled=false`;
- force `auto_reply_enabled=false`;
- remove WA-4 authorization/control RPCs;
- retain AI run evidence with FORCE RLS and append-only guard;
- preserve all WA-3 routing/ownership state.

Model rollback never reintroduces externally retired Llama IDs.

## Exit gates

1. Exact-SHA Zero-Cost workflow PASS.
2. Cross-workstream regressions green.
3. Merge to current `main` only after rebase/sync if another workstream moved it.
4. Deploy WA-4 and verify `/api/wa4/health` confirms account-specific GPT-OSS readiness without exposing the key.
5. Apply WA-4 control/audit migration to production with copilot OFF.
6. Apply the server-only secret boundary, then re-verify provider readiness through the vault.
7. Only after model readiness: apply the seven-agent model refresh.
8. Enable copilot for a controlled exact-owner canary and evaluate generated suggestions; no automatic send.
9. WA-4 reaches 100% only after grounded sales/security evals and owner canary. Autonomous AI outbound is a later controlled gate, not WA-4 default behavior.
