'use strict';
const fs=require('fs');

function replaceOnce(path,needle,replacement){
  let s=fs.readFileSync(path,'utf8');
  const i=s.indexOf(needle);
  if(i<0)throw new Error('needle not found in '+path+': '+needle.slice(0,120));
  if(s.indexOf(needle,i+needle.length)>=0)throw new Error('needle not unique in '+path);
  s=s.slice(0,i)+replacement+s.slice(i+needle.length);
  fs.writeFileSync(path,s);
}

replaceOnce(
  'app/server-phase-s.js',
  "function proxyVerify(req,res){",
  `async function handleCustomerWindowSend(req,res,p){\n  const a=await actor(req);\n  if(!a)return writeJson(res,403,{ok:false,error:'WA3_2FA_PANEL_REQUIRED'});\n  const m=String(p||'').match(/^\\/api\\/wa3\\/conversations\\/([0-9a-f-]{36})\\/send$/i);\n  if(!m||!UUID_RE.test(m[1]))return writeJson(res,400,{ok:false,error:'INVALID_CONVERSATION_ID'});\n  try{\n    const out=await serviceGet('/rest/v1/aos_wa_conversations_v1?id=eq.'+encodeURIComponent(m[1])+'&select=id,owner_user_id,state,last_inbound_at&limit=1');\n    const row=Array.isArray(out.data)?out.data[0]||null:null;\n    if(!row)return writeJson(res,404,{ok:false,error:'CONVERSATION_NOT_FOUND'});\n    if(a.is_admin!==true&&row.owner_user_id!==a.actor_id)return writeJson(res,403,{ok:false,error:'WA3_NOT_OWNER'});\n    const lastMs=Date.parse(String(row.last_inbound_at||''));\n    const expiresMs=Number.isFinite(lastMs)?lastMs+(24*60*60*1000):0;\n    const open=expiresMs>Date.now();\n    if(!open){\n      return writeJson(res,409,{\n        ok:false,\n        error:'WA_CUSTOMER_WINDOW_CLOSED',\n        status:'BLOCKED',\n        requires_template:true,\n        last_inbound_at:row.last_inbound_at||null,\n        window_expires_at:expiresMs?new Date(expiresMs).toISOString():null,\n        policy:'WHATSAPP_24H_CUSTOMER_SERVICE_WINDOW'\n      });\n    }\n    return proxy(req,res);\n  }catch(e){\n    console.error('[PHASE-S] customer-window preflight',e.message);\n    return writeJson(res,503,{ok:false,error:'WA_CUSTOMER_WINDOW_CHECK_UNAVAILABLE'});\n  }\n}\n\nfunction proxyVerify(req,res){`
);
replaceOnce(
  'app/server-phase-s.js',
  "  if(req.method==='GET'&&p==='/api/phase-s/status')return handlePhaseStatus(req,res);\n  return proxy(req,res);",
  "  if(req.method==='GET'&&p==='/api/phase-s/status')return handlePhaseStatus(req,res);\n  if(req.method==='POST'&&/^\\/api\\/wa3\\/conversations\\/[0-9a-f-]{36}\\/send$/i.test(p))return handleCustomerWindowSend(req,res,p);\n  return proxy(req,res);"
);

replaceOnce(
  'app/server-wa3.js',
  "else reject(Object.assign(new Error('META_SEND_REJECTED'),{status:502,definite:true,metaStatus:r.statusCode}));",
  "else {const me=d&&d.error||{};const mc=String(me.code||'').trim();const md=String((me.error_data&&me.error_data.details)||me.message||'').slice(0,700);reject(Object.assign(new Error(mc?('META_'+mc):'META_SEND_REJECTED'),{status:502,definite:true,metaStatus:r.statusCode,metaCode:mc||null,metaDetails:md||null}));}"
);
replaceOnce(
  'app/server-wa3.js',
  "writeJson(res,e.status||502,{ok:false,error:e.message||'WA3_SEND_FAILED',status:ambiguous?'PENDING':'FAILED',retry_safe:false});",
  "writeJson(res,e.status||502,{ok:false,error:e.message||'WA3_SEND_FAILED',status:ambiguous?'PENDING':'FAILED',retry_safe:false,provider_http_status:e.metaStatus||null,provider_code:e.metaCode||null,provider_details:e.metaDetails||null});"
);

