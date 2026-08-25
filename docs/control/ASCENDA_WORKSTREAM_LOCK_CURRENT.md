# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-25 America/Lima  
**WA-7A.1 merge:** `0bdac2d8e171fbc8883835cb7cfdda0b39339807`  
**WA-7A.1:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE LOCK:** `WA-7A.2 — IDENTITY VERIFICATION & CONTINUITY`

## Owner directive

Continue WhatsApp Revenue Hub with at most one HIGH/CRITICAL mutable workstream at a time.

**Only WA-7A.2 is mutable now.** Other HIGH/CRITICAL workstreams remain read-only/regression-only unless WA-7A.2 proves a strict dependency.

## Preserved portfolio state

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- Notifications S13–S15.5 = CLOSED / regression-only.
- CIA, Sentinel, KronIA and unrelated product/data work = read-only/regression-only unless strict dependency.

## WA-7A.0 preserved

WA-7A.0 owns PHONE/BSUID/PARENT_BSUID transport compatibility, generic recipients, alias continuity and channel-identity conflict handling. PHONE remains backward compatible. Fresh provider/BSUID LIVE recertification remains external debt while Supabase REST/Auth is HTTP 402.

## WA-7A.1 handoff

WA-7A.1 proved that ASCENDA does **not** need a new CRM/customer/person master for WhatsApp identity resolution.

Canonical authority remains REV/F5/F6. The minimal bridge is:

`WA conversation + active aliases → governed PHONE evidence → REV Patient Identity Bridge V2 → MATCH | UNRESOLVED | IDENTITY_CONFLICT`.

Delivered:

- private view `aos_wa_identity_resolution_v1`;
- gated RPC `aos_wa7a1_resolve_conversation_identity_v1`;
- no canonical mutation;
- no username merge authority;
- no BSUID→person direct mapping;
- conflicts fail closed;
- Zero-Cost rollback/reapply coverage.

Production readback after apply:

- 2 WA conversations;
- 2 PHONE aliases;
- 0 real BSUID aliases currently;
- 2 `UNRESOLVED` canonical resolutions;
- 0 fabricated MATCH;
- 0 identity conflicts;
- 21 messages preserved;
- 0 raw alias columns exposed by the bridge.

The two current conversations correctly remain unresolved because their existing PHONE aliases do not have an exact governed canonical match in REV.

## WA-7A.2 — allowed mutations

May discover/build only what is necessary to preserve WhatsApp identity continuity and verification evidence when provider identifiers/contact facts change.

Allowed discovery:

- current `user_id_update` / provider-equivalent events;
- old/current BSUID and parent-BSUID semantics;
- `REQUEST_CONTACT_INFO` and contact-share origin;
- typed/manual/CRM/import/form/lead-ad phone source;
- provider status evidence such as recipient user identity when contractually reliable;
- Contact Book behavior only as provider-side assistance;
- current alias ledger/REV bridge reuse.

Allowed implementation when necessary:

- old→new BSUID lineage/supersession;
- contact source metadata;
- `VERIFIED / CLAIMED / UNKNOWN / CONFLICT` verification state;
- immutable evidence/timestamps;
- reversible functions/schema strictly necessary for continuity;
- tests for replay/idempotency/concurrency/conflict/no destructive overwrite.

Must not:

- create a parallel customer/person master;
- overwrite canonical patient facts silently;
- mark typed/manual phone as VERIFIED automatically;
- resolve identity from username;
- treat Contact Book as canonical identity;
- infer attribution from identity facts;
- broaden into WA-7A.3 Attribution before WA-7A.2 closes;
- build Ads Sync before WA-7B;
- activate AI send, auto-reply or auto-routing.

## Mandatory identity invariants

- phone remains nullable for WhatsApp;
- BSUID remains a scoped channel alias, not canonical person id;
- identifier changes preserve lineage instead of destructive overwrite;
- PHONE disclosure is evidence, not automatic ownership proof;
- canonical identity remains governed by REV/F5/F6;
- channel identity and acquisition touchpoint remain separate;
- unresolved and conflict states are valid fail-closed outcomes.

## Safety state

Preserve:

- signed Meta gateway;
- replay/idempotency;
- Auth V3/2FA;
- explicit whatsapp-agent authorization;
- exact-owner send and active assignment requirement;
- queue privacy/claim/reassign/release;
- customer 24h window;
- canary allowlist;
- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`.

`human_send=true` is a pre-existing governed canary state and must not be widened by WA-7A.2.

## External LIVE hold

Supabase SQL management access works, but REST/Auth remains HTTP 402. Do not interpret SQL access as full Cloud recovery.

Forbidden:

- auth bypass;
- service-role substitution for user/session canaries;
- blind provider retries;
- synthetic LIVE claims from historical provider evidence.

## Lock transition rule

WA-7A.2 remains the sole mutable HIGH/CRITICAL lane until its scoped closeout is certified. Only then may the lock advance to `WA-7A.3 — Attribution Ingress`.
