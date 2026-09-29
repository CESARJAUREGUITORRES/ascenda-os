/* ASCENDA Clinic — Marketing Web Bookings V1
 * Admin-only modal for landing -> ad -> campaign -> booking -> call -> sale lineage.
 * Reads only through the authenticated same-origin Marketing gateway.
 */
(function(){
'use strict';

if(window.__AOS_WEB_BOOKINGS_UI_V1){
  try{window.__AOS_WEB_BOOKINGS_UI_V1.mount();}catch(_){}
  return;
}

var S={rows:[],data:null,status:'',search:'',desde:'',hasta:''};
var STATUS=['','VENDIDO','ASISTIO','CONTACTADO','SIN CONTACTO','AGENDADO','NO ASISTIO','CANCELADA','REAGENDADA'];
function byId(id){return document.getElementById(id);}
function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function money(v){var n=Number(v||0);return 'S/'+Math.round(n).toLocaleString('es-PE');}
function num(v,d){var n=Number(v);return Number.isFinite(n)?n.toFixed(d||0):'—';}
function pad(n){return n<10?'0'+n:String(n);}
function isoDate(d){return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());}
function localDateTime(v){if(!v)return '—';try{return new Date(v).toLocaleString('es-PE',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});}catch(_){return String(v);}}
function appToken(){try{return String(sessionStorage.getItem('aos_app_token')||'').trim();}catch(_){return '';}}

function apiRead(payload){
  var headers={'Content-Type':'application/json','Accept':'application/json'};
  var token=appToken();if(token)headers['X-AOS-App-Token']=token;
  return fetch('/api/marketing/rpc',{
    method:'POST',credentials:'same-origin',cache:'no-store',headers:headers,
    body:JSON.stringify({name:'aos_marketing_web_bookings_admin_v1',payload:payload})
  }).then(function(r){return r.json().then(function(j){if(!r.ok)throw new Error((j&&j.error)||('HTTP_'+r.status));return j;});});
}

function style(){
  if(byId('mk-web-bookings-style'))return;
  var st=document.createElement('style');st.id='mk-web-bookings-style';st.textContent='\
#mk-web-bookings-btn{background:linear-gradient(135deg,#0D9488,#00C9A7)!important;}\
#mk-web-modal .modal{max-width:1500px;width:96vw;}\
.web-filterbar{display:flex;gap:6px;align-items:center;flex-wrap:wrap;margin-bottom:9px}.web-lbl{font-size:8px;font-weight:800;color:#6B7BA8;letter-spacing:.5px;text-transform:uppercase}.web-chip{font-family:DM Sans;padding:5px 10px;border-radius:14px;border:1px solid #DDE4F5;background:#fff;color:#6B7BA8;font-size:9px;font-weight:700;cursor:pointer}.web-chip.act{background:#0A4FBF;border-color:#0A4FBF;color:#fff}.web-sel,.web-search{font-family:DM Sans;font-size:9px;padding:6px 9px;border:1px solid #DDE4F5;border-radius:8px;background:#fff;color:#0D1B3E;outline:none}.web-search{margin-left:auto;min-width:210px}.web-kpis{display:grid;grid-template-columns:repeat(8,minmax(0,1fr));gap:6px;margin-bottom:10px}.web-kpi{background:#F8FAFF;border-radius:10px;padding:8px;text-align:center;min-width:0}.web-kpi-v{font-family:Exo 2;font-weight:800;font-size:17px;color:#071D4A;overflow-wrap:anywhere}.web-kpi-l{font-size:7px;color:#9AAAC8;text-transform:uppercase;letter-spacing:.4px;font-weight:700}.web-note{font-size:8px;color:#D97706;background:#FFFBEB;border:1px solid #FDE68A;border-radius:8px;padding:6px 9px;margin-bottom:8px}.web-table-wrap{border:1px solid #E2E8F0;border-radius:10px;overflow:auto;max-height:52vh}.web-table{width:100%;border-collapse:collapse;min-width:1380px}.web-table th{position:sticky;top:0;z-index:2;background:#F0F4FC;padding:7px 6px;text-align:left;font-size:7px;color:#6B7BA8;letter-spacing:.4px;border-bottom:1px solid #DDE4F5}.web-table td{padding:6px;border-bottom:1px solid #F1F5F9;font-size:8px;vertical-align:middle}.web-table tr:hover td{background:#F8FAFF}.web-state{display:inline-block;padding:2px 6px;border-radius:8px;font-size:7px;font-weight:800;white-space:nowrap}.web-state-VENDIDO{background:#F0FDF4;color:#059669}.web-state-ASISTIO{background:#ECFDF5;color:#047857}.web-state-CONTACTADO{background:#EBF2FF;color:#0A4FBF}.web-state-SINCONTACTO{background:#FEE2E2;color:#DC2626}.web-state-AGENDADO,.web-state-REAGENDADA{background:#F5F3FF;color:#7C3AED}.web-state-NOASISTIO,.web-state-CANCELADA{background:#FFF7ED;color:#C2410C}@media(max-width:900px){.web-kpis{grid-template-columns:repeat(2,minmax(0,1fr))}.web-search{margin-left:0;width:100%}#mk-web-modal .modal{width:98vw}}';document.head.appendChild(st);
}

