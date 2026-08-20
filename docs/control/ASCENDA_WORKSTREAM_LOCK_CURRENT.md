# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Certification main:** `5ba6401406812115ee55eb245854331be2ce818e`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.5 — Historical Sales Plug-in`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED` · fp `02ba53adb9dabfcd0a4557061be53c2f`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `PASS / CERTIFIED — 100%` · fp `3f4174660107661a2c4509f6f8817d7a`  
**REV-F6.4:** `PASS / CERTIFIED — 100%` · fp `b0f06d841c74ceeb231451aecdeceef2`  
**REV-F6 global:** `62.5%`  
**REV-F6.5:** `NEXT / UNBLOCKED`  
**REV-F6.6:** `BLOCKED until REV-F6.5 certification`  
**REV-F6.7:** `BLOCKED`  
**REV-F7:** `BLOCKED until REV-F6 final certification`

GitHub CURRENT + Supabase LIVE are authoritative over historical checkpoints. `REV-F6-CLOSEOUT` remains the only HIGH/CRITICAL mutable Revenue lane.

## REV-F6.4 terminal certification

PR **#314** merged with exact expected head `36914e89d6624cc0541774adcff89600fd14537a` to certification `main@5ba6401406812115ee55eb245854331be2ce818e` after exact-head SUCCESS for Ascenda CI and REV-F6.0 through REV-F6.4.

Supabase LIVE:

- migrations `20260820191924`, `20260820192121`, `20260820192333` applied;
- F6.4 terminal fingerprint `b0f06d841c74ceeb231451aecdeceef2` reproduced twice post-merge;
- F6.3 fingerprint remains `3f4174660107661a2c4509f6f8817d7a`;
- patients **7,688**;
- sales **1,299**;
- F3 **406**;
- F4 **162**;
- dashboard cache **22** governed filter combinations;
- 2026 certified transactions **1,299**, billed amount **561889.27**;
- 2024/2025: `hasData=false`, `value=null`, `source_status=NO_CERTIFIED_SOURCE`.

Post-merge performance:

- global: **97.29 ms**;
- San Isidro: **4.09 ms**;
- Pueblo Libre: **4.32 ms**;
- certification target: **<1000 ms**.

Security remains fail-closed: raw Sales Intelligence read models/cache are browser-closed; internal V3 is not anon executable; refresh is not authenticated executable; governed gateway remains available; legacy `aos_paciente_360` remains closed.

`aos_memory` and Notion were reconciled to REV-F6.4 PASS / REV-F6 62.5%.

## REV-F6.5 execution contract

F6.5 may now create the Historical Sales Plug-in only as an additive governed ingestion/read-model boundary. It must not fabricate historical revenue, mutate certified 2026 source truth, or relax F3/F4/F5/F6.0–F6.4 semantics.

Required gates:

- dynamic Historical Coverage Contract;
- removal of F6.4 hardcoded 2024/2025 availability semantics in favor of governed source registry/coverage;
- recompute/refresh hook;
- fixtures A–J covering no-source, partial, complete, duplicate, invalid, provenance, year isolation, replay, recovery and security cases;
- idempotent ingestion/recompute;
- fail-closed recovery;
- browser-closed raw historical models;
- no raw PII/PHI in aggregate contracts;
- performance gate without timeout inflation;
- deterministic terminal fingerprint;
- exact-head CI + LIVE migration/readback + post-merge replay.

Until F6.5 is certified:

- `REV-F6.5 = IN PROGRESS` once its isolated branch is opened;
- `REV-F6.6/F6.7 = BLOCKED`;
- `REV-F7 = BLOCKED`.
