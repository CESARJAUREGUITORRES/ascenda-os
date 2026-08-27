/* Product FAQ UI overlay — 2026-08-27
   Scope: PRODUCTO repository only. Services keep existing behavior. */
(function(){
  function parseFaqs(v){
    try{
      if(!v)return [];
      var x=typeof v==='string'?JSON.parse(v):v;
      return Array.isArray(x)?JSON.parse(JSON.stringify(x)):[];
    }catch(e){return []}
  }
  function attr(s){
    return H(s).replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }
  window._acProdFaqs=[];
  window.acParseFaqs=parseFaqs;

  var baseRenderRepo=window.acRenderRepo;
  window.acRenderRepo=function(){
    var c=AC.selCat;
    if(!c)return '';
    if(AC.tipo!=='PRODUCTO')return baseRenderRepo();
    var o='<div class="ac-sec">Repositorio de productos — '+H(c.nombre)+'</div>';
    o+='<div style="font-size:8px;color:#6B7BA8;margin-bottom:8px">Click en un producto para editar su repositorio individual y sus preguntas frecuentes</div>';
    AC.items.forEach(function(it,i){
      var hasRepo=it.descripcion_clinica||it.descripcion_comercial||it.composicion;
      var fqs=parseFaqs(it.faqs);
      o+='<div class="ac-item-row" style="cursor:pointer" onclick="acEditProdRepo('+i+')">';
      o+='<span class="ac-item-name">'+H(it.nombre)+'</span>';
      o+='<span style="font-size:7px;font-weight:800;padding:2px 6px;border-radius:999px;background:#EEF2FF;color:#0A4FBF;white-space:nowrap">❓ '+fqs.length+' FAQs</span>';
      o+='<span style="font-size:7px;color:'+(hasRepo?'#059669':'#D97706')+';font-weight:700">'+(hasRepo?'✅ Con info':'⚠️ Sin info')+'</span></div>';
    });
    return o;
  };

  window.acRenderProdFaqs=function(){
    var el=$('pr-faqs');if(!el)return;
    el.innerHTML=window._acProdFaqs.map(function(f,i){
      return '<div class="ac-faq">'+
        '<div style="display:flex;gap:4px;margin-bottom:3px">'+
        '<input class="ac-fi" value="'+attr(f.q)+'" onchange="_acProdFaqs['+i+'].q=this.value" style="font-weight:700;flex:1" placeholder="Pregunta">'+
        '<button class="ac-btn ac-btn-d" style="padding:2px 6px;font-size:8px" onclick="_acProdFaqs.splice('+i+',1);acRenderProdFaqs()">x</button>'+
        '</div>'+
        '<textarea class="ac-ta" rows="3" onchange="_acProdFaqs['+i+'].a=this.value" placeholder="Respuesta">'+H(f.a)+'</textarea>'+
        '</div>';
    }).join('')||'<div style="font-size:9px;color:#9AAAC8;padding:8px">Sin FAQs — agrega la primera pregunta</div>';
    var badge=$('pr-faq-count');if(badge)badge.textContent=window._acProdFaqs.length+' FAQs';
  };

  window.acAddProdFaq=function(){
    window._acProdFaqs.push({q:'',a:''});
    window.acRenderProdFaqs();
  };

  window.acEditProdRepo=function(idx){
    var it=AC.items[idx];if(!it)return;
    window._acProdFaqs=parseFaqs(it.faqs);
    var o='<div class="ac-sec">Repositorio — '+H(it.nombre)+'</div>';
    o+=fgta('Descripción clínica','pr-desclin',it.descripcion_clinica||'');
    o+=fgta('Descripción comercial','pr-descom',it.descripcion_comercial||'');
    o+=fgta('Composición / Ingredientes','pr-comp',it.composicion||'');
    o+=fgta('Beneficios','pr-benef',it.beneficios||'');
    o+=fgta('Contraindicaciones','pr-contra',it.contraindicaciones||'');
    o+=fgta('Perfil paciente','pr-perfil',it.perfil_paciente||'');
    o+=fgta('Indicaciones de uso','pr-indic',it.indicaciones||'');
    o+='<div class="ac-sec" style="display:flex;align-items:center;justify-content:space-between">'+
       '<span>Preguntas frecuentes</span>'+
       '<span id="pr-faq-count" style="font-size:7px;font-weight:800;padding:2px 6px;border-radius:999px;background:#EEF2FF;color:#0A4FBF">'+window._acProdFaqs.length+' FAQs</span></div>';
    o+='<div style="font-size:8px;color:#6B7BA8;margin-bottom:6px">Conocimiento didáctico específico de este producto para atención, repositorio y futuro bot.</div>';
    o+='<div id="pr-faqs"></div>';
    o+='<button class="ac-btn ac-btn-s" style="font-size:9px;padding:4px 10px;margin-top:4px" onclick="acAddProdFaq()">+ FAQ</button>';
    o+='<div style="display:flex;gap:6px;margin-top:12px">'+
       '<button class="ac-btn ac-btn-p" onclick="acSaveProdRepo('+idx+')">Guardar repositorio + FAQs</button>'+
       '<button class="ac-btn ac-btn-s" onclick="acRenderMain()">Volver</button></div>';
    $('ac-main').innerHTML=o;
    window.acRenderProdFaqs();
  };

  window.acSaveProdRepo=function(idx){
    var it=AC.items[idx];if(!it)return;
    window._acProdFaqs=window._acProdFaqs.map(function(f){
      return {q:String(f.q||'').trim(),a:String(f.a||'').trim()};
    });
    var incomplete=window._acProdFaqs.some(function(f){return !f.q||!f.a});
    if(incomplete){alert('Completa pregunta y respuesta de todas las FAQs antes de guardar.');return}
    var seen={};
    var duplicated=window._acProdFaqs.some(function(f){
      var k=f.q.toLocaleLowerCase().replace(/\s+/g,' ').trim();
      if(seen[k])return true;seen[k]=1;return false;
    });
    if(duplicated){alert('Hay preguntas FAQ duplicadas. Corrígelas antes de guardar.');return}
    var body={
      descripcion_clinica:($('pr-desclin')||{}).value||null,
      descripcion_comercial:($('pr-descom')||{}).value||null,
      composicion:($('pr-comp')||{}).value||null,
      beneficios:($('pr-benef')||{}).value||null,
      contraindicaciones:($('pr-contra')||{}).value||null,
      perfil_paciente:($('pr-perfil')||{}).value||null,
      indicaciones:($('pr-indic')||{}).value||null,
      faqs:window._acProdFaqs,
      updated_at:new Date().toISOString()
    };
    sbPatch('aos_catalogo_servicios','id=eq.'+it.id,body,function(ok){
      if(!ok){alert('No se pudo guardar el repositorio. Intenta nuevamente.');return}
      Object.keys(body).forEach(function(k){it[k]=body[k]});
      it.faqs=JSON.parse(JSON.stringify(window._acProdFaqs));
      if(window.AOS_showToast)AOS_showToast('Repositorio + '+window._acProdFaqs.length+' FAQs guardado','','');
      AC.tab='repositorio';acRenderMain();
    });
  };
})();
