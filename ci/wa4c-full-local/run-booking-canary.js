'use strict';
const assert=require('assert');
const http=require('http');

const BASE=process.env.WA4C_RUNTIME_URL||'http://127.0.0.1:60300';
const SB=process.env.SUPABASE_URL||'http://127.0.0.1:60201';
const SERVICE=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
const AGENT='agent-a-token-44444444444444444444444444444444444';
const ADMIN='admin-token-111111111111111111111111111111111111';
const CUSTOMER='51911111111';

function requestJson(base,pathname,options){
  options=options||{};
  return new Promise((resolve,reject)=>{
    const u=new URL(pathname,base),body=options.body==null?'':JSON.stringify(options.body);
    const headers=Object.assign({Accept:'application/json'},options.headers||{});
    if(body){headers['Content-Type']='application/json';headers['Content-Length']=Buffer.byteLength(body);}
    const req=http.request({hostname:u.hostname,port:u.port,path:u.pathname+u.search,method:options.method||'GET',headers,timeout:15000},res=>{
      let raw='';res.on('data',c=>raw+=c);res.on('end',()=>{let data=null;try{data=raw?JSON.parse(raw):null;}catch(_){data=raw;}resolve({status:res.statusCode||0,data,raw});});
    });
    req.on('timeout',()=>req.destroy(new Error('HTTP_TIMEOUT')));req.on('error',reject);if(body)req.write(body);req.end();
  });
}
function runtime(path,body,token){return requestJson(BASE,path,{method:'POST',body,headers:{'X-AOS-App-Token':token}});}
async function sbGet(path){
  assert(SERVICE,'SUPABASE_SERVICE_ROLE_KEY missing');
  const r=await requestJson(SB,path,{headers:{apikey:SERVICE,Authorization:'Bearer '+SERVICE}});
  assert(r.status>=200&&r.status<300,'Supabase GET failed '+r.status+' '+r.raw.slice(0,300));
  return Array.isArray(r.data)?r.data:[];
}

async function main(){
  const conversations=await sbGet('/rest/v1/aos_wa_conversations_v1?contact_number=eq.'+CUSTOMER+'&select=id,owner_user_id,state&order=updated_at.desc&limit=1');
  assert(conversations[0]&&conversations[0].id,'FULL LOCAL conversation missing');
  const cid=conversations[0].id;
  const fixtures=await sbGet('/rest/v1/aos_wa4c_booking_test_fixture?id=eq.1&select=treatment_id,professional_id,target_date,target_time&limit=1');
  assert(fixtures[0],'booking fixture missing');
  const f=fixtures[0];
  const payload={
    treatment_id:f.treatment_id,
    professional_id:f.professional_id,
    site:'SAN_ISIDRO',
    date:f.target_date,
    time:f.target_time,
    name:'Cliente Booking QA',
    appointment_type:'CONSULTA NUEVA'
  };
  const idem='wa4c-full-local-booking-0001';

  const first=await runtime('/api/wa4/conversations/'+cid+'/book',{idempotency_key:idem,payload},AGENT);
  assert.strictEqual(first.status,200,'booking commit failed '+first.raw);
  assert(first.data&&first.data.ok===true,'booking not ok '+first.raw);
  assert.strictEqual(first.data.status,'BOOKED');
  assert.strictEqual(first.data.confirmation_allowed,true);
  assert.strictEqual(first.data.auto_send,false);
  assert.strictEqual(first.data.send_authority,'HUMAN_ONLY');
  assert.strictEqual(first.data.idempotent_replay,false);
  assert(first.data.agenda_id,'agenda id missing');

  const replay=await runtime('/api/wa4/conversations/'+cid+'/book',{idempotency_key:idem,payload},AGENT);
  assert.strictEqual(replay.status,200,'idempotent replay failed '+replay.raw);
  assert.strictEqual(replay.data.idempotent_replay,true);
  assert.strictEqual(replay.data.agenda_id,first.data.agenda_id);

  const changed=Object.assign({},payload,{time:'10:30'});
  const mismatch=await runtime('/api/wa4/conversations/'+cid+'/book',{idempotency_key:idem,payload:changed},AGENT);
  assert.strictEqual(mismatch.status,409,'idempotency mismatch should fail');
  assert.strictEqual(mismatch.data.error,'WA4_BOOKING_IDEMPOTENCY_MISMATCH');

  const notOwner=await runtime('/api/wa4/conversations/'+cid+'/book',{idempotency_key:'wa4c-full-local-booking-admin',payload:changed},ADMIN);
  assert.strictEqual(notOwner.status,409,'non-owner booking should fail');
  assert.strictEqual(notOwner.data.error,'WA4_BOOKING_NOT_CONVERSATION_OWNER');

  const staleDate=new Date(String(f.target_date)+'T12:00:00Z');staleDate.setUTCDate(staleDate.getUTCDate()+30);
  const stalePayload=Object.assign({},payload,{date:staleDate.toISOString().slice(0,10)});
  const stale=await runtime('/api/wa4/conversations/'+cid+'/book',{idempotency_key:'wa4c-full-local-booking-stale',payload:stalePayload},AGENT);
  assert.strictEqual(stale.status,409,'stale schedule should fail');
  assert.strictEqual(stale.data.error,'WA4_BOOKING_SCHEDULE_SOURCE_STALE');

  const actions=await sbGet('/rest/v1/aos_wa4_booking_actions_v1?conversation_id=eq.'+encodeURIComponent(cid)+'&select=agenda_id,status');
  assert.strictEqual(actions.length,1,'booking action ledger must contain exactly one committed booking');
  const agenda=await sbGet('/rest/v1/aos_agenda_citas?id=eq.'+encodeURIComponent(first.data.agenda_id)+'&select=id,origen_cita,origen,tipo_atencion,llamada_id_origen');
  assert.strictEqual(agenda.length,1,'agenda booking missing');
  assert.strictEqual(agenda[0].origen_cita,'WHATSAPP');
  assert.strictEqual(agenda[0].llamada_id_origen,null,'WhatsApp booking fabricated a Call Center call');

  console.log(JSON.stringify({ok:true,conversation_id:cid,agenda_id:first.data.agenda_id,idempotent_replay:true,stale_fail_closed:true,ownership_fail_closed:true,callcenter_call_fabricated:false,send_authority:'HUMAN_ONLY',auto_send:false},null,2));
  console.log('WA4C_GOVERNED_BOOKING_CANARY_PASS');
}
main().catch(e=>{console.error(e&&e.stack||e);process.exit(1);});