function modal(){
  if(byId('mk-web-modal'))return;
  var root=document.createElement('div');root.className='mov';root.id='mk-web-modal';root.onclick=function(e){if(e.target===root)close();};
  root.innerHTML='<div class="modal"><div class="mhd"><div class="mtit">🌐 Citas Web <span id="web-count" style="font-size:10px;color:#6B7BA8;font-weight:600;margin-left:7px;">0 de 0</span></div><button class="mx" id="web-x">✕</button></div><div class="mbody">'+
    '<div class="web-filterbar"><span class="web-lbl">Rango:</span><button class="web-chip act" data-web-range="mes">📅 Este mes</button><button class="web-chip" data-web-range="hoy">☀ Hoy</button><button class="web-chip" data-web-range="7d">🗓 Últimos 7d</button><button class="web-chip" data-web-range="anio">Este año</button><button class="web-chip" data-web-range="custom">⚙ Personalizado</button><input type="date" class="web-sel" id="web-desde" style="display:none"><input type="date" class="web-sel" id="web-hasta" style="display:none"><button class="web-chip" id="web-apply" style="display:none;background:#0A4FBF;color:#fff">Aplicar →</button></div>'+
    '<div class="web-filterbar"><span class="web-lbl">Origen:</span><select class="web-sel" id="web-platform"><option value="">Todas las plataformas</option></select><select class="web-sel" id="web-campaign"><option value="">Todas las campañas</option></select><select class="web-sel" id="web-ad"><option value="">Todos los anuncios</option></select><select class="web-sel" id="web-landing"><option value="">Todas las landings</option></select><input class="web-search" id="web-search" placeholder="🔎 Cliente, número, landing o anuncio..."></div>'+
    '<div class="web-filterbar"><span class="web-lbl">Estado:</span><div id="web-statuses"></div></div>'+
    '<div class="web-kpis" id="web-kpis"></div><div id="web-spend-note"></div>'+
    '<div class="web-table-wrap"><table class="web-table"><thead><tr><th>INGRESO</th><th>CLIENTE</th><th>NÚMERO</th><th>LANDING</th><th>PLATAFORMA</th><th>CAMPAÑA</th><th>ANUNCIO</th><th>TRATAMIENTO</th><th>CITA</th><th>ASESOR</th><th>LLAM.</th><th>ESTADO</th><th>FACT.</th></tr></thead><tbody id="web-body"><tr><td colspan="13" class="ld">Sin datos</td></tr></tbody></table></div>'+
    '</div><div class="mfoot"><button class="mbtn mbtn-c" id="web-export">📥 Exportar CSV</button><button class="mbtn mbtn-p" id="web-close">Cerrar</button></div></div>';
  document.body.appendChild(root);
  byId('web-x').onclick=close;byId('web-close').onclick=close;byId('web-export').onclick=exportCsv;
  byId('web-search').oninput=function(){S.search=this.value||'';renderRows();};
  ['platform','campaign','ad','landing'].forEach(function(k){byId('web-'+k).onchange=load;});
  byId('web-apply').onclick=load;
  root.querySelectorAll('[data-web-range]').forEach(function(b){b.onclick=function(){setRange(this.getAttribute('data-web-range'));};});
  byId('web-statuses').innerHTML=STATUS.map(function(s){return '<button class="web-chip'+(s===''?' act':'')+'" data-web-status="'+esc(s)+'" style="margin-right:4px;margin-bottom:3px">'+(s||'Todos')+'</button>';}).join('');
  byId('web-statuses').querySelectorAll('[data-web-status]').forEach(function(b){b.onclick=function(){S.status=this.getAttribute('data-web-status')||'';byId('web-statuses').querySelectorAll('.web-chip').forEach(function(x){x.classList.toggle('act',(x.getAttribute('data-web-status')||'')===S.status);});load();};});
}

