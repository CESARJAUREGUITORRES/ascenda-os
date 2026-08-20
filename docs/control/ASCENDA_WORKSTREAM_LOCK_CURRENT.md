# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Entry main:** `c73b41b318639ef09027956b3c183f8379c42e33`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.5 — Historical Sales Plug-in`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED` · fp `02ba53adb9dabfcd0a4557061be53c2f`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `PASS / CERTIFIED — 100%` · fp `3f4174660107661a2c4509f6f8817d7a`  
**REV-F6.4:** `PASS / CERTIFIED — 100%` · fp `b0f06d841c74ceeb231451aecdeceef2`  
**REV-F6 global:** `62.5%`  
**REV-F6.5:** `IN PROGRESS / PRE-LIVE`  
**REV-F6.6:** `BLOCKED until REV-F6.5 certification`  
**REV-F6.7:** `BLOCKED`  
**REV-F7:** `BLOCKED until REV-F6 final certification`

GitHub CURRENT + Supabase LIVE are authoritative over historical checkpoints. `REV-F6-CLOSEOUT` remains the only HIGH/CRITICAL mutable Revenue lane.

## REV-F6.4 certified boundary

PR #314 merged with expected head `36914e89d6624cc0541774adcff89600fd14537a` to certification `main@5ba6401406812115ee55eb245854331be2ce818e`. Post-merge LIVE reproduced F6.4 fp `b0f06d841c74ceeb231451aecdeceef2`; protected truth remains patients 7,688 / sales 1,299 / F3 406 / F4 162; F6.3 fp remains exact. Post-merge Sales Intelligence V3 performance remained below 1000 ms globally and by both sedes.

## REV-F6.5 entry

F6.5 starts from docs-reconciled `main@c73b41b318639ef09027956b3c183f8379c42e33` on isolated branch `data/rev-f6-5-historical-sales-plugin-20260820`.

No certifiable 2024/2025 transactional files are currently supplied. Therefore:

- no historical revenue may be invented;
- 2024/2025 must remain `value=null` until canonical transaction evidence exists;
- source manifest/SHA proves coverage only, not revenue;
- future ingestion must reuse `aos_ventas` + F3 + F5 + F4, not create parallel masters;
- same SHA replay must be idempotent;
- conflicting SHA-bound metadata must fail closed;
- active Sales Intelligence historical availability must become dynamic, replacing fixed runtime labels;
- recompute may refresh derived read models only and may not ingest/mutate business rows.

## F6.5 implementation contract

Required objects/gates:

- private zero-PII historical source manifest registry;
- dynamic year coverage contract for 2024/2025;
- service-only manifest registration and certification with immutable provenance;
- F6.4 runtime preserved as internal base;
- F6.5 dynamic historical overlay on the active Sales Intelligence V3 name;
- service-only recompute hook;
- fixtures A–J;
- migration replay/idempotency;
- exact F6.4 recovery;
- security + no-PII + `<1000 ms` performance;
- deterministic F6.5 terminal fingerprint;
- LIVE no-source readback before certification.

Until certified:

- `REV-F6.5 = IN PROGRESS`;
- `REV-F6.6/F6.7 = BLOCKED`;
- `REV-F7 = BLOCKED`.
