from pathlib import Path
import re

path = Path('app/public/admin-sales.html')
text = path.read_text(encoding='utf-8')


def replace_once(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f'Marker not found: {label}')
    text = text.replace(old, new, 1)


replace_once(
    '/* Middle row: Metodos + Top Asesores + Top Tratamientos */\n.vs-mid{display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;}',
    '''/* Middle row: Metodos + Top Asesores */
.vs-mid{display:grid;grid-template-columns:1fr 1fr;gap:10px;}
.vs-rankings{display:grid;grid-template-columns:1fr 1fr;gap:10px;}
.rkx-row{display:grid;grid-template-columns:minmax(120px,1.1fr) minmax(90px,1fr) 88px;gap:8px;align-items:center;padding:6px 0;border-bottom:1px solid #F0F4FC;}
.rkx-row:last-child{border-bottom:none;}
.rkx-name{font-size:10px;font-weight:700;color:#0D1B3E;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.rkx-sub{font-size:8px;color:#9AAAC8;margin-top:1px;}
.rkx-bar{height:7px;background:#E2E8F0;border-radius:4px;overflow:hidden;}
.rkx-fill{height:100%;border-radius:4px;background:linear-gradient(90deg,#0A4FBF,#00C9A7);}
.rkx-fill-prod{background:linear-gradient(90deg,#7C3AED,#A78BFA);}
.rkx-val{text-align:right;font-family:'Exo 2',sans-serif;font-size:10px;font-weight:800;color:#071D4A;}
.rkx-note{font-size:8px;color:#9AAAC8;margin-top:8px;padding-top:7px;border-top:1px solid #F0F4FC;}
.more-btn{padding:6px 14px;border-radius:8px;border:1px solid #DDE4F5;background:#fff;color:#0A4FBF;font-size:10px;font-weight:700;cursor:pointer;font-family:'DM Sans';}
.more-btn:hover{background:#F8FAFF;border-color:#0A4FBF;}''',
    'middle-row-css',
)

replace_once(
    '@media(max-width:1100px){.vs-top{grid-template-columns:1fr 1fr;}.vs-mid{grid-template-columns:1fr 1fr;}}\n@media(max-width:800px){.krow{grid-template-columns:repeat(4,1fr);}.vs-top{grid-template-columns:1fr;}.vs-mid{grid-template-columns:1fr;}}',
    '@media(max-width:1100px){.vs-top{grid-template-columns:1fr 1fr;}.vs-mid{grid-template-columns:1fr 1fr;}.vs-rankings{grid-template-columns:1fr 1fr;}}\n@media(max-width:800px){.krow{grid-template-columns:repeat(4,1fr);}.vs-top{grid-template-columns:1fr;}.vs-mid{grid-template-columns:1fr;}.vs-rankings{grid-template-columns:1fr;}}',
    'responsive-css',
)

old_mid = '''  <!-- ROW 3: Metodos + Top Asesores + Top Tratamientos -->
  <div class="vs-mid">
    <div class="crd"><div class="ct">💳 MÉTODOS DE PAGO</div>
      <div class="mp-tabs" id="mp-tabs"></div>
      <div id="vs-metodos"><div class="ld">--</div></div>
    </div>
    <div class="crd"><div class="ct">🏆 TOP ASESORES</div><div id="vs-rank"><div class="ld">--</div></div></div>
    <div class="crd"><div class="ct">💊 TOP TRATAMIENTOS</div><div id="vs-trat"><div class="ld">--</div></div></div>
  </div>

  <!-- ROW 4: Detail table -->'''
new_mid = '''  <!-- ROW 3: Metodos + Top Asesores -->
  <div class="vs-mid">
    <div class="crd"><div class="ct">💳 MÉTODOS DE PAGO</div>
      <div class="mp-tabs" id="mp-tabs"></div>
      <div id="vs-metodos"><div class="ld">--</div></div>
    </div>
    <div class="crd"><div class="ct">🏆 TOP ASESORES</div><div id="vs-rank"><div class="ld">--</div></div></div>
  </div>

  <!-- ROW 4: Top Servicios + Top Productos -->
  <div class="vs-rankings">
    <div class="crd">
      <div class="ct">🩺 TOP SERVICIOS <span style="margin-left:auto;font-size:8px;color:#9AAAC8;font-family:'DM Sans';font-weight:600;">por facturación</span></div>
      <div id="vs-top-serv"><div class="ld">--</div></div>
      <div class="rkx-note">Servicios específicos. La categoría OTROS sigue incluida en facturación general, pero no compite en este ranking.</div>
    </div>
    <div class="crd">
      <div class="ct">🧴 TOP PRODUCTOS <span style="margin-left:auto;font-size:8px;color:#9AAAC8;font-family:'DM Sans';font-weight:600;">por facturación</span></div>
      <div id="vs-top-prod"><div class="ld">--</div></div>
      <div class="rkx-note">Solo ventas COMPRA DE PRODUCTO. El nombre se consolida desde DESCRIPCIÓN; se muestran ventas, no unidades físicas.</div>
    </div>
  </div>

  <!-- ROW 5: Detail table -->'''
