from pathlib import Path

path = Path('app/public/admin-marketing.html')
text = path.read_text(encoding='utf-8')


def replace_once(src: str, old: str, new: str, label: str) -> str:
    count = src.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return src.replace(old, new, 1)


# 1) Click affordance + modal detail styles.
media_anchor = "@media(max-width:1100px){.mk-2t{grid-template-columns:1fr;}.emb-2{grid-template-columns:1fr;}}"
media_replacement = """.mk-an-row{cursor:pointer;transition:background .12s;}
.mk-an-row:hover td{background:#F0F7FF!important;}
.ad-detail-name{font-family:'Exo 2',sans-serif;font-weight:800;font-size:17px;line-height:1.35;color:#0D1B3E;word-break:break-word;padding:12px 14px;background:#F8FAFF;border:1px solid #E8EEF8;border-radius:12px;}
.ad-detail-sub{font-size:9px;color:#6B7BA8;margin-top:5px;}
.ad-detail-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;margin-top:12px;}
.ad-detail-kpi{background:#fff;border:1px solid #E8EEF8;border-radius:10px;padding:10px;text-align:center;min-width:0;}
.ad-detail-kpi-v{font-family:'Exo 2',sans-serif;font-size:18px;font-weight:800;color:#0D1B3E;overflow-wrap:anywhere;}
.ad-detail-kpi-l{font-size:7px;font-weight:700;letter-spacing:.4px;text-transform:uppercase;color:#9AAAC8;margin-top:2px;}
.ad-detail-note{margin-top:12px;padding:9px 11px;border-radius:9px;background:#F0FDFA;color:#0D9488;font-size:9px;line-height:1.5;}
@media(max-width:700px){.ad-detail-grid{grid-template-columns:repeat(2,minmax(0,1fr));}}
""" + media_anchor
text = replace_once(text, media_anchor, media_replacement, 'marketing detail CSS')

# 2) Add a small hint in the card header.
old_header = '<div class="crd"><div class="ct">📢 Top Anuncios <span class="tag tag-c">leads del mes</span></div>'
new_header = '<div class="crd"><div class="ct">📢 Top Anuncios <span class="tag tag-c">leads del mes</span><span style="margin-left:auto;font-size:8px;font-weight:600;color:#9AAAC8;">clic en una fila para ver detalle</span></div>'
text = replace_once(text, old_header, new_header, 'Top Anuncios header')

# 3) Insert read-only detail modal before the existing investment modal.
modal_anchor = '<div class="mov" id="m-iv"'
modal_html = '''<!-- ═══ MODAL DETALLE TOP ANUNCIO ═══ -->
<div class="mov" id="m-ad-detail" onclick="if(event.target===this)this.classList.remove('open')">
  <div class="modal" style="max-width:820px;width:94vw;">
    <div class="mhd">
      <div class="mtit">📢 Detalle del anuncio <span id="ad-detail-period" style="font-size:9px;color:#9AAAC8;font-weight:600;margin-left:6px;"></span></div>
      <button class="mx" onclick="el('m-ad-detail').classList.remove('open')">✕</button>
    </div>
    <div class="mbody" id="ad-detail-body"></div>
    <div class="mfoot"><button class="mbtn mbtn-p" onclick="el('m-ad-detail').classList.remove('open')">Cerrar</button></div>
  </div>
</div>

'''
text = replace_once(text, modal_anchor, modal_html + modal_anchor, 'Top Anuncios modal')

# 4) Keep current ad rows in state so clicking a row can open its details.
text = replace_once(text, "var MK={modo:'mes'};", "var MK={modo:'mes',anuncios:[]};", 'MK state')

# 5) Make rAn preserve row index for the click handler.
old_ran_start = "function rAn(an){\n  el('mk-an').innerHTML=an.length?an.map(function(a){"
new_ran_start = "function rAn(an){\n  MK.anuncios=an||[];\n  el('mk-an').innerHTML=an.length?an.map(function(a,idx){"
text = replace_once(text, old_ran_start, new_ran_start, 'rAn state/index')

