#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const censusPath=process.argv[2]||path.join(process.env.RUNNER_TEMP||'.tmp','asc-perf-runtime-census.json');
const failures=[];
function fail(code,detail){failures.push({code,detail});}
function read(p){return fs.readFileSync(path.join(root,p),'utf8');}
function count(text,re){return (text.match(re)||[]).length;}
function expect(code,cond,detail){if(!cond)fail(code,detail);}

if(!fs.existsSync(censusPath))throw new Error('ASC_PERF_CENSUS_REQUIRED '+censusPath);
const census=JSON.parse(fs.readFileSync(censusPath,'utf8'));
expect('CENSUS_SCHEMA',census.schema==='asc-perf-runtime-census/v1','unexpected runtime census schema');
expect('RECURRENT_FILE_BUDGET',Number(census.recurrentNetworkCandidateCount)<=55,`recurrent network candidate files ${census.recurrentNetworkCandidateCount} > 55`);
expect('FAST_INTERVAL_BUDGET',Number(census.fastIntervalCandidateCount)<=10,`literal intervals <5s ${census.fastIntervalCandidateCount} > 10`);
expect('BROAD_READ_BUDGET',Number(census.broadReadCandidateCount)<=61,`broad read signals ${census.broadReadCandidateCount} > 61`);

const recurrentDebt=new Set([
'app/public/admin-billing.html','app/public/admin-calls.html','app/public/admin-catalogo.html','app/public/admin-config.html','app/public/admin-email.html','app/public/admin-home.html','app/public/admin-marketing-v2.js','app/public/admin-sales.html','app/public/admin-team.html','app/public/admin-whatsapp-wa3.html','app/public/admin-whatsapp.html','app/public/agenda.js','app/public/agendar.html','app/public/agendar-v2.html','app/public/agents.html','app/public/app.html','app/public/asesor-coord.html','app/public/attendance.html','app/public/auth-session-cookie-bridge.js','app/public/caja.html','app/public/calls.html','app/public/calls.js','app/public/catalogo.html','app/public/cerebro.html','app/public/coordinacion.html','app/public/f4-production-canary-hotfix.js','app/public/f4-revenue-ops.js','app/public/inventario.html','app/public/login.html','app/public/notification-center-s15.js','app/public/notification-push-s14.js','app/public/patients.js','app/public/rev-prc1-product-resolution-center.js','app/public/rev-sx1-sales-explorer.js','app/public/sentinel-hub-bootstrap.js','app/public/sentinel-hub.js','app/public/sentinel-inapp-notifications.js','app/public/studio-creator.html','app/public/studio.html','app/public/wa-human-alerts.js','app/public/wa-multiagent-final-panel.js','app/public/wa-multiagent-v2-panel.js','app/public/wa-native-panel.js','app/public/wa-performance-hardening.js','app/public/wa-shell-integration.js','app/server-f17.js','app/server-f4.js','app/server-f5.js','app/server-phase-s.js','app/server-phase2.js','app/server-wa2.js','app/server-wa3-v2.js','app/server-wa3.js','app/server-wa4.js','app/server.js','app/src/pages/login.js'
]);
for(const item of census.recurrentNetworkCandidates||[]){
  if(!recurrentDebt.has(item.file))fail('NEW_RECURRENT_NETWORK_OWNER',item.file);
}

const waNative=read('app/public/wa-native-panel.js');
const waMulti=read('app/public/wa-multiagent-final-panel.js');
expect('WA_SINGLE_INBOX_OWNER',!waMulti.includes("api('/api/wa3/inbox?limit=120')"),'multiagent regained direct inbox read');
expect('WA_SHARED_SNAPSHOT',waNative.includes('getInboxSnapshot')&&waNative.includes('aos:wa3-inbox')&&waMulti.includes('getInboxSnapshot')&&waMulti.includes('aos:wa3-inbox'),'WA shared snapshot/event contract missing');
expect('WA_FALLBACK_CADENCE',waNative.includes('setInterval(function(){heartbeat(false);},2500)'),'native fallback cadence is not 2500ms');
expect('WA_IDLE_TIMELINE',!waNative.includes('S.heartbeatTick%3===0'),'idle third-tick timeline refresh returned');
expect('WA_HIDDEN_GUARD',waMulti.includes('X.busy||document.hidden'),'multiagent hidden-page guard missing');

