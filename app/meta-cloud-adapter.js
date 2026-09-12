'use strict';

const https=require('https');
const wa=require('./wa-gateway');
const interactive=require('./wa-interactive');

function trim(v,max){return String(v==null?'':v).trim().slice(0,max||512);}
function isGraphVersion(v){return /^v\d+\.\d+$/.test(String(v||''));}
function nowMs(){return Date.now();}

function providerCategory(code,status){
  const c=String(code||'');
  if(c==='190'||status===401)return 'AUTH';
  if(['10','100','200','131005'].includes(c)||status===403)return 'PERMISSION';
  if(['131026','131047','131051'].includes(c))return 'RECIPIENT';
  if(/^132/.test(c))return 'TEMPLATE';
  if(['4','17','32','613','80007','130429'].includes(c)||status===429)return 'RATE';
  if(status>=500)return 'TRANSIENT';
  return 'UNKNOWN';
}

function normalizeProviderError(status,body,fallback){
  const e=body&&body.error&&typeof body.error==='object'?body.error:{};
  const code=trim(e.code,64);
  const subcode=trim(e.error_subcode,64);
  const category=providerCategory(code,Number(status||0));
  const errorCode=code?('META_'+code+(subcode?'_'+subcode:'')):String(fallback||'META_PROVIDER_REJECTED');
  return {
    errorCode,
    providerCode:code||null,
    providerSubcode:subcode||null,
    providerHttpStatus:Number(status||0)||null,
    category,
    definite:Number(status||0)>=400&&Number(status||0)<500,
    diagnosis:category==='AUTH'?'TOKEN_INVALID_OR_EXPIRED':
      category==='PERMISSION'?'PERMISSION_OR_ASSET_ACCESS':
      category==='RECIPIENT'?'RECIPIENT_UNAVAILABLE':
      category==='TEMPLATE'?'TEMPLATE_REJECTED':
      category==='RATE'?'PROVIDER_RATE_LIMITED':
      category==='TRANSIENT'?'PROVIDER_TRANSIENT_FAILURE':'META_PROVIDER_REJECTED'
  };
}

