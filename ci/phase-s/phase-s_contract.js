'use strict';
const fs=require('fs');
const assert=require('assert');

const s=fs.readFileSync('app/server-phase-s.js','utf8');
const f17=fs.readFileSync('app/server-f17.js','utf8');
const s152=fs.readFileSync('app/server-phase-s-f17.js','utf8');
const railway=fs.readFileSync('app/railway.json','utf8');
const authSync=fs.readFileSync('app/auth-resend-reconcile.js','utf8');
const login=fs.readFileSync('app/public/login.html','utf8');
const quota=fs.readFileSync('app/supabase-quota-circuit-preload.cjs','utf8');
const quotaTarget=fs.readFileSync('app/supabase-quota-target.cjs','utf8');
const waPrelude=fs.readFileSync('app/public/wa-native-bootstrap-prelude.js','utf8');

assert(s.includes("['server-f5.js']"),'Phase S must wrap the certified server-f5 chain');
assert(s.includes("p==='/api/wa3/bootstrap'"),'Phase S must intercept WA3 bootstrap');
assert(s.includes("aos_wa3_actor_v1"),'Phase S must reuse WA3 server-side actor authorization');
assert(s.includes("degraded_components"),'Phase S must expose degraded bootstrap components');
assert(s.includes("human_send_enabled:false"),'degraded control must fail closed for human send');
assert(s.includes("auto_routing_enabled:false"),'degraded control must fail closed for auto routing');
assert(s.includes("ai_send_enabled:false"),'degraded control must fail closed for AI send');
assert(s.includes("p==='/api/phase-s/status'"),'Phase S must expose protected diagnostics');
assert(s.includes("p==='/health'"),'Phase S must expose non-secret Railway health');
assert(s.includes("p==='/api/auth/v3/login'"),'Phase S must preserve Auth V3 Resend reconcile boundary');
assert(waPrelude.includes("caches.open('aos-phase2-auth')"),'WA bootstrap must recover a previously issued strong token from the existing auth bridge cache');
assert(waPrelude.includes("c.match('/__aos_app_token')"),'WA bootstrap cache recovery must use the canonical Auth V3 bridge key');
assert(waPrelude.includes("sessionStorage.setItem('aos_app_token',t)"),'recovered strong token should repopulate only session-scoped browser state');
assert(!waPrelude.includes("localStorage.setItem('aos_app_token'"),'WA bootstrap must never persist the strong token in localStorage');
assert(authSync.includes('aos_integration_secrets_v1'),'Auth Resend sync must target private integration vault');
assert(authSync.includes("AUTH_RESEND_SYNC_DEFERRED"),'transient Resend/Supabase sync outage must be explicitly deferred rather than pre-block canonical auth');
assert(authSync.includes('SYNC_TIMEOUT_MS = 1500'),'Resend sync must stay short-bounded and must not inflate timeouts');
assert(!authSync.includes('/rest/v1/aos_integraciones?'),'Auth Resend sync must not write public integration catalog');
assert(login.includes('href="/favicon.png"'),'login document must advertise the canonical Ascenda favicon');
assert(login.includes('<img src="/favicon.png" alt="AscendaOS">'),'login card must render the canonical Ascenda mark');
assert(!login.includes('<div class="logo">✦</div>'),'generic star must not replace the Ascenda mark');
assert(login.includes('id="togglePass"'),'password field must expose an explicit visibility toggle');
assert(login.includes('aria-label="Mostrar contraseña"'),'password visibility toggle must be accessible');
assert(login.includes("p.type=show?'text':'password'"),'password toggle must only switch visibility state');
assert(login.includes("e==='AUTH_UPSTREAM_UNAVAILABLE'"),'raw auth transport outage must be translated to a user-facing availability message');
assert(!/WHATSAPP_ACCESS_TOKEN\s*=\s*['\"][^'\"]+['\"]/.test(s),'no hard-coded Meta access token');
assert(!/SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"][^'\"]+['\"]/.test(s+quota+quotaTarget),'no hard-coded service role');
assert(quota.includes("isConfiguredSupabaseRequest(args, configuredHost)"),'quota preload must classify requests by the configured Supabase host');
assert(quota.includes("scope: 'ALL_CONFIGURED_SUPABASE_RUNTIME_REQUESTS'"),'project-wide 402 breaker scope must remain explicit');
assert(quotaTarget.includes("host === String(configuredHost || '').toLowerCase()"),'quota target must match only the configured Supabase host');
assert(!quota.includes('userAgentRe'),'quota breaker must not depend on User-Agent because Fair Use 402 is project-wide');
assert(!quota.includes('SUPABASE_SERVICE_ROLE_KEY'),'quota preload must never inspect service-role credentials');

const cfg=JSON.parse(railway);
const legacy='node server-phase-s.js';
const sentinel="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js";
const sentinelEmail="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs --require ./email-runtime-env-compat.cjs' node server-phase-s.js";
const sentinelEmailQuota="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs --require ./email-runtime-env-compat.cjs --require ./supabase-quota-circuit-preload.cjs' node server-phase-s.js";
const s152Legacy='node server-phase-s-f17.js';
const s152Sentinel="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js";
const s152SentinelEmail="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs --require ./email-runtime-env-compat.cjs' node server-phase-s-f17.js";
const s152SentinelEmailQuota="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs --require ./email-runtime-env-compat.cjs --require ./supabase-quota-circuit-preload.cjs' node server-phase-s-f17.js";
const start=cfg.deploy.startCommand;
const studioHardOffPrefix='env AOS_STUDIO_BACKGROUND_ENABLED=false ';
const studioHardOff=String(start||'').startsWith(studioHardOffPrefix);
let normalizedStart=start;
if(studioHardOff){
  const remainder=start.slice(studioHardOffPrefix.length);
  normalizedStart=remainder.startsWith('NODE_OPTIONS=')?'env '+remainder:remainder;
}
assert(studioHardOff,'Studio background must remain HARD-OFF while ASC-PERF owns the mutable lane');
const directPhaseS=[legacy,sentinel,sentinelEmail,sentinelEmailQuota].includes(normalizedStart);
const f17Bootstrap=[s152Legacy,s152Sentinel,s152SentinelEmail,s152SentinelEmailQuota].includes(normalizedStart)
  && s152.includes("a[0]==='server-f5.js'")
  && s152.includes("a[0]='server-f17.js'")
  && s152.includes("require('./server-phase-s.js')")
  && f17.includes("['server-f5.js']");
assert(directPhaseS||f17Bootstrap,'Phase S start command must be direct or an exact certified F17 bootstrap/preload chain after the Studio HARD-OFF prefix');
if([sentinel,sentinelEmail,sentinelEmailQuota,s152Sentinel,s152SentinelEmail,s152SentinelEmailQuota].includes(normalizedStart)){
  assert(!String(cfg.build&&cfg.build.buildCommand||'').includes('NODE_OPTIONS'),'runtime preloads must not contaminate build');
}
assert.strictEqual(cfg.deploy.healthcheckPath,'/health');

console.log('PHASE_S_CONTRACT_PASS');