replaceOnce(
  'app/public/wa-native-panel.js',
  "function canSend(){var r=S.selected,b=S.boot;if(!r||!b||!b.actor)return {ok:false,reason:'Selecciona una conversación.'};if(!b.control||b.control.human_send_enabled!==true)return {ok:false,reason:'Envío humano global deshabilitado.'};if(r.owner_user_id!==b.actor.id)return {ok:false,reason:'El chat debe estar asignado a tu usuario para responder.'};if(['HUMAN_ACTIVE','AI_COPILOT'].indexOf(r.state)<0)return {ok:false,reason:'Activa modo Humano o Copilot antes de responder.'};return {ok:true,reason:'Respuesta humana gobernada por ownership + 2FA + canary.'};}",
  "function canSend(){var r=S.selected,b=S.boot;if(!r||!b||!b.actor)return {ok:false,reason:'Selecciona una conversación.'};if(!b.control||b.control.human_send_enabled!==true)return {ok:false,reason:'Envío humano global deshabilitado.'};if(r.owner_user_id!==b.actor.id)return {ok:false,reason:'El chat debe estar asignado a tu usuario para responder.'};if(['HUMAN_ACTIVE','AI_COPILOT'].indexOf(r.state)<0)return {ok:false,reason:'Activa modo Humano o Copilot antes de responder.'};var li=Date.parse(String(r.last_inbound_at||''));if(!Number.isFinite(li)||Date.now()-li>=86400000)return {ok:false,reason:'Ventana de WhatsApp cerrada (>24 h). Se requiere plantilla aprobada o un nuevo mensaje del cliente.'};return {ok:true,reason:'Ventana 24 h abierta · respuesta humana gobernada por ownership + 2FA + canary.'};}"
);
replaceOnce(
  'app/public/wa-native-panel.js',
  "var owner=userName(r.owner_user_id),box=boxName(r.box_id),mode=r.state==='AI_COPILOT'?'COPILOT':(r.state==='HUMAN_ACTIVE'?'HUMANO':'COLA');",
  "var owner=userName(r.owner_user_id),box=boxName(r.box_id),mode=r.state==='AI_COPILOT'?'COPILOT':(r.state==='HUMAN_ACTIVE'?'HUMANO':'COLA');var li=Date.parse(String(r.last_inbound_at||'')),windowOpen=Number.isFinite(li)&&(Date.now()-li<86400000);"
);
replaceOnce(
  'app/public/wa-native-panel.js',
  "<span class=\"wa8-chip\">BOT '+((b.control&&b.control.ai_send_enabled)?'ON':'OFF')+'</span><span class=\"wa8-chip\">'+esc(box)+'</span>",
  "<span class=\"wa8-chip\">BOT '+((b.control&&b.control.ai_send_enabled)?'ON':'OFF')+'</span><span class=\"wa8-chip '+(windowOpen?'ok':'warn')+'\">24H '+(windowOpen?'ABIERTA':'CERRADA')+'</span><span class=\"wa8-chip\">'+esc(box)+'</span>"
);

replaceOnce(
  '.github/workflows/phase-s-wa3-stabilization.yml',
  "            'ci/phase-s/wa_native_s8_contract.js',\n            'ci/phase16/test_auth_resend_reconcile.js'",
  "            'ci/phase-s/wa_native_s8_contract.js',\n            'ci/phase-s/wa_customer_window_s10_contract.js',\n            'ci/phase16/test_auth_resend_reconcile.js'"
);
replaceOnce(
  '.github/workflows/phase-s-wa3-stabilization.yml',
  "      - name: Auth Resend private-vault regression",
  "      - name: WA S10 customer-window contract\n        shell: powershell\n        run: |\n          node ci/phase-s/wa_customer_window_s10_contract.js\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n\n      - name: Auth Resend private-vault regression"
);

console.log('S10_PATCH_APPLIED');
