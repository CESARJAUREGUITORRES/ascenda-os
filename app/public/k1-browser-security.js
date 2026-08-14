// ASCENDA OS — K1 browser security boundary, rebased on Phase 2 Auth V3.
// One canonical credential: sessionStorage.aos_app_token.
(function(){
  'use strict';
  if(window.__AOS_K1_BROWSER_BOUNDARY__)return;window.__AOS_K1_BROWSER_BOUNDARY__=true;
  var nativeFetch=window.fetch.bind(window);
  var SB='https://ituyqwstonmhnfshnaqz.supabase.co';
  var SAFE_INTEGRATION_COLUMNS='id,tipo,nombre,cuenta,estado,principal,categoria,icono,descripcion,uso_para,orden,url_docs,url_signup,multi_cuenta,logo_url,created_at,updated_at';
  function anonKey(){return String(window._SK||'')}
  function token(){try{return sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||''}catch(e){return ''}}
  function urlOf(i){return typeof i==='string'?i:(i&&i.url)||''}
  function body(i){try{return JSON.parse((i&&i.body)||'{}')}catch(e){return {}}}
  function resp(obj,status){return new Response(JSON.stringify(obj),{status:status||200,headers:{'Content-Type':'application/json'}})}
  function rpc(name,p){
    var k=anonKey();if(!k)return Promise.resolve(resp({ok:false,error:'SUPABASE_PUBLIC_KEY_UNAVAILABLE'},503));
    return nativeFetch(SB+'/rest/v1/rpc/'+name,{method:'POST',headers:{'Content-Type':'application/json','apikey':k,Authorization:'Bearer '+k},body:JSON.stringify(p||{})});
  }
  function rpcJson(name,p){return rpc(name,p).then(function(r){return r.json().then(function(d){if(!r.ok||d&&d.ok===false)throw new Error((d&&d.error)||('HTTP_'+r.status));return d})})}
  function sameOriginApi(raw){try{var u=new URL(raw,location.href);return u.origin===location.origin&&(u.pathname.indexOf('/api/kronia/')===0||u.pathname.indexOf('/api/agents/')===0)}catch(e){return false}}
  function withBearer(input,init){
    var t=token(),h=new Headers((init&&init.headers)||(input&&input.headers)||{});if(t)h.set('Authorization','Bearer '+t);h.delete('X-AOS-User');h.delete('X-AOS-Id');
    return [input,Object.assign({},init||{},{headers:h})];
  }
  function targetIdFrom(u){var x=u.searchParams.get('id')||'';return x.indexOf('eq.')===0?x.slice(3):''}
  function targetByCode(code){var k=anonKey();return nativeFetch(SB+'/rest/v1/aos_usuarios?select=id&codigo_asesor=eq.'+encodeURIComponent(code),{headers:{apikey:k,Authorization:'Bearer '+k}}).then(function(r){return r.json()}).then(function(rows){return rows&&rows[0]&&rows[0].id})}
  function identity(action,id,params){var t=token();if(!t)return Promise.reject(new Error('APP_SESSION_REQUIRED'));return rpcJson('aos_admin_identity_v4',{p_token:t,p_action:action,p_target_user_id:id,p_params:params||{}})}

  window.fetch=function(input,init){
    var raw=urlOf(input),method=String((init&&init.method)||(input&&input.method)||'GET').toUpperCase();
    if(sameOriginApi(raw)){var b=withBearer(input,init);return nativeFetch(b[0],b[1]);}

    var u;try{u=new URL(raw,location.href)}catch(e){return nativeFetch(input,init)}
    var rpcm=u.pathname.match(/\/rest\/v1\/rpc\/([^/]+)$/),fn=rpcm&&rpcm[1];

    if(fn==='aos_editar_venta'){
      var p=body(init);return rpc('aos_kronia_tool_v3',{p_token:token(),p_tool:'aos_editar_venta',p_params:{p_venta_id:p.p_venta_id,p_campos:p.p_campos||{},_session_id:'panel-'+Date.now()}});
    }
    if(fn==='aos_admin_toggle_usuario'){
      var p=body(init);return identity('toggle_active',p.p_usuario_id,{enabled:!!p.p_activar}).then(function(d){return resp(d,200)}).catch(function(e){return resp({ok:false,error:e.message},403)});
    }
    if(fn==='aos_admin_eliminar_usuario'){
      var p=body(init);return identity('delete_user',p.p_usuario_id,{}).then(function(d){return resp(d,200)}).catch(function(e){return resp({ok:false,error:e.message},403)});
    }
    if(fn==='aos_admin_cambiar_username'){
      var p=body(init);return identity('change_username',p.p_usuario_id,{username:p.p_nuevo_username}).then(function(d){return resp(d,200)}).catch(function(e){return resp({ok:false,error:e.message},403)});
    }

    if(u.hostname.indexOf('supabase.co')>=0&&u.pathname==='/rest/v1/aos_usuarios'&&method==='PATCH'){
      var id=targetIdFrom(u),p=body(init);if(!id)return Promise.resolve(resp({ok:false,error:'TARGET_REQUIRED'},403));
      var action='update_profile',params=p;
      if(Object.prototype.hasOwnProperty.call(p,'two_factor')){action='set_2fa';params={enabled:!!p.two_factor};}
      else if(Object.prototype.hasOwnProperty.call(p,'activo')){action='toggle_active';params={enabled:!!p.activo};}
      else if(Object.keys(p).every(function(k){return k==='servicios'||k==='cmp'})){action='set_services';params={servicios:p.servicios||[]};}
      return identity(action,id,params).then(function(){return new Response(null,{status:204})}).catch(function(e){return resp({ok:false,error:e.message},403)});
    }
    if(u.hostname.indexOf('supabase.co')>=0&&u.pathname==='/rest/v1/aos_rrhh'&&method==='PATCH'){
      var p=body(init),code=(u.searchParams.get('codigo_asesor')||'').replace(/^eq\./,'');
      if(Object.prototype.hasOwnProperty.call(p,'password_hash')&&code){
        return targetByCode(code).then(function(id){if(!id)throw new Error('TARGET_NOT_FOUND');return rpcJson('aos_admin_cambiar_password_v3',{p_token:token(),p_usuario_id:id,p_nueva_password:String(p.password_hash||'')})}).then(function(){return new Response(null,{status:204})}).catch(function(e){return resp({ok:false,error:e.message},403)});
      }
      return Promise.resolve(new Response(null,{status:204}));
    }

    if(u.hostname.indexOf('supabase.co')>=0&&u.pathname==='/rest/v1/aos_configuracion'&&['POST','PATCH','PUT','DELETE'].indexOf(method)>=0){
      if(method==='DELETE')return Promise.resolve(resp({ok:false,error:'CONFIG_DELETE_NOT_ALLOWED'},403));
      var p=body(init),key=(u.searchParams.get('clave')||p.clave||'').replace(/^eq\./,''),value=p.valor;
      if(!key||value===undefined)return Promise.resolve(resp({ok:false,error:'CONFIG_KEY_VALUE_REQUIRED'},400));
      return rpcJson('aos_admin_config_v3',{p_token:token(),p_clave:decodeURIComponent(key),p_valor:String(value)}).then(function(){return new Response(null,{status:204})}).catch(function(e){return resp({ok:false,error:e.message},403)});
    }

    if(u.hostname.indexOf('supabase.co')>=0&&u.pathname==='/rest/v1/aos_integraciones'){
      if(method==='GET'){
        u.searchParams.set('select',SAFE_INTEGRATION_COLUMNS);return nativeFetch(u.toString(),init);
      }
      var id=(u.searchParams.get('id')||'').replace(/^eq\./,'');
      if(method==='PATCH'&&id){
        return rpcJson('aos_admin_integracion_v3',{p_token:token(),p_id:id,p_action:'update',p_data:body(init)}).then(function(){return new Response(null,{status:204})}).catch(function(e){return resp({ok:false,error:e.message},403)});
      }
    }

    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_agente_logs'){
      return rpcJson('aos_kronia_feed_v3',{p_token:token(),p_feed:'agent_logs',p_limit:Number(u.searchParams.get('limit')||50)}).then(function(d){return resp(d.rows||[],200)}).catch(function(e){return resp({ok:false,error:e.message},403)});
    }
    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_log_auditoria'){
      return rpcJson('aos_kronia_feed_v3',{p_token:token(),p_feed:'audit',p_limit:Number(u.searchParams.get('limit')||50)}).then(function(d){return resp(d.rows||[],200)}).catch(function(e){return resp({ok:false,error:e.message},403)});
    }

    return nativeFetch(input,init);
  };
})();