const calls=read('app/public/calls.html');
expect('CALLS_SINGLE_PANEL_OWNER',count(calls,/_rpc\('aos_panel_asesor'/g)===1,'Calls has more than one direct aos_panel_asesor owner');
expect('CALLS_SHARED_HELPER',calls.includes('function _panelAsesorShared('),'Calls shared snapshot helper missing');

const admin=read('app/public/admin-home.html');
expect('ADMIN_SINGLE_PANEL_OWNER',count(admin,/_r\('aos_panel_admin'/g)===1,'Admin has more than one direct aos_panel_admin owner');
expect('ADMIN_SHARED_HELPER',admin.includes('function _panelAdminShared('),'Admin shared snapshot helper missing');

const prc=read('app/public/rev-prc1-product-resolution-center.js');
expect('PRC_NO_MUTATION_NETWORK_THROTTLE',!prc.includes('Date.now()-lastBadgeLoad>3000'),'PRC mutation-driven heavy badge read returned');
expect('PRC_NO_FOCUS_HEAVY_READ',!prc.includes("focus',function(){ensureButton();refreshBadge();"),'PRC focus-driven heavy badge read returned');
expect('PRC_EVENT_DRIVEN_BADGE',prc.includes('if(created)refreshBadge();')&&prc.includes('decorateImportPreview(br,0);refreshBadge();'),'PRC event-driven badge contract missing');

const server=read('app/server.js');
expect('AGENT_CRON_NO_SELECT_STAR',!server.includes("aos_agentes?select=*&activo=eq.true&tipo_ejecucion=eq.cron"),'agent cron select=* returned');
expect('AGENT_CRON_COMPACT',server.includes('select=id,nombre,emoji,cron_intervalo,ultima_actividad,system_prompt,motor_ai,modelo&activo=eq.true&tipo_ejecucion=eq.cron'),'agent cron compact projection missing');

const f17=read('app/server-f17.js');
expect('NOTIFICATION_ADAPTIVE_IDLE',f17.includes('const NOTIFICATION_PUMP_IDLE_MS = [8000, 15000]')&&f17.includes('function notificationPumpDelay('),'notification adaptive idle backoff missing');
expect('NOTIFICATION_NO_FIXED_INTERVAL',!f17.includes('setInterval(runNotificationPump'),'fixed notification pump interval returned');
expect('NOTIFICATION_SINGLE_TIMER',f17.includes('notificationPumpTimer')&&f17.includes('scheduleNotificationPump'),'notification single timer ownership missing');

const railway=read('app/railway.json');
const emailGatewayBootstrap=read('app/email-gateway.js');
expect('STUDIO_HARD_OFF_RAILWAY',railway.includes('AOS_STUDIO_BACKGROUND_ENABLED=false'),'Studio background hard-off missing in Railway config');
expect('STUDIO_HARD_OFF_DEFAULT',server.includes("process.env.AOS_STUDIO_BACKGROUND_ENABLED || 'false'"),'Studio server default is not hard-off');
expect('STUDIO_BOOTSTRAP_FAIL_CLOSED',emailGatewayBootstrap.includes("process.env.AOS_STUDIO_BACKGROUND_ENABLED = 'false'"),'Studio runtime bootstrap hard-off missing');
expect('STUDIO_BOOTSTRAP_CORE_CHAIN',emailGatewayBootstrap.includes("module.exports = require('./email-gateway-core')"),'Email gateway core chain missing');

if(failures.length){
  console.error('ASC-PERF PERFORMANCE GUARD = FAIL');
  for(const f of failures)console.error(`${f.code}: ${f.detail}`);
  process.exit(1);
}
console.log('ASC-PERF PERFORMANCE GUARD = PASS');
console.log(JSON.stringify({recurrentNetworkCandidateCount:census.recurrentNetworkCandidateCount,fastIntervalCandidateCount:census.fastIntervalCandidateCount,broadReadCandidateCount:census.broadReadCandidateCount,guardedRecurrentDebtFiles:recurrentDebt.size}));
