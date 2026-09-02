# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-02 America/Lima  
**Canonical entry baseline:** `main@943e93333d31a25cdbd102ce5332b0412a6e7489`  
**ACTIVE HIGH/CRITICAL LOCK:** `REV-F5.11 — Historical Patient Identity Completion 2024–2026`  
**GitHub authority:** Issue `#441`  
**WhatsApp authority:** `HOLD / SAFE-OFF`; WA-L4 implementation does not own the mutable lock while REV-F5.11 is active.

## Why this lock exists

The six certified historical patient exports for San Isidro and Pueblo Libre, years 2024/2025/2026, are fully preserved in F5 staging but the original F5 classification intentionally left most ambiguous identities uncommitted. The owner has authorized completing only the deterministic identity subset now so historical phone/email/document evidence can support future patient/customer resolution.

Transactional sales 2024/2025 are explicitly out of scope. `aos_ventas` remains governed by its independently certified source boundary.

## Certified entry truth

- P0 `#436` Patient 360 runtime incident = **CLOSED** after owner smoke.
- Patient 360 hot path/enrichment split = production deployed.
- Filiación Teléfono/Correo = production deployed and owner-verified.
- Historical source batches = **6/6 MATCHED**.
- Historical source rows = **15,498 / 15,498**.
- Identity memberships = **15,498 / 15,498**.
- Historical identity clusters = **8,716**.
- Original F5 classification = **296 MATCH / 6,984 REVIEW / 1,436 NEW**.
- Current `aos_pacientes` at entry readback = **7,737 total / 7,311 non-FUSIONADO / 426 FUSIONADO**.
- Historical phone/email/document remain provenance; no mass contact overwrite was certified.
- Transactional sales 2024 = `NO_CERTIFIED_SOURCE`.
- Transactional sales 2025 = `NO_CERTIFIED_SOURCE`.

## REV-F5.11 mutation boundary

Allowed:
1. create a governed resolution overlay over immutable F5 clusters;
2. resolve an historical cluster to an existing **current non-FUSIONADO** patient only with deterministic strong evidence;
3. preserve historical phone/email/document as aliases/provenance;
4. create deterministic `P-HIST-F511-*` patients only for high-confidence NEW identities with DNI8 + second signal, repeated coherent evidence, and no current collision;
5. keep identity-vs-attribute conflicts explicit;
6. produce exact coverage and an idempotent audit ledger.

Forbidden:
- merge by name alone;
- merge/link by phone alone;
- fuzzy/numeric-neighbor phone matching;
- overwrite any existing canonical phone/email/document/name;
- silently discard conflicts;
- mutate/import 2024/2025 transactional sales;
- create a second patient master;
- enable WhatsApp autonomous sending/routing while this lock is active.

## Exit gates

REV-F5.11 may close only after:
1. deterministic preview covers every certified F5 cluster/source row;
2. exact-head CI proves safe branches and fail-closed branches;
3. migration + replay + recovery pass in isolated PostgreSQL;
4. LIVE preview fingerprint/count is captured before apply;
5. LIVE canary/recovery evidence passes;
6. governed batch apply preserves the fingerprint of all pre-existing canonical patient identity fields;
7. new patient count equals the certified `NEW_SAFE` preview exactly;
8. every resolved alias points only to a current non-FUSIONADO patient and conflicts remain explicit;
9. no 2024/2025 sale row is introduced;
10. post-apply source coverage remains 15,498/15,498 and residual REVIEW is quantified;
11. GitHub + Notion + CURRENT control are reconciled.

Only after those gates may the HIGH/CRITICAL lock return to WhatsApp (`WA-L4`, still AUTO_OFF until its own authorization gates).
