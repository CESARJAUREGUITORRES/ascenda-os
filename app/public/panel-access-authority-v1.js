// ASCENDA OS — Panel Access Authority V1
// Team > Roles y Permisos is the source of truth for sidebar visibility and
// mixed admin/operational access. Sensitive Team writes use a strong 2FA RPC.
(function(){
'use strict';
if(window.__AOS_PANEL_ACCESS_AUTHORITY_V1__)return;
window.__AOS_PANEL_ACCESS_AUTHORITY_V1__=true;

var PANEL_PREFIX=/^(admin-|advisor-|whatsapp-agent$)/;
var nativeFetch=window.fetch.bind(window);

function ctx(){return (window.AOS&&window.AOS.ctx)||{};}
function panels(){
  var p=ctx().paneles_acceso||[];
  if(typeof p==='string'){try{p=JSON.parse(p);}catch(_){p=[];}}
  return Array.isArray(p)?p:[];
}
function allowedMap(){var m={};panels().forEach(function(p){m[String(p)]=true;});return m;}
function hasPanel(id){return !!allowedMap()[String(id||'')];}
function isPanelId(id){return PANEL_PREFIX.test(String(id||''));}
function esc(s){
  if(typeof window.escHtml==='function')return window.escHtml(s);
  return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
function notify(title,body){
  try{if(typeof window.showToast==='function')window.showToast(title,body||'','toast-alerta');}
  catch(_){}
}
function uniqueMenuIds(menu){
  return (menu||[]).filter(function(x){return x&&x.type==='item'&&isPanelId(x.id);}).map(function(x){return x.id;});
}
function firstAllowed(){
  var a=allowedMap();
  var order=(window.AOS&&AOS.role==='ADMIN')
    ? uniqueMenuIds(window.SIDEBAR_ADMIN).concat(uniqueMenuIds(window.SIDEBAR_ASESOR))
    : uniqueMenuIds(window.SIDEBAR_ASESOR).concat(uniqueMenuIds(window.SIDEBAR_ADMIN));
  for(var i=0;i<order.length;i++)if(a[order[i]])return order[i];
  var raw=panels();
  return raw.length?raw[0]:'';
}

function filteredGroups(menu,allowed,seen){
  var out=[],section=null,items=[];
  function flush(){
    if(items.length){if(section)out.push(section);Array.prototype.push.apply(out,items);}
    items=[];
  }
  (menu||[]).forEach(function(it){
    if(!it)return;
    if(it.type==='section'){flush();section=it;return;}
    if(it.type==='item'){
      if(!isPanelId(it.id)||!allowed[it.id]||seen[it.id])return;
      seen[it.id]=true;items.push(it);
    }
  });
  flush();
  return out;
}

function governedBuildSidebar(){
  if(!document.getElementById('sb-content')||!Array.isArray(window.SIDEBAR_ADMIN)||!Array.isArray(window.SIDEBAR_ASESOR))return;
  var allowed=allowedMap(),seen={},items=[];
  if(window.AOS&&AOS.role==='ADMIN'){
    items=items.concat(filteredGroups(window.SIDEBAR_ADMIN,allowed,seen));
    items=items.concat(filteredGroups(window.SIDEBAR_ASESOR,allowed,seen));
  }else{
    items=items.concat(filteredGroups(window.SIDEBAR_ASESOR,allowed,seen));
    items=items.concat(filteredGroups(window.SIDEBAR_ADMIN,allowed,seen));
  }
  items.push({type:'sep',bot:true});
  if(!(window.AOS&&AOS.role==='ADMIN'))items.push({type:'item',id:'__profile',ico:'profile',lbl:'Mi perfil',bot:true});
  items.push({type:'item',id:'__logout',ico:'logout',lbl:'Salir',danger:true,bot:true});

  var host=document.getElementById('sb-content'),html='',inBot=false;
  items.forEach(function(it){
    if(it.bot&&!inBot){html+='<div class="sb-bot">';inBot=true;}
    if(it.type==='section')html+='<div class="ns">'+esc(it.label)+'</div>';
    else if(it.type==='sep'){if(!it.bot)html+='<div class="nsep"></div>';}
    else if(it.type==='item'){
      var ds=it.danger?'style="color:var(--red);"':'';
      var ls=it.danger?'style="color:var(--red);"':'';
      var bd=(it.badge!==undefined)?'<span class="ni-badge" style="background:'+(it.badgeColor||'#DC2626')+';display:none;" id="badge-nav-'+esc(it.id)+'"></span>':'';
      var ico=(typeof window.mkIco==='function')?window.mkIco(it.ico):'';
      html+='<div class="ni" id="nav-'+esc(it.id)+'" data-view="'+esc(it.id)+'" data-special="'+esc(it.special||'')+'" '+ds+'>'+ico+'<span class="ni-lbl" '+ls+'>'+esc(it.lbl)+'</span>'+bd+'</div>';
    }
  });
  if(inBot)html+='</div>';
  host.innerHTML=html;
  host.querySelectorAll('.ni[data-view]').forEach(function(n){
    n.addEventListener('click',function(){
      var v=this.getAttribute('data-view');
      if(v==='__logout'){if(typeof window.openLogoutModal==='function')window.openLogoutModal();return;}
      if(v==='__profile')return;
      if(v==='advisor-leads'){if(window.AOS_openLeads)window.AOS_openLeads();return;}
      if(v==='admin-import-ventas'){if(window.AOS_openImportVentas)window.AOS_openImportVentas();return;}
      if(typeof window.navigateTo==='function')window.navigateTo(v);
    });
  });
}
governedBuildSidebar.__panelAuthorityV1=true;

function installNavigationAuthority(){
  if(typeof window.navigateTo!=='function')return false;
  if(window.navigateTo.__panelAuthorityV1)return true;
  var baseNavigate=window.navigateTo;
  function governedNavigate(viewId){
    var id=String(viewId||'');
    if(isPanelId(id)&&!hasPanel(id)){
      var fallback=firstAllowed();
      notify('Acceso no asignado','El panel '+id+' no está habilitado para este usuario.');
      if(fallback&&fallback!==id)return baseNavigate.call(this,fallback);
      return;
    }
    return baseNavigate.apply(this,arguments);
  }
  governedNavigate.__panelAuthorityV1=true;
  governedNavigate.__base=baseNavigate;
  window.navigateTo=governedNavigate;
  return true;
}

function installSidebarAuthority(){
  if(typeof window.buildSidebar!=='function')return false;
  window.buildSidebar=governedBuildSidebar;
  governedBuildSidebar();
  var current=window.AOS&&AOS.activeView;
  if(current&&isPanelId(current)&&!hasPanel(current)){
    var fallback=firstAllowed();
    if(fallback&&typeof window.navigateTo==='function')window.navigateTo(fallback);
  }
  return true;
}

function urlOf(input){return typeof input==='string'?input:(input&&input.url)||'';}
function parseBody(init){try{return JSON.parse((init&&init.body)||'{}');}catch(_){return {};}}
function cacheToken(){
  if(!('caches' in window))return Promise.resolve('');
  return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token');}).then(function(r){return r?r.text():'';}).catch(function(){return '';});
}
function strongToken(){
  var s='';try{s=String(sessionStorage.getItem('aos_app_token')||'').trim();}catch(_){}
  if(s.length>=32)return Promise.resolve(s);
  return cacheToken().then(function(t){
    t=String(t||'').trim();
    if(t.length>=32)try{sessionStorage.setItem('aos_app_token',t);}catch(_){}
    return t;
  });
}
function targetId(url){
  try{
    var u=new URL(url,location.origin),v=u.searchParams.get('id')||'';
    return v.indexOf('eq.')===0?v.slice(3):'';
  }catch(_){return '';}
}
function isSensitiveUserPatch(url,init,body){
  return String((init&&init.method)||'GET').toUpperCase()==='PATCH'
    && url.indexOf('/rest/v1/aos_usuarios?')>=0
    && (Object.prototype.hasOwnProperty.call(body,'paneles_acceso')
      ||Object.prototype.hasOwnProperty.call(body,'nivel_jerarquia')
      ||Object.prototype.hasOwnProperty.call(body,'rol'));
}
function rpcBase(url){return url.split('/rest/v1/')[0];}
function updateCurrentContext(out){
  if(!out||!out.ok||!window.AOS||!AOS.ctx)return;
  if(String(out.codigo_asesor||'')!==String(AOS.ctx.idAsesor||''))return;
  AOS.ctx.paneles_acceso=out.paneles_acceso||[];
  AOS.ctx.nivel=Number(out.nivel_jerarquia||AOS.ctx.nivel||4);
  AOS.role=AOS.ctx.nivel<=2?'ADMIN':'ASESOR';
  try{
    var s=JSON.parse(localStorage.getItem('aos_session')||'{}');
    s.paneles_acceso=AOS.ctx.paneles_acceso;s.nivel=AOS.ctx.nivel;
    localStorage.setItem('aos_session',JSON.stringify(s));
  }catch(_){}
  governedBuildSidebar();
}
function governedTeamPatch(input,init,url,body){
  var id=targetId(url);
  if(!id)return Promise.reject(new Error('TEAM_TARGET_ID_REQUIRED'));
  var sensitive={
    p_target_user_id:id,
    p_paneles:Array.isArray(body.paneles_acceso)?body.paneles_acceso:[],
    p_nivel:Number(body.nivel_jerarquia)
  };
  var rest={};Object.keys(body).forEach(function(k){if(k!=='paneles_acceso'&&k!=='nivel_jerarquia'&&k!=='rol')rest[k]=body[k];});
  return strongToken().then(function(token){
    if(String(token||'').length<32)throw new Error('TEAM_STRONG_2FA_TOKEN_REQUIRED');
    sensitive.p_token=token;
    var h=new Headers((init&&init.headers)||{});h.set('Content-Type','application/json');
    return nativeFetch(rpcBase(url)+'/rest/v1/rpc/aos_team_set_access_v1',{
      method:'POST',headers:h,body:JSON.stringify(sensitive),cache:'no-store'
    });
  }).then(function(r){
    return r.clone().json().catch(function(){return null;}).then(function(d){
      if(!r.ok||!d||d.ok!==true){
        var code=d&&d.error?d.error:('HTTP_'+r.status);
        notify('No se guardaron los permisos',code);
        throw new Error(code);
      }
      updateCurrentContext(d);
      var keys=Object.keys(rest);
      if(!keys.length)return new Response('',{status:204});
      var next=Object.assign({},init||{}, {body:JSON.stringify(rest)});
      return nativeFetch(input,next).then(function(profileRes){
        if(!profileRes.ok){notify('Permisos guardados, perfil pendiente','HTTP '+profileRes.status);throw new Error('TEAM_PROFILE_PATCH_'+profileRes.status);}
        return profileRes;
      });
    });
  });
}

function installFetchAuthority(){
  if(window.fetch&&window.fetch.__panelAuthorityV1)return;
  nativeFetch=window.fetch.bind(window);
  function governedFetch(input,init){
    var url=urlOf(input),body=parseBody(init);
    if(isSensitiveUserPatch(url,init,body))return governedTeamPatch(input,init,url,body);
    return nativeFetch(input,init);
  }
  governedFetch.__panelAuthorityV1=true;
  governedFetch.__base=nativeFetch;
  window.fetch=governedFetch;
}

function install(){
  installFetchAuthority();
  installNavigationAuthority();
  installSidebarAuthority();
}
install();
setTimeout(install,0);
setTimeout(install,500);
setTimeout(install,1800);
try{window.addEventListener('focus',function(){install();governedBuildSidebar();});}catch(_){}
try{document.addEventListener('visibilitychange',function(){if(!document.hidden){install();governedBuildSidebar();}});}catch(_){}
})();
