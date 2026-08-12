import fs from 'node:fs';

function replaceOnce(file, oldText, newText, label){
  let text=fs.readFileSync(file,'utf8');
  const count=text.split(oldText).length-1;
  if(count!==1)throw new Error(`${label}: expected exactly 1 match, found ${count}`);
  text=text.replace(oldText,newText);
  fs.writeFileSync(file,text);
  console.log('patched:',label);
}

const calls='app/public/calls.js';
replaceOnce(calls,
  "_rpc('aos_siguiente_lead',{p_asesor:x.a,p_id_asesor:x.id,p_hoy:x.hoy},function(res){",
  "_rpc('aos_siguiente_lead_v2',{p_asesor:x.a,p_id_asesor:x.id,p_hoy:x.hoy},function(res){",
  'Call Center uses aos_siguiente_lead_v2');

replaceOnce(calls,
  "CC.lead={num:res.lead&&res.lead.num||'',trat:res.lead&&res.lead.trat||'',intento:res.lead&&res.lead.intento||1,rowNum:0,fecha:res.lead&&String(res.lead.fecha||''),wa:'https://api.whatsapp.com/send?phone=51'+((res.lead&&res.lead.num)||'').replace(/\\D/g,''),contexto:res.contexto||null};",
  "CC.lead={leadId:res.lead&&res.lead.id!=null?Number(res.lead.id):null,num:res.lead&&res.lead.num||'',trat:res.lead&&res.lead.trat||'',anuncio:res.lead&&res.lead.anuncio||((res.anuncio&&res.anuncio.nombre)||''),horaIngreso:res.lead&&res.lead.hora_ingreso||null,attributionSource:res.lead&&res.lead.attributionSource||'UNRESOLVED',intento:res.lead&&res.lead.intento||1,rowNum:0,fecha:res.lead&&String(res.lead.fecha||''),wa:'https://api.whatsapp.com/send?phone=51'+((res.lead&&res.lead.num)||'').replace(/\\D/g,''),contexto:res.contexto||null};",
  'CC.lead preserves exact touchpoint context');

replaceOnce(calls,
  "var adEl=document.getElementById('cc-anuncio');\n    if(res.anuncio&&res.anuncio.nombre){adEl.innerHTML='<b>'+escH(res.anuncio.nombre)+'</b>';adEl.style.display='block';}else{adEl.innerHTML='';adEl.style.display='none';}",
  "var adEl=document.getElementById('cc-anuncio');var adNombre=(res.anuncio&&res.anuncio.nombre)||CC.lead.anuncio||'';\n    if(adNombre){adEl.innerHTML='<b>'+escH(adNombre)+'</b>';adEl.style.display='block';}else{adEl.innerHTML='';adEl.style.display='none';}",
  'Call Center displays V2 lead ad');

replaceOnce(calls,
  "anuncio:CC.lead?CC.lead.anuncio||'':'',created_at:now.toISOString()};",
  "anuncio:CC.lead?CC.lead.anuncio||'':'',lead_id_origen:CC.lead&&CC.lead.leadId?CC.lead.leadId:null,created_at:now.toISOString()};",
  'regular call stores lead_id_origen');

replaceOnce(calls,
  "intento:CC.lead?(CC.lead.intento||0)+1:1,created_at:now.toISOString()};\n  var rowC={numero_limpio:numL",
  "intento:CC.lead?(CC.lead.intento||0)+1:1,anuncio:CC.lead?CC.lead.anuncio||'':'',lead_id_origen:CC.lead&&CC.lead.leadId?CC.lead.leadId:null,created_at:now.toISOString()};\n  var rowC={numero_limpio:numL",
  'confirmed-call row stores source lead');

replaceOnce(calls,
  "estado_cita:'PENDIENTE',origen_cita:'CALL_CENTER',ts_creado:now.toISOString()};",
  "estado_cita:'PENDIENTE',origen_cita:'CALL_CENTER',lead_id_origen:CC.lead&&CC.lead.leadId?CC.lead.leadId:null,ts_creado:now.toISOString()};",
  'appointment stores source lead');

replaceOnce(calls,
  "prox_rein:p.proxReintentoTs,created_at:now.toISOString()};",
  "prox_rein:p.proxReintentoTs,anuncio:CC.lead?CC.lead.anuncio||'':'',lead_id_origen:CC.lead&&CC.lead.leadId?CC.lead.leadId:null,created_at:now.toISOString()};",
  'follow-up call stores source lead');

replaceOnce(calls,
  'var rowS={"NUMERO":numL,"TRATAMIENTO":p.tratamiento||\'\',"ASESOR":x.a,"ID_ASESOR":x.id,"FECHA_PROGRAMADA":fecha,"HORA_PROGRAMADA":hora,"OBS_RECONTACTO":p.obs||\'\',"ESTADO":"PENDIENTE"};',
  'var rowS={"NUMERO":numL,"TRATAMIENTO":p.tratamiento||\'\',"ASESOR":x.a,"ID_ASESOR":x.id,"FECHA_PROGRAMADA":fecha,"HORA_PROGRAMADA":hora,"OBS_RECONTACTO":p.obs||\'\',"ESTADO":"PENDIENTE","lead_id_origen":CC.lead&&CC.lead.leadId?CC.lead.leadId:null};',
  'new follow-up stores source lead');

replaceOnce(calls,
  "CC.lead = {num:pl.num, trat:pl.trat||'', wa:'https://api.whatsapp.com/send?phone=51'+pl.num, rowNum:0, segId:pl.segId||'', fromSeg:true, intento:0, anuncio:''};",
  "CC.lead = {leadId:pl.leadId||null,num:pl.num, trat:pl.trat||'', wa:'https://api.whatsapp.com/send?phone=51'+pl.num, rowNum:0, segId:pl.segId||'', fromSeg:true, intento:0, anuncio:pl.anuncio||'',horaIngreso:pl.horaIngreso||null,attributionSource:pl.attributionSource||'FOLLOWUP'};",
  'pending follow-up can propagate V2 context');

const marketing='app/public/admin-marketing.html';
let mh=fs.readFileSync(marketing,'utf8');
if(!mh.includes('admin-marketing-v2.js')){
  const pos=mh.lastIndexOf('</script>');
  if(pos<0)throw new Error('Marketing bootstrap: closing script not found');
  const boot=`\n/* Marketing Attribution V2 modular bootstrap */\n(function(){\n  window.__AOS_MARKETING_V2_LOADED=false;\n  var old=document.getElementById('aos-marketing-v2-adapter');if(old)old.remove();\n  var s=document.createElement('script');s.id='aos-marketing-v2-adapter';\n  s.src='/admin-marketing-v2.js?v='+(typeof _APP_VERSION!=='undefined'?_APP_VERSION:Date.now());\n  document.head.appendChild(s);\n})();\n`;
  mh=mh.slice(0,pos)+boot+mh.slice(pos);
  fs.writeFileSync(marketing,mh);
  console.log('patched: Marketing V2 bootstrap');
}else{
  console.log('skip: Marketing V2 bootstrap already present');
}

console.log('Marketing Attribution V2 frontend patch complete');
