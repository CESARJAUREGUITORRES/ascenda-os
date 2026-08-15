import fs from 'node:fs';

const path = 'app/public/calls.js';
let src = fs.readFileSync(path, 'utf8');

const oldLoad = `    var arr=Array.isArray(rows)?rows:[];\n    var items=arr.map(function(s){var fecha=String(s.fecha_prog||'').slice(0,10),hora=String(s.hora_prog||'').slice(0,5);var venc=fecha&&fecha<x.hoy,esHoy=fecha===x.hoy;return{segId:s.id||'',num:s.numero||'',trat:s.tratamiento||'',obs:s.obs||'',fecha:fecha,hora:hora,fechaHora:fecha?(fecha+(hora?' '+hora:'')):'' ,vencido:venc&&!esHoy,esHoy:esHoy,whatsapp:s.whatsapp||('https://api.whatsapp.com/send?phone=51'+(s.numero||'').replace(/\\D/g,''))};});`;
const newLoad = `    var arr=Array.isArray(rows)?rows:(rows&&Array.isArray(rows.items)?rows.items:[]);\n    var items=arr.map(function(s){var fecha=String(s.fecha||s.fecha_prog||'').slice(0,10),hora=String(s.hora||s.hora_prog||'').slice(0,5);var venc=fecha&&fecha<x.hoy,esHoy=fecha===x.hoy;var num=s.num||s.numero||'';return{segId:s.segId||s.id||'',leadId:s.leadId!=null?s.leadId:(s.lead_id_origen!=null?s.lead_id_origen:null),num:num,trat:s.trat||s.tratamiento||'',obs:s.obs||s.obs_recontacto||'',fecha:fecha,hora:hora,fechaHora:fecha?(fecha+(hora?' '+hora:'')):'' ,vencido:venc&&!esHoy,esHoy:esHoy,whatsapp:s.whatsapp||('https://api.whatsapp.com/send?phone=51'+String(num).replace(/\\D/g,''))};});`;

const oldRender = `    var sid=escH(s.segId||''),snum=escH(s.num||'—'),wa=escH(s.whatsapp||('https://api.whatsapp.com/send?phone=51'+(s.num||'').replace(/[^0-9]/g,'')));`;
const newRender = `    var sid=escH(s.segId||''),snum=escH(s.num||'—'),leadId=s.leadId!=null?String(s.leadId):'',trat=escH(s.trat||''),wa=escH(s.whatsapp||('https://api.whatsapp.com/send?phone=51'+(s.num||'').replace(/[^0-9]/g,'')));`;

const oldButton = `<button data-num="'+snum+'" onclick="segLlamar(this)"`;
const newButton = `<button data-num="'+snum+'" data-segid="'+sid+'" data-leadid="'+escH(leadId)+'" data-trat="'+trat+'" onclick="segLlamar(this)"`;

const oldCall = `function segLlamar(b){var num=b.getAttribute('data-num');if(!num)return;CC.lead={num:num,trat:'',wa:'https://api.whatsapp.com/send?phone=51'+num.replace(/[^0-9]/g,''),rowNum:0};document.getElementById('cc-num').textContent=num;document.getElementById('cc-tier').textContent='SEGUIM.';document.getElementById('cc-no-lead').style.display='none';document.getElementById('cc-lead-panel').style.display='block';document.getElementById('cc-tipif').value='';cargarNombrePaciente(num);}`;
const newCall = `function segLlamar(b){var num=b.getAttribute('data-num');if(!num)return;var lid=b.getAttribute('data-leadid'),sid=b.getAttribute('data-segid'),trat=b.getAttribute('data-trat')||'';CC.lead={leadId:lid?Number(lid):null,num:num,trat:trat,wa:'https://api.whatsapp.com/send?phone=51'+num.replace(/[^0-9]/g,''),rowNum:0,segId:sid||'',fromSeg:true,intento:0,anuncio:'',horaIngreso:null,attributionSource:lid?'FOLLOWUP_EXACT':'UNRESOLVED'};document.getElementById('cc-num').textContent=num;document.getElementById('cc-trat').textContent=trat;document.getElementById('cc-meta').textContent='SEGUIMIENTO';document.getElementById('cc-tier').textContent='SEGUIM.';document.getElementById('cc-no-lead').style.display='none';document.getElementById('cc-lead-panel').style.display='block';document.getElementById('cc-tipif').value='';cargarNombrePaciente(num);}`;

const replacements = [[oldLoad,newLoad,'loadSegsPanel adapter'],[oldRender,newRender,'render metadata'],[oldButton,newButton,'button metadata'],[oldCall,newCall,'segLlamar propagation']];
let changed = false;
for (const [oldText,newText,label] of replacements) {
  if (src.includes(newText)) continue;
  if (!src.includes(oldText)) throw new Error(`Expected source not found: ${label}`);
  src = src.replace(oldText,newText);
  changed = true;
}
if (!changed) {
  console.log('already patched');
  process.exit(0);
}
fs.writeFileSync(path, src);
console.log('patched calls.js');
