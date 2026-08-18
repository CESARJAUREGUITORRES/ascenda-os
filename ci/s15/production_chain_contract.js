'use strict'
const fs=require('fs'),path=require('path')
const root=path.resolve(__dirname,'../..')
const bootstrapPath=path.join(root,'app/server-phase-s-f17.js')
const f17Path=path.join(root,'app/server-f17.js')
const bootstrap=fs.readFileSync(bootstrapPath,'utf8')
const phaseS=fs.readFileSync(path.join(root,'app/server-phase-s.js'),'utf8')
const f17=fs.readFileSync(f17Path,'utf8')
const f5=fs.readFileSync(path.join(root,'app/server-f5.js'),'utf8')
const railway=JSON.parse(fs.readFileSync(path.join(root,'app/railway.json'),'utf8'))
function ok(v,m){if(!v){console.error('S15.3 PRODUCTION CHAIN CONTRACT FAIL:',m);process.exit(1)}}

ok(railway.deploy&&String(railway.deploy.startCommand||'').includes('node server-phase-s-f17.js'),'Railway must start S15.2 bootstrap')
ok(String(railway.build&&railway.build.buildCommand||'').includes('server-phase-s.js -> server-f17.js -> server-f5.js'),'Railway chain documentation must show Phase S -> F17 -> F5')
ok(bootstrap.includes("a[0]==='server-f5.js'")&&bootstrap.includes("a[0]='server-f17.js'"),'bootstrap must rewrite only Phase S F5 child to F17')
ok(bootstrap.includes("require('./server-phase-s.js')"),'bootstrap must preserve certified Phase S runtime')
ok(bootstrap.includes('command===process.execPath'),'spawn rewrite must be constrained to Node child process')
ok(phaseS.includes("spawn(process.execPath,['server-f5.js']"),'Phase S expected child anchor changed; reassess bootstrap')
ok(f17.includes("child = spawn(process.execPath, ['server-f5.js']"),'F17 must delegate downstream to F5')
ok(f5.includes("child=spawn(process.execPath,['server-wa4.js']"),'F5 must preserve WA4 downstream chain')
ok(f17.includes("url.pathname === '/api/notifications/health'"),'F17 notification health endpoint missing from production boundary')
ok(f17.includes("url.pathname === '/api/notifications/inbox'"),'F17 actor-bound notification inbox missing from production boundary')
ok(f17.includes("url.pathname === '/api/push/config'"),'S14 Push boundary missing from F17')
ok(f17.includes('const headers = bufferedProxyHeaders(req, raw)'),'buffered routes must use canonical HTTP framing helper')

const bootstrapMod=require(bootstrapPath)
const original=['server-f5.js','--example']
const rewritten=bootstrapMod.rewriteChildArgs(process.execPath,original)
ok(original[0]==='server-f5.js','rewrite helper must not mutate caller args')
ok(rewritten[0]==='server-f17.js'&&rewritten[1]==='--example','rewrite helper must preserve remaining args')
const untouched=bootstrapMod.rewriteChildArgs(process.execPath,['server-wa4.js'])
ok(untouched[0]==='server-wa4.js','rewrite helper must not touch non-F5 child')

const f17Mod=require(f17Path)
const raw=Buffer.from('{"object":"whatsapp_business_account"}','utf8')
const signature='sha256='+('a'.repeat(64))
const framed=f17Mod.bufferedProxyHeaders({headers:{
  'transfer-encoding':'chunked',
  connection:'keep-alive, x-hop-test',
  'keep-alive':'timeout=5',
  'x-hop-test':'remove-me',
  'content-type':'application/json',
  'x-hub-signature-256':signature
}},raw)
ok(!Object.prototype.hasOwnProperty.call(framed,'transfer-encoding'),'buffered proxy must never forward Transfer-Encoding with Content-Length')
ok(!Object.prototype.hasOwnProperty.call(framed,'connection'),'buffered proxy must strip Connection')
ok(!Object.prototype.hasOwnProperty.call(framed,'keep-alive'),'buffered proxy must strip Keep-Alive')
ok(!Object.prototype.hasOwnProperty.call(framed,'x-hop-test'),'buffered proxy must strip Connection-nominated hop-by-hop headers')
ok(Number(framed['content-length'])===raw.length,'buffered proxy must set exact byte Content-Length')
ok(framed['x-hub-signature-256']===signature,'Meta signature header must survive framing canonicalization')
ok(framed['content-type']==='application/json','end-to-end content metadata must survive framing canonicalization')

console.log('S15.3 production runtime + buffered HTTP framing contract PASS')
