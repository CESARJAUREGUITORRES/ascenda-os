/* ASCENDA CIA · Audience Workspace V3
   Product model: Audiencias -> Distribución -> Actividad -> Explorar.
   Dynamic audience definitions are separate from execution snapshots/assignments.
   No automatic sends. One-contact Call Center test remains the only assignment mutation. */
(function(){
'use strict';
if(window.__ASCENDA_CIA_AUDIENCE_WORKSPACE_V3__)return;
window.__ASCENDA_CIA_AUDIENCE_WORKSPACE_V3__=true;

var state={
  meta:null,boot:null,library:null,tab:'audiences',category:'ALL',query:'',
  selected:null,preview:[],advisor:null,canary:null,armedUntil:0,
  activity:null,controllers:{},seq:{}
};

var CAT={
  ALL:{label:'Todas',icon:'✦'},
  LEAD:{label:'Leads',icon:'◎'},
  CALL:{label:'Llamadas',icon:'☎'},
  APPOINTMENT:{label:'Citas',icon:'◷'},
  FOLLOWUP:{label:'Seguimientos',icon:'↻'},
  SEGMENT:{label:'Clientes y valor',icon:'◆'},
  SALE:{label:'Ventas y compras',icon:'S/'},
  EMAIL:{label:'Email',icon:'@'},
  DEMOGRAPHIC:{label:'Demografía',icon:'◉'},
  CONTACT:{label:'Calidad de datos',icon:'✓'},
  CRM:{label:'CRM y sede',icon:'⌂'},
  CUSTOM:{label:'Personalizadas',icon:'◇'}
};

function esc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]})}
function fmt(v){var n=Number(v);return Number.isFinite(n)?new Intl.NumberFormat('es-PE').format(n):'—'}
function dt(v){if(!v)return 'Sin actualizar';try{return new Date(v).toLocaleString('es-PE',{dateStyle:'short',timeStyle:'short'})}catch(_){return String(v)}}
function cat(k){return CAT[k]||{label:k||'Otros',icon:'•'}}
function token(){try{return String(sessionStorage.getItem('aos_app_token')||'').trim()}catch(_){return''}}
function cfg(){return {sb:window._SB||'https://ituyqwstonmhnfshnaqz.supabase.co',key:window._SK||''}}
function slug(s){return String(s||'audiencia').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-zA-Z0-9-_]+/g,'-').replace(/^-+|-+$/g,'').toLowerCase().slice(0,80)||'audiencia'}
function toast(msg,bad){if(window.AOS_showToast){AOS_showToast((bad?'⚠️ ':'✅ ')+msg,'','');return}console[bad?'warn':'log']('[CIA-V3]',msg)}
function silent(e){var m=String(e&&e.message||'');return m==='STALE_RESPONSE'||m==='REQUEST_REPLACED'||(e&&e.name==='AbortError')||/aborted without reason/i.test(m)}
function friendly(e){var m=String(e&&e.message||'Error inesperado'),x={
  HTTP_500:'No se pudo completar la consulta. Intenta nuevamente.',
  CONTROL_CENTER_V3_ERROR:'No se pudo completar la operación.',
  CATALOG_REFRESH_FAILED:'No se pudieron actualizar los conteos. El catálogo anterior sigue disponible.',
  UNAUTHORIZED:'Tu sesión venció. Vuelve a ingresar.',
  FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED:'Esta acción requiere sesión de administrador verificada.',
  CANARY_ALREADY_ACTIVE:'Ya existe una prueba activa. Ciérrala antes de iniciar otra.',
  ROUTING_NOT_BASELINE:'Call Center no está en modo normal. No se inició la prueba.',
  INVALID_CALL_ADVISOR:'El asesor seleccionado no tiene Call Center habilitado.',
  EXPORT_LIMIT_EXCEEDED:'La exportación supera el límite seguro.',
  CATALOG_AUDIENCE_STALE:'La audiencia guardada no coincide con la regla actual. Se bloqueó la asignación.'
};return x[m]||m.replace(/^HTTP_/,'Error ')}
function report(e,target){if(silent(e))return;var msg=friendly(e),el=target&&document.getElementById(target);if(el){el.textContent=msg;el.classList.add('aw-state-warn')}toast(msg,true);try{console.warn('[CIA-WORKSPACE-V3]',e)}catch(_){}}

function rpc(action,payload,opt){
  opt=opt||{};var c=cfg(),t=token();if(!c.key||t.length<32)return Promise.reject(new Error('UNAUTHORIZED'));
  var key=opt.key||String(action||'main');
  if(opt.replace!==false&&state.controllers[key])try{state.controllers[key].abort('REQUEST_REPLACED')}catch(_e){}
  var ctl=new AbortController();state.controllers[key]=ctl;state.seq[key]=(state.seq[key]||0)+1;var seq=state.seq[key];
  return fetch(c.sb+'/rest/v1/rpc/aos_cia_control_center_app_v3',{
    method:'POST',signal:ctl.signal,cache:'no-store',
    headers:{apikey:c.key,Authorization:'Bearer '+c.key,'Content-Type':'application/json','Cache-Control':'no-store'},
    body:JSON.stringify({p_app_token:t,p_action:action,p_payload:payload||{}})
  }).then(function(r){return r.json().catch(function(){return null}).then(function(d){
    if(opt.replace!==false&&seq!==state.seq[key])throw new Error('STALE_RESPONSE');
    if(!r.ok||!d||d.ok!==true)throw new Error((d&&d.error)||('HTTP_'+r.status));
    return d;
  })}).catch(function(e){if(ctl.signal.aborted||(e&&e.name==='AbortError'))throw new Error('STALE_RESPONSE');throw e});
}

