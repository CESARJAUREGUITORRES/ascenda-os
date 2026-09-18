const fs=require('fs');

function ok(cond,msg){ if(!cond){ console.error('FAIL:',msg); process.exit(1); } }

const migration=fs.readFileSync('supabase/migrations/20260918013500_cc_hopper_f1_claim_hotpath.sql','utf8');
const doc=fs.readFileSync('docs/control/commercial-intelligence/CC_HOPPER_F1_ARCHITECTURE_20260917.md','utf8');
const calls=fs.readFileSync('app/public/calls-performance-v1.js','utf8');

ok(/create index if not exists idx_cia_assignments_claim_hotpath_v1/i.test(migration),'claim hotpath index missing');
ok(/advisor_user_id[\s\S]*state[\s\S]*must_start_before[\s\S]*source_rank[\s\S]*assigned_at/i.test(migration),'claim index order incomplete');
ok(/where state in \('ASSIGNED','IN_PROGRESS'\)/i.test(migration),'partial active-state predicate missing');
ok(!/create\s+table/i.test(migration),'F1 must not create a parallel hopper table');
ok(!/create\s+or\s+replace\s+function/i.test(migration),'F1 must not change routing behavior');
ok(calls.includes("fn==='aos_siguiente_lead_v2'?'aos_siguiente_lead_v3':fn"),'Call Center compatibility layer is not routing through V3 authority');
ok(/Audience != Activation != Assignment != Advisor Work/.test(doc),'core operating-model separation missing');
ok(/aos_cia_assignments/.test(doc) && /hopper/i.test(doc),'existing assignments table is not documented as hopper');
ok(/No parallel CRM/.test(doc),'parallel-store prohibition missing');
ok(/Human canary:\s*NOT EXECUTED/i.test(doc),'human canary safety status missing');

console.log('CC-HOPPER-F1 contract: PASS');
