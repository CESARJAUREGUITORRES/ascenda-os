# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L8 — Security Gate for Autonomous Canary`  
**GitHub authority:** Issue `#451` = `OPEN / ACTIVE`  
**ENTRY baseline:** `main@237eda4099e90b4186037678c90078af0c6af89f`  
**Parent roadmap:** Issue `#410`  
**Previous closed lane:** `WA-L7 — WhatsApp/AI Cost Intelligence`  
**Effective production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**CANARY:** `NOT AUTHORIZED` — separate explicit owner authorization required.

## WA-L8 scope

L8 is the sole mutable HIGH/CRITICAL lane. It must harden only the autonomous WhatsApp/Agenda path and must not introduce broad blind RLS/security churn across unrelated modules.

Required exit contract:

- Meta 2026 pricing/policy preflight hardening without synthetic/unverified production pricing;
- persist provider pricing/free-entry evidence required for explainable billing;
- market-aware provider pricing resolution and business-phone/monthly free-tier observability;
- selective RLS/privilege hardening for WhatsApp/Agenda objects touched by the autonomous path;
- browser/direct writes revoked where governed server/RPC boundaries already exist;
- Meta webhook signature + replay/idempotency checks remain mandatory;
- provider/runtime secrets remain server-only;
- PII/PHI-safe operational logs and AI traces;
- explicit opt-in/opt-out/STOP evidence for business-initiated messaging;
- direct, auditable human escalation remains available;
- dedicated L8 CI plus L7/L6/L5/L4 and P0 #432 cross-module regressions;
- exact-head CI, anti-drift, merge, Railway, Supabase PROD readback before L8 closeout.

## Binding Meta 2026 policy evidence

Reviewed 2026-09-03:

- WhatsApp Business Messaging Policy permits automated replies inside the 24-hour service window only when timely, clear and direct escalation paths are available;
- WhatsApp Business Solution Terms dated 2026-03-06 permit an AI provider as a third-party service provider but prohibit using WhatsApp Business Solution Data to create/train/improve general AI models outside the stated exclusive-use exception;
- updated WhatsApp-for-Business terms take effect 2026-09-23.

These are compliance gates, not autonomy authorization.

## Retained P0 #432 doctrine

- no heavy global analytical views on synchronous hot paths;
- no synchronous materialized-view refresh/rebuild on message/call/booking/sales writes;
- no timeout inflation used to hide query defects;
- bounded/indexed reads;
- no duplicate legacy/new generation;
- browser fan-out governed;
- enrichment/cold path isolated from operational hot path;
- mandatory cross-module regressions: Agenda + Call Center + Marketing + Sales/Commissions + Patients/Identity + shared Supabase/background;
- CODE PASS ≠ DEPLOY PASS ≠ PROD PASS.

## Previous WA-L7 closeout retained

WA-L7 remains `CLOSED · PRODUCTION CERTIFIED · DORMANT / SAFE-OFF`.

- issue `#449` = CLOSED/completed;
- certified exact-head `1ea6a4f61c1e03a38e902aefc7ad6f74efbfb109`;
- merge `41c25a6a54d0043b6f0f7a679677942968fe6566`;
- Supabase PROD migration `20260903182220 · wa_l7_cost_intelligence_v1`;
- Railway SUCCESS;
- no synthetic pricing rows inserted;
- provider `billable=false` remains authoritative `KNOWN 0`;
- pricing authority remains effective-dated and fail-closed when a verified rate is missing.

## Explicitly outside L8 authority

L8 does **not** authorize:

- `AUTO_OFF → CANARY`;
- kill-switch disengagement;
- autonomous reply/send/routing;
- live allowlisted autonomous traffic;
- bulk sends/broadcasts;
- WA-L9 or WA-L10 execution.

The next transition after a certified L8 remains a separate owner decision.