function setRange(kind){
  document.querySelectorAll('[data-web-range]').forEach(function(b){b.classList.toggle('act',b.getAttribute('data-web-range')===kind);});
  var d=byId('web-desde'),h=byId('web-hasta'),a=byId('web-apply');
  var custom=kind==='custom';d.style.display=custom?'':'none';h.style.display=custom?'':'none';a.style.display=custom?'':'none';
  if(custom)return;
  var now=new Date(),start,end;
  if(kind==='hoy'){start=end=now;}
  else if(kind==='7d'){end=now;start=new Date(now);start.setDate(start.getDate()-6);}
  else if(kind==='anio'){start=new Date(now.getFullYear(),0,1);end=new Date(now.getFullYear(),11,31);}
  else {
    var me=byId('mk-mes'),ye=byId('mk-anio');var m=me?Number(me.value):now.getMonth()+1,y=ye?Number(ye.value):now.getFullYear();
    start=new Date(y,m-1,1);end=new Date(y,m,0);
  }
  d.value=isoDate(start);h.value=isoDate(end);load();
}

function optionList(id,items,label){
  var e=byId(id),old=e.value;e.innerHTML='<option value="">'+label+'</option>'+((items||[]).map(function(v){return '<option value="'+esc(v)+'">'+esc(v)+'</option>';}).join(''));if(Array.from(e.options).some(function(o){return o.value===old;}))e.value=old;
}
function sourceFilters(){return {platform:byId('web-platform').value||'',campaign:byId('web-campaign').value||'',ad:byId('web-ad').value||'',landing:byId('web-landing').value||'',status:S.status||''};}

function renderSummary(){
  var d=S.data||{},s=d.summary||{},sp=s.spend_available===true;
  var cards=[['RESERVAS',s.reservas||0],['CONTACTADOS',s.contactados||0],['ASISTIERON',s.asistieron||0],['CLIENTES',s.clientes||0],['FACTURACIÓN',money(s.facturacion||0)],['INVERSIÓN',sp?money(s.inversion||0):'—'],['CAC',sp&&s.cac!=null?money(s.cac):'—'],['ROAS',sp&&s.roas!=null?num(s.roas,2)+'x':'—']];
  byId('web-kpis').innerHTML=cards.map(function(c){return '<div class="web-kpi"><div class="web-kpi-v">'+c[1]+'</div><div class="web-kpi-l">'+c[0]+'</div></div>';}).join('');
  byId('web-spend-note').innerHTML=sp?'':'<div class="web-note">La trazabilidad de reservas ya está operativa. CAC/ROAS por landing, campaña y anuncio aparecerán cuando exista inversión granular en el ledger de Marketing.</div>';
}

function stateClass(v){return 'web-state-'+String(v||'').replace(/\s+/g,'');}
function visibleRows(){var q=String(S.search||'').trim().toLowerCase();if(!q)return S.rows.slice();return S.rows.filter(function(r){return [r.nombre,r.apellido,r.numero_limpio,r.landing_name,r.landing_code,r.campaign_code,r.campaign_name,r.ad_code,r.ad_name,r.tratamiento].join(' ').toLowerCase().indexOf(q)>=0;});}
function renderRows(){
  var rows=visibleRows();byId('web-count').textContent=rows.length+' de '+((S.data&&S.data.rows_total)||S.rows.length);
  var b=byId('web-body');if(!rows.length){b.innerHTML='<tr><td colspan="13" class="ld">Sin citas web en este rango/filtro</td></tr>';return;}
  b.innerHTML=rows.map(function(r){var cliente=(String(r.nombre||'')+' '+String(r.apellido||'')).trim()||'—';var camp=r.campaign_code||r.campaign_name||'—';var ad=r.ad_code||r.ad_name||'—';var cita=(r.fecha_cita||'—')+(r.hora_cita?' · '+r.hora_cita:'');return '<tr><td>'+esc(localDateTime(r.created_at))+'</td><td style="font-weight:700">'+esc(cliente)+'</td><td style="font-family:monospace;color:#0A4FBF">'+esc(r.numero_limpio||'—')+'</td><td><b>'+esc(r.landing_name||r.landing_code||'—')+'</b><div style="font-size:6px;color:#9AAAC8">'+esc(r.landing_code||'')+'</div></td><td>'+esc(r.plataforma||'—')+'</td><td>'+esc(camp)+'</td><td>'+esc(ad)+'</td><td>'+esc(r.tratamiento||'—')+'</td><td>'+esc(cita)+'</td><td>'+esc(r.ultimo_asesor||r.asesor||r.advisor_code||'—')+'</td><td style="text-align:center;font-weight:700">'+Number(r.llamadas_total||0)+'</td><td><span class="web-state '+stateClass(r.estado_comercial)+'">'+esc(r.estado_comercial||'AGENDADO')+'</span></td><td style="font-weight:800;color:#059669">'+(Number(r.facturacion||0)>0?money(r.facturacion):'—')+'</td></tr>';}).join('');
}

