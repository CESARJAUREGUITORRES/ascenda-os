# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-19 America/Lima  
**Entry baseline:** `main@754ab44f39f10123ab83b98f97b5c01fff25bab5`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F5.10 terminal fingerprint:** `2f0a365fae4caaa7be9d204e0f76679b`  
**CURRENT GATE:** `REV-F6.0 — DATA CONTRACT / IN PROGRESS`  
**REV-F6.1:** `BLOCKED until REV-F6.0 PASS`  
**REV-F7:** `BLOCKED until REV-F6 certification`

This is the single mutable Revenue execution pointer. GitHub CURRENT + Supabase LIVE remain authoritative over historical checkpoints.

## One-lock rule

At most one HIGH/CRITICAL mutable workstream may alter shared Revenue/current-state contracts. While `REV-F6-CLOSEOUT` owns the lane, other HIGH/CRITICAL workstreams remain read-only/regression/documentation-only unless explicitly required by F6 validation.

## Certified upstream boundary

REV-F1 through REV-F5 are closed. REV-F6 must preserve these truth owners:

- F3 = canonical product truth;
- F4 = payment/revenue/cartera truth;
- F5 = patient identity + provenance truth;
- `aos_ventas` = canonical persisted sales ledger;
- `aos_cia_contact_identity_v1` = compatibility identity view only;
- F6 = derived intelligence/read models only.

Protected F5 state at F6.0 entry:

- patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 fp = `5af139243f6aed37020048af292587fe`;
- F5.8 fp = `4ce1695532a57655179558ed2b5f78aa`;
- F5.9 fp = `5070c701d216eb839572bd70f530c2e6`;
- F5.10 terminal fp = `2f0a365fae4caaa7be9d204e0f76679b`.

## REV-F6.0 entry snapshot

- source batches = **6 / 6 MATCHED**;
- source rows / memberships = **15,498 / 15,498**;
- clusters = **8,716**;
- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- sales = **1,299**, range **2026-01-05 → 2026-08-15**;
- sale identity MATCH / REVIEW / UNRESOLVED = **208 / 940 / 151**;
- F3 RESOLVED / REVIEW_REQUIRED / EXCLUDED / MISSING = **397 / 3 / 6 / 0**;
- F4 linked sales = **123 / 1,299**;
- `aos_cia_contact_identity_v1` = **11,796 rows**, **7,069** with canonical patient, **23** conflicts;
- Identity Bridge V2 is **contract-frozen but not materialized LIVE**.

## REV-F6.0 security gate

Preflight found legacy `aos_paciente_360(text)` exposed to browser roles under `SECURITY DEFINER` while returning more patient/clinical/document data than Citas consumes. F6.0 therefore cannot close until:

- browser EXECUTE on legacy Patient 360 is revoked;
- its search path is hardened;
- Citas legacy call is routed by the production service worker to a minimum Auth V3 + PASSWORD_2FA summary;
- no fallback reopens the legacy path;
- recovery remains fail-closed;
- protected business domains show zero mutation.

## Metric Trust boundary

All relevant F6-derived insights must expose or inherit:

`coverage + confidence + freshness + sample_size`

No-source, zero-observed, not-applicable and unknown states remain distinct. Unsupported 2024/2025 transactional YoY remains prohibited.

## REV-F6 roadmap

1. **F6.0 Data Contract** — ACTIVE.
2. F6.1 Patient Commercial 360 V2 — blocked until F6.0 PASS.
3. F6.2 Customer Lifecycle.
4. F6.3 Identity Confidence + Metric Trust.
5. F6.4 Sales Intelligence 3.0.
6. F6.5 Historical-sales plug-in, only for certified sources.
7. F6.6 Sentinel Data Integrity handoff.
8. F6.7 Final certification.

`REV-F6-CLOSEOUT` remains assigned until F6.7 or an explicit owner handoff. F6.0 completion does not release the global Revenue F6 lane.
