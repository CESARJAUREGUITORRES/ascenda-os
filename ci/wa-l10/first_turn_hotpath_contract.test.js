'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');

const migration=fs.readFileSync('supabase/migrations/20260904225500_wa_l10_first_turn_hotpath_fix_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260904225500_wa_l10_first_turn_hotpath_fix_v1.rollback.sql','utf8');
const copilot=fs.readFileSync('app/wa4-copilot.js','utf8');

assert.match(migration,/with\s+prepared\s+as\s+materialized/i,'search hot path must materialize the normalized eligible row set once');
assert.match(migration,/public\.aos_wa4a_norm_v1\(k\.title\)\s+as\s+norm_title/i);
assert.match(migration,/public\.aos_wa4a_norm_v1\(k\.search_text\)\s+as\s+norm_search/i);
assert.equal((migration.match(/aos_wa4a_norm_v1\(k\.search_text\)/g)||[]).length,1,'derived search_text normalization must occur only once in the optimized function');
assert.equal((migration.match(/aos_wa4a_norm_v1\(k\.title\)/g)||[]).length,1,'derived title normalization must occur only once in the optimized function');
assert.match(migration,/p\.norm_search\s+like/i,'ranking/filtering must reuse the normalized row value');
assert.doesNotMatch(migration,/set\s+(?:local\s+)?statement_timeout\s*=/i,'remediation must never inflate or alter statement_timeout');
assert.doesNotMatch(migration,/create\s+materialized\s+view/i,'do not introduce a refresh-driven global materialized hot path');
assert.match(copilot,/task\s*:\s*['"]SALES_PLAYBOOK['"]/,'WA4 fail-closed logger still emits SALES_PLAYBOOK');
assert.match(migration,/['"]SALES_PLAYBOOK['"]::text/,'DB task CHECK must accept the existing fail-closed SALES_PLAYBOOK audit task');
assert.match(rollback,/WA_L10_RECOVERY_BLOCKED_SALES_PLAYBOOK_AUDIT_HISTORY/,'rollback must preserve append-only audit evidence once SALES_PLAYBOOK rows exist');
assert.doesNotMatch(migration,/aos_wa_l4_set_control_v1|aos_wa_l4_allowlist_set_v1|graph\.facebook\.com|\/messages/i,'DB hot-path repair must not activate CANARY or add a sender');

console.log('WA-L10 first-turn hotpath contract: PASS');
