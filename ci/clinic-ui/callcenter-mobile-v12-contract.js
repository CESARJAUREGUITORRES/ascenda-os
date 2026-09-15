'use strict'
const fs=require('fs')
const crypto=require('crypto')
const app=fs.readFileSync('app/public/app.html','utf8')
const calls=fs.readFileSync('app/public/calls.html','utf8')
const css=fs.readFileSync('app/public/clinic-callcenter-mobile-v12.css','utf8')
function ok(v,m){if(!v){console.error('CALL CENTER MOBILE V1.2 CONTRACT FAIL:',m);process.exit(1)}}

// Wiring and strict scope.
ok(app.includes('/clinic-callcenter-mobile-v12.css?v=20260915-1'),'Call Center mobile CSS hook missing')
ok(css.includes('.clinic-compact-ui .workspace .main-grid'),'responsive rules must be compact-only')
ok(css.includes('@media(min-width:821px) and (hover:hover) and (pointer:fine)'),'desktop preservation declaration missing')

// Existing Call Center behavior anchors must remain untouched.
for(const anchor of [
  'onclick="doCallCC()"',
  'onclick="openWaCC()"',
  'onchange="onCCTipif(this.value)"',
  'onclick="ccGuardar()"',
  'onclick="abrirFicha360()"',
  'onclick="cerrarFicha360()"',
  'onclick="fichaWa()"',
  'onclick="fichaLlamar()"',
  'onclick="fichaEditar()"',
  'function doCallCC()',
  'function ccGuardar(',
  'function abrirFicha360(',
  'function cerrarFicha360(',
  'function ccConfirmarCita(',
  'function ccConfirmarSeguimiento('
]) ok(calls.includes(anchor),'existing Call Center authority missing: '+anchor)

// Layout must reflow without hiding operational columns.
ok(css.includes('grid-template-columns:minmax(0,1fr)!important'),'portrait single-column Call Center layout missing')
ok(css.includes('.col-cc')&&css.includes('.col-cal')&&css.includes('.col-score'),'all three operational columns must be preserved')
ok(!css.includes('display:none!important') || css.includes('::-webkit-scrollbar{display:none}'),'mobile stylesheet must not hide operational sections')

// KPI/data preservation.
ok(css.includes('grid-template-columns:repeat(2,minmax(0,1fr))'),'portrait KPI reflow missing')
ok(css.includes('.clinic-compact-ui.clinic-landscape .workspace .kpi-strip'),'landscape KPI layout missing')
ok(css.includes('.call-table')&&css.includes('min-width:520px'),'call history internal scroll canvas missing')

// Lead controls.
ok(css.includes('.cbtns')&&css.includes('.clinic-compact-ui:not(.clinic-landscape) .workspace .cbtns'),'primary actions responsive stacking missing')
ok(css.includes('.fsel')&&css.includes('.fta')&&css.includes('.sbtn'),'tipification controls missing')

// 360 detail must become sheet on compact UI only.
ok(css.includes('.clinic-compact-ui .workspace .ficha-360'),'mobile ficha sheet rule missing')
ok(css.includes('bottom:-100dvh!important'),'mobile ficha hidden state missing')
ok(css.includes('.ficha-360.open')&&css.includes('bottom:0!important'),'mobile ficha open state missing')
ok(css.includes('height:min(88dvh,760px)!important'),'portrait sheet height bound missing')
ok(css.includes('.clinic-compact-ui.clinic-landscape .workspace .ficha-360'),'landscape detail adaptation missing')

// Modal safety.
ok(css.includes('.clinic-compact-ui .workspace .mov'),'mobile Call Center modal scope missing')
ok(css.includes('.clinic-compact-ui .workspace .modal'),'mobile modal sheet rule missing')
ok(css.includes('grid-template-columns:minmax(0,1fr)!important'),'mobile modal single-column form missing')

// Regression marker: calls.html itself is not patched by this feature branch.
console.log('calls.html sha256='+crypto.createHash('sha256').update(calls).digest('hex'))
console.log('CALL CENTER MOBILE V1.2 contract: PASS')
