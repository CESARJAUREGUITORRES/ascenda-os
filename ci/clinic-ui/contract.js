'use strict'
const fs=require('fs')
const app=fs.readFileSync('app/public/app.html','utf8')
const ui=fs.readFileSync('app/public/clinic-ui-v1.css','utf8')
const shell=fs.readFileSync('app/public/clinic-shell-ui-v1.js','utf8')
const login=fs.readFileSync('app/public/login.html','utf8')
const loginCss=fs.readFileSync('app/public/clinic-login-v4.css','utf8')
const home=fs.readFileSync('app/public/admin-home.html','utf8')
function ok(v,m){if(!v){console.error('CLINIC UI V1.1 CONTRACT FAIL:',m);process.exit(1)}}

// Existing navigation/functionality authority must remain unchanged.
ok(app.includes("document.getElementById('tb-brand').addEventListener('click'"),'drawer logo click authority missing')
ok(app.includes("classList.toggle('col', AOS.collapsed)"),'drawer collapse behavior missing')
ok(app.includes("var VIEW_MAP = {"),'view map missing')
for(const id of ['admin-home','admin-calls','admin-sales','admin-team','admin-agenda','admin-patients','admin-caja','admin-cartera','admin-inventario']){
  ok(app.includes("'"+id+"'"),'panel route missing: '+id)
}

// Compact-device detection must include phone landscape, not width-only mobile.
ok(shell.includes("(max-width:1200px)"),'touch-landscape width bound missing')
ok(shell.includes("(pointer:coarse)")&&shell.includes("(hover:none)"),'touch device detection missing')
ok(shell.includes("clinic-compact-ui"),'compact UI root class missing')
ok(shell.includes("clinic-landscape"),'landscape root class missing')

// Desktop must keep original composition; home hero is compact-only.
ok(shell.includes("if(!isCompactDevice())"),'desktop hero removal gate missing')
ok(ui.includes("html:not(.clinic-compact-ui) .workspace{background:var(--bg)!important}"),'desktop workspace rollback missing')
ok(ui.includes(".clinic-home-hero{display:none}"),'home hero must be off by default')
ok(ui.includes(".clinic-compact-ui .clinic-home-hero"),'home hero compact scope missing')

// Critical mobile overflow fix.
ok(ui.includes("flex:1 1 0!important"),'workspace flex remainder fix missing')
ok(ui.includes("width:auto!important"),'workspace must not be viewport width')
ok(ui.includes("max-width:calc(100vw - var(--swc))"),'collapsed drawer workspace bound missing')
ok(ui.includes(".sidebar:not(.col) + .workspace"),'expanded drawer workspace bound missing')

// Home content must reflow, not disappear.
ok(ui.includes(".clinic-compact-ui .workspace .ah-c3")&&ui.includes("display:flex!important"),'home third column must remain visible')
ok(ui.includes(".clinic-compact-ui .workspace .ah-grid")&&ui.includes("grid-template-columns:minmax(0,1fr)!important"),'vertical home stacking missing')
ok(ui.includes(".clinic-compact-ui.clinic-landscape .workspace .ah-grid"),'touch-landscape home layout missing')
ok(ui.includes("overflow-x:auto!important"),'preserving overflow scroll missing')
ok(home.includes("@media(max-width:900px){.ah-grid{grid-template-columns:1fr;}.ah-c3{display:none;}}"),'legacy home rule unexpectedly rewritten')

// Login brand canary.
ok(loginCss.includes(".brand .clinic-wordmark-text"),'wordmark override missing')
ok(loginCss.includes("color:#fff!important"),'Ascenda word must be white')
ok(loginCss.includes("gap:3px!important"),'Ascenda Clinic spacing correction missing')
ok(loginCss.includes("strong{")&&loginCss.includes("color:var(--clinic-mint)!important"),'Clinic accent missing')
ok(loginCss.includes("repeating-linear-gradient"),'tech hero layer missing')
ok(login.includes('/clinic-login-v4.css?v=20260915-4'),'login visual cache-bust missing')
ok(app.includes('/clinic-ui-v1.css?v=20260915-2'),'shell visual cache-bust missing')
ok(app.includes('/clinic-shell-ui-v1.js?v=20260915-2'),'shell adapter cache-bust missing')

console.log('CLINIC UI V1.1 responsive canary contract: PASS')
