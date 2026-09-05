from pathlib import Path


def once(s, old, new, label):
    if new in s:
        return s
    if old not in s:
        raise SystemExit('PATCH_ANCHOR_MISSING:' + label)
    return s.replace(old, new, 1)

# 1) WA4 must not own Meta transport. Route typing through the existing canonical WA-1/F4 boundary.
p=Path('app/server-wa4.js')
s=p.read_text()
s=once(s,
"const WA_L4_INTERNAL_TOKEN=process.env.WA_L4_INTERNAL_TOKEN||'';\nconst WA_ACCESS_TOKEN=process.env.WHATSAPP_ACCESS_TOKEN||'';\nconst WA_PHONE_NUMBER_ID=process.env.WHATSAPP_PHONE_NUMBER_ID||'';\nconst WA_GRAPH_VERSION=process.env.WHATSAPP_GRAPH_VERSION||'';",
"const WA_L4_INTERNAL_TOKEN=process.env.WA_L4_INTERNAL_TOKEN||'';",
'wa4-provider-secrets')
old="""function sendTypingIndicator(providerMessageId){
  return new Promise(resolve=>{
    const messageId=String(providerMessageId||'').trim();
    if(!messageId||!WA_ACCESS_TOKEN||!WA_PHONE_NUMBER_ID||!/^v\\d+\\.\\d+$/.test(WA_GRAPH_VERSION))return resolve({ok:false,skipped:true});
    const payload=JSON.stringify({messaging_product:'whatsapp',status:'read',message_id:messageId,typing_indicator:{type:'text'}});
    const q=https.request({hostname:'graph.facebook.com',path:'/'+WA_GRAPH_VERSION+'/'+encodeURIComponent(WA_PHONE_NUMBER_ID)+'/messages',method:'POST',headers:{Authorization:'Bearer '+WA_ACCESS_TOKEN,'Content-Type':'application/json','Content-Length':Buffer.byteLength(payload),'User-Agent':'AscendaOS-WA-L10-Typing/1.0'},timeout:3000},r=>{r.resume();r.on('end',()=>resolve({ok:r.statusCode>=200&&r.statusCode<300,status:r.statusCode||0}));});
    q.on('timeout',()=>{q.destroy();resolve({ok:false,error:'META_TYPING_TIMEOUT'});});
    q.on('error',()=>resolve({ok:false,error:'META_TYPING_UNAVAILABLE'}));
    q.write(payload);q.end();
  });
}
const bridge=createAutonomousBridge({serviceRpc,suggestInternal,autoSend:body=>internalPost('/api/wa/auto-send',body),requestHandoff,sendTyping:sendTypingIndicator,log:console});
"""
new="""const bridge=createAutonomousBridge({
  serviceRpc,
  suggestInternal,
  autoSend:body=>internalPost('/api/wa/auto-send',body),
  requestHandoff,
  sendTyping:providerMessageId=>internalPost('/api/wa/auto-typing',{provider_message_id:providerMessageId}),
  log:console
});
"""
s=once(s,old,new,'wa4-typing-boundary')
p.write_text(s)

# 2) F4/WA-1 owns provider transport, authenticated by the same server-only L4 token.
p=Path('app/server-f4.js')
f=p.read_text()
anchor="""async function handleWaStatus(req,res){
"""
handler="""async function handleWaAutoTyping(req,res,body){
  if(!WA_L4_INTERNAL_TOKEN||WA_L4_INTERNAL_TOKEN.length<32){writeJson(res,503,{ok:false,error:'WA_L4_INTERNAL_AUTH_NOT_CONFIGURED'});return;}
  if(!authorizeWaAutoRuntime(req)){writeJson(res,403,{ok:false,error:'WA_L4_INTERNAL_AUTH_REQUIRED'});return;}
  const messageId=String(body&&body.provider_message_id||'').trim();
  if(!/^wamid\\.[A-Za-z0-9._~:/+=-]{8,500}$/.test(messageId)){writeJson(res,400,{ok:false,error:'WA_TYPING_PROVIDER_MESSAGE_ID_REQUIRED'});return;}
  if(!waConfigReadyOutbound()){writeJson(res,503,{ok:false,error:'WA_OUTBOUND_NOT_CONFIGURED'});return;}
  try{
    await graphSend({messaging_product:'whatsapp',status:'read',message_id:messageId,typing_indicator:{type:'text'}});
    writeJson(res,200,{ok:true,typing:true,provider:'META'});
  }catch(e){
    console.error('[WA-L10] typing indicator',l4.sanitizeReason(e&&e.message));
    writeJson(res,e.status||502,{ok:false,error:'WA_TYPING_PROVIDER_UNAVAILABLE'});
  }
}

async function handleWaStatus(req,res){
"""
f=once(f,anchor,handler,'f4-typing-handler')
route="""  if(pathname==='/api/wa/auto-send'&&req.method==='POST'){try{const parsed=await readJson(req,256*1024);await handleWaAutoSend(req,res,parsed.body);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}
"""
route_new=route+"""  if(pathname==='/api/wa/auto-typing'&&req.method==='POST'){try{const parsed=await readJson(req,16*1024);await handleWaAutoTyping(req,res,parsed.body);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}
"""
f=once(f,route,route_new,'f4-typing-route')
method="""  if(pathname==='/api/wa/auto-send'){writeJson(res,405,{ok:false,error:'WA_L4_INTERNAL_POST_ONLY'});return;}
"""
method_new=method+"""  if(pathname==='/api/wa/auto-typing'){writeJson(res,405,{ok:false,error:'WA_L4_INTERNAL_POST_ONLY'});return;}
"""
f=once(f,method,method_new,'f4-typing-post-only')
p.write_text(f)

