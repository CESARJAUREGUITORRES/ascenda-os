// ASCENDA Conversations — mount WA-3 inside the canonical ASCENDA shell.
(function(){
'use strict';
var BOOT_TRIES=0,BOOT_MAX=50;

function contains(arr,id){return Array.isArray(arr)&&arr.some(function(x){return x&&x.type==='item'&&x.id===id;});}
function insertAfter(arr,afterId,item){
  if(!Array.isArray(arr)||contains(arr,item.id))return;
  var idx=arr.findIndex(function(x){return x&&x.type==='item'&&x.id===afterId;});
  if(idx<0)arr.push(item);else arr.splice(idx+1,0,item);
}
function perms(){try{return (window.AOS&&AOS.ctx&&Array.isArray(AOS.ctx.paneles_acceso))?AOS.ctx.paneles_acceso:[];}catch(e){return [];}}
function allowed(viewId){
  var p=perms(),ctx=(window.AOS&&AOS.ctx)||{};
  if(viewId==='admin-whatsapp')return AOS.role==='ADMIN'&&Number(ctx.nivel||99)<=2&&p.indexOf('admin-whatsapp')>=0;
  if(viewId==='whatsapp-agent')return p.indexOf('whatsapp-agent')>=0;
  return false;
}
function markActive(viewId){
  document.querySelectorAll('.ni').forEach(function(n){n.classList.remove('act-asesor','act-admin');});
  var nd=document.getElementById('nav-'+viewId);
  if(nd)nd.classList.add(AOS.role==='ADMIN'?'act-admin':'act-asesor');
}
function esc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function appToken(){try{return sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||'';}catch(e){return '';}}
function reqJson(url){
  return fetch(url,{headers:{'X-AOS-App-Token':appToken(),'Accept':'application/json'},cache:'no-store'}).then(function(r){
    return r.json().catch(function(){return {ok:false,error:'INVALID_JSON'};}).then(function(d){if(!r.ok||d.ok===false){var e=new Error(d.error||('HTTP_'+r.status));e.status=r.status;throw e;}return d;});
  });
}
function recoveryStatus(d,text,bad){
  var side=d.getElementById('side');if(!side)return;
  side.innerHTML='<div class="card"><div class="ct">Recuperación automática</div><div class="statusline" style="'+(bad?'color:#b42318;background:#fff1f2':'color:#51617f')+'">'+esc(text)+'</div></div>';
}
function renderRecoveryMessages(d,row,endpoint){
  var head=d.getElementById('chathead'),msgs=d.getElementById('msgs'),composer=d.getElementById('composer');
  if(head)head.innerHTML='<div><div class="name">'+esc(row.contact_name||('WhatsApp +'+String(row.contact_number||'').slice(-6)))+'</div><div class="meta">+'+esc(row.contact_number||'')+' · '+esc(row.state||'')+' · recuperación de inbox</div></div>';
  if(msgs)msgs.innerHTML='<div class="empty"><b>Cargando conversación…</b></div>';
  if(composer)composer.innerHTML='<div class="locked">🔄 Recuperando sesión operativa WA-3…</div>';
  reqJson(endpoint).then(function(x){
    var arr=x.messages||[];
    if(!msgs)return;
    if(!arr.length){msgs.innerHTML='<div class="empty"><b>Sin mensajes cargados</b></div>';return;}
    msgs.innerHTML=arr.map(function(m){return '<div class="msg '+(m.direction==='OUTBOUND'?'out':'in')+'"><div class="bubble">'+esc(m.message_body||('['+(m.message_type||'mensaje')+']'))+'</div><div class="meta">'+esc(m.status||'')+'</div></div>';}).join('');
    msgs.scrollTop=msgs.scrollHeight;
  }).catch(function(e){if(msgs)msgs.innerHTML='<div class="empty"><b>No se pudo cargar el timeline</b>'+esc(e.message)+'</div>';});
}
function renderRecoveryList(frame,d,rows,mode){
  var list=d.getElementById('list');if(!list)return;
  if(!rows.length){list.innerHTML='<div class="empty"><b>Sin conversaciones visibles</b>La API respondió correctamente pero no devolvió filas.</div>';return;}
  list.innerHTML=rows.map(function(r){return '<div class="conv" data-id="'+esc(r.id)+'"><div class="row"><div class="name">'+esc(r.contact_name||('WhatsApp +'+String(r.contact_number||'').slice(-6)))+'</div><div class="grow"></div>'+(Number(r.unread_count||0)?'<span class="badge">'+Math.min(99,Number(r.unread_count||0))+'</span>':'')+'</div><div class="meta">+'+esc(r.contact_number||'')+'</div><div class="row" style="margin-top:4px"><span class="badge '+(r.owner_user_id?'human':'queue')+'">'+esc(r.state||'NEW')+'</span><span class="meta">'+(mode==='WA2'?'fallback WA-2':'WA-3')+'</span></div></div>';}).join('');
  Array.prototype.forEach.call(list.querySelectorAll('.conv'),function(el){el.onclick=function(){var id=el.getAttribute('data-id'),row=rows.find(function(x){return x.id===id;});if(!row)return;renderRecoveryMessages(d,row,(mode==='WA2'?'/api/wa/conversations/':'/api/wa3/conversations/')+id+'/messages?limit=250');};});
}
function installRecovery(frame,d){
  if(frame.__aosWaRecovery)return;frame.__aosWaRecovery=true;
  setTimeout(function(){
    try{
      var list=d.getElementById('list'),side=d.getElementById('side');
      if(!list||!side)return;
      if(list.children.length>0||side.children.length>0)return;
      recoveryStatus(d,'Reintentando bootstrap WA-3…',false);
      var bErr='';
      reqJson('/api/wa3/bootstrap').catch(function(e){bErr=e.message;return null;}).then(function(boot){
        return reqJson('/api/wa3/inbox?limit=120').then(function(inbox){
          renderRecoveryList(frame,d,inbox.rows||[],'WA3');
          recoveryStatus(d,boot?'WA-3 recuperado automáticamente.':'Chats recuperados; bootstrap parcial: '+(bErr||'sin detalle'),!boot);
          return true;
        }).catch(function(e3){
          var iErr=e3.message;
          return reqJson('/api/wa/inbox?limit=120').then(function(inbox2){
            renderRecoveryList(frame,d,inbox2.rows||[],'WA2');
            recoveryStatus(d,'Fallback WA-2 activo. WA-3: '+(bErr||'bootstrap pendiente')+' / inbox: '+iErr,true);
            return true;
          }).catch(function(e2){
            recoveryStatus(d,'WA-3 bootstrap: '+(bErr||'OK')+' · WA-3 inbox: '+iErr+' · WA-2 inbox: '+e2.message,true);
            return false;
          });
        });
      });
    }catch(e){console.warn('[AOS-WA-SHELL] recovery',e);}
  },1800);
}
function mountWhatsApp(viewId){
  if(!allowed(viewId)){
    return window.__AOS_WA_BASE_NAV(AOS.role==='ADMIN'?'admin-home':'advisor-home');
  }
  if(AOS.activeView===viewId)return;
  AOS.activeView=viewId;
  markActive(viewId);
  var ws=document.getElementById('workspace');
  if(!ws)return;
  try{if(typeof window.aosCleanupPanelRuntime==='function')window.aosCleanupPanelRuntime();}catch(e){}
  ws.innerHTML='<iframe id="aos-wa-workspace" title="ASCENDA WhatsApp" src="/admin-whatsapp.html?embedded=1" style="display:block;width:100%;height:100%;border:0;background:#f2f5fb" referrerpolicy="same-origin"></iframe>';
  var frame=document.getElementById('aos-wa-workspace');
  frame.addEventListener('load',function(){
    try{
      var d=frame.contentDocument;
      if(!d)return;
      var top=d.querySelector('.top');if(top)top.style.display='none';
      var layout=d.querySelector('.layout');if(layout)layout.style.height='100%';
      var notice=d.querySelector('.notice');if(notice)notice.style.top='10px';
      d.documentElement.style.height='100%';d.body.style.height='100%';
      installRecovery(frame,d);
    }catch(e){console.warn('[AOS-WA-SHELL] embed styling skipped',e);}
  });
}
function boot(){
  BOOT_TRIES++;
  if(!window.AOS||!AOS.ctx||typeof window.buildSidebar!=='function'||typeof window.navigateTo!=='function'){
    if(BOOT_TRIES<BOOT_MAX)setTimeout(boot,100);
    return;
  }
  var p=perms();
  insertAfter(window.SIDEBAR_ADMIN,'admin-calls',{type:'item',id:'admin-whatsapp',ico:'chat',lbl:'WhatsApp Hub',requiresPanel:true,badge:'',badgeColor:'#16A34A'});
  if(p.indexOf('whatsapp-agent')>=0){
    insertAfter(window.SIDEBAR_ASESOR,'advisor-calls',{type:'item',id:'whatsapp-agent',ico:'chat',lbl:'WhatsApp',badge:'',badgeColor:'#16A34A'});
  }
  if(window.VIEW_MAP){VIEW_MAP['admin-whatsapp']='ViewWhatsApp';VIEW_MAP['whatsapp-agent']='ViewWhatsApp';}
  if(!window.__AOS_WA_BASE_NAV){
    window.__AOS_WA_BASE_NAV=window.navigateTo;
    var wrapped=function(viewId){
      if(viewId==='admin-whatsapp'||viewId==='whatsapp-agent')return mountWhatsApp(viewId);
      return window.__AOS_WA_BASE_NAV(viewId);
    };
    wrapped.__waShellWrapped=true;
    window.navigateTo=wrapped;
  }
  window.buildSidebar();
  var hash=String(location.hash||'').replace(/^#/,'');
  if(hash==='admin-whatsapp'||hash==='whatsapp-agent'){
    setTimeout(function(){window.navigateTo(hash);},0);
  }
}
boot();
})();
