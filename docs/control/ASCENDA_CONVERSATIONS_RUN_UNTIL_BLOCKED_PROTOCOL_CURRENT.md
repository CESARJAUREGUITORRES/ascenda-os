# ASCENDA CONVERSATIONS — RUN-UNTIL-BLOCKED EXECUTION PROTOCOL CURRENT

**Program:** CONV-001  
**Purpose:** let the execution agent organize, evaluate, implement, test, remediate and verify the active loop with minimum owner interruption.  
**Mode:** RUN UNTIL BLOCKED.  
**Global rule:** one HIGH/CRITICAL loop at a time.  
**No background promise:** execution happens in the active working session/automation context; this protocol does not claim unattended work outside an authorized run.

## 1. Owner authorization model

A loop starts only after one explicit owner authorization naming the exact loop.

Recommended form:

```
AUTORIZO CONV-L<n> #<issue> — RUN UNTIL BLOCKED
```

That one authorization permits the execution agent to continue through all **reversible, in-scope technical steps** without asking the owner after every commit/check.

Within the authorized loop the agent may, when supported by evidence and repository governance:

- revalidate GitHub/main/branch/PR state;
- inspect Supabase/Railway/runtime evidence;
- create or update the scoped branch;
- implement the approved loop;
- add/update tests and CI contracts;
- repair legitimate regressions discovered by those tests;
- open/update PRs;
- wait for and inspect CI;
- rebase/update exact-head when required;
- merge when all required in-scope gates are green;
- verify exact merged SHA;
- observe deployment and runtime health when deployment is part of the loop;
- run read-only production verification;
- update CURRENT docs/issues/evidence;
- continue to the next sub-gate inside the same authorized loop.

The agent must not repeatedly ask `¿procedo?` for these normal steps.

## 2. What still requires owner intervention

RUN UNTIL BLOCKED stops immediately when any of these boundaries is reached.

### A — New loop / scope expansion
Examples:
- L1 -> L2;
- Conversations -> Revenue;
- adding an unplanned HIGH/CRITICAL migration;
- broadening a test from one bounded test recipient to general users.

Requires a fresh owner authorization.

### B — Real external side effect not already explicitly bounded
Examples:
- first live Meta send to a real/test recipient;
- enabling a real autonomous canary;
- campaign dispatch;
- real appointment creation if the test would mutate production Agenda;
- production message/template send outside an already approved test matrix.

For provider tests, request **one bounded authorization for the full matrix**, not one approval per message.

Recommended form:

```
AUTORIZO CONV-L1 REAL META TEST — <TEST SCOPE> — RUN UNTIL RESULT
```

Once granted, the agent may execute the whole approved provider test matrix and stop only on PASS, safety failure or required human action.

### C — Secret / account action
Examples:
- token rotation;
- Meta console permission approval;
- 2FA challenge;
- payment/billing approval;
- adding a provider asset that only the account owner can add.

Never ask the owner to paste production secrets into chat. Ask for the secure account-side action, then verify from runtime/provider health.

### D — Irreversible/destructive production mutation
Examples:
- dropping legacy tables/functions;
- deleting historical audit evidence;
- destructive backfill/rewrite;
- deleting provider/channel configuration.

Requires explicit owner approval after impact + rollback evidence.

### E — General autonomous production
Any transition from bounded test/canary to general autonomous production requires its own go/no-go authorization.

### F — Policy ambiguity
If business/clinical/privacy policy is genuinely ambiguous and cannot be inferred from canonical product rules, stop and ask the owner.

## 3. Execution loop

For one authorized CONV loop:

```
0 AUTHORIZATION
  ↓
1 EXACT-CURRENT REVALIDATION
  GitHub main + active PR/head
  Railway exact deployment/runtime
  Supabase safety/performance state
  current loop issue/contract
  ↓
2 IMPACT MAP
  owner component
  consumers
  authority
  risk
  rollback
  tests
  ↓
3 SMALLEST IMPLEMENTATION SLICE
  no scope expansion
  no duplicate authority
  ↓
4 FAST STATIC/UNIT/CONTRACT GATES
  ↓
5 REPAIR LOOP
  failure -> classify:
    implementation bug -> fix
    stale test -> update test with evidence
    unrelated paused-lane failure -> document, do not mutate that lane
    ambiguous production failure -> stop
  repeat 4
  ↓
6 DB/SECURITY/PERFORMANCE GATES WHEN APPLICABLE
  ↓
7 EXACT-HEAD ANTI-DRIFT
  main still expected?
  PR mergeable?
  no incompatible current change?
  ↓
8 MERGE
  only if authorized loop permits merge
  ↓
9 EXACT-SHA DEPLOY / RUNTIME READBACK
  only when runtime change exists
  ↓
10 PRODUCTION VERIFICATION
   health
   provider/readiness
   DB >2s/>5s
   duplicate/error checks
   protected-module regressions
  ↓
11 EVIDENCE CHECKPOINT
   issue + CURRENT docs + SHA + runtime receipt
  ↓
12 NEXT SUB-GATE
   still same authorized loop? -> continue automatically
   owner boundary? -> STOP AND REQUEST OWNER
```

