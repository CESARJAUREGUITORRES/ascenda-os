# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 ACTIVE / MKT-INTEGRITY-HOTFIX-V3 PAUSED AFTER LOOP 5  
**Owner assignment:** 2026-08-18 Lima — explicit owner directive to resume and complete REV-F5 closeout now  
**Handoff base:** `main@fd9a80d3d04bde11d29fd21ec43324873ee92902`  
**Previous lock:** `MKT-INTEGRITY-HOTFIX-V3` — LOOP 5 PASS; LOOP 6 NOT STARTED / PAUSED  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**NEXT LOCK:** `UNASSIGNED` until REV-F5 production certification or explicit owner handoff.

## Handoff evidence

MKT Integrity V3 Loop 5 is merged and PASS at PR #297 / `fd9a80d3d04bde11d29fd21ec43324873ee92902`. Loop 6 was not started. The owner explicitly states there are no other active app processes and authorizes REV-F5 to resume and finish completely. This directive is the handback authorization.

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `REV-F5-CLOSEOUT` owns the lock, all other HIGH/CRITICAL feature/data workstreams remain read-only/documentation/regression-only unless explicitly required for REV-F5 validation.

## REV-F5 certified recoverable baseline before resume

Canonical pause checkpoint: `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_MKT_INTEGRITY_V3.md`.

Live state to revalidate before each write gate:

- 6 source batches / 15,498 expected rows;
- 7,064 persisted source rows;
- 8,434 remaining;
- 3,950 provisional identity clusters;
- members 0;
- preview 0;
- apply events 0.

Recovery hashes from certified pause:

- batches `807f03e96e5786203d867938c3938154`
- source rows `62b8fbedaa5da450a38c2471dd23b6b9`
- clusters `2d39d9ac990fee61a7ecb6ffa52efb64`

`aos_pacientes` count is observational only during staging because normal production workflows may create/update patients independently; F5-owned tables, hashes and audit events are the mutation boundary.

## Mandatory REV-F5 closeout sequence

1. REV-F5.0 exact-current rebaseline and lock acquisition.
2. REV-F5.1 finish all six historical source batches to 15,498/15,498 through the existing private idempotent compact ingest path.
3. REV-F5.2 certify all six batches, manifests, SHA, ranges, duplicates/orphans and full idempotent replay.
4. REV-F5.3 rebuild identity from complete provenance and require 15,498 members.
5. REV-F5.4 classify every cluster as MATCH / REVIEW / NEW with auditable evidence.
6. REV-F5.5 generate fill-only enrichment preview; no silent overwrite.
7. REV-F5.6 governed Review & Apply with admin+2FA, dry-run, canary, rollback proof and progressive apply.
8. REV-F5.7 certify patient → sale → canonical product F3 → payment/revenue/cartera F4 linkage.
9. REV-F5.8 audit real transactional sources for 2024–2025 and prohibit unsupported YoY claims where source evidence is absent.
10. REV-F5.9 emit numeric Coverage & Data Quality Report.
11. REV-F5.10 independent final exact-head/live certification; only then `REV-F5 = PRODUCTION CERTIFIED — 100%` and REV-F6 may be unblocked.

## Safety invariants

- no merge by name alone;
- source-specific patient ID and HC are not global identity keys without evidence;
- phone alone does not authorize a merge;
- `Último presupuesto` is evidence only, never automatic payment/debt/balance;
- `ADELANTO` is payment evidence, never automatic debt;
- clinical notes/allergies stay out of automatic commercial enrichment;
- every retry reconciles persisted state first and is idempotent;
- no Google Drive, GitHub PII, new bucket, new transport table or alternate uploader for the source rows while the current compact ingest path remains usable;
- no competing migrations/imports/canaries from other HIGH/CRITICAL workstreams.

## Main-moving policy

Before each mutable gate, re-read `main`. If `main` moves, stop new REV-F5 writes, inspect the diff, revalidate compatibility, then continue from LIVE state. Never infer persistence from a timeout.

## Exit / handback

Do not move this lock automatically. REV-F5 releases it only after REV-F5.10 is certified from exact GitHub/CI/deploy + live Supabase invariants + rollback/recovery + final documentation, or after an explicit owner directive that safely pauses/aborts it with a recoverable checkpoint.
