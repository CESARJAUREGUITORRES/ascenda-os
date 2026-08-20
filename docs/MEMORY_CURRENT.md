# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-08-19 America/Lima  
**GitHub entry baseline:** `main@754ab44f39f10123ab83b98f97b5c01fff25bab5`  
**ACTIVE WORKSTREAM:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.0 — DATA CONTRACT`

## Authority order

1. root `AGENTS.md`;
2. `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. `docs/control/REV_F6_0_DATA_CONTRACT_V1.md`;
6. F6 design contracts under `docs/control/`;
7. exact GitHub CURRENT + Supabase LIVE;
8. fresh CURRENT rows in `aos_memory`;
9. Notion visual continuity.

Historical documents and chat checkpoints never override persisted CURRENT/LIVE.

## Revenue state

- REV-F1 — CLOSED;
- REV-F2 — CLOSED;
- REV-F3 — CLOSED;
- REV-F4 — CLOSED;
- REV-F5 — **PRODUCTION CERTIFIED — 100%**;
- REV-F5 terminal fingerprint — `2f0a365fae4caaa7be9d204e0f76679b`;
- REV-F6 — **ACTIVE**;
- REV-F6.0 Data Contract — **IN PROGRESS**;
- REV-F6.1 Patient Commercial 360 V2 — **BLOCKED until F6.0 PASS**;
- REV-F7 — **BLOCKED until F6 certification**.

## F6.0 certified-entry snapshot

LIVE preflight at the F6.0 entry baseline:

- F5 batches = **6 / 6 MATCHED**;
- source rows = **15,498 / 15,498**;
- identity memberships = **15,498 / 15,498**;
- clusters = **8,716**;
- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- canonical patients = **7,688**;
- sales = **1,299**, range **2026-01-05 → 2026-08-15**;
- sale identity MATCH / REVIEW / UNRESOLVED = **208 / 940 / 151**;
- F3 = **406** facts, **397 RESOLVED / 3 REVIEW_REQUIRED / 6 EXCLUDED / 0 MISSING**;
- F4 = **162** reconciliation rows / **123** linked sales;
- `aos_cia_contact_identity_v1` = **11,796** rows / **7,069** with canonical patient / **23** conflicts;
- Identity Bridge V2 materialized = **false**.

Protected entry fingerprints:

- patients `eee5a57717937a4f77049b3aebd8c525`;
- sales `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 `e3c8499026d13401c4a733b4da16b6c8`;
- F4 `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 `5af139243f6aed37020048af292587fe`;
- F5.8 `4ce1695532a57655179558ed2b5f78aa`;
- F5.9 `5070c701d216eb839572bd70f530c2e6`;
- F5.10 `2f0a365fae4caaa7be9d204e0f76679b`.

## Truth ownership carried into F6

- F3 owns product truth;
- F4 owns payment/revenue/cartera truth;
- F5 owns patient identity + provenance;
- `aos_ventas` is the canonical persisted sales ledger;
- `aos_cia_contact_identity_v1` is compatibility identity only;
- F6 owns derived intelligence/read models only;
- CIA owns governed audience/activation/assignment/channel attribution;
- Sentinel observes integrity and does not silently repair business data.

## Metric Trust contract

Every material F6-derived insight must expose or inherit:

`coverage + confidence + freshness + sample_size`

Never collapse:

- zero observed;
- zero applicable;
- unknown;
- no certified source.

No global average may hide a low-coverage critical domain.

## Historical transaction boundary

- patient history 2024/2025/2026 = AVAILABLE;
- transactional sales 2024 = NO_CERTIFIED_SOURCE;
- transactional sales 2025 = NO_CERTIFIED_SOURCE;
- transactional sales 2026 = available only inside certified current range;
- missing source never means zero sales/revenue;
- unsupported factual YoY remains prohibited.

Future historical sales must follow the existing SHA/provenance → staging → sale → F3 → F5 → F4 → F6 pipeline.

## REV-F6.0 security finding

The F6.0 preflight found a real CRITICAL boundary defect: legacy `public.aos_paciente_360(text)` was SECURITY DEFINER and browser-executable while returning more patient/clinical/document data than the Citas consumer requires.

F6.0 therefore includes a mandatory fail-closed cutover:

- legacy Patient 360 becomes service-role-only and search-path hardened;
- new minimum history summary requires Auth V3 + PASSWORD_2FA + patient-panel permission;
- Citas compatibility is preserved by the production service worker, which injects the existing app token and routes the legacy RPC name to the secure summary;
- no fallback may invoke the weak legacy RPC;
- recovery never reopens browser access;
- protected patient/sales/F3/F4 data must remain byte-identical.

## F6 roadmap

1. F6.0 Data Contract — ACTIVE.
2. F6.1 Patient Commercial 360 V2.
3. F6.2 Customer Lifecycle.
4. F6.3 Identity Confidence + Metric Trust.
5. F6.4 Sales Intelligence 3.0.
6. F6.5 Historical-sales plug-in for certified sources only.
7. F6.6 Sentinel integrity handoff.
8. F6.7 Final certification.

Do not start F6.1 before F6.0 exact-head CI, LIVE persistence/readback, deterministic contract fingerprint, merge and Notion/aos_memory reconciliation all PASS.
