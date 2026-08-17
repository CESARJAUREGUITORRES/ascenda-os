'use strict';
const fs=require('fs');const core=require('../../sentinel/remediation/remediation-core.cjs');
function ok(v,m){if(!v)throw new Error(m);}
const contract=JSON.parse(fs.readFileSync('sentinel/remediation/remediation-contract.v1.json','utf8'));
ok(contract.schema_version==='sentinel.remediation-contract.v1','contract version');
ok(contract.request_schema_version===core.REQUEST_SCHEMA,'request schema drift');
ok(contract.plan_schema_version===core.PLAN_SCHEMA,'plan schema drift');
ok(contract.audit_schema_version===core.AUDIT_SCHEMA,'audit schema drift');
ok(contract.baseline.production_mutation===false,'production mutation must default false');
ok(contract.baseline.auto_merge===false&&contract.baseline.auto_deploy===false,'automation defaults unsafe');
ok(contract.baseline.network_access===false&&contract.baseline.arbitrary_shell===false&&contract.baseline.arbitrary_sql===false,'unsafe capabilities enabled');
const src=fs.readFileSync('sentinel/remediation/remediation-core.cjs','utf8');
for(const forbidden of ['child_process','execSync(','spawnSync(','fetch(','axios','service_role','SUPABASE_SERVICE_ROLE_KEY','RAILWAY_TOKEN','GITHUB_TOKEN'])ok(!src.includes(forbidden),'forbidden runtime capability: '+forbidden);
ok(src.includes('PRODUCTION_MUTATION_BLOCKED'),'production block missing');
ok(src.includes('APPROVAL_BYPASS_BLOCKED'),'approval block missing');
ok(src.includes('SYMLINK_ESCAPE_BLOCKED'),'symlink block missing');
ok(src.includes('PROMPT_INJECTION_BLOCKED'),'injection block missing');
console.log('SENTINEL_F12_CONTRACT=PASS');
console.log('SENTINEL_F12_NO_PROD_WRITE=PASS');
