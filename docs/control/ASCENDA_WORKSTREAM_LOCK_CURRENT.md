# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Certification merge main:** `ad2a879c895177d375fac89c64911ce3ea12f49a`  
**Terminal exact-head pre-merge:** `0cfdc71cfe5b1110be3ceaab952f184f926cf0a7`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.6 — Sentinel Data-Integrity Handoff`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED — 100%` · fp `f81a1b8fcfe010cd5254c4ab2e6048d2`  
**REV-F6.1:** `PASS / CERTIFIED — 100%`  
**REV-F6.2:** `PASS / CERTIFIED — 100%`  
**REV-F6.3:** `PASS / CERTIFIED — 100%` · fp `186a1da2c29b498dad26223ae264adea`  
**REV-F6.4:** `PASS / CERTIFIED — 100%` · fp `54c07961f191147860f6acd3a3e85c2a`  
**REV-F6.5:** `PASS / CERTIFIED — 100%` · fp `88957cec3d785e4931a8f834c0259a91`  
**REV-F6 global:** `75%`  
**REV-F6.6:** `NEXT / UNBLOCKED`  
**REV-F6.7:** `PENDING`  
**REV-F7:** `BLOCKED until REV-F6.6 + REV-F6.7 complete`

GitHub CURRENT + Supabase LIVE remain authoritative. `REV-F6-CLOSEOUT` remains the only mutable HIGH/CRITICAL Revenue lane until F6 is complete.

## REV-F6.5 terminal certification

PR **#316** is merged. Merge commit:

`ad2a879c895177d375fac89c64911ce3ea12f49a`

Terminal exact-head before merge:

`0cfdc71cfe5b1110be3ceaab952f184f926cf0a7`

Final exact-head CI = **7/7 SUCCESS**:

- Ascenda CI **#2680**;
- REV-F6.0 **#49**;
- REV-F6.1 **#49**;
- REV-F6.2 **#28**;
- REV-F6.3 **#19**;
- REV-F6.4 **#14**;
- REV-F6.5 **#6**.

Supabase LIVE hardening migration:

`20260820211638 rev_f6_5_rev_f6_0_fingerprint_isolation_v1`

Terminal deterministic fingerprint chain:

- F6.0 `f81a1b8fcfe010cd5254c4ab2e6048d2`;
- F6.3 `186a1da2c29b498dad26223ae264adea`;
- F6.4 `54c07961f191147860f6acd3a3e85c2a`;
- F6.5 `88957cec3d785e4931a8f834c0259a91`.

Hardening semantic:

`REVENUE_TRUTH_EXCLUDES_MUTABLE_CIA_COMPATIBILITY_CARDINALITY`

Normal CIA/WA activity can no longer invalidate Revenue certification fingerprints through compatibility-view cardinality/freshness. The CIA compatibility metrics remain visible in the contract; only the certification hash projection is isolated.

## LIVE terminal truth

Final reconciliation readback:

- patients **7,690**;
- canonical sales **1,299**;
- F3 product facts **406**;
- F4 reconciliation rows **162**;
- F6.4 sales fact **1,299**;
- 2024 transactional sales = `value=null / NO_CERTIFIED_SOURCE`;
- 2025 transactional sales = `value=null / NO_CERTIFIED_SOURCE`.

The patient count **7,690** is the current valid LIVE baseline. The increase from **7,688 → 7,690** came from two legitimate operational patient creations before the terminal PR #316 merge; it was not caused by REV-F6.5. No patients were created after the terminal merge timestamp during reconciliation.

No REV-F6.5 terminal hardening mutation was made to patients, sales, F3, or F4.

Security/ACL = **PASS**. Replay/recovery = **PASS**. Post-merge LIVE = **PASS**.

Performance = **PASS**, target `<1000 ms`:

- global **3.211 ms**;
- San Isidro **138.042 ms**;
- Pueblo Libre **10.591 ms**.

## Historical semantics

No certified transactional source exists for 2024 or 2025. Therefore historical transactional revenue remains **null / unavailable**, never fabricated as zero.

`NO_CERTIFIED_SOURCE != zero`

No historical XLSX search, Google Drive source discovery, parallel revenue master, patient rewrite, or direct historical mass insert is authorized by this certification.

## Next gate

`REV-F6.5 — PASS / CERTIFIED — 100%`

`REV-F6 global = 75%`

`REV-F6.6 — Sentinel Data-Integrity Handoff = NEXT / UNBLOCKED`

REV-F6.7 remains pending. REV-F7 remains blocked until REV-F6.6 + REV-F6.7 are complete and REV-F6 reaches terminal certification.