replace_once(old_mid, new_mid, 'middle-html')

replace_once(
    '    </table></div>\n  </div>\n</div>\n\n<!-- MODAL CONFIG -->',
    '    </table></div>\n    <div id="vs-more" style="text-align:center;margin-top:10px;"></div>\n  </div>\n</div>\n\n<!-- MODAL CONFIG -->',
    'detail-more-container',
)

replace_once(
    "var VS={data:null,filtro:'all',modo:'mes',mpSede:'all'};",
    "var VS={data:null,filtro:'all',modo:'mes',mpSede:'all',detailLimit:100,detailStep:100};",
    'vs-state',
)
replace_once(
    "  VS.filtro='all';VS.mpSede='all';",
    "  VS.filtro='all';VS.mpSede='all';VS.detailLimit=100;",
    'load-reset',
)

annual_call = "      renderRank(d.porAsesor||[],d.noAplica);renderTrat(d.porTratamiento||[]);"
if text.count(annual_call) != 1:
    raise SystemExit(f'Expected 1 annual render call, found {text.count(annual_call)}')
text = text.replace(annual_call, "      renderRank(d.porAsesor||[],d.noAplica);renderCategoryRankings(d.detalle||[]);", 1)

month_call = "    renderRank(d.porAsesor||[],d.noAplica);renderTrat(d.porTratamiento||[]);"
if text.count(month_call) != 1:
    raise SystemExit(f'Expected 1 monthly render call, found {text.count(month_call)}')
text = text.replace(month_call, "    renderRank(d.porAsesor||[],d.noAplica);renderCategoryRankings(d.detalle||[]);", 1)

ranking_code = r'''function normSalesLabel(s){
  return String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/\s+/g,' ').trim();
}
function canonProductName(s){
  var x=normSalesLabel(s),c=x.replace(/[^A-Z0-9]/g,'');
  if(!x)return '';
  if(x.indexOf('BEAUTY MAKER')>=0||c.indexOf('BEAUTYMAKER')>=0)return 'BEAUTY MAKER';
  if(c.indexOf('LIFTINGB')>=0||c.indexOf('LIFTINB')>=0)return 'LIFTING B';
  if(c.indexOf('SKINREGENERATION')>=0)return 'SKIN REGENERATION';
  if(x.indexOf('ASTAXANTINA')>=0)return 'ASTAXANTINA';
  if(x.indexOf('REDUFAST')>=0)return 'REDUFAST';
  if(x.indexOf('HYDRASHIELD')>=0||x.indexOf('HIDRASHIELD')>=0)return 'HYDRASHIELD';
  if(x.indexOf('ULTRAGLOW')>=0)return 'ULTRAGLOW';
  if(x.indexOf('SPRAY')>=0&&x.indexOf('MINOX')>=0)return 'SPRAY MINOX';
  if(c.indexOf('NEUROVITAL')>=0)return 'NEUROVITAL';
  if(x.indexOf('ZINC')>=0)return 'ZINC';
  if(x.indexOf('ULTRA EYE')>=0)return 'ULTRA EYES';
  if(x.indexOf('RETINAL INTEN')>=0)return 'RETINAL INTENSE';
  return x.replace(/\s*\+\s*DELIVERY.*$/,'').trim();
}
function rankRows(map){
  return Object.keys(map).map(function(k){return{name:k,n:map[k].n,total:map[k].total};}).sort(function(a,b){return b.total-a.total;}).slice(0,8);
}
function renderCategoryRankings(rows){
  var serv={},prod={},servBase=0,prodBase=0;
  (rows||[]).forEach(function(v){
    var m=parseFloat(v.monto||0);if(!isFinite(m))m=0;
    if(v.tipo==='SERVICIO'){
      servBase+=m;
      var s=normSalesLabel(v.tratamiento||'');
      if(!s||s==='OTROS')return;
      if(!serv[s])serv[s]={n:0,total:0};serv[s].n++;serv[s].total+=m;
    }else if(v.tipo==='PRODUCTO'&&normSalesLabel(v.tratamiento)==='COMPRA DE PRODUCTO'){
      var p=canonProductName(v.descripcion||'');if(!p)return;
      prodBase+=m;if(!prod[p])prod[p]={n:0,total:0};prod[p].n++;prod[p].total+=m;
    }
  });
  renderRankList('vs-top-serv',rankRows(serv),servBase,false);
  renderRankList('vs-top-prod',rankRows(prod),prodBase,true);
}
function renderRankList(id,items,base,isProd){
  var box=el(id);if(!box)return;
  if(!items.length){box.innerHTML='<div class="ld">Sin datos</div>';return;}
  var max=items[0].total||1;
  box.innerHTML=items.map(function(x,i){
    var w=Math.max(4,Math.round((x.total/max)*100));
    var share=base>0?Math.round((x.total/base)*100):0;
    return '<div class="rkx-row"><div><div class="rkx-name" title="'+h(x.name)+'">'+(i+1)+'. '+h(x.name)+'</div><div class="rkx-sub">'+x.n+' ventas · '+share+'% categoría</div></div><div class="rkx-bar"><div class="rkx-fill '+(isProd?'rkx-fill-prod':'')+'" style="width:'+w+'%"></div></div><div class="rkx-val">S/'+fmt(x.total)+'</div></div>';
  }).join('');
}

function renderDet'''
text, n = re.subn(r"function renderTrat\(trats\)\{.*?\n\}\n\nfunction renderDet", ranking_code, text, count=1, flags=re.S)
if n != 1:
    raise SystemExit(f'Could not replace renderTrat block: {n}')

