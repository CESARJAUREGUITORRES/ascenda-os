'use strict';
const fs=require('fs');
const assert=require('assert');

const s=fs.readFileSync('app/server-phase-s.js','utf8');
const railway=fs.readFileSync('app/railway.json','utf8');

assert(s.includes("['server-f5.js']"),'Phase S must wrap the certified server-f5 chain');
assert(s.includes("p==='/api/wa3/bootstrap'"),'Phase S must intercept WA3 bootstrap');
assert(s.includes("aos_wa3_actor_v1"),'Phase S must reuse WA3 server-side actor authorization');
assert(s.includes("degraded_components"),'Phase S must expose degraded bootstrap components');
assert(s.includes("human_send_enabled:false"),'degraded control must fail closed for human send');
assert(s.includes("auto_routing_enabled:false"),'degraded control must fail closed for auto routing');
assert(s.includes("ai_send_enabled:false"),'degraded control must fail closed for AI send');
assert(s.includes("p==='/api/phase-s/status'"),'Phase S must expose protected diagnostics');
assert(s.includes("p==='/health'"),'Phase S must expose non-secret Railway health');
assert(!/WHATSAPP_ACCESS_TOKEN\s*=\s*['\"][^'\"]+['\"]/.test(s),'no hard-coded Meta access token');
assert(!/SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"][^'\"]+['\"]/.test(s),'no hard-coded service role');

const cfg=JSON.parse(railway);
assert.strictEqual(cfg.deploy.startCommand,'node server-phase-s.js');
assert.strictEqual(cfg.deploy.healthcheckPath,'/health');

console.log('PHASE_S_CONTRACT_PASS');
