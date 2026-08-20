# REV-F6.1 — PRE-LIVE CHECKPOINT

**Captured:** 2026-08-19 America/Lima  
**Phase:** `REV-F6.1 — Patient Commercial 360 V2`  
**Entry baseline:** `main@2b636acef991f51ce5e3c71a5ddbde7f3c58e23c`  
**Upstream contract:** `REV-F6.0 PASS / CERTIFIED`  
**F6.0 fingerprint:** `02ba53adb9dabfcd0a4557061be53c2f`  
**PR:** `#310`

## State

The deterministic service-worker cutover has been materialized on the PR branch. Browser compatibility calls for legacy `aos_paciente_360` are routed to `aos_patient_commercial_360_v2` with the cached application token; direct Patient V2 search/360 calls are token-injected by the same governed bridge.

The bot-authored cutover commit produced GitHub `action_required` check suites with no jobs, so it is not accepted as certification evidence. This checkpoint is a human-authored exact-head transition whose CI must execute normally before any F6.1 LIVE DDL.

## Fail-closed pre-LIVE rules

- No F6.1 production DDL before exact-head FAST/UI and isolated DB/security/semantic PASS.
- No patient merge or business-row mutation is in F6.1 scope.
- `canonical_patient_id` remains the subject; phone/document/email are lookup aliases only.
- ambiguous aliases stay `IDENTITY_CONFLICT` and never auto-assign.
- no fuzzy identity and no phone-nearness authority.
- F3 owns product truth; F4 owns payment/revenue/cartera truth; F5 owns patient identity/provenance.
- lifecycle remains `PENDING_REV_F6_2`.
- 2024/2025 transactional sales remain `NO_CERTIFIED_SOURCE`, never zero.

## Preflight LIVE evidence already measured read-only

- phone aliases: 7,139;
- unambiguous phone aliases: 7,102;
- conflicting phone aliases: 37;
- canonical patients with more than one safe phone alias: 6;
- F6.0 data contract fingerprint remains `02ba53adb9dabfcd0a4557061be53c2f`;
- protected business domains before F6.1 LIVE DDL: patients 7,688; sales 1,299; F3 406; F4 162.

## Next gate

`exact-head CI → FAST/UI → isolated DB/security/semantic → replay → recovery → anti-drift main/F6.0 → LIVE migration → identity/alias invariants → real old/current phone convergence → real conflict fail-closed → ACL → protected fingerprints → F6.1 fingerprint x2 → certificate → final exact-head CI → expected-head merge → post-merge GitHub/LIVE → aos_memory → Notion/readback`.