function installButton(){
  var root=document.querySelector('#workspace .ac');if(!root||document.getElementById('cia-audience-open'))return;
  var hdr=root.querySelector('.ac-hdr>div:last-child')||root.querySelector('.ac-hdr');if(!hdr)return;
  var b=document.createElement('button');b.id='cia-audience-open';b.className='chip';
  b.style.cssText='background:#071D4A;color:#fff;border-color:#071D4A;font-family:DM Sans;';
  b.textContent='🎯 Audiencias';b.onclick=open;hdr.appendChild(b);
}

function styles(){
  if(document.getElementById('cia-aw-v3-style'))return;
  var s=document.createElement('style');s.id='cia-aw-v3-style';
  s.textContent=`
#cia-aw{--navy:#071d4a;--blue:#0a4fbf;--mint:#00a88a;--ink:#15233f;--muted:#6d7d9e;--line:#dfe6f1;--soft:#f5f8fc;--danger:#b42318;font-family:DM Sans,system-ui,-apple-system,Segoe UI,sans-serif}
#cia-aw *{box-sizing:border-box}#cia-aw button,#cia-aw input,#cia-aw select{font:inherit}
.aw-shell{width:min(1480px,98vw);height:min(930px,96vh);background:#f6f8fc;border-radius:22px;overflow:hidden;display:flex;flex-direction:column;box-shadow:0 36px 110px rgba(5,25,62,.34);border:1px solid rgba(255,255,255,.7)}
.aw-head{height:72px;padding:0 20px;background:linear-gradient(135deg,#071d4a,#0d367f);display:flex;align-items:center;gap:14px;color:#fff;flex:0 0 auto}
.aw-head-main{flex:1;min-width:0}.aw-title{font:800 21px Exo 2,DM Sans,sans-serif}.aw-sub{font-size:10px;opacity:.76;margin-top:3px}
.aw-head-stat{padding:8px 10px;border:1px solid rgba(255,255,255,.14);background:rgba(255,255,255,.08);border-radius:11px;min-width:110px}.aw-head-stat span{display:block;font-size:8px;opacity:.68;text-transform:uppercase}.aw-head-stat b{display:block;font-size:13px;margin-top:2px}
.aw-close{width:38px;height:38px;border:0;border-radius:11px;background:rgba(255,255,255,.12);color:#fff;font-size:18px;cursor:pointer}
.aw-tabs{height:52px;background:#fff;border-bottom:1px solid var(--line);display:flex;align-items:flex-end;padding:0 16px;gap:3px;flex:0 0 auto}
.aw-tab{height:43px;border:0;border-bottom:3px solid transparent;background:transparent;padding:0 16px;color:#7180a1;font-size:11px;font-weight:800;cursor:pointer}.aw-tab.active{color:var(--navy);border-bottom-color:var(--blue)}
.aw-main{min-height:0;flex:1;overflow:hidden}.aw-view{display:none;height:100%}.aw-view.active{display:block}
.aw-audience-grid{height:100%;display:grid;grid-template-columns:210px minmax(470px,1fr) 410px}
.aw-side{background:#fff;border-right:1px solid var(--line);padding:13px;overflow:auto}.aw-side-title{font-size:10px;font-weight:900;color:#8090ac;text-transform:uppercase;letter-spacing:.07em;margin:5px 7px 9px}
.aw-cat{width:100%;display:flex;align-items:center;gap:8px;padding:9px 10px;margin:2px 0;border:0;border-radius:10px;background:transparent;color:#566a91;font-size:10px;font-weight:800;cursor:pointer;text-align:left}.aw-cat:hover{background:#f3f7fc}.aw-cat.active{background:#eaf2ff;color:#164f9e}.aw-cat-icon{width:22px;height:22px;border-radius:7px;background:#eef3f9;display:grid;place-items:center}.aw-cat.active .aw-cat-icon{background:#d7e7ff}.aw-cat-count{margin-left:auto;font-size:8px;background:#f0f3f8;border-radius:999px;padding:3px 6px}
.aw-center{padding:14px;overflow:auto}.aw-toolbar{display:flex;align-items:center;gap:8px;margin-bottom:10px}.aw-search{flex:1;border:1px solid #d5deeb;background:#fff;border-radius:11px;padding:10px 12px;outline:none}.aw-search:focus{border-color:#8bb1eb;box-shadow:0 0 0 3px rgba(10,79,191,.07)}
.aw-btn{border:0;border-radius:10px;padding:9px 11px;font-size:9px;font-weight:900;cursor:pointer;white-space:nowrap}.aw-btn:disabled{opacity:.42;cursor:not-allowed}.aw-primary{background:var(--blue);color:#fff}.aw-secondary{background:#fff;border:1px solid #bdc9da;color:#405578}.aw-success{background:var(--mint);color:#fff}.aw-danger{background:#fff;border:1px solid #e4aaa6;color:var(--danger)}
.aw-info{display:flex;gap:8px;margin-bottom:10px}.aw-kpi{flex:1;background:#fff;border:1px solid var(--line);border-radius:12px;padding:10px}.aw-kpi span{display:block;font-size:8px;color:#8090aa;text-transform:uppercase;letter-spacing:.05em}.aw-kpi b{display:block;font-size:18px;color:var(--navy);margin-top:3px}.aw-kpi small{display:block;font-size:8px;color:#8a98b1;margin-top:2px}
.aw-table-wrap{background:#fff;border:1px solid var(--line);border-radius:13px;overflow:auto}.aw-table{width:100%;border-collapse:collapse;font-size:9px}.aw-table th{text-align:left;padding:9px 10px;background:#f7f9fc;color:#66799c;position:sticky;top:0;z-index:2}.aw-table td{padding:10px;border-top:1px solid #edf1f6;color:#283a58;vertical-align:middle}.aw-table tr[data-key]{cursor:pointer}.aw-table tr[data-key]:hover td{background:#f8fbff}.aw-table tr.selected td{background:#edf5ff}.aw-name{font-size:10px;font-weight:900;color:var(--ink)}.aw-desc{font-size:8px;color:#8291ab;margin-top:2px;max-width:440px}.aw-badge{display:inline-block;padding:4px 6px;border-radius:999px;background:#eef3f9;color:#576d91;font-size:8px;font-weight:800}.aw-count{font-size:13px;font-weight:900;color:var(--navy)}.aw-fresh{font-size:8px;color:#8392ac}.aw-empty{padding:36px;text-align:center;color:#8a99b3;font-size:10px}
.aw-detail{background:#fff;border-left:1px solid var(--line);padding:15px;overflow:auto}.aw-detail-empty{height:100%;display:grid;place-items:center;text-align:center;color:#8999b5;font-size:10px;padding:30px}.aw-detail-title{font-size:17px;font-weight:900;color:var(--ink)}.aw-detail-copy{font-size:10px;line-height:1.45;color:var(--muted);margin:5px 0 12px}.aw-detail-count{font-size:34px;font-weight:900;color:var(--navy)}.aw-detail-count small{font-size:9px;color:#8997b0;font-weight:700}.aw-detail-meta{font-size:8px;color:#8997b0;margin:2px 0 10px}.aw-detail-actions{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin:10px 0}.aw-detail-actions .wide{grid-column:1/-1}.aw-preview{border:1px solid #edf1f6;border-radius:11px;overflow:auto;max-height:400px}.aw-preview table{width:100%;border-collapse:collapse;font-size:8px}.aw-preview th{text-align:left;background:#f7f9fc;padding:7px;position:sticky;top:0}.aw-preview td{padding:7px;border-top:1px solid #edf1f6}.aw-muted{font-size:7px;color:#8b99b1;margin-top:2px}
.aw-panel{height:100%;overflow:auto;padding:14px}.aw-card{background:#fff;border:1px solid var(--line);border-radius:14px;padding:14px}.aw-panel-title{font-size:15px;font-weight:900;color:var(--ink)}.aw-panel-copy{font-size:10px;line-height:1.45;color:var(--muted);margin-top:4px}.aw-dist-grid{display:grid;grid-template-columns:minmax(0,1fr) 390px;gap:12px}.aw-selection{margin:10px 0;background:#f7faff;border:1px solid #dce6f3;border-radius:11px;padding:10px}.aw-selection b{display:block;color:var(--ink);font-size:11px}.aw-selection span{font-size:9px;color:var(--muted)}.aw-channels{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:10px}.aw-channel{border:1px solid var(--line);border-radius:12px;padding:10px}.aw-channel b{font-size:11px}.aw-channel p{font-size:9px;line-height:1.4;color:var(--muted);min-height:38px}.aw-state{font-size:9px;line-height:1.45;border:1px solid #e1e8f2;background:#f8fafc;border-radius:10px;padding:9px;margin-top:8px;color:#657797}.aw-state-warn{background:#fff8e8;border-color:#efdba5;color:#765815}.aw-state-good{background:#eafaf5;border-color:#b9e8d9;color:#086a58}.aw-label{display:block;font-size:9px;font-weight:800;color:#617394;margin:10px 0 4px}.aw-select{width:100%;border:1px solid #cfd8e7;border-radius:10px;padding:9px 10px;background:#fff}
.aw-activity{margin-top:10px}.aw-activity-row{display:grid;grid-template-columns:minmax(180px,1.2fr) 110px 100px 100px 100px 100px;gap:8px;align-items:center;padding:10px;border-top:1px solid #edf1f6;font-size:9px}.aw-activity-row.head{font-weight:900;color:#697b9c;background:#f7f9fc;border-top:0}.aw-activity-row b{font-size:10px}.aw-filter-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px;margin-top:10px}.aw-filter-card{border:1px solid var(--line);border-radius:12px;background:#fff;padding:10px}.aw-filter-card b{font-size:11px}.aw-filter-card p{font-size:8px;color:var(--muted)}.aw-field{display:inline-block;font-size:8px;padding:4px 6px;border-radius:999px;background:#f0f4fa;color:#566b90;margin:2px}
@media(max-width:1100px){.aw-audience-grid{grid-template-columns:170px 1fr}.aw-detail{grid-column:1/-1;border-left:0;border-top:1px solid var(--line);max-height:45vh}.aw-dist-grid{grid-template-columns:1fr}.aw-filter-grid{grid-template-columns:repeat(2,1fr)}}
@media(max-width:760px){#cia-aw{padding:0!important}.aw-shell{width:100%;height:100vh;border-radius:0}.aw-head-stat{display:none}.aw-tabs{overflow:auto}.aw-tab{padding:0 11px}.aw-audience-grid{display:block;overflow:auto}.aw-side{border-right:0;border-bottom:1px solid var(--line);display:flex;gap:4px;overflow:auto;padding:8px}.aw-side-title{display:none}.aw-cat{width:auto;white-space:nowrap}.aw-cat-count{display:none}.aw-center,.aw-detail{overflow:visible}.aw-info,.aw-channels,.aw-filter-grid,.aw-detail-actions{grid-template-columns:1fr;display:grid}.aw-detail-actions .wide{grid-column:auto}.aw-activity-row{grid-template-columns:1fr 80px 70px}.aw-activity-row span:nth-child(n+4){display:none}}
`;
  document.head.appendChild(s);
}

