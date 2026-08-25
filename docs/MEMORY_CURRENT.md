# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-08-25 America/Lima  
**ACTIVE PROGRAM:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT GATE:** `WA-7A.2 — IDENTITY VERIFICATION & CONTINUITY`  
**WA-7A.1 MERGE:** `0bdac2d8e171fbc8883835cb7cfdda0b39339807`  
**WA-7A.1 CERT HEAD:** `ab432ddf5f7b0b8c1be9afb2ba3dfe7e616855b3`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_WA_7A_1_CERTIFICATE.md`;
8. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
9. exact GitHub + Supabase + Railway/runtime evidence when applicable;
10. Notion executive continuity.

Historical chat/doc snapshots never override exact CURRENT + runtime evidence.

## Portfolio state

- REV-F5 — PRODUCTION CERTIFIED 100%.
- REV-F6 — PRODUCTION CERTIFIED 100%.
- REV-F7 — paused while WA owns the mutable lane.
- WhatsApp Revenue Hub V2 — ACTIVE.
- Notifications S13–S15.5 — CLOSED / regression-only.
- CIA, Sentinel, KronIA and unrelated HIGH/CRITICAL work — read-only/regression-only unless strict WA dependency.

## WhatsApp V2 current

- `WA-V2-0` = CLOSED.
- `WA-3` = OFFLINE CERTIFIED / LIVE recovery debt.
- `WA-3.5` = OFFLINE CERTIFIED 100% / LIVE recovery debt.
- `WA-7A.0` = CLOSED at demonstrated identity-compatibility boundary.
- `WA-7A.1` = CLOSED at CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK boundary.
- `WA-7A.2` = ACTIVE MUTABLE LOCK.
- `WA-7A.3/4` = blocked behind sequential closeout.
- WA-4 existing infrastructure remains SAFE-OFF and does not certify WA-4A/B/C.

## WA-7A.1 necessity result

ASCENDA already had canonical identity authority in REV/F5/F6. WA-7A.1 therefore did not create a new CRM/customer/person master.

Reused:

- `aos_pacientes.ID_PACIENTE` as canonical subject;
- `aos_rev_patient_identity_alias_v2` for governed exact aliases/candidate/conflict/confidence evidence;
- F5 reviewed evidence through the REV bridge;
- WA-7A.0 `aos_wa_channel_aliases_v1` for PHONE/BSUID/PARENT_BSUID conversation continuity.

Added only:

- private view `aos_wa_identity_resolution_v1`;
- permission-gated read RPC `aos_wa7a1_resolve_conversation_identity_v1`;
- Zero-Cost behavioral and rollback tests.

Resolution semantics:

`WA conversation → active PHONE evidence → REV → MATCH | UNRESOLVED | IDENTITY_CONFLICT`.

BSUID/username do not independently resolve a canonical patient. Genuine BSUID-only without corroborating canonical evidence remains unresolved. Conflicting PHONE evidence fails closed.

## Certification evidence

PR #375 exact head: `ab432ddf5f7b0b8c1be9afb2ba3dfe7e616855b3`.

Merge: `0bdac2d8e171fbc8883835cb7cfdda0b39339807`.

Exact-head:

- WA-7A.1 run `32903271309` = SUCCESS;
- Ascenda CI run `32903271282` = SUCCESS.

Production migration applied as `wa7a1_identity_resolution_bridge_v1`.

Production readback:

- messages = 21 preserved;
- conversations = 2;
- active PHONE aliases = 2;
- active BSUID aliases = 0;
- identity resolution = 2 UNRESOLVED / 0 MATCH / 0 CONFLICT;
- canonical candidates = 0;
- raw aliases exposed by bridge = 0;
- direct anon/authenticated bridge reads = denied;
- invalid token returns `WA_2FA_PANEL_REQUIRED`.

The current unresolved state is correct because neither WA PHONE alias currently has an exact governed canonical match in REV. No patient was fabricated.

WA-7A.1 changed no runtime/server/frontend file; Railway is N/A as a phase gate.

## Production hold

Supabase SQL management works but REST/Auth still returns HTTP 402 on real API traffic.

Therefore fresh browser/Auth/provider/Meta/BSUID canaries remain external debt. No auth/service-role bypass is allowed to manufacture LIVE certification.

Safety remains:

- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` preserved as pre-existing governed canary state.

## WA-7A.2 next execution

Goal: preserve identity continuity and verification evidence when WhatsApp identifiers/contact facts change, while reusing WA-7A.0 aliases + WA-7A.1 REV bridge.

First loop:

1. revalidate exact CURRENT and lock;
2. discover current provider/Meta contracts for identifier updates, parent BSUID, contact-info request, contact-share origin, recipient user identity and Contact Book;
3. audit existing ASCENDA source/verification metadata before adding schema;
4. run necessity gate/evidence matrix;
5. build minimum old→new BSUID lineage and phone-source/verification contracts only where missing;
6. preserve `VERIFIED / CLAIMED / UNKNOWN / CONFLICT` and evidence timestamps;
7. test replay/idempotency/concurrency/conflict/no destructive overwrite;
8. exact-head Zero-Cost CI;
9. anti-drift;
10. production apply/readback only when safe;
11. merge expected head;
12. Railway only if runtime changed;
13. GitHub CURRENT;
14. Notion LAST;
15. advance to WA-7A.3 only after closeout.

Hard rules: typed/manual phone is not VERIFIED automatically; username is not identity; no canonical overwrite; no Attribution/Ads Sync/AI/campaign expansion in WA-7A.2.
