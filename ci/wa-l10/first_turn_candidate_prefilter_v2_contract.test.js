'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');

const migration=fs.readFileSync('supabase/migrations/20260905001000_wa_l10_first_turn_candidate_prefilter_v2.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260905001000_wa_l10_first_turn_candidate_prefilter_v2.rollback.sql','utf8');

assert.match(migration,/with\s+folded\s+as\s+materialized/i,'v2 must materialize the cheap folded eligible set');
assert.match(migration,/candidates\s+as\s+materialized/i,'v2 must materialize the candidate subset');
assert.match(migration,/prepared\s+as\s+materialized/i,'v2 must materialize canonical normalized candidates once');
assert.match(migration,/lower\s*\(\s*translate\s*\(\s*coalesce\s*\(\s*k\.search_text\s*,\s*''\s*\)/i,'v2 must use cheap accent/case folding before regex normalization');
assert.match(migration,/exists\s*\(\s*select\s+1\s+from\s+unnest\s*\(v_tokens\)\s+w\s+where\s+f\.fold_search\s+like/i,'candidate filtering must use bounded query tokens against folded text');
assert.equal((migration.match(/aos_wa4a_norm_v1\(c\.search_text\)/g)||[]).length,1,'expensive canonical candidate search_text normalization must occur once');
assert.equal((migration.match(/aos_wa4a_norm_v1\(k\.search_text\)/g)||[]).length,0,'v2 must not canonically regex-normalize every eligible source row');
assert.match(migration,/p\.norm_search\s+like/i,'final ranking/filter must reuse canonical candidate normalization');
assert.doesNotMatch(migration,/set\s+(?:local\s+)?statement_timeout\s*=/i,'v2 must never alter statement_timeout');
assert.doesNotMatch(migration,/create\s+materialized\s+view/i,'v2 must not create a refresh-driven persistent materialized view');
assert.doesNotMatch(migration,/aos_wa_l4_set_control_v1|aos_wa_l4_allowlist_set_v1|graph\.facebook\.com|\/messages/i,'v2 must not activate CANARY, mutate allowlist, or add a sender');
assert.match(rollback,/with\s+prepared\s+as\s+materialized/i,'rollback must restore v1 prepared-set behavior');
assert.match(rollback,/aos_wa4a_norm_v1\(k\.search_text\)\s+as\s+norm_search/i,'rollback must restore v1 per-eligible-row normalization');
assert.doesNotMatch(rollback,/aos_wa_l4_set_control_v1|aos_wa_l4_allowlist_set_v1|graph\.facebook\.com|\/messages/i,'rollback must preserve authority boundary');

console.log('WA-L10 first-turn candidate prefilter v2 contract: PASS');
