'use strict';
const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8').replace(/\r\n/g,'\n')}
function write(p,s){fs.writeFileSync(p,s,'utf8')}
function die(m){throw new Error(m)}
function insertBeforeBody(p,tag){let s=read(p);if(s.includes(tag))return;const i=s.toLowerCase().lastIndexOf('</body>');if(i<0)die(p+' body anchor missing');write(p,s.slice(0,i)+tag+'\n'+s.slice(i))}

// 1) CURRENT runtime: K1 wraps Phase S, which preserves F5->WA4->WA3->WA2->F4.
{
  const p='app/server-k1.js';let s=read(p);
  s=s.replace("spawn(process.execPath,['server-f5.js']","spawn(process.execPath,['server-phase-s.js']");
  if(!s.includes("spawn(process.execPath,['server-phase-s.js']"))die('K1 Phase S child missing');
  if(s.includes("spawn(process.execPath,['server-f5.js']"))die('stale direct F5 K1 child survived');
  write(p,s);
}

// 2) Railway keeps Sentinel preload but enters K1 first; Nixpacks agrees.
{
  const p='app/railway.json';const j=JSON.parse(read(p));
  j.build=j.build||{};
  j.build.buildCommand="echo 'Skip build — K1 CURRENT chain: server-k1.js -> server-phase-s.js -> server-f5.js -> server-wa4.js -> server-wa3.js -> server-wa2.js -> server-f4.js'";
  j.deploy=j.deploy||{};
  j.deploy.startCommand="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-k1.js";
  write(p,JSON.stringify(j,null,2)+'\n');
  const n='app/nixpacks.toml';let s=read(n);s=s.replace(/cmd = "node [^"]+"/, 'cmd = "node server-k1.js"');write(n,s);
}

// 3) Provider verify token must never be committed as a live secret.
{
  const p='app/server.js';let s=read(p);
  s=s.replace(/const VERIFY_TOKEN = ['"][^'"\n]+['"]/,"const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'");
  if(!s.includes("const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'"))die('VERIFY_TOKEN env boundary missing');
  write(p,s);
}

// 4) Browser boundary is committed statically on the CURRENT HTML, never by build mutation.
const tag='<script src="/k1-browser-security.js"></script>';
insertBeforeBody('app/public/app.html',tag);
insertBeforeBody('app/public/cerebro.html',tag);
{
  const p='app/public/cerebro.html';let s=read(p);
  s=s.replace(/\nconnectRT\(\);\n/,'\n/* K1: direct audit Realtime disabled; sanitized polling remains. */\n');
  write(p,s);
}
{
  const p='app/public/admin-team.html';let s=read(p);
  s=s.replace(/sessionStorage\.getItem\('aos_si_token'\)/g,"sessionStorage.getItem('aos_app_token')");
  s=s.replace(/pw\.length<6/g,'pw.length<10').replace(/np\.length<6/g,'np.length<10');
  s=s.replace(/Mínimo 6 caracteres/g,'Mínimo 10 caracteres').replace(/mínimo 6 caracteres/g,'mínimo 10 caracteres').replace(/Contraseña mínimo 6 caracteres/g,'Contraseña mínimo 10 caracteres');
  if(s.includes('aos_si_token'))die('alternate Sales Intelligence token survived CURRENT admin-team');
  write(p,s);
}

