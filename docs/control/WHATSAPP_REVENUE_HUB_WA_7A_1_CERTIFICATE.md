# WA-7A.1 — Identity Resolution — Certificate

**Captured:** 2026-08-25 America/Lima  
**PR:** `#375`  
**Exact cert head:** `ab432ddf5f7b0b8c1be9afb2ba3dfe7e616855b3`  
**Merge:** `0bdac2d8e171fbc8883835cb7cfdda0b39339807`  
**Status:** `CLOSED AT DEMONSTRATED BOUNDARY`

## Purpose

Connect WhatsApp channel alias evidence to ASCENDA's existing canonical patient identity without creating a second CRM, customer master or merge authority.

## Necessity gate result

No new identity engine was required.

Existing canonical authority reused:

- `aos_pacientes.ID_PACIENTE` as canonical patient subject;
- REV/F5/F6 Patient Identity Bridge V2;
- `aos_rev_patient_identity_alias_v2` for governed PHONE aliases, candidates, status, evidence and confidence;
- WA-7A.0 `aos_wa_channel_aliases_v1` for PHONE/BSUID/PARENT_BSUID conversation continuity.

WA-7A.1 added only the missing projection:

`WhatsApp conversation + active channel aliases → governed PHONE evidence → REV identity authority → MATCH | UNRESOLVED | IDENTITY_CONFLICT`.

## Added production objects

- private derived view `aos_wa_identity_resolution_v1`;
- Auth/2FA and patient-permission gated RPC `aos_wa7a1_resolve_conversation_identity_v1(text,uuid)`.

No person/customer/patient table was created. No `aos_pacientes`, F5 classification or REV canonical record is mutated by WA-7A.1.

## Identity semantics

- username never resolves canonical identity;
- BSUID is not a universal person id;
- pure BSUID-only without corroborating canonical evidence remains `UNRESOLVED`;
- a BSUID-only later message may retain canonical continuity when the same WA conversation already owns governed historical PHONE evidence;
- REV conflict remains `IDENTITY_CONFLICT`;
- multiple active PHONE aliases on one WA conversation resolving to different patients remain `IDENTITY_CONFLICT`;
- no conflict performs a silent merge.

## Exact-head CI

At `ab432ddf5f7b0b8c1be9afb2ba3dfe7e616855b3`:

- `ASCENDA WA-7A.1 Identity Resolution` run `32903271309` = **SUCCESS**;
- `Ascenda CI` run `32903271282` = **SUCCESS**.

The dedicated Zero-Cost gate passed:

- authority/source invariants;
- isolated Supabase setup;
- PHONE+BSUID resolution;
- BSUID-only continuity;
- genuine BSUID-only unresolved behavior;
- REV ambiguity/conflict fail-closed;
- multi-PHONE canonical conflict;
- duplicate prevention;
- raw alias privacy boundary;
- WA-7A.0 regression;
- rollback and reapply.

## Production apply/readback

Migration registered in Supabase as `wa7a1_identity_resolution_bridge_v1`.

Post-apply readback:

- identity-resolution rows = `2`;
- `UNRESOLVED = 2`;
- `MATCH = 0`;
- `IDENTITY_CONFLICT = 0`;
- active PHONE aliases = `2`;
- active BSUID aliases = `0`;
- canonical candidates = `0`;
- messages remain `21`;
- conversations remain `2`;
- raw phone/BSUID/username/identifier-key columns exposed by the bridge = `0`;
- direct view SELECT: anon=`false`, authenticated=`false`, service_role=`true`;
- invalid-token RPC call returns `WA_2FA_PANEL_REQUIRED`;
- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` remains the pre-existing governed state and was not widened.

The two existing conversations correctly remain `UNRESOLVED`: current WA PHONE aliases do not have an exact governed canonical match in REV. WA-7A.1 deliberately does not create patients to force a match.

## Runtime / Railway

WA-7A.1 contains no application/runtime JavaScript or server topology change. Railway deployment is therefore **N/A as a phase gate**; the production mutation is DB-only plus CI/documentation.

## LIVE boundary

Supabase REST/Auth continues HTTP 402. Therefore fresh browser/Auth/provider/Meta/BSUID behavior is not certified and no service-role or 2FA bypass is permitted.

`WA-7A.1 LIVE/PRODUCTION END-TO-END CERTIFIED 100% = NO` while that external gate remains.

`WA-7A.1 CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK = CLOSED`.

## Handoff

**NEXT MUTABLE LOCK:** `WA-7A.2 — Identity Verification & Continuity`.

WA-7A.2 must reuse this bridge and focus only on identifier change/contact disclosure lineage and verification evidence. It must not reopen canonical identity ownership or create a parallel customer master.
