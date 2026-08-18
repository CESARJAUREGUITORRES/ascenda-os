'use strict';
const fs=require('fs');
const path=require('path');
const cp=require('child_process');
const ROOT=path.resolve(__dirname,'../..');
const APP=path.join(ROOT,'app');
const ok=(v,m)=>{if(!v)throw new Error(m)};
const read=p=>{const a=path.join(ROOT,p);ok(fs.existsSync(a),`MISSING_FILE:${p}`);return fs.readFileSync(a,'utf8')};
const json=p=>JSON.parse(read(p));

const f1=read('docs/control/SENTINEL_F1_GOVERNANCE_PRIVACY_COST_POLICY.md');
const f2=json('docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json');
const f3=json('sentinel/telemetry/contract-v1.json');
const f4=json('sentinel/sentry/f4-contract.json');
const align=json('sentinel/maintenance/current-alignment-v1.json');
const railway=json('app/railway.json');
const wrapper=read('app/server-phase-s-f17.js');
const phaseS=read('app/server-phase-s.js');
const f17=read('app/server-f17.js');
const init=read('app/sentinel-sentry-init.cjs');
const pkg=json('app/package.json');

// Historical V1 remains immutable evidence; CURRENT is a separate dimension.
ok(align.schema_version==='sentinel-current-alignment/v1','ALIGN_SCHEMA_DRIFT');
ok(align.baseline?.certified_main==='15de6f0358c53f9088a20d44e579dafae99fa041','ALIGN_BASELINE_SHA_DRIFT');
ok(align.baseline?.registry==='docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json','ALIGN_BASELINE_REGISTRY_DRIFT');
ok(align.baseline?.status==='CERTIFIED_BASELINE'&&align.baseline?.immutable_by_sha===true,'ALIGN_BASELINE_INVALID');
ok(f2.snapshot?.source_commit==='2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0','F2_HISTORICAL_SNAPSHOT_REWRITTEN');
ok(Array.isArray(f2.runtime?.chain)&&f2.runtime.chain.length===8,'F2_HISTORICAL_EVIDENCE_DRIFT');
ok(f2.rules?.default_observability_state==='UNKNOWN'&&f2.rules?.phi_pii_telemetry_allowed===false,'F2_POLICY_DRIFT');

function prBase(){try{return cp.execFileSync('git',['rev-parse','HEAD^1'],{cwd:ROOT,encoding:'utf8'}).trim()}catch(_){return ''}}
const base=prBase();
ok(/^[0-9a-f]{40}$/.test(align.current?.source_main||''),'ALIGN_CURRENT_SHA_INVALID');
if(base)ok(base===align.current.source_main,`ALIGN_CURRENT_BASE_DRIFT:${base}`);
ok(['REVALIDATING','ALIGNED'].includes(align.current?.status),'ALIGN_CURRENT_STATUS_INVALID');

// CURRENT runtime truth.
const rt=align.current.runtime;
ok(rt?.entrypoint==='app/server-phase-s-f17.js','CURRENT_ENTRYPOINT_DRIFT');
ok(rt?.railway_config==='app/railway.json'&&rt?.healthcheck_path==='/health','CURRENT_RUNTIME_POINTER_DRIFT');
ok(railway.deploy?.startCommand===rt.start_command,'RAILWAY_START_COMMAND_DRIFT');
ok(railway.deploy?.healthcheckPath===rt.healthcheck_path,'RAILWAY_HEALTHCHECK_DRIFT');
ok(f4.current_alignment_contract==='sentinel/maintenance/current-alignment-v1.json','F4_ALIGNMENT_POINTER_MISSING');
ok(f4.activation?.runtime_start_command===rt.start_command,'F4_START_COMMAND_DRIFT');
ok(rt.start_command.includes("--require ./sentinel-sentry-init.cjs")&&rt.start_command.endsWith('node server-phase-s-f17.js'),'SENTRY_PRELOAD_OR_ENTRYPOINT_DRIFT');
ok(!String(railway.build?.buildCommand||'').includes('NODE_OPTIONS'),'SENTRY_BUILD_PRELOAD_FORBIDDEN');
ok(Array.isArray(rt.chain)&&rt.chain.length===10,'CURRENT_CHAIN_LENGTH_DRIFT');
for(const p of rt.chain)ok(fs.existsSync(path.join(ROOT,p)),`CURRENT_CHAIN_FILE_MISSING:${p}`);
ok(rt.chain[0]==='app/server-phase-s-f17.js'&&rt.chain[1]==='app/server-phase-s.js'&&rt.chain[2]==='app/server-f17.js'&&rt.chain[9]==='app/server.js','CURRENT_CHAIN_ORDER_DRIFT');
ok(wrapper.includes("a[0]='server-f17.js'")&&wrapper.includes("require('./server-phase-s.js')"),'S152_WRAPPER_DRIFT');
ok(phaseS.includes("env:Object.assign({},process.env,{PORT:String(INNER_PORT)})"),'PHASE_S_ENV_INHERITANCE_DRIFT');
ok(f17.includes("spawn(process.execPath, ['server-f5.js']")&&f17.includes('env: Object.assign({}, process.env'),'F17_ENV_INHERITANCE_DRIFT');

