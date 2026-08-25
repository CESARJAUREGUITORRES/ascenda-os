# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Captured:** 2026-08-25 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**WA-7A.1 merge:** `0bdac2d8e171fbc8883835cb7cfdda0b39339807`  
**WA-7A.1:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE MUTABLE SUBPHASE:** `WA-7A.2 — Identity Verification & Continuity`  
**LIVE hold:** Supabase REST/Auth HTTP 402

## Current phase state

- `WA-V2-0 — Baseline & Governance` = **CLOSED**.
- `WA-3 — Human Operations Multiagent` = **OFFLINE CERTIFIED / LIVE recovery debt**.
- `WA-3.5 — Revenue Inbox UX` = **OFFLINE CERTIFIED 100% / LIVE recovery debt**.
- `WA-7A.0 — Identity Compatibility` = **CLOSED at CODE/CI/ZERO-COST/PROD-SCHEMA/PHONE-COMPAT boundary**.
- `WA-7A.1 — Identity Resolution` = **CLOSED at CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK boundary**.
- `WA-7A.2 — Identity Verification & Continuity` = **ACTIVE NEXT MUTABLE SUBPHASE**.
- `WA-7A.3 — Attribution Ingress` = blocked behind WA-7A.2.
- `WA-7A.4 — Marketing Eligibility Foundation` = blocked behind WA-7A.3.
- WA-4A/B/C, WA-5, WA-6, WA-7B/C/D, WA-8, WA-9..14 remain later roadmap.

## WA-7A.1 decision

The necessity gate demonstrated that ASCENDA already has the required canonical identity authority in REV/F5/F6. WA therefore did not create another CRM, person table or customer master.

Canonical resolution path:

`WhatsApp conversation → active PHONE/BSUID alias context → governed PHONE evidence → REV Patient Identity Bridge V2 → MATCH | UNRESOLVED | IDENTITY_CONFLICT`.

BSUID preserves WhatsApp channel continuity but does not become `canonical_patient_id` by itself. Username remains display-only.

## WA-7A.1 delivered

PR `#375` merged from exact head `ab432ddf5f7b0b8c1be9afb2ba3dfe7e616855b3` into `0bdac2d8e171fbc8883835cb7cfdda0b39339807`.

Added only:

- private derived view `aos_wa_identity_resolution_v1`;
- permission-gated read RPC `aos_wa7a1_resolve_conversation_identity_v1`;
- Zero-Cost behavior/rollback coverage;
- evidence/necessity documentation.

No application runtime file changed. No `aos_pacientes`, F5 classification or REV canonical object is mutated by the bridge.

## Exact-head gates

At `ab432ddf5f7b0b8c1be9afb2ba3dfe7e616855b3`:

- `ASCENDA WA-7A.1 Identity Resolution` run `32903271309` = **SUCCESS**;
- `Ascenda CI` run `32903271282` = **SUCCESS**.

The dedicated gate passed PHONE+BSUID, BSUID-only continuity, genuine BSUID-only unresolved, REV ambiguity/conflict, multi-PHONE canonical conflict, duplicate prevention, privacy boundary, WA-7A.0 regression and rollback/reapply.

## Production readback

Supabase migration `wa7a1_identity_resolution_bridge_v1` is applied.

Current production resolution:

- conversations = `2`;
- `UNRESOLVED = 2`;
- `MATCH = 0`;
- `IDENTITY_CONFLICT = 0`;
- active PHONE aliases = `2`;
- active BSUID aliases = `0`;
- canonical candidates = `0`;
- messages preserved = `21`.

This result is correct. The two current WhatsApp PHONE aliases do not have exact governed canonical matches in REV. WA-7A.1 does not fabricate patients or use fuzzy/username matching to force a result.

Security/read boundary:

- raw phone/BSUID/username/REV identifier columns exposed by the bridge = `0`;
- direct view SELECT for anon/authenticated = denied;
- service-role view read = allowed;
- public RPC transport remains internally guarded by WA Auth V3/2FA plus patient permissions;
- invalid-token verification returned `WA_2FA_PANEL_REQUIRED`.

## Runtime / Railway

WA-7A.1 contains no runtime/server/frontend change. Railway is therefore **N/A as a WA-7A.1 phase gate**. Production impact is database-derived only.

## Current external blocker

Supabase SQL management works, but REST/Auth continues returning HTTP 402 on real ASCENDA API traffic.

Therefore:

- fresh authenticated UI smoke cannot be certified;
- fresh Meta/provider/BSUID canary remains blocked;
- no service-role/Auth bypass is allowed;
- `WA-7A.1 LIVE END-TO-END CERTIFIED 100% = NO` while this external blocker remains.

## Preserved safety

- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` remains pre-existing governed canary state and was not widened;
- signed webhook, replay/idempotency, Auth V3/2FA, ownership and assignment authority remain unchanged.

## NEXT — WA-7A.2

Identity Verification & Continuity must now determine only how identifier changes and contact disclosures are evidenced and preserved:

- old→new BSUID lineage/provider update events;
- optional parent-BSUID evidence;
- `REQUEST_CONTACT_INFO` / contact-share origin;
- phone source and verification state;
- `VERIFIED / CLAIMED / UNKNOWN / CONFLICT`;
- no destructive overwrite;
- no typed/manual phone auto-verification;
- no username identity authority;
- reuse the WA-7A.1 bridge and REV canonical identity; do not create a new customer master.

Authoritative certificate: `docs/control/WHATSAPP_REVENUE_HUB_WA_7A_1_CERTIFICATE.md`.
Authoritative roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.
Authoritative lock: `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.