# 3) Static contracts explicitly preserve the single provider boundary.
p=Path('ci/wa-l10/autonomous_bridge_contract.test.js')
t=p.read_text()
t=once(t,
"const server=fs.readFileSync('app/server-wa4.js','utf8');\nconst bridge=fs.readFileSync('app/wa-l10-autonomous-bridge.js','utf8');",
"const server=fs.readFileSync('app/server-wa4.js','utf8');\nconst f4=fs.readFileSync('app/server-f4.js','utf8');\nconst bridge=fs.readFileSync('app/wa-l10-autonomous-bridge.js','utf8');",
'contract-f4-read')
old_contract="""assert(server.includes("typing_indicator:{type:'text'}"),'Meta typing indicator payload missing');
assert(server.includes("status:'read'"),'typing indicator must mark the triggering inbound as read');
assert(server.includes('sendTyping:sendTypingIndicator'),'L10 bridge must receive server-owned typing dependency');
const typingAt=bridge.indexOf('sendTyping(claim.provider_message_id)');
assert(typingAt>claimAt&&typingAt<suggestAt,'typing indicator must start after exact claim and before model work');
assert(!/graph\\.facebook\\.com/i.test(bridge),'bridge itself may not become provider transport');
"""
new_contract="""assert(server.includes("internalPost('/api/wa/auto-typing'"),'WA4 typing must reuse canonical internal provider boundary');
assert(!/graph\\.facebook\\.com/i.test(server),'WA4 may not own Meta provider transport');
assert(!/WHATSAPP_ACCESS_TOKEN|WHATSAPP_PHONE_NUMBER_ID|WHATSAPP_GRAPH_VERSION/.test(server),'WA4 may not own Meta transport secrets');
assert(f4.includes("pathname==='/api/wa/auto-typing'&&req.method==='POST'"),'canonical WA-1/F4 typing route missing');
assert(f4.includes("typing_indicator:{type:'text'}"),'Meta typing indicator payload missing at canonical provider boundary');
assert(f4.includes("status:'read'"),'typing indicator must mark the triggering inbound as read');
assert(f4.includes('authorizeWaAutoRuntime(req)'),'typing route must require server-only internal authorization');
assert(f4.includes("graph.facebook.com"),'canonical provider boundary must retain Meta transport');
const typingAt=bridge.indexOf('sendTyping(claim.provider_message_id)');
assert(typingAt>claimAt&&typingAt<suggestAt,'typing indicator must start after exact claim and before model work');
assert(!/graph\\.facebook\\.com/i.test(bridge),'bridge itself may not become provider transport');
"""
t=once(t,old_contract,new_contract,'typing-contract-boundary')
p.write_text(t)

# 4) Preserve WA4 UI provider-boundary invariant and add a focused F4 route contract.
p=Path('ci/wa4-ai-sales-router/r6-conversation-ux-fastlane.test.js')
r=p.read_text().rstrip()+"\n\n"+"""test('R6 typing transport remains in canonical F4/WA-1 provider boundary',()=>{
  const wa4=fs.readFileSync(require.resolve('../../app/server-wa4'),'utf8');
  const f4=fs.readFileSync(require.resolve('../../app/server-f4'),'utf8');
  assert.equal(wa4.includes('graph.facebook.com'),false);
  assert.equal(wa4.includes('WHATSAPP_ACCESS_TOKEN'),false);
  assert.ok(wa4.includes("internalPost('/api/wa/auto-typing'"));
  assert.ok(f4.includes("pathname==='/api/wa/auto-typing'&&req.method==='POST'"));
  assert.ok(f4.includes("typing_indicator:{type:'text'}"));
  assert.ok(f4.includes('authorizeWaAutoRuntime(req)'));
});
"""
p.write_text(r)
