(function(){
'use strict';
if(window.__AOS_F11_FETCH_ADAPTER)return;
window.__AOS_F11_FETCH_ADAPTER=true;
var originalFetch=window.fetch.bind(window);
var RPC_V2_RE=/\/rest\/v1\/rpc\/(aos_siguiente_lead|aos_siguiente_lead_v2)(?:\?|$)/;
var CALLS_RE=/\/rest\/v1\/aos_llamadas(?:\?|$)/;
var currentRouting=null;
function norm(v){var d=String(v||'').replace(/\D/g,'');if(d.length===11&&d.slice(0,2)==='51')d=d.slice(-9);return d;}
function rpcUrl(name,url){return String(url).replace(/\/rest\/v1\/rpc\/[^?]+/,'/rest/v1/rpc/'+name);}
function headersFrom(opts){var h={};try{new Headers((opts&&opts.headers)||{}).forEach(function(v,k){h[k]=v;});}catch(_){ }return h;}
function captureRouting(data){var r=data&&data.routingV3||null;currentRouting=(r&&r.route==='V3'&&r.assignmentId)?r:null;window.__AOS_F11_CURRENT_ROUTING=currentRouting;}
function parseBody(opts){try{return JSON.parse((opts&&opts.body)||'{}');}catch(_){return {};}}
function toast(title,msg,kind){try{if(window.AOS_showToast)window.AOS_showToast(title,msg,kind||'');}catch(_){}}
function consumeAfterCall(url,opts,response){if(!response||!response.ok||!currentRouting||!currentRouting.assignmentId)return Promise.resolve(response);var row=parseBody(opts),contact=norm(row.numero_limpio||row.numero);if(!contact||contact!==norm(currentRouting.contactKey))return Promise.resolve(response);var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};var advisor=String(ctx.asesor||row.asesor||'').toUpperCase(),code=String(ctx.idAsesor||row.id_asesor||'');if(!advisor||!code)return Promise.resolve(response);var result=String(row.estado||'').toUpperCase()||'UNSPECIFIED';var hoy=String(row.fecha||currentRouting.clinicDay||'').slice(0,10);var body={p_asesor:advisor,p_id_asesor:code,p_assignment_id:currentRouting.assignmentId,p_result:result,p_hoy:hoy};var rpc=String(url).replace(/\/rest\/v1\/aos_llamadas(?:\?.*)?$/,'/rest/v1/rpc/aos_cia_call_routing_consume_v1');var consumeOpts={method:'POST',headers:headersFrom(opts),body:JSON.stringify(body)};return originalFetch(rpc,consumeOpts).then(function(r){if(!r.ok)throw new Error('HTTP '+r.status);return r.json();}).then(function(x){if(!x||x.ok===false)throw new Error((x&&x.error)||'consume failed');currentRouting=null;window.__AOS_F11_CURRENT_ROUTING=null;return response;}).catch(function(e){console.error('[F11] Llamada guardada; consume V3 pendiente:',e);toast('Llamada guardada','Routing V3 no sincronizó el lease; se reanudará el mismo contacto.','toast-alerta');return response;});}
window.fetch=function(input,opts){var url=typeof input==='string'?input:(input&&input.url)||'';if(RPC_V2_RE.test(url)){var next=rpcUrl('aos_siguiente_lead_v3',url);return originalFetch(next,opts).then(function(resp){var oj=resp.json.bind(resp);resp.json=function(){return oj().then(function(data){captureRouting(data);return data;});};return resp;});}
 if(CALLS_RE.test(url)&&String((opts&&opts.method)||'GET').toUpperCase()==='POST'){return originalFetch(input,opts).then(function(resp){return consumeAfterCall(url,opts,resp);});}
 return originalFetch(input,opts);
};
window.AOS_F11_ROUTING_ADAPTER={version:'1.0',getCurrent:function(){return currentRouting;},restoreFetch:function(){window.fetch=originalFetch;window.__AOS_F11_FETCH_ADAPTER=false;currentRouting=null;}};
})();