// CURRENT public inventory. The old F2 count is not rewritten.
const html=fs.readdirSync(path.join(APP,'public')).filter(x=>x.endsWith('.html')).sort();
ok(html.length===align.current.public_surfaces?.html_count,`CURRENT_PUBLIC_HTML_DRIFT:${html.length}`);
ok(html.includes('admin-sentinel.html'),'CURRENT_SENTINEL_SURFACE_MISSING');
for(const p of align.current.public_surfaces?.sentinel_hub_assets||[])ok(fs.existsSync(path.join(ROOT,p)),`CURRENT_HUB_ASSET_MISSING:${p}`);

// Material F1/F3/F4 privacy and cost invariants remain active.
ok(pkg.dependencies?.['@sentry/node']==='10.70.0','SENTRY_SDK_PIN_DRIFT');
for(const t of ['Zero-PHI/PII','allowlist-first','Session Replay: **OFF**','attachments: **OFF**','pay-as-you-go: OFF'])ok(f1.includes(t),`F1_INVARIANT_MISSING:${t}`);
ok(f3.schema_version==='sentinel-telemetry-contract/v1'&&f3.design?.zero_phi_pii===true&&f3.design?.allowlist_first===true&&f3.design?.baggage_enabled===false,'F3_PRIVACY_DRIFT');
ok(f3.sampling?.defaults?.production===0,'F3_SAMPLING_DRIFT');
ok(f4.activation?.default_active===false&&f4.activation?.preload_scope==='runtime-command-only-not-global-railway-variable','F4_ACTIVATION_DRIFT');
ok(f4.privacy?.send_default_pii===false&&f4.privacy?.breadcrumbs===0&&f4.privacy?.logs===false&&f4.privacy?.local_variables===false&&f4.privacy?.session_replay===false&&f4.privacy?.attachments===false,'F4_PRIVACY_DRIFT');
ok(f4.sampling?.traces_sample_rate===0&&f4.cost?.incremental_cloud_budget_usd_month===0&&f4.cost?.pay_as_you_go===false,'F4_COST_OR_SAMPLING_DRIFT');
for(const t of ['sendDefaultPii: false','tracesSampleRate: 0','enableLogs: false','maxBreadcrumbs: 0','includeLocalVariables: false','beforeBreadcrumb: () => null','beforeSend: event => {'])ok(init.includes(t),`F4_SOURCE_GUARD_MISSING:${t}`);

const installed=path.join(APP,'node_modules/@sentry/node/package.json');
ok(fs.existsSync(installed)&&JSON.parse(fs.readFileSync(installed,'utf8')).version==='10.70.0','SENTRY_INSTALLED_VERSION_DRIFT');
process.env.SENTINEL_ENABLED='false';process.env.SENTINEL_SENTRY_ENABLED='false';
const telemetry=require(path.join(ROOT,'app/sentinel-sentry-init.cjs'));
ok(telemetry.status.requested===false&&telemetry.status.active===false,'F4_DEFAULT_OFF_FAILED');
const sanitized=telemetry.sanitizeEvent({level:'error',message:'ordinary diagnostic message',user:{id:'synthetic-user'},extra:{note:'synthetic'}});
ok(!('user' in sanitized)&&!('extra' in sanitized),'F4_SANITIZER_BOUNDARY_DRIFT');
ok(sanitized.message==='[REDACTED_MESSAGE]','F4_MESSAGE_REDACTION_DRIFT');

function changedFiles(){
  try{cp.execFileSync('git',['rev-parse','HEAD^2'],{cwd:ROOT,stdio:'ignore'});return cp.execFileSync('git',['diff','--name-only','HEAD^1','HEAD'],{cwd:ROOT,encoding:'utf8'}).split(/\r?\n/).filter(Boolean)}catch(_){return []}
}
const allowed=new Set([
  'docs/control/SENTINEL_V11_CURRENT_ALIGNMENT_IMPACT_REPORT_20260817.md',
  'docs/control/SENTINEL_V1_POST_CERTIFICATION_REVIEW_20260817.md',
  'sentinel/maintenance/current-alignment-v1.json',
  'sentinel/sentry/f4-contract.json',
  'ci/sentinel/phase4_sentry_current_alignment_contract.js',
  '.github/workflows/sentinel-phase4-sentry.yml',
  '.github/workflows/sentinel-phase9-alerting.yml',
  '.github/workflows/sentinel-phase13-hub.yml'
]);
const changed=changedFiles();
for(const p of changed)ok(allowed.has(p),`V11_SCOPE_UNEXPECTED_FILE:${p}`);
ok(!changed.some(p=>p.startsWith('supabase/migrations/')||p.startsWith('supabase/functions/')),'V11_DB_MUTATION_FORBIDDEN');

console.log(JSON.stringify({ok:true,certificate:'SENTINEL_F4_CURRENT_ALIGNMENT_PASS',baseline:align.baseline.status,current:align.current.status,current_source_main:align.current.source_main,runtime_entrypoint:rt.entrypoint,runtime_chain_files:rt.chain.length,public_html:html.length,sentry_preload_preserved:true,zero_phi_pii:true,pay_as_you_go:false,changed_files_checked:changed.length},null,2));
