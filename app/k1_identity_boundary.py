from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parent
path=ROOT/'public/admin-team.html'
s=path.read_text(encoding='utf-8')

shim=r'''
// ═══ K1 IDENTITY BOUNDARY — compatibility shim ═══
(function(){
  var K1_RAW_FETCH=window.fetch.bind(window);
  function k1Token(){try{return sessionStorage.getItem('aos_kronia_token')||(window.parent&&window.parent!==window?window.parent.sessionStorage.getItem('aos_kronia_token'):'')||''}catch(e){return ''}}
  function k1Json(obj,status){return new Response(JSON.stringify(obj),{status:status||200,headers:{'Content-Type':'application/json'}})}
  function k1UserById(id){return (window.U||[]).find(function(x){return String(x.id)===String(id)})||null}
  function k1UserByCode(code){return (window.U||[]).find(function(x){return String(x.codigo_asesor||'').toLowerCase()===String(code||'').toLowerCase()})||null}
  function k1UserByName(name){return (window.U||[]).find(function(x){return String(x.nombre||'').toUpperCase()===String(name||'').toUpperCase()})||null}
  function k1TargetFromUrl(u){
    var id=(u.searchParams.get('id')||'').replace(/^eq\./,'');if(id)return k1UserById(id);
    var code=(u.searchParams.get('codigo_asesor')||'').replace(/^eq\./,'');if(code)return k1UserByCode(decodeURIComponent(code));
    var name=(u.searchParams.get('nombre')||'').replace(/^eq\./,'');if(name)return k1UserByName(decodeURIComponent(name));
    return null;
  }
  function k1Identity(action,targetId,params){
    var token=k1Token();if(!token)return Promise.resolve(k1Json({ok:false,error:'ADMIN_SESSION_REQUIRED'},401));
    return K1_RAW_FETCH(SB+'/rest/v1/rpc/aos_kronia_admin_identity_safe',{
      method:'POST',headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'},
      body:JSON.stringify({p_token:token,p_action:action,p_target_user_id:targetId||null,p_params:params||{}})
    });
  }
  function k1AsTableMutation(action,targetId,params){
    return k1Identity(action,targetId,params).then(function(r){return r.clone().json().catch(function(){return {ok:false,error:'INVALID_GATEWAY_RESPONSE'}}).then(function(j){if(!r.ok||!j.ok)throw new Error(j.error||('HTTP_'+r.status));return new Response(null,{status:204});});});
  }
  function bodyJson(opts){try{return JSON.parse((opts&&opts.body)||'{}')}catch(e){return {}}}
  function scrubCredentialEmail(opts){
    if(!opts||!opts.body)return opts;
    try{
      var b=JSON.parse(opts.body);if(!b||!b.html||b.html.indexOf('Contraseña:')<0)return opts;
      b.html=b.html
        .replace(/<span[^>]*>Contraseña:<\/span><span[^>]*>.*?<\/span>/gi,'<span style="color:#6B7BA8;font-weight:700;">Contraseña:</span><span>Entregada por el administrador mediante canal seguro</span>')
        .replace(/(<b>Contraseña:<\/b>)[^<]*(<\/p>)/gi,'$1 Entregada por el administrador mediante canal seguro$2');
      return Object.assign({},opts,{body:JSON.stringify(b)});
    }catch(e){return opts}
  }
  window.fetch=function(url,opts){
    var raw=String(url||''), method=String((opts&&opts.method)||'GET').toUpperCase();
    var u;try{u=new URL(raw,window.location.origin)}catch(e){return K1_RAW_FETCH(url,opts)}

    // Never email a plaintext/temporary password from the Team UI.
    if(u.pathname==='/api/send-email'||raw.indexOf('/api/send-email')>=0){return K1_RAW_FETCH(url,scrubCredentialEmail(opts));}

    // Direct identity-table writes are redirected to the token-bound gateway.
    if(raw.indexOf('/rest/v1/aos_usuarios?')>=0 && method==='PATCH'){
      var target=k1TargetFromUrl(u), b=bodyJson(opts);if(!target)return Promise.reject(new Error('K1_TARGET_NOT_FOUND'));
      if(Object.prototype.hasOwnProperty.call(b,'two_factor'))return k1AsTableMutation('set_2fa',target.id,{enabled:!!b.two_factor});
      if(Object.prototype.hasOwnProperty.call(b,'activo'))return k1AsTableMutation('toggle_active',target.id,{enabled:!!b.activo});
      if(Object.prototype.hasOwnProperty.call(b,'cuenta_activada'))return Promise.resolve(new Response(null,{status:204}));
      return k1AsTableMutation('update_profile',target.id,b);
    }
    if(raw.indexOf('/rest/v1/aos_rrhh?')>=0 && method==='PATCH'){
      var rrTarget=k1TargetFromUrl(u), rb=bodyJson(opts);if(!rrTarget)return Promise.reject(new Error('K1_TARGET_NOT_FOUND'));
      if(Object.prototype.hasOwnProperty.call(rb,'password_hash'))return k1AsTableMutation('activate_account',rrTarget.id,{password:String(rb.password_hash||'')});
      // Name/cargo/sede synchronization is already performed by update_profile.
      return Promise.resolve(new Response(null,{status:204}));
    }

    // Retire legacy SECURITY DEFINER identity RPC calls from the browser.
    if(raw.indexOf('/rest/v1/rpc/aos_admin_cambiar_username')>=0){var b=bodyJson(opts);return k1Identity('change_username',b.p_usuario_id,{username:b.p_nuevo_username});}
    if(raw.indexOf('/rest/v1/rpc/aos_admin_cambiar_password')>=0){var b=bodyJson(opts),t=b.p_usuario_id?k1UserById(b.p_usuario_id):k1UserByCode(b.p_codigo_asesor);return t?k1Identity('change_password',t.id,{password:b.p_nueva_password}):Promise.resolve(k1Json({ok:false,error:'TARGET_NOT_FOUND'},404));}
    if(raw.indexOf('/rest/v1/rpc/aos_admin_crear_usuario')>=0){var b=bodyJson(opts);return k1Identity('create_user',null,{nombre:b.p_nombre,apellido:b.p_apellido,email:b.p_email,telefono:b.p_telefono,cargo:b.p_cargo,area:b.p_area,nivel_jerarquia:b.p_nivel_jerarquia,acceso_geo:b.p_acceso_geo,sede:b.p_sede});}
    if(raw.indexOf('/rest/v1/rpc/aos_admin_toggle_usuario')>=0){var b=bodyJson(opts);return k1Identity('toggle_active',b.p_usuario_id,{enabled:!!b.p_activar});}
    if(raw.indexOf('/rest/v1/rpc/aos_admin_eliminar_usuario')>=0){var b=bodyJson(opts);return k1Identity('delete_user',b.p_usuario_id,{});}

    // Force-logout is an identity action, not an anonymous audit-table insert.
    if(raw.indexOf('/rest/v1/aos_security_log')>=0 && method==='POST'){
      var b=bodyJson(opts);if(b.accion==='force_logout'){var t=k1UserByName(b.usuario);return t?k1Identity('force_logout',t.id,{}):Promise.resolve(k1Json({ok:false,error:'TARGET_NOT_FOUND'},404));}
    }
    return K1_RAW_FETCH(url,opts);
  };
})();
'''

