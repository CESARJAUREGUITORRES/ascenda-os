# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-04 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L10 #456 — FIRST REAL TURN FAIL-CLOSED REMEDIATION`  
**GitHub authority:** Issue `#456` = `OPEN / ACTIVE`  
**Parent roadmap:** Issue `#410`  
**Exact entry main:** `525975bb819ace54fe0af334bec584c208b98784`  
**Active branch:** `wa-l10-first-turn-db-hotpath-fix-20260904`  
**Deployed L10 layer:** `PR #464 · event-driven autonomous canary bridge`  
**Current production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**Active L4 allowlist:** `0`  
**Prior L10 CANARY authorization:** `CONSUMED BY FIRST-TURN ATTEMPT; RE-ACTIVATION SUSPENDED PENDING FRESH EVIDENCE`  
**Authorization ref:** `OWNER-CHAT-20260904-L10-ZIVITAL-CANARY`  
**L11/general PROD:** `NOT AUTHORIZED`

## First real turn result

The exact Zi Vital test conversation produced a valid Meta inbound and entered the deployed L10 bridge. The provider message was durably queued and claimed exactly once. WA4 Copilot then failed before L4 autonomous authorization/provider dispatch. The bridge correctly requested human handoff and recorded `HANDOFF · WA4_COPILOT_UNAVAILABLE`; no AUTO decision or outbound autonomous message was created.

The corresponding `aos_wa_ai_runs_v1` row records `SALES_COPILOT · ERROR · FAIL_CLOSED · WA4_DB_UNAVAILABLE` with ~10.6 s latency. PostgreSQL logs at the same first-turn timestamp contain two `statement timeout` cancellations. A bounded read-only reproduction under a stricter 3 s limit identified the hot path in `aos_wa4a_knowledge_search_v1`, where the same derived `search_text` is repeatedly normalized inside phrase and per-token predicates. A second audit defect was exposed: WA4 intentionally logs a `SALES_PLAYBOOK` fail-closed event, but the current `aos_wa_ai_runs_v1_task_check` only accepts `SALES_COPILOT|MODEL_EVAL`.

Per the predeclared canary rollback rule, production was immediately returned to `AUTO_OFF`, kill switch engaged, autonomous reply/send disabled, and the exact conversation allowlist disabled. The conversation remains `HUMAN_REQUESTED`. An authenticated `/api/wa3/provider-health` call subsequently returned HTTP 502, so provider readiness must also return to explicit READY before any retry.

## Authorized mutable remediation scope

1. Preserve the deployed event-driven L10 bridge and its fail-closed human boundary; do not add a second sender or authority.
2. Replace repeated WA4A derived-row normalization with a bounded per-query materialized prepared set so each eligible title/search text is normalized once while preserving ranking/authority semantics.
3. Align `aos_wa_ai_runs_v1_task_check` with the existing `SALES_PLAYBOOK` fail-closed logger so the audit path cannot fail while reporting a primary error.
4. Add regression gates proving no timeout inflation, no global materialized-view refresh path, no CANARY activation side effect, and preservation of the L4/L8 authority boundary.
5. Certify exact head, merge, deploy, apply merged-lineage migration, then run a strict bounded production read-only knowledge-search proof.
6. Re-run authenticated Meta provider-health and require HTTP 200 / `diagnosis=READY`.
7. Present the complete repaired evidence before any fresh `AUTO_OFF → CANARY` retry. Do not silently reuse the failed activation.

## Binding invariants

- Production remains `AUTO_OFF`, kill switch engaged, `auto_reply=false`, `ai_send=false`, `auto_routing=false`, `human_send=true` throughout remediation/certification.
- Active L4 allowlist remains zero until a separately reviewed retry gate.
- No live autonomous provider dispatch during remediation.
- No statement-timeout inflation or bypass of the 3 s bounded first-turn proof.
- L4 remains the sole `AUTO_OFF|CANARY|PROD` authority; L8 remains mandatory preflight.
- Human handoff always overrides autonomy.
- No browser-held provider/internal secrets, no raw webhook/message-body/recipient storage in remediation evidence.
- No second sender, browser polling, autonomous retry loop, or refresh-driven global materialized analytical hot path.

## Exit boundary

This remediation can close only after exact-head CI, merged Railway/Supabase parity, strict bounded WA4A first-turn search PASS, authenticated provider-health READY, and a fresh safe readback showing `AUTO_OFF + kill=true + allowlist=0 + AUTO outbound=0`. A new real CANARY retry remains a separate go/no-go after that evidence. L11/general production stays blocked.
