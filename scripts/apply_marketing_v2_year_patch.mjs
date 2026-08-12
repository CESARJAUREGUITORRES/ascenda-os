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
  "window.rAn=function(d){legacyCache.an=d;if(MK.modo==='anio'&&orig.rAn)orig.rAn(d);};",
  "window.rAn=function(d){legacyCache.an=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rAn)orig.rAn(d);};",
  'suppress legacy annual ads while V2 is active');
replaceOnce(file,
  "window.rCamp=function(d){legacyCache.camp=d;if(MK.modo==='anio'&&orig.rCamp)orig.rCamp(d);};",
  "window.rCamp=function(d){legacyCache.camp=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rCamp)orig.rCamp(d);};",
  'suppress legacy annual campaigns while V2 is active');
replaceOnce(file,
  "    } else {\n      var sc=document.getElementById('mk-v2-summary');if(sc)sc.style.display='none';\n    }",
  "    } else {\n      var sc=document.getElementById('mk-v2-summary');if(sc)sc.style.display='';\n      vrpc('aos_marketing_attribution_summary_v2_anio_preview',{p_anio:anio}).then(renderSummary).catch(function(e){console.warn('[MKT-V2] annual summary',e);});\n      vrpc('aos_marketing_anuncios_v2_anio_preview',{p_anio:anio,p_search:null,p_limit:200,p_offset:0,p_order:'fact_acum'}).then(function(rows){if(orig.rAn)orig.rAn(mapAds(rows));}).catch(function(e){console.warn('[MKT-V2] annual ads',e);if(legacyCache.an&&orig.rAn)orig.rAn(legacyCache.an);});\n      vrpc('aos_marketing_campanas_v2_anio_preview',{p_anio:anio,p_search:null,p_limit:200,p_offset:0,p_order:'fact_acum'}).then(function(rows){if(orig.rCamp)orig.rCamp(mapCamp(rows));}).catch(function(e){console.warn('[MKT-V2] annual campaigns',e);if(legacyCache.camp&&orig.rCamp)orig.rCamp(legacyCache.camp);});\n    }",
  'wire annual V2 summary ads and campaigns');

console.log('Marketing V2 annual-mode patch complete');