function shell(){
  styles();var old=document.getElementById('cia-aw');if(old)old.remove();
  var o=document.createElement('div');o.id='cia-aw';
  o.style.cssText='position:fixed;inset:0;z-index:14000;background:rgba(7,29,74,.57);backdrop-filter:blur(7px);display:flex;align-items:center;justify-content:center;padding:10px;';
  o.innerHTML='<div class="aw-shell"><header class="aw-head"><div class="aw-head-main"><div class="aw-title">Audiencias comerciales</div><div class="aw-sub">Catálogo vivo sobre una sola base. Las audiencias se actualizan con los datos; la ejecución se gestiona por separado.</div></div><div class="aw-head-stat"><span>Contactos</span><b id="aw-head-total">—</b></div><div class="aw-head-stat"><span>Audiencias</span><b id="aw-head-presets">—</b></div><button id="aw-close" class="aw-close" aria-label="Cerrar">✕</button></header><nav class="aw-tabs"><button class="aw-tab active" data-tab="audiences">📚 Audiencias</button><button class="aw-tab" data-tab="distribution">🎯 Distribución</button><button class="aw-tab" data-tab="activity">🕘 Actividad</button><button class="aw-tab" data-tab="explore">🔎 Explorar</button></nav><main class="aw-main"><section id="aw-view-audiences" class="aw-view active"></section><section id="aw-view-distribution" class="aw-view"></section><section id="aw-view-activity" class="aw-view"></section><section id="aw-view-explore" class="aw-view"></section></main></div>';
  document.body.appendChild(o);
  document.getElementById('aw-close').onclick=function(){o.remove()};
  o.querySelectorAll('.aw-tab').forEach(function(b){b.onclick=function(){switchTab(b.dataset.tab)}});
  return o;
}

