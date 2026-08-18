'use strict';
const fs=require('fs');function ok(v,m){if(!v)throw new Error(m)}
const runtime=fs.readFileSync('app/server-f17-current.js','utf8');
const phase=fs.readFileSync('app/server-phase-s.js','utf8');
const f5=fs.readFileSync('app/server-f5.js','utf8');
const rail=fs.readFileSync('app/railway.json','utf8');
ok(rail.includes('server-f17-current.js'),'Railway must start F17 CURRENT');
ok(runtime.includes("spawn(process.execPath,['server-phase-s.js']"),'F17 CURRENT must preserve Phase S');
ok(phase.includes("spawn(process.execPath,['server-f5.js']"),'Phase S must preserve F5');
ok(f5.includes("spawn(process.execPath,['server-wa4.js']"),'F5 must preserve WA4');
ok(runtime.includes('handleGovernedWebhook')&&runtime.includes("p==='/webhook'"),'webhook must traverse F17');
ok(runtime.includes('handleNativeHumanSend')&&runtime.includes('f17wa.prepareOutbound')&&runtime.includes('f17wa.markAccepted')&&runtime.includes('f17wa.markFailed'),'native send must reconcile F17');
ok(runtime.indexOf('f17wa.prepareOutbound')<runtime.indexOf('proxyBuffered(req,raw'),'F17 policy must precede inner Meta path');
ok(runtime.includes('wa.canaryAllows'),'real allowlist gate missing');
ok(!/WHATSAPP_ACCESS_TOKEN\s*=\s*['"][^'"]+/.test(runtime),'hard-coded provider token');
console.log('F17_EFFECTIVE_RUNTIME_CHAIN=PASS');
