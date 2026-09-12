'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');

const migration='supabase/migrations/20260902201500_mkt_loop6_p0432_decouple_llammap_refresh_v1.sql';
const rollback='supabase/rollbacks/20260902201500_mkt_loop6_p0432_decouple_llammap_refresh_v1_recovery.sql';
const m=fs.readFileSync(migration,'utf8');
const r=fs.readFileSync(rollback,'utf8');

function stripComments(sql){return sql.replace(/--.*$/gm,'').replace(/\/\*[\s\S]*?\*\//g,'');}

test('P0 #432 removes only legacy per-insert refresh trigger',()=>{
  const sql=stripComments(m);
  assert.match(sql,/DROP\s+TRIGGER\s+trg_refresh_llammap\s+ON\s+public\.aos_llamadas\s*;/i);
  assert.doesNotMatch(sql,/DROP\s+(?:MATERIALIZED\s+VIEW|FUNCTION|TABLE)\b/i);
  assert.doesNotMatch(sql,/DROP\s+TRIGGER\s+trg_000_aos_loop6_governed_call_v22/i);
  assert.doesNotMatch(sql,/DROP\s+TRIGGER\s+trg_aos_hotfix_call_guard_v1/i);
  assert.match(sql,/P0432_GOVERNED_WRITE_GUARD_MISSING/);
  assert.match(sql,/P0432_COMMERCIAL_POLICY_GUARD_MISSING/);
});

test('explicit legacy refresh compatibility remains intact',()=>{
  assert.match(m,/public\.fn_refresh_llammap\(\)/);
  assert.match(m,/public\.aos_refresh_llammap\(\)/);
  assert.doesNotMatch(stripComments(m),/REVOKE\b|GRANT\b/i);
});

test('rollback recreates exact statement-level trigger only',()=>{
  const sql=stripComments(r);
  assert.match(sql,/CREATE\s+TRIGGER\s+trg_refresh_llammap\s+AFTER\s+INSERT\s+ON\s+public\.aos_llamadas\s+FOR\s+EACH\s+STATEMENT\s+EXECUTE\s+FUNCTION\s+public\.fn_refresh_llammap\(\)\s*;/is);
  assert.doesNotMatch(sql,/CREATE\s+(?:MATERIALIZED\s+VIEW|TABLE)\b/i);
  assert.doesNotMatch(sql,/DROP\s+TRIGGER\s+trg_000_aos_loop6_governed_call_v22/i);
  assert.doesNotMatch(sql,/DROP\s+TRIGGER\s+trg_aos_hotfix_call_guard_v1/i);
});

test('no timeout or WA authority manipulation',()=>{
  const sql=stripComments(m+'\n'+r);
  assert.doesNotMatch(sql,/statement_timeout\s*=/i);
  assert.doesNotMatch(sql,/auto_reply|ai_send|auto_routing|human_send/i);
});
