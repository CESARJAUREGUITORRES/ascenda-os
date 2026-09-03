# WA-L8 — Security Gate for Autonomous Canary

**GitHub authority:** issue `#451`  
**Parent roadmap:** issue `#410`  
**ENTRY baseline:** `main@237eda4099e90b4186037678c90078af0c6af89f`  
**Governance lock:** `main@e57c2c6339134efd79dc71d4e7b0b980b723ea8d`  
**Branch:** `wa-l8-security-gate-20260903`  
**Safety:** `AUTO_OFF · kill switch engaged · autonomous send/reply/routing=false · CANARY NOT AUTHORIZED`

## 1. Objective

WA-L8 adds the security/compliance gate required before any future autonomous canary. It does not authorize or activate CANARY.

Authority chain after L8:

`provider ingress → sanitized evidence → conversation/policy preflight → certified L4 autonomous authority → provider reservation/idempotency → Meta send`

A L8 `PASS` is only a prerequisite. L4 still owns AUTO_OFF/CANARY/PROD mode, kill switch, safety, identity, template verification, allowlists, rate limits, cooldown and duplicate guards.

## 2. Meta 2026 pricing/policy hardening

L8 updates the L7 cost layer without fabricating provider prices.

### Provider pricing evidence

The Meta status webhook normalizer now preserves `pricing.type` in the sanitized immutable `message.status` event payload. It does not add a new enrichment write to the hot message row.

`aos_wa_l8_meta_pricing_evidence_v1` resolves:

- provider message;
- exact conversation;
- business phone number id;
- pricing category/model;
- provider billable flag;
- provider `pricing.type` evidence;
- recipient billing market when deterministically known.

### Market authority

Meta pricing may not use a `GLOBAL` authoritative rate after L8. Current deterministic production scope recognizes Peru telephone recipients as `PE`; non-Peru/unresolved recipients fail closed as `UNMAPPED/UNRESOLVED` until a certified market resolver/rate exists.

AI provider pricing may continue to use `GLOBAL` because it is model/token pricing rather than recipient-market pricing.

### Monthly invoice observability

`aos_wa_l8_meta_monthly_usage_v1` groups realized provider evidence by:

- business phone number id;
- UTC billing month;
- billing market;
- category/model/type;
- provider billable/non-billable counts;
- KNOWN/PARTIAL/UNKNOWN cost events.

The researched 2026 service-message free allowance is **not hard-coded as a VERIFIED production entitlement**. Forecasting that allowance requires account/WABA primary billing evidence. Provider `billable=false` remains authoritative realized `KNOWN 0`.

## 3. Consent / STOP policy gate

`aos_wa_l8_consent_events_v1` is append-only. It stores:

- conversation id;
- recipient kind;
- SHA-256 recipient hash;
- OPT_IN / OPT_OUT;
- evidence source/reference;
- authenticated 2FA administrator provenance.

No raw phone/BSUID is stored in this audit ledger.

`aos_wa_l8_consent_record_v1(...)` requires `admin-whatsapp` + active 2FA authority.

### Autonomous preflight

`aos_wa_l8_autonomous_preflight_v1(...)` uses bounded exact-conversation reads and applies:

1. recipient must match the conversation strong transport identity;
2. current explicit OPT_OUT or latest customer STOP-like signal blocks;
3. within 24 hours of the latest customer inbound, a reply may pass if no active opt-out exists;
4. outside 24 hours, autonomous free-form sends are blocked;
5. outside 24 hours, a provider template still requires explicit evidence-backed OPT_IN;
6. any recipient mismatch becomes HANDOFF.

The latest inbound read is `conversation_id + direction + ORDER BY created_at DESC LIMIT 1`, reusing the certified conversation index. Historical consent state comes from the dedicated indexed consent ledger rather than scanning full message history.

CTWA/free-entry pricing evidence is preserved for billing, but L8 intentionally does not use a 72-hour free-entry window to broaden autonomous-send permission without a separate primary-policy certification.

## 4. L4 wrapping, not replacement

The certified L4 function is renamed internally to:

`aos_wa_l4_authorize_autonomous_send_pre_l8_v1(...)`

The public server-side function name remains:

`aos_wa_l4_authorize_autonomous_send_v1(...)`

The new wrapper performs L8 preflight first. Only a L8 PASS reaches the existing certified L4 authority. Therefore all prior L4 safety invariants remain authoritative.

## 5. Human escalation

The existing provider runtime retains direct `aos_wa3_handoff_request_v1` handling for L4/L8 HANDOFF decisions and provider failures. L8 cannot silently convert a required human escalation into an autonomous send.

## 6. Signed webhook / replay / idempotency

The existing gateway contract remains binding:

- exact raw-body HMAC SHA-256 verification before parsing/persistence;
- deterministic inbound/status event keys;
- provider message idempotency;
- outbound reservation by idempotency key before `graphSend`;
- ambiguous provider outcomes remain PENDING and are not blindly re-sent.

## 7. PII/PHI / AI trace boundary

WA-4 AI run history remains metadata-only. No raw prompt, raw reply or message body column is added.

Conversation history sent to model context uses the existing identifier redactor. Operational gateway logs contain controlled error codes/messages, not raw webhook/message bodies.

Identity/business evidence stored in canonical ledgers remains service-only and is not exposed as browser logs or AI audit traces.

## 8. Selective least privilege

L8 does not perform a blind global RLS rollout.

On the exact autonomous path:

- `aos_wa_messages_v1`: service role keeps runtime-required SELECT/INSERT/UPDATE; destructive/table-management privileges are revoked;
- `aos_wa_outbound_requests_v1`: same runtime boundary;
- `aos_wa_conversations_v1`: service role keeps operational read/write but loses destructive/table-management privileges;
- `aos_wa_ai_runs_v1`: service role is reduced to append/read semantics;
- `aos_booking_operations_v2`: direct service-role DML is removed; certified SECURITY DEFINER booking contracts own writes; service role retains SELECT.

Browser roles receive no direct table write authority.

## 9. Performance / P0 #432

L8 introduces:

- no materialized view;
- no synchronous refresh;
- no trigger on message/AI/booking/Agenda/Sales/Call Center hot ledgers;
- no global analytical read on the send path;
- exact conversation predicates;
- bounded latest-inbound lookup;
- indexed consent/preflight reads;
- cost/pricing enrichment remains outside inbox-list polling.

Dedicated CI uses a 3-second fail-fast statement budget only as a test gate; no production timeout is increased.

## 10. Recovery

Structural recovery is allowed only before L8 consent/preflight history exists.

Once any L8 audit history exists, rollback fails closed with:

`WA_L8_RECOVERY_BLOCKED_AUDIT_HISTORY`

Least-privilege revocations are monotonic security hardening and are intentionally not reopened by structural recovery.

## 11. Production deployment rule

L8 can be certified only after:

1. dedicated exact-head CI passes;
2. L7/L6/L5/L4 and ingress regressions pass;
3. P0 #432 performance/isolation matrix passes;
4. main anti-drift remains clean;
5. exact-head merge occurs;
6. Railway deploy succeeds;
7. exact merged migrations are applied to Supabase PROD;
8. live readback proves objects, privileges and SAFE-OFF state;
9. no autonomous outbound is produced;
10. Notion/governance authorities are synchronized.

## 12. Explicitly out of scope

WA-L8 does not authorize:

- `AUTO_OFF → CANARY`;
- kill-switch disengagement;
- autonomous send/reply/routing;
- live allowlisted autonomous traffic;
- broad marketing/broadcast sends;
- WA-L9/L10 execution.

A future CANARY transition remains a separate explicit owner authorization.
