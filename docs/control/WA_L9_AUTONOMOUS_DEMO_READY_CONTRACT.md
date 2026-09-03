# WA-L9 — AUTONOMOUS DEMO READY

**Issue:** #453  
**Parent roadmap:** #410  
**ENTRY baseline:** `main@c0e546b77f072f85662c0c2ce5ab13f6f4f64f0d`  
**Governance lock:** `main@7a588dce3c2f398b39f54aef082ee2fe6e6fe60e`  
**Branch:** `wa-l9-autonomous-demo-ready-20260903`  
**Safety:** `AUTO_OFF · kill switch engaged · auto_reply=false · ai_send=false · auto_routing=false · human_send=true · CANARY NOT AUTHORIZED`

## Objective

WA-L9 certifies that the governed autonomous Revenue Agent can be demonstrated end-to-end without sending autonomous provider traffic and without creating a second autonomy authority.

The certified chain is:

`Meta/campaign context → conversation/identity → governed knowledge + price → booking readiness + real availability → BOOK/REBOOK decision path → L8 consent/STOP/security → L4 autonomous authority → redacted would-send envelope → L6 attribution context → L7 Meta/AI cost + journey KPIs → human handoff/fail-closed evidence`.

## Shadow authority design

`aos_wa_l9_shadow_authorize_v1(...)` calls the exact production `aos_wa_l4_authorize_autonomous_send_v1(...)` function. Since L8 already wraps that function, the shadow call traverses L8 first and L4 second.

The call executes inside a PL/pgSQL subtransaction and intentionally raises/catches `WA_L9_SHADOW_ROLLBACK` after receiving the authority result. The subtransaction rollback removes the L8 preflight row and L4 decision row before the RPC returns.

Therefore:

- L4 remains the sole autonomous-send authority;
- L8 remains the sole autonomous policy/security preflight;
- no shadow decision consumes daily/rate/cooldown/turn budgets;
- no shadow decision can reserve an outbound request;
- no shadow decision can call Meta;
- the returned `would_send=true` means only that the exact authority path returned `ALLOW` inside the rolled-back evaluation.

## Redacted demo evidence

`aos_wa_l9_demo_runs_v1` is append-only and stores only:

- demo key;
- conversation UUID;
- SHA-256 recipient hash;
- SHA-256 provider payload hash;
- message type/template name;
- L4/L8 decision/reason/mode;
- would-send boolean;
- structural `provider_dispatch=false`;
- structural `raw_content_stored=false`.

It never stores raw phone/BSUID, message body, prompt, model reply or provider token.

`scripts/wa-l9-shadow-demo.js` builds the same governed provider payload and L4 authority request used by the real transport, calls the rollback-safe shadow RPC, records redacted evidence and reads L7 conversation/journey cost. The CLI has no Meta transport implementation and never reads `WHATSAPP_ACCESS_TOKEN`.

## Positive demo gate

The isolated FULL LOCAL gate may temporarily set the synthetic local database to CANARY, install a synthetic conversation allowlist and run the shadow authority. The expected result is:

- L8 preflight = PASS;
- L4 decision = ALLOW;
- `would_send=true`;
- `provider_dispatch=false`;
- L4 decision count unchanged before/after shadow;
- L8 preflight count unchanged before/after shadow;
- no AUTO outbound request/message created.

The isolated database is restored to `AUTO_OFF + kill switch engaged` before certification completes.

## Negative matrix

The same shadow path must fail closed for at least:

- AUTO_OFF;
- kill switch;
- recipient/conversation mismatch;
- STOP/opt-out;
- identity conflict / required identity unresolved;
- unverified provider template;
- L8 business-initiation/consent failures;
- WA-4C governed knowledge/safety failures;
- unsupported booking/capability/no-slot conditions;
- replay/demo-key conflicts;
- unknown/partial pricing where the downstream cost model cannot reconcile deterministically.

## Cross-module / P0 #432 gate

WA-L9 may not add any hot-path trigger to Messages, Agenda, Calls or Sales and may not create/refresh a materialized view. The FULL LOCAL workflow freezes and compares PRE→POST counts for Agenda + Call Center + Marketing leads + Sales + Patients after the WA-4C demo corpus and before/after L9 itself.

The 3-second fail-fast boundary remains binding for scoped cost/status calls. No timeout inflation is permitted.

## Exit

WA-L9 is `AUTONOMOUS DEMO READY` only after:

1. exact-head CI is green;
2. dedicated L9 static and FULL LOCAL jobs pass;
3. WA-4C full conversation, governed knowledge/price/safety and transactional booking canaries pass;
4. WA-7A.4 + L8 + L7 + L6 + L5 + L4 regressions pass;
5. positive would-send shadow and negative matrix pass;
6. cross-module PRE→POST parity passes;
7. recovery is verified before history and fail-closed after audit history;
8. merge uses exact expected head;
9. any PROD migration is applied only from merged lineage and read back under SAFE-OFF;
10. autonomous outbound remains zero.

## Explicitly not authorized

WA-L9 does not authorize:

- `AUTO_OFF → CANARY` in production;
- kill-switch disengagement in production;
- autonomous Meta/provider dispatch;
- live allowlisted autonomous traffic;
- bulk sends/broadcasts;
- WA-L10 execution.

`WA-L10 — AUTONOMOUS PRODUCTION CANARY` is a separate owner-authorized production boundary.