function switchTab(tab){
  state.tab=tab;
  document.querySelectorAll('#cia-aw .aw-tab').forEach(function(b){b.classList.toggle('active',b.dataset.tab===tab)});
  document.querySelectorAll('#cia-aw .aw-view').forEach(function(v){v.classList.toggle('active',v.id==='aw-view-'+tab)});
  if(tab==='audiences')renderAudiences();
  if(tab==='distribution')renderDistribution();
  if(tab==='activity')loadActivity();
  if(tab==='explore')renderExplore();
}

function presets(){return state.meta&&Array.isArray(state.meta.presets)?state.meta.presets:[]}
function categoryCounts(){var out={};presets().forEach(function(p){out[p.category]=(out[p.category]||0)+1});return out}
function categories(){
  var cc=categoryCounts(),keys=['ALL','CALL','LEAD','APPOINTMENT','FOLLOWUP','SEGMENT','SALE','EMAIL','DEMOGRAPHIC','CONTACT'];
  return keys.filter(function(k){return k==='ALL'||cc[k]});
}
function filteredPresets(){
  var q=String(state.query||'').trim().toLowerCase();
  return presets().filter(function(p){
    return (state.category==='ALL'||p.category===state.category) &&
      (!q||String((p.name||'')+' '+(p.description||'')+' '+(p.category||'')).toLowerCase().indexOf(q)>=0);
  });
}
function selectedKey(){return state.selected?(state.selected.__all?'__ALL__':state.selected.preset_key):''}
function currentCount(s){if(!s)return null;if(s.__all)return state.meta&&state.meta.total_contacts;return s.count_cache}
function currentFresh(s){if(!s)return null;if(s.__all)return state.meta&&state.meta.catalog_refreshed_at;return s.count_refreshed_at}