detail_code = r'''function renderDet(rows,filtro){
  var f=filtro==='all'?rows:rows.filter(function(r){return(r.tipo||'')===filtro;});
  var tb=el('vs-tb');
  var visible=f.slice(0,VS.detailLimit);
  el('vs-cnt').textContent=(visible.length<f.length?visible.length+' de ':'')+f.length+' registros';
  if(!f.length){tb.innerHTML='<tr><td colspan="10" class="ld">Sin ventas en este período</td></tr>';el('vs-tft').textContent='S/0';if(el('vs-more'))el('vs-more').innerHTML='';return;}
  var tot=f.reduce(function(s,v){return s+parseFloat(v.monto||0);},0);
  tb.innerHTML=visible.map(function(v){
    var m=parseFloat(v.monto||0);
    var cli=((v.nombres||'')+' '+(v.apellidos||'')).trim();
    var epC=v.estado_pago==='PAGO COMPLETO'?'ep-ok':v.estado_pago==='ADELANTO'?'ep-ad':'ep-pen';
    var epL=v.estado_pago==='PAGO COMPLETO'?'Completo':v.estado_pago==='ADELANTO'?'Adelanto':(v.estado_pago||'--');
    return '<tr style="cursor:pointer;" onclick="abrirEditorVenta('+(v.id||0)+')" title="Click para editar"><td style="color:#6B7BA8;white-space:nowrap;font-size:9px;">'+h(v.fecha)+'</td>'+
      '<td style="font-weight:700;font-size:10px;">'+h((cli||'--').substring(0,20))+'</td>'+
      '<td style="font-size:9px;color:#6B7BA8;">'+h(v.numero_limpio||'')+'</td>'+
      '<td style="font-size:9px;color:#6B7BA8;">'+h((v.tratamiento||'').substring(0,15))+'</td>'+
      '<td style="font-size:9px;">'+h((v.pago||'').substring(0,12))+'</td>'+
      '<td style="font-weight:700;color:#0D1B3E;">S/'+m.toFixed(2)+'</td>'+
      '<td><span class="ep '+epC+'">'+epL+'</span></td>'+
      '<td><span class="tb '+(v.tipo==='PRODUCTO'?'tb-p':'tb-s')+'">'+((v.tipo||'')==='PRODUCTO'?'PROD':'SERV')+'</span></td>'+
      '<td style="font-size:9px;font-weight:700;color:'+(CL[v.asesor]||'#6B7BA8')+';">'+h(v.asesor||'')+'</td>'+
      '<td style="font-size:9px;color:#6B7BA8;">'+h((v.sede||'').substring(0,6))+'</td></tr>';
  }).join('');
  el('vs-tft').textContent='S/'+fmt(tot);
  var more=el('vs-more');if(more){
    if(f.length>VS.detailLimit){var rem=f.length-VS.detailLimit;more.innerHTML='<button class="more-btn" onclick="vsMore()">Mostrar '+Math.min(VS.detailStep,rem)+' más · quedan '+rem+'</button>';}
    else{more.innerHTML=f.length>VS.detailStep?'<span style="font-size:9px;color:#9AAAC8;">'+f.length+' registros cargados</span>':'';}
  }
}
function vsFlt(btn){document.querySelectorAll('.ftab').forEach(function(t){t.classList.remove('act');});btn.classList.add('act');VS.filtro=btn.getAttribute('data-f');VS.detailLimit=100;if(VS.data)renderDet(VS.data.detalle||[],VS.filtro);}
function vsMore(){VS.detailLimit+=VS.detailStep;if(VS.data)renderDet(VS.data.detalle||[],VS.filtro);}

// ═══ CONFIG MODAL'''
text, n = re.subn(r"function renderDet\(rows,filtro\)\{.*?\n\}\nfunction vsFlt\(btn\)\{.*?\}\n\n// ═══ CONFIG MODAL", detail_code, text, count=1, flags=re.S)
if n != 1:
    raise SystemExit(f'Could not replace detail block: {n}')

path.write_text(text, encoding='utf-8')
print(f'Patched {path}')
