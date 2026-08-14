from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parent
path=ROOT/'public/admin-config.html'
s=path.read_text(encoding='utf-8')

shim=r'''
<script>
// ═══ K1 SECURITY CONFIG BOUNDARY ═══
(function(){
  var K1_CONFIG_FETCH=window.fetch.bind(window);
  function token(){try{return sessionStorage.getItem('aos_kronia_token')||(window.parent&&window.parent!==window?window.parent.sessionStorage.getItem('aos_kronia_token'):'')||''}catch(e){return ''}}
  function jsonResponse(obj,status){return new Response(JSON.stringify(obj),{status:status||200,headers:{'Content-Type':'application/json'}})}
  function parseBody(opts){try{return JSON.parse((opts&&opts.body)||'{}')}catch(e){return {}}}
  function gateway(key,value){
    var t=token();if(!t)return Promise.resolve(jsonResponse({ok:false,error:'ADMIN_SESSION_REQUIRED'},401));
    return K1_CONFIG_FETCH(SB+'/rest/v1/rpc/aos_kronia_admin_config_safe',{
      method:'POST',headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'},
      body:JSON.stringify({p_token:t,p_clave:key,p_valor:String(value)})
    });
  }
  window.fetch=function(url,opts){
    var raw=String(url||''),method=String((opts&&opts.method)||'GET').toUpperCase();
    if(raw.indexOf('/rest/v1/aos_configuracion')>=0 && ['POST','PATCH','PUT','DELETE'].indexOf(method)>=0){
      if(method==='DELETE')return Promise.resolve(jsonResponse({ok:false,error:'CONFIG_DELETE_NOT_ALLOWED'},403));
      var u;try{u=new URL(raw,window.location.origin)}catch(e){return Promise.resolve(jsonResponse({ok:false,error:'CONFIG_URL_INVALID'},400))}
      var b=parseBody(opts),key=(u.searchParams.get('clave')||b.clave||'').replace(/^eq\./,''),value=b.valor;
      if(!key||value===undefined)return Promise.resolve(jsonResponse({ok:false,error:'CONFIG_KEY_VALUE_REQUIRED'},400));
      return gateway(decodeURIComponent(key),value).then(function(r){return r.clone().json().catch(function(){return {ok:false,error:'INVALID_GATEWAY_RESPONSE'}}).then(function(j){if(!r.ok||!j.ok)throw new Error(j.error||('HTTP_'+r.status));return new Response(null,{status:204});});});
    }
    return K1_CONFIG_FETCH(url,opts);
  };
})();
</script>
'''

if 'K1 SECURITY CONFIG BOUNDARY' not in s:
    idx=s.lower().rfind('</body>')
    if idx<0: raise SystemExit('K1 config boundary: body close anchor missing')
    s=s[:idx]+shim+'\n'+s[idx:]
path.write_text(s,encoding='utf-8')

manifest=ROOT/'k1-runtime-manifest.json'
m=json.loads(manifest.read_text()) if manifest.exists() else {'files':{}}
targets=['server.js','public/app.html','public/kronia-core.js','public/login.html','public/admin-sales.html','public/admin-config.html','public/agents.html','public/cerebro.html','public/admin-team.html']
m={'contract':'kronia-k1-runtime-v4','files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in targets}}
manifest.write_text(json.dumps(m,sort_keys=True,indent=2)+'\n',encoding='utf-8')
print('KRONIA_K1_CONFIG_BOUNDARY=PASS')
for p,d in m['files'].items(): print(p+' '+d)
