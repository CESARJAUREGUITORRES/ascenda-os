import fs from 'node:fs';

const htmlPath='app/public/calls.html';
const jsPath='app/public/calls-loop6.js';
const callsJsPath='app/public/calls.js';
const marker='<script src="/calls-loop6.js?v=20260821-loop6-v2.2"></script>';
const oldMarkers=[
  '<script src="/calls-loop6.js?v=20260821-loop6"></script>',
  '<script src="/calls-loop6-policy-v2.js?v=20260821-loop6-policy-v2"></script>'
];
const anchor='<!-- KronIA Chat — en app.html (persistente entre paneles) -->';
const guard="if(window.__AOS_CC_LOOP6_V2__!=='v2.2'){alert('ASCENDA Call Center se actualizó. Recarga esta pantalla antes de registrar una cita.');return;}";

function patchLegacy(path){
  let text=fs.readFileSync(path,'utf8');
  let changed=false;
  for(const sig of ['function ccConfirmarCita(){','function guardarCitaManual(){']){
    const guarded=`${sig}\n  ${guard}`;
    const guardedCr=`${sig}\r\n  ${guard}`;
    if(text.includes(guarded)||text.includes(guardedCr)) continue;
    if(!text.includes(sig)) throw new Error(`Loop6 legacy function not found in ${path}: ${sig}`);
    text=text.replace(sig,`${sig}\n  ${guard}`);
    changed=true;
  }
  if(changed) fs.writeFileSync(path,text,'utf8');
}

let html=fs.readFileSync(htmlPath,'utf8');
let htmlChanged=false;
for(const old of oldMarkers){
  if(html.includes(old)){
    html=html.split(old+'\n').join('').split(old+'\r\n').join('').split(old).join('');
    htmlChanged=true;
  }
}
const count=html.split(marker).length-1;
if(count>1) throw new Error(`LOOP6 v2.2 loader duplicated: ${count}`);
if(count===0){
  if(!html.includes(anchor)) throw new Error('LOOP6 loader anchor not found');
  html=html.replace(anchor,`${marker}\n${anchor}`);
  htmlChanged=true;
}
if(htmlChanged) fs.writeFileSync(htmlPath,html,'utf8');

patchLegacy(htmlPath);
patchLegacy(callsJsPath);

let runtime=fs.readFileSync(jsPath,'utf8');
const bootRe=/if\(window\.__AOS_CC_LOOP6_V2__\) return;\r?\nwindow\.__AOS_CC_LOOP6_V2__='v2';/;
if(bootRe.test(runtime)){
  runtime=runtime.replace(bootRe,"window.__AOS_CC_LOOP6_V2__='v2.2';");
  fs.writeFileSync(jsPath,runtime,'utf8');
}else if(!runtime.includes("window.__AOS_CC_LOOP6_V2__='v2.2';")){
  throw new Error('Loop6 runtime bootstrap signature not found');
}

console.log('LOOP6_V22_PATCH=OK');
