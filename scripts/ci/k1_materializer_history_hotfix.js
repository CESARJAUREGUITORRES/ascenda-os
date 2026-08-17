'use strict';
const fs=require('fs');
const p='scripts/ci/k1_materialize_current.js';
let s=fs.readFileSync(p,'utf8').replace(/\r\n/g,'\n');
const oldLine=`  s=s.replace("            if (Array.isArray(data.historial)) state.historial = data.historial;\\n",'');`;
const newLine=`  s=s.replace(/^\\s*if \\(Array\\.isArray\\(data\\.historial\\)\\) state\\.historial = data\\.historial;\\s*$/gm,'');`;
if(!s.includes(newLine)){
  if(!s.includes(oldLine)) throw new Error('Chrome history materializer anchor missing');
  s=s.replace(oldLine,newLine);
}
if(!s.includes("s=s.replace(/^\\s*if \\(Array\\.isArray\\(data\\.historial\\)\\)")) throw new Error('global Chrome history scrub not installed');
fs.writeFileSync(p,s,'utf8');
console.log('KRONIA_K1_CHROME_HISTORY_MATERIALIZER_HOTFIX=PASS');
