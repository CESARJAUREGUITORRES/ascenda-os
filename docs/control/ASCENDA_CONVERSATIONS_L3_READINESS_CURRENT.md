# ASCENDA CONVERSATIONS — CONV-L3 READINESS CURRENT

**Program:** CONV-001 #502  
**Loop:** CONV-L3 #507  
**State:** ACTIVE · RUN UNTIL BLOCKED · SHADOW/OFFLINE ONLY  
**Owner authorization:** development + CI + shadow/offline evaluation + merge/deploy/readback until the next owner-authenticated or cost-bearing boundary  
**Starting main:** `bea297e1c390b628c94542e63bc9365b82da98ce`  
**Prerequisite:** CONV-L2 #506 CLOSED / real human round-trip certified  
**Autonomous provider send:** NOT AUTHORIZED  
**Production autonomy:** `AUTO_OFF · KILL ON · AI SEND OFF · AUTO ROUTING OFF`

## Goal

Build the smallest framework-independent Sales Agent Runtime on top of the certified Conversation Core, without reopening the legacy autonomous hot path and without creating a second provider, customer, price, booking or consent authority.

Target hot path:

`bounded inbound -> semantic turn -> one agent cycle -> 0–2 typed tools -> response candidate -> stale/human recheck -> governed outbound eligibility`

L3 produces a **response candidate only**. It does not send WhatsApp messages.

## L2 prerequisite evidence

The owner-authenticated L2 round trip completed on production:

- `CONV L2 PANEL OK` = one HUMAN outbound canonical message;
- provider accepted/reconciled to DELIVERED;
- `L2 RESPUESTA OK` = one canonical inbound message;
- both rows resolve to the same canonical conversation;
- Conversation Core persisted the inbound event;
- conversation remained `HUMAN_ACTIVE`;
- active assignment remained valid;
- duplicate count = 1 outbound / 1 inbound;
- active PostgreSQL queries >2s and >5s = 0 at readback;
- Railway exact L2 deployment remained SUCCESS.

GitHub #506 is CLOSED / completed. L3 #507 is the sole HIGH/CRITICAL implementation lane.

## L3 foundation slice

The first L3 slice is deliberately provider-neutral and side-effect free:

- `app/conversation-agent-runtime.js`
  - bounded/redacted memory;
  - measured short-burst semantic-turn coalescing;
  - per-conversation single-flight;
  - explicit typed tool allowlist;
  - maximum 2 tool calls per turn;
  - tool timeout/fail-closed behavior;
  - deterministic STOP interception;
  - deterministic personalized-clinical handoff;
  - human ownership/takeover dominance;
  - stale-turn suppression after reasoning;
  - provider dispatch structurally absent.

The runtime accepts an injected `modelAdapter.run(...)` and an injected typed `ToolGateway`. No framework is required.

## Tool boundary

L3 may name only the frozen target tools:

- `get_customer_context`
- `get_prices`
- `get_promotions`
- `get_locations_payment_methods`
- `get_availability`
- `prepare_booking`
- `confirm_booking`
- `rebook_booking`
- `cancel_booking`
- `get_media`
- `handoff`
- `create_hot_lead_signal`

There is no generic SQL, HTTP, shell or provider tool.

L4 remains the phase that binds real business authorities to these contracts.

## Safety invariants

- no direct LLM -> Meta;
- no direct LLM -> SQL;
- no autonomous provider dispatch;
- human takeover wins before and after reasoning;
- STOP prevents model/tool work for that semantic turn;
- personalized clinical risk routes to HUMAN;
- failed governed tool truth cannot be replaced by invented commercial facts;
- PII in bounded conversational memory is redacted before model-adapter input;
- no raw provider secret/payload enters the agent runtime;
- no campaign/general-user traffic during L3.

## Local foundation evidence

Local isolated checks executed before branch write:

- `node --check app/conversation-agent-runtime.js` = PASS
- `node --test ci/conv-l3/agent_runtime_contract.test.js` = **13/13 PASS**

Covered cases include greeting, burst aggregation, bounded memory, STOP, personalized clinical handoff, human ownership, typed tool budget, generic-tool rejection, governed-tool failure, stale-turn suppression, human takeover race and single-flight.

This is **architecture/safety evidence**, not yet the final L3 conversational-quality certificate.

## Impact Report

**Project / phase:** CONV-001 / CONV-L3 #507  
**Objective:** introduce the new framework-independent Sales Agent Runtime contract.  
**Risk:** HIGH

### Code/runtime
Additive pure runtime module only. This slice is not wired to Meta dispatch and does not change the Railway entrypoint.

### Data/RPC/triggers
No schema, migration, trigger, function, table or production data mutation.

### Consumers/dependencies
Conversation Core L2 remains authoritative. Legacy WA4/WA-L10 code remains extraction/reference only and is not reactivated.

### Security/roles/sensitive data
No secrets added. No browser credentials. Direct provider/SQL execution absent. Memory redaction and deterministic STOP/clinical/human gates are local runtime controls.

### Tests
L3 contract + L2/L1/P0/performance regressions through a dedicated self-hosted workflow. No paid hosted-runner fallback.

### Rollback
Remove the additive L3 module/tests/workflow/readiness changes. No DB rollback is required.

### Portfolio-lock impact
CONV-L3 #507 is the sole HIGH/CRITICAL mutable lane. Other projects remain protected/read-only except their normal regression sensors.

## Remaining L3 gates

Before L3 can close:

1. add the concrete server-side model-adapter binding without direct provider-send authority;
2. bind bounded canonical conversation reads into a SHADOW/COPILOT-only path;
3. preserve human/stale recheck against the live canonical state;
4. run the frozen simple/multi-turn/product/objection/context-switch benchmark with an actual configured model;
5. grade naturalness, context retention, safety, tool discipline and latency;
6. prove no autonomous Meta send and no duplicate authority;
7. exact-head merge/deploy/readback;
8. persist evidence and only then mark L3 CLOSED.

A real model/provider evaluation that requires a new credential, a paid capability, or owner-authenticated UI interaction is the next legitimate stop boundary.

## Exit

L3 closes only when the actual model-backed SHADOW runtime passes the declared conversational benchmark and safety/concurrency gates. L3 closure still does **not** authorize autonomous Meta sending; real autonomy remains gated behind L7 plus a fresh owner authorization.
