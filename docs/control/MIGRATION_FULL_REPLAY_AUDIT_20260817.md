# ASCENDA Migration Full Replay Audit

**Environment:** self-hosted Zero-Cost isolated Supabase DB; no production writes.

- Branch source: exact-6 parity candidate
- Supabase CLI: `2.101.0`
- DB start: `rc=1`
- Full `supabase/migrations` reset/replay: `rc=999`
- Result: **FAIL** at stage **DB_START**
- Last migration announced by CLI: `20260812023500_fix_marketing_cohort_attribution.sql...`
- First detected error: `ERROR: query returned no rows (SQLSTATE P0002)`

## Gate

**FULL_HISTORY_REPLAY=BLOCKED.** Resolve the recorded startup/replay blocker before merging history repairs.
