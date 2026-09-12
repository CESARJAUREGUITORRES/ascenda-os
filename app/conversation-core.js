'use strict';

const CORE_VERSION='CONV-L2-V1';
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EVENT_TYPES=new Set([
  'ready',
  'conversation.invalidate',
  'conversation.ownership',
  'message.accepted',
  'provider.webhook',
  'configuration.changed'
]);

function cleanReason(v){
  return String(v||'').replace(/[^A-Za-z0-9_.:-]/g,'_').slice(0,80)||null;
}
function cleanConversationId(v){
  const s=String(v||'');
  return UUID_RE.test(s)?s:null;
}

function createEventHub(options){
  options=options||{};
  const heartbeatMs=Math.max(10000,Math.min(60000,Number(options.heartbeatMs||20000)));
  const maxClients=Math.max(10,Math.min(1000,Number(options.maxClients||250)));
  const clients=new Map();
  let clientSeq=0,eventSeq=0,closed=false;

  function writeEvent(res,event){
    if(!res||res.destroyed||res.writableEnded)return false;
    try{
      res.write('id: '+String(event.seq)+'\n');
      res.write('event: conversation-core\n');
      res.write('data: '+JSON.stringify(event)+'\n\n');
      return true;
    }catch(_){return false;}
  }

  function remove(id){
    const c=clients.get(id);
    if(!c)return;
    clients.delete(id);
    if(c.heartbeat)clearInterval(c.heartbeat);
    if(c.res&&!c.res.writableEnded){try{c.res.end();}catch(_){}}
  }

  function subscribe(res,actor){
    if(closed)throw new Error('CONVERSATION_CORE_CLOSED');
    if(clients.size>=maxClients)throw Object.assign(new Error('CONVERSATION_EVENT_CAPACITY'),{status:503});
    const id=++clientSeq;
    res.writeHead(200,{
      'Content-Type':'text/event-stream; charset=utf-8',
      'Cache-Control':'no-store, no-transform',
      'Connection':'keep-alive',
      'X-Accel-Buffering':'no',
      'X-Content-Type-Options':'nosniff',
      'X-Ascenda-Conversation-Core':CORE_VERSION
    });
    if(typeof res.flushHeaders==='function')res.flushHeaders();
    const client={
      id,
      res,
      actorId:cleanConversationId(actor&&actor.id),
      isAdmin:actor&&actor.is_admin===true,
      heartbeat:null
    };
    client.heartbeat=setInterval(()=>{
      if(res.destroyed||res.writableEnded)return remove(id);
      try{res.write(': ping '+Date.now()+'\n\n');}catch(_){remove(id);}
    },heartbeatMs);
    if(client.heartbeat&&typeof client.heartbeat.unref==='function')client.heartbeat.unref();
    clients.set(id,client);
    writeEvent(res,{seq:++eventSeq,type:'ready',conversation_id:null,reason:'stream_ready',at:new Date().toISOString()});
    const cleanup=()=>remove(id);
    res.on('close',cleanup);
    res.on('error',cleanup);
    return cleanup;
  }

  function emit(type,payload){
    if(closed)return null;
    const safeType=EVENT_TYPES.has(type)?type:'conversation.invalidate';
    payload=payload||{};
    const event={
      seq:++eventSeq,
      type:safeType,
      conversation_id:cleanConversationId(payload.conversation_id),
      reason:cleanReason(payload.reason),
      at:new Date().toISOString()
    };
    for(const [id,c] of clients){
      if(!writeEvent(c.res,event))remove(id);
    }
    return event;
  }

  function snapshot(){
    return {version:CORE_VERSION,clients:clients.size,event_seq:eventSeq};
  }

  function close(){
    closed=true;
    for(const id of Array.from(clients.keys()))remove(id);
  }

  return {version:CORE_VERSION,subscribe,emit,snapshot,close};
}

module.exports={CORE_VERSION,createEventHub};