if 'K1 IDENTITY BOUNDARY — compatibility shim' not in s:
    idx=s.rfind('loadTeam();')
    if idx<0: raise SystemExit('K1 identity boundary: loadTeam anchor missing')
    s=s[:idx]+shim+'\n'+s[idx:]

# Gateway enforces >=8. Match UI validation so legacy chains cannot report a
# false success for 6–7 character passwords.
s=s.replace('pw.length<6','pw.length<8').replace('Mínimo 6 caracteres','Mínimo 8 caracteres').replace('mínimo 6 caracteres','mínimo 8 caracteres').replace('Contraseña mínimo 6 caracteres','Contraseña mínimo 8 caracteres')

# Materialization must be deterministic and git-diff clean. The source HTML has
# historical blank lines containing spaces; strip trailing whitespace from every
# line so `git diff --check` certifies the generated artifact rather than failing
# on unrelated formatting residue.
had_final_newline=s.endswith('\n')
s='\n'.join(line.rstrip() for line in s.splitlines())+('\n' if had_final_newline else '')
path.write_text(s,encoding='utf-8')

# Final deploy manifest v3 includes the Team identity surface. Config boundary
# runs after this materializer and upgrades the manifest to runtime-v4.
manifest_path=ROOT/'k1-runtime-manifest.json'
m=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'files':{}}
targets=['server.js','public/app.html','public/kronia-core.js','public/login.html','public/admin-sales.html','public/admin-config.html','public/agents.html','public/cerebro.html','public/admin-team.html']
m={'contract':'kronia-k1-runtime-v3','files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in targets}}
manifest_path.write_text(json.dumps(m,sort_keys=True,indent=2)+'\n',encoding='utf-8')
print('KRONIA_K1_IDENTITY_BOUNDARY=PASS')
for p,d in m['files'].items():print(p+' '+d)