function sideHtml(){
  var cc=categoryCounts();
  return '<div class="aw-side-title">Categorías</div>'+categories().map(function(k){
    var c=cat(k),n=k==='ALL'?presets().length:(cc[k]||0);
    return '<button class="aw-cat '+(state.category===k?'active':'')+'" data-cat="'+k+'"><span class="aw-cat-icon">'+c.icon+'</span>'+esc(c.label)+'<span class="aw-cat-count">'+n+'</span></button>';
  }).join('');
}
function audienceRows(){
  var a=filteredPresets(),all={__all:true,name:'Todos los contactos',description:'Universo comercial canónico completo.',category:'ALL',count_cache:state.meta&&state.meta.total_contacts,count_refreshed_at:state.meta&&state.meta.catalog_refreshed_at};
  var rows=(state.category==='ALL'&&!state.query?[all]:[]).concat(a);
  if(!rows.length)return '<tr><td colspan="4"><div class="aw-empty">No hay audiencias para esta búsqueda.</div></td></tr>';
  return rows.map(function(p){
    var key=p.__all?'__ALL__':p.preset_key,c=p.__all?{label:'Base completa'}:cat(p.category),count=currentCount(p),fresh=currentFresh(p),sel=selectedKey()===key;
    return '<tr data-key="'+esc(key)+'" class="'+(sel?'selected':'')+'"><td><div class="aw-name">'+esc(p.name)+'</div><div class="aw-desc">'+esc(p.description||'Audiencia comercial preestablecida')+'</div></td><td><span class="aw-badge">'+esc(c.label)+'</span></td><td><div class="aw-count">'+(count==null?'—':fmt(count))+'</div><div class="aw-fresh">'+(count==null?'Pendiente de conteo':'contactos')+'</div></td><td><div class="aw-fresh">'+esc(fresh?dt(fresh):'Sin actualizar')+'</div></td></tr>';
  }).join('');
}
function previewTable(){
  var a=state.preview;if(!Array.isArray(a)||!a.length)return '<div class="aw-empty">Pulsa <b>Ver 25 contactos</b> para revisar miembros actuales.</div>';
  return '<table><thead><tr><th>Contacto</th><th>Estado</th><th>Valor</th><th>Señal</th></tr></thead><tbody>'+a.map(function(x){
    var name=x.name||x.contact_name||x.contact_key||'Contacto',email=x.email||x.canonical_email||'',status=x.lifecycle||x.latest_call_status||'—',value=x.value_tier||'—',signal=x.latest_interest||x.next_appointment_at||'—';
    return '<tr><td><b>'+esc(name)+'</b><div class="aw-muted">'+esc(x.contact_key||'')+(email?' · '+esc(email):'')+'</div></td><td>'+esc(status)+'</td><td>'+esc(value)+'</td><td>'+esc(signal)+'</td></tr>';
  }).join('')+'</tbody></table>';
}
function detailHtml(){
  var s=state.selected;if(!s)return '<div class="aw-detail-empty"><div><b>Selecciona una audiencia</b><br><br>Aquí podrás revisar sus contactos, descargar CSV o usarla en una distribución.</div></div>';
  var count=currentCount(s),fresh=currentFresh(s),c=s.__all?{label:'Base completa'}:cat(s.category);
  return '<div class="aw-badge">'+esc(c.label)+'</div><div class="aw-detail-title" style="margin-top:8px">'+esc(s.name)+'</div><div class="aw-detail-copy">'+esc(s.description||'')+'</div><div class="aw-detail-count">'+(count==null?'—':fmt(count))+' <small>contactos</small></div><div class="aw-detail-meta">Conteo: '+esc(fresh?dt(fresh):'pendiente de actualización')+'</div><div class="aw-detail-actions"><button id="aw-preview-btn" class="aw-btn aw-primary">Ver 25 contactos</button><button id="aw-export-btn" class="aw-btn aw-secondary">Descargar CSV</button><button id="aw-use-btn" class="aw-btn aw-success wide" '+(s.__all?'disabled':'')+'>Usar en distribución</button></div><div id="aw-preview" class="aw-preview">'+previewTable()+'</div>';
}
function renderAudiences(){
  var root=document.getElementById('aw-view-audiences');if(!root)return;
  if(!state.meta){root.innerHTML='<div class="aw-empty">Cargando catálogo…</div>';return}
  root.innerHTML='<div class="aw-audience-grid"><aside class="aw-side">'+sideHtml()+'</aside><section class="aw-center"><div class="aw-toolbar"><input id="aw-search" class="aw-search" placeholder="Buscar no-show, Gold, email, llamada, edad…" value="'+esc(state.query)+'"><button id="aw-refresh" class="aw-btn aw-secondary">↻ Actualizar conteos</button></div><div class="aw-info"><div class="aw-kpi"><span>Base comercial</span><b>'+fmt(state.meta.total_contacts)+'</b><small>contactos canónicos</small></div><div class="aw-kpi"><span>Audiencias listas</span><b>'+fmt(state.meta.preset_count)+'</b><small>reglas vivas preestablecidas</small></div><div class="aw-kpi"><span>Último conteo</span><b style="font-size:12px">'+esc(state.meta.catalog_refreshed_at?dt(state.meta.catalog_refreshed_at):'Pendiente')+'</b><small>actualización explícita, no bloquea el panel</small></div></div><div class="aw-table-wrap"><table class="aw-table"><thead><tr><th>Audiencia</th><th>Tipo</th><th>Contactos</th><th>Actualización</th></tr></thead><tbody>'+audienceRows()+'</tbody></table></div></section><aside id="aw-detail" class="aw-detail">'+detailHtml()+'</aside></div>';

  document.getElementById('aw-search').oninput=function(){state.query=this.value;renderAudiences()};
  root.querySelectorAll('[data-cat]').forEach(function(b){b.onclick=function(){state.category=b.dataset.cat;state.preview=[];renderAudiences()}});
  root.querySelectorAll('tr[data-key]').forEach(function(row){row.onclick=function(){selectAudience(row.dataset.key)}});
  document.getElementById('aw-refresh').onclick=refreshCatalog;
  bindDetail();
}
function selectAudience(key){
  if(key==='__ALL__')state.selected={__all:true,name:'Todos los contactos',description:'Universo comercial canónico completo.',category:'ALL'};
  else state.selected=presets().find(function(p){return p.preset_key===key})||null;
  state.preview=[];renderAudiences();
}
function bindDetail(){
  var p=document.getElementById('aw-preview-btn'),e=document.getElementById('aw-export-btn'),u=document.getElementById('aw-use-btn');
  if(p)p.onclick=loadPreview;if(e)e.onclick=downloadSelected;if(u)u.onclick=function(){switchTab('distribution')};
}
function refreshCatalog(){
  var b=document.getElementById('aw-refresh');if(!b)return;b.disabled=true;b.textContent='Actualizando…';
  rpc('REFRESH_CATALOG',{}, {key:'catalog-refresh'}).then(function(d){
    toast('Conteos actualizados en '+fmt(d.duration_ms)+' ms');return loadMeta();
  }).catch(function(e){report(e)}).then(function(){if(b){b.disabled=false;b.textContent='↻ Actualizar conteos'}});
}
function loadPreview(){
  var s=state.selected;if(!s)return;var b=document.getElementById('aw-preview-btn');if(b){b.disabled=true;b.textContent='Cargando…'}
  var req=s.__all?rpc('PREVIEW_ALL',{limit:25,offset:0},{key:'preview'}):rpc('PREVIEW',{filter:s.dsl,limit:25,offset:0},{key:'preview'});
  req.then(function(d){state.preview=d.items||[];if(!s.__all&&d.count!=null){s.count_cache=Number(d.count);s.count_refreshed_at=d.observed_at||new Date().toISOString()}renderAudiences()}).catch(report).then(function(){var x=document.getElementById('aw-preview-btn');if(x){x.disabled=false;x.textContent='Ver 25 contactos'}});
}
function downloadSelected(){
  var s=state.selected;if(!s)return;var name=s.__all?'todos-los-contactos':slug(s.name);toast('Preparando CSV…');
  rpc('EXPORT_CSV',{all_contacts:!!s.__all,filter:s.__all?null:s.dsl,filename:name},{key:'export'}).then(function(d){
    var blob=new Blob(['\uFEFF'+String(d.csv||'')],{type:'text/csv;charset=utf-8;'}),url=URL.createObjectURL(blob),a=document.createElement('a');
    a.href=url;a.download=d.filename||name+'.csv';document.body.appendChild(a);a.click();a.remove();requestAnimationFrame(function(){URL.revokeObjectURL(url)});
    toast(fmt(d.row_count)+' contactos exportados');
  }).catch(report);
}

