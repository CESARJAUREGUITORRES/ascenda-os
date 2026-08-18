# ASCENDA OS — MEMORY CURRENT

**Captured from exact baseline:** `main@101b44bb8d69d9c9066a2910c68b42b3dbd6aea0`  
**Runtime:** S15.5 notification infrastructure certified; production runtime preserved  
**ACTIVE WORKSTREAM:** `REV-F5-CLOSEOUT`

## Authority

Read in order:

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`
6. Revenue Data & Intelligence CURRENT / REV-F5 checkpoint
7. exact GitHub + live Supabase/Railway
8. `aos_memory`
9. Notion

Historical documents/chat checkpoints never override CURRENT.

## Global state

S15.5 / Notifications is closed and regression-only. The owner explicitly assigned the next mutable HIGH/CRITICAL workstream to Revenue F5 and ordered the definitive closeout before moving to REV-F6. WhatsApp Revenue Hub V2 remains a separate program and must not mutate production concurrently while REV-F5 owns the lock.

Production runtime chain remains:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

Do not change runtime topology as part of F5 unless a demonstrated F5 blocker requires it and exact-chain regression evidence is added.

## REV-F5 baseline at acquisition

Exact production rebaseline:

- manifests: 6 / expected source rows: 15,498;
- staged source rows: 1,000;
- remaining source rows: 14,498;
- provisional identity clusters: 3,950;
- identity members: 0;
- patient link previews: 0;
- canonical apply events: 0;
- canonical patients: 7,675;
- temporary private transport: empty;
- structural duplicate `(batch_id, source_row_num)` keys: 0;
- orphan source rows: 0;
- latest F5 canary status: blocked because pre-apply gate is incomplete.

All six original private XLSX files are recoverable from the file library and were materialized for this closeout. Their SHA-256 values exactly match `aos_f5_source_batches_v1`; no source reconstruction is needed.

Expected rows:

- Pueblo Libre 2024: 4,192 (1,000 currently staged);
- Pueblo Libre 2025: 3,053;
- Pueblo Libre 2026: 993;
- San Isidro 2024: 3,190;
- San Isidro 2025: 3,066;
- San Isidro 2026: 1,004.

## REV-F5 current execution point

`REV-F5.0` is the active gate. Its purpose is exact-current rebaseline, source verification and exclusive lock acquisition. After the control handoff is merged and exact-head is revalidated, continue directly to `REV-F5.1`: complete the remaining 14,498 source rows through the existing private/idempotent F5 path, verifying production counts after every persisted chunk/batch.

Do not treat a merged PR, worker `COMPLETE`, manifest profile, or expected result as certification. Only live persisted counts/invariants close a gate.

## Safety rules specific to F5

- no canonical patient mutation before complete provenance, preview and governed review gate;
- no merge by name alone;
- document/email may be strong evidence; phone/name alone are not merge authority;
- source patient IDs and HC remain source-specific unless proven otherwise;
- fill-only enrichment by default; conflict when a non-null canonical value disagrees;
- clinical notes/allergies stay outside automatic commercial apply;
- `Último presupuesto` is evidence only, never payment/debt/balance;
- `ADELANTO` is payment evidence, never automatic debt;
- retries must reconcile persisted state first and be idempotent;
- every gate creates a recoverable checkpoint with exact SHA, live counters and next step.

## Related programs

- Revenue: F1–F4 closed; REV-F5 active; F6/F7 blocked until their declared predecessors certify.
- WhatsApp Revenue Hub: notification infrastructure S13–S15.5 closed; WA V2 roadmap remains separate/read-only while REV-F5 owns the lock.
- CIA: F0–F16 closed; CIA-F17/F18 remain separate and read-only during REV-F5 mutation.
- Sentinel: F1–F13 closed/regression-only.
- KronIA: K0 closed; K1–K8 paused.
- PARITY/BASELINE: maintenance/governance lanes only unless needed by REV-F5 validation.

## Institutional learning

- one global HIGH/CRITICAL mutable workstream;
- exact-current revalidation after every unrelated `main` advance;
- runner activity is execution state, never source of truth;
- do not cancel/duplicate a valid active run; reconcile its persisted effect first;
- code/pipeline completion is not data completion;
- staging completeness precedes identity rebuild;
- production Supabase + exact GitHub/CI/deploy evidence outrank documentation;
- Notion is reconciled to live truth, never used to manufacture it.