## 4. Failure handling

The agent does not blindly retry.

### Deterministic code/test failure
Inspect -> fix -> rerun.

### Provider failure
Classify:
- credential/auth;
- permission/asset;
- recipient/template/policy;
- rate limit;
- transient network;
- ambiguous timeout.

Do not resend an ambiguous outbound until idempotency/provider reconciliation proves retry safety.

### DB/performance degradation
Do not inflate timeouts.
Reduce work/fan-out, isolate background load, inspect query plan/call frequency.

### Production safety failure
Fail closed first, then investigate.

For autonomous legacy/new AI:
- human takeover;
- STOP/privacy;
- duplicate;
- wrong money/fact;
- unsafe clinical content;
- wrong booking mutation;
- provider ambiguity;
- retry loop;
- material cross-module degradation

=> stop outbound authority / rollback to safe state before analysis.

## 5. Evidence standard for each sub-gate

A sub-gate is complete only when applicable evidence contains:

- exact code SHA;
- exact PR/head;
- exact CI run result;
- exact deployed SHA for runtime work;
- direct live readback;
- independent invariant where data mutation occurred;
- rollback state;
- unresolved risks.

`CODE PASS != DEPLOY PASS != PROD PASS`.

## 6. Token / credential handling

Owner reports that the Meta WhatsApp access token was rotated on 2026-09-11 after the prior test credential expired.

This is **reported configuration state, not certified provider readiness**.

At the first authorized L1 execution:
1. do not request the token value;
2. verify runtime variable presence through secure platform tooling if needed;
3. perform a live provider-health/auth/asset check;
4. record only sanitized status/error codes;
5. treat the credential as READY only from fresh provider evidence.

If provider-health fails, stop at the account-action boundary only when the fix requires the owner.

## 7. CONV-L1-specific run plan once authorized

Within `CONV-L1 #505 — Native Meta Channel Gateway`, RUN UNTIL BLOCKED will execute:

### L1-A Current provider contract extraction
- verify current Meta config contract;
- freeze normalized error/status taxonomy;
- identify all direct Meta callers that must become compatibility callers.

### L1-B Native MetaCloudAdapter
Implement one boundary for:
- webhook verification;
- webhook normalization;
- provider status normalization;
- text;
- media;
- template;
- interactive;
- typing;
- health;
- template sync/read model.

### L1-C Compatibility adapters
Legacy routes may proxy to the new provider boundary but cannot keep a second provider implementation.

### L1-D Idempotency/status contract
- one outbound reservation;
- one provider message ID;
- safe ambiguous-timeout handling;
- monotonic status reconciliation.

### L1-E CI / provider fixtures
- signature;
- inbound message types;
- statuses;
- provider errors;
- template/media payload contracts;
- duplicate/idempotency cases.

### L1-F Shadow / no-AI runtime
Deploy gateway behind compatibility/shadow mode with AI autonomy still OFF.

### L1-G Fresh provider-health
Verify current rotated token and Meta assets from the deployed exact SHA.

### L1-H Owner boundary: real Meta test
If no bounded real-test authorization is already present, stop once and request it.

After approval, run the full bounded test matrix:
- inbound;
- outbound text;
- image/media;
- approved template;
- interactive if supported by current scope;
- delivered/read/status reconciliation;
- duplicate/idempotency negative case;
- provider error negative case where safely simulatable.

### L1-I Closeout
If all pass:
- persist exact evidence;
- mark L1 technically closed;
- make L2 NEXT ELIGIBLE / NOT AUTHORIZED;
- stop for the owner.

## 8. Definition of a useful owner interruption

When the agent stops, it must ask for **one concrete action**, not a broad `what next?`.

Examples:
- `Please complete Meta app permission X; I will verify automatically afterward.`
- `Authorize the bounded L1 real Meta test matrix for test conversation Y.`
- `Authorize CONV-L2 #506 — RUN UNTIL BLOCKED.`

The owner should not be used as a manual CI operator or asked to approve ordinary commits one by one.

## 9. Default response behavior

During an authorized RUN UNTIL BLOCKED session:
- execute first;
- report meaningful checkpoints;
- do not narrate every trivial tool call;
- stop only at a defined owner boundary, a safety stop, or technical ambiguity that cannot be resolved with available evidence.