function normalizeAudience(a){
  a=a||{};return {id:a.id||a.audience_id||a.audiencia_id,name:a.name||a.nombre||'',description:a.description||a.descripcion||'',version:Number(a.current_version||a.version||a.version_number||1),filter:a.filter||a.dsl||a.filter_dsl||a.definition||null,raw:a};
}
function libraryItems(){var l=state.library||{};return Array.isArray(l.items)?l.items:(Array.isArray(l.audiences)?l.audiences:[])}
function sameJson(a,b){try{return JSON.stringify(a)===JSON.stringify(b)}catch(_){return false}}
function findSafeSaved(s){
  var arr=libraryItems();
  for(var i=0;i<arr.length;i++){var n=normalizeAudience(arr[i]);if(n.name===s.name&&n.filter&&sameJson(n.filter,s.dsl))return n}
  return null;
}
function ensurePersisted(){
  var s=state.selected;if(!s||s.__all)return Promise.reject(new Error('Selecciona una audiencia específica.'));
  if(s.persisted&&s.persisted.id)return Promise.resolve(s.persisted);
  var ex=findSafeSaved(s);if(ex){s.persisted=ex;return Promise.resolve(ex)}
  return rpc('CREATE_AUDIENCE',{name:s.name,description:s.description||'',filter:s.dsl,reason:'CIA_WORKSPACE_V3_DISTRIBUTION'},{key:'persist'}).then(function(d){
    var a=normalizeAudience(d.audience||d);s.persisted=a;return loadLibrary().then(function(){return a});
  });
}
function advisors(){var a=state.boot&&Array.isArray(state.boot.advisors)?state.boot.advisors:[];return a.filter(function(x){return Array.isArray(x.panels)&&x.panels.indexOf('advisor-calls')>=0})}
function canaryText(){
  if(state.canary)return '<b>Prueba activa.</b> El asesor debe solicitar el siguiente contacto desde Call Center. Después pulsa “Comprobar asignación”.';
  if(!state.selected||state.selected.__all)return 'Selecciona una audiencia específica desde la pestaña Audiencias.';
  if(!state.advisor)return 'Selecciona un asesor para preparar una prueba con 1 contacto.';
  return 'Listo. El primer clic revisa la selección y el segundo confirma una asignación reversible de 1 contacto.';
}
function renderDistribution(){
  var root=document.getElementById('aw-view-distribution');if(!root)return;var s=state.selected,adv=advisors();
  root.innerHTML='<div class="aw-panel"><div class="aw-dist-grid"><section class="aw-card"><div class="aw-panel-title">Distribución</div><div class="aw-panel-copy">La audiencia define a quiénes califican. La distribución decide quién los trabaja y por qué canal. Son procesos separados.</div><div class="aw-selection"><b>'+(s?esc(s.name):'Ninguna audiencia seleccionada')+'</b><span>'+(s?'Fuente activa para esta distribución.':'Vuelve a Audiencias y elige “Usar en distribución”.')+'</span></div><div class="aw-channels"><article class="aw-channel"><b>☎ Call Center</b><p>Materializa trabajo en la cola gobernada de asesores.</p><span class="aw-badge">Prueba segura disponible</span></article><article class="aw-channel"><b>@ Email</b><p>Consume la misma audiencia; no crea una segunda base.</p><span class="aw-badge">Fuente compartida</span></article><article class="aw-channel"><b>◉ WhatsApp</b><p>Consume la misma audiencia cuando el canal esté habilitado.</p><span class="aw-badge">Sin envío desde aquí</span></article></div><div class="aw-state"><b>Distribución masiva permanece bloqueada.</b> Primero validamos el recorrido real de 1 contacto: audiencia → asignación → Call Center → resultado → cierre.</div></section><aside class="aw-card"><div class="aw-panel-title">Prueba segura · 1 contacto</div><div class="aw-panel-copy">Comprueba el flujo con un solo asesor sin cambiar el trabajo de los demás.</div><label class="aw-label">Asesor de Call Center</label><select id="aw-advisor" class="aw-select"><option value="">Selecciona asesor</option>'+adv.map(function(a){return '<option value="'+esc(a.id)+'">'+esc(a.name||a.nombre||'Asesor')+(a.code||a.codigo_asesor?' · '+esc(a.code||a.codigo_asesor):'')+'</option>'}).join('')+'</select><button id="aw-test" class="aw-btn aw-primary" style="width:100%;margin-top:9px" '+(!s||s.__all?'disabled':'')+'>Preparar prueba · 1 contacto</button><button id="aw-check" class="aw-btn aw-secondary" style="width:100%;margin-top:7px" '+(state.canary?'':'disabled')+'>Comprobar asignación</button><button id="aw-stop" class="aw-btn aw-danger" style="width:100%;margin-top:7px" '+(state.canary?'':'disabled')+'>Cerrar prueba · volver a modo normal</button><div id="aw-test-state" class="aw-state">'+canaryText()+'</div></aside></div></div>';
  var sel=document.getElementById('aw-advisor');sel.value=state.advisor||'';sel.onchange=function(){state.advisor=this.value||null;state.armedUntil=0;renderDistribution()};
  document.getElementById('aw-test').onclick=startTest;document.getElementById('aw-check').onclick=checkTest;document.getElementById('aw-stop').onclick=stopTest;
}
function startTest(){
  if(state.canary||!state.selected||state.selected.__all||!state.advisor)return;
  var now=Date.now(),b=document.getElementById('aw-test'),st=document.getElementById('aw-test-state');
  if(now>state.armedUntil){state.armedUntil=now+15000;b.textContent='Confirmar · asignar 1 contacto';st.className='aw-state aw-state-warn';st.innerHTML='<b>Revisión final:</b> 1 contacto de <b>'+esc(state.selected.name)+'</b> será asignado al asesor elegido. Pulsa otra vez dentro de 15 segundos.';return}
  state.armedUntil=0;b.disabled=true;b.textContent='Activando…';
  ensurePersisted().then(function(a){return rpc('START_CANARY_ASSIGNMENT',{audience_id:a.id,version:a.version||1,advisor_user_id:state.advisor,source_limit:1,name:'Prueba segura Call Center'},{key:'test'})}).then(function(d){
    state.canary={plan_id:d.plan&&d.plan.plan_id,activation_id:d.activation&&d.activation.activation_id,advisor_user_id:state.advisor};toast('Prueba activada con 1 contacto');renderDistribution();
  }).catch(function(e){state.armedUntil=0;report(e,'aw-test-state');renderDistribution()});
}
function checkTest(){
  if(!state.canary)return;var st=document.getElementById('aw-test-state');st.className='aw-state';st.textContent='Comprobando…';
  rpc('CANARY_READBACK',{plan_id:state.canary.plan_id,advisor_user_id:state.canary.advisor_user_id},{key:'test-readback'}).then(function(d){
    var ai=d.assignments&&d.assignments.items,wi=d.advisor_work&&d.advisor_work.items,ac=Array.isArray(ai)?ai.length:0,wc=Array.isArray(wi)?wi.length:0;
    st.className='aw-state aw-state-good';st.innerHTML='<b>Comprobado:</b> '+ac+' asignación(es) · '+wc+' trabajo(s) visibles para el asesor.';toast('Asignación comprobada');
  }).catch(function(e){report(e,'aw-test-state')});
}
function stopTest(){
  if(!state.canary)return;var st=document.getElementById('aw-test-state');st.textContent='Cerrando prueba…';
  rpc('STOP_CANARY_ASSIGNMENT',{plan_id:state.canary.plan_id,advisor_user_id:state.canary.advisor_user_id},{key:'test-stop'}).then(function(){
    state.canary=null;state.armedUntil=0;toast('Prueba cerrada; Call Center volvió a modo normal');renderDistribution();if(state.tab==='activity')loadActivity(true);
  }).catch(function(e){report(e,'aw-test-state')});
}

