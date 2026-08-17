'use strict'
const fs=require('fs')
const path='app/server-f5.js'
let src=fs.readFileSync(path,'utf8')
function replaceOnce(oldText,newText,label){const n=src.split(oldText).length-1;if(n!==1)throw new Error(label+': expected exactly one match, found '+n);src=src.replace(oldText,newText)}
replaceOnce("const f5=require('./f5-historical-upload');","const f5=require('./f5-historical-upload');\nconst {createLegacyWhatsAppGateway}=require('./f17-whatsapp-legacy-gateway');",'gateway import')
replaceOnce("const serviceGet=e=>sbRequest('GET',e,null,true);","const serviceGet=e=>sbRequest('GET',e,null,true);\n\nasync function verifyF17App(token){const t=String(token||'').trim();if(t.length<32)return{ok:false,status:401};try{const out=await anonRpc('aos_app_actor_v3',{p_token:t,p_required_panel:null,p_require_2fa:false});const id=typeof out.data==='string'?out.data:'';return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)?{ok:true,actor_id:id}:{ok:false,status:403};}catch(_){return{ok:false,status:503};}}\nconst f17Gateway=createLegacyWhatsAppGateway({supabaseUrl:SB_URL,serviceRoleKey:SB_SERVICE_KEY,verifyApp:verifyF17App});",'gateway wiring')
replaceOnce("if(u.pathname==='/api/f5/historical-upload'&&req.method==='POST')return handleUpload(req,res);","if(u.pathname==='/api/f17/whatsapp/templates')return f17Gateway.handle(req,res);if(u.pathname==='/api/f5/historical-upload'&&req.method==='POST')return handleUpload(req,res);",'route')
if(!src.includes("f5Recovery=require('./f5-recovery-worker')"))throw new Error('current F5 recovery worker must be preserved')
if(!src.includes("/api/f17/whatsapp/templates"))throw new Error('F17 route missing')
fs.writeFileSync(path,src)
console.log('F17 F5 boundary materialized while preserving F5 recovery')
