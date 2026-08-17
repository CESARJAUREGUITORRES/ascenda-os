# Sentinel F13 History Parity Audit

**Mode:** child-branch, read-only comparison against the already-applied production migration statement.

- Local file: `20260817203500_sentinel_f13_owner_hub.sql`
- Production ledger: `20260817203504 sentinel_f13_owner_hub`
- Raw MD5: local `5022ae05e1b705e587cad2e0c957df72` vs live `e403332d1c9f53efa0338f8f3585442c` → **DIFF**
- Normalized MD5 (line comments + whitespace removed): local `e2f7b3b395c5632db27ecdfb72bc15bc` vs live `e2f7b3b395c5632db27ecdfb72bc15bc` → **PASS**
- Local normalized length: `1970` vs live normalized length: `1970`

## Decision

**VERSION_ONLY_FORMAT_DRIFT: normalized SQL is equivalent; owner-specific version rename is eligible after CURRENT-main sync and exact-head replay.**