function renderActivity(){
  var root=document.getElementById('aw-view-activity');if(!root)return;
  if(state.activity===null){root.innerHTML='<div class="aw-panel"><div class="aw-card"><div class="aw-empty">Cargando actividad…</div></div></div>';return}
  var a=Array.isArray(state.activity)?state.activity:[];
  root.innerHTML='<div class="aw-panel"><div class="aw-card"><div class="aw-panel-title">Actividad de audiencias</div><div class="aw-panel-copy">Snapshots y planes utilizados para ejecutar una audiencia. Esta vista no modifica Call Center.</div><div class="aw-activity"><div class="aw-activity-row head"><span>Audiencia</span><span>Estado</span><span>Asignados</span><span>En curso</span><span>Completados</span><span>Fecha</span></div>'+(a.length?a.map(function(x){return '<div class="aw-activity-row"><span><b>'+esc(x.audience_name||'Audiencia')+'</b><div class="aw-muted">'+esc(x.strategy||'—')+'</div></span><span><span class="aw-badge">'+esc(x.plan_state||x.activation_state||'—')+'</span></span><span>'+fmt(x.assignment_count||0)+'</span><span>'+fmt(x.in_progress||0)+'</span><span>'+fmt(x.completed||0)+'</span><span>'+esc(dt(x.created_at))+'</span></div>'}).join(''):'<div class="aw-empty">Aún no hay actividad de distribución que mostrar.</div>')+'</div></div></div>';
}
function loadActivity(force){
  var root=document.getElementById('aw-view-activity');if(!root)return;if(state.activity!==null&&!force){renderActivity();return}
  state.activity=null;renderActivity();rpc('ACTIVITY_SUMMARY',{limit:50},{key:'activity'}).then(function(d){state.activity=d.items||[];renderActivity()}).catch(function(e){state.activity=[];renderActivity();report(e)});
}
function renderExplore(){
  var root=document.getElementById('aw-view-explore');if(!root)return;if(!state.meta){root.innerHTML='<div class="aw-empty">Cargando dimensiones…</div>';return}
  var groups={};(state.meta.filters||[]).forEach(function(f){(groups[f.category]||(groups[f.category]=[])).push(f)});
  var lib=libraryItems();
  root.innerHTML='<div class="aw-panel"><div class="aw-card"><div class="aw-panel-title">Explorar la base</div><div class="aw-panel-copy">Estas son las dimensiones gobernadas disponibles para construir casos especiales. El uso cotidiano debe partir del catálogo de Audiencias.</div><div class="aw-filter-grid">'+Object.keys(groups).sort().map(function(k){var c=cat(k),a=groups[k];return '<article class="aw-filter-card"><b>'+c.icon+' '+esc(c.label)+'</b><p>'+a.length+' dimensiones disponibles</p>'+a.slice(0,12).map(function(f){return '<span class="aw-field">'+esc(f.label)+'</span>'}).join('')+(a.length>12?'<span class="aw-field">+'+(a.length-12)+' más</span>':'')+'</article>'}).join('')+'</div></div><div class="aw-card" style="margin-top:10px"><div class="aw-panel-title">Audiencias personalizadas guardadas</div><div class="aw-panel-copy">Combinaciones persistidas para reutilización. No reemplazan el catálogo vivo.</div><div class="aw-table-wrap" style="margin-top:10px"><table class="aw-table"><thead><tr><th>Nombre</th><th>Versión</th><th>Acción</th></tr></thead><tbody>'+(lib.length?lib.map(function(raw){var n=normalizeAudience(raw);return '<tr><td><div class="aw-name">'+esc(n.name||'Audiencia')+'</div><div class="aw-desc">'+esc(n.description||'')+'</div></td><td>v'+esc(n.version)+'</td><td><button class="aw-btn aw-secondary" data-saved="'+esc(n.id||'')+'">Usar</button></td></tr>'}).join(''):'<tr><td colspan="3"><div class="aw-empty">Aún no hay audiencias personalizadas.</div></td></tr>')+'</tbody></table></div></div></div>';
  root.querySelectorAll('[data-saved]').forEach(function(b){b.onclick=function(){var raw=lib.find(function(x){return String(normalizeAudience(x).id)===b.dataset.saved}),n=normalizeAudience(raw);state.selected={name:n.name,description:n.description,category:'CUSTOM',dsl:n.filter,persisted:n};switchTab('distribution')}});
}

