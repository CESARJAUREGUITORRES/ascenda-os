// ASCENDA OS — Phase 2 browser cutover shim.
// Additive-first: if a v2 gateway is not installed yet, legacy behavior is retained.
(function(){
  'use strict';
  var nativeFetch=window.fetch.bind(window);
  var protectedTables={
    aos_catalogo_categorias:1,aos_catalogo_servicios:1,aos_catalogo_toppings:1,
    aos_catalogo_productos_detalle:1,aos_planes_trabajo:1,aos_plan_trabajo_items:1
  };
  var cajaMap={
    aos_caja_abrir:'aos_caja_abrir_v2',
    aos_caja_cerrar:'aos_caja_cerrar_v2',
    aos_caja_editar_pago:'aos_caja_editar_pago_v2',
    aos_caja_eliminar_venta:'aos_caja_eliminar_venta_v2',
    aos_caja_ingreso_extra:'aos_caja_ingreso_extra_v2',
    aos_caja_registrar_gasto:'aos_caja_registrar_gasto_v2'
  };
  function urlOf(input){return typeof input==='string'?input:(input&&input.url)||'';}
  function token(){try{return sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||''}catch(e){return ''}}
  function body(init){try{return JSON.parse((init&&init.body)||'{}')}catch(e){return {}}}
  function makeResponse(payload,status){return new Response(JSON.stringify(payload),{status:status||200,headers:{'Content-Type':'application/json'}});}
  function rpcUrl(url,name){var base=url.split('/rest/v1/')[0];return base+'/rest/v1/rpc/'+name;}
  function postGateway(url,init,name,payload){
    var headers=Object.assign({},(init&&init.headers)||{});headers['Content-Type']='application/json';
    return nativeFetch(rpcUrl(url,name),{method:'POST',headers:headers,body:JSON.stringify(payload)});
  }
  function gatewayMissing(r){return r.status===404||r.status===400;}
  function parseEqMatch(u){
    var out={};
    u.searchParams.forEach(function(v,k){
      if(k==='select'||k==='order'||k==='limit'||k==='offset')return;
      if(String(v).indexOf('eq.')!==0)throw new Error('FILTER_NOT_ALLOWED');
      out[k]=String(v).slice(3);
    });
    return out;
  }
  window.fetch=function(input,init){
    var url=urlOf(input),method=String((init&&init.method)||'GET').toUpperCase();

    var rpcMatch=url.match(/\/rest\/v1\/rpc\/([^?]+)/);
    if(rpcMatch&&cajaMap[rpcMatch[1]]){
      var oldName=rpcMatch[1],newName=cajaMap[oldName],p=body(init),t=token();
      p.p_token=t;delete p.p_usuario;
      return postGateway(url,init,newName,p).then(function(r){
        if(gatewayMissing(r))return nativeFetch(input,init);
        return r;
      }).catch(function(){return nativeFetch(input,init);});
    }

    if(method==='POST'||method==='PATCH'||method==='DELETE'){
      try{
        var u=new URL(url,location.href);
        var m=u.pathname.match(/\/rest\/v1\/([^/]+)$/);
        var table=m&&m[1];
        if(table&&protectedTables[table]){
          var payload={p_token:token(),p_table:table,p_action:method==='POST'?'INSERT':method,p_match:parseEqMatch(u),p_data:method==='DELETE'?{}:body(init)};
          return postGateway(url,init,'aos_secure_write_v2',payload).then(function(r){
            if(gatewayMissing(r))return nativeFetch(input,init);
            return r.json().then(function(d){
              if(!d||d.ok===false)return makeResponse(d||{ok:false,error:'WRITE_REJECTED'},403);
              return makeResponse(d.rows||[],200);
            });
          }).catch(function(e){
            if(e&&e.message==='FILTER_NOT_ALLOWED')return Promise.resolve(makeResponse({ok:false,error:'FILTER_NOT_ALLOWED'},403));
            return nativeFetch(input,init);
          });
        }
      }catch(e){
        if(e&&e.message==='FILTER_NOT_ALLOWED')return Promise.resolve(makeResponse({ok:false,error:'FILTER_NOT_ALLOWED'},403));
      }
    }
    return nativeFetch(input,init);
  };
})();