function createMetaCloudAdapter(config){
  config=config||{};
  const accessToken=String(config.accessToken!=null?config.accessToken:(process.env.WHATSAPP_ACCESS_TOKEN||''));
  const phoneNumberId=String(config.phoneNumberId!=null?config.phoneNumberId:(process.env.WHATSAPP_PHONE_NUMBER_ID||''));
  const graphVersion=String(config.graphVersion!=null?config.graphVersion:(process.env.WHATSAPP_GRAPH_VERSION||''));
  const appSecret=String(config.appSecret!=null?config.appSecret:(process.env.WHATSAPP_APP_SECRET||''));
  const configuredWabaId=String(config.businessAccountId!=null?config.businessAccountId:(process.env.WHATSAPP_BUSINESS_ACCOUNT_ID||''));
  const businessPortfolioId=String(config.businessPortfolioId!=null?config.businessPortfolioId:(process.env.WHATSAPP_BUSINESS_PORTFOLIO_ID||''));
  const requester=config.requester||requestJson;
  let resolvedWabaCache=configuredWabaId?{id:configuredWabaId,name:null,source:'CONFIG'}:null;

  function transportConfigured(){return !!(accessToken&&phoneNumberId&&isGraphVersion(graphVersion));}
  function webhookConfigured(){return !!appSecret;}

  async function requestJson(method,path,body,timeoutMs){
    if(!accessToken)throw Object.assign(new Error('META_ACCESS_TOKEN_NOT_CONFIGURED'),{status:503,definite:true,category:'AUTH'});
    const payload=body==null?null:JSON.stringify(body);
    const headers={Authorization:'Bearer '+accessToken,Accept:'application/json','User-Agent':'AscendaOS-MetaCloudAdapter/1.0'};
    if(payload!=null){headers['Content-Type']='application/json';headers['Content-Length']=Buffer.byteLength(payload);}
    const started=nowMs();
    return new Promise((resolve,reject)=>{
      const q=https.request({
        hostname:'graph.facebook.com',
        path:'/'+graphVersion+'/'+String(path||'').replace(/^\/+/, ''),
        method:String(method||'GET').toUpperCase(),
        headers,
        timeout:Number(timeoutMs||12000)
      },r=>{
        const chunks=[];
        r.on('data',c=>chunks.push(Buffer.from(c)));
        r.on('end',()=>{
          const text=Buffer.concat(chunks).toString('utf8');let parsed={};
          if(text){try{parsed=JSON.parse(text);}catch(_){parsed={};}}
          const status=r.statusCode||502;
          if(status>=200&&status<300)return resolve({status,data:parsed,latencyMs:nowMs()-started});
          const p=normalizeProviderError(status,parsed,'META_PROVIDER_REJECTED');
          const err=Object.assign(new Error(p.errorCode),p,{status:status>=500?502:status});
          reject(err);
        });
      });
      q.on('timeout',()=>q.destroy(Object.assign(new Error('META_PROVIDER_TIMEOUT'),{status:504,ambiguous:true,category:'TRANSIENT'})));
      q.on('error',err=>reject(Object.assign(err,{status:err.status||502,ambiguous:err.definite!==true,category:err.category||'TRANSIENT'})));
      if(payload!=null)q.write(payload);
      q.end();
    });
  }

  function verifyWebhook(rawBody,signatureHeader){
    return webhookConfigured()&&wa.verifyMetaSignature(rawBody,signatureHeader,appSecret);
  }

  function normalizeWebhook(payload){return wa.extractWebhook(payload);}

  async function phoneAsset(){
    if(!transportConfigured())throw Object.assign(new Error('WA_PROVIDER_NOT_CONFIGURED'),{status:503,definite:true});
    const fields='id,display_phone_number,verified_name,quality_rating';
    return requester('GET',encodeURIComponent(phoneNumberId)+'?fields='+encodeURIComponent(fields),null,12000);
  }

  async function discoverBusinessAccounts(){
    const businesses=[];
    if(businessPortfolioId)businesses.push({id:businessPortfolioId,name:null,source:'CONFIG_PORTFOLIO'});
    if(!businesses.length){
      try{
        const out=await requester('GET','me/businesses?fields='+encodeURIComponent('id,name')+'&limit=50',null,12000);
        for(const row of Array.isArray(out&&out.data&&out.data.data)?out.data.data:[]){
          const id=trim(row&&row.id,128);if(id)businesses.push({id,name:trim(row&&row.name,256)||null,source:'ME_BUSINESSES'});
        }
      }catch(_){}
    }
    const seenBusinesses=new Set(),wabas=new Map();
    for(const business of businesses){
      if(!business.id||seenBusinesses.has(business.id))continue;seenBusinesses.add(business.id);
      for(const edge of ['owned_whatsapp_business_accounts','client_whatsapp_business_accounts']){
        try{
          const out=await requester('GET',encodeURIComponent(business.id)+'/'+edge+'?fields='+encodeURIComponent('id,name')+'&limit=50',null,15000);
          for(const row of Array.isArray(out&&out.data&&out.data.data)?out.data.data:[]){
            const id=trim(row&&row.id,128);if(id&&!wabas.has(id))wabas.set(id,{id,name:trim(row&&row.name,256)||null,source:edge,businessId:business.id});
          }
        }catch(_){}
      }
    }
    if(!wabas.size){
      try{
        const out=await requester('GET','me/assigned_whatsapp_business_accounts?fields='+encodeURIComponent('id,name')+'&limit=50',null,15000);
        for(const row of Array.isArray(out&&out.data&&out.data.data)?out.data.data:[]){
          const id=trim(row&&row.id,128);if(id&&!wabas.has(id))wabas.set(id,{id,name:trim(row&&row.name,256)||null,source:'ME_ASSIGNED'});
        }
      }catch(_){}
    }
    return Array.from(wabas.values());
  }

  async function resolveWaba(){
    if(resolvedWabaCache&&resolvedWabaCache.id)return resolvedWabaCache;
    const candidates=await discoverBusinessAccounts();
    for(const candidate of candidates){
      try{
        const out=await requester('GET',encodeURIComponent(candidate.id)+'/phone_numbers?fields='+encodeURIComponent('id,display_phone_number,verified_name')+'&limit=50',null,15000);
        const rows=Array.isArray(out&&out.data&&out.data.data)?out.data.data:[];
        if(rows.some(row=>String(row&&row.id||'')===phoneNumberId)){
          resolvedWabaCache={id:candidate.id,name:candidate.name||null,source:candidate.source||'DISCOVERY'};
          return resolvedWabaCache;
        }
      }catch(_){}
    }
    return null;
  }

  async function resolveWabaId(){
    const row=await resolveWaba();
    return row&&row.id?row.id:'';
  }

  async function health(){
    const result={
      ok:false,provider:'META',checkedAt:new Date().toISOString(),
      configured:transportConfigured(),webhookConfigured:webhookConfigured(),
      credentialState:'UNKNOWN',assetState:'UNKNOWN',permissionsState:'UNKNOWN',
      diagnosis:'CONFIG_MISSING',graphVersion:isGraphVersion(graphVersion)?graphVersion:null
    };
    if(!transportConfigured())return result;
    try{
      await requester('GET','me?fields=id',null,10000);
      result.credentialState='READY';
    }catch(e){
      result.credentialState='INVALID';result.diagnosis=e.diagnosis||'TOKEN_INVALID_OR_EXPIRED';
      result.providerErrorCode=String(e.errorCode||e.message||'META_AUTH_CHECK_FAILED').slice(0,128);
      result.providerHttpStatus=e.providerHttpStatus||null;return result;
    }
    try{
      const p=await requester('GET','me/permissions',null,10000);
      const rows=Array.isArray(p&&p.data&&p.data.data)?p.data.data:[];
      if(rows.length){
        const needed=['whatsapp_business_management','whatsapp_business_messaging'];
        result.permissionsState=needed.every(name=>rows.some(r=>r&&r.permission===name&&r.status==='granted'))?'READY':'INVALID';
      }else result.permissionsState='UNKNOWN';
    }catch(e){
      result.permissionsState='UNKNOWN';
    }
    try{
      const asset=await phoneAsset();
      result.assetState=asset&&asset.data&&String(asset.data.id||'')===phoneNumberId?'READY':'INVALID';
      result.phoneNumberId=phoneNumberId;
      result.verifiedName=asset&&asset.data?trim(asset.data.verified_name,256)||null:null;
      result.displayPhoneNumber=asset&&asset.data?trim(asset.data.display_phone_number,64)||null:null;
      result.qualityRating=asset&&asset.data?trim(asset.data.quality_rating,64)||null:null;
      let waba=null;
      try{waba=await resolveWaba();}catch(_){waba=null;}
      result.businessAccountAvailable=!!(waba&&waba.id);
      result.businessAccountId=waba&&waba.id?waba.id:null;
      result.businessAccountName=waba&&waba.name?waba.name:null;
    }catch(e){
      result.assetState='INVALID';result.diagnosis=e.diagnosis||'PHONE_NUMBER_ID_INVALID_OR_INACCESSIBLE';
      result.providerErrorCode=String(e.errorCode||e.message||'META_PHONE_CHECK_FAILED').slice(0,128);
      result.providerHttpStatus=e.providerHttpStatus||null;return result;
    }
    result.messagingReady=result.credentialState==='READY'&&result.assetState==='READY'&&result.permissionsState!=='INVALID';
    result.managementReady=result.messagingReady&&result.businessAccountAvailable===true;
    result.ok=result.managementReady;
    result.diagnosis=result.ok?'READY':
      (result.permissionsState==='INVALID'?'PERMISSION_OR_ASSET_ACCESS':
      (!result.businessAccountAvailable?'WABA_ASSET_ACCESS_MISSING':'PROVIDER_CHECK_INCOMPLETE'));
    return result;
  }

  async function sendPayload(payload){
    if(!transportConfigured())throw Object.assign(new Error('WA_OUTBOUND_NOT_CONFIGURED'),{status:503,definite:true});
    if(!payload||payload.messaging_product!=='whatsapp')throw Object.assign(new Error('INVALID_META_PAYLOAD'),{status:400,definite:true});
    const allowed=new Set(['text','image','audio','video','document','template','interactive']);
    const isTypingStatus=payload.status==='read'&&payload.message_id;
    if(!isTypingStatus&&!allowed.has(String(payload.type||'')))throw Object.assign(new Error('META_MESSAGE_TYPE_NOT_ALLOWED'),{status:400,definite:true});
    const out=await requester('POST',encodeURIComponent(phoneNumberId)+'/messages',payload,15000);
    const id=out&&out.data&&out.data.messages&&out.data.messages[0]&&out.data.messages[0].id;
    if(!isTypingStatus&&!id)throw Object.assign(new Error('META_MESSAGE_ID_MISSING'),{status:502,ambiguous:true,category:'UNKNOWN'});
    return {
      accepted:true,
      providerMessageId:id?String(id):null,
      phoneNumberId,
      latencyMs:Number(out.latencyMs||0),
      rawStatus:Number(out.status||200)
    };
  }

  async function sendText(input){return sendPayload(wa.buildOutboundPayload(Object.assign({},input,{type:'text'})));}
  async function sendMedia(input){
    const type=String(input&&input.type||'').toLowerCase();
    if(!['image','audio','video','document'].includes(type))throw Object.assign(new Error('MEDIA_TYPE_NOT_ALLOWED'),{status:400,definite:true});
    return sendPayload(wa.buildOutboundPayload(input));
  }
  async function sendTemplate(input){return sendPayload(wa.buildOutboundPayload(Object.assign({},input,{type:'template'})));}
  async function sendInteractive(input){return sendPayload(interactive.build(input));}
  async function typing(providerMessageId){
    const id=String(providerMessageId||'').trim();
    if(!/^wamid\.[A-Za-z0-9._~:/+=-]{8,500}$/.test(id))throw Object.assign(new Error('WA_TYPING_PROVIDER_MESSAGE_ID_REQUIRED'),{status:400,definite:true});
    return sendPayload({messaging_product:'whatsapp',status:'read',message_id:id,typing_indicator:{type:'text'}});
  }

  async function listTemplates(){
    if(!transportConfigured())throw Object.assign(new Error('WA_PROVIDER_NOT_CONFIGURED'),{status:503,definite:true});
    const wabaId=await resolveWabaId();
    if(!wabaId)throw Object.assign(new Error('META_WABA_ID_UNAVAILABLE'),{status:503,definite:true,category:'PERMISSION'});
    const fields='id,name,status,category,language,components';
    const out=await requester('GET',encodeURIComponent(wabaId)+'/message_templates?fields='+encodeURIComponent(fields)+'&limit=50',null,15000);
    const rows=Array.isArray(out&&out.data&&out.data.data)?out.data.data:[];
    return {
      ok:true,
      templates:rows.map(r=>({
        id:trim(r&&r.id,128)||null,
        name:trim(r&&r.name,512),
        status:trim(r&&r.status,64),
        category:trim(r&&r.category,64),
        language:trim(r&&r.language,32),
        components:Array.isArray(r&&r.components)?r.components:[]
      })),
      count:rows.length,
      next:out&&out.data&&out.data.paging&&out.data.paging.next?true:false
    };
  }

  return {
    transportConfigured,webhookConfigured,verifyWebhook,normalizeWebhook,health,discoverBusinessAccounts,resolveWaba,resolveWabaId,
    sendPayload,sendText,sendMedia,sendTemplate,sendInteractive,typing,listTemplates,
    normalizeProviderError
  };
}

module.exports={createMetaCloudAdapter,normalizeProviderError,providerCategory,isGraphVersion};
