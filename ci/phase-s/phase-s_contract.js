'use strict';
const fs=require('fs');
const assert=require('assert');

const s=fs.readFileSync('app/server-phase-s.js','utf8');
const railway=fs.readFileSync('app/railway.json','utf8');
const authSync=fs.readFileSync('app/auth-resend-reconcile.js','utf8');

assert(s.includes("['server-f5.js']"),'Phase S must wrap the certified server-f5 chain');
assert(s.includes("p==='/api/wa3/bootstrap'"),'Phase S must intercept WA3 bootstrap');
assert(s.includes("aos_wa3_actor_v1"),'Phase S must reuse WA3 server-side actor authorization');
assert(s.includes("degraded_components"),'Phase S must expose degraded bootstrap components');
assert(s.includes("human_send_enabled:false"),'degraded control must fail closed for human send');
assert(s.includes("auto_routing_enabled:false"),'degraded control must fail closed for auto routing');
assert(s.includes("ai_send_enabled:false"),'degraded control must fail closed for AI send');
assert(s.includes("p==='/api/phase-s/status'"),'Phase S must expose protected diagnostics');
assert(s.includes("p==='/health'"),'Phase S must expose non-secret Railway health');
assert(s.includes("p==='/api/auth/v3/login'"),'Phase S must preserve Auth V3 Resend reconcile gate');
assert(authSync.includes('aos_integration_secrets_v1'),'Auth Resend sync must target private integration vault');
assert(!authSync.includes('/rest/v1/aos_integraciones?'),'Auth Resend sync must not write public integration catalog');
assert(!/WHATSAPP_ACCESS_TOKEN\s*=\s*['\"][^'\"]+['\"]/.test(s),'no hard-coded Meta access token');
assert(!/SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"][^'\"]+['\"]/.test(s),'no hard-coded service role');
assert(!/RESEND_API_KEY\s*=\s*['\"][^'\"]+['\"]/.test(s+authSync),'no hard-coded Resend API key');

const cfg=JSON.parse(railway);
const legacy='node server-phase-s.js';
const sentinel="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js";
assert([legacy,sentinel].includes(cfg.deploy.startCommand),'Phase S start command must be legacy or exact Sentinel runtime wrapper');
if(cfg.deploy.startCommand===sentinel){
  assert(!String(cfg.build&&cfg.build.buildCommand||'').includes('NODE_OPTIONS'),'Sentinel preload must not contaminate build');
}
assert.strictEqual(cfg.deploy.healthcheckPath,'/health');

console.log('PHASE_S_CONTRACT_PASS');