# 6) Make every Top Anuncios row clickable and preserve the full ad name in DOM.
old_row_prefix = "return '<tr><td style=\"font-weight:600;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;\">'+h((a.nombre||'').substring(0,28))+'</td>"
new_row_prefix = "return '<tr class=\"mk-an-row\" onclick=\"mkAdDetail('+idx+')\" title=\"Ver detalle completo del anuncio\"><td style=\"font-weight:600;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;\">'+h(a.nombre||'—')+'</td>"
text = replace_once(text, old_row_prefix, new_row_prefix, 'clickable Top Anuncios row')

# 7) Insert detail renderer before campaign renderer.
render_anchor = 'function rCamp(tr){'
render_code = '''function _mkAdCard(label,value,color){
  return '<div class="ad-detail-kpi"><div class="ad-detail-kpi-v" style="color:'+(color||'#0D1B3E')+';">'+value+'</div><div class="ad-detail-kpi-l">'+label+'</div></div>';
}
function mkAdDetail(idx){
  var a=(MK.anuncios||[])[idx];if(!a)return;
  var fm=parseFloat(a.fact_mes||0),fa=parseFloat(a.fact_acum||0);
  var cf=parseInt(a.clientes_fuera||0),vf=parseInt(a.ventas_fuera||0);
  var postFact=Math.max(0,fa-fm);
  var citas=parseInt(a.citas||0),leads=parseInt(a.leads||0),clientes=parseInt(a.clientes||0),ventas=parseInt(a.ventas||0);
  var pctCita=leads>0?(citas/leads*100):0;
  var pctCliente=leads>0?(clientes/leads*100):0;
  var totalVentas=ventas+vf;
  var ticket=totalVentas>0?fa/totalVentas:0;
  var anio=Number(el('mk-anio').value),mes=Number(el('mk-mes').value);
  var periodo=MK.modo==='anio'?'Año '+anio:(MF[mes]+' '+anio);
  el('ad-detail-period').textContent='· '+periodo;
  el('ad-detail-body').innerHTML=
    '<div class="ad-detail-name">'+h(a.nombre||'—')+'<div class="ad-detail-sub">Cohorte de leads: '+h(periodo)+'</div></div>'+
    '<div class="ad-detail-grid">'+
      _mkAdCard('Leads',leads,'#0A4FBF')+
      _mkAdCard('Citas',citas,'#00C9A7')+
      _mkAdCard('% cita',pctCita.toFixed(1)+'%','#00C9A7')+
      _mkAdCard('Asistencias',parseInt(a.asistieron||0),'#7C3AED')+
      _mkAdCard('Clientes Mes 0',clientes,'#059669')+
      _mkAdCard('Ventas Mes 0',ventas,'#0D1B3E')+
      _mkAdCard('Fact. Mes 0',fm>0?'S/'+Math.round(fm).toLocaleString('es-PE'):'—','#0A4FBF')+
      _mkAdCard('Conv. lead→cliente',pctCliente.toFixed(1)+'%','#059669')+
      _mkAdCard('Clientes posteriores',cf>0?cf:'—','#7C3AED')+
      _mkAdCard('Ventas posteriores',vf>0?vf:'—','#D97706')+
      _mkAdCard('Fact. posterior',postFact>0?'S/'+Math.round(postFact).toLocaleString('es-PE'):'—','#D97706')+
      _mkAdCard('Fact. acumulada',fa>0?'S/'+Math.round(fa).toLocaleString('es-PE'):'—','#00C9A7')+
      _mkAdCard('Ticket acum.',ticket>0?'S/'+Math.round(ticket).toLocaleString('es-PE'):'—','#6B7BA8')+
    '</div>'+
    '<div class="ad-detail-note"><b>Lectura correcta de cohorte:</b> Mes 0 incluye únicamente ventas ocurridas durante el mes en que ingresó el lead. “Posteriores” incluye solo ventas después de cerrar ese mes; compras anteriores a la cohorte no se atribuyen a este anuncio.</div>';
  el('m-ad-detail').classList.add('open');
}
'''
text = replace_once(text, render_anchor, render_code + render_anchor, 'Top Anuncios detail renderer')

path.write_text(text, encoding='utf-8')
print('admin-marketing.html patched successfully')
