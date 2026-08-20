# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Current main before terminal hardening:** `70bd591a2f4da7a39e41819416af40af4a694b29`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.5 — POST-MERGE TERMINAL FINGERPRINT ISOLATION`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED — semantic hardening in progress`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `PASS / CERTIFIED — terminal chain fp pending isolation`  
**REV-F6.4:** `PASS / CERTIFIED — terminal chain fp pending isolation`  
**REV-F6 global:** `62.5%` until F6.5 terminal certification  
**REV-F6.5:** `POST-MERGE HARDENING / NOT YET TERMINALLY CERTIFIED`  
**REV-F6.6:** `BLOCKED until REV-F6.5 certification`  
**REV-F6.7:** `BLOCKED`  
**REV-F7:** `BLOCKED until REV-F6 final certification`

GitHub CURRENT + Supabase LIVE remain authoritative. `REV-F6-CLOSEOUT` is the only mutable HIGH/CRITICAL Revenue lane.

## REV-F6.5 implementation + first merge

PR **#315** passed final exact-head Ascenda CI + REV-F6.0 through REV-F6.5 on `1d4d6005ac2aa9747e14625dfdffb9864b88c889` and merged with `expected_head_sha` to `main@70bd591a2f4da7a39e41819416af40af4a694b29`.

Supabase LIVE migration `20260820201634 rev_f6_5_historical_sales_plugin_v1` is applied. Historical runtime semantics remain correct:

- manifest rows **0**;
- certified historical sources **0**;
- 2024 = `value=null / NO_CERTIFIED_SOURCE`;
- 2025 = `value=null / NO_CERTIFIED_SOURCE`;
- 2026 = **1,299** transactions / billed **561889.27**;
- protected truth = patients **7,688** / sales **1,299** / F3 **406** / F4 **162**;
- ACL remains fail-closed and browser raw historical access remains closed.

## Post-merge fingerprint finding

Post-merge readback correctly stopped terminal certification because F6.0→F6.3→F6.4→F6.5 fingerprints moved while protected Revenue truth did not.

Root cause is architectural, not business-data drift: `aos_rev_f6_data_contract_v1()` included mutable cardinality/freshness from `aos_cia_contact_identity_v1` in its certification fingerprint. That compatibility view spans patients + leads + calls + appointments + sales, so normal CIA/WA activity can change its row cardinality without changing Revenue truth.

Observed post-merge chain before hardening:

- F6.0 `5ab234f6f37cfcae31bccee45cb1607a`;
- F6.3 `8656f87a275a84588ee103fbe1626950`;
- F6.4 `583b8b79e781f3c9303e64aceedc2105`;
- F6.5 `2595c0d17989714693f32cf19f064f98`.

These hashes are **not accepted as terminal certification fingerprints** because their upstream F6.0 projection is coupled to another mutable workstream.

## Terminal hardening contract

Branch `data/rev-f6-5-terminal-fingerprint-isolation-20260820` isolates the Revenue certification fingerprint while preserving full CIA compatibility metrics in the visible F6.0 contract.

The fingerprint projection excludes only:

- `compatibility_identity.rows`;
- `compatibility_identity.with_canonical_patient`;
- `compatibility_identity.identity_conflicts`;
- `freshness_sources.cia_identity_updated_at`.

It does **not** exclude or alter patient, sales, F3, F4, F5, lifecycle, identity-confidence, historical-source, security, or Revenue coverage truth.

Required terminal proof:

1. synthetic CIA-churn test demonstrates legacy hash changes while isolated Revenue hash remains stable;
2. F6.0/F6.3/F6.4/F6.5 new chain fingerprints reproduce deterministically;
3. exact-head Ascenda CI + F6.0–F6.5 SUCCESS;
4. LIVE migration + protected truth + ACL + historical no-source + performance PASS;
5. final certificate/snapshot updated with superseded and terminal fingerprints;
6. exact-head merge of hardening PR;
7. post-merge LIVE fingerprints exact;
8. `aos_memory` + Notion + CURRENT reconciled last.

Until all gates pass, **REV-F6.5 remains not terminally certified and REV-F6.6 remains blocked**.