function loadMeta(){
  return rpc('CATALOG_META',{}, {key:'meta'}).then(function(d){state.meta=d;var a=document.getElementById('aw-head-total'),b=document.getElementById('aw-head-presets');if(a)a.textContent=fmt(d.total_contacts);if(b)b.textContent=fmt(d.preset_count);if(state.tab==='audiences')renderAudiences();if(state.tab==='explore')renderExplore();return d});
}
function loadBoot(){
  return rpc('BOOTSTRAP',{}, {key:'boot'}).then(function(d){state.boot=d;if(state.tab==='distribution')renderDistribution();return d}).catch(function(e){if(!silent(e))console.warn('[CIA-V3] bootstrap secondary load failed',e);return null});
}
function loadLibrary(){
  return rpc('LIST_AUDIENCES',{limit:100,offset:0,include_archived:false},{key:'library'}).then(function(d){state.library=d;if(state.tab==='explore')renderExplore();return d}).catch(function(e){state.library={items:[],__error:true};if(!silent(e))console.warn('[CIA-V3] library secondary load failed',e);return state.library});
}
function open(){
  shell();renderAudiences();loadMeta().catch(function(e){report(e);var root=document.getElementById('aw-view-audiences');if(root)root.innerHTML='<div class="aw-empty">'+esc(friendly(e))+'</div>'});
  loadBoot();loadLibrary();
}

window.__AOS_CIA_INSTALL_AUDIENCE_BUTTON_V1__=installButton;
window.__AOS_CIA_INSTALL_AUDIENCE_BUTTON_V3__=installButton;
installButton();
})();