// 5) K1-A bootstraps the private provider vault itself so chronological fresh replay is valid.
{
  const p='supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql';let s=read(p);
  const marker='-- K1 CURRENT private provider vault bootstrap.';
  if(!s.includes(marker)){
    const anchor='begin;\n'; if(!s.includes(anchor))die('K1-A begin anchor missing');
    const block=`\n-- K1 CURRENT private provider vault bootstrap.\n-- This makes K1 valid on both CURRENT production (table already exists) and\n-- chronological fresh migration replay before the later WA4 boundary migration.\ncreate table if not exists public.aos_integration_secrets_v1 (\n  integration_id uuid primary key references public.aos_integraciones(id) on delete cascade,\n  tipo text not null,\n  nombre text not null,\n  api_key text not null default '',\n  api_secret text not null default '',\n  captured_at timestamptz not null default now(),\n  updated_at timestamptz not null default now()\n);\ncreate index if not exists aos_integration_secrets_v1_tipo_idx on public.aos_integration_secrets_v1(lower(tipo));\nalter table public.aos_integration_secrets_v1 enable row level security;\nalter table public.aos_integration_secrets_v1 force row level security;\nrevoke all on table public.aos_integration_secrets_v1 from public,anon,authenticated;\ngrant select,insert,update on table public.aos_integration_secrets_v1 to service_role;\ninsert into public.aos_integration_secrets_v1(integration_id,tipo,nombre,api_key,api_secret,captured_at,updated_at)\nselect id,tipo,nombre,coalesce(api_key,''),coalesce(api_secret,''),now(),now()\nfrom public.aos_integraciones\nwhere coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>''\non conflict(integration_id) do update\nset tipo=excluded.tipo,nombre=excluded.nombre,\n    api_key=case when excluded.api_key<>'' then excluded.api_key else public.aos_integration_secrets_v1.api_key end,\n    api_secret=case when excluded.api_secret<>'' then excluded.api_secret else public.aos_integration_secrets_v1.api_secret end,\n    updated_at=now();\nupdate public.aos_integraciones set api_key='',api_secret='',updated_at=now()\nwhere coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>'';\n`;
    s=s.replace(anchor,anchor+block);
  }
  if(!s.includes('from public.aos_integration_secrets_v1 s'))die('K1-A does not consume private vault');
  write(p,s);
}

// 6) Runtime validator now reflects the real CURRENT chain.
// The final v4 generator writes the authoritative Python contracts.

// 7) F5 historical contract recognizes K1->Phase S->F5 without weakening F5 controls.
{
  const p='ci/phase5-historical-identity/f5_upload_contract.js';let s=read(p);
  if(!s.includes("const k1=fs.existsSync('app/server-k1.js')")){
    s=s.replace("const phaseS=fs.existsSync('app/server-phase-s.js')?fs.readFileSync('app/server-phase-s.js','utf8'):'';", "const phaseS=fs.existsSync('app/server-phase-s.js')?fs.readFileSync('app/server-phase-s.js','utf8'):'';\nconst k1=fs.existsSync('app/server-k1.js')?fs.readFileSync('app/server-k1.js','utf8'):'';");
  }
  // npm start is not the production authority anymore (CURRENT uses Railway), but it must remain a valid server entry.
  s=s.replace("ok(pkg.scripts.start==='node server-f5.js','npm start must enter F5 wrapper');", "ok(/^node server-[a-z0-9-]+\\.js$/i.test(String(pkg.scripts.start||'')),'npm start must remain a valid Ascenda server entry');");
  const old=`const sentinelPhaseS="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js";\nconst directF5=start==='node server-f5.js';\nconst phaseSEntry=start==='node server-phase-s.js'||start===sentinelPhaseS;\nconst phaseSWrapped=phaseSEntry&&phaseS.includes("['server-f5.js']")&&phaseS.includes('proxy(req,res)');\nok(directF5||phaseSWrapped,'Railway must enter F5 directly or through certified Phase S wrapper');`;
  const neu=`const sentinelPhaseS="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js";\nconst sentinelK1="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-k1.js";\nconst directF5=start==='node server-f5.js';\nconst phaseSEntry=start==='node server-phase-s.js'||start===sentinelPhaseS;\nconst phaseSWrapped=phaseSEntry&&phaseS.includes("['server-f5.js']")&&phaseS.includes('proxy(req,res)');\nconst k1Wrapped=start===sentinelK1&&k1.includes("['server-phase-s.js']")&&phaseS.includes("['server-f5.js']")&&phaseS.includes('proxy(req,res)');\nok(directF5||phaseSWrapped||k1Wrapped,'Railway must enter F5 directly, through Phase S, or through certified K1 -> Phase S');`;
  if(s.includes(old))s=s.replace(old,neu);
  if(!s.includes('const k1Wrapped='))die('F5 K1/Phase S recognition missing');
  s=s.replace("if(start===sentinelPhaseS){", "if(start===sentinelPhaseS||start===sentinelK1){");
  if(!s.includes("server-k1.js"))die('F5 contract lacks K1 entry');
  write(p,s);
}

console.log('KRONIA_K1_CURRENT_V4_PORT_ADAPTER=PASS');
