import fs from 'node:fs';

function replaceOnce(file, oldText, newText, label){
  let text=fs.readFileSync(file,'utf8');
  const count=text.split(oldText).length-1;
  if(count!==1)throw new Error(`${label}: expected exactly 1 match, found ${count}`);
  text=text.replace(oldText,newText);
  fs.writeFileSync(file,text);
  console.log('patched:',label);
}

const file='app/public/admin-marketing-v2.js';
replaceOnce(file,
  "    mkL:window.mkL,\n    rHist:window.rHist,",
  "    mkL:window.mkL,\n    rKPI:window.rKPI,\n    rEmb:window.rEmb,\n    rHist:window.rHist,",
  'capture KPI and funnel renderers');

replaceOnce(file,
  "  var legacyCache={hist:null,an:null,camp:null};",
  "  var legacyCache={kpi:null,emb:null,hist:null,an:null,camp:null};",
  'extend legacy fallback cache');

replaceOnce(file,
  "  window.rLTV=function(k,hi,d){if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rLTV)orig.rLTV(k,hi,d);};\n  window.rAn=function(d){legacyCache.an=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rAn)orig.rAn(d);};",
  "  window.rLTV=function(k,hi,d){if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rLTV)orig.rLTV(k,hi,d);};\n  window.rKPI=function(d){legacyCache.kpi=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rKPI)orig.rKPI(d);};\n  window.rEmb=function(d){legacyCache.emb=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rEmb)orig.rEmb(d);};\n  window.rAn=function(d){legacyCache.an=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rAn)orig.rAn(d);};",
  'suppress legacy KPI and funnel after V2 activation');

replaceOnce(file,
  "  function renderLtvV2(rows){",
  `  function loadInvestment(anio,mes){
    var q=SB+'/rest/v1/aos_inversion_campanas?select=inversion&anio=eq.'+encodeURIComponent(anio);
    if(mes!=null)q+='&mes_num=eq.'+encodeURIComponent(mes);
    return fetch(q,{headers:{'apikey':SK,'Authorization':'Bearer '+SK}}).then(function(r){if(!r.ok)throw new Error('investment HTTP '+r.status);return r.json();}).then(function(rows){return (Array.isArray(rows)?rows:[]).reduce(function(s,x){return s+n(x.inversion);},0);});
  }

  function renderTopV2(rows,inv){
    rows=rows||[];var src;
    if(MK.modo==='mes'){
      var m=Number(document.getElementById('mk-mes').value);src=rows.filter(function(x){return n(x.mes)===m;})[0]||{};
    }else{
      src=rows.reduce(function(a,x){
        a.personas_unicas+=n(x.personas_unicas);a.leads_gestionados+=n(x.leads_gestionados);a.llamadas_atribuidas+=n(x.llamadas_atribuidas);
        a.leads_con_cita+=n(x.leads_con_cita);a.leads_con_asistencia+=n(x.leads_con_asistencia);a.clientes_m0+=n(x.clientes_m0);a.ventas_m0+=n(x.ventas_m0);
        a.fact_m0+=n(x.fact_m0);a.fact_acumulado+=n(x.fact_acumulado);return a;
      },{personas_unicas:0,leads_gestionados:0,llamadas_atribuidas:0,leads_con_cita:0,leads_con_asistencia:0,clientes_m0:0,ventas_m0:0,fact_m0:0,fact_acumulado:0});
    }
    var leads=n(src.personas_unicas),ll=n(src.leads_gestionados),citas=n(src.leads_con_cita),asist=n(src.leads_con_asistencia),cli=n(src.clientes_m0),ventas=n(src.ventas_m0),fact=n(src.fact_m0),factAc=n(src.fact_acumulado),inversion=n(inv);
    var k={leads:leads,llamados:ll,llamadasTotal:n(src.llamadas_atribuidas),citas:citas,asistieron:asist,clientes:cli,nVentas:ventas,factTotal:fact,factAcumulado:factAc,invTotal:inversion,
      roas:inversion>0?fact/inversion:null,cac:cli>0&&inversion>0?inversion/cli:null,pctLlamados:leads>0?ll/leads*100:0,cpl:leads>0&&inversion>0?inversion/leads:null,ltvMultiplier:fact>0?factAc/fact:null};
    var tasas={llamados:leads>0?ll/leads*100:0,citas:ll>0?citas/ll*100:0,asist:citas>0?asist/citas*100:0,clientes:asist>0?cli/asist*100:0,ventas:cli>0?ventas/cli*100:0};
    if(orig.rKPI)orig.rKPI(k);
    if(orig.rEmb)orig.rEmb({leads:leads,llamados:ll,citas:citas,asistieron:asist,clientes:cli,ventas:ventas,factTotal:fact,tasas:tasas});
  }

  function renderLtvV2(rows){`,
  'add lightweight KPI/funnel derivation');

replaceOnce(file,
  "    vrpc('aos_marketing_historico_v2_preview',{p_anio:anio}).then(function(rows){if(orig.rHist)orig.rHist(mapHist(rows));}).catch(function(e){console.warn('[MKT-V2] historico',e);if(legacyCache.hist&&orig.rHist)orig.rHist(legacyCache.hist);});\n    vrpc('aos_marketing_cohortes_ltv_v2_preview',{p_anio:anio}).then(renderLtvV2).catch(function(e){console.warn('[MKT-V2] ltv',e);});",
  "    var histP=vrpc('aos_marketing_historico_v2_preview',{p_anio:anio});\n    histP.then(function(rows){if(orig.rHist)orig.rHist(mapHist(rows));}).catch(function(e){console.warn('[MKT-V2] historico',e);if(legacyCache.hist&&orig.rHist)orig.rHist(legacyCache.hist);});\n    Promise.all([histP,loadInvestment(anio,MK.modo==='mes'?mes:null)]).then(function(res){renderTopV2(res[0],res[1]);}).catch(function(e){console.warn('[MKT-V2] KPI/embudo',e);if(legacyCache.kpi&&orig.rKPI)orig.rKPI(legacyCache.kpi);if(legacyCache.emb&&orig.rEmb)orig.rEmb(legacyCache.emb);});\n    vrpc('aos_marketing_cohortes_ltv_v2_preview',{p_anio:anio}).then(renderLtvV2).catch(function(e){console.warn('[MKT-V2] ltv',e);});",
  'render KPI and funnel from V2 historical payload');

console.log('Marketing V2 KPI/funnel consistency patch complete');
