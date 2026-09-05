# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-04 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L10 #456 — FIRST REAL TURN FAIL-CLOSED REMEDIATION V2`  
**GitHub authority:** Issue `#456` = `OPEN / ACTIVE`  
**Parent roadmap:** Issue `#410`  
**Exact entry main:** `abb6444766cb45116f42c450c1174d339c2b86fc`  
**Active branch:** `wa-l10-first-turn-candidate-prefilter-20260904`  
**Deployed L10 layer:** `PR #464 · event-driven autonomous canary bridge`  
**Deployed first remediation:** `PR #465 · first-turn DB hotpath v1`  
**Current production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**Active L4 allowlist:** `0`  
**Prior L10 CANARY authorization:** `CONSUMED BY FIRST-TURN ATTEMPT; RE-ACTIVATION SUSPENDED PENDING FRESH EVIDENCE`  
**Authorization ref:** `OWNER-CHAT-20260904-L10-ZIVITAL-CANARY`  
**L11/general PROD:** `NOT AUTHORIZED`

## First real turn and v1 remediation result

The exact Zi Vital test conversation produced a valid Meta inbound and entered the deployed L10 bridge. The provider message was durably queued and claimed exactly once. WA4 Copilot then failed before L4 autonomous authorization/provider dispatch. The bridge correctly requested human handoff and recorded `HANDOFF · WA4_COPILOT_UNAVAILABLE`; no AUTO decision or outbound autonomous message was created.

PR #465 fixed the first discovered defects without timeout inflation: it normalized each eligible derived row once via a per-query MATERIALIZED prepared set and aligned the append-only audit CHECK with the existing `SALES_PLAYBOOK` fail-closed logger. It merged and deployed on exact main `abb6444766cb45116f42c450c1174d339c2b86fc`.

Fresh production certification then used the exact real first-turn phrase under the binding `statement_timeout=3000ms` boundary. That exact proof still returned SQLSTATE `57014` (`canceling statement due to statement timeout`). Therefore v1 is insufficient and the CANARY retry remains blocked. Production source profiling explains the residual cost: about 234 active service rows average ~12.7k characters of derived commercial search text, with additional category rows averaging ~8k characters. Canonical regexp normalization of the entire eligible multi-megabyte corpus once per request remains too expensive under foreground load.

The same observation window also contained transient foreground Call Center/Historial/Panel timeouts near the 3 s boundary. Those are treated as systemic pressure signals, not as evidence that L10 may bypass its own strict first-turn gate.

## Authorized mutable remediation v2 scope

1. Preserve the deployed event-driven L10 bridge, L4 authority and L8 mandatory preflight; no second sender or authority.
2. Add a **cheap per-query candidate prefilter** using case/accent folding without regexp normalization.
3. Perform the existing canonical `aos_wa4a_norm_v1(search_text)` and the original ranking semantics only on the candidate subset.
4. Keep the solution request-scoped: no persistent/global materialized view, no refresh trigger, no polling and no retry loop.
5. Add a production-scale synthetic regression approximating the current service/category text volume and require the exact real first-turn phrase to pass under 3 s.
6. Re-run the original WA4A retrieval/provenance/conflict/ACL suite plus L4-L10 authority/safety regressions.
7. Certify exact head, merge, deploy, apply merged-lineage migration, then repeat the exact strict 3 s proof in PROD.
8. Require a fresh authenticated Meta provider-health `200 / READY` after DB remediation before any new `AUTO_OFF → CANARY` transition.

## Binding invariants

- Production remains `AUTO_OFF`, kill switch engaged, `auto_reply=false`, `ai_send=false`, `auto_routing=false`, `human_send=true` throughout remediation/certification.
- Active L4 allowlist remains zero until the retry gate is explicitly re-armed after all evidence is green.
- No live autonomous provider dispatch during remediation.
- No statement-timeout inflation or bypass of the 3 s exact first-turn proof.
- L4 remains the sole `AUTO_OFF|CANARY|PROD` authority; L8 remains mandatory preflight.
- Human handoff always overrides autonomy.
- No browser-held provider/internal secrets and no raw webhook/message-body/recipient storage in remediation evidence.
- No second sender, browser polling, autonomous retry loop or refresh-driven global materialized analytical hot path.

## Exit boundary

This remediation can close only after exact-head CI, merged Railway/Supabase parity, strict production-scale + exact-PROD first-turn search PASS, authenticated provider-health READY, and a fresh safe readback showing `AUTO_OFF + kill=true + allowlist=0 + AUTO outbound=0`. Only then may the tiny exact-conversation L10 CANARY be re-armed for one fresh real turn. L11/general production stays blocked.
