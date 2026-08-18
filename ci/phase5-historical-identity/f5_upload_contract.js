const fs=require('fs');
function ok(c,m){if(!c)throw new Error(m)}
const srv=fs.readFileSync('app/server-f5.js','utf8');
const phaseS=fs.existsSync('app/server-phase-s.js')?fs.readFileSync('app/server-phase-s.js','utf8'):'';
const f17=fs.existsSync('app/server-f17.js')?fs.readFileSync('app/server-f17.js','utf8'):'';
const s152=fs.existsSync('app/server-phase-s-f17.js')?fs.readFileSync('app/server-phase-s-f17.js','utf8'):'';
const mod=fs.readFileSync('app/f5-historical-upload.js','utf8');
const html=fs.readFileSync('app/public/admin-f5-historical.html','utf8');
const rail=JSON.parse(fs.readFileSync('app/railway.json','utf8'));
const pkg=JSON.parse(fs.readFileSync('app/package.json','utf8'));
ok(srv.includes("p_required_panel:'admin-import-ventas'"),'F5 upload must require authorized import panel');
ok(srv.includes('p_require_2fa:true'),'F5 upload must require 2FA');
ok(srv.includes("'/api/f5/historical-upload'"),'upload route missing');
ok(srv.includes('manifestBySha(normalized.sourceSha)'),'exact SHA manifest check missing');
ok(srv.includes('SOURCE_FILENAME_SHA_MISMATCH'),'filename/SHA binding missing');
ok(srv.includes('SOURCE_MANIFEST_COUNT_MISMATCH'),'row/column manifest count check missing');
ok(srv.includes("serviceRpc('aos_f5_ingest_source_rows_v1'"),'private ingest RPC missing');
ok(srv.includes('normalized.rows.slice(i,i+500)'),'bounded staging chunks missing');
ok(!srv.includes('console.log(buffer)')&&!srv.includes('console.log(normalized.rows)'),'PII must not be logged');
ok(mod.includes('MAX_FILE_BYTES=12*1024*1024'),'file size bound missing');
ok(mod.includes('const HEADERS=[')&&mod.includes("'Último presupuesto'"),'schema allowlist missing');
ok(mod.includes('row_content_hash')&&mod.includes('identity_seed_hash'),'row provenance hashes missing');
ok(html.includes('X-AOS-App-Token')&&html.includes('X-AOS-Source-Filename'),'admin upload headers missing');
ok(html.includes('No crea pacientes')&&html.includes('no fusiona identidades'),'safety disclosure missing');
ok(pkg.dependencies&&pkg.dependencies.exceljs==='4.4.0','ExcelJS version must be pinned');
ok(pkg.scripts.start==='node server-f5.js'||pkg.scripts.start==='node server-f17.js','npm start must enter F5 directly or through F17 wrapper');
const start=rail.deploy.startCommand;
const sentinelPhaseS="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js";
const sentinelS152="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js";
const directF5=start==='node server-f5.js';
const phaseSEntry=start==='node server-phase-s.js'||start===sentinelPhaseS;
const phaseSWrapped=phaseSEntry&&phaseS.includes("['server-f5.js']")&&phaseS.includes('proxy(req,res)');
const s152Entry=start==='node server-phase-s-f17.js'||start===sentinelS152;
const s152Wrapped=s152Entry&&s152.includes("a[0]==='server-f5.js'")&&s152.includes("a[0]='server-f17.js'")&&s152.includes("require('./server-phase-s.js')")&&phaseS.includes("['server-f5.js']")&&phaseS.includes('proxy(req,res)')&&f17.includes("['server-f5.js']");
ok(directF5||phaseSWrapped||s152Wrapped,'Railway must enter F5 directly, through certified Phase S, or through S15.2 Phase S -> F17 -> F5 wrapper');
if(start===sentinelPhaseS||start===sentinelS152){
  ok(rail.build&&!String(rail.build.buildCommand).includes('NODE_OPTIONS'),'Sentinel preload must not contaminate build');
}
if(phaseSWrapped||s152Wrapped){
  ok(String(rail.build.buildCommand).includes('server-phase-s.js'),'Phase S chain declaration missing');
  ok(String(rail.build.buildCommand).includes('server-f5.js'),'F5 chain declaration missing');
}
if(s152Wrapped){
  ok(String(rail.build.buildCommand).includes('server-f17.js'),'F17 chain declaration missing');
  ok(String(rail.build.buildCommand).includes('server-phase-s-f17.js'),'S15.2 bootstrap chain declaration missing');
}
ok(String(rail.build.buildCommand).includes('server-wa4.js'),'WA4 chain declaration missing');
console.log('F5 secure XLSX upload contract: PASS');