function load(){
  var d=byId('web-desde'),h=byId('web-hasta');if(!d||!h||!d.value||!h.value)return;S.desde=d.value;S.hasta=h.value;
  byId('web-body').innerHTML='<tr><td colspan="13" class="ld">Cargando trazabilidad web...</td></tr>';
  apiRead({p_desde:S.desde,p_hasta:S.hasta,p_filters:sourceFilters()}).then(function(data){
    if(!data||data.ok!==true)throw new Error((data&&data.error)||'WEB_BOOKINGS_READ_FAILED');
    S.data=data;S.rows=Array.isArray(data.rows)?data.rows:[];
    var dim=data.dimensions||{};optionList('web-platform',dim.platforms,'Todas las plataformas');optionList('web-campaign',dim.campaigns,'Todas las campañas');optionList('web-ad',dim.ads,'Todos los anuncios');optionList('web-landing',dim.landings,'Todas las landings');
    renderSummary();renderRows();
  }).catch(function(e){console.error('[ASCENDA] Citas Web read failed',e);S.rows=[];byId('web-count').textContent='0 de 0';byId('web-body').innerHTML='<tr><td colspan="13" class="ld" style="color:#DC2626">No se pudo cargar Citas Web: '+esc(e&&e.message||e)+'</td></tr>';});
}

function open(){modal();var root=byId('mk-web-modal');if(!root)return;root.classList.add('open');S.status='';byId('web-search').value='';S.search='';byId('web-statuses').querySelectorAll('.web-chip').forEach(function(x){x.classList.toggle('act',(x.getAttribute('data-web-status')||'')==='');});setRange('mes');}
function close(){var r=byId('mk-web-modal');if(r)r.classList.remove('open');}
function exportCsv(){var rows=visibleRows();if(!rows.length)return;var head=['Ingreso','Cliente','Numero','Landing','Plataforma','Campana','Anuncio','Tratamiento','Fecha cita','Hora cita','Asesor','Llamadas','Estado','Facturacion'];function c(v){var s=String(v==null?'':v).replace(/"/g,'""');return /[",\n]/.test(s)?'"'+s+'"':s;}var csv=head.join(',')+'\n'+rows.map(function(r){return [r.created_at,(String(r.nombre||'')+' '+String(r.apellido||'')).trim(),r.numero_limpio,r.landing_name||r.landing_code,r.plataforma,r.campaign_code||r.campaign_name,r.ad_code||r.ad_name,r.tratamiento,r.fecha_cita,r.hora_cita,r.ultimo_asesor||r.asesor||r.advisor_code,r.llamadas_total,r.estado_comercial,r.facturacion].map(c).join(',');}).join('\n');var blob=new Blob(['\ufeff'+csv],{type:'text/csv;charset=utf-8;'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='citas_web_'+S.desde+'_a_'+S.hasta+'.csv';a.click();URL.revokeObjectURL(url);}

function mount(){
  style();modal();
  var existing=byId('mk-web-bookings-btn');if(existing)return;
  var leadsBtn=Array.from(document.querySelectorAll('.mk-hdr button')).find(function(b){return /Ver Leads/i.test(b.textContent||'');});
  if(!leadsBtn)return;
  var btn=document.createElement('button');btn.id='mk-web-bookings-btn';btn.className='mk-inv';btn.textContent='🌐 Citas Web';btn.onclick=open;leadsBtn.parentNode.insertBefore(btn,leadsBtn.nextSibling);
}

window.openWebBookingsModal=open;
window.__AOS_WEB_BOOKINGS_UI_V1={mount:mount,open:open,load:load};
mount();
})();
